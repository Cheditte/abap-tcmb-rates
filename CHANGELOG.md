# Changelog

## Unreleased

This revision is pre-release. The changes below have local static and JavaScript-transpiled logic validation; they have not been executed in SAP. SAP acceptance is tracked in [CONTRIBUTING.md](CONTRIBUTING.md#sap-acceptance-checklist).

### Changed

- Restrict the target currency to blank/TRY so a TRY quote cannot be stored as an unrelated cross rate.
- Preserve earlier results when a fatal source/parse error stops a range, and report the failing day.
- Treat every file-open failure as a file error. A missing local file no longer implies that TCMB did not publish a bulletin.
- Validate bulletin dates, units, positive numeric rates and currency identifiers, including duplicate codes.
- Improve write/commit error handling and regression coverage around the writer and loader boundaries.
- Preserve repeated spaces in application-server folder paths.

### Added

- Pinned local abaplint tooling, fixed-revision SAP stubs and GitHub Actions checks for 7.40 SP08 and 7.58 syntax targets.
- A reproducible JavaScript-transpiled logic regression harness for selected calculator, runner and writer tests, with pinned dependencies and an explicit SAP-runtime limitation.
- English/Turkish installation and first-run instructions, a DEV maintenance-dialog setup path, partial-write recovery guidance and explicit support limits.
- Contribution and SAP acceptance guidance, plus an unpublished English SAP Community author outline and technical fact pack.

### Historical baseline

The README previously reported 26 passing ABAP Unit tests and end-to-end verification on an SAP ABAP Platform 2023 trial on 1 November 2026. That evidence belongs to the earlier revision and does not establish that these changes have passed SAP activation or runtime checks.
