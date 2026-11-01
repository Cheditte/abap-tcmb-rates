# Installation and usage guide

> **English** | [Türkçe](WALKTHROUGH.tr.md) · [Project overview](README.md) · [Technical reference](TECHNICAL.md)

By the end of this guide, you will be able to run `ZCHE_TCMB_LOAD`, preview one day's TCMB rates without saving them, then perform a controlled load in a sandbox and check the records in OB08.

**Starting point:** you are an ABAP developer with development access. Start in DEV/a sandbox. This is a pre-release; clean installation, maintenance-dialog generation and SAP runtime validation remain outstanding for the current revision.

![Setup map: install SAP objects, prepare a profile and connectivity, then preview and save](docs/images/setup-en.svg)

## Separate the preparations first

| Preparation | Where | Why |
|---|---|---|
| Import objects and generate settings screens | SAP development system | Make the report runnable and settings maintainable. You do this. |
| Choose currencies, rate types, ratios and dates | SAP FI configuration and your accounting process | Store the right rates under the right keys and dates. Consult the FI owner if needed. |
| Enable TCMB access | SAP application-server network and SSL configuration | Allow SAP to retrieve the bulletin. Do it yourself if authorized, otherwise involve Basis/network support. |

The normal HTTPS route does not require RDP/SSH access to install extra software. SAP GUI connectivity/certificate configuration and network permissions may be sufficient. Host access is only needed where your environment requires it, such as for the alternative file route.

## 1. Install the SAP objects

### 1.1. Import with abapGit

abapGit imports ABAP objects from GitHub into SAP. This project includes classes and tables as well as a report; pasting only the report into SE38 is not a complete installation.

