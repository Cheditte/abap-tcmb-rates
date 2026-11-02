# Load TCMB rates with one SAP report

> **English** | [Türkçe](README.tr.md)

Use this project to load the daily exchange rates published by the Central Bank of the Republic of Türkiye (TCMB) into SAP. Choose the currencies, buying or selling rates, and valid-from date.

**Paste one file into SE38, activate and run it.** All settings are on that report's selection screen. Save reusable choices with SAP's standard **variant** feature.

**Use Turkish even in an English SAP session.** Choose **Türkçe** in the report's **Dil / Language (`P_LANG`)** field without logging out. The choice is stored in the variant. Default **Otomatik / Logon language** uses Turkish for a Turkish logon and English otherwise.

![TCMB bulletin, selection-screen settings, preview without saving, then a controlled write verified in OB08](docs/images/overview-en.svg)

## What you need

The person installing the report should be an **ABAP developer** who can create and run reports in SE38. Complete FI and connectivity tasks yourself if authorized, or involve the relevant owner.

![SAP development access, rate choices and connectivity from the SAP server to TCMB](docs/images/prepare-en.svg)

The SAP application server needs HTTPS access to **`www.tcmb.gov.tr:443`** and trust in the current certificate chain. Browser access on your computer alone is insufficient. The standard HTTPS route needs no extra server software, TCMB account, password or API key.

## From installation to first use

| Step | What you do | Result |
|---|---|---|
| 1 · Install | Upload the source into `ZCHE_TCMB_LOAD` in SE38 and activate. | One executable report. |
| 2 · Choose | Set currencies, rate type and date rule on the same screen; optionally save a variant. | Reusable choices. |
| 3 · Preview | Run one day and a few currencies with Test run selected. | Results without saving exchange rates. |
| 4 · Verify | After review, clear Test run and verify the records in OB08. | Standard SAP exchange-rate records. |

**[Step-by-step guide with a screenshot and diagrams →](WALKTHROUGH.md)**

**[Open / save the single source file](src/zche_tcmb_load.prog.abap)**

A **variant** stores selection-screen values and can be used by a daily job. **OB08** is SAP's exchange-rate display/maintenance transaction. Saving a variant does not write exchange rates.

## Scope and validation status

- The quote currency is **TRY**; the report does not calculate cross rates or create accounting documents.
- Test mode is selected by default. `NEW` / `UPDATED` in a preview describe planned operations.
- Fresh installation needs no custom tables, domains, data elements, global classes or separate installer. abapGit is optional.
- **v0.3.0 integration candidate.** The syntax target is ABAP 7.00. Runtime on actual 7.00/7.01/7.02 systems remains unverified.
- The handoff reports 34 tests and limited real-write results on the A4H sandbox. Integration and language changes bring the current suite to 48 tests; SAP acceptance remains pending. An operator-supplied screenshot shows Turkish selection labels and a successful TCMB connection message; current preview, write/OB08, language variants and background checks remain outstanding. [Validation record](docs/validation-v0.3.0.md).

The language choice covers selection labels, the date-rule list, project-authored messages and result-list headings. Technical status codes such as `NEW` / `ERROR` stay unchanged, with a description in the selected language. SAP GUI menus and raw SAP/BAPI/OS diagnostics may remain in their system/logon language.

If SAP has no internet access, use [XML files staged in a server folder](WALKTHROUGH.md#read-from-files). Downloading/staging them is outside this project.

If the older multi-object edition is installed, read [the migration note](TECHNICAL.md#migration-from-the-old-edition). Old SAP objects are not automatically deleted; this report does not use the old profile tables.

## Guides

| Your task | Document |
|---|---|
| Install, run, save a variant or schedule daily use | [Step-by-step guide](WALKTHROUGH.md) |
| Fields, local classes, extensions and errors | [Technical reference](TECHNICAL.md) |
| Checks and SAP acceptance | [CONTRIBUTING.md](CONTRIBUTING.md) |
| Changes | [CHANGELOG.md](CHANGELOG.md) |

MIT licensed. [License](LICENSE) · [Report an issue](https://github.com/Cheditte/abap-tcmb-rates/issues)
