*&---------------------------------------------------------------------*
*& ZCHE_TCMB_LOAD: load TCMB exchange rates into TCURR
*& abap-tcmb-rates, https://github.com/Cheditte/abap-tcmb-rates
*& MIT License, Copyright (c) 2026 Ali Emre Altuntas
*&---------------------------------------------------------------------*
*& One program, nothing else to create: copy it into SE38 and activate.
*& All settings are on the selection screen; save them as a variant.
*& Run it as a background job on working days after 15:30, when TCMB
*& publishes. In the background an error ends the job as "Cancelled".
*& Your own rules: class LCL_EXIT below.
*&
*& Classic ABAP syntax target: SAP_BASIS 7.00 (ECC 6.0). Runtime on that
*& release still needs acceptance: no inline declarations, constructor
*& expressions or string templates.
*&---------------------------------------------------------------------*
REPORT zche_tcmb_load.

TYPE-POOLS: abap, vrm.

TABLES sscrfields.


"! Shared types and constants
INTERFACE lif_tcmb.

  CONSTANTS version TYPE string VALUE `0.3.0`.

  "! Address of the TCMB bulletins; one day is &lt;url&gt;/YYYYMM/DDMMYYYY.xml
  CONSTANTS default_url TYPE string VALUE `https://www.tcmb.gov.tr/kurlar`.
  CONSTANTS default_target TYPE waers VALUE 'TRY'.

  TYPES ty_code TYPE c LENGTH 3.
  TYPES ty_source TYPE c LENGTH 10.
  TYPES ty_date_rule TYPE c LENGTH 12.

  " TCMB rates that can be mapped to an SAP rate type
  CONSTANTS:
    BEGIN OF source,
      fx_buy  TYPE ty_source VALUE 'FX_BUY',
      fx_sell TYPE ty_source VALUE 'FX_SELL',
      bn_buy  TYPE ty_source VALUE 'BN_BUY',
      bn_sell TYPE ty_source VALUE 'BN_SELL',
      fx_avg  TYPE ty_source VALUE 'FX_AVG',
      bn_avg  TYPE ty_source VALUE 'BN_AVG',
    END OF source.

  " Which day a bulletin is written for
  CONSTANTS:
    BEGIN OF date_rule,
      same_day     TYPE ty_date_rule VALUE 'SAME_DAY',
      next_day     TYPE ty_date_rule VALUE 'NEXT_DAY',
      next_workday TYPE ty_date_rule VALUE 'NEXT_WORKDAY',
    END OF date_rule.

  " What to do when TCURR already has a rate for that day
  CONSTANTS:
    BEGIN OF existing,
      skip   TYPE c LENGTH 1 VALUE 'S',
      update TYPE c LENGTH 1 VALUE 'U',
    END OF existing.

  " What a day without a bulletin means for the run
  CONSTANTS:
    BEGIN OF no_bulletin,
      log     TYPE c LENGTH 1 VALUE 'I',
      warning TYPE c LENGTH 1 VALUE 'W',
      error   TYPE c LENGTH 1 VALUE 'E',
    END OF no_bulletin.

  " Where the bulletin comes from
  CONSTANTS:
    BEGIN OF origin,
      https  TYPE c LENGTH 6 VALUE 'HTTPS',
      folder TYPE c LENGTH 6 VALUE 'FOLDER',
    END OF origin.

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

  " A TCMB value. Packed, because DECFLOAT34 needs release 7.02
  TYPES ty_value TYPE p LENGTH 16 DECIMALS 10.

  " One currency of a bulletin; an initial value means TCMB gave none
  TYPES:
    BEGIN OF ty_rate,
      code    TYPE ty_code,
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
      tcmb_code     TYPE ty_code,
      source        TYPE ty_source,
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

  " Which TCMB rate goes into which SAP rate type
  TYPES:
    BEGIN OF ty_mapping,
      rate_type TYPE tcurr-kurst,
      source    TYPE ty_source,
    END OF ty_mapping,
    ty_mappings TYPE STANDARD TABLE OF ty_mapping WITH DEFAULT KEY.

  " A TCMB code that has another code in SAP, for example USD = USD2
  TYPES:
    BEGIN OF ty_rename,
      tcmb_code    TYPE ty_code,
      sap_currency TYPE waers,
    END OF ty_rename,
    ty_renames    TYPE SORTED TABLE OF ty_rename WITH UNIQUE KEY tcmb_code,
    ty_code_range TYPE RANGE OF ty_code.

  " Everything the selection screen holds
  TYPES:
    BEGIN OF ty_settings,
      mappings         TYPE ty_mappings,
      date_rule        TYPE ty_date_rule,
      factory_calendar TYPE wfcid,
      target_currency  TYPE waers,
      codes            TYPE ty_code_range,
      renames          TYPE ty_renames,
      write_inverse    TYPE abap_bool,
      existing_rate    TYPE c LENGTH 1,
      no_bulletin      TYPE c LENGTH 1,
      origin           TYPE c LENGTH 6,
      rfc_destination  TYPE rfcdest,
      base_url         TYPE string,
      file_folder      TYPE string,
    END OF ty_settings.

ENDINTERFACE.


"! Values as text for messages (string templates need release 7.02)
CLASS lcl_fmt DEFINITION FINAL.
  PUBLIC SECTION.
    "! 2026-10-30
    CLASS-METHODS date
      IMPORTING
        iv_date        TYPE d
      RETURNING
        value(rv_text) TYPE string.

    CLASS-METHODS int
      IMPORTING
        iv_int         TYPE i
      RETURNING
        value(rv_text) TYPE string.

    "! A number without trailing zeros, for example 49.7747
    CLASS-METHODS num
      IMPORTING
        iv_num         TYPE numeric
      RETURNING
        value(rv_text) TYPE string.
ENDCLASS.



CLASS lcl_fmt IMPLEMENTATION.

  METHOD date.
    CONCATENATE iv_date(4) '-' iv_date+4(2) '-' iv_date+6(2) INTO rv_text.
  ENDMETHOD.


  METHOD int.
    rv_text = iv_int.
    CONDENSE rv_text.
  ENDMETHOD.


  METHOD num.
    rv_text = iv_num.
    CONDENSE rv_text.
    IF rv_text CA '.'.
      SHIFT rv_text RIGHT DELETING TRAILING '0'.
      SHIFT rv_text RIGHT DELETING TRAILING '.'.
      CONDENSE rv_text.
    ENDIF.
  ENDMETHOD.

ENDCLASS.


"! Error. KIND tells what went wrong, so callers can react (for example a
"! day without a bulletin is not an error); the text says who can fix it.
CLASS lcx_tcmb DEFINITION INHERITING FROM cx_static_check FINAL.
  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF kinds,
        config      TYPE string VALUE `CONFIG`,
        connection  TYPE string VALUE `CONNECTION`,
        ssl         TYPE string VALUE `SSL`,
        http        TYPE string VALUE `HTTP`,
        no_bulletin TYPE string VALUE `NO_BULLETIN`,
        parse       TYPE string VALUE `PARSE`,
        file        TYPE string VALUE `FILE`,
      END OF kinds.

    DATA kind TYPE string READ-ONLY.
    DATA text TYPE string READ-ONLY.

    METHODS constructor
      IMPORTING
        kind     TYPE string OPTIONAL
        text     TYPE string OPTIONAL
        previous TYPE REF TO cx_root OPTIONAL.

    METHODS if_message~get_text REDEFINITION.
ENDCLASS.



