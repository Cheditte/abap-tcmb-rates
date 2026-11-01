"! <p class="shorttext synchronized">TCMB exchange rates: one day's load</p>
INTERFACE zif_che_tcmb_day_loader PUBLIC.

  "! Loads one bulletin day; the runner records errors and missing bulletins.
  METHODS load_day
    IMPORTING
      iv_date         TYPE d
      iv_test         TYPE abap_bool
    RETURNING
      VALUE(rt_lines) TYPE zif_che_tcmb=>ty_lines
    RAISING
      zcx_che_tcmb.

ENDINTERFACE.
