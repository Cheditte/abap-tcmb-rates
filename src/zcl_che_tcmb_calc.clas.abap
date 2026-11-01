"! <p class="shorttext synchronized">TCMB exchange rates: turns a bulletin into TCURR lines</p>
"! No database access: the caller passes the TCURF ratios and the
"! currencies known to SAP, so every rule here can be unit tested.
CLASS zcl_che_tcmb_calc DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! One line per mapped rate type and currency; a line that cannot be
    "! written gets STATUS SKIPPED or ERROR and a MESSAGE saying why
    "! @parameter it_factors | TCURF ratios valid on IV_VALID_FROM
    "! @parameter it_known | currency codes defined in SAP (TCURC)
    METHODS build_lines
      IMPORTING
        is_bulletin     TYPE zif_che_tcmb=>ty_bulletin
        is_profile      TYPE zif_che_tcmb=>ty_profile
        it_mappings     TYPE zif_che_tcmb=>ty_mappings
        it_currencies   TYPE zif_che_tcmb=>ty_currencies
        iv_valid_from   TYPE d
        it_factors      TYPE zif_che_tcmb=>ty_factors
        it_known        TYPE zif_che_tcmb=>ty_currency_codes
      RETURNING
        VALUE(rt_lines) TYPE zif_che_tcmb=>ty_lines.

    "! SAP currency for a TCMB code; initial if the profile leaves it out.
    "! Entries with EXCLUDE = space list the wanted currencies; without
    "! such entries every currency except the excluded ones is wanted.
    METHODS sap_currency
      IMPORTING
        iv_code         TYPE zche_tcmb_code
        it_currencies   TYPE zif_che_tcmb=>ty_currencies
      RETURNING
        VALUE(rv_waers) TYPE waers.

    "! Value of one TCMB rate; initial when TCMB gives none
    METHODS pick
      IMPORTING
        is_rate         TYPE zif_che_tcmb=>ty_rate
        iv_source       TYPE zche_tcmb_source
      RETURNING
        VALUE(rv_value) TYPE zif_che_tcmb=>ty_value.

  PRIVATE SECTION.
    METHODS add_line
      IMPORTING
        is_line     TYPE zif_che_tcmb=>ty_line
        iv_value    TYPE zif_che_tcmb=>ty_value
        iv_unit     TYPE i
        it_factors  TYPE zif_che_tcmb=>ty_factors
      CHANGING
        ct_lines    TYPE zif_che_tcmb=>ty_lines.

ENDCLASS.



