# Contributing

Bug reports, focused pull requests and SAP acceptance results are welcome. The project is pre-release. Keep financial behavior explicit: quote units, factors, quotation direction, validity dates and overwrite choices are part of correctness.

## Local checks

Requirements: Node.js 22+, npm and Git. From the repository root:

```sh
npm ci --ignore-scripts
npm run lint
npm run test:logic
```

Use `npm run lint:740` or `npm run lint:758` for an individual target. Both use `@abaplint/cli` **2.120.92** and SAP dependency stubs from `abaplint/deps` commit **17aab021807da9249c9a20b9ce785de6be6d258e**. The first run needs network access to fetch the stubs. Later runs verify the ignored `.abaplint-deps/` checkout's revision and cleanliness. If a fetch was interrupted or the generated checkout changed, move that directory aside and rerun. The runner does not reset or delete an existing checkout.

GitHub Actions runs the same commands with a read-only repository token. Static checks use incomplete SAP dependency definitions and relaxed checking outside customer namespaces. They do not execute ABAP or verify SAP API availability, authorizations, locks or database commits.

`test:logic` runs selected unchanged calculator, runner and writer test sources after transpilation to JavaScript. It uses simplified DDIC definitions and a fake persistence boundary; the default store fails if accidentally called by the harness. Tooling pins `@abaplint/transpiler-cli` and `@abaplint/runtime` to **2.14.15**, and `open-abap-core` to **f735eed652288c8ed85b3083a187cc3e7e4a9b97**. Generated files stay in ignored `.logic-tests/`. This is a local logic regression check, not SAP ABAP Unit execution. It does not validate SAP activation, real BAPI/database/commit behavior, authorizations, factory calendars, XML/file/HTTP integration or exact SAP decimal/overflow semantics.

Update the CLI lockfile and dependency SHA deliberately when upgrading tooling. Keep the two lint configurations equivalent except for the syntax target. Do not add a rule just to create an unrelated formatting rewrite.

## Making a change

1. Describe a concrete failing input or operational problem. State the expected result and affected SAP release.
2. Keep changes focused. Add ABAP Unit regression coverage for changed calculation, validation and error behavior. Use dependency boundaries for database/BAPI orchestration rather than touching real exchange rates in unit tests.
3. Export SAP objects with abapGit when available. If editing serialized source locally, disclose that it has not yet been imported or executed in SAP.
4. Run local checks, then perform the applicable SAP acceptance checks below. Record what passed, failed or was unavailable; a test count is not evidence that those tests ran.
5. Update both READMEs and the unreleased changelog when user-visible behavior changes.

## SAP acceptance checklist

Run this in an authorized DEV/test client with a dedicated profile and limited currencies. Record the exact Git commit, SAP_BASIS release/SP, kernel, abapGit version, client, source type and tested configuration. Redact internal hosts, credentials and business data from shared evidence.

- [ ] Import into a clean package with abapGit; verify DDIC dependencies, activation and all test classes. Run ATC and the complete package ABAP Unit suite. Record results for the current commit.
- [ ] Generate and transport the three table-maintenance dialogs following the [usage guide](WALKTHROUGH.md#12-generate-the-settings-screens-once). Create the `DEMO` profile, mapping and USD/JPY inclusion rows through SM30. Confirm client isolation and restricted maintenance authorization.
- [ ] Test HTTPS directly and through an SM59 destination when supported by the environment. Verify the actual TLS trust chain. Exercise connection failure, HTTP error, malformed XML and bulletin-date mismatch.
- [ ] Test file input with a valid file, missing file, unreadable file, invalid XML and a folder containing spaces. File-open failures must be `ERROR`, not an inferred holiday.
- [ ] Confirm invalid dates, units, numeric values, duplicate currencies, unsupported targets and invalid profile choices are rejected without writing rates.
- [ ] Verify `SAME_DAY`, month/year boundaries and `NEXT_WORKDAY` across weekends/holidays using a real configured calendar. Check `NO_BULLETIN` policies `I`, `W` and `E` for HTTP/custom sources.
- [ ] Dry-run USD and JPY with expected unit/factor values, missing TCURF configuration, missing TCMB values, currency inclusion/exclusion and renamed SAP currency codes. Confirm that no BAPI write occurs.
- [ ] Perform controlled real writes for direct and inverse quotation. Read back through SAP currency-conversion functions and OB08; verify amounts, factors and valid-from dates. A dry run does not satisfy this item.
- [ ] Repeat a successful run for `UNCHANGED`. Test different existing entries under both `S` (preserve) and `U` (update). Exercise a restricted runtime user, lock failure, failed write and commit failure using a suitable controlled test setup.
- [ ] Trigger a later-day source failure after an earlier successful day. Verify earlier results remain visible, later dates stop, prior commits remain, and recovery by test-run/retry behaves as documented.
- [ ] Test foreground results and a background job: summary, spool, warning policy and cancelled status on errors. Reconcile stored rates after a failed job.
- [ ] If using exits, verify test-mode behavior, changed lines and errors before and after writing. `BEFORE_WRITE` has no test flag and should only mutate supplied lines; `AFTER_WRITE` receives `iv_test` and must suppress side effects in test mode.

## Reporting and release evidence

For a bug report include the commit, SAP release, sanitized profile/mapping, source sample, result message, expected conversion and whether rates were actually written. Do not paste credentials or production dumps into an issue.

A release should state the SAP versions actually tested and outstanding acceptance items. The historical Platform 2023 run cannot certify later revisions or older releases. Review [the Community draft](docs/sap-community-draft.md) only after acceptance evidence and repository access are ready; it is not a publication action.
