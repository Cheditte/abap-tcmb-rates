"! <p class="shorttext synchronized">TCMB exchange rates: runs days and retains results</p>
CLASS zcl_che_tcmb_runner DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Keeps committed earlier days visible when a later day fails.
    "! Missing bulletins follow IV_NO_BULLETIN and do not stop the range.
    METHODS run
      IMPORTING
        iv_from         TYPE d
        iv_to           TYPE d
        iv_test         TYPE abap_bool
        iv_no_bulletin  TYPE zche_tcmb_nodata
        io_day_loader   TYPE REF TO zif_che_tcmb_day_loader
      RETURNING
        VALUE(rt_lines) TYPE zif_che_tcmb=>ty_lines
      RAISING
        zcx_che_tcmb.

    CLASS-METHODS is_weekday
      IMPORTING
        iv_date        TYPE d
      RETURNING
        VALUE(rv_bool) TYPE abap_bool.

ENDCLASS.


CLASS zcl_che_tcmb_runner IMPLEMENTATION.

  METHOD run.
    IF iv_to < iv_from.
      RAISE EXCEPTION TYPE zcx_che_tcmb
        EXPORTING
          kind = zcx_che_tcmb=>kinds-config
          text = |The end date { iv_to DATE = ISO } is before the start date { iv_from DATE = ISO }|.
    ENDIF.
    IF io_day_loader IS NOT BOUND.
      RAISE EXCEPTION TYPE zcx_che_tcmb
        EXPORTING
          kind = zcx_che_tcmb=>kinds-config
          text = `A day loader is required`.
    ENDIF.

    DATA(lv_date) = iv_from.
    WHILE lv_date <= iv_to.
      IF is_weekday( lv_date ) = abap_true.
        TRY.
            APPEND LINES OF io_day_loader->load_day( iv_date = lv_date iv_test = iv_test ) TO rt_lines.
          CATCH zcx_che_tcmb INTO DATA(lx_error).
            DATA(lv_missing) = xsdbool( lx_error->kind = zcx_che_tcmb=>kinds-no_bulletin ).
            APPEND VALUE #(
              bulletin_date = lv_date
              status        = COND #( WHEN lv_missing = abap_true
                                      AND iv_no_bulletin <> zif_che_tcmb=>no_bulletin-error
                                      THEN zif_che_tcmb=>status-no_bulletin
                                      ELSE zif_che_tcmb=>status-error )
              message       = lx_error->get_text( ) ) TO rt_lines.
            IF lv_missing = abap_false.
              EXIT.
            ENDIF.
        ENDTRY.
      ENDIF.
      " Avoid incrementing the final representable ABAP date.
      IF lv_date = iv_to.
        EXIT.
      ENDIF.
      lv_date = lv_date + 1.
    ENDWHILE.
  ENDMETHOD.


  METHOD is_weekday.
    " 1 January 1900 was a Monday.
    rv_bool = xsdbool( ( iv_date - CONV d( '19000101' ) ) MOD 7 < 5 ).
  ENDMETHOD.

ENDCLASS.
