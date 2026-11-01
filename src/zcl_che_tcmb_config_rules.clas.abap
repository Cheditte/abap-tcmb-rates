"! Validation for the one-mapping, explicit-currency setup screen.
CLASS zcl_che_tcmb_config_rules DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    CLASS-METHODS validate_client
      IMPORTING iv_state TYPE c iv_local TYPE abap_bool iv_has_task TYPE abap_bool
      RAISING zcx_che_tcmb.
    CLASS-METHODS assert_simple
      IMPORTING it_mappings TYPE zif_che_tcmb=>ty_mappings
                it_currencies TYPE zif_che_tcmb=>ty_currencies
      RAISING zcx_che_tcmb.
    CLASS-METHODS validate
      IMPORTING is_profile TYPE zif_che_tcmb=>ty_profile
                it_mappings TYPE zif_che_tcmb=>ty_mappings
                it_currencies TYPE zif_che_tcmb=>ty_currencies
      RAISING zcx_che_tcmb.
ENDCLASS.

CLASS zcl_che_tcmb_config_rules IMPLEMENTATION.
  METHOD validate_client.
    " CCCORACTIV: blank = manual recording; 1 = automatic; 2 = closed;
    " 3 = local changes allowed, transports forbidden. Zero is not a value.
    IF iv_state <> space AND iv_state <> '1' AND iv_state <> '3'.
      RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = `Client customizing is closed or has an unknown control value (SCC4).`.
    ENDIF.
    IF iv_local = abap_true.
      IF iv_has_task = abap_true OR iv_state = '1'.
        RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = `Local save needs an empty task and a client allowing changes without automatic recording.`.
      ENDIF.
    ELSE.
      IF iv_state = '3'.
        RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = `This client permits local changes only. Select Local settings with an empty task.`.
      ENDIF.
      IF iv_has_task = abap_false.
        RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = `Enter your own modifiable transport task or select Local settings where permitted.`.
      ENDIF.
    ENDIF.
  ENDMETHOD.
  METHOD assert_simple.
    IF lines( it_mappings ) > 1.
      RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text =
        `This profile has multiple mappings. Maintain it with the advanced table-maintenance route.`.
    ENDIF.
    LOOP AT it_currencies INTO DATA(currency).
      IF currency-exclude = abap_true OR
        ( currency-sap_currency IS NOT INITIAL AND currency-sap_currency <> currency-tcmb_code ).
        RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text =
          `This profile uses exclusions or renamed currencies. Use advanced table maintenance; no data was changed.`.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validate.
    assert_simple( it_mappings = it_mappings it_currencies = it_currencies ).
    IF is_profile-profile IS INITIAL OR lines( it_mappings ) <> 1 OR it_currencies IS INITIAL.
      RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = `Enter a profile, one rate mapping and an explicit currency list.`.
    ENDIF.
    IF is_profile-target_currency <> 'TRY' OR
      ( is_profile-existing_rate <> 'S' AND is_profile-existing_rate <> 'U' ) OR
      ( is_profile-no_bulletin <> 'I' AND is_profile-no_bulletin <> 'W' AND is_profile-no_bulletin <> 'E' ).
      RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = `Use target TRY, existing-rate policy S/U and no-bulletin policy I/W/E.`.
    ENDIF.
    IF is_profile-date_rule <> 'SAME_DAY' AND is_profile-date_rule <> 'NEXT_DAY' AND is_profile-date_rule <> 'NEXT_WORKDAY'.
      RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = `Choose SAME_DAY, NEXT_DAY or NEXT_WORKDAY.`.
    ENDIF.
    IF is_profile-date_rule = 'NEXT_WORKDAY' AND is_profile-factory_calendar IS INITIAL.
      RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = `NEXT_WORKDAY requires a factory calendar.`.
    ENDIF.
    IF is_profile-source_class IS NOT INITIAL AND
      is_profile-source_class <> 'ZCL_CHE_TCMB_SOURCE_HTTP' AND is_profile-source_class <> 'ZCL_CHE_TCMB_SOURCE_FILE'.
      RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = `Custom source classes require advanced table maintenance.`.
    ENDIF.
    IF is_profile-source_class = 'ZCL_CHE_TCMB_SOURCE_FILE' AND is_profile-file_folder IS INITIAL.
      RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = `File input requires an application-server folder.`.
    ENDIF.
    DATA(mapping) = it_mappings[ 1 ].
    IF mapping-profile <> is_profile-profile OR mapping-rate_type IS INITIAL OR
      ( mapping-source <> 'FX_BUY' AND mapping-source <> 'FX_SELL' AND mapping-source <> 'BN_BUY'
        AND mapping-source <> 'BN_SELL' AND mapping-source <> 'FX_AVG' AND mapping-source <> 'BN_AVG' ).
      RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = `Invalid profile/rate-type/source mapping.`.
    ENDIF.
    DATA seen TYPE zif_che_tcmb=>ty_currency_codes.
    LOOP AT it_currencies INTO DATA(currency).
      IF currency-profile <> is_profile-profile OR strlen( currency-tcmb_code ) <> 3 OR
        currency-tcmb_code CN 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
        RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = `Enter distinct three-letter TCMB currency codes for this profile.`.
      ENDIF.
      INSERT CONV waers( currency-tcmb_code ) INTO TABLE seen.
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_che_tcmb EXPORTING text = `Duplicate currency in the profile.`.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
