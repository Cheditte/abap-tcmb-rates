# Contributing

This is a pre-release single-report ABAP project. Keep setup to one SE38 source file, avoid new custom DDIC/global objects, and preserve the ABAP 7.00 syntax target. Follow the existing architecture and keep financial behavior explicit.

## Local checks

Node.js 22+:

```sh
npm ci --ignore-scripts
npm run lint
npm run check:source
```

abaplint 2.120.92 runs in `v700` mode. The three `.abaplint-deps/` stand-ins are local checker inputs, never SAP installation objects. Incomplete standard SAP definitions limit type/API coverage. The supplemental scanner catches selected newer constructs, packaging errors and lines over 255 characters; it does not prove 7.00 compatibility.

There is no generated installer or JavaScript logic-test command. An attempted whole-report transpilation could not resolve selection-screen/ALV/legacy test dependencies. The 48 tests are embedded SAP Unit tests, not tests executed by CI.

## Making a change

1. Describe a concrete failing input and expected behavior. Keep the source and optional report XML consistent.
2. Add meaningful embedded regression tests for parser/date/calculation/configuration changes. Keep harmless tests free of business-table writes and external calls. Do not use 7.02+ syntax in tests.
3. Avoid inline declarations, constructor expressions, string templates, chained/nested calls, new Open SQL, `WITH EMPTY KEY`, pragmas, `DECFLOAT34`, `CL_ABAP_UNIT_ASSERT` and test risk/duration additions. Use `CL_AUNIT_ASSERT` and `"#AU` comments. Review manually as well as linting.
4. Run local checks, then applicable SAP acceptance on the exact source hash. A discovered test count is not a passing test result.
5. Update both languages, diagrams and the validation record. Do not present handoff reports or an older revision's results as fresh observations.

For localization changes, preserve `P_LANG` values `A` (Otomatik / Logon language), `T` (Türkçe) and `E` (English), and keep technical status codes unchanged. Cover both explicit languages independently of the test user's logon language. Reset mutable language state between tests. Retain raw SAP/BAPI/OS diagnostics while translating project-authored context; never imply that the report changes SAP GUI menus or system message language.

## SAP acceptance checklist

Use an authorized DEV/test system with limited dates/currencies. Record source SHA-256, SAP_BASIS release/SP, kernel and configuration. Redact user names, system identifiers, transport numbers and private/business data from shared screenshots. Diagrams must be identified as illustrations rather than actual SAP evidence.

- [ ] Create `ZCHE_TCMB_LOAD` by copy/paste and by file upload in a clean test context. Verify fixed-point arithmetic, long-line settings, syntax and activation; run all 48 embedded tests.
- [ ] Open the actual selection screen. From an English logon, select Türkçe in `P_LANG` without logging out, then switch back to English. Check refreshed labels/date choices, connection/error/row/summary messages, all ALV headings and localized status descriptions. Technical status codes must remain unchanged. Check `SELECTION_TEXTS_MODIFY`/`VRM_SET_VALUES`, including background initialization.
- [ ] Run on an actual 7.00/7.01/7.02 system before claiming support. Check `CL_HTTP_CLIENT`, iXML, SALV, date/calendar functions, text/listbox APIs and BAPI interfaces.
- [ ] Save/reload variants with explicit `T` and `E` language choices. Check `A` follows Turkish logon with Turkish and other logons with English. Test dynamic current-date selection with SM36, including a background user with a different logon language; verify selected-language job log/spool, warnings and cancellation. Rebuild old `P_PROF` variants rather than reusing them.
- [ ] Test direct HTTPS and an SM59 type-G destination. Verify the current TLS chain and exercise HTTP/connection/malformed XML/date-mismatch failures.
- [ ] Test server files: valid, missing, unreadable, incomplete and malformed XML, including repeated spaces in the folder. File-open failures must be `ERROR`, never an inferred holiday.
- [ ] Reject malformed/duplicate currency codes, impossible dates, absent/fractional/nonpositive Units, invalid/nonpositive supplied values, zero factors and non-TRY targets without writing.
- [ ] Preview USD/JPY with actual OBBS factors, inclusion/exclusion/renaming, missing source fields and missing SAP currency definitions. Verify Test run does not call write BAPI or commit.
- [ ] Verify `SAME_DAY`, month/year boundaries and `NEXT_WORKDAY` with a real factory calendar and holiday cases. Check all missing-HTTP-bulletin policies.
- [ ] Perform limited real writes; inspect OB08 and standard currency-conversion readback for direct/inverse quotations, factors and valid-from dates. Equal reruns must be `UNCHANGED`.
- [ ] Test Keep/Update against different existing rates, concurrent inserts, locks, restricted users, BAPI failure and commit failure. Confirm failures never appear as successful writes; reconcile SM13 before retry.
- [ ] Fail a later source day after earlier successful commits. Earlier result rows must remain visible, later days must stop, and earlier records must remain stored.
- [ ] Test custom `LCL_EXIT` code in both modes. `BEFORE_WRITE` must not have external effects; `AFTER_WRITE` must respect `iv_test`.
- [ ] Optional abapGit installation imports report attributes/texts correctly and creates no obsolete custom DDIC/global objects.

## Reporting evidence

Include the exact source hash, release, sanitized selections, source sample, messages, expected conversion and whether rates were actually written. The current [validation record](docs/validation-v0.3.0.md) distinguishes reported handoff results from local checks and outstanding SAP execution. Do not paste credentials or production dumps into issues.
