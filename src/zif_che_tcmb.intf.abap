"! <p class="shorttext synchronized">TCMB exchange rates: shared types and constants</p>
"! abap-tcmb-rates, https://github.com/Cheditte/abap-tcmb-rates (MIT License)
INTERFACE zif_che_tcmb PUBLIC.

  CONSTANTS version TYPE string VALUE `0.1.0`.

  "! Address of the TCMB bulletins; one day is &lt;url&gt;/YYYYMM/DDMMYYYY.xml
  CONSTANTS default_url TYPE string VALUE `https://www.tcmb.gov.tr/kurlar`.
  CONSTANTS default_target TYPE waers VALUE 'TRY'.
  CONSTANTS default_source_class TYPE seoclsname VALUE 'ZCL_CHE_TCMB_SOURCE_HTTP'.

  " TCMB rates that can be mapped to an SAP rate type (domain ZCHE_TCMB_SOURCE)
  CONSTANTS:
    BEGIN OF source,
      fx_buy  TYPE zche_tcmb_source VALUE 'FX_BUY',
      fx_sell TYPE zche_tcmb_source VALUE 'FX_SELL',
      bn_buy  TYPE zche_tcmb_source VALUE 'BN_BUY',
      bn_sell TYPE zche_tcmb_source VALUE 'BN_SELL',
      fx_avg  TYPE zche_tcmb_source VALUE 'FX_AVG',
      bn_avg  TYPE zche_tcmb_source VALUE 'BN_AVG',
    END OF source.

  " Which day a bulletin is written for (domain ZCHE_TCMB_DATE_RULE)
  CONSTANTS:
    BEGIN OF date_rule,
      same_day     TYPE zche_tcmb_date_rule VALUE 'SAME_DAY',
      next_day     TYPE zche_tcmb_date_rule VALUE 'NEXT_DAY',
      next_workday TYPE zche_tcmb_date_rule VALUE 'NEXT_WORKDAY',
    END OF date_rule.

  " What to do when TCURR already has a rate for that day
  CONSTANTS:
    BEGIN OF existing,
      skip   TYPE zche_tcmb_existing VALUE 'S',
      update TYPE zche_tcmb_existing VALUE 'U',
    END OF existing.

  " What a day without a bulletin means for the run
  CONSTANTS:
    BEGIN OF no_bulletin,
      log     TYPE zche_tcmb_nodata VALUE 'I',
      warning TYPE zche_tcmb_nodata VALUE 'W',
      error   TYPE zche_tcmb_nodata VALUE 'E',
    END OF no_bulletin.

  TYPES ty_status TYPE c LENGTH 12.

  " Result of one line
  CONSTANTS:
    BEGIN OF status,
      new         TYPE ty_status VALUE 'NEW',
      updated     TYPE ty_status VALUE 'UPDATED',
      unchanged   TYPE ty_status VALUE 'UNCHANGED',
      skipped     TYPE ty_status VALUE 'SKIPPED',
      no_bulletin TYPE ty_status VALUE 'NO_BULLETIN',
      error       TYPE ty_status VALUE 'ERROR',
    END OF status.

  TYPES ty_value TYPE decfloat34.

  " One currency of a bulletin; an initial value means TCMB gave none
  TYPES:
    BEGIN OF ty_rate,
      code    TYPE zche_tcmb_code,
      unit    TYPE i,
      fx_buy  TYPE ty_value,
      fx_sell TYPE ty_value,
      bn_buy  TYPE ty_value,
      bn_sell TYPE ty_value,
    END OF ty_rate,
    ty_rates TYPE STANDARD TABLE OF ty_rate WITH DEFAULT KEY,
    BEGIN OF ty_bulletin,
      date   TYPE d,
      number TYPE string,
      rates  TYPE ty_rates,
    END OF ty_bulletin.

  " One TCURR entry and what happened to it.
  " RATE is always positive; INDIRECT marks an entry from the target
  " currency to the foreign currency, which TCURR stores with a minus sign.
  TYPES:
    BEGIN OF ty_line,
      bulletin_date TYPE d,
      tcmb_code     TYPE zche_tcmb_code,
      source        TYPE zche_tcmb_source,
      rate_type     TYPE tcurr-kurst,
      from_curr     TYPE tcurr-fcurr,
      to_curr       TYPE tcurr-tcurr,
      valid_from    TYPE d,
      rate          TYPE tcurr-ukurs,
      from_factor   TYPE tcurr-ffact,
      to_factor     TYPE tcurr-tfact,
      indirect      TYPE abap_bool,
      status        TYPE ty_status,
      message       TYPE string,
    END OF ty_line,
    ty_lines TYPE STANDARD TABLE OF ty_line WITH DEFAULT KEY.

  " TCURF ratio valid on the day of the entry
  TYPES:
    BEGIN OF ty_factor,
      kurst TYPE tcurf-kurst,
      fcurr TYPE tcurf-fcurr,
      tcurr TYPE tcurf-tcurr,
      ffact TYPE tcurf-ffact,
      tfact TYPE tcurf-tfact,
    END OF ty_factor,
    ty_factors        TYPE SORTED TABLE OF ty_factor WITH UNIQUE KEY kurst fcurr tcurr,
    ty_currency_codes TYPE SORTED TABLE OF waers WITH UNIQUE KEY table_line.

  TYPES:
    ty_profile    TYPE zche_tcmb_prof,
    ty_mappings   TYPE STANDARD TABLE OF zche_tcmb_map WITH DEFAULT KEY,
    ty_currencies TYPE STANDARD TABLE OF zche_tcmb_curr WITH DEFAULT KEY.

ENDINTERFACE.
