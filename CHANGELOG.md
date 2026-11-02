# Changelog

## 0.3.0 — integration candidate, unreleased

### Changed

- One executable ZCHE_TCMB_LOAD with local classes and embedded tests; copy/paste or upload directly in SE38. No installer, custom profile tables, DDIC objects or global-class dependencies.
- Selection-screen settings and standard variants replace custom profiles. Six TCMB rate mappings, date-rule list, code filters/renaming and optional server files remain configurable.
- Classic ABAP 7.00 syntax target, committed checker stand-ins and a pinned v700 lint command. Older SAP runtime support remains unverified.
- Preserve validation, file-error, path-space, partial-result and BAPI/commit checks while integrating the handoff. Keep policy also disables BAPI updates.
- Bilingual README, walkthrough, technical reference and workflow diagrams updated for one report. Old installer/settings captures are not presented as current screens.
- Expand the Turkish walkthrough with every selection-screen field, a one-currency first preview and an operator-supplied Turkish connection-success screenshot; distinguish connection evidence from rate preview/write acceptance.
- Add `P_LANG`: automatic/logon language, Türkçe or English independently of the SAP session. Variants retain the choice; selection labels, date choices, project messages, run summaries and ALV headings use it. Technical status codes remain stable with localized descriptions. SAP GUI menus and raw SAP/BAPI/OS diagnostics retain their underlying language.

### Validation

- Handoff reports 34 SAP tests and limited actual writes on the prior single-report edition. Ten integration regressions and four localization tests bring the embedded suite to 48; these additions have not been executed in SAP here. The operator supplied a Turkish selection/connection-success screenshot; rate preview/write, language variants and background localization acceptance remain pending.
- Old installer build/check and multi-object transpilation commands removed. A whole-report transpilation attempt could not resolve SAP UI/legacy test dependencies; CI runs static/source checks only.
- [Exact source provenance, local checks and SAP limitations](docs/validation-v0.3.0.md).

## Earlier multi-object edition — historical pre-release

The entries below describe the previous architecture and its historical validation, not the current one-report installation.

### Changed

- Rework the bilingual README and walkthrough from the overall flow and prerequisites to numbered actions and checkpoints, with clearer diagrams and maintainer-supplied SAP screenshots beside the relevant steps.
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
