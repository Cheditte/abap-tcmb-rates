"! <p class="shorttext synchronized">TCMB exchange rates: your own rules before and after writing</p>
"! Enter the implementing class in ZCHE_TCMB_PROF-EXIT_CLASS.
INTERFACE zif_che_tcmb_exit PUBLIC.

  "! Called for each day before the lines are compared with TCURR.
  "! Lines can be changed, added or removed; a line with an initial
  "! STATUS is written, a line with STATUS = ERROR is not.
  METHODS before_write
    IMPORTING
      is_profile TYPE zif_che_tcmb=>ty_profile
    CHANGING
      ct_lines   TYPE zif_che_tcmb=>ty_lines.

  "! Called for each day after writing, also in test mode
  METHODS after_write
    IMPORTING
      is_profile TYPE zif_che_tcmb=>ty_profile
      it_lines   TYPE zif_che_tcmb=>ty_lines
      iv_test    TYPE abap_bool.

ENDINTERFACE.
