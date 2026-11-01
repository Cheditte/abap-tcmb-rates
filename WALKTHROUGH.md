# Installation and usage guide

> **English** | [Türkçe](WALKTHROUGH.tr.md) · [Project overview](README.md) · [Technical reference](TECHNICAL.md)

By the end of this guide, you will be able to run `ZCHE_TCMB_LOAD`, preview one day's TCMB rates without saving them, then perform a controlled load in a sandbox and check the records in OB08.

**Starting point:** you are an ABAP developer with development access. Start in DEV/a sandbox. This is a pre-release; the completed isolated installation and remaining checks are explained in the [validation record](docs/validation-2026-11-02.md).

![Setup map: install SAP objects, prepare a profile and connectivity, then preview and save](docs/images/setup-en.svg)

## Separate the preparations first

| Preparation | Where | Why |
|---|---|---|
| Single-file installation | SAP development system | Run the installer and settings report. You do this. |
| Choose currencies, rate types, ratios and dates | SAP FI configuration and your accounting process | Store the right rates under the right keys and dates. Consult the FI owner if needed. |
| Enable TCMB access | SAP application-server network and SSL configuration | Allow SAP to retrieve the bulletin. Do it yourself if authorized, otherwise involve Basis/network support. |

The normal HTTPS route does not require RDP/SSH access to install extra software. SAP GUI connectivity/certificate configuration and network permissions may be sufficient. Host access is only needed where your environment requires it, such as for the alternative file route.

## 1. Install the SAP objects from one file

This route does not require abapGit, manually creating each class, or generating settings screens in SE54. The installer creates the objects; a separate SE38 report maintains simple settings. The single-file installation completed in an SAP sandbox using isolated test names. Run preflight and acceptance checks in your own DEV environment too.

### 1.1. Prepare a package and task

1. Create/select a transportable customer package in SE80. `ZCHE_TCMB` is an example; substitute your own **Z/Y package**.
2. In SE09, prepare **your own modifiable development task** beneath a Workbench request. Supply the child task number to the installer, rather than its parent request. Select the real number from your system.

For a local-only sandbox trial, `$TMP` is allowed with an empty task. Use a customer package to transport between systems. Object-creation/change and CTS permissions are required.

### 1.2. Upload the single file in SE38

