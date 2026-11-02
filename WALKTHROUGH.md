# TCMB rates: choose your goal

> **English** | [Türkçe](WALKTHROUGH.tr.md) · [Overview](README.md) · [Technical reference](TECHNICAL.md)

## Start with the outcome you need

One report reads TCMB bulletins, calculates your selected rates and compares them with SAP records. **Test run selected: inspect without saving. Test run cleared: the report can write rates.** OB08 is where you verify the resulting records.

![Three paths: preview rates, add or update OB08 records, and schedule daily use](docs/images/goals-en.svg)

| Your goal | Follow | Completion check |
|---|---|---|
| See rates without saving | [Path A — Preview](#preview) | Results inspected with Test run selected. |
| Add missing rates or update existing ones | [Path B — Write and verify](#first-write) | Results match the same key/date in OB08. |
| Run automatically each day | [Path C — Schedule](#daily-use) | Dynamic-date variant and monitored SM36/SM37 job. |
| Understand a field | [Selection-field reference](TECHNICAL.md#selection-fields) | Meaning, format and behavior. |
| Recover from locks or partial writes | [Recovery path](#locks-and-partial-writes) | Existing successes reconciled; affected rows retried. |

If not installed, start with preparation and SE38 below. Otherwise jump to your goal. Use DEV/a sandbox for initial writes. [Current acceptance evidence and limits](docs/validation-v0.3.0.md).

<a id="prepare"></a>

## 0. Complete three preparations

![SAP development access, rate choices and connectivity from SAP to TCMB](docs/images/prepare-en.svg)

- **SAP access:** permission to create/activate a report. Use your Z/Y package and appropriate Workbench child task for a transportable installation. `$TMP` is available for a local-only trial; that object cannot be transported.
- **Rate choices:** decide currencies, buying/selling fields and valid-from dates. Choose the SAP rate type for your process; example `M` is not an accounting recommendation. Currencies and rate types must exist. Verify the pair/rate type and effective **OBBS** translation ratios. TCMB may quote JPY per 100 units; do not enter arbitrary `1:1` ratios.
- **Connectivity:** HTTPS from the SAP application server to `www.tcmb.gov.tr:443`, with certificate trust. No TCMB account/password or server helper software is needed. Configure it yourself if authorized, otherwise involve Basis/network support. A browser test on your computer alone is insufficient.

<a id="install"></a>

## 1. Load the single file in SE38

1. Open [`src/zche_tcmb_load.prog.abap`](src/zche_tcmb_load.prog.abap). Use **Copy raw file** to copy the complete source, or **Download raw file** to save the `.abap` file. Do not upload the GitHub HTML page.
2. In **SE38**, create **`ZCHE_TCMB_LOAD`**, type **Executable program**. A suitable title is `TCMB exchange rates`. Assign your customer package and Workbench task, or Local Object / `$TMP` for a local trial.
3. Replace the entire initial source with this file. Alternatively use **Utilities → More Utilities → Upload/Download → Upload** to load the `.abap` file.

![SE38 Upload menu; the file to load in this edition is zche_tcmb_load.prog.abap](docs/images/sap-upload.png)

4. Check syntax and activate with **Ctrl+F3**. Enable **Fixed point arithmetic** in report attributes; calculations require it. The abapGit alternative imports this attribute from metadata.
5. Run the embedded suite through **Program → Execute → Unit Tests**. The current source contains **48 tests**; this count does not mean they have passed in SAP. Resolve failures before a real-write trial.

**Long-line error:** the source contains lines longer than 72 characters. Check **Downwards-compatible line length (72)** in editor settings and **Force Line Length 72** under Upload/Download. Disable the 72-character restriction and reload; do not truncate source. Menu wording varies by SAP GUI release/language.

**Checkpoint:** `ZCHE_TCMB_LOAD` is active and F8 opens its selection screen. No separate installer, settings report or SE11/SE54/SM30 work is needed. Default **Otomatik / Logon language** uses Turkish for a Turkish logon and English otherwise; change it in **Dil / Language**. No manual text-element entry is required. Record the complete message if initialization fails.

If an older report already exists, preserve its source, custom changes and variants before replacement; follow [the migration note](TECHNICAL.md#migration-from-the-old-edition). An [operator-supplied Turkish screenshot](WALKTHROUGH.tr.md#turkce-ekran) now shows selection labels and a successful connection message. A fixed-date Turkish variant and one-off preview job are now evidenced below. Full clean installation, the language-switch interaction, dynamic dates and broader background acceptance remain pending. The capture above illustrates only the general SE38 upload menu.

<a id="preview"></a>

## Path A — I want to inspect rates without saving

![Preview path: small selection, Test run selected, F8, inspect results](docs/images/preview-path-en.svg)

<a id="settings"></a>

### A1. Start with one day and one currency

Open `ZCHE_TCMB_LOAD` through SE38/F8. Example date **30 October 2026** was available in the supplied connection test; use an available bulletin date in your environment. `M` is an example rate type which must exist and be appropriate in your system.

| Field | What to do for the first trial |
|---|---|
| Dil / Language (`P_LANG`) | **Türkçe (`T`)** for Turkish or **English (`E`)** for English. Default **Otomatik / Logon language (`A`)** follows the logon language. |
| Bulletin date(s) (`S_DATE`) | One past weekday with a published bulletin. |
| Test run (`P_TEST`) | **Keep selected.** |
| Forex buying (`P_FXBUY`) | Example `M`; use an appropriate defined SAP rate type. |
| Other five rate fields | Leave blank initially. Do not assign one rate type to two TCMB fields. |
| Date rule (`P_RULE`) | Select **Same day as the bulletin**. A choice is required; there is no default. |
| Factory calendar (`P_CAL`) | Required only for **Next working day**; use your actual SCAL calendar. `TR` is not present in every system. |
| TCMB currency codes (`S_CURR`) | Limit the trial to `USD` initially; add other codes as individual rows in multiple selection later. |
| Other SAP code (`P_MAP`) | Blank if codes match. `USD=USD2` applies only if that is your actual SAP code. |
| Currency of TCMB rates (`P_TARG`) | `TRY`; no conversion to another target is performed. |
| Also write reverse direction (`P_INV`) | Unselected initially. |
| Existing different rate | Select **Keep it (`R_KEEP`)** for the first trial. The program defaults to Update; check this explicitly. |
| Working day without a bulletin | **Only show it in the list (`R_NBLOG`)**. |
| Source | **From TCMB over HTTPS (`R_HTTP`)**. Leave destination/custom address blank unless your environment needs them. |

**An empty currency selection means all**, not none: every bulletin code is evaluated; currencies unknown to SAP are skipped. Exclusions and code renaming are supported. Use an explicit inclusion list initially. [All fields and date rules](TECHNICAL.md#selection-fields).

### A2. Check connectivity, then preview

1. Click **Test the connection to TCMB**; read and dismiss the message. It searches the last seven days, ignores the selected date and writes nothing.
2. Keep **Test run selected** and press **F8** for your chosen date.
3. Inspect rate type, currency pair, valid-from date, value and factors. `NEW`/`UPDATED` describe planned operations; `UNCHANGED` means equal existing value; `SKIPPED` requires reading the reason; `NO_BULLETIN` is a missing bulletin; resolve `ERROR` before writing.

![Real Turkish result list with an unchanged USD TRY record](docs/images/sap-tr-result-unchanged.png)

This separate example is for **27 October**, with M, USD → TRY, 49.69970 and factors 1:1. It reports `UNCHANGED`. The selection/test flag is not visible, so this image alone neither establishes preview mode nor proves a new write. The project's language choice changes report labels, not SAP standard screens.

After one-day verification, extend the date range or add currencies via multiple selection. Saturdays/Sundays are skipped. [A real Turkish range-selection example and all field explanations](EKRAN_REHBERI.tr.md).

**You can stop here.** For inspection only, keep Test run selected. It does not verify write authorization or commit success. Custom exits must honor the [test-mode side-effect rules](TECHNICAL.md#local-classes-and-extensions).

<a id="first-write"></a>

## Path B — I want to add or update OB08 rates

![Write path: choose policy, preview, exit OB08 maintenance, clear Test run and execute, verify OB08](docs/images/write-path-en.svg)

### B1. Choose the intended effect

| Intention | Existing-rate policy | Behavior |
|---|---|---|
| Add missing records; preserve different existing values | **Keep it** | Inserts missing records, skips different existing values. Use for the first trial. |
| Replace different existing values with TCMB values; also add missing records | **Update it** | Updates differences and inserts missing records. Review the preview first. |

Equal records remain `UNCHANGED` in both modes. Keep it does **not** disable all writes; Test run does.

### B2. Reconcile and preview first

1. Use the authorized sandbox, run the **48 embedded SAP tests** and resolve failures. Complete Path A without unexplained errors or values.
2. Note the result key: **rate type, from currency, to currency, valid-from date**. Example: M / USD / TRY / 2026-10-30.
3. Open `/oOB08` to inspect that key in another session; if a new session is unavailable, note your choices and use `/nOB08`. Do not edit records there.
4. **Exit OB08 maintenance after inspection**, including your other open maintenance sessions. Merely switching windows does not release a maintenance lock. Do not delete another user's active lock.
5. A new-record preview should show `NEW`. An existing equal record needs no rewrite. Do not delete a rate just to manufacture a new-record test.

### B3. Execute the write

1. Return to the report selection screen, preserving the checked date, mappings, currencies and policy.
2. **Clear Test run** and capture the selection screen with this flag visible.
3. Press **F8**. No separate Save or confirmation is required; the report calls the SAP write and commit operations.
4. Inspect and capture results. `NEW` reports an insertion; `UPDATED` reports an update. Mixed `NEW` and `ERROR` means a partially successful run; successes are not automatically rolled back. Use [recovery](#locks-and-partial-writes).

### B4. Verify in OB08, then exit maintenance

Reopen OB08 after execution in the same system/client. Use **Position** or the available selection controls to find the exact key and valid-from date. Compare rate, quotation and factors, expanding shortened columns if necessary.

![Actual OB08 screen showing M EUR TRY records for July 2026](docs/images/sap-ob08-eur-july.png)

The supplied OB08 image shows **M / EUR / TRY**, factors 1:1, including **53.08900 for 1 July** and **54.48410 for 31 July 2026**. These are date-specific examples. It does not establish all USD records or resolution of the failed rows. No manual OB08 save is needed. **Exit maintenance before another report run.** Also verify the expected amount with SAP currency conversion; see [calculation and readback](TECHNICAL.md#dates-and-ratios).

### B5. Repeat without writing

Select Test run again and execute the same choices. Equal records should report `UNCHANGED`. Retain the selection, actual result, OB08 and repeat-preview evidence together.

Writes affect standard **TCURR**; a different Z report name does not isolate records. Commits are per row, not atomic for the range.

<a id="daily-use"></a>

## Path C — I want a daily automatic run

Start after Path B acceptance. A variant stores selections; it does not itself save exchange rates.

1. Save a separate variant, for example `TCMB_DAILY`, including the desired output language.
2. Set `S_DATE` to **D / Dynamic date → Current date** in variant attributes. Do not carry over a fixed historical range/end date from testing.
3. Clear Test run for a write variant and deliberately choose Keep or Update. Reload the variant to check saved values.
4. Schedule `ZCHE_TCMB_LOAD` and this variant in **SM36** after bulletin publication; verify system/job time zones.
5. Monitor the first runs through **SM37**, log/spool and OB08. A cancelled job does not undo earlier successful rows.
6. Transport through the normal customer-package process; verify target connectivity, FI settings, variants and runtime-user permissions separately.

### First rehearse with a one-off preview job

The [illustrated Turkish job guide](WALKTHROUGH.tr.md#gunluk-kullanim) follows every screen from variant creation to job log and spool. The screenshots are real A4H/001 captures from 2 November 2026; SAP standard menus are English and the report output is Turkish.

1. Keep **Test run checked**, choose **Keep**, select your dates/currencies and explicitly choose Turkish. Save a new variant with Ctrl+S; the captured example is `TCMB_DOC_TEST`, with the fixed range 1 July–1 August 2026, USD/EUR, FX buying → M, SAME_DAY and TRY. Reload to inspect selections. Use your own test date and unique names.
2. In **SM36**, enter a new job name; the example is `ZTCMB_DOC_TEST_20261102`, class C. Choose **Step**, ABAP program `ZCHE_TCMB_LOAD`, and your test variant. Save the step and return with F3. Use an appropriately authorized execution user.

![SM36 program and preview variant](docs/images/sap-live-08-sm36-step.png)

3. Choose **Start condition → Immediate**, leave **Periodic Job unchecked**, save the condition, then save the main job. Check the Released confirmation.
4. In **SM37**, filter by your job name/user and execution date. Include Released/Ready/Active/Finished/Canceled, execute and refresh. Include Scheduled too if diagnosing a missing/unreleased job.

![One-off preview job finished in SM37](docs/images/sap-live-14-sm37-finished.png)

5. Select the job row and choose **Job log**. This run finished in 74 seconds and explicitly reports a no-write test: 4 planned new, 0 updated, 40 unchanged, 0 skipped, 1 no-bulletin day, 0 errors.

![Turkish no-write summary in the job log](docs/images/sap-live-15-sm37-job-log.png)

6. Return to the job list; choose **Spool**, then the document icon in the Type column. Inspect the rows; printing is unnecessary. The step language was EN, while the explicit Turkish variant produced Turkish report messages and spool statuses.

![Turkish spool rows with four planned new records](docs/images/sap-live-17-spool-results.png)

**Finished does not prove a write.** The four missing keys (1 July USD, 6 July USD/EUR, 7 July USD) were only planned and remain missing. Daily operation needs a separate dynamic-date variant and, after Path B acceptance, deliberate write settings. For daily scheduling use Date/Time, Periodic Job and Period values → Daily, then save both the condition and main job. Dynamic dates, recurring actual writes and restricted-user execution remain pending acceptance.

<a id="locks-and-partial-writes"></a>

## Recovery — Some rows succeeded and others failed

![Turkish result list with successful writes, E_TABLE lock errors and a missing bulletin](docs/images/sap-tr-range-write-locks.png)

The supplied list contains `NEW`, `ERROR` with `E_TABLE ... locked by user DEVELOPER`, and `NO_BULLETIN` for 15 July. The **Yeni kayıt** descriptions and BAPI lock errors are consistent with a write run. The separately supplied selection image has **Test run checked**; the two images cannot be represented as one proven before/after run.

1. Preserve results and failed keys; do not immediately rerun the whole month with Update.
2. Reconcile successful and failed keys in OB08, then **exit OB08 maintenance**. The supplied **Change View** screen is a plausible lock source, not proof of its cause.
3. Exit your own other maintenance sessions. If the lock persists, ask the owner/administrator to inspect its object and owner in **SM12**. Do not use deletion of an active lock as a generic fix. [SAP lock-management guidance](https://learning.sap.com/courses/technical-implementation-and-operation-i-of-sap-s-4hana-and-sap-business-suite/describing-as-abap).
4. After the cause is resolved, preview only the affected dates/currencies with **Test run selected and Keep it**. Existing equal records remain unchanged, different ones are preserved and missing ones can be identified.
5. Complete missing records through Path B and verify again. Handle deliberately requested updates separately. A missing bulletin is not a lock error and should not be filled with another day's rate automatically.

For commit errors reconcile OB08 and SM13 before retrying. [Technical recovery rules](TECHNICAL.md#errors-and-reruns).

## Read from files

Use only if SAP cannot retrieve TCMB over HTTPS. The source is a folder readable by the **SAP application server**, not your computer's Downloads folder. An automatic downloader is not included.

<details>
<summary>Prepare server files</summary>

1. If authorized, access the server through approved RDP (Windows), SSH (Linux) or managed transfer; otherwise involve the server owner.
2. Stage complete XML files as `DDMMYYYY.xml`. **30 October 2026 is an example:** its file is `30102026.xml`. Use your chosen date and matching bulletin date inside the XML. Place only complete files in the readable folder.
3. Select **From a folder on the server (`R_FILE`)** and enter your real folder in **Folder of the XML files (`P_DIR`)**. Do not copy a fixed example path.
4. Verify OS/SAP read permissions and shared access across application servers/job hosts.
5. Preview the staged file's date. The connection button searches the last seven days; preview an older file by selecting its date directly.

**Missing/unreadable files are `ERROR`.** They do not prove a holiday. No automatic download or source fallback occurs.

</details>

## Other problems

Check the full error, complete source and line-length settings for installation; SAP host HTTPS/STRUST/SM59 for connectivity; OBBS keys and effective factors for rate errors; and the actual server path, filename and permissions for files. [Technical reference](TECHNICAL.md).

<details>
<summary>Optional: install with abapGit</summary>

Import into your customer package, Pull and activate; offline ZIP import is also possible. abapGit imports attributes/text elements but is not required for daily operation. Do not load the same program twice using both methods. Review the [migration notes](TECHNICAL.md#migration-from-the-old-edition) for existing installations.

</details>