If needed, follow the official [abapGit installation guide](https://docs.abapgit.org/user-guide/getting-started/install.html): upload the standalone source into a new SE38 report named `ZABAPGIT_STANDALONE`, activate it and execute it.

1. Create a **dedicated transportable customer package**. `ZCHE_TCMB` is an example name; choose one suitable for your system. Avoid `$TMP` if you intend to transport the project.
2. In abapGit, use **New Online** with the following repository URL and your package, create the repository, then **Pull**. This is the actual project URL; keep it as shown:

   `https://github.com/Cheditte/abap-tcmb-rates`

3. Activate the objects. Resolve activation errors before continuing. Run the package's ABAP Unit tests and appropriate ATC checks.

**If SAP cannot reach GitHub:** download **Code → Download ZIP** on your computer and use **New Offline → Import zip → Pull zip** in abapGit instead. Offline import solves installation access; daily TCMB access is a separate preparation.

### 1.2. Generate the settings screens once

The repository includes three configuration tables, **without generated SM30 maintenance dialogs**. SM30 is the standard SAP transaction you will use to enter settings. Generate these screens once in DEV, not for every run.

| Table | What it stores |
|---|---|
| `ZCHE_TCMB_PROF` | General rules and source selection for a profile. |
| `ZCHE_TCMB_MAP` | Which TCMB field feeds which SAP rate type. |
| `ZCHE_TCMB_CURR` | Which currencies to include or exclude. |

For each table:

1. Open it in **SE11 → Utilities → Table Maintenance Generator**. Alternatively use **SE54 → Generated Objects → Create/Change**. Menu wording can vary with SAP language/release.
2. Select an appropriate authorization group, customer function group, one-step maintenance type, screen number and standard recording routine. Example function-group names: `ZCHE_TCMB_PROF_M`, `ZCHE_TCMB_MAP_M`, `ZCHE_TCMB_CURR_M`. These are names you create; check that they are available. Separate groups can each use screen `0001`.
3. Generate and save the objects in the project package and an appropriate transport request. If maintenance is disabled, review the table's maintenance setting in SE11.
4. Confirm you can open all three tables in SM30. Make the decisions below before entering settings.

**Ready to continue when:** the report is active and all three settings screens are accessible. Generate and transport from DEV rather than generating in production. Fresh installation and screen generation remain items on the [SAP acceptance checklist](CONTRIBUTING.md#sap-acceptance-checklist).

## 2. Prepare a first profile and connectivity

### 2.1. Decide which rates to load

**`DEMO` is an example profile you create**, not preinstalled data. The example previews forex buying rates for USD and JPY, valid on the bulletin date. **`M`, `FX_BUY` and `SAME_DAY` are example choices**, subject to your FI/accounting process.

- **Rate type:** a grouping of exchange rates used for a particular purpose in SAP. The example uses `M`; it must exist and be appropriate in your system.
- **TCMB field:** forex buying/selling, banknote buying/selling, or a mean. The example uses `FX_BUY` for forex buying. See [all choices](TECHNICAL.md#tcmb-fields).
- **Valid-from date:** the bulletin date, the next calendar day, or the next working day in a factory calendar. The example uses `SAME_DAY`.
- **Translation ratio:** how many currency units SAP uses for a quote. TCMB may quote JPY per 100 units. Verify OBBS ratios for the pair/rate type, including their effective date. Do not enter arbitrary `1:1` ratios.

### 2.2. Enter the sample settings in three tables

Use **SM30** in the intended SAP client. All three tables are client dependent; settings in another client will not appear here.

**A — First, one row in `ZCHE_TCMB_PROF`**

| Field | First-run value | Meaning |
|---|---|---|
| `PROFILE` | `DEMO` | Example name; use the same name in the other two tables. |
| `DESCRIPTION` | Your description | For example, “TCMB first trial”. |
| `DATE_RULE` | `SAME_DAY` | Valid from the bulletin date. |
| `TARGET_CURRENCY` | `TRY` | Supported quote currency. |
| `EXISTING_RATE` | `S` | Preserve a different existing rate for the same key/date. |
| `NO_BULLETIN` | `I` | Report a missing bulletin in the results. |

For the first HTTPS trial, leave these fields blank: `FACTORY_CALENDAR`, `WRITE_INVERSE`, `SOURCE_CLASS`, `RFC_DESTINATION`, `BASE_URL`, `FILE_FOLDER`, `EXIT_CLASS`. A blank source class selects the built-in HTTPS source. If your organization uses an SM59 destination, fill the relevant field as described below.

**Important:** a blank `EXISTING_RATE` does not protect existing values. Blank or `U` allows updates, which is why this example explicitly uses `S`. See the [complete field reference](TECHNICAL.md#profile-settings).

**B — One mapping row in `ZCHE_TCMB_MAP`**

| `PROFILE` | `RATE_TYPE` | `SOURCE` |
|---|---|---|
| `DEMO` | `M` | `FX_BUY` |

This means “use TCMB forex buying values under SAP rate type M when DEMO runs.” If you chose another rate type, replace `M` with it and verify the corresponding OBBS settings.

**C — Two currency rows in `ZCHE_TCMB_CURR`**

| `PROFILE` | `TCMB_CODE` | `SAP_CURRENCY` | `EXCLUDE` |
|---|---|---|---|
| `DEMO` | `USD` | Leave blank | Leave blank |
| `DEMO` | `JPY` | Leave blank | Leave blank |

“Leave blank” is an instruction, not text to enter. These two rows restrict the run to USD and JPY. If your SAP currency code differs, enter the local code in `SAP_CURRENCY`.

**Do not leave the currency table empty for this trial:** without inclusion rows, the program considers all non-excluded currencies in the bulletin.

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

After installation and real-write acceptance, transport the objects, maintenance dialogs and settings through your normal landscape. Recheck the client, connectivity, permissions and FI configuration in each target system.

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
| SM30 cannot open a table | Generated maintenance dialog and maintenance authorization. |
| SSL / connection failure | SAP-server connectivity, STRUST/SM59, network and proxy. |
| Ratio / TCURF error | OBBS currency pair, rate type and factors effective on the valid-from date. |
| Expected rate skipped | Row message, currency list, source field and existing-rate policy. |
| Failed job | SM37 log/spool and OB08; earlier successful writes may remain. |

**Do not retry blindly.** Earlier successful days and rows may already be committed. Review results and OB08, resolve the cause and preview the affected range again. After a commit error, have an authorized person inspect failed/pending updates in SM13 before retrying. See [partial-write recovery](TECHNICAL.md#errors-partial-writes-and-reruns).
