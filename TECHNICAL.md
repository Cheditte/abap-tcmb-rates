# Technical reference

> **English** | [Türkçe](TECHNICAL.tr.md) · [README](README.md) · [Installation and use](WALKTHROUGH.md)

## Structure and release target

`src/zche_tcmb_load.prog.abap` is one executable report containing types, business logic, selection screen, local classes and SAP Unit tests. It creates no custom DDIC objects or global classes. `src/package.devc.xml` and report XML are metadata for optional abapGit import.

The syntax target is **ABAP 7.00**: explicit declarations, `CREATE OBJECT`, classic Open SQL, `CONCATENATE`, packed numbers and `CL_AUNIT_ASSERT`. Tests use `"#AU` comments rather than `RISK LEVEL`/`DURATION` additions. API/runtime compatibility on actual 7.00/7.01/7.02 systems remains unverified; activation on 7.58 does not establish it. [Validation record](docs/validation.md).

For manual creation, enable **Fixed point arithmetic** in report attributes. Do not force 72-character lines; import the complete source including tests. `SELECTION_TEXTS_MODIFY` creates labels; `VRM_SET_VALUES` fills the date-rule list. The text table must be exactly `STANDARD TABLE OF rsseltexts WITH DEFAULT KEY`. Verify these interfaces on the target older release.

**Dil / Language (`P_LANG`)** selects the report's language without changing the SAP session. `A` = **Otomatik / Logon language**: Turkish when `sy-langu = 'T'`, otherwise English. `T` = **Türkçe**, `E` = **English**. Default `A` preserves the previous behavior. An explicit choice is stored in the variant and also applies in background execution.

The choice covers selection labels, date-rule choices, project-authored connection/error/row/summary messages and all ALV headings. Technical status codes remain stable; an additional status description uses the selected language. SAP GUI menus and raw SAP/BAPI/OS diagnostic text may retain the underlying system/logon language.

## Selection fields

Variants store these standard selections. No custom profile table is used.

| Field | Meaning / behavior |
|---|---|
| `P_LANG` | `A`: automatic, `T`: Türkçe, `E`: English. Stored in variants; controls report presentation and project messages. |
| `S_DATE` | Bulletin date/range; Saturdays and Sundays are skipped. |
| `P_TEST` | Default `X`; no write BAPI/commit. Reads, calculations, comparisons and exits still run. |
| `P_FXBUY` | SAP rate type for `ForexBuying`. |
| `P_FXSEL` | Rate type for `ForexSelling`. |
| `P_BNBUY` | Rate type for `BanknoteBuying`. |
| `P_BNSEL` | Rate type for `BanknoteSelling`. |
| `P_FXAVG` | Rate type for the forex buying/selling arithmetic mean; both values required. |
| `P_BNAVG` | Rate type for the banknote buying/selling mean; both values required. |
| `P_RULE` | Required date rule; initially blank. Select from the list. |
| `P_CAL` | Actual SCAL factory calendar for `NEXT_WORKDAY`. |
| `S_CURR` | Include/exclude TCMB codes. Empty evaluates all codes. |
| `P_MAP` | Example code mappings `USD=USD2; XAU=GLD`. TCMB codes have three letters, SAP codes up to five characters. |
| `P_INV` | Add TRY → foreign currency as an indirect quotation. |
| `R_UPD` / `R_KEEP` | Update/preserve different existing rates. Default Update; choose Keep initially. Equal records always return `UNCHANGED`. |
| `R_NBLOG` / `R_NBWRN` / `R_NBERR` | List/warn/error for missing weekday HTTP bulletins. Default list. |
| `R_HTTP` | Default HTTPS source. |
| `P_DEST` | Actual optional SM59 type-G destination name; host www.tcmb.gov.tr, 443, SSL, empty path prefix. |
| `P_URL` | Normally blank. Direct HTTPS is restricted to www.tcmb.gov.tr and paths under it, case-insensitive host; spaces, @, backslash, query/fragment and other hosts are rejected. Trailing slashes are removed. |
| `R_FILE` / `P_DIR` | Application-server folder; `..` is rejected. S_DATASET read authorization is checked before OPEN DATASET; internal spaces are preserved. |

