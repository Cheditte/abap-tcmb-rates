CLASS ltc_calc DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zcl_che_tcmb_calc.
    DATA ms_bulletin TYPE zif_che_tcmb=>ty_bulletin.
    DATA ms_profile TYPE zif_che_tcmb=>ty_profile.
    DATA mt_mappings TYPE zif_che_tcmb=>ty_mappings.
    DATA mt_currencies TYPE zif_che_tcmb=>ty_currencies.
    DATA mt_factors TYPE zif_che_tcmb=>ty_factors.
    DATA mt_known TYPE zif_che_tcmb=>ty_currency_codes.

    METHODS setup.
    METHODS direct_rate FOR TESTING.
    METHODS unit_with_matching_ratio FOR TESTING.
    METHODS unit_with_ratio_one FOR TESTING.
    METHODS average_rate FOR TESTING.
    METHODS missing_tcmb_rate FOR TESTING.
    METHODS unknown_sap_currency FOR TESTING.
    METHODS missing_ratio FOR TESTING.
    METHODS wanted_currencies_only FOR TESTING.
    METHODS excluded_currency FOR TESTING.
    METHODS renamed_currency FOR TESTING.
    METHODS inverse_rate FOR TESTING.
    METHODS inverse_uses_direct_ratio FOR TESTING.
    METHODS one_line_per_rate_type FOR TESTING.
    METHODS default_target_is_try FOR TESTING.
    METHODS rejects_non_try_target FOR TESTING.

    METHODS build
      RETURNING
        VALUE(rt_lines) TYPE zif_che_tcmb=>ty_lines.

    METHODS map
      IMPORTING
        iv_source    TYPE zche_tcmb_source
        iv_rate_type TYPE tcurr-kurst DEFAULT 'M'.

    METHODS line
      IMPORTING
        it_lines       TYPE zif_che_tcmb=>ty_lines
        iv_from        TYPE waers
        iv_to          TYPE waers DEFAULT 'TRY'
        iv_rate_type   TYPE tcurr-kurst DEFAULT 'M'
      RETURNING
        VALUE(rs_line) TYPE zif_che_tcmb=>ty_line.

ENDCLASS.



