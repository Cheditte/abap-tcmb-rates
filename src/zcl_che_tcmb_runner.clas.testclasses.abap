CLASS lcl_day_loader DEFINITION FINAL.
  PUBLIC SECTION.
    INTERFACES zif_che_tcmb_day_loader.

    TYPES:
      BEGIN OF ty_call,
        date TYPE d,
        test TYPE abap_bool,
      END OF ty_call,
      ty_calls TYPE STANDARD TABLE OF ty_call WITH EMPTY KEY.

    DATA calls TYPE ty_calls.
    DATA fail_date TYPE d.
    DATA error_kind TYPE string.

ENDCLASS.


CLASS lcl_day_loader IMPLEMENTATION.
  METHOD zif_che_tcmb_day_loader~load_day.
    APPEND VALUE #( date = iv_date test = iv_test ) TO calls.
    IF iv_date = fail_date.
      RAISE EXCEPTION TYPE zcx_che_tcmb
        EXPORTING
          kind = error_kind
          text = `Simulated day failure`.
    ENDIF.
    APPEND VALUE #( bulletin_date = iv_date
                    valid_from    = iv_date
                    from_curr     = 'USD'
                    to_curr       = 'TRY'
                    rate          = 50
                    status        = zif_che_tcmb=>status-new ) TO rt_lines.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_runner DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS retains_prior_on_fatal FOR TESTING RAISING zcx_che_tcmb.
    METHODS stops_on_parse_error FOR TESTING RAISING zcx_che_tcmb.
    METHODS no_bulletin_log FOR TESTING RAISING zcx_che_tcmb.
    METHODS no_bulletin_warning FOR TESTING RAISING zcx_che_tcmb.
    METHODS no_bulletin_error FOR TESTING RAISING zcx_che_tcmb.
    METHODS skips_weekends FOR TESTING RAISING zcx_che_tcmb.
    METHODS forwards_test_mode FOR TESTING RAISING zcx_che_tcmb.
    METHODS rejects_reversed_range FOR TESTING.
    METHODS requires_day_loader FOR TESTING.
    METHODS ends_at_maximum_date FOR TESTING RAISING zcx_che_tcmb.

    METHODS assert_missing_policy
      IMPORTING
        iv_policy TYPE zche_tcmb_nodata
        iv_status TYPE zif_che_tcmb=>ty_status
      RAISING
        zcx_che_tcmb.

    METHODS assert_fatal_error
      IMPORTING
        iv_kind TYPE string
      RAISING
        zcx_che_tcmb.

ENDCLASS.


