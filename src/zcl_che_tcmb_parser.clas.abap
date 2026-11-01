"! <p class="shorttext synchronized">TCMB exchange rates: reads one bulletin XML</p>
CLASS zcl_che_tcmb_parser DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Reads a bulletin such as kurlar/202610/30102026.xml
    METHODS parse
      IMPORTING
        iv_xml             TYPE xstring
      RETURNING
        VALUE(rs_bulletin) TYPE zif_che_tcmb=>ty_bulletin
      RAISING
        zcx_che_tcmb.

  PRIVATE SECTION.
    METHODS child_text
      IMPORTING
        io_element     TYPE REF TO if_ixml_element
        iv_name        TYPE string
      RETURNING
        VALUE(rv_text) TYPE string.

    METHODS to_value
      IMPORTING
        iv_text         TYPE string
      RETURNING
        VALUE(rv_value) TYPE zif_che_tcmb=>ty_value
      RAISING
        zcx_che_tcmb.

    METHODS to_unit
      IMPORTING
        iv_text        TYPE string
      RETURNING
        VALUE(rv_unit) TYPE i
      RAISING
        zcx_che_tcmb.

    METHODS to_date
      IMPORTING
        iv_text        TYPE string
      RETURNING
        VALUE(rv_date) TYPE d
      RAISING
        zcx_che_tcmb.

    METHODS parse_error
      IMPORTING
        iv_text TYPE string
      RAISING
        zcx_che_tcmb.

ENDCLASS.



CLASS zcl_che_tcmb_parser IMPLEMENTATION.

  METHOD parse.
    DATA(lo_ixml) = cl_ixml=>create( ).
    DATA(lo_factory) = lo_ixml->create_stream_factory( ).
    DATA(lo_document) = lo_ixml->create_document( ).
    DATA(lo_parser) = lo_ixml->create_parser(
      stream_factory = lo_factory
      istream        = lo_factory->create_istream_xstring( iv_xml )
      document       = lo_document ).
    IF lo_parser->parse( ) <> 0.
      parse_error( `The TCMB answer is not valid XML` ).
    ENDIF.

    DATA(lo_root) = lo_document->get_root_element( ).
    IF lo_root IS NOT BOUND OR lo_root->get_name( ) <> `Tarih_Date`.
      parse_error( `The TCMB answer is not an exchange rate bulletin` ).
    ENDIF.

    rs_bulletin-date   = to_date( lo_root->get_attribute( name = `Tarih` ) ).
    rs_bulletin-number = lo_root->get_attribute( name = `Bulten_No` ).

    DATA(lo_list) = lo_root->get_elements_by_tag_name( name = `Currency` ).
    DO lo_list->get_length( ) TIMES.
      DATA(lo_currency) = CAST if_ixml_element( lo_list->get_item( sy-index - 1 ) ).
      DATA(lv_code) = to_upper( lo_currency->get_attribute( name = `CurrencyCode` ) ).
      IF strlen( lv_code ) <> 3 OR lv_code CN 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.
        parse_error( |Invalid TCMB currency code "{ lv_code }"| ).
      ENDIF.
      IF line_exists( rs_bulletin-rates[ code = lv_code ] ).
        parse_error( |Duplicate TCMB currency code "{ lv_code }"| ).
      ENDIF.
      APPEND VALUE #(
        code    = lv_code
        unit    = to_unit( child_text( io_element = lo_currency iv_name = `Unit` ) )
        fx_buy  = to_value( child_text( io_element = lo_currency iv_name = `ForexBuying` ) )
        fx_sell = to_value( child_text( io_element = lo_currency iv_name = `ForexSelling` ) )
        bn_buy  = to_value( child_text( io_element = lo_currency iv_name = `BanknoteBuying` ) )
        bn_sell = to_value( child_text( io_element = lo_currency iv_name = `BanknoteSelling` ) ) )
        TO rs_bulletin-rates.
    ENDDO.

    IF rs_bulletin-rates IS INITIAL.
      parse_error( `The TCMB bulletin contains no currencies` ).
    ENDIF.
  ENDMETHOD.


  METHOD child_text.
    DATA(lo_child) = io_element->find_from_name( name = iv_name ).
    IF lo_child IS BOUND.
      rv_text = condense( lo_child->get_value( ) ).
    ENDIF.
  ENDMETHOD.


  METHOD to_value.
    IF iv_text IS INITIAL.
      RETURN.
    ENDIF.
    FIND REGEX '^[0-9]+([.][0-9]+)?$' IN iv_text.
    IF sy-subrc <> 0.
      parse_error( |"{ iv_text }" in the TCMB bulletin is not a positive decimal number| ).
    ENDIF.
    TRY.
        rv_value = iv_text.
      CATCH cx_sy_conversion_error.
        parse_error( |"{ iv_text }" in the TCMB bulletin is not a number| ).
    ENDTRY.
    IF rv_value <= 0.
      parse_error( |"{ iv_text }" in the TCMB bulletin is not positive| ).
    ENDIF.
  ENDMETHOD.


  METHOD to_unit.
    IF iv_text IS INITIAL OR iv_text CN '0123456789'.
      parse_error( |Unit "{ iv_text }" in the TCMB bulletin must be a positive integer| ).
    ENDIF.
    TRY.
        rv_unit = iv_text.
      CATCH cx_sy_conversion_error.
        parse_error( |Unit "{ iv_text }" in the TCMB bulletin is not a number| ).
    ENDTRY.
    IF rv_unit <= 0.
      parse_error( |Unit "{ iv_text }" in the TCMB bulletin is not positive| ).
    ENDIF.
  ENDMETHOD.


  METHOD to_date.
    " TCMB writes the date as DD.MM.YYYY
    IF strlen( iv_text ) <> 10
       OR substring( val = iv_text off = 2 len = 1 ) <> `.`
       OR substring( val = iv_text off = 5 len = 1 ) <> `.`
       OR iv_text CN '0123456789.'.
      parse_error( |Bulletin date "{ iv_text }" is not DD.MM.YYYY| ).
    ENDIF.
    rv_date = substring( val = iv_text off = 6 len = 4 )
           && substring( val = iv_text off = 3 len = 2 )
           && substring( val = iv_text off = 0 len = 2 ).
    IF rv_date CN '0123456789'.
      parse_error( |Bulletin date "{ iv_text }" is not DD.MM.YYYY| ).
    ENDIF.

    DATA(lv_year) = CONV i( rv_date(4) ).
    DATA(lv_month) = CONV i( rv_date+4(2) ).
    DATA(lv_day) = CONV i( rv_date+6(2) ).
    DATA(lv_days) = 31.
    CASE lv_month.
      WHEN 4 OR 6 OR 9 OR 11.
        lv_days = 30.
      WHEN 2.
        lv_days = COND #( WHEN lv_year MOD 400 = 0 OR ( lv_year MOD 4 = 0 AND lv_year MOD 100 <> 0 )
                         THEN 29 ELSE 28 ).
    ENDCASE.
    IF lv_year = 0 OR lv_month < 1 OR lv_month > 12 OR lv_day < 1 OR lv_day > lv_days.
      parse_error( |Bulletin date "{ iv_text }" is not a valid calendar date| ).
    ENDIF.
  ENDMETHOD.


  METHOD parse_error.
    RAISE EXCEPTION TYPE zcx_che_tcmb
      EXPORTING
        kind = zcx_che_tcmb=>kinds-parse
        text = iv_text.
  ENDMETHOD.

ENDCLASS.