CLASS ltc_calc IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW #( ).
    ms_bulletin = VALUE #(
      date  = '20261030'
      rates = VALUE #(
        ( code = 'USD' unit = 1 fx_buy = '49.7747' fx_sell = '49.8644' bn_buy = '49.7399' bn_sell = '49.9392' )
        ( code = 'JPY' unit = 100 fx_buy = '31.5605' fx_sell = '31.7695' )
        ( code = 'XDR' unit = 1 fx_buy = '67.5422' ) ) ).
    ms_profile = VALUE #( profile = 'TEST' target_currency = 'TRY' ).
    mt_factors = VALUE #(
      ( kurst = 'M' fcurr = 'USD' tcurr = 'TRY' ffact = 1 tfact = 1 )
      ( kurst = 'M' fcurr = 'JPY' tcurr = 'TRY' ffact = 100 tfact = 1 )
      ( kurst = 'M' fcurr = 'XDR' tcurr = 'TRY' ffact = 1 tfact = 1 )
      ( kurst = 'M' fcurr = 'TRY' tcurr = 'USD' ffact = 1 tfact = 1 )
      ( kurst = 'B' fcurr = 'USD' tcurr = 'TRY' ffact = 1 tfact = 1 ) ).
    mt_known = VALUE #( ( CONV #( 'EUR' ) ) ( CONV #( 'JPY' ) ) ( CONV #( 'TRY' ) )
                        ( CONV #( 'USD' ) ) ( CONV #( 'XDR' ) ) ).
  ENDMETHOD.


  METHOD direct_rate.
    map( zif_che_tcmb=>source-fx_buy ).

    DATA(ls_line) = line( it_lines = build( ) iv_from = 'USD' ).

    cl_abap_unit_assert=>assert_initial( act = ls_line-status msg = ls_line-message ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-rate exp = '49.7747' ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-valid_from exp = '20261030' ).
    cl_abap_unit_assert=>assert_false( ls_line-indirect ).
  ENDMETHOD.


  METHOD unit_with_matching_ratio.
    " TCMB quotes 100 JPY; TCURF says 100 JPY : 1 TRY, so the value stays
    map( zif_che_tcmb=>source-fx_buy ).

    DATA(ls_line) = line( it_lines = build( ) iv_from = 'JPY' ).

    cl_abap_unit_assert=>assert_equals( act = ls_line-rate exp = '31.5605' ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-from_factor exp = 100 ).
  ENDMETHOD.


  METHOD unit_with_ratio_one.
    " With 1 JPY : 1 TRY the rate is per yen, rounded to 5 decimals
    mt_factors = VALUE #( ( kurst = 'M' fcurr = 'JPY' tcurr = 'TRY' ffact = 1 tfact = 1 ) ).
    map( zif_che_tcmb=>source-fx_buy ).

    DATA(ls_line) = line( it_lines = build( ) iv_from = 'JPY' ).

    cl_abap_unit_assert=>assert_equals( act = ls_line-rate exp = '0.31561' ).
  ENDMETHOD.


  METHOD average_rate.
    map( zif_che_tcmb=>source-fx_avg ).

    DATA(ls_line) = line( it_lines = build( ) iv_from = 'USD' ).

    cl_abap_unit_assert=>assert_equals( act = ls_line-rate exp = '49.81955' ).
  ENDMETHOD.


  METHOD missing_tcmb_rate.
    " XDR has no forex selling rate
    map( zif_che_tcmb=>source-fx_sell ).

    DATA(ls_line) = line( it_lines = build( ) iv_from = 'XDR' ).

    cl_abap_unit_assert=>assert_equals( act = ls_line-status exp = zif_che_tcmb=>status-skipped ).
  ENDMETHOD.


  METHOD unknown_sap_currency.
    DELETE mt_known WHERE table_line = 'XDR'.
    map( zif_che_tcmb=>source-fx_buy ).

    DATA(ls_line) = line( it_lines = build( ) iv_from = 'XDR' ).

    cl_abap_unit_assert=>assert_equals( act = ls_line-status exp = zif_che_tcmb=>status-skipped ).
    cl_abap_unit_assert=>assert_char_cp( act = ls_line-message exp = '*TCURC*' ).
  ENDMETHOD.


  METHOD missing_ratio.
    DELETE mt_factors WHERE fcurr = 'USD'.
    map( zif_che_tcmb=>source-fx_buy ).

    DATA(ls_line) = line( it_lines = build( ) iv_from = 'USD' ).

    cl_abap_unit_assert=>assert_equals( act = ls_line-status exp = zif_che_tcmb=>status-error ).
    cl_abap_unit_assert=>assert_char_cp( act = ls_line-message exp = '*TCURF*' ).
  ENDMETHOD.


  METHOD wanted_currencies_only.
    mt_currencies = VALUE #( ( profile = 'TEST' tcmb_code = 'USD' ) ).
    map( zif_che_tcmb=>source-fx_buy ).

    DATA(lt_lines) = build( ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_lines ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_lines[ 1 ]-from_curr exp = 'USD' ).
  ENDMETHOD.


  METHOD excluded_currency.
    mt_currencies = VALUE #( ( profile = 'TEST' tcmb_code = 'JPY' exclude = abap_true ) ).
    map( zif_che_tcmb=>source-fx_buy ).

    DATA(lt_lines) = build( ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_lines ) exp = 2 ).
    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( lt_lines[ tcmb_code = 'JPY' ] ) ) ).
  ENDMETHOD.


  METHOD renamed_currency.
    " A system that keeps the US dollar as 'USD2'
    mt_currencies = VALUE #( ( profile = 'TEST' tcmb_code = 'USD' sap_currency = 'USD2' ) ).
    INSERT CONV waers( 'USD2' ) INTO TABLE mt_known.
    INSERT VALUE #( kurst = 'M' fcurr = 'USD2' tcurr = 'TRY' ffact = 1 tfact = 1 ) INTO TABLE mt_factors.
    map( zif_che_tcmb=>source-fx_buy ).

    DATA(ls_line) = line( it_lines = build( ) iv_from = 'USD2' ).

    cl_abap_unit_assert=>assert_equals( act = ls_line-tcmb_code exp = 'USD' ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-rate exp = '49.7747' ).
  ENDMETHOD.


  METHOD inverse_rate.
    ms_profile-write_inverse = abap_true.
    mt_currencies = VALUE #( ( profile = 'TEST' tcmb_code = 'USD' ) ).
    map( zif_che_tcmb=>source-fx_buy ).

    DATA(lt_lines) = build( ).
    DATA(ls_inverse) = line( it_lines = lt_lines iv_from = 'TRY' iv_to = 'USD' ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_lines ) exp = 2 ).
    cl_abap_unit_assert=>assert_true( ls_inverse-indirect ).
    cl_abap_unit_assert=>assert_equals( act = ls_inverse-rate exp = '49.7747' ).
  ENDMETHOD.


  METHOD inverse_uses_direct_ratio.
    " TRY -> JPY is quoted per 100 JPY, like JPY -> TRY, so no precision is lost
    ms_profile-write_inverse = abap_true.
    mt_currencies = VALUE #( ( profile = 'TEST' tcmb_code = 'JPY' ) ).
    map( zif_che_tcmb=>source-fx_buy ).

    DATA(ls_inverse) = line( it_lines = build( ) iv_from = 'TRY' iv_to = 'JPY' ).

    cl_abap_unit_assert=>assert_equals( act = ls_inverse-rate exp = '31.5605' ).
    cl_abap_unit_assert=>assert_equals( act = ls_inverse-from_factor exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_inverse-to_factor exp = 100 ).
  ENDMETHOD.


  METHOD one_line_per_rate_type.
    mt_currencies = VALUE #( ( profile = 'TEST' tcmb_code = 'USD' ) ).
    map( iv_source = zif_che_tcmb=>source-fx_buy iv_rate_type = 'M' ).
    map( iv_source = zif_che_tcmb=>source-fx_sell iv_rate_type = 'B' ).

    DATA(lt_lines) = build( ).

    cl_abap_unit_assert=>assert_equals( act = line( it_lines = lt_lines iv_from = 'USD' iv_rate_type = 'M' )-rate
                                        exp = '49.7747' ).
    cl_abap_unit_assert=>assert_equals( act = line( it_lines = lt_lines iv_from = 'USD' iv_rate_type = 'B' )-rate
                                        exp = '49.8644' ).
  ENDMETHOD.


  METHOD default_target_is_try.
    CLEAR ms_profile-target_currency.
    mt_currencies = VALUE #( ( profile = 'TEST' tcmb_code = 'USD' ) ).
    map( zif_che_tcmb=>source-fx_buy ).

    DATA(ls_line) = line( it_lines = build( ) iv_from = 'USD' ).

    cl_abap_unit_assert=>assert_initial( act = ls_line-status msg = ls_line-message ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-to_curr exp = 'TRY' ).
    cl_abap_unit_assert=>assert_equals( act = ls_line-rate exp = '49.7747' ).
  ENDMETHOD.


  METHOD rejects_non_try_target.
    ms_profile-target_currency = 'EUR'.
    ms_profile-write_inverse = abap_true.
    mt_currencies = VALUE #( ( profile = 'TEST' tcmb_code = 'USD' ) ).
    INSERT VALUE #( kurst = 'M' fcurr = 'USD' tcurr = 'EUR' ffact = 1 tfact = 1 ) INTO TABLE mt_factors.
    map( zif_che_tcmb=>source-fx_buy ).

    DATA(lt_lines) = build( ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_lines ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_lines[ 1 ]-status exp = zif_che_tcmb=>status-error ).
    cl_abap_unit_assert=>assert_char_cp( act = lt_lines[ 1 ]-message exp = '*TRY*EUR*' ).
    cl_abap_unit_assert=>assert_initial( lt_lines[ 1 ]-rate ).
  ENDMETHOD.


  METHOD build.
    rt_lines = mo_cut->build_lines(
      is_bulletin   = ms_bulletin
      is_profile    = ms_profile
      it_mappings   = mt_mappings
      it_currencies = mt_currencies
      iv_valid_from = ms_bulletin-date
      it_factors    = mt_factors
      it_known      = mt_known ).
  ENDMETHOD.


  METHOD map.
    APPEND VALUE #( profile = 'TEST' rate_type = iv_rate_type source = iv_source ) TO mt_mappings.
  ENDMETHOD.


  METHOD line.
    READ TABLE it_lines INTO rs_line
      WITH KEY from_curr = iv_from to_curr = iv_to rate_type = iv_rate_type.
    cl_abap_unit_assert=>assert_subrc( act = sy-subrc msg = |No line { iv_rate_type } { iv_from }/{ iv_to }| ).
  ENDMETHOD.

ENDCLASS.
