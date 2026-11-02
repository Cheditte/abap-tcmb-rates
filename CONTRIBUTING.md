# Contributing

Keep installation to one SE38 report and preserve the ABAP 7.00 syntax target. Add no mandatory custom DDIC/global objects. Follow existing classic syntax even where newer ABAP would be shorter.

## Local checks

Node.js 22+:

```sh
npm ci --ignore-scripts
npm run lint
npm run check:source
```

abaplint 2.120.92 targets v700. The three `.abaplint-deps/` stand-ins support local checking and are not installed in SAP. Standard API coverage is incomplete. CI runs static checks; the 55 embedded Unit tests run in SAP.

## Change checklist

- Use explicit declarations, CREATE OBJECT, CONCATENATE and CL_AUNIT_ASSERT; avoid inline/constructor/string-template/new SQL syntax, pragmas and nested functional calls. Use `"#AU` comments for legacy tests.
- Add focused harmless regression tests for changed parser, settings, date and calculation behavior; avoid real writes/external calls in Unit tests.
- Keep source and optional abapGit metadata consistent. Update EN/TR guides and [verification](docs/validation.md).
- Keep message-key/parameter parity across languages. Restore language state after each test; technical status codes remain stable.
- Sanitize screenshots before committing: no usernames, system identifiers, transport/job numbers or private/business data.

<a id="sap-acceptance-checklist"></a>
## SAP acceptance checklist

Use an authorized DEV/test system and record revision, SAP release, date and results in the verification table.

- Activate the complete source with fixed-point arithmetic enabled; run all 55 native tests.
- Check English/Turkish labels, date/language listboxes, connection button, result columns and messages.
- Preview a limited day/period through HTTPS. Reject invalid direct URLs and parent-folder paths on the selection screen.
- Test server files, S_DATASET failure and repeated spaces in folders.
- Test actual writes with and without V_TCURR authorization. The preflight should fail once before processing; the BAPI retains its own checks.
- Verify actual writes, factors, direct/inverse conversion and equal UNCHANGED reruns through OB08/standard SAP conversion.
- Exercise Keep/Update, locks, partial ranges and BAPI/commit failures. Earlier successful commits remain stored.
- Save/reload variants, set S_DATE to dynamic current date and run a preview job. Inspect selected-language log/spool and runtime-user permissions.
- Verify actual 7.00/7.01/7.02 systems before claiming runtime support.
- Preserve/reapply custom LCL_EXIT code; ensure it respects test-mode side effects.

## Reporting an issue

Include the report revision, SAP release, sanitized selections, exact messages and whether Test was checked. Explain expected rate/factors/date and the observed result. Keep credentials and production data out of public issues.
