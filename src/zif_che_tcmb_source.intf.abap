"! <p class="shorttext synchronized">TCMB exchange rates: where the bulletin comes from</p>
"! Implementations: ZCL_CHE_TCMB_SOURCE_HTTP (default) and
"! ZCL_CHE_TCMB_SOURCE_FILE. Enter your own class in ZCHE_TCMB_PROF-SOURCE_CLASS.
INTERFACE zif_che_tcmb_source PUBLIC.

  "! Returns the bulletin of one day as UTF-8 XML
  "! @raising zcx_che_tcmb | KIND = NO_BULLETIN when TCMB published nothing that day
  METHODS get_bulletin
    IMPORTING
      iv_date       TYPE d
      is_profile    TYPE zif_che_tcmb=>ty_profile
    RETURNING
      VALUE(rv_xml) TYPE xstring
    RAISING
      zcx_che_tcmb.

ENDINTERFACE.
