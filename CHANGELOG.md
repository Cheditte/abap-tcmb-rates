# Changelog

## Unreleased

This revision is pre-release. The current changes have local static and JavaScript-transpiled logic validation. An isolated single-file installation completed in SAP; final settings acceptance is partial. See the [validation record](docs/validation-2026-11-02.md). SAP acceptance is tracked in [CONTRIBUTING.md](CONTRIBUTING.md#sap-acceptance-checklist).

### Changed

- Respect blank/1/2/3 client controls, including local-only clients. Restore DDIC field metadata and selection-text prefixes, and activate report source/text objects correctly.
- Remove the truncated `NEXT_WORKD` domain fixed value. Keep CHAR12 date rules and provide full-name F4 choices in the settings report, with application validation.

- Restrict the target currency to blank/TRY so a TRY quote cannot be stored as an unrelated cross rate.
- Preserve earlier results when a fatal source/parse error stops a range, and report the failing day.
- Treat every file-open failure as a file error. A missing local file no longer implies that TCMB did not publish a bulletin.
- Validate bulletin dates, units, positive numeric rates and currency identifiers, including duplicate codes.
- Improve write/commit error handling and regression coverage around the writer and loader boundaries.
- Preserve repeated spaces in application-server folder paths.

### Added

- Generated single-file SE38 installer with preview-only defaults, package/task checks, existing-object protection, embedded DDIC/OO/report metadata and test includes. Fresh installation only; the scope and limits of the completed SAP run are recorded.
- Simple profile editor with explicit currency selection, table authorization/client/CTS checks, profile locking and stale-edit protection. Advanced profiles are preserved.
- Twenty configuration-rule regression tests and generated-payload round-trip/completeness checks in CI. Updated bilingual guides and setup diagrams for the SE38 route.

- Separate English/Turkish setup and usage guides and technical references, with static setup diagrams, explicit sample values and first-run result explanations.
- Pinned local abaplint tooling, fixed-revision SAP stubs and GitHub Actions checks for 7.40 SP08 and 7.58 syntax targets.
- A reproducible JavaScript-transpiled logic regression harness for selected calculator, runner and writer tests, with pinned dependencies and an explicit SAP-runtime limitation.
- English/Turkish installation and first-run instructions, a DEV maintenance-dialog setup path, partial-write recovery guidance and explicit support limits.
- Contribution and SAP acceptance guidance, plus an unpublished English SAP Community author outline and technical fact pack.

### Historical baseline

The README previously reported 26 passing ABAP Unit tests and end-to-end verification on an SAP ABAP Platform 2023 trial on 1 November 2026. That evidence belongs to the earlier revision and does not establish that these changes have passed SAP activation or runtime checks.
