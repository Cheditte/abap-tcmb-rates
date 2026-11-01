# abap-tcmb-rates

> **English** | [Türkçe](README.tr.md)

Load TCMB daily exchange-rate bulletins into SAP using ABAP, configurable profiles and `BAPI_EXCHANGERATE_CREATE`.

For ABAP developers and SAP FI teams who need a repeatable way to load TCMB rates. Configure currencies, rate types and validity rules in profiles, review a dry run, then schedule the approved load as a SAP job. The built-in HTTPS source runs within SAP; a file source is available for systems without outbound access.

**Getting started:** [install in DEV](#install-in-development), [create a small profile](#create-a-small-first-profile), then follow the [first-run guide](#safe-first-run). Source code is MIT licensed; feedback and reproducible test results are welcome.

**Pre-release: v0.1.** Start in a development or sandbox system. This revision contains changes that have **not been executed in SAP**. A previous revision was tested on an SAP ABAP Platform 2023 trial. Fresh installation and maintenance-dialog generation still need acceptance testing.

## What it does

`ZCHE_TCMB_LOAD` retrieves Monday–Friday bulletins over HTTPS or from an application-server folder, maps TCMB fields to SAP rate types, applies TCURF factors, compares with TCURR and writes through the BAPI. Results include `NEW`, `UPDATED`, `UNCHANGED`, `SKIPPED`, `NO_BULLETIN` and `ERROR`, with explanations.

**Test run is selected by default.** It retrieves, calculates and compares without calling the write BAPI. It does not prove write authorization, lock handling or commit success. Custom exits still run and must respect test mode.

Rates are quoted in **TRY**. `TARGET_CURRENCY` must be blank or `TRY`; no cross rates are calculated. Optional inverse entries use indirect quotation for `TRY → foreign currency`.

## Support and prerequisites

| Area | Current position |
|---|---|
| Language | Standard ABAP for on-premise/private systems; **not an ABAP Cloud implementation**. |
| Static targets | abaplint checks 7.40 SP08 and 7.58. This does not guarantee runtime support. |
| Runtime evidence | Historical ABAP Platform 2023 tests only; current changes await SAP validation. |
| Installation | abapGit objects in `src/`; no generated SM30 dialogs or profile data. |
| Connectivity | SAP application-server access to `www.tcmb.gov.tr:443`, or prepared local files. Basis must verify the actual certificate chain and STRUST PSE. |
| SAP configuration | Currencies, rate types, TCURF factors in OBBS; a factory calendar for `NEXT_WORKDAY`. |
| Permissions | Import/development and profile maintenance for setup; runtime BAPI, table and file permissions must be tested separately. |

Accounting must choose the source field, SAP rate type, validity rule and overwrite policy. The project does not determine statutory accounting or tax treatment.

## Install in development

1. Install [abapGit](https://docs.abapgit.org/user-guide/getting-started/install) if needed. Create a dedicated package such as `ZCHE_TCMB` with your landscape's transport settings.
2. Create an online repository for `https://github.com/Cheditte/abap-tcmb-rates` and pull into that package. Offline: create an offline repository, import the repository ZIP and use **Pull zip**.
3. Activate the imported objects and resolve errors before continuing. The static version target does not guarantee every SAP dependency exists.
4. Run all package ABAP Unit tests and your system's ATC checks, then complete the [SAP acceptance checklist](CONTRIBUTING.md#sap-acceptance-checklist).

### One-time SM30 setup

The configuration tables are supplied; **their generated table-maintenance dialogs are not**. An authorized developer must generate them in DEV:

1. In **SE54**, enter each table below, select **Generated Objects → Create/Change**. SE11 → Utilities → Table Maintenance Generator is an alternative.
2. Assign a suitable authorization group, customer function group, one-step overview screen and standard recording routine. Example groups: `ZCHE_TCMB_PROF_M`, `ZCHE_TCMB_MAP_M`, `ZCHE_TCMB_CURR_M`; separate groups can each use screen `0001`. Check name availability.
3. Generate and save in a transportable customer package. Review the SE11 maintenance setting if maintenance is disabled.
4. Transport the generated objects and configuration through your normal landscape; use **SM30** in the intended client. Do not generate directly in production.

See SAP's [maintenance-dialog procedure](https://help.sap.com/docs/SAP_NETWEAVER_AS_ABAP_FOR_SOH_740/c0d47b1c53ee451f847c21d4ba5be6e6/48d59095982b424be10000000a421937.html). This setup path remains untested for this revision.

## Create a small first profile

After generating the dialogs, use SM30. All tables are client dependent. Create the profile first, then its mapping and currency rows.

**`ZCHE_TCMB_PROF`: one profile**

| Field | First-run value or meaning |
|---|---|
| `PROFILE` | `DEMO` |
| `DESCRIPTION` | Your description |
| `DATE_RULE` | `SAME_DAY` for this example; confirm with accounting |
| `FACTORY_CALENDAR` | Blank unless `NEXT_WORKDAY`; select a calendar configured in SCAL |
| `TARGET_CURRENCY` | `TRY` or blank |
| `WRITE_INVERSE` | Blank initially; `X` adds inverse entries |
| `EXISTING_RATE` | `S` initially preserves different existing rates; `U` or blank permits updates |
| `NO_BULLETIN` | `I`: result only; `W`: warning; `E`: error |
| `SOURCE_CLASS` | Blank for HTTPS; `ZCL_CHE_TCMB_SOURCE_FILE` for files |
| `RFC_DESTINATION` | Optional SM59 HTTP destination: TCMB host, 443, SSL, no path prefix |
| `BASE_URL` | Normally blank; custom bulletin base URL without an SM59 destination |
| `FILE_FOLDER` | Required for file source; application-server folder |
| `EXIT_CLASS` | Blank initially |

**`ZCHE_TCMB_MAP`: one example mapping**

| `PROFILE` | `RATE_TYPE` | `SOURCE` |
|---|---|---|
| `DEMO` | `M` | `FX_BUY` |

This is an example, not an accounting recommendation. One TCMB field is allowed per profile/rate type; the same source can feed several rate types.

**`ZCHE_TCMB_CURR`: limit the first run**

| `PROFILE` | `TCMB_CODE` | `SAP_CURRENCY` | `EXCLUDE` |
|---|---|---|---|
| `DEMO` | `USD` | blank | blank |
| `DEMO` | `JPY` | blank | blank |

Prepare the corresponding TCURF factors first. Rows with `EXCLUDE` blank form an inclusion list; `X` rows exclude currencies. Without inclusion rows, all non-excluded bulletin currencies are considered. `SAP_CURRENCY` maps a foreign code to its local SAP equivalent; it does not convert the quote into another currency.

## Safe first run

1. Open `ZCHE_TCMB_LOAD` with `DEMO` in the test client. **Test the connection to TCMB** retrieves a recent bulletin using the configured source, including file input.
2. Select one historical weekday with a known bulletin; keep **Test run** selected. Check bulletin date, `VALID_FROM`, currencies, rate type, factors and messages. Include JPY to check TCMB's unit of 100 against SAP factors.
3. Resolve unexpected `ERROR` and `SKIPPED` results. Compare expected conversion amounts against XML and SAP configuration.
4. In the sandbox, clear **Test run** and execute once. Inspect OB08 and verify with SAP currency conversion. Repeat the same run: successfully stored equal values should be `UNCHANGED`.
5. After acceptance and transport, schedule an approved SM36 variant, normally after TCMB publication, with the date as a current-date selection variable. Confirm the job's time zone and monitor SM37, job log and spool.

The program skips Saturdays and Sundays. A weekday without an HTTP bulletin can be `NO_BULLETIN`; the profile determines warning/error handling. The factory calendar changes the valid-from date, not which weekdays are fetched.

| Date rule | Meaning |
|---|---|
| `SAME_DAY` | Bulletin date |
| `NEXT_DAY` | Next calendar day |
| `NEXT_WORKDAY` | Next working day in the configured factory calendar |

## TCMB fields

| `SOURCE` | XML value |
|---|---|
| `FX_BUY` | `ForexBuying` |
| `FX_SELL` | `ForexSelling` |
| `BN_BUY` | `BanknoteBuying` |
| `BN_SELL` | `BanknoteSelling` |
| `FX_AVG` | Mean of forex buying and selling |
| `BN_AVG` | Mean of banknote buying and selling |

Missing values produce `SKIPPED`; for example XDR may have no selling or banknote rates. Averages require both values. Choose rate types configured in your system.

## File source and troubleshooting

Set `SOURCE_CLASS = ZCL_CHE_TCMB_SOURCE_FILE` and an application-server `FILE_FOLDER`. Stage each complete XML as `DDMMYYYY.xml`, for example `30102026.xml`, before selecting that date. The XML date must match the requested date. Downloading and atomically staging files is an external responsibility; no downloader is installed.

**Changed behavior:** any file-open failure, including a missing file, is an `ERROR`. A missing file cannot reliably distinguish an unpublished bulletin from transfer/access failure. Prepare the selected files and choose the range accordingly. A custom source can explicitly raise `NO_BULLETIN` when it can establish that condition.

| Symptom | Next check |
|---|---|
| TLS/SSL failure | Basis: actual certificate chain, STRUST PSE, SM59 SSL and proxy settings |
| Connection failure | Network team: application-server routing, firewall, proxy |
| HTTP destination failure | Basis: destination host, SSL and path |
| File error | File presence/content, OS permissions and SAP file authorization |
| TCURF error | FI team: pair, rate type, factors and effective date in OBBS |

## Errors, partial writes and reruns

**A range is not one atomic transaction.** Earlier successful writes may be committed before a later line/day fails. A failed or cancelled job does not undo those commits. Review results, spool and OB08 before retrying. Fatal source/parse errors stop further dates while preserving earlier results and an error row.

Fix the cause, then test-run the affected range. Equal records are `UNCHANGED`. `EXISTING_RATE = S` preserves different existing entries as `SKIPPED`; `U` or blank allows replacement. Use `U` only when overwriting is intended. Reconcile a commit error against stored rates before retrying. Do not delete rates as a general recovery step.

For commit failures, ask Basis to inspect failed or pending updates in **SM13** before retrying or reprocessing an update request.

## Architecture and extensions

| Object | Responsibility |
|---|---|
| `ZCHE_TCMB_LOAD` | Selection, results and job outcome |
| `ZCL_CHE_TCMB_LOADER` | Profiles, dates and orchestration |
| `ZCL_CHE_TCMB_RUNNER` | Date-range iteration and retained results after fatal errors |
| `ZCL_CHE_TCMB_SOURCE_HTTP`, `_FILE` | Retrieval |
| `ZCL_CHE_TCMB_PARSER` | XML parsing and validation |
| `ZCL_CHE_TCMB_DATE_RULE` | Valid-from calculation |
| `ZCL_CHE_TCMB_CALC` | Calculation without database access |
| `ZCL_CHE_TCMB_WRITER` | TCURR comparison and BAPI writes |
| `ZCL_CHE_TCMB_RATE_STORE` | SAP persistence adapter used by the writer |

Custom sources implement `ZIF_CHE_TCMB_SOURCE`. Custom exits implement `ZIF_CHE_TCMB_EXIT`: `BEFORE_WRITE` can change lines; `AFTER_WRITE` receives results and the test flag. `BEFORE_WRITE` has no test flag: keep it pure and only mutate the supplied lines. `AFTER_WRITE` receives `iv_test` and must suppress writes/external side effects during test runs. Validate extensions in SAP before use.

## Validation and contributing

Install Node.js 22+ and Git, then:

```sh
npm ci --ignore-scripts
npm run lint
npm run test:logic
```

`npm run lint:740` and `npm run lint:758` run the targets separately. The runner fetches fixed-revision SAP stubs into ignored `.abaplint-deps/`; npm tooling is locked. GitHub Actions runs the same checks. Incomplete dependency stubs cannot replace SAP activation, ATC, ABAP Unit or integration tests.

`test:logic` transpiles selected calculator, runner and writer tests to JavaScript with simplified DDIC stubs and a fake persistence boundary. It uses pinned transpiler/runtime dependencies and an exact `open-abap-core` revision. It does not establish SAP activation, BAPI/database/commit behavior, authorizations, factory calendars, input integration or exact SAP decimal/overflow semantics.

**Historical evidence:** the revision exported on 1 November 2026 was reported to pass 26 tests on ABAP Platform 2023, with real USD/EUR/JPY writes/readback, inverse quotation, file input and background jobs. These results **do not validate subsequent changes**. Fresh installation, restricted users, SM59, maintenance-dialog generation and older releases remain acceptance tasks.

See [CONTRIBUTING.md](CONTRIBUTING.md), [CHANGELOG.md](CHANGELOG.md) and the unpublished [SAP Community author outline](docs/sap-community-draft.md).

## License

MIT. See [LICENSE](LICENSE). Copyright (c) 2026 Ali Emre Altuntaş.
