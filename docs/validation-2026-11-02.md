# Validation record — 2 November 2026

This record distinguishes local checks from actual SAP execution. The illustrations are based on SAP GUI captures cropped to the relevant area. The upload menu, installation result, settings and currency-selection illustrations use cursor-cleaned versions supplied by the maintainer. This visual cleanup does not change the recorded test results. SAP's clock showed 1 November 2026 during the session; the workstation date was 2 November 2026.

## Actual SAP scope

Tests used the authenticated sandbox system A4H, client 001. The precise SAP_BASIS SP and kernel were not collected. Do not infer 7.40 runtime compatibility from these results.

The existing `ZCHE_*` objects were preserved. A namespace copy was built **before literal chunking**, renaming all custom source/XML references consistently. The bootstrap report was `ZTST_TCMB_INSTALL`; the completed installation used `ZTS8_TCMB_*`, `ZCL_TS8_TCMB_*`, `ZIF_TS8_TCMB*` and `ZCX_TS8_TCMB` in `$TMP`. Standard SAP calls and installation behavior were unchanged.

| Check | Observed result |
|---|---|
| Bootstrap creation, upload, syntax and activation | Passed. Two obsolete `UNICODE ENABLING` warnings on the newer system; retained for the older syntax target. |
| Existing-object protection | Stopped on an existing canonical object before installation. |
| Complete fresh isolated installation | 44 source objects created; DDIC and OO activated; report source/text pools activated; reports and class/interface pools generated. `Installation completed` displayed. |
| Settings screen and currency selection | Opened successfully; DEMO, M, FX_BUY, SAME_DAY, USD and JPY entered. |
| Client policy inspection | Standard CCCORACTIV domain inspected: blank permits changes without automatic recording, 1 requires recording, 2 forbids changes, 3 permits local changes but forbids transports. No SCC4 settings changed. |
| Successful settings save/load | Pending after the client-policy correction. The earlier editor incorrectly rejected local saves in a state-3 client. |
| CTS settings key recording and target import | Pending in a transport-enabled client. A dedicated empty Customizing request/task was created but not released. No settings were written by the rejected attempts. |
| SAP ABAP Unit / ATC for this revision | Pending. Local transpiled tests are separate. |
| Current loader HTTPS, dry run, actual rates and background job | Not rerun in this session. No exchange rates were written. |

The completed installation's canonical payload SHA-256 was `3cc3f353e881baa735d04c55225726ffa4449ef68a5fcd87b11e489157624f91`.

After that run, the client-policy validator was corrected and covered by six additional regression tests; four settings labels were shortened. The current generated payload is `f64072e82fc90d05e7b1271a71830c90346b961ffef27eebaaeab9fb40e8d1fa`. Its final SAP rerun was prevented by repeated `Memory low` and `Transaction from "PRIV" session reset after timeout` messages while opening the SE38 editor. The additional test session was closed. System parameters were not changed.

## Local checks for the current payload

| Check | Result | Limit |
|---|---|---|
| `npm run lint` | Passed for 7.40 SP08 and 7.58 | Static checks with pinned SAP definitions, not execution on those releases. |
| `npm run test:logic` | 59 tests passed | JavaScript-transpiled ABAP with simplified DDIC and fake persistence. Includes 20 settings-rule tests. |
| `npm run check:installer` | Generated-payload round-trip/completeness/date-rule checks | Ensures embedded source, metadata and test includes match; does not execute SAP repository APIs. |

Earlier failed test namespaces (`ZTST`, `ZTS2`–`ZTS7`) may contain partial objects. No existing objects were deleted or overwritten to retry. These sandbox objects and the unreleased test transport require a separate owner-reviewed cleanup; do not copy these test names into an installation.

The remaining [SAP acceptance checklist](../CONTRIBUTING.md#sap-acceptance-checklist) includes older releases and the classic OO API fallback, transport/import behavior, restricted users, concurrent edits, failure recovery and real currency conversion readback.

## Screenshots

- [Upload menu](images/sap-upload.png)
- [Installer selection](images/sap-installer.png)
- [Completed isolated installation](images/sap-install-complete.png)
- [Settings entered before saving](images/sap-settings.png)
- [Explicit currency selection](images/sap-currencies.png)

For the meaning of SCC4 settings, see SAP's [Client Control documentation](https://help.sap.com/saphelp_aii710/helpdata/en/57/38dea84eb711d182bf0000e829fbfe/content.htm).
