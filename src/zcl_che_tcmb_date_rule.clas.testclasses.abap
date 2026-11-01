CLASS ltc_date_rule DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    METHODS same_day FOR TESTING RAISING zcx_che_tcmb.
    METHODS next_day_crosses_month FOR TESTING RAISING zcx_che_tcmb.
    METHODS rejects_unknown_rule FOR TESTING.
    METHODS workday_needs_calendar FOR TESTING.

    METHODS assert_config_error
      IMPORTING
        iv_rule     TYPE zche_tcmb_date_rule
        iv_calendar TYPE wfcid OPTIONAL.

ENDCLASS.



CLASS ltc_date_rule IMPLEMENTATION.

  METHOD same_day.
    DATA(lo_cut) = CAST zif_che_tcmb_date_rule(
      NEW zcl_che_tcmb_date_rule( zif_che_tcmb=>date_rule-same_day ) ).

    cl_abap_unit_assert=>assert_equals( act = lo_cut->valid_from( '20261030' ) exp = '20261030' ).
  ENDMETHOD.


  METHOD next_day_crosses_month.
    DATA(lo_cut) = CAST zif_che_tcmb_date_rule(
      NEW zcl_che_tcmb_date_rule( zif_che_tcmb=>date_rule-next_day ) ).

    cl_abap_unit_assert=>assert_equals( act = lo_cut->valid_from( '20261031' ) exp = '20261101' ).
  ENDMETHOD.


  METHOD rejects_unknown_rule.
    assert_config_error( 'TOMORROW' ).
  ENDMETHOD.


  METHOD workday_needs_calendar.
    assert_config_error( zif_che_tcmb=>date_rule-next_workday ).
  ENDMETHOD.


  METHOD assert_config_error.
    TRY.
        DATA(lo_cut) = NEW zcl_che_tcmb_date_rule( iv_rule = iv_rule iv_calendar = iv_calendar ).
        cl_abap_unit_assert=>assert_not_bound( act = lo_cut msg = `No error raised` ).
      CATCH zcx_che_tcmb INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->kind exp = zcx_che_tcmb=>kinds-config ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
