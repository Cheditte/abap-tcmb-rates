CLASS ltc_parser DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zcl_che_tcmb_parser.

    METHODS setup.
    METHODS reads_header FOR TESTING RAISING zcx_che_tcmb.
    METHODS reads_rates FOR TESTING RAISING zcx_che_tcmb.
    METHODS reads_unit FOR TESTING RAISING zcx_che_tcmb.
    METHODS keeps_missing_rates_initial FOR TESTING RAISING zcx_che_tcmb.
    METHODS rejects_other_xml FOR TESTING.
    METHODS rejects_broken_xml FOR TESTING.
    METHODS rejects_bad_number FOR TESTING.
    METHODS rejects_missing_unit FOR TESTING.
    METHODS rejects_fractional_unit FOR TESTING.
    METHODS rejects_negative_rate FOR TESTING.
    METHODS rejects_invalid_dates FOR TESTING.
    METHODS accepts_leap_day FOR TESTING RAISING zcx_che_tcmb.
    METHODS rejects_invalid_code FOR TESTING.
    METHODS rejects_duplicate_code FOR TESTING.

    CLASS-METHODS currency_xml
      IMPORTING
        iv_date       TYPE string DEFAULT `30.10.2026`
        iv_unit       TYPE string DEFAULT `1`
        iv_code       TYPE string DEFAULT `USD`
        iv_rate       TYPE string DEFAULT `49.7747`
      RETURNING
        VALUE(rv_xml) TYPE string.

    METHODS assert_parse_error
      IMPORTING
        iv_xml TYPE string.

    CLASS-METHODS sample
      RETURNING
        VALUE(rv_xml) TYPE xstring.

    CLASS-METHODS utf8
      IMPORTING
        iv_text       TYPE string
      RETURNING
        VALUE(rv_xml) TYPE xstring.

ENDCLASS.



