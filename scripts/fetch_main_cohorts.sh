#!/usr/bin/env bash
# Fetch the three verified main-line cohorts.
# Identities checked against GEO series_matrix on 2026-09-17:
#   GSE165816 human DFU scRNA-seq (healer/nonhealer labels), 54 dense CSVs
#   GSE231643 human DFU debridement scRNA-seq (independent validation)
#   GSE326622 mouse NDB/PDB/GDB wounds, POD0/2/7/30 (10x mtx triplets)
#
# NOTE: do NOT use curl -C - here. NCBI intermittently ignores the Range header
# and replays the whole body, which silently appends a second copy onto the
# partial file (observed: 446,920,944 bytes for a 410,255,360 byte archive, tar
# unreadable past member 48). Each attempt therefore downloads to a .part file
# from scratch and is only promoted after its byte count matches filelist.txt.
set -u
BASE=https://ftp.ncbi.nlm.nih.gov/geo/series
ROOT=data/raw
MAX_TRIES=12

fetch () {
  local gse=$1 pre=$2
  local url="$BASE/$pre/$gse/suppl/${gse}_RAW.tar"
  local dst="$ROOT/$gse/${gse}_RAW.tar"
  local part="$dst.part"
  local want
  want=$(curl -sS --max-time 60 "$BASE/$pre/$gse/suppl/filelist.txt" \
         | awk -F'\t' '$1=="Archive"{print $4+0; exit}')
  if [ "${want:-0}" -le 0 ]; then
    echo "[$(date +%T)] $gse: cannot resolve expected size, skipping"; return 1
  fi
  echo "[$(date +%T)] $gse expects $want bytes"

  if [ -f "$dst" ] && [ "$(stat -c%s "$dst")" -eq "$want" ]; then
    echo "[$(date +%T)] DONE  $gse (already complete)"
  else
    for try in $(seq 1 $MAX_TRIES); do
      rm -f "$part"
      curl -sS --max-time 3600 --speed-limit 20000 --speed-time 120 \
           -o "$part" "$url" || true
      local have=0; [ -f "$part" ] && have=$(stat -c%s "$part")
      if [ "$have" -eq "$want" ]; then
        mv "$part" "$dst"
        echo "[$(date +%T)] DONE  $gse ($have bytes, attempt $try)"
        break
      fi
      echo "[$(date +%T)] $gse attempt $try short: $have / $want, retrying"
      sleep 10
    done
  fi
  rm -f "$part"
  curl -sS -o "$ROOT/$gse/filelist.txt" "$BASE/$pre/$gse/suppl/filelist.txt" 2>/dev/null
  curl -sS -o "$ROOT/$gse/${gse}_series_matrix.txt.gz" \
       "$BASE/$pre/$gse/matrix/${gse}_series_matrix.txt.gz" 2>/dev/null

  local final=0; [ -f "$dst" ] && final=$(stat -c%s "$dst")
  if [ "$final" -eq "$want" ] && tar -tf "$dst" >/dev/null 2>&1; then
    echo "[$(date +%T)] VERIFIED $gse (size ok, tar readable)"
  else
    echo "[$(date +%T)] INCOMPLETE $gse $final/$want"
  fi
}

fetch GSE165816 GSE165nnn
fetch GSE231643 GSE231nnn
fetch GSE326622 GSE326nnn
echo "[$(date +%T)] ALL FETCHES FINISHED"
