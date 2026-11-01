" Test harness only. Fail immediately if a test reaches the default store.
" All writer tests must inject their in-memory fake; no SAP BAPI is called.
CLASS zcl_che_tcmb_rate_store DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES zif_che_tcmb_rate_store.
ENDCLASS.

CLASS zcl_che_tcmb_rate_store IMPLEMENTATION.
  METHOD zif_che_tcmb_rate_store~read_rate.
    ASSERT 1 = 2.
  ENDMETHOD.

  METHOD zif_che_tcmb_rate_store~save_rate.
    ASSERT 1 = 2.
  ENDMETHOD.

  METHOD zif_che_tcmb_rate_store~commit_rates.
    ASSERT 1 = 2.
  ENDMETHOD.
ENDCLASS.
