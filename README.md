# Load TCMB exchange rates into SAP

> **English** | [Türkçe](README.tr.md)

Use this project to load the daily exchange rates published by the Central Bank of the Republic of Türkiye (TCMB) into SAP. You choose the currencies, buying or selling rates, and the date from which the rates are valid.

**The flow:** SAP reads TCMB's daily bulletin and shows the results based on your settings, without saving exchange rates. Review them, choose to save, then verify the records in **OB08**, SAP's exchange-rate maintenance transaction.

![TCMB daily bulletin and profile choices lead to a preview, then an explicit choice to save and verify in OB08](docs/images/overview-en.svg)

## What do you need to start?

The person installing the project should be an **ABAP developer** who can create and run reports in SE38. You can complete all the preparations yourself if you have the relevant access. Involve the FI or Basis/network owner where needed.

![Three preparations: SAP development access, decisions about the rates, and HTTPS connectivity from SAP to TCMB](docs/images/prepare-en.svg)

The standard HTTPS route needs no extra helper software on the SAP server. **No TCMB account, password or API key is required.** The SAP application server needs access to `www.tcmb.gov.tr:443` and certificate trust. Opening the site on your computer does not establish connectivity from SAP.

## From installation to first use

Start by **uploading one file in SE38**, without abapGit. The three reports have different purposes:

| Order | Report to open in SE38 | What you do |
|---|---|---|
| 1 · Install | `ZCHE_TCMB_INSTALL` | Create the SAP objects in your package from the downloaded file. |
| 2 · Configure | `ZCHE_TCMB_CONFIG` | Save currencies, rate type and date choices in a profile. |
| 3 · Use | `ZCHE_TCMB_LOAD` | Select the profile and bulletin date; preview first, then choose to save. |

A **profile** is a saved set of choices you reuse for each run. You create your first profile; none is preinstalled. Installation and saving a profile do not save exchange rates. Rates are written by the third report when you clear the test flag.

**[Step-by-step installation and use, with SAP screenshots →](WALKTHROUGH.md)**

[Open / save the single-file installer](https://raw.githubusercontent.com/Cheditte/abap-tcmb-rates/main/installer/zche_tcmb_install.prog.abap). Create report `ZCHE_TCMB_INSTALL` in SE38; follow the guide to upload it and perform the first checks.

Start in DEV/a sandbox with **one day and a few currencies**. After verifying the results, you can schedule daily use as an SAP background job.

## Scope and current status

- The quote currency is **TRY**. The project does not calculate cross rates or create accounting documents. It loads standard SAP exchange-rate records through a BAPI.
- Test mode is selected by default. Seeing `NEW` / `UPDATED` in a preview does not mean anything was saved.
- The installer is for a **clean first installation**. Existing target objects stop the run without replacement or updates. Use normal transports for subsequent systems.
- **Pre-release: v0.1.** An isolated SAP installation completed; final settings-save, transport and end-to-end acceptance checks remain pending. Static checks for 7.40 SP08 and 7.58 do not establish runtime compatibility on those releases. [Validation scope and remaining checks](docs/validation-2026-11-02.md).

If SAP has no outbound internet access, an [alternative route](WALKTHROUGH.md#read-from-files) reads XML files staged in an SAP server folder. Downloading/preparing those files is outside this project.

## Choose a guide

| Your task | Document |
|---|---|
| Install, configure and perform the first run | [Installation and usage guide](WALKTHROUGH.md) |
| Look up all fields, call the classes from your own ABAP or extend the project | [Technical reference](TECHNICAL.md) |
| Run checks or contribute | [CONTRIBUTING.md](CONTRIBUTING.md) |
| Review changes | [CHANGELOG.md](CHANGELOG.md) |

MIT licensed. [License](LICENSE) · [Report an issue / suggest an improvement](https://github.com/Cheditte/abap-tcmb-rates/issues)