CLASS zcl_che_tcmb_calc IMPLEMENTATION.

  METHOD build_lines.
    DATA(lv_target) = COND waers( WHEN is_profile-target_currency IS INITIAL
                                  THEN zif_che_tcmb=>default_target
                                  ELSE is_profile-target_currency ).

    LOOP AT is_bulletin-rates INTO DATA(ls_rate).
      DATA(lv_waers) = sap_currency( iv_code = ls_rate-code it_currencies = it_currencies ).
      IF lv_waers IS INITIAL.
        CONTINUE.
      ENDIF.

      LOOP AT it_mappings INTO DATA(ls_mapping).
        DATA(ls_line) = VALUE zif_che_tcmb=>ty_line(
          bulletin_date = is_bulletin-date
          tcmb_code     = ls_rate-code
          source        = ls_mapping-source
          rate_type     = ls_mapping-rate_type
          from_curr     = lv_waers
          to_curr       = lv_target
          valid_from    = iv_valid_from ).

        IF lv_target <> zif_che_tcmb=>default_target.
          ls_line-status  = zif_che_tcmb=>status-error.
          ls_line-message = |TCMB rates are quoted in TRY; target currency { lv_target } is not supported|.
          APPEND ls_line TO rt_lines.
          CONTINUE.
        ENDIF.

        IF NOT line_exists( it_known[ table_line = lv_waers ] ).
          ls_line-status  = zif_che_tcmb=>status-skipped.
          ls_line-message = |Currency { lv_waers } is not defined in SAP (TCURC)|.
          APPEND ls_line TO rt_lines.
          CONTINUE.
        ENDIF.

        DATA(lv_value) = pick( is_rate = ls_rate iv_source = ls_mapping-source ).
        IF lv_value <= 0.
          ls_line-status  = zif_che_tcmb=>status-skipped.
          ls_line-message = |TCMB gives no { ls_mapping-source } rate for { ls_rate-code }|.
          APPEND ls_line TO rt_lines.
          CONTINUE.
        ENDIF.

        add_line( EXPORTING is_line    = ls_line
                            iv_value   = lv_value
                            iv_unit    = ls_rate-unit
                            it_factors = it_factors
                  CHANGING  ct_lines   = rt_lines ).

        IF is_profile-write_inverse = abap_true.
          ls_line-from_curr = lv_target.
          ls_line-to_curr   = lv_waers.
          ls_line-indirect  = abap_true.
          add_line( EXPORTING is_line    = ls_line
                              iv_value   = lv_value
                              iv_unit    = ls_rate-unit
                              it_factors = it_factors
                    CHANGING  ct_lines   = rt_lines ).
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD sap_currency.
    DATA(lv_list_given) = xsdbool( line_exists( it_currencies[ exclude = abap_false ] ) ).

    READ TABLE it_currencies INTO DATA(ls_currency) WITH KEY tcmb_code = iv_code.
    IF sy-subrc = 0.
      IF ls_currency-exclude = abap_false.
        rv_waers = COND #( WHEN ls_currency-sap_currency IS INITIAL
                           THEN CONV waers( iv_code )
                           ELSE ls_currency-sap_currency ).
      ENDIF.
    ELSEIF lv_list_given = abap_false.
      rv_waers = iv_code.
    ENDIF.
  ENDMETHOD.


  METHOD pick.
    rv_value = SWITCH #( iv_source
      WHEN zif_che_tcmb=>source-fx_buy  THEN is_rate-fx_buy
      WHEN zif_che_tcmb=>source-fx_sell THEN is_rate-fx_sell
      WHEN zif_che_tcmb=>source-bn_buy  THEN is_rate-bn_buy
      WHEN zif_che_tcmb=>source-bn_sell THEN is_rate-bn_sell
      WHEN zif_che_tcmb=>source-fx_avg
        THEN COND #( WHEN is_rate-fx_buy > 0 AND is_rate-fx_sell > 0
                     THEN ( is_rate-fx_buy + is_rate-fx_sell ) / 2 )
      WHEN zif_che_tcmb=>source-bn_avg
        THEN COND #( WHEN is_rate-bn_buy > 0 AND is_rate-bn_sell > 0
                     THEN ( is_rate-bn_buy + is_rate-bn_sell ) / 2 ) ).
  ENDMETHOD.


  METHOD add_line.
    DATA(ls_line) = is_line.

    " Both entries use the ratio of the direct pair (foreign -> target):
    " for an indirect quotation SAP reads the ratio of the reverse pair
    " (seen on S/4HANA 2023 with CONVERT_TO_LOCAL_CURRENCY)
    DATA(lv_foreign) = COND waers( WHEN ls_line-indirect = abap_true THEN ls_line-to_curr ELSE ls_line-from_curr ).
    DATA(lv_target) = COND waers( WHEN ls_line-indirect = abap_true THEN ls_line-from_curr ELSE ls_line-to_curr ).
    READ TABLE it_factors INTO DATA(ls_factor)
      WITH TABLE KEY kurst = ls_line-rate_type
                     fcurr = lv_foreign
                     tcurr = lv_target.
    IF sy-subrc <> 0.
      ls_line-status  = zif_che_tcmb=>status-error.
      ls_line-message = |No ratio in TCURF for { ls_line-rate_type } {
                         lv_foreign }/{ lv_target } (maintain it with OBBS)|.
      APPEND ls_line TO ct_lines.
      RETURN.
    ENDIF.
    IF ls_line-indirect = abap_true.
      ls_line-from_factor = ls_factor-tfact.
      ls_line-to_factor   = ls_factor-ffact.
    ELSE.
      ls_line-from_factor = ls_factor-ffact.
      ls_line-to_factor   = ls_factor-tfact.
    ENDIF.

    " TCMB: UNIT foreign units cost VALUE target units; TCURR quotes the
    " rate for FFACT foreign units against TFACT target units
    DATA(lv_rate) = iv_value * ls_factor-ffact / ( iv_unit * ls_factor-tfact ).

    TRY.
        ls_line-rate = round( val = lv_rate dec = 5 ).
      CATCH cx_sy_conversion_overflow cx_sy_arithmetic_overflow.
        ls_line-status  = zif_che_tcmb=>status-error.
        ls_line-message = |Rate { lv_rate } does not fit TCURR; use a larger ratio in TCURF (OBBS)|.
    ENDTRY.
    IF ls_line-status IS INITIAL AND ls_line-rate <= 0.
      ls_line-status  = zif_che_tcmb=>status-error.
      ls_line-message = |Rate { lv_rate } rounds to zero; use a larger ratio in TCURF (OBBS)|.
    ENDIF.
    APPEND ls_line TO ct_lines.
  ENDMETHOD.

ENDCLASS.
