# SAP Community author outline: TCMB exchange rates in standard ABAP

**Status: unpublished editorial outline and technical fact pack.** This is material for the author to build on in their own voice, not a ready-to-paste article. The repository is public; no Community post has been published.

SAP Community allows AI assistance with planning and structure but excludes primarily AI-written posts. The author must contribute their own explanation, verified experience and wording. If AI meaningfully shapes the final text, use the **GenAI Assisted Content** label or the suggested disclosure: “This post was assisted by GenAI.” Review the [official guidelines](https://community.sap.com/t5/welcome-corner-knowledge-base/guidelines-for-content-created-with-generative-ai/ta-p/14238551) before publishing.

## Publication prerequisites

- Repository access: source is public at `https://github.com/Cheditte/abap-tcmb-rates`. Link the exact revision used in the demonstration so readers can reproduce it.
- Current revision: run the [SAP acceptance checklist](../CONTRIBUTING.md#sap-acceptance-checklist) for the exact commit and record SAP_BASIS/SP, kernel, abapGit, activation, ATC and test results.
- Evidence: capture sanitized screenshots of profile setup, dry-run output, controlled real write, repeat-run results and SAP conversion readback. Use real screenshots and measured amounts.
- Scope: explicitly describe a pre-release standard-ABAP project. Static 7.40 SP08/7.58 targets do not establish runtime support. This is not an ABAP Cloud implementation.
- Experience: identify which design and test observations the author personally made. Attribute historical reports separately; do not turn them into first-person experience.

## Suggested title

**Loading TCMB exchange rates into SAP: profiles, factors and safe reruns in ABAP**

Alternative: **A configurable standard-ABAP loader for TCMB daily exchange rates**

## 1. Explain the problem from actual experience

Author prompts:

- Which process needed the rates, and which part was difficult to maintain?
- What concrete requirements led to ABAP retrieval, configurable mappings and a file fallback?
- Which alternatives were considered in that environment? Avoid claims that no SAP or third-party connector exists.

Technical facts:

- Input is a dated TCMB XML bulletin, obtained by HTTPS or from the SAP application server.
- Output is a SAP exchange-rate entry through `BAPI_EXCHANGERATE_CREATE`.
- Accounting chooses source field, rate type and valid-from rule; the tool does not select statutory accounting/tax policy.

## 2. Walk through the architecture

Use the following sequence to draw or explain the actual flow:

`ZCHE_TCMB_LOAD → LOADER → RUNNER → day load: SOURCE_HTTP / SOURCE_FILE → PARSER → DATE_RULE + CALC → WRITER → RATE_STORE → BAPI`

Supporting configuration:

| Table | Role |
|---|---|
| `ZCHE_TCMB_PROF` | Source, dates, target, overwrite/no-bulletin policies, optional exits |
| `ZCHE_TCMB_MAP` | TCMB source field to SAP rate type |
| `ZCHE_TCMB_CURR` | Currency inclusion/exclusion and local SAP code mapping |

Useful author discussion points: pure calculation from supplied factors; source abstraction; BAPI-backed persistence; how the boundaries helped reproduce a bug. Add a specific example from the author's own tests.

## 3. Show why units, factors and dates matter

Example to verify in the author's SAP system:

- Include USD and JPY in a small test profile, with target blank/TRY.
- Inspect the JPY XML `Unit` and TCURF factors together. Do not copy a historical exchange amount into a current example.
- Show direct quotation and, if tested, the optional indirect `TRY → foreign` record.
- Read a controlled amount back with SAP currency conversion and compare the result to the bulletin.

Date-rule facts:

| Rule | Validity date |
|---|---|
| `SAME_DAY` | Bulletin date |
| `NEXT_DAY` | Following calendar day |
| `NEXT_WORKDAY` | Next working day in the configured factory calendar |

Clarify that the factory calendar changes validity, while source retrieval considers Monday–Friday. No cross rates are calculated; `TARGET_CURRENCY` is limited to blank/TRY.

## 4. Demonstrate installation and a safe first run

Author evidence to add:

1. Exact commit imported into a clean DEV package using abapGit; show activation and test evidence.
2. One-time SE54 maintenance-dialog generation and normal transport. The repository does not include generated SM30 dialogs or ready-made profile data.
3. A `DEMO` profile restricted to USD/JPY; explain its mapping as an example, not an accounting recommendation.
4. Dry-run result showing dates, factors and statuses; explain that the BAPI is not called in test mode.
5. Controlled real write in a sandbox, OB08/conversion readback, then `UNCHANGED` on a repeat run.

The README contains the concrete setup sequence. Describe only steps the author has actually completed; list the rest as limitations.

## 5. Explain failure handling and recovery

Facts worth illustrating with an actual failure test:

- A range is not atomic: earlier successful commits remain if a later line/day fails.
- Fatal source/parse failure stops later dates and preserves earlier results plus an error row.
- `EXISTING_RATE = S` keeps different existing entries; `U` allows replacement. Equal stored values are `UNCHANGED`.
- Missing/unreadable local files are errors. A missing file does not establish that TCMB published no bulletin.
- Dry runs cannot validate BAPI authorizations, locks or commits. Custom `BEFORE_WRITE` should only mutate supplied lines; `AFTER_WRITE` receives the test flag and must suppress side effects during tests.

Add one sanitized error/result screenshot and the measured recovery outcome from the test system.

## 6. State validation honestly

Use an evidence table completed by the author:

| Check | Commit / environment | Actual outcome |
|---|---|---|
| Fresh abapGit installation and activation | To fill after execution | Pending |
| ATC and complete ABAP Unit suite | To fill after execution | Pending |
| Direct/inverse real write and SAP readback | To fill after execution | Pending |
| Restricted user, locks and failed commits | To fill after execution | Pending |
| Background job and later-day failure recovery | To fill after execution | Pending |
| Local static checks | Pinned tooling, 7.40 SP08 and 7.58 targets | Record current run |
| Transpiled local logic tests | JavaScript, DDIC stubs and fake persistence | 39 passed locally on 2 November 2026; JavaScript emulation, not SAP execution. Rerun for the publication commit. |

Historical context only: an earlier revision was reported to pass 26 ABAP Unit tests and end-to-end checks on an ABAP Platform 2023 trial on 1 November 2026. That report does not certify the changed revision or older releases.

## 7. Invite focused feedback

Ask for evidence that helps development: SAP release/SP, exact commit, sanitized configuration/input, expected conversion and actual result. Useful areas include clean installation, maintenance workflow, restricted runtime users and recovery behavior.

Reference links for the author:

- [Project repository](https://github.com/Cheditte/abap-tcmb-rates) — check reader access before publication.
- [English README](../README.md), [Turkish README](../README.tr.md), [contribution and acceptance guidance](../CONTRIBUTING.md).
- [SAP maintenance-dialog documentation](https://help.sap.com/docs/SAP_NETWEAVER_AS_ABAP_FOR_SOH_740/c0d47b1c53ee451f847c21d4ba5be6e6/48d59095982b424be10000000a421937.html).
- [SAP Community generative-AI guidelines](https://community.sap.com/t5/welcome-corner-knowledge-base/guidelines-for-content-created-with-generative-ai/ta-p/14238551).