CLASS ltc_runner IMPLEMENTATION.

  METHOD retains_prior_on_fatal.
    assert_fatal_error( zcx_che_tcmb=>kinds-connection ).
  ENDMETHOD.


  METHOD stops_on_parse_error.
    assert_fatal_error( zcx_che_tcmb=>kinds-parse ).
  ENDMETHOD.


  METHOD assert_fatal_error.
    DATA(lo_day) = NEW lcl_day_loader( ).
    lo_day->fail_date = '20261103'.
    lo_day->error_kind = iv_kind.

    DATA(lt_lines) = NEW zcl_che_tcmb_runner( )->run(
      iv_from        = '20261102'
      iv_to          = '20261104'
      iv_test        = abap_false
      iv_no_bulletin = zif_che_tcmb=>no_bulletin-log
      io_day_loader  = lo_day ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_lines ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_lines[ 1 ]-status exp = zif_che_tcmb=>status-new ).
    cl_abap_unit_assert=>assert_equals( act = lt_lines[ 1 ]-bulletin_date exp = '20261102' ).
    cl_abap_unit_assert=>assert_equals( act = lt_lines[ 1 ]-rate exp = 50 ).
    cl_abap_unit_assert=>assert_equals( act = lt_lines[ 2 ]-status exp = zif_che_tcmb=>status-error ).
    cl_abap_unit_assert=>assert_equals( act = lt_lines[ 2 ]-bulletin_date exp = '20261103' ).
    cl_abap_unit_assert=>assert_equals( act = lt_lines[ 2 ]-message exp = `Simulated day failure` ).
    cl_abap_unit_assert=>assert_equals( act = lines( lo_day->calls ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lo_day->calls[ 2 ]-date exp = '20261103' ).
  ENDMETHOD.


  METHOD no_bulletin_log.
    assert_missing_policy( iv_policy = zif_che_tcmb=>no_bulletin-log
                           iv_status = zif_che_tcmb=>status-no_bulletin ).
  ENDMETHOD.


  METHOD no_bulletin_warning.
    assert_missing_policy( iv_policy = zif_che_tcmb=>no_bulletin-warning
                           iv_status = zif_che_tcmb=>status-no_bulletin ).
  ENDMETHOD.


  METHOD no_bulletin_error.
    assert_missing_policy( iv_policy = zif_che_tcmb=>no_bulletin-error
                           iv_status = zif_che_tcmb=>status-error ).
  ENDMETHOD.


  METHOD assert_missing_policy.
    DATA(lo_day) = NEW lcl_day_loader( ).
    lo_day->fail_date = '20261102'.
    lo_day->error_kind = zcx_che_tcmb=>kinds-no_bulletin.

    DATA(lt_lines) = NEW zcl_che_tcmb_runner( )->run(
      iv_from        = '20261102'
      iv_to          = '20261103'
      iv_test        = abap_true
      iv_no_bulletin = iv_policy
      io_day_loader  = lo_day ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_lines ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_lines[ 1 ]-status exp = iv_status ).
    cl_abap_unit_assert=>assert_equals( act = lt_lines[ 1 ]-bulletin_date exp = '20261102' ).
    cl_abap_unit_assert=>assert_equals( act = lt_lines[ 1 ]-message exp = `Simulated day failure` ).
    cl_abap_unit_assert=>assert_equals( act = lt_lines[ 2 ]-status exp = zif_che_tcmb=>status-new ).
    cl_abap_unit_assert=>assert_equals( act = lt_lines[ 2 ]-bulletin_date exp = '20261103' ).
    cl_abap_unit_assert=>assert_equals( act = lines( lo_day->calls ) exp = 2 ).
  ENDMETHOD.


  METHOD skips_weekends.
    DATA(lo_day) = NEW lcl_day_loader( ).
    DATA(lt_lines) = NEW zcl_che_tcmb_runner( )->run(
      iv_from        = '20261030'
      iv_to          = '20261102'
      iv_test        = abap_true
      iv_no_bulletin = zif_che_tcmb=>no_bulletin-log
      io_day_loader  = lo_day ).

    cl_abap_unit_assert=>assert_equals( act = lines( lo_day->calls ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lo_day->calls[ 1 ]-date exp = '20261030' ).
    cl_abap_unit_assert=>assert_equals( act = lo_day->calls[ 2 ]-date exp = '20261102' ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_lines ) exp = 2 ).
  ENDMETHOD.


  METHOD forwards_test_mode.
    DATA(lo_day) = NEW lcl_day_loader( ).
    DATA(lo_runner) = NEW zcl_che_tcmb_runner( ).
    lo_runner->run( iv_from        = '20261102'
                    iv_to          = '20261102'
                    iv_test        = abap_true
                    iv_no_bulletin = zif_che_tcmb=>no_bulletin-log
                    io_day_loader  = lo_day ).
    lo_runner->run( iv_from        = '20261102'
                    iv_to          = '20261102'
                    iv_test        = abap_false
                    iv_no_bulletin = zif_che_tcmb=>no_bulletin-log
                    io_day_loader  = lo_day ).

    cl_abap_unit_assert=>assert_equals( act = lines( lo_day->calls ) exp = 2 ).
    cl_abap_unit_assert=>assert_true( lo_day->calls[ 1 ]-test ).
    cl_abap_unit_assert=>assert_false( lo_day->calls[ 2 ]-test ).
  ENDMETHOD.


  METHOD rejects_reversed_range.
    DATA(lo_day) = NEW lcl_day_loader( ).
    TRY.
        NEW zcl_che_tcmb_runner( )->run(
          iv_from        = '20261103'
          iv_to          = '20261102'
          iv_test        = abap_true
          iv_no_bulletin = zif_che_tcmb=>no_bulletin-log
          io_day_loader  = lo_day ).
        cl_abap_unit_assert=>fail( `A reversed range must be rejected` ).
      CATCH zcx_che_tcmb INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->kind exp = zcx_che_tcmb=>kinds-config ).
    ENDTRY.
    cl_abap_unit_assert=>assert_initial( lo_day->calls ).
  ENDMETHOD.


  METHOD requires_day_loader.
    DATA lo_day TYPE REF TO zif_che_tcmb_day_loader.
    TRY.
        NEW zcl_che_tcmb_runner( )->run(
          iv_from        = '20261102'
          iv_to          = '20261102'
          iv_test        = abap_true
          iv_no_bulletin = zif_che_tcmb=>no_bulletin-log
          io_day_loader  = lo_day ).
        cl_abap_unit_assert=>fail( `An unbound day loader must be rejected` ).
      CATCH zcx_che_tcmb INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->kind exp = zcx_che_tcmb=>kinds-config ).
    ENDTRY.
  ENDMETHOD.


  METHOD ends_at_maximum_date.
    DATA(lo_day) = NEW lcl_day_loader( ).
    DATA(lt_lines) = NEW zcl_che_tcmb_runner( )->run(
      iv_from        = '99991231'
      iv_to          = '99991231'
      iv_test        = abap_true
      iv_no_bulletin = zif_che_tcmb=>no_bulletin-log
      io_day_loader  = lo_day ).

    cl_abap_unit_assert=>assert_equals( act = lines( lo_day->calls ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_lines[ 1 ]-bulletin_date exp = '99991231' ).
  ENDMETHOD.

ENDCLASS.
