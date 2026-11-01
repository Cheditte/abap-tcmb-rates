CLASS ltc_loader DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    METHODS weekdays FOR TESTING.

ENDCLASS.



CLASS ltc_loader IMPLEMENTATION.

  METHOD weekdays.
    " 30 Oct 2026 is a Friday
    cl_abap_unit_assert=>assert_true( zcl_che_tcmb_loader=>is_weekday( '20261030' ) ).
    cl_abap_unit_assert=>assert_false( zcl_che_tcmb_loader=>is_weekday( '20261031' ) ).
    cl_abap_unit_assert=>assert_false( zcl_che_tcmb_loader=>is_weekday( '20261101' ) ).
    cl_abap_unit_assert=>assert_true( zcl_che_tcmb_loader=>is_weekday( '20261102' ) ).
  ENDMETHOD.

ENDCLASS.
