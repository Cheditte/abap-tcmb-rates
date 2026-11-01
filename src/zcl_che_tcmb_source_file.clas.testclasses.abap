CLASS ltc_source_file DEFINITION DEFERRED.
CLASS zcl_che_tcmb_source_file DEFINITION LOCAL FRIENDS ltc_source_file.

CLASS ltc_source_file DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS unix_path FOR TESTING.
    METHODS windows_path_keeps_spaces FOR TESTING.
    METHODS trailing_separator FOR TESTING.
    METHODS open_failure_is_error FOR TESTING.
    METHODS successful_open FOR TESTING RAISING zcx_che_tcmb.
ENDCLASS.

CLASS ltc_source_file IMPLEMENTATION.
  METHOD unix_path.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_che_tcmb_source_file=>file_name( iv_folder = `/usr/sap/tcmb` iv_date = '20261030' )
      exp = `/usr/sap/tcmb/30102026.xml` ).
  ENDMETHOD.

  METHOD windows_path_keeps_spaces.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_che_tcmb_source_file=>file_name( iv_folder = `D:\TCMB  rates` iv_date = '20261030' )
      exp = `D:\TCMB  rates\30102026.xml` ).
  ENDMETHOD.

  METHOD trailing_separator.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_che_tcmb_source_file=>file_name( iv_folder = `/usr/sap/tcmb/` iv_date = '20261030' )
      exp = `/usr/sap/tcmb/30102026.xml` ).
  ENDMETHOD.

  METHOD open_failure_is_error.
    TRY.
        NEW zcl_che_tcmb_source_file( )->check_open_result(
          iv_file = `/tcmb/30102026.xml` iv_subrc = 8 iv_message = `Permission denied` ).
        cl_abap_unit_assert=>fail( `An inaccessible file must not become NO_BULLETIN` ).
      CATCH zcx_che_tcmb INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->kind exp = zcx_che_tcmb=>kinds-file ).
        cl_abap_unit_assert=>assert_true( xsdbool( lx_error->get_text( ) CS `Permission denied` ) ).
    ENDTRY.
  ENDMETHOD.

  METHOD successful_open.
    NEW zcl_che_tcmb_source_file( )->check_open_result(
      iv_file = `/tcmb/30102026.xml` iv_subrc = 0 iv_message = `` ).
  ENDMETHOD.
ENDCLASS.