CLASS ltc_parser IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW #( ).
  ENDMETHOD.


  METHOD reads_header.
    DATA(ls_bulletin) = mo_cut->parse( sample( ) ).

    cl_abap_unit_assert=>assert_equals( act = ls_bulletin-date exp = '20261030' ).
    cl_abap_unit_assert=>assert_equals( act = ls_bulletin-number exp = `2026/204` ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_bulletin-rates ) exp = 3 ).
  ENDMETHOD.


  METHOD reads_rates.
    DATA(ls_bulletin) = mo_cut->parse( sample( ) ).
    DATA(ls_usd) = ls_bulletin-rates[ code = 'USD' ].

    cl_abap_unit_assert=>assert_equals( act = ls_usd-unit exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_usd-fx_buy exp = CONV decfloat34( '49.7747' ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_usd-fx_sell exp = CONV decfloat34( '49.8644' ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_usd-bn_buy exp = CONV decfloat34( '49.7399' ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_usd-bn_sell exp = CONV decfloat34( '49.9392' ) ).
  ENDMETHOD.


  METHOD reads_unit.
    DATA(ls_bulletin) = mo_cut->parse( sample( ) ).
    DATA(ls_jpy) = ls_bulletin-rates[ code = 'JPY' ].

    cl_abap_unit_assert=>assert_equals( act = ls_jpy-unit exp = 100 ).
    cl_abap_unit_assert=>assert_equals( act = ls_jpy-fx_buy exp = CONV decfloat34( '31.5605' ) ).
  ENDMETHOD.


  METHOD keeps_missing_rates_initial.
    " XDR has only a forex buying rate
    DATA(ls_bulletin) = mo_cut->parse( sample( ) ).
    DATA(ls_xdr) = ls_bulletin-rates[ code = 'XDR' ].

    cl_abap_unit_assert=>assert_equals( act = ls_xdr-fx_buy exp = CONV decfloat34( '67.5422' ) ).
    cl_abap_unit_assert=>assert_initial( ls_xdr-fx_sell ).
    cl_abap_unit_assert=>assert_initial( ls_xdr-bn_buy ).
    cl_abap_unit_assert=>assert_initial( ls_xdr-bn_sell ).
  ENDMETHOD.


  METHOD rejects_other_xml.
    assert_parse_error( `<html><body>Not found</body></html>` ).
  ENDMETHOD.


  METHOD rejects_broken_xml.
    assert_parse_error( `<Tarih_Date Tarih="30.10.2026"><Currency>` ).
  ENDMETHOD.


  METHOD rejects_bad_number.
    assert_parse_error(
      `<Tarih_Date Tarih="30.10.2026" Bulten_No="1">` &&
      `<Currency CurrencyCode="USD"><Unit>1</Unit><ForexBuying>abc</ForexBuying></Currency>` &&
      `</Tarih_Date>` ).
  ENDMETHOD.


  METHOD assert_parse_error.
    TRY.
        mo_cut->parse( utf8( iv_xml ) ).
        cl_abap_unit_assert=>fail( `No error raised` ).
      CATCH zcx_che_tcmb INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->kind exp = zcx_che_tcmb=>kinds-parse ).
    ENDTRY.
  ENDMETHOD.


  METHOD rejects_missing_unit.
    assert_parse_error( currency_xml( iv_unit = `` ) ).
  ENDMETHOD.

  METHOD rejects_fractional_unit.
    assert_parse_error( currency_xml( iv_unit = `1.5` ) ).
  ENDMETHOD.

  METHOD rejects_negative_rate.
    assert_parse_error( currency_xml( iv_rate = `-1` ) ).
    assert_parse_error( currency_xml( iv_rate = `0` ) ).
    assert_parse_error( currency_xml( iv_rate = `NaN` ) ).
  ENDMETHOD.

  METHOD rejects_invalid_dates.
    assert_parse_error( currency_xml( iv_date = `31.02.2026` ) ).
    assert_parse_error( currency_xml( iv_date = `29.02.2025` ) ).
    assert_parse_error( currency_xml( iv_date = `01.13.2026` ) ).
    assert_parse_error( currency_xml( iv_date = `00.10.2026` ) ).
    assert_parse_error( currency_xml( iv_date = `01.01.0000` ) ).
    assert_parse_error( currency_xml( iv_date = `1` ) ).
    assert_parse_error( currency_xml( iv_date = `..10.2026` ) ).
  ENDMETHOD.

  METHOD accepts_leap_day.
    DATA(ls_bulletin) = mo_cut->parse( utf8( currency_xml( iv_date = `29.02.2024` ) ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_bulletin-date exp = '20240229' ).
  ENDMETHOD.

  METHOD rejects_invalid_code.
    assert_parse_error( currency_xml( iv_code = `` ) ).
    assert_parse_error( currency_xml( iv_code = `USDX` ) ).
    assert_parse_error( currency_xml( iv_code = `U1D` ) ).
  ENDMETHOD.

  METHOD rejects_duplicate_code.
    assert_parse_error(
      `<Tarih_Date Tarih="30.10.2026">` &&
      `<Currency CurrencyCode="USD"><Unit>1</Unit><ForexBuying>49</ForexBuying></Currency>` &&
      `<Currency CurrencyCode="USD"><Unit>1</Unit><ForexBuying>50</ForexBuying></Currency>` &&
      `</Tarih_Date>` ).
  ENDMETHOD.

  METHOD currency_xml.
    rv_xml = |<Tarih_Date Tarih="{ iv_date }"><Currency CurrencyCode="{ iv_code }">|
          && |<Unit>{ iv_unit }</Unit><ForexBuying>{ iv_rate }</ForexBuying></Currency></Tarih_Date>|.
  ENDMETHOD.


  METHOD sample.
    " Shortened from https://www.tcmb.gov.tr/kurlar/202610/30102026.xml
    rv_xml = utf8(
      `<?xml version="1.0" encoding="UTF-8"?>` &&
      `<Tarih_Date Tarih="30.10.2026" Date="10/30/2026" Bulten_No="2026/204">` &&
      `<Currency CrossOrder="0" Kod="USD" CurrencyCode="USD"><Unit>1</Unit>` &&
      `<Isim>ABD DOLARI</Isim><CurrencyName>US DOLLAR</CurrencyName>` &&
      `<ForexBuying>49.7747</ForexBuying><ForexSelling>49.8644</ForexSelling>` &&
      `<BanknoteBuying>49.7399</BanknoteBuying><BanknoteSelling>49.9392</BanknoteSelling>` &&
      `<CrossRateUSD/><CrossRateOther/></Currency>` &&
      `<Currency CrossOrder="5" Kod="JPY" CurrencyCode="JPY"><Unit>100</Unit>` &&
      `<ForexBuying>31.5605</ForexBuying><ForexSelling>31.7695</ForexSelling>` &&
      `<BanknoteBuying>31.4437</BanknoteBuying><BanknoteSelling>31.8902</BanknoteSelling>` &&
      `<CrossRateUSD>157.33</CrossRateUSD><CrossRateOther/></Currency>` &&
      `<Currency CrossOrder="0" Kod="XDR" CurrencyCode="XDR"><Unit>1</Unit>` &&
      `<ForexBuying>67.5422</ForexBuying><ForexSelling/><BanknoteBuying/><BanknoteSelling/>` &&
      `<CrossRateUSD/><CrossRateOther>1.35574</CrossRateOther></Currency>` &&
      `</Tarih_Date>` ).
  ENDMETHOD.


  METHOD utf8.
    rv_xml = cl_abap_codepage=>convert_to( iv_text ).
  ENDMETHOD.

ENDCLASS.