1. [Open and save the installer file](https://raw.githubusercontent.com/Cheditte/abap-tcmb-rates/main/installer/zche_tcmb_install.prog.abap). Use the **complete** `zche_tcmb_install.prog.abap` file, not one source class or a GitHub HTML page.
2. Create executable report **`ZCHE_TCMB_INSTALL`** in SE38. Assign the same customer package/appropriate task.
3. In the source editor, upload through **Utilities → More Utilities → Upload/Download → Upload**, or paste the entire source. Menu wording varies with SAP language. Check syntax and activate. This report needs no pre-existing TCMB project objects to activate.
4. Execute with F8. Set **Existing target package / P_PACK** and **Your Workbench task / P_TASK** to your package and child task.
5. Keep **Check only - create nothing / P_TEST selected** and execute. Review `READY` lines and `Preflight passed`. This check creates no objects, profiles or rates, and does not establish that actual installation will succeed.
6. After a successful preflight, return to the selection screen. Clear Check only **when you intend to install**, then execute. Check for `Installation completed`. Run package ABAP Unit and appropriate ATC checks.

**The installer is for a clean first installation.** Existing active/inactive objects stop the run without replacement; this is not an updater or automatic repair tool. If it stops partway through, earlier objects may exist. Review the log, SE11/SE24/SE38 activation state and transport list. Do not delete objects or remove guards to retry. An authorized developer must reconcile partial state and recover after fixing the cause. Installation is not one reversible transaction.

**Ready to continue when:** `ZCHE_TCMB_CONFIG` and `ZCHE_TCMB_LOAD` are active. Installation does not write profiles or rates. Transport the objects normally to other systems rather than rerunning the installer in each target.

### What does it look like?

**Upload the file:** open this menu in the SE38 source editor, then select the downloaded `.abap` file.

![SE38 Utilities, More Utilities, Upload/Download and Upload menus](docs/images/sap-upload.png)

**Preflight:** run with Check only selected first. Enter your own package; the example package name is not mandatory. The task is your child task in SE09. Leave it empty only for a `$TMP` sandbox installation.

![Installer package, Workbench task and selected Check only fields](docs/images/sap-installer.png)

**At the end of a successful installation:** look for `Installation completed`. No profiles or exchange rates are created at this stage.

![Actual SAP installation result showing Installation completed after creating 44 objects](docs/images/sap-install-complete.png)

These are actual SAP GUI captures; your theme and menu language may differ. The completion capture uses `ZTS8` names to preserve the existing project during testing. Follow this guide's `ZCHE_TCMB_INSTALL`, `ZCHE_TCMB_CONFIG` and `ZCHE_TCMB_LOAD` names for your installation.

### Alternative: abapGit

If preferred, import `https://github.com/Cheditte/abap-tcmb-rates` into a customer package with abapGit, Pull and activate. Offline import uses New Offline → Import zip → Pull zip. Do not install the same objects twice using both routes. This route also includes `ZCHE_TCMB_CONFIG`; SM30 is optional advanced maintenance. See the [abapGit installation guide](https://docs.abapgit.org/user-guide/getting-started/install.html).

## 2. Prepare a first profile and connectivity

### 2.1. Decide which rates to load

**`DEMO` is an example profile you create**, not preinstalled data. The example previews forex buying rates for USD and JPY, valid on the bulletin date. **`M`, `FX_BUY` and `SAME_DAY` are example choices**, subject to your FI/accounting process.

- **Rate type:** a grouping of exchange rates used for a particular purpose in SAP. The example uses `M`; it must exist and be appropriate in your system.
- **TCMB field:** forex buying/selling, banknote buying/selling, or a mean. The example uses `FX_BUY` for forex buying. See [all choices](TECHNICAL.md#tcmb-fields).
- **Valid-from date:** the bulletin date, the next calendar day, or the next working day in a factory calendar. The example uses `SAME_DAY`.
- **Translation ratio:** how many currency units SAP uses for a quote. TCMB may quote JPY per 100 units. Verify OBBS ratios for the pair/rate type, including their effective date. Do not enter arbitrary `1:1` ratios.

### 2.2. Save the profile in the simple settings screen

1. Open **SE38 → `ZCHE_TCMB_CONFIG` → F8**. `DEMO` is not preinstalled; you will create it now.
2. Enter the sample below, adjusted to your FI decisions.

| Screen field | First trial |
|---|---|
| Profile name (`P_PROF`) | `DEMO` |
| Description (`P_DESC`) | Your description |
| Valid-from date rule (`P_RULE`) | `SAME_DAY` |
| SAP rate type (`P_TYPE`) | Example `M`; use your appropriate rate type |
| TCMB rate field (`P_SRC`) | Example `FX_BUY` |
| Currency codes (`S_CURR`) | Individual `USD` and `JPY` entries through multiple selection; no ranges/exclusions |
| Existing: S keep/U update (`P_KEEP`) | `S`: preserve different existing rates |
| No bulletin (I/W/E) (`P_NONE`) | `I`: report in results |
| Your transport task (`P_TASK`) | Your modifiable Customizing or Workbench child task from SE09/SE10 |

3. For the first HTTPS trial, leave factory calendar, inverse/file flags, SM59 destination, custom URL, folder and exit blank/unselected. If you need SM59, enter your actual destination as described below. The quote currency is saved as `TRY`.
4. Select **Save settings when executing (`P_SAVE`)**, then F8. Verify `Settings saved` and the recorded transport keys. This saves configuration only, not exchange rates.

To edit an existing profile, first enter its name and click **Load existing profile into this screen**. Saving over an existing profile requires loading it first. If another user changed it while you were editing, reload before saving. Multiple mappings, exclusions and renamed SAP currency codes require [advanced maintenance](TECHNICAL.md#advanced-profile-maintenance); the simple screen refuses to replace those settings.

**Permissions and transport:** `S_TABU_NAM` activities 03 (display) / 02 (change) are required for all three settings tables. Saving in a closed client is rejected. Only in a sandbox client allowing changes without automatic recording, select **Local settings, no transport (P_LOCAL)** with an empty task if needed. This does not transport settings; use the normal customer-package/transport process for shared use.

An explicit currency list is mandatory here. An empty advanced currency table can instead consider all non-excluded bulletin currencies. Keep the first trial limited.

### Follow the example on screen

Enter a profile name and your settings. Use the **multiple-selection** button beside currencies to add USD and JPY on separate rows. Use **Select Single Values**, without ranges or exclusions.

![USD and JPY entered on separate rows under Select Single Values](docs/images/sap-currencies.png)

The next capture shows **settings entered before saving**; it is not evidence of a successful save. Do not copy the pictured transport number. Choose your own task, or select Local settings with an empty task where your client only permits local changes.

![Settings screen prepared with DEMO, currency choices and Save settings selected](docs/images/sap-settings.png)

`S` keeps different existing rates; `U` allows updates. For a missing bulletin, `I` means information, `W` warning and `E` error. Long labels were shortened after this capture to fit the screen; parameter names and choices are unchanged.

### 2.3. Let SAP retrieve the bulletin

The default source is `https://www.tcmb.gov.tr/kurlar`; you do not replace it with a personal address. This route does not ask for a TCMB username, password or API key.

| Situation | What to do |
|---|---|
| SAP can access the internet directly | Connection fields may stay blank. Verify SAP HTTPS access and trust. The direct route uses STRUST's SSL client **Anonymous** PSE. |
| Your organization uses SM59/a proxy | Prepare a type-G HTTP destination with host `www.tcmb.gov.tr`, port `443`, SSL active and no path prefix. Enter **the name of your destination** in `RFC_DESTINATION`. Configure the destination's SSL PSE and proxy for your environment. |
| You do not manage connectivity | Ask the Basis/network owner for outbound HTTPS access from the SAP application server to www.tcmb.gov.tr:443 and the corresponding certificate trust. |
| SAP has no outbound access | Use [the file route](#read-from-files) below. |

For certificate errors, verify the actual trust chain and correct PSE. A successful browser test on your computer alone is insufficient.

**Ready to continue when:** the profile and two currency rows exist, and the selected source is accessible from SAP.

## 3. Preview, then save

### 3.1. First run without saving

1. Open **SE38 → `ZCHE_TCMB_LOAD` → Execute (F8)**.
2. Enter `DEMO` in **Rate profile / `P_PROF`**.
3. Click **Test the connection to TCMB**. Retrieving and parsing a recent bulletin confirms source access without writing rates. This button checks the last seven days, independently of the selected date range.
4. In **Bulletin date(s) / `S_DATE`**, choose one past weekday with a published bulletin. The default is today, whose bulletin might not yet be available.
5. Leave **Date rule / `P_RULE`** blank to use the profile rule. Keep **Test run, write nothing / `P_TEST` selected**.
6. Execute with F8. Check the bulletin date, `VALID_FROM`, USD/JPY, rate type, factors and messages. Account for quote units and SAP ratios when comparing the XML value to the calculated rate.

| Result | How to read it |
|---|---|
| `NEW` | Preview: a new record would be created. Real load: created if writing and commit succeeded. |
| `UPDATED` | Preview: an existing record would change. Real load: updated if writing and commit succeeded. |
| `UNCHANGED` | An equal rate already exists for the same key/date. |
| `SKIPPED` | The row was skipped; read its message. It may reflect an existing-rate policy or a missing source field. |
| `NO_BULLETIN` | No bulletin was retrieved for that weekday, for example a holiday or before publication. The profile policy can instead make this an error. |
| `ERROR` | Read and resolve the reported problem. |

**`NEW` in a test run does not mean anything was saved in OB08.** A preview also does not establish write authorization or commit success. Custom exit classes run in test mode too and must follow the [test-mode contract](TECHNICAL.md#architecture-and-extensions).

### 3.2. Perform a controlled write in the sandbox

1. Resolve unexpected errors/skips. Verify rate type, valid-from date and expected conversion amounts.
2. Keep the same limited selection. Clear Test run **only when you intend to save**, then execute.
3. Find the rate in **OB08**, using the same rate type, currency pair and valid-from date. Also verify the expected amount through SAP currency conversion.
4. Repeat the same day: equal stored rates should return `UNCHANGED`.

### 3.3. Schedule daily use

After installation and real-write acceptance, transport the objects and settings through your normal landscape. Recheck the client, connectivity, permissions and FI configuration in each target system.

In **SM36**, prepare an approved variant/job for `ZCHE_TCMB_LOAD`. For daily bulletins, use a **current-date selection variable**, rather than saving a fixed date. Explicitly check the Test run flag in a variant intended to save rates. Validate background execution with a test user before choosing an appropriately authorized runtime user.

TCMB announces indicative rates at 15:30 on business days. Schedule after publication and verify the SAP/job time zone. See [TCMB's explanation](https://tcmb.gov.tr/wps/wcm/connect/TR/TCMB%2BTR/Main%2BMenu/Banka%2BHakkinda/Sikca%2BSorulan%2BSorular/Doviz%2BKuru%2BPolitikasi%2Bve%2BRezerv%2BYonetimi/).

The program skips Saturdays/Sundays. The profile controls missing-bulletin handling on other days. Monitor **SM37**, job log and spool; a failed job does not undo earlier successful writes.

## Read from files

Use this route only when SAP cannot retrieve TCMB bulletins over HTTPS. The program reads a folder accessible to the **SAP application server**, not your laptop's Downloads folder. This project does not install a downloader.

1. If authorized, use your organization's host-access method (RDP for Windows, SSH for Linux, or managed file transfer). Otherwise arrange folder/file preparation with the server owner.
2. Stage each complete daily XML as `DDMMYYYY.xml`. For **30 October 2026**, the name is `30102026.xml`; change it to match the date you actually select. The XML bulletin date must match too. Move files into the readable folder only after they are complete.
3. Set `SOURCE_CLASS = ZCL_CHE_TCMB_SOURCE_FILE` and enter **your actual server folder** in `FILE_FOLDER`. With multiple application servers, ensure the foreground run/job can access the same files.
4. Verify SAP runtime file authorization and OS read access. Preview one day matching a staged file.

The connection button still checks recent dates. If you only staged an older file, preview its date directly instead. Missing/unreadable files produce `ERROR`; the program does not infer a TCMB holiday or automatically switch sources.

## If something goes wrong

| Symptom | First check |
|---|---|
| Profile not found | Client, profile name and the three configuration tables. |
| Settings save rejected | S_TABU_NAM permissions, SCC4 client setting, your transport task and loading an existing profile first. |
| SSL / connection failure | SAP-server connectivity, STRUST/SM59, network and proxy. |
| Ratio / TCURF error | OBBS currency pair, rate type and factors effective on the valid-from date. |
| Expected rate skipped | Row message, currency list, source field and existing-rate policy. |
| Failed job | SM37 log/spool and OB08; earlier successful writes may remain. |

**Do not retry blindly.** Earlier successful days and rows may already be committed. Review results and OB08, resolve the cause and preview the affected range again. After a commit error, have an authorized person inspect failed/pending updates in SM13 before retrying. See [partial-write recovery](TECHNICAL.md#errors-partial-writes-and-reruns).