CLASS lcx_tcmb IMPLEMENTATION.

  METHOD constructor.
    super->constructor( previous = previous ).
    me->kind = kind.
    me->text = text.
  ENDMETHOD.


  METHOD if_message~get_text.
    result = text.
    IF result IS INITIAL.
      result = super->if_message~get_text( ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.


"! Your own rules: change here. Both methods are called for each day,
"! also in a test run. Nothing happens as long as they stay empty.
CLASS lcl_exit DEFINITION FINAL.
  PUBLIC SECTION.
    "! Before the lines are compared with TCURR. Lines can be changed,
    "! added or removed; a line with an initial STATUS is written, a line
    "! with STATUS = ERROR is not.
    METHODS before_write
      IMPORTING
        is_settings TYPE lif_tcmb=>ty_settings
      CHANGING
        ct_lines    TYPE lif_tcmb=>ty_lines.

    "! After writing. In test mode, suppress writes and external effects.
    METHODS after_write
      IMPORTING
        is_settings TYPE lif_tcmb=>ty_settings
        it_lines    TYPE lif_tcmb=>ty_lines
        iv_test     TYPE abap_bool.
ENDCLASS.



CLASS lcl_exit IMPLEMENTATION.

  METHOD before_write.                                      "#EC NEEDED
  ENDMETHOD.


  METHOD after_write.                                       "#EC NEEDED
  ENDMETHOD.

ENDCLASS.


"! Reads one bulletin XML
CLASS lcl_parser DEFINITION FINAL.
  PUBLIC SECTION.
    "! Reads a bulletin such as kurlar/202610/30102026.xml
    METHODS parse
      IMPORTING
        iv_xml             TYPE xstring
      RETURNING
        value(rs_bulletin) TYPE lif_tcmb=>ty_bulletin
      RAISING
        lcx_tcmb.

  PRIVATE SECTION.
    METHODS child_text
      IMPORTING
        io_element     TYPE REF TO if_ixml_element
        iv_name        TYPE string
      RETURNING
        value(rv_text) TYPE string.

    METHODS child_value
      IMPORTING
        io_element      TYPE REF TO if_ixml_element
        iv_name         TYPE string
      RETURNING
        value(rv_value) TYPE lif_tcmb=>ty_value
      RAISING
        lcx_tcmb.

    METHODS to_unit
      IMPORTING
        iv_text        TYPE string
      RETURNING
        value(rv_unit) TYPE i
      RAISING
        lcx_tcmb.

    METHODS to_date
      IMPORTING
        iv_text        TYPE string
      RETURNING
        value(rv_date) TYPE d
      RAISING
        lcx_tcmb.

    METHODS parse_error
      IMPORTING
        iv_text TYPE string
      RAISING
        lcx_tcmb.
ENDCLASS.



CLASS lcl_parser IMPLEMENTATION.

  METHOD parse.
    DATA lo_ixml TYPE REF TO if_ixml.
    DATA lo_factory TYPE REF TO if_ixml_stream_factory.
    DATA lo_stream TYPE REF TO if_ixml_istream.
    DATA lo_document TYPE REF TO if_ixml_document.
    DATA lo_parser TYPE REF TO if_ixml_parser.
    DATA lo_root TYPE REF TO if_ixml_element.
    DATA lo_list TYPE REF TO if_ixml_node_collection.
    DATA lo_currency TYPE REF TO if_ixml_element.
    DATA lo_node TYPE REF TO if_ixml_node.
    DATA lv_count TYPE i.
    DATA lv_index TYPE i.
    DATA lv_text TYPE string.
    DATA ls_rate TYPE lif_tcmb=>ty_rate.

    lo_ixml = cl_ixml=>create( ).
    lo_factory = lo_ixml->create_stream_factory( ).
    lo_document = lo_ixml->create_document( ).
    lo_stream = lo_factory->create_istream_xstring( iv_xml ).
    lo_parser = lo_ixml->create_parser( stream_factory = lo_factory
                                        istream        = lo_stream
                                        document       = lo_document ).
    IF lo_parser->parse( ) <> 0.
      parse_error( `The TCMB answer is not valid XML` ).
    ENDIF.

    lo_root = lo_document->get_root_element( ).
    IF lo_root IS NOT BOUND.
      parse_error( `The TCMB answer is not an exchange rate bulletin` ).
    ENDIF.
    IF lo_root->get_name( ) <> `Tarih_Date`.
      parse_error( `The TCMB answer is not an exchange rate bulletin` ).
    ENDIF.

    lv_text = lo_root->get_attribute( name = `Tarih` ).
    rs_bulletin-date   = to_date( lv_text ).
    rs_bulletin-number = lo_root->get_attribute( name = `Bulten_No` ).

    lo_list = lo_root->get_elements_by_tag_name( name = `Currency` ).
    lv_count = lo_list->get_length( ).
    DO lv_count TIMES.
      lv_index = sy-index - 1.
      lo_node = lo_list->get_item( lv_index ).
      lo_currency ?= lo_node.
      CLEAR ls_rate.
      lv_text = lo_currency->get_attribute( name = `CurrencyCode` ).
      TRANSLATE lv_text TO UPPER CASE.
      IF strlen( lv_text ) <> 3 OR lv_text CN 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
        parse_error( `CurrencyCode must contain exactly three letters` ).
      ENDIF.
      ls_rate-code = lv_text.
      READ TABLE rs_bulletin-rates TRANSPORTING NO FIELDS WITH KEY code = ls_rate-code.
      IF sy-subrc = 0.
        parse_error( `The TCMB bulletin contains a duplicate currency code` ).
      ENDIF.
      lv_text = child_text( io_element = lo_currency iv_name = `Unit` ).
      ls_rate-unit = to_unit( lv_text ).
      ls_rate-fx_buy  = child_value( io_element = lo_currency iv_name = `ForexBuying` ).
      ls_rate-fx_sell = child_value( io_element = lo_currency iv_name = `ForexSelling` ).
      ls_rate-bn_buy  = child_value( io_element = lo_currency iv_name = `BanknoteBuying` ).
      ls_rate-bn_sell = child_value( io_element = lo_currency iv_name = `BanknoteSelling` ).
      APPEND ls_rate TO rs_bulletin-rates.
    ENDDO.

    IF rs_bulletin-rates IS INITIAL.
      parse_error( `The TCMB bulletin contains no currencies` ).
    ENDIF.
  ENDMETHOD.


  METHOD child_text.
    DATA lo_child TYPE REF TO if_ixml_element.
    lo_child = io_element->find_from_name( name = iv_name ).
    IF lo_child IS BOUND.
      rv_text = lo_child->get_value( ).
      CONDENSE rv_text.
    ENDIF.
  ENDMETHOD.


  METHOD child_value.
    DATA lv_text TYPE string.
    DATA lv_message TYPE string.
    lv_text = child_text( io_element = io_element iv_name = iv_name ).
    IF lv_text IS INITIAL.
      RETURN.
    ENDIF.
    FIND REGEX '^[0-9]+([.][0-9]+)?$' IN lv_text.
    IF sy-subrc <> 0.
      parse_error( `A supplied TCMB rate must be a positive decimal number` ).
    ENDIF.
    TRY.
        rv_value = lv_text.
      CATCH cx_sy_conversion_error.
        CONCATENATE `"` lv_text `" in the TCMB bulletin is not a number` INTO lv_message.
        parse_error( lv_message ).
    ENDTRY.
    IF rv_value <= 0.
      parse_error( `A supplied TCMB rate must be greater than zero` ).
    ENDIF.
  ENDMETHOD.


  METHOD to_unit.
    DATA lv_message TYPE string.
    IF iv_text IS INITIAL OR iv_text CN '0123456789'.
      parse_error( `Unit must be a positive whole number` ).
    ENDIF.
    TRY.
        rv_unit = iv_text.
      CATCH cx_sy_conversion_error.
        CONCATENATE `Unit "` iv_text `" in the TCMB bulletin is not a number` INTO lv_message.
        parse_error( lv_message ).
    ENDTRY.
    IF rv_unit <= 0.
      CONCATENATE `Unit "` iv_text `" in the TCMB bulletin is not positive` INTO lv_message.
      parse_error( lv_message ).
    ENDIF.
  ENDMETHOD.


  METHOD to_date.
    " TCMB writes the date as DD.MM.YYYY
    DATA lv_message TYPE string.
    IF strlen( iv_text ) <> 10 OR iv_text CN '0123456789.'.
      CONCATENATE `Bulletin date "` iv_text `" is not DD.MM.YYYY` INTO lv_message.
      parse_error( lv_message ).
    ENDIF.
    IF iv_text+2(1) <> '.' OR iv_text+5(1) <> '.'.
      CONCATENATE `Bulletin date "` iv_text `" is not DD.MM.YYYY` INTO lv_message.
      parse_error( lv_message ).
    ENDIF.
    CONCATENATE iv_text+6(4) iv_text+3(2) iv_text(2) INTO rv_date.
    CALL FUNCTION 'DATE_CHECK_PLAUSIBILITY'
      EXPORTING date = rv_date
      EXCEPTIONS OTHERS = 1.
    IF sy-subrc <> 0.
      parse_error( `The bulletin contains an invalid calendar date` ).
    ENDIF.
  ENDMETHOD.


  METHOD parse_error.
    RAISE EXCEPTION TYPE lcx_tcmb
      EXPORTING
        kind = lcx_tcmb=>kinds-parse
        text = iv_text.
  ENDMETHOD.

ENDCLASS.


"! Where the bulletin comes from
INTERFACE lif_source.
  "! Returns the bulletin of one day as UTF-8 XML
  "! @raising lcx_tcmb | KIND = NO_BULLETIN when TCMB published nothing that day
  METHODS get_bulletin
    IMPORTING
      iv_date       TYPE d
      is_settings   TYPE lif_tcmb=>ty_settings
    RETURNING
      value(rv_xml) TYPE xstring
    RAISING
      lcx_tcmb.
ENDINTERFACE.


"! Bulletin over HTTPS. With an SM59 HTTP destination (host
"! www.tcmb.gov.tr, port 443, SSL active, no path prefix) proxy and SSL
"! settings stay with Basis. Without one, the base URL or the TCMB address
"! is used with the SSL client PSE "Anonymous" (STRUST).
CLASS lcl_source_http DEFINITION FINAL.
  PUBLIC SECTION.
    INTERFACES lif_source.

    "! Path of one day below the base URL: YYYYMM/DDMMYYYY.xml
    CLASS-METHODS day_path
      IMPORTING
        iv_date        TYPE d
      RETURNING
        value(rv_path) TYPE string.

  PRIVATE SECTION.
    METHODS create_client
      IMPORTING
        iv_date          TYPE d
        is_settings      TYPE lif_tcmb=>ty_settings
      RETURNING
        value(ro_client) TYPE REF TO if_http_client
      RAISING
        lcx_tcmb.

    METHODS raise_communication_error
      IMPORTING
        io_client TYPE REF TO if_http_client
      RAISING
        lcx_tcmb.
ENDCLASS.



CLASS lcl_source_http IMPLEMENTATION.

  METHOD lif_source~get_bulletin.
    DATA lo_client TYPE REF TO if_http_client.
    DATA lv_code TYPE i.
    DATA lv_reason TYPE string.
    DATA lv_text TYPE string.
    DATA lv_date TYPE string.
    DATA lv_number TYPE string.

    lo_client = create_client( iv_date = iv_date is_settings = is_settings ).

    lo_client->request->set_method( if_http_request=>co_request_method_get ).
    lo_client->send( EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc <> 0.
      raise_communication_error( lo_client ).
    ENDIF.
    lo_client->receive( EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc <> 0.
      raise_communication_error( lo_client ).
    ENDIF.

    lo_client->response->get_status( IMPORTING code = lv_code reason = lv_reason ).
    rv_xml = lo_client->response->get_data( ).
    lo_client->close( ).

    lv_date = lcl_fmt=>date( iv_date ).
    CASE lv_code.
      WHEN 200.
        RETURN.
      WHEN 404.
        CONCATENATE `TCMB has no bulletin for ` lv_date ` (weekend, holiday, `
                    `or not published yet; TCMB publishes on working days at 15:30)` INTO lv_text.
        RAISE EXCEPTION TYPE lcx_tcmb
          EXPORTING
            kind = lcx_tcmb=>kinds-no_bulletin
            text = lv_text.
      WHEN OTHERS.
        lv_number = lcl_fmt=>int( lv_code ).
        CONCATENATE `TCMB answered HTTP ` lv_number ` ` lv_reason ` for ` lv_date INTO lv_text.
        RAISE EXCEPTION TYPE lcx_tcmb
          EXPORTING
            kind = lcx_tcmb=>kinds-http
            text = lv_text.
    ENDCASE.
  ENDMETHOD.


  METHOD day_path.
    CONCATENATE iv_date(6) '/' iv_date+6(2) iv_date+4(2) iv_date(4) '.xml' INTO rv_path.
  ENDMETHOD.


  METHOD create_client.
    DATA lv_base TYPE string.
    DATA lv_url TYPE string.
    DATA lv_path TYPE string.
    DATA lv_text TYPE string.
    DATA lv_destination TYPE string.

    lv_path = day_path( iv_date ).
    IF is_settings-rfc_destination IS NOT INITIAL.
      cl_http_client=>create_by_destination(
        EXPORTING
          destination = is_settings-rfc_destination
        IMPORTING
          client      = ro_client
        EXCEPTIONS
          OTHERS      = 1 ).
      IF sy-subrc <> 0.
        lv_destination = is_settings-rfc_destination.
        CONCATENATE `HTTP destination ` lv_destination ` cannot be used; check it in SM59` INTO lv_text.
        RAISE EXCEPTION TYPE lcx_tcmb
          EXPORTING
            kind = lcx_tcmb=>kinds-config
            text = lv_text.
      ENDIF.
      CONCATENATE `/kurlar/` lv_path INTO lv_url.
      cl_http_utility=>set_request_uri( request = ro_client->request
                                        uri     = lv_url ).
      RETURN.
    ENDIF.

    IF is_settings-base_url IS INITIAL.
      lv_base = lif_tcmb=>default_url.
    ELSE.
      lv_base = is_settings-base_url.
      CONDENSE lv_base.
    ENDIF.
    CONCATENATE lv_base `/` lv_path INTO lv_url.
    cl_http_client=>create_by_url(
      EXPORTING
        url    = lv_url
        ssl_id = 'ANONYM'
      IMPORTING
        client = ro_client
      EXCEPTIONS
        OTHERS = 1 ).
    IF sy-subrc <> 0.
      CONCATENATE `Cannot create an HTTP client for ` lv_url ` (is the ICM HTTPS plug-in active?)` INTO lv_text.
      RAISE EXCEPTION TYPE lcx_tcmb
        EXPORTING
          kind = lcx_tcmb=>kinds-config
          text = lv_text.
    ENDIF.
  ENDMETHOD.


  METHOD raise_communication_error.
    DATA lv_message TYPE string.
    DATA lv_upper TYPE string.
    DATA lv_text TYPE string.

    io_client->get_last_error( IMPORTING message = lv_message ).
    io_client->close( ).

    lv_upper = lv_message.
    TRANSLATE lv_upper TO UPPER CASE.
    IF lv_upper CS 'SSL' OR lv_upper CS 'CERTIFICATE' OR lv_upper CS 'HANDSHAKE' OR lv_upper CS 'PSE'.
      CONCATENATE `Secure connection to TCMB failed (` lv_message `). Verify the current `
                  `certificate chain in STRUST, SSL client Anonymous `
                  `(or the PSE of the SM59 destination)` INTO lv_text.
      RAISE EXCEPTION TYPE lcx_tcmb
        EXPORTING
          kind = lcx_tcmb=>kinds-ssl
          text = lv_text.
    ENDIF.
    CONCATENATE `SAP cannot reach TCMB (` lv_message `). Network team: allow outbound HTTPS `
                `from the SAP host to www.tcmb.gov.tr:443, or use a proxy in an SM59 destination` INTO lv_text.
    RAISE EXCEPTION TYPE lcx_tcmb
      EXPORTING
        kind = lcx_tcmb=>kinds-connection
        text = lv_text.
  ENDMETHOD.

ENDCLASS.


"! Bulletin from a folder on the application server, for SAP systems that
"! cannot reach TCMB: a scheduled task on the SAP host (or a share) saves
"! each bulletin there as DDMMYYYY.xml.
CLASS lcl_source_file DEFINITION FINAL.
  PUBLIC SECTION.
    INTERFACES lif_source.

    "! Full name of the file of one day
    CLASS-METHODS file_name
      IMPORTING
        iv_folder      TYPE csequence
        iv_date        TYPE d
      RETURNING
        value(rv_file) TYPE string.
ENDCLASS.



CLASS lcl_source_file IMPLEMENTATION.

  METHOD lif_source~get_bulletin.
    DATA lv_file TYPE string.
    DATA lv_os_message TYPE c LENGTH 100.
    DATA lv_os_text TYPE string.
    DATA lv_error TYPE string.
    DATA lv_text TYPE string.
    DATA lx_open TYPE REF TO cx_root.
    DATA lx_read TYPE REF TO cx_root.

    IF is_settings-file_folder IS INITIAL.
      RAISE EXCEPTION TYPE lcx_tcmb
        EXPORTING
          kind = lcx_tcmb=>kinds-config
          text = `Enter the folder of the bulletin files on the selection screen`.
    ENDIF.

    lv_file = file_name( iv_folder = is_settings-file_folder iv_date = iv_date ).
    TRY.
        OPEN DATASET lv_file FOR INPUT IN BINARY MODE MESSAGE lv_os_message.
      CATCH cx_sy_file_authority cx_sy_file_open cx_sy_file_access_error INTO lx_open.
        lv_error = lx_open->get_text( ).
        CONCATENATE `Cannot open ` lv_file `: ` lv_error INTO lv_text.
        RAISE EXCEPTION TYPE lcx_tcmb
          EXPORTING
            kind     = lcx_tcmb=>kinds-file
            text     = lv_text
            previous = lx_open.
    ENDTRY.
    IF sy-subrc <> 0.
      lv_os_text = lv_os_message.
      CONDENSE lv_os_text.
      CONCATENATE `Cannot open file ` lv_file ` (` lv_os_text `). Check the download, `
                  `server folder and read permissions; a missing file does not prove a holiday` INTO lv_text.
      RAISE EXCEPTION TYPE lcx_tcmb
        EXPORTING
          kind = lcx_tcmb=>kinds-file
          text = lv_text.
    ENDIF.

    TRY.
        READ DATASET lv_file INTO rv_xml.
      CATCH cx_sy_file_io INTO lx_read.
        CLOSE DATASET lv_file.
        lv_error = lx_read->get_text( ).
        CONCATENATE `Cannot read ` lv_file `: ` lv_error INTO lv_text.
        RAISE EXCEPTION TYPE lcx_tcmb
          EXPORTING
            kind     = lcx_tcmb=>kinds-file
            text     = lv_text
            previous = lx_read.
    ENDTRY.
    CLOSE DATASET lv_file.
  ENDMETHOD.


  METHOD file_name.
    DATA lv_folder TYPE string.
    DATA lv_separator TYPE string.
    DATA lv_last TYPE i.

    lv_folder = iv_folder.
    SHIFT lv_folder LEFT DELETING LEADING space.
    SHIFT lv_folder RIGHT DELETING TRAILING space.
    IF lv_folder CA '\'.
      lv_separator = `\`.
    ELSE.
      lv_separator = `/`.
    ENDIF.
    IF lv_folder IS NOT INITIAL.
      lv_last = strlen( lv_folder ) - 1.
      IF lv_folder+lv_last(1) <> lv_separator.
        CONCATENATE lv_folder lv_separator INTO lv_folder.
      ENDIF.
    ENDIF.
    CONCATENATE lv_folder iv_date+6(2) iv_date+4(2) iv_date(4) '.xml' INTO rv_file.
  ENDMETHOD.

ENDCLASS.


"! Valid-from date of a bulletin. SAME_DAY: the bulletin date. NEXT_DAY:
"! the calendar day after it. NEXT_WORKDAY: the first working day after
"! it in a factory calendar.
CLASS lcl_date_rule DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS constructor
      IMPORTING
        iv_rule     TYPE lif_tcmb=>ty_date_rule
        iv_calendar TYPE wfcid OPTIONAL
      RAISING
        lcx_tcmb.

    "! The TCURR valid-from date for a bulletin published on IV_BULLETIN_DATE
    METHODS valid_from
      IMPORTING
        iv_bulletin_date TYPE d
      RETURNING
        value(rv_date)   TYPE d
      RAISING
        lcx_tcmb.

  PRIVATE SECTION.
    DATA mv_rule TYPE lif_tcmb=>ty_date_rule.
    DATA mv_calendar TYPE wfcid.
ENDCLASS.



CLASS lcl_date_rule IMPLEMENTATION.

  METHOD constructor.
    DATA lv_text TYPE string.
    DATA lv_rule TYPE string.

    IF iv_rule IS INITIAL.
      RAISE EXCEPTION TYPE lcx_tcmb
        EXPORTING
          kind = lcx_tcmb=>kinds-config
          text = `Choose a date rule; ask accounting which day a bulletin is valid for`.
    ENDIF.
    IF iv_rule <> lif_tcmb=>date_rule-same_day
       AND iv_rule <> lif_tcmb=>date_rule-next_day
       AND iv_rule <> lif_tcmb=>date_rule-next_workday.
      lv_rule = iv_rule.
      CONCATENATE `Unknown date rule "` lv_rule `"; use SAME_DAY, NEXT_DAY or NEXT_WORKDAY` INTO lv_text.
      RAISE EXCEPTION TYPE lcx_tcmb
        EXPORTING
          kind = lcx_tcmb=>kinds-config
          text = lv_text.
    ENDIF.
    IF iv_rule = lif_tcmb=>date_rule-next_workday AND iv_calendar IS INITIAL.
      RAISE EXCEPTION TYPE lcx_tcmb
        EXPORTING
          kind = lcx_tcmb=>kinds-config
          text = `Date rule NEXT_WORKDAY needs a factory calendar`.
    ENDIF.
    mv_rule     = iv_rule.
    mv_calendar = iv_calendar.
  ENDMETHOD.


  METHOD valid_from.
    DATA lv_next_day TYPE d.
    DATA lv_text TYPE string.
    DATA lv_date TYPE string.
    DATA lv_calendar TYPE string.

    CASE mv_rule.
      WHEN lif_tcmb=>date_rule-same_day.
        rv_date = iv_bulletin_date.

      WHEN lif_tcmb=>date_rule-next_day.
        rv_date = iv_bulletin_date + 1.

      WHEN lif_tcmb=>date_rule-next_workday.
        " '+' moves a non-working day forward to the next working day
        lv_next_day = iv_bulletin_date + 1.
        CALL FUNCTION 'DATE_CONVERT_TO_FACTORYDATE'
          EXPORTING
            correct_option      = '+'
            date                = lv_next_day
            factory_calendar_id = mv_calendar
          IMPORTING
            date                = rv_date
          EXCEPTIONS
            OTHERS              = 1.
        IF sy-subrc <> 0.
          lv_date = lcl_fmt=>date( iv_bulletin_date ).
          lv_calendar = mv_calendar.
          CONCATENATE `Factory calendar ` lv_calendar ` gives no working day after `
                      lv_date ` (check it in SCAL)` INTO lv_text.
          RAISE EXCEPTION TYPE lcx_tcmb
            EXPORTING
              kind = lcx_tcmb=>kinds-config
              text = lv_text.
        ENDIF.
    ENDCASE.
  ENDMETHOD.

ENDCLASS.


"! Turns a bulletin into TCURR lines. No database access: the caller
"! passes the TCURF ratios and the currencies known to SAP, so every rule
"! here can be unit tested.
CLASS lcl_calc DEFINITION FINAL.
  PUBLIC SECTION.
    "! One line per mapped rate type and currency; a line that cannot be
    "! written gets STATUS SKIPPED or ERROR and a MESSAGE saying why
    "! @parameter it_factors | TCURF ratios valid on IV_VALID_FROM
    "! @parameter it_known | currency codes defined in SAP (TCURC)
    METHODS build_lines
      IMPORTING
        is_bulletin     TYPE lif_tcmb=>ty_bulletin
        is_settings     TYPE lif_tcmb=>ty_settings
        iv_valid_from   TYPE d
        it_factors      TYPE lif_tcmb=>ty_factors
        it_known        TYPE lif_tcmb=>ty_currency_codes
      RETURNING
        value(rt_lines) TYPE lif_tcmb=>ty_lines.

    "! SAP currency for a TCMB code; initial if the code is not wanted
    METHODS sap_currency
      IMPORTING
        iv_code         TYPE lif_tcmb=>ty_code
        is_settings     TYPE lif_tcmb=>ty_settings
      RETURNING
        value(rv_waers) TYPE waers.

    "! Value of one TCMB rate; initial when TCMB gives none
    METHODS pick
      IMPORTING
        is_rate         TYPE lif_tcmb=>ty_rate
        iv_source       TYPE lif_tcmb=>ty_source
      RETURNING
        value(rv_value) TYPE lif_tcmb=>ty_value.

    "! Reads "USD=USD2; XAU=GLD": TCMB codes that have another code in SAP.
    "! Pairs are separated by semicolons, commas or spaces.
    CLASS-METHODS parse_renames
      IMPORTING
        iv_text           TYPE csequence
      RETURNING
        value(rt_renames) TYPE lif_tcmb=>ty_renames
      RAISING
        lcx_tcmb.

  PRIVATE SECTION.
    METHODS add_line
      IMPORTING
        is_line    TYPE lif_tcmb=>ty_line
        iv_value   TYPE lif_tcmb=>ty_value
        iv_unit    TYPE i
        it_factors TYPE lif_tcmb=>ty_factors
      CHANGING
        ct_lines   TYPE lif_tcmb=>ty_lines.
ENDCLASS.



CLASS lcl_calc IMPLEMENTATION.

  METHOD build_lines.
    DATA lv_target TYPE waers.
    DATA lv_waers TYPE waers.
    DATA lv_value TYPE lif_tcmb=>ty_value.
    DATA lv_source TYPE string.
    DATA lv_code TYPE string.
    DATA ls_rate TYPE lif_tcmb=>ty_rate.
    DATA ls_mapping TYPE lif_tcmb=>ty_mapping.
    DATA ls_line TYPE lif_tcmb=>ty_line.

    IF is_settings-target_currency IS INITIAL.
      lv_target = lif_tcmb=>default_target.
    ELSE.
      lv_target = is_settings-target_currency.
    ENDIF.
    IF lv_target <> lif_tcmb=>default_target.
      ls_line-status = lif_tcmb=>status-error.
      ls_line-message = `TCMB quotes are in TRY; cross rates are not supported`.
      APPEND ls_line TO rt_lines.
      RETURN.
    ENDIF.

    LOOP AT is_bulletin-rates INTO ls_rate.
      lv_waers = sap_currency( iv_code = ls_rate-code is_settings = is_settings ).
      IF lv_waers IS INITIAL.
        CONTINUE.
      ENDIF.

      LOOP AT is_settings-mappings INTO ls_mapping.
        CLEAR ls_line.
        ls_line-bulletin_date = is_bulletin-date.
        ls_line-tcmb_code     = ls_rate-code.
        ls_line-source        = ls_mapping-source.
        ls_line-rate_type     = ls_mapping-rate_type.
        ls_line-from_curr     = lv_waers.
        ls_line-to_curr       = lv_target.
        ls_line-valid_from    = iv_valid_from.

        READ TABLE it_known TRANSPORTING NO FIELDS WITH TABLE KEY table_line = lv_waers.
        IF sy-subrc <> 0.
          ls_line-status = lif_tcmb=>status-skipped.
          CONCATENATE `Currency ` lv_waers ` is not defined in SAP (TCURC)` INTO ls_line-message.
          APPEND ls_line TO rt_lines.
          CONTINUE.
        ENDIF.

        lv_value = pick( is_rate = ls_rate iv_source = ls_mapping-source ).
        IF lv_value <= 0.
          ls_line-status = lif_tcmb=>status-skipped.
          lv_source = ls_mapping-source.
          lv_code = ls_rate-code.
          CONCATENATE `TCMB gives no ` lv_source ` rate for ` lv_code INTO ls_line-message.
          APPEND ls_line TO rt_lines.
          CONTINUE.
        ENDIF.

        add_line( EXPORTING is_line    = ls_line
                            iv_value   = lv_value
                            iv_unit    = ls_rate-unit
                            it_factors = it_factors
                  CHANGING  ct_lines   = rt_lines ).

        IF is_settings-write_inverse = abap_true.
          ls_line-from_curr = lv_target.
          ls_line-to_curr   = lv_waers.
          ls_line-indirect  = abap_true.
          add_line( EXPORTING is_line    = ls_line
                              iv_value   = lv_value
                              iv_unit    = ls_rate-unit
                              it_factors = it_factors
                    CHANGING  ct_lines   = rt_lines ).
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD sap_currency.
    DATA ls_rename TYPE lif_tcmb=>ty_rename.
    " An empty range wants every currency
    IF iv_code NOT IN is_settings-codes.
      RETURN.
    ENDIF.
    READ TABLE is_settings-renames INTO ls_rename WITH TABLE KEY tcmb_code = iv_code.
    IF sy-subrc = 0.
      rv_waers = ls_rename-sap_currency.
    ELSE.
      rv_waers = iv_code.
    ENDIF.
  ENDMETHOD.


  METHOD pick.
    CASE iv_source.
      WHEN lif_tcmb=>source-fx_buy.
        rv_value = is_rate-fx_buy.
      WHEN lif_tcmb=>source-fx_sell.
        rv_value = is_rate-fx_sell.
      WHEN lif_tcmb=>source-bn_buy.
        rv_value = is_rate-bn_buy.
      WHEN lif_tcmb=>source-bn_sell.
        rv_value = is_rate-bn_sell.
      WHEN lif_tcmb=>source-fx_avg.
        IF is_rate-fx_buy > 0 AND is_rate-fx_sell > 0.
          rv_value = ( is_rate-fx_buy + is_rate-fx_sell ) / 2.
        ENDIF.
      WHEN lif_tcmb=>source-bn_avg.
        IF is_rate-bn_buy > 0 AND is_rate-bn_sell > 0.
          rv_value = ( is_rate-bn_buy + is_rate-bn_sell ) / 2.
        ENDIF.
    ENDCASE.
  ENDMETHOD.


  METHOD parse_renames.
    DATA lt_pairs TYPE STANDARD TABLE OF string WITH DEFAULT KEY.
    DATA lv_text TYPE string.
    DATA lv_pair TYPE string.
    DATA lv_code TYPE string.
    DATA lv_sap TYPE string.
    DATA lv_message TYPE string.
    DATA ls_rename TYPE lif_tcmb=>ty_rename.

    lv_text = iv_text.
    TRANSLATE lv_text TO UPPER CASE.
    TRANSLATE lv_text USING `, ; `.
    CONDENSE lv_text.
    REPLACE ALL OCCURRENCES OF ` =` IN lv_text WITH `=`.
    REPLACE ALL OCCURRENCES OF `= ` IN lv_text WITH `=`.
    SPLIT lv_text AT space INTO TABLE lt_pairs.

    LOOP AT lt_pairs INTO lv_pair WHERE table_line IS NOT INITIAL.
      CLEAR: lv_code, lv_sap.
      SPLIT lv_pair AT '=' INTO lv_code lv_sap.
      IF strlen( lv_code ) <> 3 OR lv_code CN 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
         OR lv_sap IS INITIAL OR strlen( lv_sap ) > 5 OR lv_sap CA '='.
        CONCATENATE `"` lv_pair `" is not TCMB code = SAP code, for example USD=USD2` INTO lv_message.
        RAISE EXCEPTION TYPE lcx_tcmb
          EXPORTING
            kind = lcx_tcmb=>kinds-config
            text = lv_message.
      ENDIF.
      ls_rename-tcmb_code    = lv_code.
      ls_rename-sap_currency = lv_sap.
      INSERT ls_rename INTO TABLE rt_renames.
      IF sy-subrc <> 0.
        CONCATENATE `TCMB code ` lv_code ` has two SAP codes; keep one` INTO lv_message.
        RAISE EXCEPTION TYPE lcx_tcmb
          EXPORTING
            kind = lcx_tcmb=>kinds-config
            text = lv_message.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD add_line.
    DATA ls_line TYPE lif_tcmb=>ty_line.
    DATA ls_factor TYPE lif_tcmb=>ty_factor.
    DATA lv_foreign TYPE waers.
    DATA lv_target TYPE waers.
    DATA lv_rate TYPE lif_tcmb=>ty_value.
    DATA lv_rate_text TYPE string.
    DATA lv_rate_type TYPE string.

    ls_line = is_line.

    " Both entries use the ratio of the direct pair (foreign -> target):
    " for an indirect quotation SAP reads the ratio of the reverse pair
    " (seen on S/4HANA 2023 with CONVERT_TO_LOCAL_CURRENCY)
    IF ls_line-indirect = abap_true.
      lv_foreign = ls_line-to_curr.
      lv_target  = ls_line-from_curr.
    ELSE.
      lv_foreign = ls_line-from_curr.
      lv_target  = ls_line-to_curr.
    ENDIF.
    READ TABLE it_factors INTO ls_factor
      WITH TABLE KEY kurst = ls_line-rate_type
                     fcurr = lv_foreign
                     tcurr = lv_target.
    IF sy-subrc <> 0.
      ls_line-status = lif_tcmb=>status-error.
      lv_rate_type = ls_line-rate_type.
      CONCATENATE `No ratio in TCURF for ` lv_rate_type ` ` lv_foreign `/` lv_target
                  ` (maintain it with OBBS)` INTO ls_line-message.
      APPEND ls_line TO ct_lines.
      RETURN.
    ENDIF.
    IF ls_line-indirect = abap_true.
      ls_line-from_factor = ls_factor-tfact.
      ls_line-to_factor   = ls_factor-ffact.
    ELSE.
      ls_line-from_factor = ls_factor-ffact.
      ls_line-to_factor   = ls_factor-tfact.
    ENDIF.
    IF iv_unit <= 0 OR ls_factor-ffact <= 0 OR ls_factor-tfact <= 0.
      ls_line-status = lif_tcmb=>status-error.
      ls_line-message = `TCMB Unit and both OBBS factors must be positive`.
      APPEND ls_line TO ct_lines.
      RETURN.
    ENDIF.

    " TCMB: UNIT foreign units cost VALUE target units; TCURR quotes the
    " rate for FFACT foreign units against TFACT target units
    " TCURR has 5 decimals; the assignment rounds commercially
    TRY.
        lv_rate = iv_value * ls_factor-ffact / ( iv_unit * ls_factor-tfact ).
        lv_rate_text = lcl_fmt=>num( lv_rate ).
        ls_line-rate = lv_rate.
      CATCH cx_sy_conversion_overflow cx_sy_arithmetic_error.
        ls_line-status = lif_tcmb=>status-error.
        CONCATENATE `Rate ` lv_rate_text ` does not fit TCURR; use a larger ratio in TCURF (OBBS)`
          INTO ls_line-message.
    ENDTRY.
    IF ls_line-status IS INITIAL AND ls_line-rate <= 0.
      ls_line-status = lif_tcmb=>status-error.
      CONCATENATE `Rate ` lv_rate_text ` rounds to zero; use a larger ratio in TCURF (OBBS)`
        INTO ls_line-message.
    ENDIF.
    APPEND ls_line TO ct_lines.
  ENDMETHOD.

ENDCLASS.


"! Compares with TCURR and writes
CLASS lcl_writer DEFINITION FINAL.
  PUBLIC SECTION.
    "! Sets the STATUS of every line without one: NEW, UPDATED, UNCHANGED,
    "! SKIPPED or ERROR. Writes with BAPI_EXCHANGERATE_CREATE and commits,
    "! unless IV_TEST is set.
    METHODS write
      IMPORTING
        iv_existing TYPE c
        iv_test     TYPE abap_bool
      CHANGING
        ct_lines    TYPE lif_tcmb=>ty_lines.

    "! TCURR keeps dates as 99999999 minus YYYYMMDD
    CLASS-METHODS inverted_date
      IMPORTING
        iv_date         TYPE d
      RETURNING
        value(rv_gdatu) TYPE tcurr-gdatu.
ENDCLASS.



CLASS lcl_writer IMPLEMENTATION.

  METHOD write.
    DATA ls_return TYPE bapiret2.
    DATA ls_rate TYPE bapi1093_0.
    DATA lv_allow_update TYPE abap_bool.
    DATA lv_stored TYPE tcurr-ukurs.
    DATA lv_existing TYPE tcurr-ukurs.
    DATA lv_gdatu TYPE tcurr-gdatu.
    DATA lv_existing_text TYPE string.
    FIELD-SYMBOLS <ls_line> TYPE lif_tcmb=>ty_line.

    LOOP AT ct_lines ASSIGNING <ls_line> WHERE status IS INITIAL.
      " An indirect quotation is stored with a minus sign
      IF <ls_line>-indirect = abap_true.
        lv_stored = <ls_line>-rate * -1.
      ELSE.
        lv_stored = <ls_line>-rate.
      ENDIF.
      lv_gdatu = inverted_date( <ls_line>-valid_from ).
      SELECT SINGLE ukurs FROM tcurr INTO lv_existing
        WHERE kurst = <ls_line>-rate_type
          AND fcurr = <ls_line>-from_curr
          AND tcurr = <ls_line>-to_curr
          AND gdatu = lv_gdatu.
      IF sy-subrc = 0.
        IF lv_existing = lv_stored.
          <ls_line>-status = lif_tcmb=>status-unchanged.
          CONTINUE.
        ENDIF.
        lv_existing_text = lcl_fmt=>num( lv_existing ).
        IF iv_existing = lif_tcmb=>existing-skip.
          <ls_line>-status = lif_tcmb=>status-skipped.
          CONCATENATE `TCURR already has ` lv_existing_text ` for that day; kept` INTO <ls_line>-message.
          CONTINUE.
        ENDIF.
        <ls_line>-status = lif_tcmb=>status-updated.
        CONCATENATE `Was ` lv_existing_text INTO <ls_line>-message.
      ELSE.
        <ls_line>-status = lif_tcmb=>status-new.
      ENDIF.

      IF iv_test = abap_true.
        CONTINUE.
      ENDIF.

      CLEAR ls_rate.
      ls_rate-rate_type  = <ls_line>-rate_type.
      ls_rate-from_curr  = <ls_line>-from_curr.
      ls_rate-to_currncy = <ls_line>-to_curr.
      ls_rate-valid_from = <ls_line>-valid_from.
      IF <ls_line>-indirect = abap_true.
        ls_rate-exch_rate_v   = <ls_line>-rate.
        ls_rate-from_factor_v = <ls_line>-from_factor.
        ls_rate-to_factor_v   = <ls_line>-to_factor.
      ELSE.
        ls_rate-exch_rate   = <ls_line>-rate.
        ls_rate-from_factor = <ls_line>-from_factor.
        ls_rate-to_factor   = <ls_line>-to_factor.
      ENDIF.

      CLEAR ls_return.
      CLEAR lv_allow_update.
      IF iv_existing = lif_tcmb=>existing-update.
        lv_allow_update = abap_true.
      ENDIF.
      CALL FUNCTION 'BAPI_EXCHANGERATE_CREATE'
        EXPORTING
          exch_rate = ls_rate
          upd_allow = lv_allow_update
        IMPORTING
          return    = ls_return
        EXCEPTIONS OTHERS = 1.
      IF sy-subrc <> 0 OR ls_return-type CA 'EAX'.
        <ls_line>-status  = lif_tcmb=>status-error.
        <ls_line>-message = ls_return-message.
        IF <ls_line>-message IS INITIAL.
          <ls_line>-message = `Exchange-rate BAPI failed`.
        ENDIF.
        CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
        CONTINUE.
      ENDIF.

      CLEAR ls_return.
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
        EXPORTING
          wait = abap_true
        IMPORTING
          return = ls_return
        EXCEPTIONS OTHERS = 1.
      IF sy-subrc <> 0 OR ls_return-type CA 'EAX'.
        <ls_line>-status = lif_tcmb=>status-error.
        CONCATENATE `Commit failed. Check OB08 and SM13 before retrying. `
                    ls_return-message INTO <ls_line>-message.
        CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD inverted_date.
    DATA lv_digits TYPE c LENGTH 8.
    DATA lv_number TYPE i.
    DATA lv_result TYPE n LENGTH 8.
    lv_digits = iv_date.
    lv_number = lv_digits.
    lv_result = 99999999 - lv_number.
    rv_gdatu = lv_result.
  ENDMETHOD.

ENDCLASS.


"! Loads days: gets each bulletin, builds the TCURR lines, calls the exit
"! and writes
CLASS lcl_loader DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS constructor
      IMPORTING
        is_settings TYPE lif_tcmb=>ty_settings.

    "! What is missing or wrong in the settings for a load; empty if nothing
    CLASS-METHODS check
      IMPORTING
        is_settings       TYPE lif_tcmb=>ty_settings
      RETURNING
        value(rv_problem) TYPE string.

    "! Loads every weekday from IV_FROM to IV_TO (TCMB publishes nothing
    "! on Saturdays and Sundays). Stops at the first connection error.
    METHODS run
      IMPORTING
        iv_from         TYPE d
        iv_to           TYPE d
        iv_test         TYPE abap_bool DEFAULT abap_true
      RETURNING
        value(rt_lines) TYPE lif_tcmb=>ty_lines
      RAISING
        lcx_tcmb.

    "! Gets and reads the latest bulletin of the last seven days
    METHODS test_connection
      RETURNING
        value(rv_text) TYPE string
      RAISING
        lcx_tcmb.

    "! Monday to Friday
    CLASS-METHODS is_weekday
      IMPORTING
        iv_date        TYPE d
      RETURNING
        value(rv_bool) TYPE abap_bool.

  PRIVATE SECTION.
    DATA ms_settings TYPE lif_tcmb=>ty_settings.
    DATA mo_source TYPE REF TO lif_source.
    DATA mo_date_rule TYPE REF TO lcl_date_rule.
    DATA mo_exit TYPE REF TO lcl_exit.

    METHODS load_day
      IMPORTING
        iv_date         TYPE d
        iv_test         TYPE abap_bool
      RETURNING
        value(rt_lines) TYPE lif_tcmb=>ty_lines
      RAISING
        lcx_tcmb.

    METHODS read_bulletin
      IMPORTING
        iv_date            TYPE d
      RETURNING
        value(rs_bulletin) TYPE lif_tcmb=>ty_bulletin
      RAISING
        lcx_tcmb.

    METHODS read_factors
      IMPORTING
        iv_date           TYPE d
        iv_target         TYPE waers
      RETURNING
        value(rt_factors) TYPE lif_tcmb=>ty_factors.

    METHODS target_currency
      RETURNING
        value(rv_waers) TYPE waers.
ENDCLASS.



CLASS lcl_loader IMPLEMENTATION.

  METHOD constructor.
    ms_settings = is_settings.
    IF ms_settings-origin = lif_tcmb=>origin-folder.
      CREATE OBJECT mo_source TYPE lcl_source_file.
    ELSE.
      CREATE OBJECT mo_source TYPE lcl_source_http.
    ENDIF.
    CREATE OBJECT mo_exit.
  ENDMETHOD.


  METHOD check.
    DATA ls_mapping TYPE lif_tcmb=>ty_mapping.
    DATA lo_date_rule TYPE REF TO lcl_date_rule.            "#EC NEEDED
    DATA lx_error TYPE REF TO lcx_tcmb.
    DATA lv_rate_type TYPE string.

    IF is_settings-mappings IS INITIAL.
      rv_problem = `Enter an SAP rate type for at least one TCMB rate`.
      RETURN.
    ENDIF.
    IF is_settings-target_currency IS NOT INITIAL
       AND is_settings-target_currency <> lif_tcmb=>default_target.
      rv_problem = `TCMB quotes are in TRY; another target would need a cross-rate calculation`.
      RETURN.
    ENDIF.
    LOOP AT is_settings-mappings INTO ls_mapping.
      LOOP AT is_settings-mappings TRANSPORTING NO FIELDS
           WHERE rate_type = ls_mapping-rate_type AND source <> ls_mapping-source.
        lv_rate_type = ls_mapping-rate_type.
        CONCATENATE `Rate type ` lv_rate_type ` is entered for two TCMB rates; `
                    `a rate type can take only one` INTO rv_problem.
        RETURN.
      ENDLOOP.
    ENDLOOP.
    TRY.
        CREATE OBJECT lo_date_rule
          EXPORTING
            iv_rule     = is_settings-date_rule
            iv_calendar = is_settings-factory_calendar.
      CATCH lcx_tcmb INTO lx_error.
        rv_problem = lx_error->get_text( ).
        RETURN.
    ENDTRY.
    IF is_settings-origin = lif_tcmb=>origin-folder AND is_settings-file_folder IS INITIAL.
      rv_problem = `Enter the folder of the bulletin files`.
    ENDIF.
  ENDMETHOD.


  METHOD run.
    DATA lv_problem TYPE string.
    DATA lv_text TYPE string.
    DATA lv_from TYPE string.
    DATA lv_to TYPE string.
    DATA lv_date TYPE d.
    DATA lt_day TYPE lif_tcmb=>ty_lines.
    DATA lx_error TYPE REF TO cx_root.
    DATA ls_error TYPE lif_tcmb=>ty_line.

    lv_problem = check( ms_settings ).
    IF lv_problem IS NOT INITIAL.
      RAISE EXCEPTION TYPE lcx_tcmb
        EXPORTING
          kind = lcx_tcmb=>kinds-config
          text = lv_problem.
    ENDIF.
    IF iv_to < iv_from.
      lv_from = lcl_fmt=>date( iv_from ).
      lv_to = lcl_fmt=>date( iv_to ).
      CONCATENATE `The end date ` lv_to ` is before the start date ` lv_from INTO lv_text.
      RAISE EXCEPTION TYPE lcx_tcmb
        EXPORTING
          kind = lcx_tcmb=>kinds-config
          text = lv_text.
    ENDIF.
    CALL FUNCTION 'DATE_CHECK_PLAUSIBILITY'
      EXPORTING date = iv_from EXCEPTIONS OTHERS = 1.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE lcx_tcmb
        EXPORTING kind = lcx_tcmb=>kinds-config text = `Choose a valid start date`.
    ENDIF.
    CALL FUNCTION 'DATE_CHECK_PLAUSIBILITY'
      EXPORTING date = iv_to EXCEPTIONS OTHERS = 1.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE lcx_tcmb
        EXPORTING kind = lcx_tcmb=>kinds-config text = `Choose a valid end date`.
    ENDIF.
    CREATE OBJECT mo_date_rule
      EXPORTING
        iv_rule     = ms_settings-date_rule
        iv_calendar = ms_settings-factory_calendar.

    lv_date = iv_from.
    WHILE lv_date <= iv_to.
      IF is_weekday( lv_date ) = abap_true.
        TRY.
            lt_day = load_day( iv_date = lv_date iv_test = iv_test ).
            APPEND LINES OF lt_day TO rt_lines.
          CATCH cx_root INTO lx_error.
            CLEAR ls_error.
            ls_error-bulletin_date = lv_date.
            ls_error-status = lif_tcmb=>status-error.
            ls_error-message = lx_error->get_text( ).
            APPEND ls_error TO rt_lines.
            EXIT.
        ENDTRY.
      ENDIF.
      IF lv_date = iv_to.
        EXIT.
      ENDIF.
      lv_date = lv_date + 1.
    ENDWHILE.
  ENDMETHOD.


  METHOD test_connection.
    DATA lv_date TYPE d.
    DATA ls_bulletin TYPE lif_tcmb=>ty_bulletin.
    DATA lx_error TYPE REF TO lcx_tcmb.
    DATA lv_day TYPE string.
    DATA lv_count TYPE string.
    DATA lv_lines TYPE i.

    lv_date = sy-datum.
    DO 7 TIMES.
      IF is_weekday( lv_date ) = abap_true.
        TRY.
            ls_bulletin = read_bulletin( lv_date ).
            lv_day = lcl_fmt=>date( ls_bulletin-date ).
            lv_lines = lines( ls_bulletin-rates ).
            lv_count = lcl_fmt=>int( lv_lines ).
            CONCATENATE `Connection OK: bulletin ` ls_bulletin-number ` of ` lv_day `, `
                        lv_count ` currencies` INTO rv_text.
            RETURN.
          CATCH lcx_tcmb INTO lx_error.
            IF lx_error->kind <> lcx_tcmb=>kinds-no_bulletin.
              RAISE EXCEPTION lx_error.
            ENDIF.
        ENDTRY.
      ENDIF.
      lv_date = lv_date - 1.
    ENDDO.
    RAISE EXCEPTION TYPE lcx_tcmb
      EXPORTING
        kind = lcx_tcmb=>kinds-no_bulletin
        text = `The connection works, but TCMB returned no bulletin for the last seven days`.
  ENDMETHOD.


  METHOD is_weekday.
    " 1 January 1900 was a Monday
    DATA lv_monday TYPE d VALUE '19000101'.
    DATA lv_days TYPE i.
    lv_days = iv_date - lv_monday.
    IF lv_days MOD 7 < 5.
      rv_bool = abap_true.
    ELSE.
      rv_bool = abap_false.
    ENDIF.
  ENDMETHOD.


  METHOD load_day.
    DATA ls_bulletin TYPE lif_tcmb=>ty_bulletin.
    DATA lx_error TYPE REF TO lcx_tcmb.
    DATA ls_line TYPE lif_tcmb=>ty_line.
    DATA lv_valid_from TYPE d.
    DATA lt_known TYPE lif_tcmb=>ty_currency_codes.
    DATA lt_factors TYPE lif_tcmb=>ty_factors.
    DATA lv_target TYPE waers.
    DATA lv_existing TYPE c LENGTH 1.
    DATA lo_calc TYPE REF TO lcl_calc.
    DATA lo_writer TYPE REF TO lcl_writer.

    TRY.
        ls_bulletin = read_bulletin( iv_date ).
      CATCH lcx_tcmb INTO lx_error.
        IF lx_error->kind <> lcx_tcmb=>kinds-no_bulletin.
          RAISE EXCEPTION lx_error.
        ENDIF.
        ls_line-bulletin_date = iv_date.
        IF ms_settings-no_bulletin = lif_tcmb=>no_bulletin-error.
          ls_line-status = lif_tcmb=>status-error.
        ELSE.
          ls_line-status = lif_tcmb=>status-no_bulletin.
        ENDIF.
        ls_line-message = lx_error->get_text( ).
        APPEND ls_line TO rt_lines.
        RETURN.
    ENDTRY.

    lv_valid_from = mo_date_rule->valid_from( iv_date ).
    SELECT waers FROM tcurc INTO TABLE lt_known.
    lv_target = target_currency( ).
    lt_factors = read_factors( iv_date = lv_valid_from iv_target = lv_target ).

    CREATE OBJECT lo_calc.
    rt_lines = lo_calc->build_lines( is_bulletin   = ls_bulletin
                                     is_settings   = ms_settings
                                     iv_valid_from = lv_valid_from
                                     it_factors    = lt_factors
                                     it_known      = lt_known ).

    mo_exit->before_write( EXPORTING is_settings = ms_settings
                           CHANGING  ct_lines    = rt_lines ).

    IF ms_settings-existing_rate IS INITIAL.
      lv_existing = lif_tcmb=>existing-update.
    ELSE.
      lv_existing = ms_settings-existing_rate.
    ENDIF.
    CREATE OBJECT lo_writer.
    lo_writer->write( EXPORTING iv_existing = lv_existing
                                iv_test     = iv_test
                      CHANGING  ct_lines    = rt_lines ).

    mo_exit->after_write( is_settings = ms_settings it_lines = rt_lines iv_test = iv_test ).
  ENDMETHOD.


  METHOD read_bulletin.
    DATA lv_xml TYPE xstring.
    DATA lo_parser TYPE REF TO lcl_parser.
    DATA lv_asked TYPE string.
    DATA lv_got TYPE string.
    DATA lv_text TYPE string.

    lv_xml = mo_source->get_bulletin( iv_date = iv_date is_settings = ms_settings ).
    CREATE OBJECT lo_parser.
    rs_bulletin = lo_parser->parse( lv_xml ).
    IF rs_bulletin-date <> iv_date.
      lv_asked = lcl_fmt=>date( iv_date ).
      lv_got = lcl_fmt=>date( rs_bulletin-date ).
      CONCATENATE `Asked TCMB for ` lv_asked ` but got the bulletin of ` lv_got INTO lv_text.
      RAISE EXCEPTION TYPE lcx_tcmb
        EXPORTING
          kind = lcx_tcmb=>kinds-parse
          text = lv_text.
    ENDIF.
  ENDMETHOD.


  METHOD read_factors.
    " A ratio is valid from its date on; with inverted dates the newest
    " ratio that is already valid has the smallest GDATU >= the day
    TYPES:
      BEGIN OF ty_tcurf,
        kurst TYPE tcurf-kurst,
        fcurr TYPE tcurf-fcurr,
        tcurr TYPE tcurf-tcurr,
        gdatu TYPE tcurf-gdatu,
        ffact TYPE tcurf-ffact,
        tfact TYPE tcurf-tfact,
      END OF ty_tcurf.
    DATA lt_tcurf TYPE STANDARD TABLE OF ty_tcurf WITH DEFAULT KEY.
    DATA ls_tcurf TYPE ty_tcurf.
    DATA ls_factor TYPE lif_tcmb=>ty_factor.
    DATA ls_mapping TYPE lif_tcmb=>ty_mapping.
    DATA lt_rate_types TYPE RANGE OF tcurf-kurst.
    DATA ls_rate_type LIKE LINE OF lt_rate_types.
    DATA lv_gdatu TYPE tcurf-gdatu.

    LOOP AT ms_settings-mappings INTO ls_mapping.
      ls_rate_type-sign   = 'I'.
      ls_rate_type-option = 'EQ'.
      ls_rate_type-low    = ls_mapping-rate_type.
      APPEND ls_rate_type TO lt_rate_types.
    ENDLOOP.
    lv_gdatu = lcl_writer=>inverted_date( iv_date ).

    SELECT kurst fcurr tcurr gdatu ffact tfact FROM tcurf
      INTO TABLE lt_tcurf
      WHERE kurst IN lt_rate_types
        AND ( fcurr = iv_target OR tcurr = iv_target )
        AND gdatu >= lv_gdatu
      ORDER BY kurst fcurr tcurr gdatu.

    LOOP AT lt_tcurf INTO ls_tcurf.
      " Sorted unique table: the first, newest ratio per key wins
      ls_factor-kurst = ls_tcurf-kurst.
      ls_factor-fcurr = ls_tcurf-fcurr.
      ls_factor-tcurr = ls_tcurf-tcurr.
      ls_factor-ffact = ls_tcurf-ffact.
      ls_factor-tfact = ls_tcurf-tfact.
      INSERT ls_factor INTO TABLE rt_factors.
    ENDLOOP.
  ENDMETHOD.


  METHOD target_currency.
    IF ms_settings-target_currency IS INITIAL.
      rv_waers = lif_tcmb=>default_target.
    ELSE.
      rv_waers = ms_settings-target_currency.
    ENDIF.
  ENDMETHOD.

ENDCLASS.


*&---------------------------------------------------------------------*
*& Selection screen. Save your entries as a variant: a variant is a
*& profile, for example one for the daily job.
*&---------------------------------------------------------------------*
DATA gv_tcmb_code TYPE lif_tcmb=>ty_code.
DATA gv_to TYPE d.

SELECTION-SCREEN BEGIN OF BLOCK b_run WITH FRAME TITLE t_run.
SELECT-OPTIONS s_date FOR sy-datum NO-EXTENSION OBLIGATORY DEFAULT sy-datum.
PARAMETERS p_test AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN PUSHBUTTON /1(40) b_conn USER-COMMAND conn.
SELECTION-SCREEN END OF BLOCK b_run.

" Which TCMB rate goes into which SAP rate type; empty = not loaded
SELECTION-SCREEN BEGIN OF BLOCK b_map WITH FRAME TITLE t_map.
SELECTION-SCREEN COMMENT /1(75) c_map.
PARAMETERS p_fxbuy TYPE kurst_curr.
PARAMETERS p_fxsel TYPE kurst_curr.
PARAMETERS p_bnbuy TYPE kurst_curr.
PARAMETERS p_bnsel TYPE kurst_curr.
PARAMETERS p_fxavg TYPE kurst_curr.
PARAMETERS p_bnavg TYPE kurst_curr.
SELECTION-SCREEN END OF BLOCK b_map.

SELECTION-SCREEN BEGIN OF BLOCK b_date WITH FRAME TITLE t_date.
PARAMETERS p_rule TYPE c LENGTH 12 AS LISTBOX VISIBLE LENGTH 40.
PARAMETERS p_cal TYPE wfcid.
SELECTION-SCREEN END OF BLOCK b_date.

SELECTION-SCREEN BEGIN OF BLOCK b_curr WITH FRAME TITLE t_curr.
SELECTION-SCREEN COMMENT /1(75) c_curr.
SELECT-OPTIONS s_curr FOR gv_tcmb_code NO INTERVALS.
PARAMETERS p_map TYPE c LENGTH 100 VISIBLE LENGTH 30.
PARAMETERS p_targ TYPE waers DEFAULT 'TRY'.
PARAMETERS p_inv AS CHECKBOX DEFAULT ' '.
SELECTION-SCREEN END OF BLOCK b_curr.

SELECTION-SCREEN BEGIN OF BLOCK b_exist WITH FRAME TITLE t_exist.
PARAMETERS r_upd RADIOBUTTON GROUP exi DEFAULT 'X'.
PARAMETERS r_keep RADIOBUTTON GROUP exi.
SELECTION-SCREEN END OF BLOCK b_exist.

SELECTION-SCREEN BEGIN OF BLOCK b_nobul WITH FRAME TITLE t_nobul.
PARAMETERS r_nblog RADIOBUTTON GROUP nob DEFAULT 'X'.
PARAMETERS r_nbwrn RADIOBUTTON GROUP nob.
PARAMETERS r_nberr RADIOBUTTON GROUP nob.
SELECTION-SCREEN END OF BLOCK b_nobul.

SELECTION-SCREEN BEGIN OF BLOCK b_src WITH FRAME TITLE t_src.
PARAMETERS r_http RADIOBUTTON GROUP src DEFAULT 'X'.
PARAMETERS p_dest TYPE rfcdest.
PARAMETERS p_url TYPE c LENGTH 255 LOWER CASE VISIBLE LENGTH 40.
PARAMETERS r_file RADIOBUTTON GROUP src.
PARAMETERS p_dir TYPE c LENGTH 255 LOWER CASE VISIBLE LENGTH 40.
SELECTION-SCREEN END OF BLOCK b_src.


"! Selection screen, result list and job
CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    "! Texts of the selection screen, so a pasted program needs no text elements
    CLASS-METHODS set_texts.

    CLASS-METHODS set_date_rules.

    "! Called before a run from the screen: stops with the first problem
    CLASS-METHODS check_screen.

    CLASS-METHODS test_connection.

    CLASS-METHODS run
      IMPORTING
        iv_from TYPE d
        iv_to   TYPE d
        iv_test TYPE abap_bool.

  PRIVATE SECTION.
    CLASS-DATA gt_lines TYPE lif_tcmb=>ty_lines.

    "! English, or Turkish when you log on in Turkish
    CLASS-METHODS text
      IMPORTING
        iv_en          TYPE csequence
        iv_tr          TYPE csequence
      RETURNING
        value(rv_text) TYPE string.

    CLASS-METHODS add_text
      IMPORTING
        iv_name  TYPE csequence
        iv_kind  TYPE c
        iv_en    TYPE csequence
        iv_tr    TYPE csequence
      CHANGING
        ct_texts TYPE STANDARD TABLE.

    CLASS-METHODS settings
      RETURNING
        value(rs_settings) TYPE lif_tcmb=>ty_settings
      RAISING
        lcx_tcmb.

    CLASS-METHODS add_mapping
      IMPORTING
        iv_rate_type TYPE kurst_curr
        iv_source    TYPE lif_tcmb=>ty_source
      CHANGING
        ct_mappings  TYPE lif_tcmb=>ty_mappings.

    CLASS-METHODS count
      IMPORTING
        iv_status       TYPE lif_tcmb=>ty_status
      RETURNING
        value(rv_count) TYPE i.

    CLASS-METHODS show.

    CLASS-METHODS fail
      IMPORTING
        iv_text TYPE string.
ENDCLASS.



CLASS lcl_app IMPLEMENTATION.

  METHOD set_texts.
    " The function module needs exactly this table type (default key)
    DATA lt_texts TYPE STANDARD TABLE OF rsseltexts WITH DEFAULT KEY.

    t_run   = text( iv_en = `Run`
                    iv_tr = `Çalıştırma` ).
    t_map   = text( iv_en = `Which TCMB rate goes into which SAP rate type`
                    iv_tr = `Hangi TCMB kuru hangi SAP kur tipine yazılır` ).
    t_date  = text( iv_en = `From which day the rates are valid`
                    iv_tr = `Kurlar hangi günden itibaren geçerli` ).
    t_curr  = text( iv_en = `Currencies`
                    iv_tr = `Para birimleri` ).
    t_exist = text( iv_en = `When TCURR already has a different rate for that day`
                    iv_tr = `TCURR'da o gün için farklı bir kur varsa` ).
    t_nobul = text( iv_en = `A working day without a TCMB bulletin`
                    iv_tr = `TCMB bülteni olmayan iş günü` ).
    t_src   = text( iv_en = `Where the bulletin comes from`
                    iv_tr = `Bülten nereden alınır` ).
    c_map   = text( iv_en = `Enter the rate type (e.g. M) next to each wanted rate; empty = not loaded`
                    iv_tr = `İstenen kurun yanına kur tipini yazın (örn. M); boş = yüklenmez` ).
    c_curr  = text( iv_en = `TCMB codes: empty = all; use "exclude" in the ranges to leave some out`
                    iv_tr = `TCMB kodları: boş = hepsi; bazılarını çıkarmak için "hariç tut" seçin` ).
    b_conn  = text( iv_en = `Test the connection to TCMB`
                    iv_tr = `TCMB bağlantısını test et` ).

    add_text( EXPORTING iv_name = 'S_DATE'  iv_kind = 'S' iv_en = `Bulletin date(s)`            iv_tr = `Bülten tarih(ler)i`
              CHANGING  ct_texts = lt_texts ).
    add_text( EXPORTING iv_name = 'P_TEST'  iv_kind = 'P' iv_en = `Test run, write nothing`     iv_tr = `Test çalıştırma, yazma`
              CHANGING  ct_texts = lt_texts ).
    add_text( EXPORTING iv_name = 'P_FXBUY' iv_kind = 'P' iv_en = `Forex buying`                iv_tr = `Döviz alış`
              CHANGING  ct_texts = lt_texts ).
    add_text( EXPORTING iv_name = 'P_FXSEL' iv_kind = 'P' iv_en = `Forex selling`               iv_tr = `Döviz satış`
              CHANGING  ct_texts = lt_texts ).
    add_text( EXPORTING iv_name = 'P_BNBUY' iv_kind = 'P' iv_en = `Banknote buying`             iv_tr = `Efektif alış`
              CHANGING  ct_texts = lt_texts ).
    add_text( EXPORTING iv_name = 'P_BNSEL' iv_kind = 'P' iv_en = `Banknote selling`            iv_tr = `Efektif satış`
              CHANGING  ct_texts = lt_texts ).
    add_text( EXPORTING iv_name = 'P_FXAVG' iv_kind = 'P' iv_en = `Forex average (buy+sell)/2`  iv_tr = `Döviz ortalama (alış+satış)/2`
              CHANGING  ct_texts = lt_texts ).
    add_text( EXPORTING iv_name = 'P_BNAVG' iv_kind = 'P' iv_en = `Banknote average`            iv_tr = `Efektif ortalama`
              CHANGING  ct_texts = lt_texts ).
    add_text( EXPORTING iv_name = 'P_RULE'  iv_kind = 'P' iv_en = `Date rule`                   iv_tr = `Tarih kuralı`
              CHANGING  ct_texts = lt_texts ).
    add_text( EXPORTING iv_name = 'P_CAL'   iv_kind = 'P' iv_en = `Factory calendar (next wd.)` iv_tr = `Fabrika takvimi (iş günü)`
              CHANGING  ct_texts = lt_texts ).
    add_text( EXPORTING iv_name = 'S_CURR'  iv_kind = 'S' iv_en = `TCMB currency codes`         iv_tr = `TCMB döviz kodları`
              CHANGING  ct_texts = lt_texts ).
    add_text( EXPORTING iv_name = 'P_MAP'   iv_kind = 'P' iv_en = `Other SAP code (USD=USD2)`   iv_tr = `Farklı SAP kodu (USD=USD2)`
              CHANGING  ct_texts = lt_texts ).
    add_text( EXPORTING iv_name = 'P_TARG'  iv_kind = 'P' iv_en = `Currency of the TCMB rates`  iv_tr = `TCMB kurlarının para birimi`
              CHANGING  ct_texts = lt_texts ).
    add_text( EXPORTING iv_name = 'P_INV'   iv_kind = 'P' iv_en = `Also write TRY -> foreign`   iv_tr = `Ters yönü de yaz (TRY->döviz)`
              CHANGING  ct_texts = lt_texts ).
    add_text( EXPORTING iv_name = 'R_UPD'   iv_kind = 'P' iv_en = `Update it`                   iv_tr = `Güncelle`
              CHANGING  ct_texts = lt_texts ).
    add_text( EXPORTING iv_name = 'R_KEEP'  iv_kind = 'P' iv_en = `Keep it`                     iv_tr = `Olduğu gibi bırak`
              CHANGING  ct_texts = lt_texts ).
    add_text( EXPORTING iv_name = 'R_NBLOG' iv_kind = 'P' iv_en = `Only show it in the list`    iv_tr = `Yalnızca listede göster`
              CHANGING  ct_texts = lt_texts ).
    add_text( EXPORTING iv_name = 'R_NBWRN' iv_kind = 'P' iv_en = `Warning`                     iv_tr = `Uyarı ver`
              CHANGING  ct_texts = lt_texts ).
    add_text( EXPORTING iv_name = 'R_NBERR' iv_kind = 'P' iv_en = `Error (job is cancelled)`    iv_tr = `Hata (job iptal olur)`
              CHANGING  ct_texts = lt_texts ).
    add_text( EXPORTING iv_name = 'R_HTTP'  iv_kind = 'P' iv_en = `From TCMB over HTTPS`        iv_tr = `TCMB'den HTTPS ile`
              CHANGING  ct_texts = lt_texts ).
    add_text( EXPORTING iv_name = 'P_DEST'  iv_kind = 'P' iv_en = `SM59 destination (optional)` iv_tr = `SM59 hedefi (isteğe bağlı)`
              CHANGING  ct_texts = lt_texts ).
    add_text( EXPORTING iv_name = 'P_URL'   iv_kind = 'P' iv_en = `Other address (optional)`    iv_tr = `Farklı adres (isteğe bağlı)`
              CHANGING  ct_texts = lt_texts ).
    add_text( EXPORTING iv_name = 'R_FILE'  iv_kind = 'P' iv_en = `From a folder on the server` iv_tr = `Sunucudaki bir klasörden`
              CHANGING  ct_texts = lt_texts ).
    add_text( EXPORTING iv_name = 'P_DIR'   iv_kind = 'P' iv_en = `Folder of the XML files`     iv_tr = `XML dosyalarının klasörü`
              CHANGING  ct_texts = lt_texts ).

    " If this fails, the screen shows the field names; the program works the same
    CALL FUNCTION 'SELECTION_TEXTS_MODIFY'
      EXPORTING
        program  = sy-repid
      TABLES
        seltexts = lt_texts
      EXCEPTIONS
        OTHERS   = 1.
  ENDMETHOD.


  METHOD add_text.
    DATA ls_text TYPE rsseltexts.
    ls_text-name = iv_name.
    ls_text-kind = iv_kind.
    ls_text-text = text( iv_en = iv_en iv_tr = iv_tr ).
    APPEND ls_text TO ct_texts.
  ENDMETHOD.


  METHOD set_date_rules.
    DATA lt_values TYPE vrm_values.
    DATA ls_value TYPE vrm_value.

    ls_value-key  = lif_tcmb=>date_rule-same_day.
    ls_value-text = text( iv_en = `Same day as the bulletin`    iv_tr = `Bülten ile aynı gün` ).
    APPEND ls_value TO lt_values.
    ls_value-key  = lif_tcmb=>date_rule-next_day.
    ls_value-text = text( iv_en = `Next calendar day`           iv_tr = `Ertesi takvim günü` ).
    APPEND ls_value TO lt_values.
    ls_value-key  = lif_tcmb=>date_rule-next_workday.
    ls_value-text = text( iv_en = `Next working day (calendar)` iv_tr = `Sonraki iş günü (takvim)` ).
    APPEND ls_value TO lt_values.

    CALL FUNCTION 'VRM_SET_VALUES'
      EXPORTING
        id     = 'P_RULE'
        values = lt_values
      EXCEPTIONS
        OTHERS = 1.
  ENDMETHOD.


  METHOD check_screen.
    DATA ls_settings TYPE lif_tcmb=>ty_settings.
    DATA lv_problem TYPE string.
    DATA lx_error TYPE REF TO lcx_tcmb.

    TRY.
        ls_settings = settings( ).
        lv_problem = lcl_loader=>check( ls_settings ).
      CATCH lcx_tcmb INTO lx_error.
        lv_problem = lx_error->get_text( ).
    ENDTRY.
    IF lv_problem IS NOT INITIAL.
      MESSAGE lv_problem TYPE 'E'.
    ENDIF.
  ENDMETHOD.


  METHOD test_connection.
    DATA ls_settings TYPE lif_tcmb=>ty_settings.
    DATA lo_loader TYPE REF TO lcl_loader.
    DATA lv_text TYPE string.
    DATA lx_error TYPE REF TO lcx_tcmb.

    TRY.
        ls_settings = settings( ).
        CREATE OBJECT lo_loader
          EXPORTING
            is_settings = ls_settings.
        lv_text = lo_loader->test_connection( ).
        MESSAGE lv_text TYPE 'I'.
      CATCH lcx_tcmb INTO lx_error.
        lv_text = lx_error->get_text( ).
        MESSAGE lv_text TYPE 'I' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.


  METHOD run.
    DATA ls_settings TYPE lif_tcmb=>ty_settings.
    DATA lo_loader TYPE REF TO lcl_loader.
    DATA lx_error TYPE REF TO lcx_tcmb.
    DATA lv_text TYPE string.
    DATA lv_summary TYPE string.
    DATA lv_new TYPE string.
    DATA lv_updated TYPE string.
    DATA lv_unchanged TYPE string.
    DATA lv_skipped TYPE string.
    DATA lv_no_bulletin TYPE string.
    DATA lv_errors TYPE string.
    DATA lv_number TYPE i.

    TRY.
        ls_settings = settings( ).
        CREATE OBJECT lo_loader
          EXPORTING
            is_settings = ls_settings.
        gt_lines = lo_loader->run( iv_from = iv_from iv_to = iv_to iv_test = iv_test ).
      CATCH lcx_tcmb INTO lx_error.
        lv_text = lx_error->get_text( ).
        fail( lv_text ).
        RETURN.
    ENDTRY.

    lv_number = count( lif_tcmb=>status-new ).
    lv_new         = lcl_fmt=>int( lv_number ).
    lv_number = count( lif_tcmb=>status-updated ).
    lv_updated     = lcl_fmt=>int( lv_number ).
    lv_number = count( lif_tcmb=>status-unchanged ).
    lv_unchanged   = lcl_fmt=>int( lv_number ).
    lv_number = count( lif_tcmb=>status-skipped ).
    lv_skipped     = lcl_fmt=>int( lv_number ).
    lv_number = count( lif_tcmb=>status-no_bulletin ).
    lv_no_bulletin = lcl_fmt=>int( lv_number ).
    lv_number = count( lif_tcmb=>status-error ).
    lv_errors      = lcl_fmt=>int( lv_number ).
    CONCATENATE lv_new ` new, ` lv_updated ` updated, ` lv_unchanged ` unchanged, `
                lv_skipped ` skipped, ` lv_no_bulletin ` days without bulletin, `
                lv_errors ` errors` INTO lv_summary.
    IF iv_test = abap_true.
      lv_text = lv_summary.
      CONCATENATE `Test run: ` lv_text INTO lv_summary.
    ENDIF.
    MESSAGE lv_summary TYPE 'S'.
    IF count( lif_tcmb=>status-no_bulletin ) > 0
       AND ls_settings-no_bulletin = lif_tcmb=>no_bulletin-warning.
      CONCATENATE `Warning: TCMB published no bulletin on ` lv_no_bulletin ` working day(s)` INTO lv_text.
      MESSAGE lv_text TYPE 'S' DISPLAY LIKE 'W'.
    ENDIF.

    show( ).

    IF count( lif_tcmb=>status-error ) > 0.
      CONCATENATE lv_errors ` line(s) failed; see the ERROR lines` INTO lv_text.
      fail( lv_text ).
    ENDIF.
  ENDMETHOD.


  METHOD text.
    IF sy-langu = 'T'.
      rv_text = iv_tr.
    ELSE.
      rv_text = iv_en.
    ENDIF.
  ENDMETHOD.


  METHOD settings.
    DATA lt_mappings TYPE lif_tcmb=>ty_mappings.

    " Same order as the TCMB rates in the bulletin
    add_mapping( EXPORTING iv_rate_type = p_fxbuy iv_source = lif_tcmb=>source-fx_buy
                 CHANGING  ct_mappings  = lt_mappings ).
    add_mapping( EXPORTING iv_rate_type = p_fxsel iv_source = lif_tcmb=>source-fx_sell
                 CHANGING  ct_mappings  = lt_mappings ).
    add_mapping( EXPORTING iv_rate_type = p_bnbuy iv_source = lif_tcmb=>source-bn_buy
                 CHANGING  ct_mappings  = lt_mappings ).
    add_mapping( EXPORTING iv_rate_type = p_bnsel iv_source = lif_tcmb=>source-bn_sell
                 CHANGING  ct_mappings  = lt_mappings ).
    add_mapping( EXPORTING iv_rate_type = p_fxavg iv_source = lif_tcmb=>source-fx_avg
                 CHANGING  ct_mappings  = lt_mappings ).
    add_mapping( EXPORTING iv_rate_type = p_bnavg iv_source = lif_tcmb=>source-bn_avg
                 CHANGING  ct_mappings  = lt_mappings ).

    rs_settings-mappings         = lt_mappings.
    rs_settings-date_rule        = p_rule.
    rs_settings-factory_calendar = p_cal.
    rs_settings-target_currency  = p_targ.
    rs_settings-codes            = s_curr[].
    rs_settings-renames          = lcl_calc=>parse_renames( p_map ).
    rs_settings-write_inverse    = p_inv.
    IF r_keep = abap_true.
      rs_settings-existing_rate = lif_tcmb=>existing-skip.
    ELSE.
      rs_settings-existing_rate = lif_tcmb=>existing-update.
    ENDIF.
    IF r_nberr = abap_true.
      rs_settings-no_bulletin = lif_tcmb=>no_bulletin-error.
    ELSEIF r_nbwrn = abap_true.
      rs_settings-no_bulletin = lif_tcmb=>no_bulletin-warning.
    ELSE.
      rs_settings-no_bulletin = lif_tcmb=>no_bulletin-log.
    ENDIF.
    IF r_file = abap_true.
      rs_settings-origin = lif_tcmb=>origin-folder.
    ELSE.
      rs_settings-origin = lif_tcmb=>origin-https.
    ENDIF.
    rs_settings-rfc_destination = p_dest.
    rs_settings-base_url        = p_url.
    CONDENSE rs_settings-base_url.
    rs_settings-file_folder     = p_dir.
    SHIFT rs_settings-file_folder LEFT DELETING LEADING space.
    SHIFT rs_settings-file_folder RIGHT DELETING TRAILING space.
  ENDMETHOD.


  METHOD add_mapping.
    DATA ls_mapping TYPE lif_tcmb=>ty_mapping.
    IF iv_rate_type IS INITIAL.
      RETURN.
    ENDIF.
    ls_mapping-rate_type = iv_rate_type.
    ls_mapping-source    = iv_source.
    APPEND ls_mapping TO ct_mappings.
  ENDMETHOD.


  METHOD count.
    LOOP AT gt_lines TRANSPORTING NO FIELDS WHERE status = iv_status.
      rv_count = rv_count + 1.
    ENDLOOP.
  ENDMETHOD.


  METHOD show.
    DATA lo_alv TYPE REF TO cl_salv_table.
    DATA lo_functions TYPE REF TO cl_salv_functions_list.
    DATA lo_columns TYPE REF TO cl_salv_columns_table.
    DATA lo_column TYPE REF TO cl_salv_column.
    DATA lx_salv TYPE REF TO cx_salv_msg.
    DATA lv_text TYPE string.

    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = lo_alv
                                CHANGING  t_table      = gt_lines ).
      CATCH cx_salv_msg INTO lx_salv.
        lv_text = lx_salv->get_text( ).
        MESSAGE lv_text TYPE 'I' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    lo_functions = lo_alv->get_functions( ).
    lo_functions->set_all( ).
    lo_columns = lo_alv->get_columns( ).
    lo_columns->set_optimize( ).
    TRY.
        lo_column = lo_columns->get_column( 'BULLETIN_DATE' ).
        lo_column->set_medium_text( 'Bulletin' ).
        lo_column->set_long_text( 'TCMB bulletin date' ).
        lo_column = lo_columns->get_column( 'TCMB_CODE' ).
        lo_column->set_medium_text( 'TCMB code' ).
        lo_column->set_long_text( 'TCMB currency code' ).
        lo_column = lo_columns->get_column( 'SOURCE' ).
        lo_column->set_medium_text( 'TCMB rate' ).
        lo_column->set_long_text( 'TCMB rate' ).
        lo_column = lo_columns->get_column( 'VALID_FROM' ).
        lo_column->set_medium_text( 'Valid from' ).
        lo_column->set_long_text( 'Valid from (TCURR)' ).
        lo_column = lo_columns->get_column( 'INDIRECT' ).
        lo_column->set_medium_text( 'Indirect' ).
        lo_column->set_long_text( 'Indirect quotation' ).
        lo_column = lo_columns->get_column( 'STATUS' ).
        lo_column->set_medium_text( 'Status' ).
        lo_column->set_long_text( 'Status' ).
        lo_column = lo_columns->get_column( 'MESSAGE' ).
        lo_column->set_medium_text( 'Message' ).
        lo_column->set_long_text( 'Message' ).
      CATCH cx_salv_not_found.                          "#EC NO_HANDLER
    ENDTRY.
    lo_alv->display( ).
  ENDMETHOD.


  METHOD fail.
    " In the background an E message ends the job as "Cancelled"
    IF sy-batch = abap_true.
      MESSAGE iv_text TYPE 'E'.
    ELSE.
      MESSAGE iv_text TYPE 'I' DISPLAY LIKE 'E'.
    ENDIF.
  ENDMETHOD.

ENDCLASS.


*&---------------------------------------------------------------------*
*& Unit tests: in SE38 or ADT, Program > Execute > Unit Tests
*& (Ctrl+Shift+F10). Nothing is read from or written to the database.
*& Written for release 7.00: CL_AUNIT_ASSERT, and risk level and
*& duration as "#AU pseudo comments.
*&---------------------------------------------------------------------*
CLASS ltc_parser DEFINITION FINAL FOR TESTING.
  "#AU Risk_Level Harmless
  "#AU Duration Short
  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO lcl_parser.

    METHODS setup.
    METHODS reads_header FOR TESTING.
    METHODS reads_rates FOR TESTING.
    METHODS reads_unit FOR TESTING.
    METHODS keeps_missing_rates_initial FOR TESTING.
    METHODS rejects_other_xml FOR TESTING.
    METHODS rejects_broken_xml FOR TESTING.
    METHODS rejects_bad_number FOR TESTING.
    METHODS rejects_bad_date FOR TESTING.
    METHODS rejects_bad_code FOR TESTING.
    METHODS rejects_duplicate_code FOR TESTING.
    METHODS rejects_bad_unit FOR TESTING.
    METHODS rejects_nonpositive_rate FOR TESTING.

    METHODS parse_sample
      RETURNING
        value(rs_bulletin) TYPE lif_tcmb=>ty_bulletin.

    METHODS rate
      IMPORTING
        iv_code        TYPE lif_tcmb=>ty_code
      RETURNING
        value(rs_rate) TYPE lif_tcmb=>ty_rate.

    METHODS assert_parse_error
      IMPORTING
        iv_xml TYPE string.

    CLASS-METHODS sample
      RETURNING
        value(rv_xml) TYPE xstring.

    CLASS-METHODS utf8
      IMPORTING
        iv_text       TYPE string
      RETURNING
        value(rv_xml) TYPE xstring.
ENDCLASS.



CLASS ltc_parser IMPLEMENTATION.

  METHOD setup.
    CREATE OBJECT mo_cut.
  ENDMETHOD.


  METHOD reads_header.
    DATA ls_bulletin TYPE lif_tcmb=>ty_bulletin.
    DATA lv_count TYPE i.
    ls_bulletin = parse_sample( ).

    cl_aunit_assert=>assert_equals( act = ls_bulletin-date exp = '20261030' ).
    cl_aunit_assert=>assert_equals( act = ls_bulletin-number exp = `2026/204` ).
    lv_count = lines( ls_bulletin-rates ).
    cl_aunit_assert=>assert_equals( act = lv_count exp = 3 ).
  ENDMETHOD.


  METHOD reads_rates.
    DATA ls_usd TYPE lif_tcmb=>ty_rate.
    DATA lv_exp TYPE lif_tcmb=>ty_value.
    ls_usd = rate( 'USD' ).

    cl_aunit_assert=>assert_equals( act = ls_usd-unit exp = 1 ).
    lv_exp = '49.7747'.
    cl_aunit_assert=>assert_equals( act = ls_usd-fx_buy exp = lv_exp ).
    lv_exp = '49.8644'.
    cl_aunit_assert=>assert_equals( act = ls_usd-fx_sell exp = lv_exp ).
    lv_exp = '49.7399'.
    cl_aunit_assert=>assert_equals( act = ls_usd-bn_buy exp = lv_exp ).
    lv_exp = '49.9392'.
    cl_aunit_assert=>assert_equals( act = ls_usd-bn_sell exp = lv_exp ).
  ENDMETHOD.


  METHOD reads_unit.
    DATA ls_jpy TYPE lif_tcmb=>ty_rate.
    DATA lv_exp TYPE lif_tcmb=>ty_value.
    ls_jpy = rate( 'JPY' ).

    cl_aunit_assert=>assert_equals( act = ls_jpy-unit exp = 100 ).
    lv_exp = '31.5605'.
    cl_aunit_assert=>assert_equals( act = ls_jpy-fx_buy exp = lv_exp ).
  ENDMETHOD.


  METHOD keeps_missing_rates_initial.
    " XDR has only a forex buying rate
    DATA ls_xdr TYPE lif_tcmb=>ty_rate.
    DATA lv_exp TYPE lif_tcmb=>ty_value.
    ls_xdr = rate( 'XDR' ).

    lv_exp = '67.5422'.
    cl_aunit_assert=>assert_equals( act = ls_xdr-fx_buy exp = lv_exp ).
    cl_aunit_assert=>assert_initial( ls_xdr-fx_sell ).
    cl_aunit_assert=>assert_initial( ls_xdr-bn_buy ).
    cl_aunit_assert=>assert_initial( ls_xdr-bn_sell ).
  ENDMETHOD.


  METHOD rejects_other_xml.
    assert_parse_error( `<html><body>Not found</body></html>` ).
  ENDMETHOD.


  METHOD rejects_broken_xml.
    assert_parse_error( `<Tarih_Date Tarih="30.10.2026"><Currency>` ).
  ENDMETHOD.


  METHOD rejects_bad_number.
    DATA lv_xml TYPE string.
    CONCATENATE `<Tarih_Date Tarih="30.10.2026" Bulten_No="1">`
                `<Currency CurrencyCode="USD"><Unit>1</Unit><ForexBuying>abc</ForexBuying></Currency>`
                `</Tarih_Date>` INTO lv_xml.
    assert_parse_error( lv_xml ).
  ENDMETHOD.

  METHOD rejects_bad_date.
    DATA lv_xml TYPE string.
    CONCATENATE `<Tarih_Date Tarih="31.02.2026"><Currency CurrencyCode="USD">`
      `<Unit>1</Unit><ForexBuying>1</ForexBuying></Currency></Tarih_Date>` INTO lv_xml.
    assert_parse_error( lv_xml ).
  ENDMETHOD.

  METHOD rejects_bad_code.
    DATA lv_xml TYPE string.
    CONCATENATE `<Tarih_Date Tarih="30.10.2026"><Currency CurrencyCode="USDX">`
      `<Unit>1</Unit><ForexBuying>1</ForexBuying></Currency></Tarih_Date>` INTO lv_xml.
    assert_parse_error( lv_xml ).
  ENDMETHOD.

  METHOD rejects_duplicate_code.
    DATA lv_xml TYPE string.
    CONCATENATE `<Tarih_Date Tarih="30.10.2026">`
      `<Currency CurrencyCode="USD"><Unit>1</Unit><ForexBuying>1</ForexBuying></Currency>`
      `<Currency CurrencyCode="USD"><Unit>1</Unit><ForexBuying>2</ForexBuying></Currency>`
      `</Tarih_Date>` INTO lv_xml.
    assert_parse_error( lv_xml ).
  ENDMETHOD.

  METHOD rejects_bad_unit.
    DATA lv_xml TYPE string.
    CONCATENATE `<Tarih_Date Tarih="30.10.2026"><Currency CurrencyCode="USD">`
      `<Unit>1.5</Unit><ForexBuying>1</ForexBuying></Currency></Tarih_Date>` INTO lv_xml.
    assert_parse_error( lv_xml ).
    REPLACE `<Unit>1.5</Unit>` IN lv_xml WITH `<Unit/>`.
    assert_parse_error( lv_xml ).
  ENDMETHOD.

  METHOD rejects_nonpositive_rate.
    DATA lv_xml TYPE string.
    CONCATENATE `<Tarih_Date Tarih="30.10.2026"><Currency CurrencyCode="USD">`
      `<Unit>1</Unit><ForexBuying>0</ForexBuying></Currency></Tarih_Date>` INTO lv_xml.
    assert_parse_error( lv_xml ).
    REPLACE `<ForexBuying>0</ForexBuying>` IN lv_xml WITH `<ForexBuying>-1</ForexBuying>`.
    assert_parse_error( lv_xml ).
  ENDMETHOD.


  METHOD parse_sample.
    DATA lv_xml TYPE xstring.
    DATA lx_error TYPE REF TO lcx_tcmb.
    DATA lv_text TYPE string.
    lv_xml = sample( ).
    TRY.
        rs_bulletin = mo_cut->parse( lv_xml ).
      CATCH lcx_tcmb INTO lx_error.
        lv_text = lx_error->get_text( ).
        cl_aunit_assert=>fail( lv_text ).
    ENDTRY.
  ENDMETHOD.


  METHOD rate.
    DATA ls_bulletin TYPE lif_tcmb=>ty_bulletin.
    ls_bulletin = parse_sample( ).
    READ TABLE ls_bulletin-rates INTO rs_rate WITH KEY code = iv_code.
    cl_aunit_assert=>assert_equals( act = sy-subrc exp = 0 msg = `Currency missing in the bulletin` ).
  ENDMETHOD.


  METHOD assert_parse_error.
    DATA lv_xml TYPE xstring.
    DATA lx_error TYPE REF TO lcx_tcmb.
    lv_xml = utf8( iv_xml ).
    TRY.
        mo_cut->parse( lv_xml ).
        cl_aunit_assert=>fail( `No error raised` ).
      CATCH lcx_tcmb INTO lx_error.
        cl_aunit_assert=>assert_equals( act = lx_error->kind exp = lcx_tcmb=>kinds-parse ).
    ENDTRY.
  ENDMETHOD.


  METHOD sample.
    " Shortened from https://www.tcmb.gov.tr/kurlar/202610/30102026.xml
    DATA lv_text TYPE string.
    CONCATENATE
      `<?xml version="1.0" encoding="UTF-8"?>`
      `<Tarih_Date Tarih="30.10.2026" Date="10/30/2026" Bulten_No="2026/204">`
      `<Currency CrossOrder="0" Kod="USD" CurrencyCode="USD"><Unit>1</Unit>`
      `<Isim>ABD DOLARI</Isim><CurrencyName>US DOLLAR</CurrencyName>`
      `<ForexBuying>49.7747</ForexBuying><ForexSelling>49.8644</ForexSelling>`
      `<BanknoteBuying>49.7399</BanknoteBuying><BanknoteSelling>49.9392</BanknoteSelling>`
      `<CrossRateUSD/><CrossRateOther/></Currency>`
      `<Currency CrossOrder="5" Kod="JPY" CurrencyCode="JPY"><Unit>100</Unit>`
      `<ForexBuying>31.5605</ForexBuying><ForexSelling>31.7695</ForexSelling>`
      `<BanknoteBuying>31.4437</BanknoteBuying><BanknoteSelling>31.8902</BanknoteSelling>`
      `<CrossRateUSD>157.33</CrossRateUSD><CrossRateOther/></Currency>`
      `<Currency CrossOrder="0" Kod="XDR" CurrencyCode="XDR"><Unit>1</Unit>`
      `<ForexBuying>67.5422</ForexBuying><ForexSelling/><BanknoteBuying/><BanknoteSelling/>`
      `<CrossRateUSD/><CrossRateOther>1.35574</CrossRateOther></Currency>`
      `</Tarih_Date>` INTO lv_text.
    rv_xml = utf8( lv_text ).
  ENDMETHOD.


  METHOD utf8.
    DATA lo_conv TYPE REF TO cl_abap_conv_out_ce.
    lo_conv = cl_abap_conv_out_ce=>create( encoding = 'UTF-8' ).
    lo_conv->convert( EXPORTING data = iv_text IMPORTING buffer = rv_xml ).
  ENDMETHOD.

ENDCLASS.


CLASS ltc_date_rule DEFINITION FINAL FOR TESTING.
  "#AU Risk_Level Harmless
  "#AU Duration Short
  PRIVATE SECTION.
    METHODS same_day FOR TESTING.
    METHODS next_day_crosses_month FOR TESTING.
    METHODS rejects_unknown_rule FOR TESTING.
    METHODS workday_needs_calendar FOR TESTING.

    METHODS valid_from
      IMPORTING
        iv_rule        TYPE lif_tcmb=>ty_date_rule
        iv_date        TYPE d
      RETURNING
        value(rv_date) TYPE d.

    METHODS assert_config_error
      IMPORTING
        iv_rule     TYPE lif_tcmb=>ty_date_rule
        iv_calendar TYPE wfcid OPTIONAL.
ENDCLASS.



CLASS ltc_date_rule IMPLEMENTATION.

  METHOD same_day.
    DATA lv_date TYPE d.
    lv_date = valid_from( iv_rule = lif_tcmb=>date_rule-same_day iv_date = '20261030' ).
    cl_aunit_assert=>assert_equals( act = lv_date exp = '20261030' ).
  ENDMETHOD.


  METHOD next_day_crosses_month.
    DATA lv_date TYPE d.
    lv_date = valid_from( iv_rule = lif_tcmb=>date_rule-next_day iv_date = '20261031' ).
    cl_aunit_assert=>assert_equals( act = lv_date exp = '20261101' ).
  ENDMETHOD.


  METHOD rejects_unknown_rule.
    assert_config_error( 'TOMORROW' ).
  ENDMETHOD.


  METHOD workday_needs_calendar.
    assert_config_error( lif_tcmb=>date_rule-next_workday ).
  ENDMETHOD.


  METHOD valid_from.
    DATA lo_cut TYPE REF TO lcl_date_rule.
    DATA lx_error TYPE REF TO lcx_tcmb.
    DATA lv_text TYPE string.
    TRY.
        CREATE OBJECT lo_cut
          EXPORTING
            iv_rule = iv_rule.
        rv_date = lo_cut->valid_from( iv_date ).
      CATCH lcx_tcmb INTO lx_error.
        lv_text = lx_error->get_text( ).
        cl_aunit_assert=>fail( lv_text ).
    ENDTRY.
  ENDMETHOD.


  METHOD assert_config_error.
    DATA lo_cut TYPE REF TO lcl_date_rule.
    DATA lx_error TYPE REF TO lcx_tcmb.
    TRY.
        CREATE OBJECT lo_cut
          EXPORTING
            iv_rule     = iv_rule
            iv_calendar = iv_calendar.
        cl_aunit_assert=>fail( `No error raised` ).
      CATCH lcx_tcmb INTO lx_error.
        cl_aunit_assert=>assert_equals( act = lx_error->kind exp = lcx_tcmb=>kinds-config ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


CLASS ltc_calc DEFINITION FINAL FOR TESTING.
  "#AU Risk_Level Harmless
  "#AU Duration Short
  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO lcl_calc.
    DATA ms_bulletin TYPE lif_tcmb=>ty_bulletin.
    DATA ms_settings TYPE lif_tcmb=>ty_settings.
    DATA mt_factors TYPE lif_tcmb=>ty_factors.
    DATA mt_known TYPE lif_tcmb=>ty_currency_codes.
    DATA mt_built TYPE lif_tcmb=>ty_lines.
    DATA mv_lines TYPE i.

    METHODS setup.
    METHODS direct_rate FOR TESTING.
    METHODS unit_with_matching_ratio FOR TESTING.
    METHODS unit_with_ratio_one FOR TESTING.
    METHODS average_rate FOR TESTING.
    METHODS missing_tcmb_rate FOR TESTING.
    METHODS unknown_sap_currency FOR TESTING.
    METHODS missing_ratio FOR TESTING.
    METHODS wanted_currencies_only FOR TESTING.
    METHODS excluded_currency FOR TESTING.
    METHODS renamed_currency FOR TESTING.
    METHODS inverse_rate FOR TESTING.
    METHODS inverse_uses_direct_ratio FOR TESTING.
    METHODS one_line_per_rate_type FOR TESTING.
    METHODS renames_read FOR TESTING.
    METHODS renames_rejected FOR TESTING.
    METHODS rejects_zero_factor FOR TESTING.
    METHODS rejects_zero_unit FOR TESTING.
    METHODS rejects_cross_target FOR TESTING.

    METHODS build
      RETURNING
        value(rt_lines) TYPE lif_tcmb=>ty_lines.

    METHODS add_rate
      IMPORTING
        iv_code    TYPE lif_tcmb=>ty_code
        iv_unit    TYPE i
        iv_fx_buy  TYPE csequence
        iv_fx_sell TYPE csequence OPTIONAL
        iv_bn_buy  TYPE csequence OPTIONAL
        iv_bn_sell TYPE csequence OPTIONAL.

    METHODS add_factor
      IMPORTING
        iv_kurst TYPE tcurf-kurst
        iv_fcurr TYPE tcurf-fcurr
        iv_tcurr TYPE tcurf-tcurr
        iv_ffact TYPE tcurf-ffact.

    METHODS map
      IMPORTING
        iv_source    TYPE lif_tcmb=>ty_source
        iv_rate_type TYPE tcurr-kurst DEFAULT 'M'.

    METHODS only
      IMPORTING
        iv_code TYPE lif_tcmb=>ty_code
        iv_sign TYPE ddsign DEFAULT 'I'.

    METHODS line
      IMPORTING
        it_lines       TYPE lif_tcmb=>ty_lines
        iv_from        TYPE waers
        iv_to          TYPE waers DEFAULT 'TRY'
        iv_rate_type   TYPE tcurr-kurst DEFAULT 'M'
      RETURNING
        value(rs_line) TYPE lif_tcmb=>ty_line.

    METHODS assert_rename_error
      IMPORTING
        iv_text TYPE string.
ENDCLASS.



CLASS ltc_calc IMPLEMENTATION.

  METHOD setup.
    DATA lv_waers TYPE waers.

    CREATE OBJECT mo_cut.
    CLEAR: ms_bulletin, ms_settings, mt_factors, mt_known.
    ms_bulletin-date = '20261030'.
    add_rate( iv_code = 'USD' iv_unit = 1 iv_fx_buy = '49.7747' iv_fx_sell = '49.8644'
              iv_bn_buy = '49.7399' iv_bn_sell = '49.9392' ).
    add_rate( iv_code = 'JPY' iv_unit = 100 iv_fx_buy = '31.5605' iv_fx_sell = '31.7695' ).
    add_rate( iv_code = 'XDR' iv_unit = 1 iv_fx_buy = '67.5422' ).
    ms_settings-target_currency = 'TRY'.
    add_factor( iv_kurst = 'M' iv_fcurr = 'USD' iv_tcurr = 'TRY' iv_ffact = 1 ).
    add_factor( iv_kurst = 'M' iv_fcurr = 'JPY' iv_tcurr = 'TRY' iv_ffact = 100 ).
    add_factor( iv_kurst = 'M' iv_fcurr = 'XDR' iv_tcurr = 'TRY' iv_ffact = 1 ).
    add_factor( iv_kurst = 'M' iv_fcurr = 'TRY' iv_tcurr = 'USD' iv_ffact = 1 ).
    add_factor( iv_kurst = 'B' iv_fcurr = 'USD' iv_tcurr = 'TRY' iv_ffact = 1 ).
    lv_waers = 'EUR'.
    INSERT lv_waers INTO TABLE mt_known.
    lv_waers = 'JPY'.
    INSERT lv_waers INTO TABLE mt_known.
    lv_waers = 'TRY'.
    INSERT lv_waers INTO TABLE mt_known.
    lv_waers = 'USD'.
    INSERT lv_waers INTO TABLE mt_known.
    lv_waers = 'XDR'.
    INSERT lv_waers INTO TABLE mt_known.
  ENDMETHOD.


  METHOD direct_rate.
    DATA ls_line TYPE lif_tcmb=>ty_line.
    map( lif_tcmb=>source-fx_buy ).

    mt_built = build( ).
    ls_line = line( it_lines = mt_built iv_from = 'USD' ).

    cl_aunit_assert=>assert_initial( act = ls_line-status msg = ls_line-message ).
    cl_aunit_assert=>assert_equals( act = ls_line-rate exp = '49.7747' ).
    cl_aunit_assert=>assert_equals( act = ls_line-valid_from exp = '20261030' ).
    cl_aunit_assert=>assert_equals( act = ls_line-indirect exp = abap_false ).
  ENDMETHOD.


  METHOD unit_with_matching_ratio.
    " TCMB quotes 100 JPY; TCURF says 100 JPY : 1 TRY, so the value stays
    DATA ls_line TYPE lif_tcmb=>ty_line.
    map( lif_tcmb=>source-fx_buy ).

    mt_built = build( ).
    ls_line = line( it_lines = mt_built iv_from = 'JPY' ).

    cl_aunit_assert=>assert_equals( act = ls_line-rate exp = '31.5605' ).
    cl_aunit_assert=>assert_equals( act = ls_line-from_factor exp = 100 ).
  ENDMETHOD.


  METHOD unit_with_ratio_one.
    " With 1 JPY : 1 TRY the rate is per yen, rounded to 5 decimals
    DATA ls_line TYPE lif_tcmb=>ty_line.
    CLEAR mt_factors.
    add_factor( iv_kurst = 'M' iv_fcurr = 'JPY' iv_tcurr = 'TRY' iv_ffact = 1 ).
    map( lif_tcmb=>source-fx_buy ).

    mt_built = build( ).
    ls_line = line( it_lines = mt_built iv_from = 'JPY' ).

    cl_aunit_assert=>assert_equals( act = ls_line-rate exp = '0.31561' ).
  ENDMETHOD.


  METHOD average_rate.
    DATA ls_line TYPE lif_tcmb=>ty_line.
    map( lif_tcmb=>source-fx_avg ).

    mt_built = build( ).
    ls_line = line( it_lines = mt_built iv_from = 'USD' ).

    cl_aunit_assert=>assert_equals( act = ls_line-rate exp = '49.81955' ).
  ENDMETHOD.


  METHOD missing_tcmb_rate.
    " XDR has no forex selling rate
    DATA ls_line TYPE lif_tcmb=>ty_line.
    map( lif_tcmb=>source-fx_sell ).

    mt_built = build( ).
    ls_line = line( it_lines = mt_built iv_from = 'XDR' ).

    cl_aunit_assert=>assert_equals( act = ls_line-status exp = lif_tcmb=>status-skipped ).
  ENDMETHOD.


  METHOD unknown_sap_currency.
    DATA ls_line TYPE lif_tcmb=>ty_line.
    DELETE mt_known WHERE table_line = 'XDR'.
    map( lif_tcmb=>source-fx_buy ).

    mt_built = build( ).
    ls_line = line( it_lines = mt_built iv_from = 'XDR' ).

    cl_aunit_assert=>assert_equals( act = ls_line-status exp = lif_tcmb=>status-skipped ).
    IF ls_line-message NS 'TCURC'.
      cl_aunit_assert=>fail( ls_line-message ).
    ENDIF.
  ENDMETHOD.


  METHOD missing_ratio.
    DATA ls_line TYPE lif_tcmb=>ty_line.
    DELETE mt_factors WHERE fcurr = 'USD'.
    map( lif_tcmb=>source-fx_buy ).

    mt_built = build( ).
    ls_line = line( it_lines = mt_built iv_from = 'USD' ).

    cl_aunit_assert=>assert_equals( act = ls_line-status exp = lif_tcmb=>status-error ).
    IF ls_line-message NS 'TCURF'.
      cl_aunit_assert=>fail( ls_line-message ).
    ENDIF.
  ENDMETHOD.


  METHOD wanted_currencies_only.
    DATA lt_lines TYPE lif_tcmb=>ty_lines.
    DATA ls_line TYPE lif_tcmb=>ty_line.
    only( 'USD' ).
    map( lif_tcmb=>source-fx_buy ).

    lt_lines = build( ).

    mv_lines = lines( lt_lines ).
    cl_aunit_assert=>assert_equals( act = mv_lines exp = 1 ).
    READ TABLE lt_lines INTO ls_line INDEX 1.
    cl_aunit_assert=>assert_equals( act = ls_line-from_curr exp = 'USD' ).
  ENDMETHOD.


  METHOD excluded_currency.
    DATA lt_lines TYPE lif_tcmb=>ty_lines.
    only( iv_code = 'JPY' iv_sign = 'E' ).
    map( lif_tcmb=>source-fx_buy ).

    lt_lines = build( ).

    mv_lines = lines( lt_lines ).
    cl_aunit_assert=>assert_equals( act = mv_lines exp = 2 ).
    READ TABLE lt_lines TRANSPORTING NO FIELDS WITH KEY tcmb_code = 'JPY'.
    cl_aunit_assert=>assert_differs( act = sy-subrc exp = 0 ).
  ENDMETHOD.


  METHOD renamed_currency.
    " A system that keeps the US dollar as 'USD2'
    DATA ls_line TYPE lif_tcmb=>ty_line.
    DATA ls_rename TYPE lif_tcmb=>ty_rename.
    DATA lv_waers TYPE waers.
    only( 'USD' ).
    ls_rename-tcmb_code = 'USD'.
    ls_rename-sap_currency = 'USD2'.
    INSERT ls_rename INTO TABLE ms_settings-renames.
    lv_waers = 'USD2'.
    INSERT lv_waers INTO TABLE mt_known.
    add_factor( iv_kurst = 'M' iv_fcurr = 'USD2' iv_tcurr = 'TRY' iv_ffact = 1 ).
    map( lif_tcmb=>source-fx_buy ).

    mt_built = build( ).
    ls_line = line( it_lines = mt_built iv_from = 'USD2' ).

    cl_aunit_assert=>assert_equals( act = ls_line-tcmb_code exp = 'USD' ).
    cl_aunit_assert=>assert_equals( act = ls_line-rate exp = '49.7747' ).
  ENDMETHOD.


  METHOD inverse_rate.
    DATA lt_lines TYPE lif_tcmb=>ty_lines.
    DATA ls_inverse TYPE lif_tcmb=>ty_line.
    ms_settings-write_inverse = abap_true.
    only( 'USD' ).
    map( lif_tcmb=>source-fx_buy ).

    lt_lines = build( ).
    ls_inverse = line( it_lines = lt_lines iv_from = 'TRY' iv_to = 'USD' ).

    mv_lines = lines( lt_lines ).
    cl_aunit_assert=>assert_equals( act = mv_lines exp = 2 ).
    cl_aunit_assert=>assert_equals( act = ls_inverse-indirect exp = abap_true ).
    cl_aunit_assert=>assert_equals( act = ls_inverse-rate exp = '49.7747' ).
  ENDMETHOD.


  METHOD inverse_uses_direct_ratio.
    " TRY -> JPY is quoted per 100 JPY, like JPY -> TRY, so no precision is lost
    DATA ls_inverse TYPE lif_tcmb=>ty_line.
    ms_settings-write_inverse = abap_true.
    only( 'JPY' ).
    map( lif_tcmb=>source-fx_buy ).

    mt_built = build( ).
    ls_inverse = line( it_lines = mt_built iv_from = 'TRY' iv_to = 'JPY' ).

    cl_aunit_assert=>assert_equals( act = ls_inverse-rate exp = '31.5605' ).
    cl_aunit_assert=>assert_equals( act = ls_inverse-from_factor exp = 1 ).
    cl_aunit_assert=>assert_equals( act = ls_inverse-to_factor exp = 100 ).
  ENDMETHOD.


  METHOD one_line_per_rate_type.
    DATA lt_lines TYPE lif_tcmb=>ty_lines.
    DATA ls_line TYPE lif_tcmb=>ty_line.
    only( 'USD' ).
    map( iv_source = lif_tcmb=>source-fx_buy iv_rate_type = 'M' ).
    map( iv_source = lif_tcmb=>source-fx_sell iv_rate_type = 'B' ).

    lt_lines = build( ).

    ls_line = line( it_lines = lt_lines iv_from = 'USD' iv_rate_type = 'M' ).
    cl_aunit_assert=>assert_equals( act = ls_line-rate exp = '49.7747' ).
    ls_line = line( it_lines = lt_lines iv_from = 'USD' iv_rate_type = 'B' ).
    cl_aunit_assert=>assert_equals( act = ls_line-rate exp = '49.8644' ).
  ENDMETHOD.


  METHOD renames_read.
    DATA lt_renames TYPE lif_tcmb=>ty_renames.
    DATA ls_rename TYPE lif_tcmb=>ty_rename.
    DATA lx_error TYPE REF TO lcx_tcmb.
    DATA lv_text TYPE string.
    TRY.
        lt_renames = lcl_calc=>parse_renames( `usd = USD2, XAU=GLD;  EUR=EUR1` ).
        mv_lines = lines( lt_renames ).
        cl_aunit_assert=>assert_equals( act = mv_lines exp = 3 ).
        READ TABLE lt_renames INTO ls_rename WITH TABLE KEY tcmb_code = 'USD'.
        cl_aunit_assert=>assert_equals( act = ls_rename-sap_currency exp = 'USD2' ).
        READ TABLE lt_renames INTO ls_rename WITH TABLE KEY tcmb_code = 'XAU'.
        cl_aunit_assert=>assert_equals( act = ls_rename-sap_currency exp = 'GLD' ).
        lt_renames = lcl_calc=>parse_renames( `` ).
        cl_aunit_assert=>assert_initial( lt_renames ).
      CATCH lcx_tcmb INTO lx_error.
        lv_text = lx_error->get_text( ).
        cl_aunit_assert=>fail( lv_text ).
    ENDTRY.
  ENDMETHOD.


  METHOD renames_rejected.
    assert_rename_error( `USD` ).
    assert_rename_error( `USD=` ).
    assert_rename_error( `DOLLAR=USD` ).
    assert_rename_error( `USD=USD2 USD=USD3` ).
    assert_rename_error( `US=USD2` ).
    assert_rename_error( `US1=USD2` ).
  ENDMETHOD.

  METHOD rejects_zero_factor.
    DATA ls_line TYPE lif_tcmb=>ty_line.
    FIELD-SYMBOLS <factor> TYPE lif_tcmb=>ty_factor.
    only( 'USD' ).
    map( lif_tcmb=>source-fx_buy ).
    READ TABLE mt_factors ASSIGNING <factor> WITH TABLE KEY kurst = 'M' fcurr = 'USD' tcurr = 'TRY'.
    <factor>-tfact = 0.
    mt_built = build( ).
    READ TABLE mt_built INTO ls_line INDEX 1.
    cl_aunit_assert=>assert_equals( act = ls_line-status exp = lif_tcmb=>status-error ).
  ENDMETHOD.

  METHOD rejects_zero_unit.
    DATA ls_line TYPE lif_tcmb=>ty_line.
    FIELD-SYMBOLS <rate> TYPE lif_tcmb=>ty_rate.
    only( 'USD' ).
    map( lif_tcmb=>source-fx_buy ).
    READ TABLE ms_bulletin-rates ASSIGNING <rate> WITH KEY code = 'USD'.
    <rate>-unit = 0.
    mt_built = build( ).
    READ TABLE mt_built INTO ls_line INDEX 1.
    cl_aunit_assert=>assert_equals( act = ls_line-status exp = lif_tcmb=>status-error ).
  ENDMETHOD.

  METHOD rejects_cross_target.
    DATA ls_line TYPE lif_tcmb=>ty_line.
    ms_settings-target_currency = 'EUR'.
    map( lif_tcmb=>source-fx_buy ).
    mt_built = build( ).
    READ TABLE mt_built INTO ls_line INDEX 1.
    cl_aunit_assert=>assert_equals( act = ls_line-status exp = lif_tcmb=>status-error ).
  ENDMETHOD.


  METHOD build.
    rt_lines = mo_cut->build_lines( is_bulletin   = ms_bulletin
                                    is_settings   = ms_settings
                                    iv_valid_from = ms_bulletin-date
                                    it_factors    = mt_factors
                                    it_known      = mt_known ).
  ENDMETHOD.


  METHOD add_rate.
    DATA ls_rate TYPE lif_tcmb=>ty_rate.
    ls_rate-code    = iv_code.
    ls_rate-unit    = iv_unit.
    ls_rate-fx_buy  = iv_fx_buy.
    ls_rate-fx_sell = iv_fx_sell.
    ls_rate-bn_buy  = iv_bn_buy.
    ls_rate-bn_sell = iv_bn_sell.
    APPEND ls_rate TO ms_bulletin-rates.
  ENDMETHOD.


  METHOD add_factor.
    DATA ls_factor TYPE lif_tcmb=>ty_factor.
    ls_factor-kurst = iv_kurst.
    ls_factor-fcurr = iv_fcurr.
    ls_factor-tcurr = iv_tcurr.
    ls_factor-ffact = iv_ffact.
    ls_factor-tfact = 1.
    INSERT ls_factor INTO TABLE mt_factors.
  ENDMETHOD.


  METHOD map.
    DATA ls_mapping TYPE lif_tcmb=>ty_mapping.
    ls_mapping-rate_type = iv_rate_type.
    ls_mapping-source    = iv_source.
    APPEND ls_mapping TO ms_settings-mappings.
  ENDMETHOD.


  METHOD only.
    DATA ls_code LIKE LINE OF ms_settings-codes.
    ls_code-sign   = iv_sign.
    ls_code-option = 'EQ'.
    ls_code-low    = iv_code.
    APPEND ls_code TO ms_settings-codes.
  ENDMETHOD.


  METHOD line.
    DATA lv_message TYPE string.
    READ TABLE it_lines INTO rs_line
      WITH KEY from_curr = iv_from to_curr = iv_to rate_type = iv_rate_type.
    IF sy-subrc <> 0.
      CONCATENATE `No line ` iv_rate_type ` ` iv_from `/` iv_to INTO lv_message.
      cl_aunit_assert=>fail( lv_message ).
    ENDIF.
  ENDMETHOD.


  METHOD assert_rename_error.
    DATA lx_error TYPE REF TO lcx_tcmb.
    DATA lv_message TYPE string.
    TRY.
        lcl_calc=>parse_renames( iv_text ).
        CONCATENATE `No error raised for "` iv_text `"` INTO lv_message.
        cl_aunit_assert=>fail( lv_message ).
      CATCH lcx_tcmb INTO lx_error.
        cl_aunit_assert=>assert_equals( act = lx_error->kind exp = lcx_tcmb=>kinds-config ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


CLASS ltc_loader DEFINITION FINAL FOR TESTING.
  "#AU Risk_Level Harmless
  "#AU Duration Short
  PRIVATE SECTION.
    DATA ms_settings TYPE lif_tcmb=>ty_settings.

    METHODS setup.
    METHODS weekdays FOR TESTING.
    METHODS valid_settings FOR TESTING.
    METHODS needs_a_rate_type FOR TESTING.
    METHODS rate_type_used_twice FOR TESTING.
    METHODS needs_a_date_rule FOR TESTING.
    METHODS folder_needs_a_path FOR TESTING.
    METHODS rejects_cross_target FOR TESTING.

    METHODS assert_problem
      IMPORTING
        iv_pattern TYPE csequence.
ENDCLASS.



CLASS ltc_loader IMPLEMENTATION.

  METHOD setup.
    DATA ls_mapping TYPE lif_tcmb=>ty_mapping.
    CLEAR ms_settings.
    ls_mapping-rate_type = 'M'.
    ls_mapping-source    = lif_tcmb=>source-fx_buy.
    APPEND ls_mapping TO ms_settings-mappings.
    ms_settings-date_rule = lif_tcmb=>date_rule-next_day.
    ms_settings-origin    = lif_tcmb=>origin-https.
  ENDMETHOD.


  METHOD weekdays.
    " 30 Oct 2026 is a Friday
    DATA lv_bool TYPE abap_bool.
    lv_bool = lcl_loader=>is_weekday( '20261030' ).
    cl_aunit_assert=>assert_equals( act = lv_bool exp = abap_true ).
    lv_bool = lcl_loader=>is_weekday( '20261031' ).
    cl_aunit_assert=>assert_equals( act = lv_bool exp = abap_false ).
    lv_bool = lcl_loader=>is_weekday( '20261101' ).
    cl_aunit_assert=>assert_equals( act = lv_bool exp = abap_false ).
    lv_bool = lcl_loader=>is_weekday( '20261102' ).
    cl_aunit_assert=>assert_equals( act = lv_bool exp = abap_true ).
  ENDMETHOD.


  METHOD valid_settings.
    DATA lv_problem TYPE string.
    lv_problem = lcl_loader=>check( ms_settings ).
    cl_aunit_assert=>assert_initial( act = lv_problem msg = lv_problem ).
  ENDMETHOD.


  METHOD needs_a_rate_type.
    CLEAR ms_settings-mappings.
    assert_problem( '*rate type*' ).
  ENDMETHOD.


  METHOD rate_type_used_twice.
    DATA ls_mapping TYPE lif_tcmb=>ty_mapping.
    ls_mapping-rate_type = 'M'.
    ls_mapping-source    = lif_tcmb=>source-fx_sell.
    APPEND ls_mapping TO ms_settings-mappings.
    assert_problem( '*two TCMB rates*' ).
  ENDMETHOD.


  METHOD needs_a_date_rule.
    CLEAR ms_settings-date_rule.
    assert_problem( '*date rule*' ).
  ENDMETHOD.


  METHOD folder_needs_a_path.
    ms_settings-origin = lif_tcmb=>origin-folder.
    assert_problem( '*folder*' ).
  ENDMETHOD.

  METHOD rejects_cross_target.
    ms_settings-target_currency = 'EUR'.
    assert_problem( '*TRY*' ).
  ENDMETHOD.


  METHOD assert_problem.
    DATA lv_problem TYPE string.
    lv_problem = lcl_loader=>check( ms_settings ).
    IF lv_problem NP iv_pattern.
      cl_aunit_assert=>fail( lv_problem ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.


CLASS ltc_writer DEFINITION FINAL FOR TESTING.
  "#AU Risk_Level Harmless
  "#AU Duration Short
  PRIVATE SECTION.
    METHODS inverted_date FOR TESTING.
ENDCLASS.



CLASS ltc_writer IMPLEMENTATION.

  METHOD inverted_date.
    DATA lv_gdatu TYPE tcurr-gdatu.
    lv_gdatu = lcl_writer=>inverted_date( '20261030' ).
    cl_aunit_assert=>assert_equals( act = lv_gdatu exp = '79738969' ).
    lv_gdatu = lcl_writer=>inverted_date( '20010101' ).
    cl_aunit_assert=>assert_equals( act = lv_gdatu exp = '79989898' ).
  ENDMETHOD.

ENDCLASS.


CLASS ltc_fmt DEFINITION FINAL FOR TESTING.
  "#AU Risk_Level Harmless
  "#AU Duration Short
  PRIVATE SECTION.
    METHODS texts FOR TESTING.
ENDCLASS.



CLASS ltc_fmt IMPLEMENTATION.

  METHOD texts.
    DATA lv_value TYPE lif_tcmb=>ty_value.
    DATA lv_rate TYPE tcurr-ukurs.
    DATA lv_text TYPE string.
    lv_text = lcl_fmt=>date( '20261030' ).
    cl_aunit_assert=>assert_equals( act = lv_text exp = `2026-10-30` ).
    lv_text = lcl_fmt=>int( 42 ).
    cl_aunit_assert=>assert_equals( act = lv_text exp = `42` ).
    lv_value = '49.7747'.
    lv_text = lcl_fmt=>num( lv_value ).
    cl_aunit_assert=>assert_equals( act = lv_text exp = `49.7747` ).
    lv_rate = '12'.
    lv_text = lcl_fmt=>num( lv_rate ).
    cl_aunit_assert=>assert_equals( act = lv_text exp = `12` ).
  ENDMETHOD.

ENDCLASS.


CLASS ltc_source_file DEFINITION FINAL FOR TESTING.
  "#AU Risk_Level Harmless
  "#AU Duration Short
  PRIVATE SECTION.
    METHODS preserves_folder_spaces FOR TESTING.
ENDCLASS.

CLASS ltc_source_file IMPLEMENTATION.
  METHOD preserves_folder_spaces.
    DATA lv_file TYPE string.
    lv_file = lcl_source_file=>file_name( iv_folder = `/tmp/two  spaces` iv_date = '20261030' ).
    cl_aunit_assert=>assert_equals( act = lv_file exp = `/tmp/two  spaces/30102026.xml` ).
    lv_file = lcl_source_file=>file_name( iv_folder = `C:\two  spaces\` iv_date = '20261030' ).
    cl_aunit_assert=>assert_equals( act = lv_file exp = `C:\two  spaces\30102026.xml` ).
  ENDMETHOD.
ENDCLASS.

INITIALIZATION.
  lcl_app=>set_texts( ).

AT SELECTION-SCREEN OUTPUT.
  lcl_app=>set_date_rules( ).

AT SELECTION-SCREEN.
  CASE sscrfields-ucomm.
    WHEN 'CONN'.
      lcl_app=>test_connection( ).
    WHEN 'ONLI' OR 'PRIN' OR 'SJOB'.
      lcl_app=>check_screen( ).
  ENDCASE.

START-OF-SELECTION.
  IF s_date-high IS INITIAL.
    gv_to = s_date-low.
  ELSE.
    gv_to = s_date-high.
  ENDIF.
  lcl_app=>run( iv_from = s_date-low
                iv_to   = gv_to
                iv_test = p_test ).
