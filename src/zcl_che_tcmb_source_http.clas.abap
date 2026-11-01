"! <p class="shorttext synchronized">TCMB exchange rates: bulletin over HTTPS</p>
"! With an SM59 HTTP destination in the profile (host www.tcmb.gov.tr,
"! port 443, SSL active, no path prefix) proxy and SSL settings stay with
"! Basis. Without one, the profile's base URL or the TCMB address is used
"! with the SSL client PSE "Anonymous" (STRUST).
CLASS zcl_che_tcmb_source_http DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_che_tcmb_source.

    "! Path of one day below the base URL: YYYYMM/DDMMYYYY.xml
    CLASS-METHODS day_path
      IMPORTING
        iv_date        TYPE d
      RETURNING
        VALUE(rv_path) TYPE string.

  PRIVATE SECTION.
    METHODS create_client
      IMPORTING
        iv_date          TYPE d
        is_profile       TYPE zif_che_tcmb=>ty_profile
      RETURNING
        VALUE(ro_client) TYPE REF TO if_http_client
      RAISING
        zcx_che_tcmb.

    METHODS raise_communication_error
      IMPORTING
        io_client TYPE REF TO if_http_client
      RAISING
        zcx_che_tcmb.

ENDCLASS.



CLASS zcl_che_tcmb_source_http IMPLEMENTATION.

  METHOD zif_che_tcmb_source~get_bulletin.
    DATA(lo_client) = create_client( iv_date = iv_date is_profile = is_profile ).

    lo_client->request->set_method( if_http_request=>co_request_method_get ).
    lo_client->send( EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc <> 0.
      raise_communication_error( lo_client ).
    ENDIF.
    lo_client->receive( EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc <> 0.
      raise_communication_error( lo_client ).
    ENDIF.

    lo_client->response->get_status( IMPORTING code = DATA(lv_code) reason = DATA(lv_reason) ).
    rv_xml = lo_client->response->get_data( ).
    lo_client->close( ).

    CASE lv_code.
      WHEN 200.
        RETURN.
      WHEN 404.
        RAISE EXCEPTION TYPE zcx_che_tcmb
          EXPORTING
            kind = zcx_che_tcmb=>kinds-no_bulletin
            text = |TCMB has no bulletin for { iv_date DATE = ISO } (weekend, holiday, |
                && |or not published yet; TCMB publishes on working days at 15:30)|.
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_che_tcmb
          EXPORTING
            kind = zcx_che_tcmb=>kinds-http
            text = |TCMB answered HTTP { lv_code } { lv_reason } for { iv_date DATE = ISO }|.
    ENDCASE.
  ENDMETHOD.


  METHOD day_path.
    rv_path = |{ iv_date(6) }/{ iv_date+6(2) }{ iv_date+4(2) }{ iv_date(4) }.xml|.
  ENDMETHOD.


  METHOD create_client.
    IF is_profile-rfc_destination IS NOT INITIAL.
      cl_http_client=>create_by_destination(
        EXPORTING
          destination = is_profile-rfc_destination
        IMPORTING
          client      = ro_client
        EXCEPTIONS
          OTHERS      = 1 ).
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_che_tcmb
          EXPORTING
            kind = zcx_che_tcmb=>kinds-config
            text = |HTTP destination { is_profile-rfc_destination } cannot be used; check it in SM59|.
      ENDIF.
      cl_http_utility=>set_request_uri( request = ro_client->request
                                        uri     = |/kurlar/{ day_path( iv_date ) }| ).
      RETURN.
    ENDIF.

    DATA(lv_base) = COND string( WHEN is_profile-base_url IS INITIAL
                                 THEN zif_che_tcmb=>default_url
                                 ELSE condense( CONV string( is_profile-base_url ) ) ).
    DATA(lv_url) = |{ lv_base }/{ day_path( iv_date ) }|.
    cl_http_client=>create_by_url(
      EXPORTING
        url    = lv_url
        ssl_id = 'ANONYM'
      IMPORTING
        client = ro_client
      EXCEPTIONS
        OTHERS = 1 ).
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_che_tcmb
        EXPORTING
          kind = zcx_che_tcmb=>kinds-config
          text = |Cannot create an HTTP client for { lv_url } (is the ICM HTTPS plug-in active?)|.
    ENDIF.
  ENDMETHOD.


  METHOD raise_communication_error.
    io_client->get_last_error( IMPORTING message = DATA(lv_message) ).
    io_client->close( ).

    DATA(lv_upper) = to_upper( lv_message ).
    IF lv_upper CS 'SSL' OR lv_upper CS 'CERTIFICATE' OR lv_upper CS 'HANDSHAKE' OR lv_upper CS 'PSE'.
      RAISE EXCEPTION TYPE zcx_che_tcmb
        EXPORTING
          kind = zcx_che_tcmb=>kinds-ssl
          text = |Secure connection to TCMB failed ({ lv_message }). Basis: verify the server certificate |
              && |chain and trusted root in STRUST, SSL client Anonymous |
              && |(or the PSE of the SM59 destination)|.
    ENDIF.
    RAISE EXCEPTION TYPE zcx_che_tcmb
      EXPORTING
        kind = zcx_che_tcmb=>kinds-connection
        text = |SAP cannot reach TCMB ({ lv_message }). Network team: allow outbound HTTPS |
            && |from the SAP host to www.tcmb.gov.tr:443, or use a proxy in an SM59 destination|.
  ENDMETHOD.

ENDCLASS.
