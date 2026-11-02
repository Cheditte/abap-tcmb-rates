# Validation record — v0.3.0 integration candidate

Date: 2 November 2026. This record separates maintainer-supplied handoff reports from checks performed during integration. No SAP GUI actions or exchange-rate writes were performed during this integration; the operator elected to perform SAP steps personally.

## Source provenance

- Baseline: [single-program commit 9b1fc51](https://github.com/Cheditte/abap-tcmb-rates/commit/9b1fc51).
- The source in the supplied tcmb-handoff.zip matches that Git source after line-ending normalization.
- Baseline source SHA-256 (LF): bb9ee67592ddc80a864256a8a4f920d45819f3c918eb74528cabbc28d5118866.
- Integrated source SHA-256 (LF): d8897ae496be72973bfb9dfe52c18503f8eb23474d9657c8f7973b062aac1c7e.
- The integration branch starts from main; unrelated single-program history was copied deliberately rather than force-pushed over main.

## Results reported in the handoff

These are reports from the prior work, not fresh execution observed during integration. The supplied ZIP contains source/docs/checker stubs, not original SAP logs or current GUI evidence.

| Reported check | Reported outcome |
|---|---|
| System | SAP ABAP Platform 2023 trial, described as SAP_BASIS 7.58. Exact SP/kernel evidence was not supplied. One bundled README inconsistently says 816; that number is not used as a verified SAP_BASIS release. |
| Activation | No activation messages. |
| SAP Unit | 34 tests passed for the handoff edition. |
| Preview job | USD/JPY, 27–30 October, forex buying to example M, next working day with the reported TR calendar; JPY per 100 units and 100:1 ratio. No HTTP bulletins reported for 28–29 October. |
| Invalid date rule | Job cancelled with a configuration message. |
| File warning | Missing file was classified NO_BULLETIN in the handoff. This is changed below and requires retest. |
| Limited actual write | USD/TRY for 27 October: NEW, then UNCHANGED on rerun. This is not evidence of OB08/readback for the integrated source. |

Earlier multi-object readback and installer results remain historical. See the [previous record](validation-2026-11-02.md).

## Integration corrections

- Reject non-TRY targets, invalid/duplicate currency codes, impossible dates, invalid/nonpositive supplied values and missing/fractional/nonpositive Units.
- Validate positive factors/Units before calculation and catch arithmetic/assignment overflow.
- Treat all failed file opens as FILE/ERROR rather than assuming a holiday; preserve repeated spaces in server paths.
- Keep earlier date results visible when a later source/parse failure stops the range.
- Respect Keep policy at the BAPI update flag, check BAPI/commit returns and report failed commits as ERROR. Commits are per row, so a range remains non-atomic.
- Use the actual current certificate chain rather than prescribing one root name.
- Add ten embedded regression tests: the integrated report contains 44 SAP tests. These additions were not executed in SAP here.

## Local integration checks

| Check | Outcome and limit |
|---|---|
| abaplint 2.120.92, v700 | 0 issues. Three small standard-object stand-ins; incomplete SAP API/type definitions. Not a runtime compatibility result. |
| Supplemental source check | Single report/metadata and selected classic-syntax restrictions checked. Discovers 44 tests; does not execute them. |
| Whole-report JavaScript transpilation attempt | Failed dependency resolution for selection-screen types, SALV and CL_AUNIT_ASSERT, among others. The old test:logic runner/dependencies were removed; no old test count is claimed for the new report. |
| Documentation | Bilingual links/anchors and diagram layouts checked separately. Diagram art illustrates the intended workflow and is not a simulated SAP success capture. |

## Outstanding SAP acceptance

Run the [acceptance checklist](../CONTRIBUTING.md#sap-acceptance-checklist) against the integrated source hash: clean paste/upload and fixed-point arithmetic; actual GUI labels/listbox/connection button; all 44 tests; HTTPS/dry run; controlled write plus OB08/conversion readback; file errors/path spaces; failure recovery/commit and concurrency; saved variants/dynamic-date SM36 jobs; restricted user; SM59; optional abapGit; custom exits; actual older releases.

Old settings/installer screenshots are historical evidence for the earlier architecture and are not used as current single-report screens. No fresh public screenshots were fabricated or captured from the operator's SAP system during this integration.