At least one mapping is required. Assigning one rate type to two TCMB fields is rejected. Currency renaming changes the SAP identifier, not the currency value. Unknown SAP currencies are `SKIPPED`. Missing TCMB fields are skipped; supplied zero/negative/malformed values are parse errors.

## Dates and ratios

| Rule | Valid-from date |
|---|---|
| `SAME_DAY` | Bulletin date. |
| `NEXT_DAY` | Next calendar day. |
| `NEXT_WORKDAY` | First working day after the bulletin in the selected calendar. |

The factory calendar changes validity, not which days are downloaded. Start/end and XML dates are checked for calendar plausibility. The XML date must match the requested day.

Direct rate: `TCMB value × FFACT / (Unit × TFACT)`. The newest TCURF ratio effective on the valid-from date is used; Unit and both factors must be positive. Intermediate values use `TYPE p LENGTH 16 DECIMALS 10`; TCURR has five decimals. Overflow or rounding to zero produces `ERROR`. Ratios follow FI decisions rather than an automatically applied example.

`P_INV` has only been exercised on the S/4HANA 2023 test environment. Inverse quotation uses the same direct-pair ratio, reversing the output factors. TCURR stores an indirect quote with a negative sign; its calculated magnitude is positive. Verify direction and amounts through standard SAP readback such as `CONVERT_TO_LOCAL_CURRENCY`. The exercised environment and limits are recorded in [verification](docs/validation.md).

## Sources

HTTPS uses `YYYYMM/DDMMYYYY.xml`. Direct access selects SSL PSE `ANONYM`. SM59 uses `/kurlar/` under the destination. Verify the actual certificate chain rather than naming a fixed trusted root. HTTP 404 produces `NO_BULLETIN`; other connection/HTTP/XML failures are errors.

Files are read from `P_DIR` as `DDMMYYYY.xml`. Every missing/unauthorized/unreadable file is **`ERROR`**, not an inferred holiday. Repeated spaces within folder paths are preserved. Downloading and publishing complete files into the readable folder belong to the external staging process. There is no automatic source fallback.

The connection button checks the last seven days, independently of `S_DATE`, without writing. Preview a specific older date if only older files are staged.

## Local classes and extensions

| Object | Purpose |
|---|---|
| `LIF_TCMB`, `LCX_TCMB`, `LCL_FMT` | Shared types, errors and text formatting. |
| `LIF_SOURCE`, `LCL_SOURCE_HTTP`, `LCL_SOURCE_FILE` | Retrieve bulletins. |
| `LCL_PARSER` | XML/date/unit/positive-number/unique-code validation. |
| `LCL_DATE_RULE` | Valid-from date. |
| `LCL_CALC` | Pure calculation using supplied ratios. |
| `LCL_WRITER` | TCURR comparison, standard BAPI and per-row commit. |
| `LCL_LOADER` | Date-range orchestration. |
| `LCL_EXIT` | Empty extension methods in the source. |
| `LCL_APP` | Selection screen, ALV, job summary/errors. |

Local classes cannot be called as global classes from another report. Edit **`LCL_EXIT`** within this report or use standard report/variant execution. The old `ZCL_CHE_TCMB_LOADER` API is not provided by this edition.

`BEFORE_WRITE` may change lines before comparison; it has no test flag and must not persist data or trigger external effects. `AFTER_WRITE` receives `iv_test` and must suppress writes/notifications in test mode. Both are empty initially. **Every source update replaces LCL_EXIT; preserve custom rules separately and reapply them.** Since the flow commits, do not embed it in a LUW that expects unrelated business records to complete atomically.

## Errors and reruns

From v0.3.1, after BEFORE_WRITE and before the first database comparison/write, the writer checks each pending row's **rate type + source currency + target currency + valid-from date** key. Duplicate keys mark the day's pending rows ERROR and prevent writes for that day. Implicit mappings are included: selecting USD and EUR with EUR=USD produces a collision.

