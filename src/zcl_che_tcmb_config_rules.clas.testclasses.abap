CLASS ltc_config DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    DATA profile TYPE zif_che_tcmb=>ty_profile.
    DATA mappings TYPE zif_che_tcmb=>ty_mappings.
    DATA currencies TYPE zif_che_tcmb=>ty_currencies.
    METHODS setup.
    METHODS valid_profile FOR TESTING RAISING zcx_che_tcmb.
    METHODS empty_currencies FOR TESTING.
    METHODS multiple_mappings FOR TESTING.
    METHODS renamed_currency FOR TESTING.
    METHODS excluded_currency FOR TESTING.
    METHODS duplicate_currency FOR TESTING.
    METHODS missing_calendar FOR TESTING.
    METHODS unsupported_target FOR TESTING.
    METHODS unsafe_blank_policy FOR TESTING.
    METHODS invalid_source FOR TESTING.
    METHODS custom_source FOR TESTING.
    METHODS missing_file_folder FOR TESTING.
    METHODS wrong_profile_key FOR TESTING.
    METHODS invalid_date_rule FOR TESTING.
    METHODS local_clients FOR TESTING RAISING zcx_che_tcmb.
    METHODS local_with_task FOR TESTING.
    METHODS automatic_recording FOR TESTING RAISING zcx_che_tcmb.
    METHODS no_transport_client FOR TESTING.
    METHODS closed_and_unknown_clients FOR TESTING.
    METHODS transport_task_required FOR TESTING.
    METHODS expect_client_error IMPORTING state TYPE c local TYPE abap_bool has_task TYPE abap_bool.
    METHODS expect_error.
ENDCLASS.
CLASS ltc_config IMPLEMENTATION.
  METHOD local_clients.
    zcl_che_tcmb_config_rules=>validate_client( iv_state = space iv_local = abap_true iv_has_task = abap_false ).
    zcl_che_tcmb_config_rules=>validate_client( iv_state = '3' iv_local = abap_true iv_has_task = abap_false ).
  ENDMETHOD.
  METHOD local_with_task.
    expect_client_error( state = space local = abap_true has_task = abap_true ).
    expect_client_error( state = '3' local = abap_true has_task = abap_true ).
  ENDMETHOD.
  METHOD automatic_recording.
    expect_client_error( state = '1' local = abap_true has_task = abap_false ).
    zcl_che_tcmb_config_rules=>validate_client( iv_state = '1' iv_local = abap_false iv_has_task = abap_true ).
    zcl_che_tcmb_config_rules=>validate_client( iv_state = space iv_local = abap_false iv_has_task = abap_true ).
  ENDMETHOD.
  METHOD no_transport_client.
    expect_client_error( state = '3' local = abap_false has_task = abap_true ).
  ENDMETHOD.
  METHOD closed_and_unknown_clients.
    expect_client_error( state = '2' local = abap_true has_task = abap_false ).
    expect_client_error( state = '2' local = abap_false has_task = abap_true ).
    expect_client_error( state = '0' local = abap_true has_task = abap_false ).
  ENDMETHOD.
  METHOD transport_task_required.
    expect_client_error( state = space local = abap_false has_task = abap_false ).
    expect_client_error( state = '1' local = abap_false has_task = abap_false ).
  ENDMETHOD.
  METHOD expect_client_error.
    TRY.
        zcl_che_tcmb_config_rules=>validate_client( iv_state = state iv_local = local iv_has_task = has_task ).
        cl_abap_unit_assert=>fail( `Expected client policy rejection` ).
      CATCH zcx_che_tcmb.
    ENDTRY.
  ENDMETHOD.
  METHOD setup.
    profile = VALUE #( profile = 'DEMO' target_currency = 'TRY' date_rule = 'SAME_DAY'
                       existing_rate = 'S' no_bulletin = 'I' ).
    mappings = VALUE #( ( profile = 'DEMO' rate_type = 'M' source = 'FX_BUY' ) ).
    currencies = VALUE #( ( profile = 'DEMO' tcmb_code = 'USD' ) ( profile = 'DEMO' tcmb_code = 'JPY' ) ).
  ENDMETHOD.
  METHOD valid_profile.
    zcl_che_tcmb_config_rules=>validate( is_profile = profile it_mappings = mappings it_currencies = currencies ).
  ENDMETHOD.
  METHOD empty_currencies.
    CLEAR currencies.
    expect_error( ).
  ENDMETHOD.
  METHOD multiple_mappings.
    APPEND VALUE #( profile = 'DEMO' rate_type = 'B' source = 'FX_SELL' ) TO mappings.
    expect_error( ).
  ENDMETHOD.
  METHOD renamed_currency.
    currencies[ 1 ]-sap_currency = 'USX'.
    expect_error( ).
  ENDMETHOD.
  METHOD excluded_currency.
    currencies[ 1 ]-exclude = abap_true.
    expect_error( ).
  ENDMETHOD.
  METHOD duplicate_currency.
    APPEND currencies[ 1 ] TO currencies.
    expect_error( ).
  ENDMETHOD.
  METHOD missing_calendar.
    profile-date_rule = 'NEXT_WORKDAY'.
    expect_error( ).
  ENDMETHOD.
  METHOD unsupported_target.
    profile-target_currency = 'EUR'.
    expect_error( ).
  ENDMETHOD.
  METHOD unsafe_blank_policy.
    CLEAR profile-existing_rate.
    expect_error( ).
  ENDMETHOD.
  METHOD invalid_source.
    mappings[ 1 ]-source = 'UNKNOWN'.
    expect_error( ).
  ENDMETHOD.
  METHOD custom_source.
    profile-source_class = 'ZCUSTOM_SOURCE'.
    expect_error( ).
  ENDMETHOD.
  METHOD missing_file_folder.
    profile-source_class = 'ZCL_CHE_TCMB_SOURCE_FILE'.
    expect_error( ).
  ENDMETHOD.
  METHOD wrong_profile_key.
    currencies[ 1 ]-profile = 'OTHER'.
    expect_error( ).
  ENDMETHOD.
  METHOD invalid_date_rule.
    profile-date_rule = 'UNKNOWN'.
    expect_error( ).
  ENDMETHOD.
  METHOD expect_error.
    TRY.
        zcl_che_tcmb_config_rules=>validate( is_profile = profile it_mappings = mappings it_currencies = currencies ).
        cl_abap_unit_assert=>fail( `Invalid settings were accepted` ).
      CATCH zcx_che_tcmb.
        " Expected rejection without database or BAPI access.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
