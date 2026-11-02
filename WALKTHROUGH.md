# From installation to your first exchange-rate record

> **English** | [Türkçe](WALKTHROUGH.tr.md) · [Project overview](README.md) · [Technical reference](TECHNICAL.md)

## Start with the big picture

Here is what we will do: **SAP will read TCMB's daily exchange-rate bulletin and preview your selected rates without saving them.** After reviewing the results, you can load the rates into SAP. You will verify the records in OB08, SAP's exchange-rate maintenance transaction.

First we will install the project, then save our rate choices. After that, each rate run uses only the load report:

![SE38 path: ZCHE_TCMB_INSTALL for initial setup, ZCHE_TCMB_CONFIG for settings, and ZCHE_TCMB_LOAD for each rate run](docs/images/setup-en.svg)

**Who is this guide for?** An ABAP developer who can create and run reports in SE38. Perform the first installation and real-write trial in DEV/a sandbox. This is a pre-release: isolated installation completed; final settings-save and end-to-end acceptance checks remain pending. [Validation record](docs/validation-2026-11-02.md).

Follow this order: [0 · Prepare](#prepare) → [1 · Install](#install) → [2 · Profile](#profile) → [3 · Connection and preview](#preview) → [4 · First write](#first-write) → [5 · Daily use](#daily-use).

<a id="prepare"></a>

## 0. What should you prepare first?

![Three preparations: SAP development access, rate choices, and connectivity from the SAP server to TCMB](docs/images/prepare-en.svg)

**SAP access:** you need object-creation and transport permissions in your development system. We will prepare a customer package and your own transport task in the installation step.

**Rate choices:** decide which currencies, buying or selling rates, and valid-from dates you need. The SAP **rate type** groups rates by their purpose. **OBBS translation ratios** determine the units SAP uses for a quote; TCMB may publish JPY per 100 units. Verify the currencies/rate type and ratios effective on the relevant date; do not enter arbitrary `1:1` ratios. Consult the FI owner if you do not manage these choices yourself.

**Connectivity:** the SAP application server needs HTTPS access to `www.tcmb.gov.tr:443` and certificate trust. The standard route does not require RDP/SSH access or extra server software. It needs no TCMB username, password or API key. Configure connectivity yourself if authorized, or involve the Basis/network owner. We will test it from SAP in step 3.

<a id="install"></a>

## 1. Install the project in SAP

Complete this step in your **SAP development system, using SE80/SE09 and SE38**. The settings and load reports will be ready afterwards, without any profiles or exchange rates yet. You do not need abapGit or to create each class manually.

### 1.1. Select your package and child task

1. In **SE80**, create or select a transportable customer package. `ZCHE_TCMB` is only an example; use your own **Z/Y package**.
2. In **SE09**, prepare/select **your own task under a modifiable Workbench request**. The task is the child entry beneath the parent request. The installer needs that child task number.

For a local-only sandbox trial, you may choose `$TMP` with an empty task; those objects cannot be transported. Use a customer package if you intend to move between systems. Use your own package and task, rather than copying examples from screenshots.

### 1.2. Download the single file and upload it in SE38

1. **[Open the installer and save it to your computer](https://raw.githubusercontent.com/Cheditte/abap-tcmb-rates/main/installer/zche_tcmb_install.prog.abap).** The filename should be `zche_tcmb_install.prog.abap`. Use this complete file, rather than a GitHub HTML page or one class from the source folder.
2. In **SE38**, create **executable report** `ZCHE_TCMB_INSTALL`. Assign your package and appropriate Workbench task.
3. In the source editor, choose **Utilities → More Utilities → Upload/Download → Upload** and select the file. Menu wording can vary; you can also paste the complete source.

![Upload menu in the SE38 source editor for loading the downloaded installer](docs/images/sap-upload.png)

4. Save the source, check syntax and activate the report. The installer can activate before the other project objects exist.

### 1.3. Run the installation preflight first

1. Open `ZCHE_TCMB_INSTALL` with **F8**.
2. Set **Existing target package (`P_PACK`)** to the package selected in 1.1.
3. Set **Your Workbench task (`P_TASK`)** to your Workbench child task. Leave it empty only for a `$TMP` trial.
4. Keep **Check only - create nothing (`P_TEST`) selected**. Execute with F8.

![Installation preflight with package, Workbench child task and Check only selected](docs/images/sap-installer.png)

**Checkpoint:** look for `READY` lines and `Preflight passed`. No objects, profiles or rates have been created. This does not mean the actual installation has completed.

### 1.4. Create the objects

1. After successful preflight, return to the selection screen.
2. **Clear Check only and press F8 to begin installation.**
3. Look for **`Installation completed`**. Verify that `ZCHE_TCMB_CONFIG` and `ZCHE_TCMB_LOAD` are active; run package ABAP Unit and appropriate ATC checks.

![Actual isolated SAP installation displaying Installation completed](docs/images/sap-install-complete.png)

The **`ZTS8` names in this real SAP capture belong to an isolated test copy**. Continue with this guide's `ZCHE_TCMB_*` names. Your SAP theme and menu language may differ.

**Existing objects or a partial installation:** the installer is for a clean first installation. It does not replace active/inactive objects, update them or automatically repair partial state. If it stops partway through, earlier objects may remain. Review the log, activation state and transport list; do not delete objects or remove guards to retry. See [installation behavior and recovery](TECHNICAL.md#standalone-installer-and-settings-report).

<a id="profile"></a>

## 2. Save your rate choices in a profile

Save your choices in **SE38 → `ZCHE_TCMB_CONFIG`**. A **profile** is this saved set of settings, so you do not need to enter them again for each run. This step saves configuration, not exchange rates.

### 2.1. Fill in the settings screen

1. Open **SE38 → `ZCHE_TCMB_CONFIG` → F8**.
2. Enter the fields below. `DEMO` is an example name for the profile you will create; it is not preinstalled. `M`, `FX_BUY` and `SAME_DAY` are also example choices; verify them against your FI process.

| Screen field | What to enter |
|---|---|
| Profile name (`P_PROF`) | For example `DEMO`: the name you will select in the load report. |
| Description (`P_DESC`) | Your description of the profile's purpose. |
| Valid-from date rule (`P_RULE`) | Example `SAME_DAY`: the rate is valid from the bulletin date. |
| SAP rate type (`P_TYPE`) | Example `M`; use a defined rate type appropriate for your process. |
| TCMB rate field (`P_SRC`) | Example `FX_BUY`: TCMB forex buying rate. |
| Currency codes (`S_CURR`) | Example `USD` and `JPY`; we will enter them on separate rows next. |
| Existing: S keep/U update (`P_KEEP`) | `S`: preserve a different existing rate for the same date/key. `U` permits updates. |
| No bulletin (I/W/E) (`P_NONE`) | Example `I`: report a missing bulletin as information. `W` means warning, `E` error. |

3. For the first HTTPS trial, leave factory calendar, inverse/file flags, SM59 destination, custom URL, server folder and exit blank/unselected. If your organization requires SM59, follow [the option in 3.1](#connectivity). The quote currency is `TRY`. [Other date rules](TECHNICAL.md#date-rules) · [Other TCMB fields](TECHNICAL.md#tcmb-fields).

This capture shows **settings entered before saving**. Do not copy its transport number; you will select your own task in 2.3. Long labels were shortened after this capture; fields and choices are unchanged.

![Settings screen filled with the example DEMO choices; it does not establish a successful save](docs/images/sap-settings.png)

### 2.2. Enter currencies on separate rows

1. Click the **multiple-selection** button to the right of **Currency codes**.
2. Under **Select Single Values**, enter `USD` and `JPY` on separate rows. Do not use ranges or exclusions for the first trial.
3. Transfer the selections back to the main screen.

![USD and JPY entered on separate rows under Select Single Values](docs/images/sap-currencies.png)

### 2.3. Save the settings

1. Enter **your own modifiable Customizing or Workbench child task** from SE09/SE10 in **Your transport task (`P_TASK`)**. Do not enter the parent request. This transports settings data; it need not be the Workbench task used for installation.
2. Select **Save settings when executing (`P_SAVE`)**, then press F8.
3. Look for **`Settings saved`**; check that the configuration keys were recorded in your task.

For a sandbox client permitting local changes, you may select **Local settings, no transport (`P_LOCAL`)** with an empty task. Those settings are not transported. Display/change `S_TABU_NAM` permissions are required for all three configuration tables. Saving is rejected in a closed client or one that disallows the chosen save mode; do not change SCC4 to bypass client policy. [Client and transport rules](TECHNICAL.md#standalone-installer-and-settings-report).

**Checkpoint:** your profile is saved; no rates have been written to OB08. To reopen an existing profile, enter its name and click **Load existing profile into this screen** first. Reload if another user changed it. Multiple mappings, exclusions or renamed SAP currency codes require [advanced maintenance](TECHNICAL.md#advanced-profile-maintenance).

<a id="preview"></a>

## 3. Test connectivity and preview the first results

<a id="connectivity"></a>

### 3.1. Open the load report and test the connection

1. Open **SE38 → `ZCHE_TCMB_LOAD` → F8**.
2. Enter your saved profile in **Rate profile (`P_PROF`)**; `DEMO` in our example.
3. Click **Test the connection to TCMB**.

The report should retrieve and read a recent bulletin. This button checks the **last seven days**, independently of your date selection, and does not save exchange rates.

The default source is **`https://www.tcmb.gov.tr/kurlar`**. This is the actual source address; do not replace it with a personal address. If direct access works, the profile's connection fields may stay blank.

<details>
<summary>If the connection fails: direct HTTPS, SM59, or SAP without internet access</summary>

- **Direct HTTPS:** verify outbound access from the SAP application server and trust in the actual certificate chain in STRUST's SSL client **Anonymous** PSE. A browser test on your own computer alone is insufficient.
- **SM59/proxy required:** create a type-**G** HTTP destination; host `www.tcmb.gov.tr`, port `443`, SSL active, path prefix empty. Configure the proxy and destination SSL PSE for your environment. Enter **the name of your destination** in the settings report's SM59 field; its technical field is `RFC_DESTINATION`. Save the profile again and retest.
- **You lack access:** ask the Basis/network owner for outbound HTTPS from the SAP application server to www.tcmb.gov.tr:443 and corresponding certificate trust.
- **SAP cannot access the internet:** use [the server-file option](#read-from-files).

</details>

### 3.2. Preview a single day

1. In **Bulletin date(s) (`S_DATE`)**, choose **one past weekday with a published bulletin**. Use only one day for the first trial. Today's bulletin may not be available yet.
2. Leave **Date rule (`P_RULE`)** blank to use the profile rule.
3. Keep **Test run, write nothing (`P_TEST`) selected**. Execute with F8.
4. Check currencies, rate type, bulletin date, **`VALID_FROM` date**, ratios and messages. Account for quote units and translation ratios when comparing TCMB values with SAP rates.

| Result | Meaning in a test run |
|---|---|
| `NEW` | A real run would create a new rate. |
| `UPDATED` | A real run would change an existing rate. |
| `UNCHANGED` | An equal rate already exists for the same key/date. |
| `SKIPPED` | The row was skipped; read its message. |
| `NO_BULLETIN` | No bulletin was retrieved for that weekday; it may be a holiday or not yet published. The profile can instead treat this as an error. |
| `ERROR` | Resolve the cause described in the message. |

**Checkpoint:** you can see the results; **even `NEW` in a preview means no OB08 record was written.** This does not establish real-write authorization or commit success. Custom exits must also follow the [test-mode contract](TECHNICAL.md#architecture-and-extensions).

<a id="first-write"></a>

## 4. Perform the first real write in the sandbox

1. Resolve unexpected errors/skips. Verify the rate type, valid-from date and expected currency-conversion amount.
2. Keep the same single day and small currency selection. **Clear Test run and press F8 when you intend to save.**
3. Check the messages. In a real run, `NEW` / `UPDATED` report creation/change if writing and commit succeeded.
4. In **OB08**, find the record for the same rate type, currency pair and valid-from date. Verify the expected amount through SAP currency conversion too.
5. Repeat the same day: equal records should return `UNCHANGED`.

**Checkpoint:** the SAP rate and conversion result match your expectations. A successful preview alone is insufficient for daily operation.

<a id="daily-use"></a>

## 5. Schedule daily use after verification

1. Transport objects and profile settings through your normal landscape. **Do not rerun the installer in every target system.** Verify connectivity, client policy, permissions and FI settings in each target.
2. Save an approved **variant** for `ZCHE_TCMB_LOAD`. For daily use, select a **current-date selection variable**, rather than a fixed past date. Explicitly check the Test run flag for a variant intended to save rates.
3. In **SM36**, create a background job using that variant. Schedule after bulletin publication; verify the SAP/job time zone.
4. Test background execution with a test user first, then select an appropriately authorized runtime user. Monitor **SM37**, job log and spool.

The program skips Saturdays/Sundays. The profile's missing-bulletin policy applies to other unpublished days. A failed job does not undo earlier successful writes.

<details>
<summary>Alternative installation: if you already use abapGit</summary>

Import `https://github.com/Cheditte/abap-tcmb-rates` into a customer package, Pull and activate. Offline import uses New Offline → Import zip → Pull zip. Do not install the same objects twice through both routes. Use `ZCHE_TCMB_CONFIG` for settings; SM30 is optional advanced maintenance. [abapGit installation guide](https://docs.abapgit.org/user-guide/getting-started/install.html).

</details>

## Read from files

Use this alternative only when SAP cannot retrieve TCMB bulletins over HTTPS. The source is a folder accessible to the **SAP application server**, rather than your computer's Downloads folder. No automatic downloader is included.

<details>
<summary>File preparation steps for SAP without outbound internet access</summary>

1. If authorized, use your organization's server-access method: RDP for Windows, SSH for Linux, or managed file transfer. Otherwise arrange folder/file preparation with the server owner.
2. Stage the complete daily TCMB XML as `DDMMYYYY.xml`. **30 October 2026 is only an example:** its filename would be `30102026.xml`. Change the name to match your selected date; the XML bulletin date must match too. Place only complete files in the readable folder.
3. In the simple settings screen, select **Read from server files**, enter **your actual server folder** in **Server folder**, and save the profile. The technical fields are `SOURCE_CLASS = ZCL_CHE_TCMB_SOURCE_FILE` and `FILE_FOLDER`.
4. Verify SAP runtime file authorization and OS read access. With multiple application servers, ensure the foreground run/job can access the same files.
5. Run the load report in **test mode** for the file's date. The connection button checks the last seven days; if you only staged an older file, preview that date directly.

Missing/unreadable files produce `ERROR`. The report does not infer a holiday or automatically switch sources. [Technical details](TECHNICAL.md#file-source-and-troubleshooting).

</details>

## If you get stuck

| Where did it stop? | First check |
|---|---|
| Installation rejected existing objects | Active/inactive target objects, log and activation state. The installer is not an updater. |
| Profile cannot be saved | Your child task, client policy, table permissions, and loading an existing profile first. |
| Profile not found | Correct client, profile name and successful settings save. |
| TCMB connection failed | SAP-server connectivity, STRUST/SM59, network and proxy. |
| Ratio / TCURF error | OBBS currency pair, rate type and ratios effective on the relevant date. |
| Expected rate skipped | Row message, currency list, TCMB field and existing-rate policy. |
| Real load or job failed | Results, OB08 and SM37 log/spool. Earlier successful writes may remain. |

Do not retry immediately after an error. Review results and OB08, resolve the cause, then preview the affected range. After a commit error, have an authorized person inspect failed/pending updates in SM13 before retrying. See [partial-write recovery](TECHNICAL.md#errors-partial-writes-and-reruns).
