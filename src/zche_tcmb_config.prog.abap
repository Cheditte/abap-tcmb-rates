*& Simple settings editor. Does not fetch bulletins or write exchange rates.
*& MIT License, Copyright (c) 2026 Ali Emre Altuntas
REPORT zche_tcmb_config.
TABLES sscrfields.
DATA gv_currency TYPE zche_tcmb_code.

PARAMETERS p_prof TYPE zche_tcmb_profile OBLIGATORY.
SELECTION-SCREEN PUSHBUTTON /1(40) b_load USER-COMMAND load.
PARAMETERS p_desc TYPE zche_tcmb_descr.
PARAMETERS p_rule TYPE zche_tcmb_date_rule DEFAULT 'SAME_DAY'.
PARAMETERS p_cal TYPE wfcid.
PARAMETERS p_type TYPE kurst DEFAULT 'M'.
PARAMETERS p_src TYPE zche_tcmb_source DEFAULT 'FX_BUY'.
SELECT-OPTIONS s_curr FOR gv_currency NO INTERVALS.
PARAMETERS p_keep TYPE zche_tcmb_existing DEFAULT 'S'.
PARAMETERS p_none TYPE zche_tcmb_nodata DEFAULT 'I'.
PARAMETERS p_inv AS CHECKBOX.
SELECTION-SCREEN SKIP.
PARAMETERS p_file AS CHECKBOX.
PARAMETERS p_dest TYPE rfcdest.
PARAMETERS p_url TYPE zche_tcmb_url LOWER CASE.
PARAMETERS p_path TYPE zche_tcmb_path LOWER CASE.
PARAMETERS p_exit TYPE zche_tcmb_exit_class.
SELECTION-SCREEN SKIP.
PARAMETERS p_task TYPE trkorr.
PARAMETERS p_local AS CHECKBOX.
PARAMETERS p_save AS CHECKBOX.

CLASS lcl_settings DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS load RAISING zcx_che_tcmb.
    CLASS-METHODS save RAISING zcx_che_tcmb.
  PRIVATE SECTION.
    CLASS-DATA cached_profile TYPE zif_che_tcmb=>ty_profile.
    CLASS-DATA cached_mappings TYPE zif_che_tcmb=>ty_mappings.
    CLASS-DATA cached_currencies TYPE zif_che_tcmb=>ty_currencies.
    CLASS-METHODS authorize IMPORTING iv_activity TYPE c RAISING zcx_che_tcmb.
    CLASS-METHODS read_profile
      EXPORTING es_profile TYPE zif_che_tcmb=>ty_profile
                et_mappings TYPE zif_che_tcmb=>ty_mappings
                et_currencies TYPE zif_che_tcmb=>ty_currencies.
    CLASS-METHODS record_transport RAISING zcx_che_tcmb.
ENDCLASS.

