# Technical reference

> **English** | [Türkçe](TECHNICAL.tr.md) · [README](README.md) · [Installation and usage](WALKTHROUGH.md)

This reference covers fields, class usage, extension points and operational behavior. Start with the usage guide for your first installation.

## What it does

`ZCHE_TCMB_LOAD` retrieves Monday–Friday bulletins over HTTPS or from an application-server folder, maps TCMB fields to SAP rate types, applies TCURF factors, compares with TCURR and writes through the BAPI. Results include `NEW`, `UPDATED`, `UNCHANGED`, `SKIPPED`, `NO_BULLETIN` and `ERROR`, with explanations.

**Test run is selected by default.** It retrieves, calculates and compares without calling the write BAPI. It does not prove write authorization, lock handling or commit success. Custom exits still run and must respect test mode.

Rates are quoted in **TRY**. `TARGET_CURRENCY` must be blank or `TRY`; no cross rates are calculated. Optional inverse entries use indirect quotation for `TRY → foreign currency`.

## Support and prerequisites

| Area | Current position |
|---|---|
| Language | Standard ABAP for on-premise/private systems; **not an ABAP Cloud implementation**. |
| Static targets | abaplint checks 7.40 SP08 and 7.58. This does not guarantee runtime support. |
| Runtime evidence | An isolated fresh installation completed in SAP; final editor acceptance remains partial. See the [validation record](docs/validation-2026-11-02.md). |
| Installation | Single-file SE38 installer and simple settings report; abapGit is optional. No generated SM30 dialogs or profile data. |
| Connectivity | SAP application-server access to `www.tcmb.gov.tr:443`, or prepared local files. Basis must verify the actual certificate chain and STRUST PSE. |
| SAP configuration | Currencies, rate types, TCURF factors in OBBS; a factory calendar for `NEXT_WORKDAY`. |
| Permissions | Import/development and profile maintenance for setup; runtime BAPI, table and file permissions must be tested separately. |

Accounting must choose the source field, SAP rate type, validity rule and overwrite policy. The project does not determine statutory accounting or tax treatment.

## Standalone installer and settings report

`installer/zche_tcmb_install.prog.abap` is generated from `src/` and `installer/template.abap` with `npm run build:installer`, retaining the 7.40 SP08 syntax target. It embeds metadata, class/interface source and ABAP Unit includes, with no abapGit or GitHub connection at installation time. It does not create a package: supply an existing Z/Y package and your modifiable Workbench task. `$TMP` requires an empty task.

Preflight rejects existing active/inactive objects in TADIR and native catalogs. It does not update DDIC schemas. Actual installation performs CTS registration, DDIC creation/activation, OO source saving and batch activation. DDIC activation return codes are checked. Dynamic `CL_OO_FACTORY` source APIs fall back to classic `CL_OO_SOURCE` when unavailable. These internal SAP repository APIs can vary by release; local lint does not validate them. An isolated fresh installation completed; final settings-save and transport acceptance remain pending in the validation record. A partial installation is neither rolled back nor automatically resumed.

`ZCHE_TCMB_CONFIG` edits one mapping and an explicit currency list. Three-table updates use one LUW with rollback and profile-lock cleanup on failure. It checks S_TABU_NAM, SCC4 and CTS. Existing settings must be loaded first; changed profile/mapping/currency snapshots are rejected on save. Advanced profiles are not silently reduced. Transport keys are restricted to client + 20-character profile key, with a generic suffix for MAP/CURR children. Verify removal behavior on target systems during SAP acceptance too. Evaluate direct-SQL maintenance logging and your environment's audit requirements separately.

Client controls use CCCORACTIV's actual values: blank = manual recording, 1 = automatic recording, 2 = no changes, 3 = local changes only. Local saves require an empty task and state blank/3; transport saves require a task and state blank/1. Unknown states fail closed. These rules do not change SCC4 settings.

## Advanced profile maintenance

