"! <p class="shorttext synchronized">TCMB exchange rates: persistence boundary</p>
INTERFACE zif_che_tcmb_rate_store PUBLIC.

  TYPES:
    BEGIN OF ty_existing,
      found TYPE abap_bool,
      rate  TYPE tcurr-ukurs,
    END OF ty_existing.

  METHODS read_rate
    IMPORTING
      is_line            TYPE zif_che_tcmb=>ty_line
    RETURNING
      VALUE(rs_existing) TYPE ty_existing.

  METHODS save_rate
    IMPORTING
      is_rate          TYPE bapi1093_0
      iv_update        TYPE abap_bool
    RETURNING
      VALUE(rs_return) TYPE bapiret2.

  METHODS commit_rates
    RETURNING
      VALUE(rs_return) TYPE bapiret2.

ENDINTERFACE.
