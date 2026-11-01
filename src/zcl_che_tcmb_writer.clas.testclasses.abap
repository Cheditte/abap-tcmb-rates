CLASS lcl_rate_store DEFINITION FINAL.

  PUBLIC SECTION.
    INTERFACES zif_che_tcmb_rate_store.

    DATA ms_existing TYPE zif_che_tcmb_rate_store=>ty_existing.
    DATA mt_returns TYPE STANDARD TABLE OF bapiret2 WITH EMPTY KEY.
    DATA ms_commit_return TYPE bapiret2.
    DATA mt_reads TYPE zif_che_tcmb=>ty_lines.
    DATA mt_saved TYPE STANDARD TABLE OF bapi1093_0 WITH EMPTY KEY.
    DATA mt_update TYPE STANDARD TABLE OF abap_bool WITH EMPTY KEY.
    DATA mv_commits TYPE i.

ENDCLASS.


CLASS lcl_rate_store IMPLEMENTATION.

  METHOD zif_che_tcmb_rate_store~read_rate.
    APPEND is_line TO mt_reads.
    rs_existing = ms_existing.
  ENDMETHOD.


  METHOD zif_che_tcmb_rate_store~save_rate.
    APPEND is_rate TO mt_saved.
    APPEND iv_update TO mt_update.
    READ TABLE mt_returns INDEX lines( mt_saved ) INTO rs_return.
  ENDMETHOD.


  METHOD zif_che_tcmb_rate_store~commit_rates.
    mv_commits = mv_commits + 1.
    rs_return = ms_commit_return.
  ENDMETHOD.

ENDCLASS.


CLASS ltc_writer DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_store TYPE REF TO lcl_rate_store.
    DATA mo_cut TYPE REF TO zcl_che_tcmb_writer.
    DATA mt_lines TYPE zif_che_tcmb=>ty_lines.

    METHODS setup.
    METHODS inverted_date FOR TESTING.
    METHODS new_rate FOR TESTING.
    METHODS unchanged_rate FOR TESTING.
    METHODS updated_rate FOR TESTING.
    METHODS kept_existing FOR TESTING.
    METHODS dry_run FOR TESTING.
    METHODS skip_prevents_race FOR TESTING.
    METHODS bapi_errors FOR TESTING.
    METHODS commit_failure FOR TESTING.
    METHODS partial_success FOR TESTING.
    METHODS indirect_rate FOR TESTING.
    METHODS unchanged_indirect FOR TESTING.
    METHODS invalid_policy FOR TESTING.
    METHODS preclassified_lines FOR TESTING.

    METHODS write
      IMPORTING
        iv_existing TYPE zche_tcmb_existing DEFAULT 'U'
        iv_test     TYPE abap_bool DEFAULT abap_false.

ENDCLASS.


