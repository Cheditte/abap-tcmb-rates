# Transpiled logic tests

Run from the repository root after `npm ci`:

```sh
npm run test:logic
```

This runs the existing ABAP test methods after transpiling them to JavaScript.
The current suite has 39 methods: 15 calculator, 10 runner and 14 writer tests.
The script checks that the number of reported executions matches the number of
test methods in the copied production test includes.

## Source selection and isolation

The harness copies the following production objects and their metadata/test
includes without editing their contents:

- `ZIF_CHE_TCMB`
- `ZIF_CHE_TCMB_RATE_STORE`
- `ZIF_CHE_TCMB_DAY_LOADER`
- `ZCL_CHE_TCMB_WRITER`
- `ZCL_CHE_TCMB_CALC`
- `ZCL_CHE_TCMB_RUNNER`
- `ZCX_CHE_TCMB`

It also copies the custom `ZCHE_*` domain, data element and table XML files, and
the metadata of `ZCL_CHE_TCMB_RATE_STORE`. It never copies that class's production
implementation. The implementation in `stubs/` contains only failing assertions:
every store method executes `ASSERT 1 = 2`. Writer tests must inject their local
in-memory fake. A passing run therefore cannot have called the default store,
real database persistence or a real SAP BAPI.

The other eight fixture files supply simplified standard DDIC definitions for
`BAPI1093_0`, `TCURR`, `TCURF`, `KURST_CURR`, `SEOCLSNAME`, `WFCID` and `XFELD`.
These fixtures are for this harness only and are outside the installable `src/`
directory. They are not exports of an installed SAP system.

## Reproducibility and evidence

The npm manifest and lockfile pin `@abaplint/transpiler-cli` and
`@abaplint/runtime` to `2.14.15`. The transpiler configuration pins the assertion
and standard-library implementation from `open-abap/open-abap-core` to
`f735eed652288c8ed85b3083a187cc3e7e4a9b97`. The script checks the configured
revision and the actual clone revision reported by the transpiler. Building
requires Git and network access to that repository.

Each invocation creates a fresh ignored `.logic-tests/runs/run-*` directory.
There is no recursive cleanup. The path is printed at startup and contains:

- `source-manifest.json`: SHA-256 hashes of the copied production sources;
- `transpile.log`: build output, including the pinned library revision;
- `runtime.log`: the test methods actually executed;
- `src/`, `abap_transpile.json` and `output/`: the inputs and generated code for
  that run.

## Validation limits

This is JavaScript execution of transpiled logic, not SAP ABAP Unit execution.
JavaScript numeric precision, rounding and overflow behavior do not establish
parity with SAP packed decimals or `DECFLOAT34`. The DDIC fixtures also do not
validate the actual SAP dictionary definitions or object activation.

The harness does not exercise iXML parsing, HTTP access, operating-system file
permissions, factory calendars, SAP authorization, real BAPIs or database commit
behavior. Those still require SAP ABAP Unit and the documented SAP acceptance
checks.
