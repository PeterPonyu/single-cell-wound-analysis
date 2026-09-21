# Software citation and archival release

The software author is Zeyu Fu. Citation metadata are provided in `CITATION.cff`
and `.zenodo.json`. The archive version is 0.1.0. A DOI is added only after it has
been returned by the archive service; citation metadata never contain a sample
or invented DOI.

## Archive procedure

1. Review the release contents, authorship and distribution license.
2. Push the reviewed repository version to its GitHub repository, or upload the
   release ZIP directly to a Zenodo draft.
3. If using the GitHub integration, enable the repository in the author's Zenodo
   account before creating a versioned GitHub release. Zenodo uses `.zenodo.json`
   when both supported metadata files are present.
4. Review the Zenodo draft and publish the archival record. Record the version
   DOI for the exact archived software and the concept DOI for the version series.
5. Add the returned identifiers and repository URL to the citation files and to
   each manuscript's code-availability statement, then verify that the DOI
   resolves to the intended record and version.

The archive bundle contains a checksum manifest. Source-study accession numbers,
published specimen identifiers and mathematical dimensions are retained for
reproducibility. Code and manuscript names describe their scientific functions.

The license choice is not inferred from authorship. Until the author approves a
distribution license, this is a release candidate and no license grant is
represented in its citation metadata.

The included draft uploader validates an archive without a network request:

```sh
python3 archive_draft.py ../single-cell-wound-analysis-0.1.0.zip
```

After the license is recorded, `--execute` creates or resumes a draft with an
environment-provided `ZENODO_ACCESS_TOKEN`. `--sandbox` instead uses the test
service and `ZENODO_SANDBOX_TOKEN`. The local state file preserves the deposition
identifier so a resumed upload uses the same draft. Upload checksums are checked
against the service response. The tool never calls the publication endpoint.
A reserved DOI in a draft is distinct from a published, resolving DOI.

Official guidance: [GitHub software citation](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-citation-files),
[Zenodo software metadata](https://help.zenodo.org/docs/github/describe-software/),
[Zenodo software archiving](https://help.zenodo.org/docs/github/archive-software/).
