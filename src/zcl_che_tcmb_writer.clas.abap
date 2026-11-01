"! <p class="shorttext synchronized">TCMB exchange rates: compares with TCURR and writes</p>
CLASS zcl_che_tcmb_writer DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING
        io_store TYPE REF TO zif_che_tcmb_rate_store OPTIONAL.

    "! Sets the STATUS of every line without one: NEW, UPDATED, UNCHANGED,
    "! SKIPPED or ERROR. Writes with BAPI_EXCHANGERATE_CREATE and commits,
    "! unless IV_TEST is set.
    METHODS write
      IMPORTING
        iv_existing TYPE zche_tcmb_existing
        iv_test     TYPE abap_bool
      CHANGING
        ct_lines    TYPE zif_che_tcmb=>ty_lines.

    "! TCURR keeps dates as 99999999 minus YYYYMMDD
    CLASS-METHODS inverted_date
      IMPORTING
        iv_date         TYPE d
      RETURNING
        VALUE(rv_gdatu) TYPE tcurr-gdatu.

  PRIVATE SECTION.
    DATA mo_store TYPE REF TO zif_che_tcmb_rate_store.

ENDCLASS.



CLASS zcl_che_tcmb_writer IMPLEMENTATION.

  METHOD constructor.
    mo_store = io_store.
    IF mo_store IS NOT BOUND.
      mo_store = NEW zcl_che_tcmb_rate_store( ).
    ENDIF.
  ENDMETHOD.


  METHOD write.
    DATA ls_return TYPE bapiret2.
    DATA lt_pending TYPE STANDARD TABLE OF i WITH EMPTY KEY.

    IF iv_existing <> zif_che_tcmb=>existing-update AND iv_existing <> zif_che_tcmb=>existing-skip.
      LOOP AT ct_lines ASSIGNING FIELD-SYMBOL(<ls_invalid>) WHERE status IS INITIAL.
        <ls_invalid>-status = zif_che_tcmb=>status-error.
        <ls_invalid>-message = |Unknown existing-rate policy "{ iv_existing }"; use U or S|.
      ENDLOOP.
      RETURN.
    ENDIF.

    LOOP AT ct_lines ASSIGNING FIELD-SYMBOL(<ls_line>) WHERE status IS INITIAL.
      DATA(lv_index) = sy-tabix.
      " An indirect quotation is stored with a minus sign
      DATA(lv_stored) = COND tcurr-ukurs( WHEN <ls_line>-indirect = abap_true
                                          THEN <ls_line>-rate * -1
                                          ELSE <ls_line>-rate ).
      DATA(ls_existing) = mo_store->read_rate( <ls_line> ).
      IF ls_existing-found = abap_true.
        IF ls_existing-rate = lv_stored.
          <ls_line>-status = zif_che_tcmb=>status-unchanged.
          CONTINUE.
        ENDIF.
        IF iv_existing = zif_che_tcmb=>existing-skip.
          <ls_line>-status  = zif_che_tcmb=>status-skipped.
          <ls_line>-message = |TCURR already has { ls_existing-rate } for that day; kept|.
          CONTINUE.
        ENDIF.
        <ls_line>-status  = zif_che_tcmb=>status-updated.
        <ls_line>-message = |Was { ls_existing-rate }|.
      ELSE.
        <ls_line>-status = zif_che_tcmb=>status-new.
      ENDIF.

      IF iv_test = abap_true.
        CONTINUE.
      ENDIF.

      DATA(ls_rate) = VALUE bapi1093_0(
        rate_type  = <ls_line>-rate_type
        from_curr  = <ls_line>-from_curr
        to_currncy = <ls_line>-to_curr
        valid_from = <ls_line>-valid_from ).
      IF <ls_line>-indirect = abap_true.
        ls_rate-exch_rate_v   = <ls_line>-rate.
        ls_rate-from_factor_v = <ls_line>-from_factor.
        ls_rate-to_factor_v   = <ls_line>-to_factor.
      ELSE.
        ls_rate-exch_rate   = <ls_line>-rate.
        ls_rate-from_factor = <ls_line>-from_factor.
        ls_rate-to_factor   = <ls_line>-to_factor.
      ENDIF.

      " Keep the policy inside the BAPI too: another writer may have
      " created this key since READ_RATE returned no existing entry.
      ls_return = mo_store->save_rate(
        is_rate   = ls_rate
        iv_update = xsdbool( iv_existing = zif_che_tcmb=>existing-update ) ).
      IF ls_return-type CA 'EAX'.
        <ls_line>-status  = zif_che_tcmb=>status-error.
        <ls_line>-message = ls_return-message.
      ELSE.
        APPEND lv_index TO lt_pending.
      ENDIF.
    ENDLOOP.

    IF lt_pending IS NOT INITIAL.
      ls_return = mo_store->commit_rates( ).
      IF ls_return-type CA 'EAX'.
        LOOP AT lt_pending INTO DATA(lv_pending).
          ASSIGN ct_lines[ lv_pending ] TO <ls_line>.
          <ls_line>-status = zif_che_tcmb=>status-error.
          <ls_line>-message = |Commit failed: { ls_return-message }|.
        ENDLOOP.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD inverted_date.
    rv_gdatu = |{ 99999999 - CONV i( CONV char8( iv_date ) ) }|.
  ENDMETHOD.

ENDCLASS.
