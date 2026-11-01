"! <p class="shorttext synchronized">TCMB exchange rates: standard date rules</p>
"! SAME_DAY: the bulletin date. NEXT_DAY: the calendar day after it.
"! NEXT_WORKDAY: the first working day after it in a factory calendar.
CLASS zcl_che_tcmb_date_rule DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_che_tcmb_date_rule.

    METHODS constructor
      IMPORTING
        iv_rule     TYPE zche_tcmb_date_rule
        iv_calendar TYPE wfcid OPTIONAL
      RAISING
        zcx_che_tcmb.

  PRIVATE SECTION.
    DATA mv_rule TYPE zche_tcmb_date_rule.
    DATA mv_calendar TYPE wfcid.

ENDCLASS.



CLASS zcl_che_tcmb_date_rule IMPLEMENTATION.

  METHOD constructor.
    IF iv_rule <> zif_che_tcmb=>date_rule-same_day
       AND iv_rule <> zif_che_tcmb=>date_rule-next_day
       AND iv_rule <> zif_che_tcmb=>date_rule-next_workday.
      RAISE EXCEPTION TYPE zcx_che_tcmb
        EXPORTING
          kind = zcx_che_tcmb=>kinds-config
          text = |Unknown date rule "{ iv_rule }"; use SAME_DAY, NEXT_DAY or NEXT_WORKDAY|.
    ENDIF.
    IF iv_rule = zif_che_tcmb=>date_rule-next_workday AND iv_calendar IS INITIAL.
      RAISE EXCEPTION TYPE zcx_che_tcmb
        EXPORTING
          kind = zcx_che_tcmb=>kinds-config
          text = `Date rule NEXT_WORKDAY needs a factory calendar in the profile`.
    ENDIF.
    mv_rule     = iv_rule.
    mv_calendar = iv_calendar.
  ENDMETHOD.


  METHOD zif_che_tcmb_date_rule~valid_from.
    CASE mv_rule.
      WHEN zif_che_tcmb=>date_rule-same_day.
        rv_date = iv_bulletin_date.

      WHEN zif_che_tcmb=>date_rule-next_day.
        rv_date = iv_bulletin_date + 1.

      WHEN zif_che_tcmb=>date_rule-next_workday.
        " '+' moves a non-working day forward to the next working day
        DATA(lv_next_day) = CONV d( iv_bulletin_date + 1 ).
        CALL FUNCTION 'DATE_CONVERT_TO_FACTORYDATE'
          EXPORTING
            correct_option      = '+'
            date                = lv_next_day
            factory_calendar_id = mv_calendar
          IMPORTING
            date                = rv_date
          EXCEPTIONS
            OTHERS              = 1.
        IF sy-subrc <> 0.
          RAISE EXCEPTION TYPE zcx_che_tcmb
            EXPORTING
              kind = zcx_che_tcmb=>kinds-config
              text = |Factory calendar { mv_calendar } gives no working day after {
                      iv_bulletin_date DATE = ISO } (check it in SCAL)|.
        ENDIF.
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