Daily results are retained by reference. If AFTER_WRITE fails, completed rows from the same day remain in the result, the error is appended, and the range stops. Unprocessed rows are marked as errors. Real-run NEW/UPDATED statuses are assigned only after a successful commit.

A range is not atomic. Writes and commits are checked per row. A BAPI failure marks `ERROR` and rolls back. Commit failure is not reported as success; reconcile OB08/SM13 before retrying. `R_KEEP` also disables the BAPI update flag; concurrently inserted rates must not be overwritten. Verify locks/races in SAP acceptance.

When a later day has a fatal source/parse failure, earlier days' results and an error row are retained, then processing stops. A failed/cancelled job does not undo prior commits. Reconcile results/spool and OB08 before retrying; have an authorized owner inspect SM13 after commit errors. Do not delete rates as a generic recovery procedure.

Exit OB08 maintenance before writing; leaving it open in another session can hold a lock. If needed, have an authorized owner inspect SM12. [Recovery steps](WALKTHROUGH.md#locks-and-partial-writes).

Test mode skips the write BAPI and commit, but does not establish real permissions, locking or persistence success. In background the summary goes to the job log, results to spool; `ERROR` cancels the job.

## Migration from the old edition

1. Preserve the existing source, custom changes, variants and job definitions in DEV.
2. Import the single source as `ZCHE_TCMB_LOAD`, replacing the previous report edition. It does not use the old custom tables/global classes.
3. Variants/jobs expecting old `P_PROF` fields are incompatible. Transfer the old profile decisions into the new fields, create new variants and test them before redirecting existing jobs.
4. Transport the report normally. Complete variant preparation/transport and connectivity/FI/permission checks in the target.

Old SAP objects/settings are not automatically deleted. SAP object deletion or package/transport cleanup is outside this change. For a separate Z report name, change `REPORT` too; rate data still goes to shared TCURR.

If the old multi-object installation is tracked by abapGit, pulling this edition can show removed files as SAP object deletions. Review these differences and dependencies in DEV; do not approve bulk deletion before deciding how to preserve old objects. Uploading the single SE38 source does not perform those deletions.

## Local checks

```sh
npm ci --ignore-scripts
npm run lint
npm run check:source
```

abaplint **2.120.92** uses `v700` with three small standard class/interface stand-ins committed to the repository. Standard type/API coverage is incomplete; lint proves neither activation nor older-release support. A supplemental scan checks selected syntax restrictions and the single-report package.

Run the 55 embedded tests in SAP. Test counts discovered locally are not execution results. [Contributing](CONTRIBUTING.md) · [Verification](docs/validation.md).

## Authorization boundaries

`LCL_LOADER->RUN` validates settings, then calls the small `CHECK_WRITE_AUTHORITY` method only when Test is false, before processing days. It uses `VIEW_AUTHORITY_CHECK` for `V_TCURR`, action U. The BAPI retains its own authorization check; this adds an early, understandable failure rather than claiming that previous BAPI writes lacked protection. The applicable group is resolved by SAP (typically FB32), not hardcoded. No additional S_EXCHRATE check is introduced.

`AUTHORITY_CHECK_DATASET`, activity READ, runs on the resolved filename before OPEN DATASET. Permission failure is a file error. These native authorization checks require runtime tests with appropriate users; pure Unit tests cover settings without changing roles. [Permissions](WALKTHROUGH.md#authorizations).

For direct HTTPS, the normalized host remains www.tcmb.gov.tr. Different hosts belong in a Basis-managed SM59 destination; the request path is /kurlar/YYYYMM/DDMMYYYY.xml. The destination is an administrator-controlled trust boundary.

Expected LCX_TCMB exceptions retain their diagnostic. Unexpected CX_ROOT exceptions include their runtime class and text; they are retained as an error row so earlier per-row commits/results remain visible.

On non-Unicode systems without a Turkish code page, choose English if Turkish text is displayed incorrectly.
