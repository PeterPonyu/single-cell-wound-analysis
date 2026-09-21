# Reproduction guide

The numerical reports and source tables contain completed computations, not
proposed experiments. Scientific numbers are retained in the publication
export. File and module names describe their functions. The checksum manifest
applies to this exact archive; provenance hashes inside computation reports
describe the source inputs at the time of their original execution.

## Included material

`wound_models/` contains the normalized topic decoder, deterministic frozen
projection, continuous population fields, sparse representation checks, count
readers, marker panels and barcode-aligned human wound data utilities.
`scripts/` contains analysis entry points. `outputs/` contains numerical reports,
source tables, the discovery model and saved cell coordinates. `cohort_metadata/`
contains mappings derived from published source-study metadata.
`manuscripts/` contains native LaTeX, bibliography files, R/TikZ figures and CSV
source data; `output/pdf/` contains the compiled manuscripts.

`RESULTS_INDEX.json` maps each archived result series to its manuscript use and
interpretive scope. The observed-design-power file includes the power component
used by the measurement study. Immune-compartment associations are supplied by
the disjoint-compartment analysis, and anatomical inference by the paired-patient
analysis. Source-study clinical metadata and acquisition identifiers are retained.

The frozen model covers 7,002 panel genes in 15 coordinates. Its focal coordinate
is identified by leading decoder genes rather than an asserted cell identity.
Per-cell arrays retain coordinate indices as mathematical indices. The encoded
coordinates used for dynamics and the normalized loadings used for abundance
comparisons are different outputs.

## Source data

Download source counts and author annotations from the linked GEO records.
Source-study terms and consent conditions continue to apply.

- [GSE165816](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE165816):
  discovery diabetic-foot/skin cohort. The focal analysis selects 25 foot-skin
  specimens; healing inference collapses repeated specimens to 11 patients.
- [GSE231643](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE231643):
  debridement projection with title-derived groups and limited clinical metadata.
- [GSE241132](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE241132):
  three-donor acute human wound time course. The author cell annotations must be
  joined by barcode before selecting fibroblasts and projecting counts.
- [GSE326622](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE326622):
  three mouse arms, one animal per arm and time point; a computational comparison.
- [GSE223964](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE223964),
  [GSE245703](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE245703),
  [GSE268834](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE268834), and
  [GSE248247](https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE248247):
  external tissue-context projections; they do not supply independent
  patient-level healing validation in these analyses.

The `fetch_*.sh` scripts document acquisition and integrity checks. Raw matrices
are downloaded to `data/raw/<accession>/` and are not included in this archive.
The discovery patient map derives from Supplementary Table 1 of the source
study, [doi:10.1038/s41467-021-27801-8](https://doi.org/10.1038/s41467-021-27801-8).
To rebuild that map, retrieve its clinical workbook and place it at
`cohort_metadata/source/41467_2021_27801_clinical_table.xlsx`.

## Analysis order

Run commands from the archive root. Inspect each command's `--help` for its
inputs and output location. Keep the archived reports for comparison and use
fresh output directories for reruns. A complete raw-data rerun requires count
downloads and substantially more computation than rebuilding the figures.

1. Fit the discovery representation with
   `python3 scripts/fit_expression_representation.py --steps 40000 --seed 0`.
   The manuscript uses 40,000 optimization steps; the generic CLI default is
   shorter. The archived model provides the exact projection reference when
   hardware-dependent training differs.
2. Project the debridement cohort, compare lineage readouts, characterize state
   mixtures, and assess technical controls and ambient RNA using the respective
   descriptive entry points. Threshold/capacity and pipeline-negative-control
   scripts read those saved loadings. `scan_sample_covariates.py` retains the
   entire 31-covariate screen, including nonsignificant associations.
3. Build or read the source-study patient map, infer the patient outcome contrast,
   benchmark patient readouts, and assess paired anatomy. The mapping's 54-study-
   specimen and 27-patient inventory is broader than the selected foot subset;
   none of those counts is substituted for the 11-patient healing analysis.
4. External cohort projection scripts precede the disjoint immune-compartment
   analysis. Readout correlations and label contrasts use the available study
   metadata; they do not imply an independently adjudicated clinical outcome.
5. Reconstruct the human held-out time point, compare time coordinates, evaluate
   donor transfer, benchmark population predictors, and evaluate training-donor
   count. The seed-stability and donor-count inference scripts summarize distinct
   sources of uncertainty. Target cells are excluded from the corresponding fit
   and standardization, and training endpoints are paired within donor.
6. Run `evaluate_mouse_timepoint.py --model-arm NDB`, and analogously PDB and GDB
   with separate output directories, before `summarize_mouse_model_arms.py`.
   Mouse arm names are the source-study labels. One animal per cell group
   precludes animal-level replication claims.
7. Run `assess_robustness.py` on the saved discovery and human temporal inputs.
   It recomputes the 20-patient bootstrap and 11-patient influence diagnostic,
   refits one seed-0 field, compares 25/50/100/200 RK4 steps, and assesses 50
   evaluation draws at each of 250/500/1,000 cells per distribution.

## Interpretation and numerical checks

The 20-patient abundance association uses fibroblast-count-weighted specimen
collapse before 10,000 bootstrap draws. The healing omission analysis reports
an influence range, not a new confidence interval. Repeated samples, cells and
bootstrap draws are not independent patients.

Energy distance is the empirical V-statistic used in the manuscripts. The new
integration comparison evaluates distances in double precision and shares
cells across resolutions. Its central evaluation-draw ranges measure Monte
Carlo sensitivity conditional on one field and the observed cohort. They do
not represent generalization intervals for new donors. Training randomness,
donor heterogeneity and evaluation subsampling are reported separately.

The release check compiles/imports the analysis programs, checks the frozen
decoder and deterministic evaluation, checks training-only scaling with a
synthetic held-out shift, and verifies the energy-statistic implementation
against its direct pairwise definition. Figure rebuilding and the added
robustness run are tested independently from the full raw-data pipeline.

The numerical input files remain the evidential record for the two studies.
The archive does not imply that every raw-count experiment has been rerun on
every operating system or accelerator.
