# Single-cell wound measurement and population dynamics

Author: Zeyu Fu. Version: 0.1.0.

Repository: [single-cell-wound-analysis](https://github.com/PeterPonyu/single-cell-wound-analysis).
Analysis code is released under the MIT License. Manuscripts, figures and
source-study data retain their respective rights; see [NOTICE](NOTICE).

This software accompanies two studies of public wound single-cell data. The
first asks whether a fibroblast-associated expression loading primarily tracks
cell-state abundance and whether it supports patient-level healing inference.
The second evaluates reconstruction of a held-out acute-wound distribution and
transfer to a held-out donor. Neither study establishes a clinically validated
prognostic tool.

The archive includes the two manuscripts, 14 editable vector figures, numerical
tables and figure source data, analysis programs, completed numerical reports,
a frozen expression model, and saved coordinates for computational sensitivity
analyses. GEO accession numbers and published study pseudonyms identify the
source material. Array indices identify model coordinates; the focal loading
is described biologically as the TIMP1/COL3A1/DCN-rich fibroblast-associated topic.

## Read the manuscripts

- [Measurement construct and patient inference](output/pdf/paper1_mixture_weight_construct_validation.pdf)
- [Acute-wound population dynamics](output/pdf/paper2_population_flow_temporal_dynamics.pdf)

The measurement study uses 25 discovery specimens and 20 mapped patients for
the state-abundance association. Its healing comparison uses 14 specimens from
11 patients. The acute temporal study has three independent donors. Bootstrap
draws, integration resolutions, training seeds and evaluation subsamples do not
increase those biological sample sizes.

## Reproduce and verify

The recorded environment uses Python 3.13.5 and the packages in `requirements.txt`. CPU computation
is supported; the recorded neural fits used CUDA. The plotting workflow needs R
with ggplot2, tikzDevice, jsonlite and digest, XeLaTeX/BibTeX/latexmk, Poppler, and
the Arial and TeX Gyre fonts. Fonts are resolved from the installed environment
and are not redistributed in the source archive.

```sh
python3 verify_archive.py --smoke
python3 manuscripts/latex/export_tables.py
python3 manuscripts/build_main_figures.py
python3 manuscripts/latex/build.py --render
python3 scripts/assess_robustness.py --output-dir outputs/reruns/robustness
```

The first command verifies file checksums, citation authorship, model/scaler
invariants, and analysis CLI imports. The next three rebuild tables, figures and
manuscripts from the archived numerical inputs. The final command repeats the
patient bootstrap and fits one field for integration/evaluation sensitivity;
it needs no raw-count download. Use a fresh output directory for each rerun.

[REPRODUCIBILITY.md](REPRODUCIBILITY.md) describes source data, the order of the
raw-data analyses, the tested scope, and numerical interpretation.

## Citation and archive

Software citation metadata are in [CITATION.cff](CITATION.cff), with matching
Zenodo metadata in [.zenodo.json](.zenodo.json). Repository and DOI links are
recorded only after the corresponding records exist. The manifest hashes the
exact release files; result-report provenance describes the original
computation and should not be mistaken for the checksum of a newly rendered
figure or reorganized source file.

[ARCHIVING.md](ARCHIVING.md) documents the archive procedure. `archive_draft.py`
validates metadata and an archive offline by default, and can create or resume
an authenticated Zenodo draft. Publishing is a separate author action in the
archive interface. A DOI is recorded only after that published record exists.
