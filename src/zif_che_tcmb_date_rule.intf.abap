"! <p class="shorttext synchronized">TCMB exchange rates: valid-from date of a bulletin</p>
INTERFACE zif_che_tcmb_date_rule PUBLIC.

  "! The TCURR valid-from date for a bulletin published on IV_BULLETIN_DATE
  METHODS valid_from
    IMPORTING
      iv_bulletin_date TYPE d
    RETURNING
      VALUE(rv_date)   TYPE d
    RAISING
      zcx_che_tcmb.

ENDINTERFACE.
