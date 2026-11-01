"! <p class="shorttext synchronized">TCMB exchange rates: TCURR and BAPI persistence</p>
CLASS zcl_che_tcmb_rate_store DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_che_tcmb_rate_store.

ENDCLASS.


CLASS zcl_che_tcmb_rate_store IMPLEMENTATION.

  METHOD zif_che_tcmb_rate_store~read_rate.
    DATA(lv_gdatu) = zcl_che_tcmb_writer=>inverted_date( is_line-valid_from ).
    SELECT SINGLE ukurs FROM tcurr
      WHERE kurst = @is_line-rate_type
        AND fcurr = @is_line-from_curr
        AND tcurr = @is_line-to_curr
        AND gdatu = @lv_gdatu
      INTO @rs_existing-rate.
    rs_existing-found = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.


  METHOD zif_che_tcmb_rate_store~save_rate.
    CALL FUNCTION 'BAPI_EXCHANGERATE_CREATE'
      EXPORTING
        exch_rate = is_rate
        upd_allow = iv_update
      IMPORTING
        return    = rs_return.
  ENDMETHOD.


  METHOD zif_che_tcmb_rate_store~commit_rates.
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING
        wait   = abap_true
      IMPORTING
        return = rs_return.
  ENDMETHOD.

ENDCLASS.
