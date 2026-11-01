*&---------------------------------------------------------------------*
*& ZCHE_TCMB_LOAD: load TCMB exchange rates into TCURR
*& abap-tcmb-rates, https://github.com/Cheditte/abap-tcmb-rates
*& MIT License, Copyright (c) 2026 Ali Emre Altuntas
*&---------------------------------------------------------------------*
*& Settings live in profiles (ZCHE_TCMB_PROF, _MAP, _CURR). Run it as a
*& background job on working days after 15:30, when TCMB publishes.
*& In the background an error ends the job with status "Cancelled".
*&---------------------------------------------------------------------*
REPORT zche_tcmb_load.

TABLES sscrfields.

PARAMETERS p_prof TYPE zche_tcmb_profile OBLIGATORY.
SELECT-OPTIONS s_date FOR sy-datum NO-EXTENSION OBLIGATORY DEFAULT sy-datum.
PARAMETERS p_rule TYPE zche_tcmb_date_rule.
PARAMETERS p_test AS CHECKBOX DEFAULT abap_true.
SELECTION-SCREEN SKIP.
SELECTION-SCREEN PUSHBUTTON /1(40) b_conn USER-COMMAND conn.


CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS test_connection
      IMPORTING
        iv_profile TYPE zche_tcmb_profile.

    CLASS-METHODS run
      IMPORTING
        iv_profile TYPE zche_tcmb_profile
        iv_from    TYPE d
        iv_to      TYPE d
        iv_rule    TYPE zche_tcmb_date_rule
        iv_test    TYPE abap_bool.

  PRIVATE SECTION.
    CLASS-DATA gt_lines TYPE zif_che_tcmb=>ty_lines.

    CLASS-METHODS count
      IMPORTING
        iv_status       TYPE zif_che_tcmb=>ty_status
      RETURNING
        VALUE(rv_count) TYPE i.

    CLASS-METHODS show.

    CLASS-METHODS fail
      IMPORTING
        iv_text TYPE string.

ENDCLASS.



CLASS lcl_app IMPLEMENTATION.

  METHOD test_connection.
    TRY.
        DATA(lv_text) = NEW zcl_che_tcmb_loader( iv_profile )->test_connection( ).
        MESSAGE lv_text TYPE 'I'.
      CATCH zcx_che_tcmb INTO DATA(lx_error).
        MESSAGE lx_error->get_text( ) TYPE 'I' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.


  METHOD run.
    TRY.
        DATA(lo_loader) = NEW zcl_che_tcmb_loader( iv_profile = iv_profile iv_date_rule = iv_rule ).
        gt_lines = lo_loader->run( iv_from = iv_from iv_to = iv_to iv_test = iv_test ).
      CATCH zcx_che_tcmb INTO DATA(lx_error).
        fail( lx_error->get_text( ) ).
        RETURN.
    ENDTRY.

    DATA(lv_summary) = |{ COND #( WHEN iv_test = abap_true THEN `Test run: ` ) }|
                    && |{ count( zif_che_tcmb=>status-new ) } new, |
                    && |{ count( zif_che_tcmb=>status-updated ) } updated, |
                    && |{ count( zif_che_tcmb=>status-unchanged ) } unchanged, |
                    && |{ count( zif_che_tcmb=>status-skipped ) } skipped, |
                    && |{ count( zif_che_tcmb=>status-no_bulletin ) } days without bulletin, |
                    && |{ count( zif_che_tcmb=>status-error ) } errors|.
    MESSAGE lv_summary TYPE 'S'.
    IF count( zif_che_tcmb=>status-no_bulletin ) > 0
       AND lo_loader->get_profile( )-no_bulletin = zif_che_tcmb=>no_bulletin-warning.
      MESSAGE |Warning: TCMB published no bulletin on { count( zif_che_tcmb=>status-no_bulletin ) } working day(s)|
        TYPE 'S' DISPLAY LIKE 'W'.
    ENDIF.

    show( ).

    IF count( zif_che_tcmb=>status-error ) > 0.
      fail( |{ count( zif_che_tcmb=>status-error ) } line(s) failed; see the ERROR lines| ).
    ENDIF.
  ENDMETHOD.


  METHOD count.
    rv_count = REDUCE #( INIT n = 0
                         FOR ls_line IN gt_lines WHERE ( status = iv_status )
                         NEXT n = n + 1 ).
  ENDMETHOD.


  METHOD show.
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_alv)
                                CHANGING  t_table      = gt_lines ).
      CATCH cx_salv_msg INTO DATA(lx_salv).
        MESSAGE lx_salv TYPE 'I' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    lo_alv->get_functions( )->set_all( ).
    DATA(lo_columns) = lo_alv->get_columns( ).
    lo_columns->set_optimize( ).
    TRY.
        DATA(lo_column) = lo_columns->get_column( 'BULLETIN_DATE' ).
        lo_column->set_medium_text( 'Bulletin' ).
        lo_column->set_long_text( 'TCMB bulletin date' ).
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
      CATCH cx_salv_not_found ##NO_HANDLER.
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


INITIALIZATION.
  b_conn = 'Test the connection to TCMB'.

AT SELECTION-SCREEN.
  IF sscrfields-ucomm = 'CONN'.
    lcl_app=>test_connection( p_prof ).
  ENDIF.

START-OF-SELECTION.
  lcl_app=>run( iv_profile = p_prof
                iv_from    = s_date-low
                iv_to      = COND #( WHEN s_date-high IS INITIAL THEN s_date-low ELSE s_date-high )
                iv_rule    = p_rule
                iv_test    = p_test ).
