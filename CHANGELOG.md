# Changelog

## Unreleased

- Shorten the Turkish TCMB URL label to fit the selection screen.
- Clarify the one-report setup message and remove unreferenced documentation images.

## 0.3.0 — 2026-11-02

- Install one executable `ZCHE_TCMB_LOAD` by copy/paste or upload in SE38; abapGit remains optional.
- Replace custom profile tables and global classes with selection-screen settings and standard SAP variants.
- Select Turkish or English independently of the SAP session, including result descriptions and job summaries.
- Map six TCMB rate fields to SAP rate types; choose currencies, valid-from rules and optional code mappings.
- Check change authorization once before a real run; retain the BAPI's own authorization checks.
- Limit direct URLs to TCMB HTTPS addresses; use a Basis-managed SM59 destination for other hosts.
- Reject parent-folder paths and check dataset read authorization before opening a server file.
- Fix the quote currency to TRY and remove the redundant target-currency selection field.
- Report unexpected exception class/text while preserving earlier results; retain per-row BAPI/commit and Keep-policy safeguards.
- Add URL/path regression tests (55 embedded SAP tests total), retain the ABAP 7.00 syntax target and provide bilingual installation, use and job guides. [Verification](docs/validation.md).

## Earlier multi-object edition

The [previous edition at 3c28fbc](https://github.com/Cheditte/abap-tcmb-rates/commit/3c28fbc) used a generated installer, custom DDIC/profile tables and global classes. Version 0.3.0 replaces that setup with one report; preserve custom code and rebuild profile-based variants when upgrading.