CLASS ltc_writer IMPLEMENTATION.

  METHOD setup.
    mo_store = NEW #( ).
    mo_cut = NEW #( io_store = mo_store ).
    mt_lines = VALUE #( ( bulletin_date = '20261030' rate_type = 'M'
                         from_curr = 'USD' to_curr = 'TRY' valid_from = '20261030'
                         rate = '49.7747' from_factor = 1 to_factor = 1 ) ).
  ENDMETHOD.


  METHOD inverted_date.
    cl_abap_unit_assert=>assert_equals( act = zcl_che_tcmb_writer=>inverted_date( '20261030' )
                                        exp = '79738969' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_che_tcmb_writer=>inverted_date( '20010101' )
                                        exp = '79989898' ).
  ENDMETHOD.


  METHOD new_rate.
    write( ).

    cl_abap_unit_assert=>assert_equals( act = mt_lines[ 1 ]-status exp = zif_che_tcmb=>status-new ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_store->mt_saved ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_store->mv_commits exp = 1 ).
    DATA(ls_saved) = mo_store->mt_saved[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_saved-rate_type exp = 'M' ).
    cl_abap_unit_assert=>assert_equals( act = ls_saved-from_curr exp = 'USD' ).
    cl_abap_unit_assert=>assert_equals( act = ls_saved-to_currncy exp = 'TRY' ).
    cl_abap_unit_assert=>assert_equals( act = ls_saved-valid_from exp = '20261030' ).
    cl_abap_unit_assert=>assert_equals( act = ls_saved-exch_rate exp = '49.7747' ).
    cl_abap_unit_assert=>assert_equals( act = ls_saved-from_factor exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_saved-to_factor exp = 1 ).
    cl_abap_unit_assert=>assert_initial( ls_saved-exch_rate_v ).
  ENDMETHOD.


  METHOD unchanged_rate.
    mo_store->ms_existing = VALUE #( found = abap_true rate = '49.7747' ).

    write( ).

    cl_abap_unit_assert=>assert_equals( act = mt_lines[ 1 ]-status exp = zif_che_tcmb=>status-unchanged ).
    cl_abap_unit_assert=>assert_initial( mo_store->mt_saved ).
    cl_abap_unit_assert=>assert_initial( mo_store->mv_commits ).
  ENDMETHOD.


  METHOD updated_rate.
    mo_store->ms_existing = VALUE #( found = abap_true rate = '48.0000' ).

    write( ).

    cl_abap_unit_assert=>assert_equals( act = mt_lines[ 1 ]-status exp = zif_che_tcmb=>status-updated ).
    cl_abap_unit_assert=>assert_char_cp( act = mt_lines[ 1 ]-message exp = 'Was *' ).
    cl_abap_unit_assert=>assert_true( mo_store->mt_update[ 1 ] ).
    cl_abap_unit_assert=>assert_equals( act = mo_store->mv_commits exp = 1 ).
  ENDMETHOD.


  METHOD kept_existing.
    mo_store->ms_existing = VALUE #( found = abap_true rate = '48.0000' ).

    write( iv_existing = zif_che_tcmb=>existing-skip ).

    cl_abap_unit_assert=>assert_equals( act = mt_lines[ 1 ]-status exp = zif_che_tcmb=>status-skipped ).
    cl_abap_unit_assert=>assert_initial( mo_store->mt_saved ).
    cl_abap_unit_assert=>assert_initial( mo_store->mv_commits ).
  ENDMETHOD.


  METHOD dry_run.
    write( iv_test = abap_true ).

    cl_abap_unit_assert=>assert_equals( act = mt_lines[ 1 ]-status exp = zif_che_tcmb=>status-new ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_store->mt_reads ) exp = 1 ).
    cl_abap_unit_assert=>assert_initial( mo_store->mt_saved ).
    cl_abap_unit_assert=>assert_initial( mo_store->mv_commits ).
  ENDMETHOD.


  METHOD skip_prevents_race.
    " The pre-read found no row, but another writer creates it before SAVE_RATE.
    mo_store->mt_returns = VALUE #( ( type = 'E' message = 'Entry already exists' ) ).

    write( iv_existing = zif_che_tcmb=>existing-skip ).

    cl_abap_unit_assert=>assert_false( mo_store->mt_update[ 1 ] ).
    cl_abap_unit_assert=>assert_equals( act = mt_lines[ 1 ]-status exp = zif_che_tcmb=>status-error ).
    cl_abap_unit_assert=>assert_equals( act = mt_lines[ 1 ]-message exp = 'Entry already exists' ).
    cl_abap_unit_assert=>assert_initial( mo_store->mv_commits ).
  ENDMETHOD.


  METHOD bapi_errors.
    APPEND VALUE #( from_curr = 'EUR' to_curr = 'TRY' rate = '50.0000' ) TO mt_lines.
    APPEND VALUE #( from_curr = 'JPY' to_curr = 'TRY' rate = '31.5605' ) TO mt_lines.
    mo_store->mt_returns = VALUE #( ( type = 'E' message = 'No authorization' )
                                   ( type = 'A' message = 'Save aborted' )
                                   ( type = 'X' message = 'Save failed' ) ).

    write( ).

    LOOP AT mt_lines INTO DATA(ls_line).
      cl_abap_unit_assert=>assert_equals( act = ls_line-status exp = zif_che_tcmb=>status-error ).
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals( act = mt_lines[ 1 ]-message exp = 'No authorization' ).
    cl_abap_unit_assert=>assert_equals( act = mt_lines[ 2 ]-message exp = 'Save aborted' ).
    cl_abap_unit_assert=>assert_equals( act = mt_lines[ 3 ]-message exp = 'Save failed' ).
    cl_abap_unit_assert=>assert_initial( mo_store->mv_commits ).
  ENDMETHOD.


  METHOD commit_failure.
    " Every successful pending save must fail together; keep unrelated results.
    APPEND VALUE #( status = zif_che_tcmb=>status-unchanged message = 'Already equal' ) TO mt_lines.
    APPEND VALUE #( from_curr = 'EUR' to_curr = 'TRY' rate = '50.0000' ) TO mt_lines.
    APPEND VALUE #( from_curr = 'JPY' to_curr = 'TRY' rate = '31.5605' ) TO mt_lines.
    mo_store->mt_returns = VALUE #( ( type = 'S' ) ( type = 'E' message = 'Row rejected' ) ( type = 'S' ) ).
    mo_store->ms_commit_return = VALUE #( type = 'E' message = 'Update terminated' ).

    write( ).

    cl_abap_unit_assert=>assert_equals( act = mt_lines[ 1 ]-status exp = zif_che_tcmb=>status-error ).
    cl_abap_unit_assert=>assert_equals( act = mt_lines[ 4 ]-status exp = zif_che_tcmb=>status-error ).
    cl_abap_unit_assert=>assert_equals( act = mt_lines[ 1 ]-message exp = 'Commit failed: Update terminated' ).
    cl_abap_unit_assert=>assert_equals( act = mt_lines[ 4 ]-message exp = 'Commit failed: Update terminated' ).
    cl_abap_unit_assert=>assert_equals( act = mt_lines[ 2 ]-status exp = zif_che_tcmb=>status-unchanged ).
    cl_abap_unit_assert=>assert_equals( act = mt_lines[ 2 ]-message exp = 'Already equal' ).
    cl_abap_unit_assert=>assert_equals( act = mt_lines[ 3 ]-message exp = 'Row rejected' ).
    cl_abap_unit_assert=>assert_equals( act = mo_store->mv_commits exp = 1 ).
  ENDMETHOD.


  METHOD partial_success.
    APPEND VALUE #( from_curr = 'EUR' to_curr = 'TRY' rate = '50.0000' ) TO mt_lines.
    mo_store->mt_returns = VALUE #( ( type = 'E' message = 'USD rejected' ) ( type = 'S' ) ).

    write( ).

    cl_abap_unit_assert=>assert_equals( act = mt_lines[ 1 ]-status exp = zif_che_tcmb=>status-error ).
    cl_abap_unit_assert=>assert_equals( act = mt_lines[ 1 ]-message exp = 'USD rejected' ).
    cl_abap_unit_assert=>assert_equals( act = mt_lines[ 2 ]-status exp = zif_che_tcmb=>status-new ).
    cl_abap_unit_assert=>assert_equals( act = mo_store->mv_commits exp = 1 ).
  ENDMETHOD.


  METHOD indirect_rate.
    mt_lines = VALUE #( ( rate_type = 'M' from_curr = 'TRY' to_curr = 'JPY' valid_from = '20261030'
                         rate = '31.5605' from_factor = 1 to_factor = 100 indirect = abap_true ) ).

    write( ).

    DATA(ls_saved) = mo_store->mt_saved[ 1 ].
    cl_abap_unit_assert=>assert_initial( ls_saved-exch_rate ).
    cl_abap_unit_assert=>assert_equals( act = ls_saved-exch_rate_v exp = '31.5605' ).
    cl_abap_unit_assert=>assert_equals( act = ls_saved-from_factor_v exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_saved-to_factor_v exp = 100 ).
  ENDMETHOD.


  METHOD unchanged_indirect.
    mt_lines[ 1 ]-indirect = abap_true.
    mo_store->ms_existing = VALUE #( found = abap_true rate = '-49.7747' ).

    write( ).

    cl_abap_unit_assert=>assert_equals( act = mt_lines[ 1 ]-status exp = zif_che_tcmb=>status-unchanged ).
    cl_abap_unit_assert=>assert_initial( mo_store->mt_saved ).
    cl_abap_unit_assert=>assert_initial( mo_store->mv_commits ).
  ENDMETHOD.


  METHOD invalid_policy.
    write( iv_existing = 'X' ).

    cl_abap_unit_assert=>assert_equals( act = mt_lines[ 1 ]-status exp = zif_che_tcmb=>status-error ).
    cl_abap_unit_assert=>assert_char_cp( act = mt_lines[ 1 ]-message exp = '*policy*' ).
    cl_abap_unit_assert=>assert_initial( mo_store->mt_reads ).
    cl_abap_unit_assert=>assert_initial( mo_store->mt_saved ).
    cl_abap_unit_assert=>assert_initial( mo_store->mv_commits ).
  ENDMETHOD.


  METHOD preclassified_lines.
    mt_lines[ 1 ]-status = zif_che_tcmb=>status-skipped.
    mt_lines[ 1 ]-message = 'No TCMB rate'.

    write( ).

    cl_abap_unit_assert=>assert_equals( act = mt_lines[ 1 ]-status exp = zif_che_tcmb=>status-skipped ).
    cl_abap_unit_assert=>assert_equals( act = mt_lines[ 1 ]-message exp = 'No TCMB rate' ).
    cl_abap_unit_assert=>assert_initial( mo_store->mt_reads ).
    cl_abap_unit_assert=>assert_initial( mo_store->mt_saved ).
    cl_abap_unit_assert=>assert_initial( mo_store->mv_commits ).
  ENDMETHOD.


  METHOD write.
    mo_cut->write( EXPORTING iv_existing = iv_existing iv_test = iv_test
                   CHANGING ct_lines = mt_lines ).
  ENDMETHOD.

ENDCLASS.
