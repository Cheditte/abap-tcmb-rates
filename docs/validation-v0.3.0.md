# Validation record — v0.3.0 integration candidate

Date: 2 November 2026. This record separates maintainer-supplied handoff reports from checks performed during integration. The initial integration used operator-supplied SAP evidence. The operator subsequently authorized direct GUI work; a fresh, non-writing foreground and background check is recorded below. No exchange-rate writes were performed in that later documentation session.

## Source provenance

- Baseline: [single-program commit 9b1fc51](https://github.com/Cheditte/abap-tcmb-rates/commit/9b1fc51).
- The source in the supplied tcmb-handoff.zip matches that Git source after line-ending normalization.
- Baseline source SHA-256 (LF): bb9ee67592ddc80a864256a8a4f920d45819f3c918eb74528cabbc28d5118866.
- Integrated source SHA-256 (LF): 32de9aef8a306973110f3856cedb13072f65b5928d5b99a3fb33af31fcc3542b.
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
- Add ten integration regression tests and four language tests: the integrated report contains 48 SAP tests. These additions were not executed in SAP here.

## Local integration checks

| Check | Outcome and limit |
|---|---|
| abaplint 2.120.92, v700 | 0 issues. Three small standard-object stand-ins; incomplete SAP API/type definitions. Not a runtime compatibility result. |
| Supplemental source check | Single report/metadata and selected classic-syntax restrictions checked. Discovers 48 tests; does not execute them. Checks 56 bilingual message templates for key references/placeholder parity and all 14 ALV headers. |
| Whole-report JavaScript transpilation attempt | Failed dependency resolution for selection-screen types, SALV and CL_AUNIT_ASSERT, among others. The old test:logic runner/dependencies were removed; no old test count is claimed for the new report. |
| Documentation | Bilingual links/anchors and diagram layouts checked separately. Diagram art illustrates the intended workflow and is not a simulated SAP success capture. |

## Turkish/English presentation update

The report now has P_LANG values A (automatic/logon), T (Türkçe), E (English). The selection is applied at initialization, selection-screen PBO/PAI and START-OF-SELECTION for background runs. Variants can store an explicit choice independently of the execution logon language. Project-authored messages and ALV headings/descriptions use that choice; technical status codes, rate keys and calculations remain unchanged. Raw SAP/BAPI/OS messages and GUI menus retain their underlying language.

The four added native tests cover explicit/automatic choice, dynamic parameters containing placeholder-like text, technical status stability and visible unknown keys. Tests save/restore the language state; existing English wildcard assertions explicitly select English. The operator subsequently supplied the Turkish selection-screen and connection-success capture documented below. It does not show the language-switching interaction itself. Verify immediate refresh after USER-COMMAND LANG, saved language variants and job log/spool separately.

## Operator-supplied screen evidence — 2 November 2026

![Operator-supplied Turkish selection screen and successful connection message](images/sap-tr-connection-success.png)

The operator supplied this screenshot after receiving the language-enabled report. The original PNG was copied unchanged; no SAP GUI actions were performed by the documentation editor.

- Visible: P_LANG is T / Türkçe, Turkish selection labels and the Turkish test-mode label; a Turkish success message reports bulletin 2026/204 dated 2026-10-30 with 22 currencies.
- Interpretation: the displayed connection test succeeded in reading a bulletin. Its last-seven-days search is separate from the selected S_DATE (2026-10-29 in the image). The currency count is a parsed bulletin count, not a write count.
- Limits: rate mappings and date rule are still empty; no F8 rate preview, ALV translation, 48-test result, BAPI write or OB08 readback is evidenced. The screenshot does not attest the complete installed source hash, older-release compatibility, clean installation or the language-switching interaction.
### Turkish result list supplied subsequently

![Operator-supplied Turkish ALV result with an unchanged USD TRY rate](images/sap-tr-result-unchanged.png)

- Visible: one row for bulletin date and valid-from date 2026-10-27, USD, FX_BUY, rate type M, USD to TRY, rate 49.69970, factors 1:1, blank indirect-quotation flag, Turkish status description "Aynı kayıt mevcut" and technical status UNCHANGED. Several column headings are shortened by their display width.
- Interpretation: the result reports that the calculated rate already matches the SAP record. Turkish result headings and the localized unchanged-status description are now evidenced in a real result list.
- Limits: the selection screen/test flag and data-source selection are not visible. This is not evidence of a current BAPI write or an independent OB08 readback. It uses 27 October, whereas the walkthrough's initial-entry example uses 30 October; they must not be presented as the same run. Complete source identity and the 48 native tests remain unverified by this screenshot.
The operator later supplied three further images, described below. They extend the evidence but do not close all acceptance checks.

### Range selections, partial-write result and OB08 evidence

All three PNGs were copied byte-for-byte from the operator's attachments. They are real screens, not edited or generated SAP captures.

| Image | Visible evidence | Limit |
|---|---|---|
| [Range selection](images/sap-tr-range-test-settings.png) | 2026-07-01 through 2026-08-01; Turkish; Test checked; FX buying to M; SAME_DAY; USD visible; TRY; Update selected; HTTPS. | Multiple-selection values are not visible; a green multiple-selection indicator does not establish every selected code. Test checked is incompatible with claiming this image directly proves the later write run's selection state. |
| [Mixed result](images/sap-tr-range-write-locks.png) | July USD/EUR rows, Turkish Yeni kayıt/NEW entries, ERROR rows with E_TABLE locked by DEVELOPER, and NO_BULLETIN for 15 July. | NEW's actual-write description plus SAP BAPI error messages are consistent with the report's write path. The exact real-run selection state/source hash is not pictured. Many rate cells are truncated. The run must not be reported as entirely successful. |
| [OB08](images/sap-ob08-eur-july.png) | Change View; M/EUR/TRY, 1:1, visible July records including 53.08900 on 1 July and 54.48410 on 31 July. | Establishes visible OB08 EUR records, not complete USD coverage, independent conversion readback or recovery of failed keys. An additional October row and unrelated existing rates are also visible. |

The mixed result visibly flags at least 1 July USD, 6 July USD/EUR and 7 July USD with locks. Reconcile these exact keys before retry; do not infer that all other keys or the full range are accepted solely from the image.

The open OB08 Change View is a plausible lock source, not a proven diagnosis from lock management. Guides now explicitly require exiting maintenance after inspection and before writes. Resolve the owning transaction normally; inspect actual object/owner via SM12 if needed rather than deleting active locks as a generic workaround. See [SAP's lock-management guidance](https://learning.sap.com/courses/technical-implementation-and-operation-i-of-sap-s-4hana-and-sap-business-suite/describing-as-abap).

Still needed: exact current source identity; native 48-test results; unambiguous real-write selection state; complete rate/factor and conversion readback; restricted-user and older-release checks; dynamic-date/recurring write jobs; and confirmation that affected lock-error keys were recovered.

## Direct GUI evidence — 2 November 2026

With explicit operator authorization, the documentation session used the open A4H/001 SAP GUI and saved original captures without editing their contents. [Capture hashes](images/live-captures-2026-11-02.json) identify the 13 published PNGs. These actions extend the earlier evidence; they do not establish the installed source hash.

- Foreground selection: explicit T, 2026-07-01–2026-08-01, USD and EUR confirmed in the multiple-selection dialog, FX_BUY → M, SAME_DAY, TRY, inverse off, Keep, no-bulletin information, HTTPS, destination/URL blank. **Test was checked before execution.**
- Foreground result: 4 planned new, 0 updated, 40 unchanged, 0 skipped, 1 no-bulletin day (15 July), 0 errors. Missing keys are 1 July USD, 6 July USD/EUR and 7 July USD. They were not written or recovered.
- Saved variant `TCMB_DOC_TEST`; fixed dates, explicit Turkish, Test checked. Created one-off job `ZTCMB_DOC_TEST_20261102`, class C, report `ZCHE_TCMB_LOAD`, variant `TCMB_DOC_TEST`, execution user DEVELOPER, step language EN. Immediate start; Periodic Job unchecked.
- Job count **11385500**, SM37 **Finished**, start **02.11.2026 11:38:55**, end **11:40:09**, duration **74 seconds**, as shown in the job log. Spool **22145** was opened, not printed. The spool list displays a different time (12:40); time-zone agreement was not verified and should not be inferred from these screens.
- The Turkish job summary explicitly says **Deneme çalıştırması (kayıt yok)** with the same 4/0/40/0/1/0 counts. Turkish spool statuses include planned NEW and UNCHANGED; the stored Turkish selection is effective despite the EN step language.
- No recurring job, actual-write job, email notification or spool delivery recipient was configured. No existing rates, locks or other jobs were deleted. The saved test variant and completed job remain available for inspection.
- The separate OB08 window could not be captured: the UI tool twice returned `window crop is outside captured monitor`. Further actions on that window were stopped. The guide retains the operator-supplied OB08 screenshot and does not claim a new OB08 check.

![Foreground no-write result](images/sap-live-04-preview-results.png)

![Finished preview job and Turkish summary](images/sap-live-15-sm37-job-log.png)

This confirms one fixed-date foreground/background preview on the installed report, including a saved explicit-T variant, HTTPS processing and spool creation. It does not validate dynamic daily dates, restricted-user operation, actual-write jobs, old-release compatibility, all 48 native tests, full source identity or recovery of the four missing keys.

## Outstanding SAP acceptance

Run the [acceptance checklist](../CONTRIBUTING.md#sap-acceptance-checklist) against the integrated source hash: clean paste/upload and fixed-point arithmetic; actual GUI labels/listbox/connection button; all 48 tests; HTTPS/dry run; controlled write plus OB08/conversion readback; file errors/path spaces; failure recovery/commit and concurrency; saved variants/dynamic-date SM36 jobs; restricted user; SM59; optional abapGit; custom exits; actual older releases.

Old settings/installer screenshots are historical evidence for the earlier architecture and are not used as current single-report screens. The earlier connection, selection, result and OB08 images were operator-supplied. The later sap-live captures were collected directly during the authorized GUI session. Both groups illustrate only their recorded states; the remaining acceptance checks are still pending.