CLASS lcl_settings IMPLEMENTATION.
  METHOD authorize.
    DATA tables TYPE STANDARD TABLE OF tabname WITH EMPTY KEY.
    tables = VALUE #( ( 'ZCHE_TCMB_PROF' ) ( 'ZCHE_TCMB_MAP' ) ( 'ZCHE_TCMB_CURR' ) ).
    LOOP AT tables INTO DATA(table).
      AUTHORITY-CHECK OBJECT 'S_TABU_NAM' ID 'TABLE' FIELD table ID 'ACTVT' FIELD iv_activity.
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = |Missing S_TABU_NAM activity { iv_activity } for { table }.|.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD read_profile.
    SELECT SINGLE * FROM zche_tcmb_prof WHERE profile = @p_prof INTO @es_profile.
    SELECT * FROM zche_tcmb_map WHERE profile = @p_prof ORDER BY PRIMARY KEY INTO TABLE @et_mappings.
    SELECT * FROM zche_tcmb_curr WHERE profile = @p_prof ORDER BY PRIMARY KEY INTO TABLE @et_currencies.
  ENDMETHOD.

  METHOD load.
    authorize( '03' ).
    read_profile( IMPORTING es_profile = DATA(profile) et_mappings = DATA(mappings) et_currencies = DATA(currencies) ).
    IF profile-profile IS INITIAL.
      RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = `Profile not found in this client. Enter settings to create it.`.
    ENDIF.
    zcl_che_tcmb_config_rules=>assert_simple( it_mappings = mappings it_currencies = currencies ).
    IF profile-source_class IS NOT INITIAL AND profile-source_class <> 'ZCL_CHE_TCMB_SOURCE_HTTP'
      AND profile-source_class <> 'ZCL_CHE_TCMB_SOURCE_FILE'.
      RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = `Use advanced maintenance for this custom source.`.
    ENDIF.
    cached_profile = profile.
    cached_mappings = mappings.
    cached_currencies = currencies.
    p_desc = profile-description.
    p_rule = profile-date_rule.
    p_cal = profile-factory_calendar.
    p_keep = COND #( WHEN profile-existing_rate IS INITIAL THEN 'U' ELSE profile-existing_rate ).
    p_none = COND #( WHEN profile-no_bulletin IS INITIAL THEN 'I' ELSE profile-no_bulletin ).
    p_inv = profile-write_inverse.
    p_file = xsdbool( profile-source_class = 'ZCL_CHE_TCMB_SOURCE_FILE' ).
    p_dest = profile-rfc_destination.
    p_url = profile-base_url.
    p_path = profile-file_folder.
    p_exit = profile-exit_class.
    CLEAR: p_type, p_src, s_curr[].
    IF mappings IS NOT INITIAL.
      p_type = mappings[ 1 ]-rate_type.
      p_src = mappings[ 1 ]-source.
    ENDIF.
    LOOP AT currencies INTO DATA(currency).
      APPEND VALUE #( sign = 'I' option = 'EQ' low = currency-tcmb_code ) TO s_curr.
    ENDLOOP.
    CLEAR p_save.
  ENDMETHOD.

  METHOD record_transport.
    SELECT SINGLE * FROM t000 WHERE mandt = @sy-mandt INTO @DATA(client).
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = `Cannot read current client settings (T000).`.
    ENDIF.
    zcl_che_tcmb_config_rules=>validate_client( iv_state = client-cccoractiv iv_local = p_local
      iv_has_task = xsdbool( p_task IS NOT INITIAL ) ).
    IF p_local = abap_true.
      RETURN.
    ENDIF.
    SELECT SINGLE * FROM e070 WHERE trkorr = @p_task INTO @DATA(task).
    IF sy-subrc <> 0 OR task-trstatus <> 'D' OR task-as4user <> sy-uname OR task-strkorr IS INITIAL
      OR ( task-trfunction <> 'Q' AND task-trfunction <> 'S' ).
      RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = `Enter your own modifiable Customizing or Workbench task in SE09/SE10.`.
    ENDIF.
    DATA objects TYPE STANDARD TABLE OF e071 WITH EMPTY KEY.
    DATA keys TYPE STANDARD TABLE OF e071k WITH EMPTY KEY.
    DATA tables TYPE STANDARD TABLE OF tabname WITH EMPTY KEY.
    tables = VALUE #( ( 'ZCHE_TCMB_PROF' ) ( 'ZCHE_TCMB_MAP' ) ( 'ZCHE_TCMB_CURR' ) ).
    LOOP AT tables INTO DATA(table).
      APPEND VALUE #( pgmid = 'R3TR' object = 'TABU' obj_name = table ) TO objects.
      DATA(key) = VALUE e071k( pgmid = 'R3TR' object = 'TABU' objname = table
        mastertype = 'TABU' mastername = table ).
      key-tabkey(3) = sy-mandt.
      key-tabkey+3(20) = p_prof.
      " Capture the whole profile, including removed child rows on transport.
      IF table <> 'ZCHE_TCMB_PROF'.
        key-tabkey+23(1) = '*'.
      ENDIF.
      APPEND key TO keys.
    ENDLOOP.
    CALL FUNCTION 'TR_APPEND_TO_COMM_OBJS_KEYS'
      EXPORTING wi_trkorr = p_task TABLES wt_e071 = objects wt_e071k = keys EXCEPTIONS OTHERS = 1.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = `Cannot record profile keys in the transport task. No settings were saved.`.
    ENDIF.
  ENDMETHOD.

  METHOD save.
    IF p_save <> abap_true.
      RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = `Select Save settings explicitly, then execute. Load existing settings with the button.`.
    ENDIF.
    authorize( '02' ).
    DATA lock_key TYPE rstable-varkey.
    lock_key(3) = sy-mandt.
    lock_key+3(20) = p_prof.
    CALL FUNCTION 'ENQUEUE_E_TABLE' EXPORTING tabname = 'ZCHE_TCMB_PROF' varkey = lock_key _scope = '1'
      EXCEPTIONS OTHERS = 1.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = `Profile is locked by another user. Try again after their work is complete.`.
    ENDIF.
    TRY.
        read_profile( IMPORTING es_profile = DATA(old_profile) et_mappings = DATA(old_maps) et_currencies = DATA(old_currencies) ).
        IF old_profile-profile IS NOT INITIAL AND
          ( cached_profile <> old_profile OR cached_mappings <> old_maps OR cached_currencies <> old_currencies ).
          RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = `Load the existing profile before editing. If it changed since loading, reload it before saving.`.
        ENDIF.
        zcl_che_tcmb_config_rules=>assert_simple( it_mappings = old_maps it_currencies = old_currencies ).
        IF old_profile-source_class IS NOT INITIAL AND old_profile-source_class <> 'ZCL_CHE_TCMB_SOURCE_HTTP'
          AND old_profile-source_class <> 'ZCL_CHE_TCMB_SOURCE_FILE'.
          RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = `This profile uses a custom source. Use advanced maintenance.`.
        ENDIF.
        DATA(profile) = VALUE zche_tcmb_prof( mandt = sy-mandt profile = p_prof description = p_desc
          date_rule = p_rule factory_calendar = p_cal target_currency = 'TRY' existing_rate = p_keep
          no_bulletin = p_none write_inverse = p_inv rfc_destination = p_dest base_url = p_url
          file_folder = p_path exit_class = p_exit
          source_class = COND #( WHEN p_file = abap_true THEN 'ZCL_CHE_TCMB_SOURCE_FILE' ELSE '' ) ).
        DATA(mappings) = VALUE zif_che_tcmb=>ty_mappings( ( mandt = sy-mandt profile = p_prof rate_type = p_type source = p_src ) ).
        DATA currencies TYPE zif_che_tcmb=>ty_currencies.
        LOOP AT s_curr INTO DATA(selection).
          IF selection-sign <> 'I' OR selection-option <> 'EQ' OR selection-high IS NOT INITIAL.
            RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = `Enter individual included currency codes; ranges, patterns and exclusions are not supported here.`.
          ENDIF.
          SELECT SINGLE waers FROM tcurc WHERE waers = @selection-low INTO @DATA(known_currency).
          IF sy-subrc <> 0 OR known_currency IS INITIAL.
            RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = |Currency { selection-low } is not defined in SAP.|.
          ENDIF.
          APPEND VALUE #( mandt = sy-mandt profile = p_prof tcmb_code = selection-low ) TO currencies.
        ENDLOOP.
        zcl_che_tcmb_config_rules=>validate( is_profile = profile it_mappings = mappings it_currencies = currencies ).
        SELECT SINGLE kurst FROM tcurv WHERE kurst = @p_type INTO @DATA(known_type).
        IF sy-subrc <> 0 OR known_type IS INITIAL.
          RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = `The selected rate type is not defined in SAP.`.
        ENDIF.
        record_transport( ).
        MODIFY zche_tcmb_prof FROM @profile.
        IF sy-subrc <> 0.
          RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = `Could not save profile.`.
        ENDIF.
        DELETE FROM zche_tcmb_map WHERE profile = @p_prof.
        INSERT zche_tcmb_map FROM TABLE @mappings.
        IF sy-subrc <> 0.
          RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = `Could not save rate mapping.`.
        ENDIF.
        DELETE FROM zche_tcmb_curr WHERE profile = @p_prof.
        INSERT zche_tcmb_curr FROM TABLE @currencies.
        IF sy-subrc <> 0.
          RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = `Could not save currencies.`.
        ENDIF.
        COMMIT WORK AND WAIT.
        IF sy-subrc <> 0.
          RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = `Commit failed. Review saved settings and SM13 before retrying.`.
        ENDIF.
      CATCH cx_root INTO DATA(error).
        ROLLBACK WORK.
        CALL FUNCTION 'DEQUEUE_E_TABLE' EXPORTING tabname = 'ZCHE_TCMB_PROF' varkey = lock_key _scope = '1'.
        RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = error->get_text( ) previous = error.
    ENDTRY.
    CALL FUNCTION 'DEQUEUE_E_TABLE' EXPORTING tabname = 'ZCHE_TCMB_PROF' varkey = lock_key _scope = '1'.
  ENDMETHOD.
ENDCLASS.

INITIALIZATION.
  b_load = 'Load existing profile into this screen'.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_rule.
  " Classic domain fixed-value keys cannot represent NEXT_WORKDAY in full.
  TYPES: BEGIN OF ty_rule,
           rule TYPE zche_tcmb_date_rule,
         END OF ty_rule.
  DATA rules TYPE STANDARD TABLE OF ty_rule WITH EMPTY KEY.
  rules = VALUE #( ( rule = 'SAME_DAY' ) ( rule = 'NEXT_DAY' ) ( rule = 'NEXT_WORKDAY' ) ).
  CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
    EXPORTING retfield = 'RULE' dynpprog = sy-repid dynpnr = sy-dynnr dynprofield = 'P_RULE' value_org = 'S'
    TABLES value_tab = rules EXCEPTIONS OTHERS = 1.
  IF sy-subrc <> 0.
    MESSAGE 'Enter SAME_DAY, NEXT_DAY or NEXT_WORKDAY' TYPE 'I'.
  ENDIF.

AT SELECTION-SCREEN.
  IF sscrfields-ucomm = 'LOAD'.
    TRY.
        lcl_settings=>load( ).
      CATCH zcx_che_tcmb INTO DATA(load_error).
        MESSAGE load_error->get_text( ) TYPE 'E'.
    ENDTRY.
  ENDIF.

START-OF-SELECTION.
  TRY.
      lcl_settings=>save( ).
      WRITE: / 'Settings saved in client', sy-mandt, 'for profile', p_prof,
             / 'No exchange rates were written. Run ZCHE_TCMB_LOAD with Test run selected.',
             / 'Validate OBBS ratios, dates, source connectivity and the transport object/key list.'.
    CATCH zcx_che_tcmb INTO DATA(save_error).
      MESSAGE save_error->get_text( ) TYPE 'I' DISPLAY LIKE 'E'.
  ENDTRY.