The date-rule field is CHAR12. `NEXT_WORKDAY` cannot fit classic DD07V fixed-value keys, so the domain has no truncated fixed values. The simple settings report supplies F4 choices and application validation. In advanced maintenance, enter the full rule name; `NEXT_WORKD` is invalid.

For multiple rate-type mappings, exclusions, renamed SAP currencies or custom sources, maintain the three tables through SM30. This **optional** route requires dialogs not supplied by the repository. In DEV use SE11 → Utilities → Table Maintenance Generator (or SE54 → Generated Objects → Create/Change). Select appropriate authorization groups, customer function groups, one-step screens and standard recording routines. Example groups: `ZCHE_TCMB_PROF_M`, `ZCHE_TCMB_MAP_M`, `ZCHE_TCMB_CURR_M`; select available names in your landscape. Separate groups can use screen 0001. Review the SE11 maintenance setting if disabled. Transport objects/settings normally rather than generating in production. This generation route still awaits SAP acceptance. None of it is needed for the simple settings report.

## Profile settings

All three tables are client dependent. Values below are examples; no profile data is supplied. See the [usage guide](WALKTHROUGH.md) for standalone installation and the simple settings report.

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

## Date rules

| Rule | Valid-from date |
|---|---|
| `SAME_DAY` | Bulletin date. |
| `NEXT_DAY` | Next calendar day. |
| `NEXT_WORKDAY` | Next working day in the selected factory calendar; requires a SCAL calendar. |

The program does not fetch Saturdays/Sundays. The factory calendar changes validity, not the dates fetched. A nonblank report parameter `P_RULE` overrides the profile date rule for that run.

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

## Call from your own ABAP code

This example uses the DEMO profile you created earlier; it does not create settings. It invokes the report's loading flow in **test mode**. Replace the date with a day that has a bulletin.

```abap
TRY.
    DATA(lo_loader) = NEW zcl_che_tcmb_loader( iv_profile = 'DEMO' ).
    DATA(lt_results) = lo_loader->run(
      iv_from = '20261030'
      iv_to   = '20261030'
      iv_test = abap_true ).
    " Inspect every result STATUS and MESSAGE before using the results.
  CATCH zcx_che_tcmb INTO DATA(lx_error).
    DATA(lv_error) = lx_error->get_text( ).
    " Handle the configuration or loading error in your application.
ENDTRY.
```

Place this inside a report execution block or a method. `iv_test = abap_false` enables real writes and commits. Not every failure is raised as an exception by `run`; also inspect `ERROR`, `SKIPPED` and `NO_BULLETIN` in `lt_results`. This flow commits internally: do not embed it in an LUW that must remain atomic with other business writes.

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
npm run build:installer
npm run check:installer
npm run lint
npm run test:logic
```

`npm run lint:740` and `npm run lint:758` run the targets separately. The runner fetches fixed-revision SAP stubs into ignored `.abaplint-deps/`; npm tooling is locked. GitHub Actions runs the same checks. Incomplete dependency stubs cannot replace SAP activation, ATC, ABAP Unit or integration tests.

`test:logic` transpiles selected calculator, configuration-rule, runner and writer tests to JavaScript with simplified DDIC stubs and a fake persistence boundary. It uses pinned transpiler/runtime dependencies and an exact `open-abap-core` revision. It does not establish SAP activation, BAPI/database/commit behavior, authorizations, factory calendars, input integration or exact SAP decimal/overflow semantics.

**Historical evidence:** the revision exported on 1 November 2026 was reported to pass 26 tests on ABAP Platform 2023, with real USD/EUR/JPY writes/readback, inverse quotation, file input and background jobs. These results **do not validate subsequent changes**. Fresh installation, restricted users, SM59, maintenance-dialog generation and older releases remain acceptance tasks.

See [CONTRIBUTING.md](CONTRIBUTING.md), [CHANGELOG.md](CHANGELOG.md) and the unpublished [SAP Community author outline](docs/sap-community-draft.md).

## License

MIT. See [LICENSE](LICENSE). Copyright (c) 2026 Ali Emre Altuntaş.
