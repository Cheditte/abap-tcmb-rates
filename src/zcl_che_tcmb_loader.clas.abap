"! <p class="shorttext synchronized">TCMB exchange rates: loads days for a profile</p>
"! Reads the profile tables, gets each bulletin from the profile's source,
"! builds the TCURR lines, calls the exit and writes.
CLASS zcl_che_tcmb_loader DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_che_tcmb_day_loader.

    "! @parameter iv_date_rule | overrides the profile's date rule for this run
    METHODS constructor
      IMPORTING
        iv_profile   TYPE zche_tcmb_profile
        iv_date_rule TYPE zche_tcmb_date_rule OPTIONAL
      RAISING
        zcx_che_tcmb.

    "! Loads every weekday from IV_FROM to IV_TO (TCMB publishes nothing
    "! on Saturdays and Sundays). Stops at the first fatal day error,
    "! returning earlier results and an ERROR line for the failed day.
    METHODS run
      IMPORTING
        iv_from         TYPE d
        iv_to           TYPE d
        iv_test         TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rt_lines) TYPE zif_che_tcmb=>ty_lines
      RAISING
        zcx_che_tcmb.

    "! Gets and reads the latest bulletin of the last seven days
    METHODS test_connection
      RETURNING
        VALUE(rv_text) TYPE string
      RAISING
        zcx_che_tcmb.

    METHODS get_profile
      RETURNING
        VALUE(rs_profile) TYPE zif_che_tcmb=>ty_profile.

    "! Monday to Friday
    CLASS-METHODS is_weekday
      IMPORTING
        iv_date        TYPE d
      RETURNING
        VALUE(rv_bool) TYPE abap_bool.

  PRIVATE SECTION.
    DATA ms_profile TYPE zif_che_tcmb=>ty_profile.
    DATA mt_mappings TYPE zif_che_tcmb=>ty_mappings.
    DATA mt_currencies TYPE zif_che_tcmb=>ty_currencies.
    DATA mo_source TYPE REF TO zif_che_tcmb_source.
    DATA mo_date_rule TYPE REF TO zif_che_tcmb_date_rule.
    DATA mo_exit TYPE REF TO zif_che_tcmb_exit.

    METHODS read_bulletin
      IMPORTING
        iv_date            TYPE d
      RETURNING
        VALUE(rs_bulletin) TYPE zif_che_tcmb=>ty_bulletin
      RAISING
        zcx_che_tcmb.

    METHODS read_factors
      IMPORTING
        iv_date           TYPE d
        iv_target         TYPE waers
      RETURNING
        VALUE(rt_factors) TYPE zif_che_tcmb=>ty_factors.

    METHODS target_currency
      RETURNING
        VALUE(rv_waers) TYPE waers.

    METHODS create_object
      IMPORTING
        iv_class         TYPE seoclsname
      RETURNING
        VALUE(ro_object) TYPE REF TO object
      RAISING
        zcx_che_tcmb.

    METHODS config_error
      IMPORTING
        iv_text TYPE string
      RAISING
        zcx_che_tcmb.

    METHODS validate_config
      RAISING
        zcx_che_tcmb.

ENDCLASS.



CLASS zcl_che_tcmb_loader IMPLEMENTATION.

  METHOD constructor.
    SELECT SINGLE * FROM zche_tcmb_prof
      WHERE profile = @iv_profile
      INTO @ms_profile.
    IF sy-subrc <> 0.
      config_error( |Profile { iv_profile } does not exist (table ZCHE_TCMB_PROF)| ).
    ENDIF.
    SELECT * FROM zche_tcmb_map
      WHERE profile = @iv_profile
      INTO TABLE @mt_mappings.
    IF mt_mappings IS INITIAL.
      config_error( |Profile { iv_profile } maps no TCMB rate to a rate type (table ZCHE_TCMB_MAP)| ).
    ENDIF.
    SELECT * FROM zche_tcmb_curr
      WHERE profile = @iv_profile
      INTO TABLE @mt_currencies.

    validate_config( ).

    IF iv_date_rule IS NOT INITIAL.
      ms_profile-date_rule = iv_date_rule.
    ENDIF.
    IF ms_profile-date_rule IS INITIAL.
      config_error( |Profile { iv_profile } has no date rule; ask accounting which day a bulletin is valid for| ).
    ENDIF.
    mo_date_rule = NEW zcl_che_tcmb_date_rule( iv_rule     = ms_profile-date_rule
                                               iv_calendar = ms_profile-factory_calendar ).

    DATA(lv_source_class) = COND seoclsname( WHEN ms_profile-source_class IS INITIAL
                                             THEN zif_che_tcmb=>default_source_class
                                             ELSE ms_profile-source_class ).
    TRY.
        mo_source ?= create_object( lv_source_class ).
        IF ms_profile-exit_class IS NOT INITIAL.
          mo_exit ?= create_object( ms_profile-exit_class ).
        ENDIF.
      CATCH cx_sy_move_cast_error.
        config_error( |Source class must implement ZIF_CHE_TCMB_SOURCE, exit class ZIF_CHE_TCMB_EXIT| ).
    ENDTRY.
  ENDMETHOD.


  METHOD run.
    rt_lines = NEW zcl_che_tcmb_runner( )->run(
      iv_from        = iv_from
      iv_to          = iv_to
      iv_test        = iv_test
      iv_no_bulletin = ms_profile-no_bulletin
      io_day_loader  = me ).
  ENDMETHOD.


  METHOD test_connection.
    DATA(lv_date) = sy-datum.
    DO 7 TIMES.
      IF is_weekday( lv_date ) = abap_true.
        TRY.
            DATA(ls_bulletin) = read_bulletin( lv_date ).
            rv_text = |Connection OK: bulletin { ls_bulletin-number } of { ls_bulletin-date DATE = ISO }, |
                   && |{ lines( ls_bulletin-rates ) } currencies|.
            RETURN.
          CATCH zcx_che_tcmb INTO DATA(lx_error).
            IF lx_error->kind <> zcx_che_tcmb=>kinds-no_bulletin.
              RAISE EXCEPTION lx_error.
            ENDIF.
        ENDTRY.
      ENDIF.
      lv_date = lv_date - 1.
    ENDDO.
    RAISE EXCEPTION TYPE zcx_che_tcmb
      EXPORTING
        kind = zcx_che_tcmb=>kinds-no_bulletin
        text = `The connection works, but TCMB returned no bulletin for the last seven days`.
  ENDMETHOD.


  METHOD get_profile.
    rs_profile = ms_profile.
  ENDMETHOD.


  METHOD is_weekday.
    rv_bool = zcl_che_tcmb_runner=>is_weekday( iv_date ).
  ENDMETHOD.


  METHOD zif_che_tcmb_day_loader~load_day.
    DATA(ls_bulletin) = read_bulletin( iv_date ).

    DATA(lv_valid_from) = mo_date_rule->valid_from( iv_date ).
    DATA lt_known TYPE zif_che_tcmb=>ty_currency_codes.
    SELECT waers FROM tcurc INTO TABLE @lt_known.

    rt_lines = NEW zcl_che_tcmb_calc( )->build_lines(
      is_bulletin   = ls_bulletin
      is_profile    = ms_profile
      it_mappings   = mt_mappings
      it_currencies = mt_currencies
      iv_valid_from = lv_valid_from
      it_factors    = read_factors( iv_date = lv_valid_from iv_target = target_currency( ) )
      it_known      = lt_known ).

    IF mo_exit IS BOUND.
      mo_exit->before_write( EXPORTING is_profile = ms_profile
                             CHANGING  ct_lines   = rt_lines ).
    ENDIF.

    NEW zcl_che_tcmb_writer( )->write(
      EXPORTING
        iv_existing = COND #( WHEN ms_profile-existing_rate IS INITIAL
                              THEN zif_che_tcmb=>existing-update
                              ELSE ms_profile-existing_rate )
        iv_test     = iv_test
      CHANGING
        ct_lines    = rt_lines ).

    IF mo_exit IS BOUND.
      mo_exit->after_write( is_profile = ms_profile it_lines = rt_lines iv_test = iv_test ).
    ENDIF.
  ENDMETHOD.


  METHOD read_bulletin.
    rs_bulletin = NEW zcl_che_tcmb_parser( )->parse(
      mo_source->get_bulletin( iv_date = iv_date is_profile = ms_profile ) ).
    IF rs_bulletin-date <> iv_date.
      RAISE EXCEPTION TYPE zcx_che_tcmb
        EXPORTING
          kind = zcx_che_tcmb=>kinds-parse
          text = |Asked TCMB for { iv_date DATE = ISO } but got the bulletin of { rs_bulletin-date DATE = ISO }|.
    ENDIF.
  ENDMETHOD.


  METHOD read_factors.
    " A ratio is valid from its date on; with inverted dates the newest
    " ratio that is already valid has the smallest GDATU >= the day
    DATA lt_rate_types TYPE RANGE OF tcurf-kurst.
    lt_rate_types = VALUE #( FOR ls_mapping IN mt_mappings
                             ( sign = 'I' option = 'EQ' low = ls_mapping-rate_type ) ).
    DATA(lv_gdatu) = zcl_che_tcmb_writer=>inverted_date( iv_date ).

    SELECT kurst, fcurr, tcurr, gdatu, ffact, tfact FROM tcurf
      WHERE kurst IN @lt_rate_types
        AND ( fcurr = @iv_target OR tcurr = @iv_target )
        AND gdatu >= @lv_gdatu
      ORDER BY kurst, fcurr, tcurr, gdatu
      INTO TABLE @DATA(lt_tcurf).

    LOOP AT lt_tcurf INTO DATA(ls_tcurf).
      " Sorted unique table: the first, newest ratio per key wins
      INSERT VALUE #( kurst = ls_tcurf-kurst
                      fcurr = ls_tcurf-fcurr
                      tcurr = ls_tcurf-tcurr
                      ffact = ls_tcurf-ffact
                      tfact = ls_tcurf-tfact ) INTO TABLE rt_factors.
    ENDLOOP.
  ENDMETHOD.


  METHOD target_currency.
    rv_waers = COND #( WHEN ms_profile-target_currency IS INITIAL
                       THEN zif_che_tcmb=>default_target
                       ELSE ms_profile-target_currency ).
  ENDMETHOD.


  METHOD create_object.
    TRY.
        CREATE OBJECT ro_object TYPE (iv_class).
      CATCH cx_sy_create_object_error INTO DATA(lx_create).
        RAISE EXCEPTION TYPE zcx_che_tcmb
          EXPORTING
            kind     = zcx_che_tcmb=>kinds-config
            text     = |Class { iv_class } cannot be created: { lx_create->get_text( ) }|
            previous = lx_create.
    ENDTRY.
  ENDMETHOD.


  METHOD config_error.
    RAISE EXCEPTION TYPE zcx_che_tcmb
      EXPORTING
        kind = zcx_che_tcmb=>kinds-config
        text = iv_text.
  ENDMETHOD.


  METHOD validate_config.
    IF ms_profile-target_currency IS NOT INITIAL
       AND ms_profile-target_currency <> zif_che_tcmb=>default_target.
      config_error( `TCMB bulletins quote rates in TRY; TARGET_CURRENCY must be empty or TRY` ).
    ENDIF.
    IF ms_profile-existing_rate IS NOT INITIAL
       AND ms_profile-existing_rate <> zif_che_tcmb=>existing-update
       AND ms_profile-existing_rate <> zif_che_tcmb=>existing-skip.
      config_error( `Unknown EXISTING_RATE policy; use U (update) or S (keep existing)` ).
    ENDIF.
    IF ms_profile-no_bulletin IS NOT INITIAL
       AND ms_profile-no_bulletin <> zif_che_tcmb=>no_bulletin-log
       AND ms_profile-no_bulletin <> zif_che_tcmb=>no_bulletin-warning
       AND ms_profile-no_bulletin <> zif_che_tcmb=>no_bulletin-error.
      config_error( `Unknown NO_BULLETIN policy; use I, W or E` ).
    ENDIF.
    LOOP AT mt_mappings INTO DATA(ls_mapping).
      IF ls_mapping-rate_type IS INITIAL.
        config_error( `A TCMB mapping has no SAP rate type` ).
      ENDIF.
      IF ls_mapping-source <> zif_che_tcmb=>source-fx_buy
         AND ls_mapping-source <> zif_che_tcmb=>source-fx_sell
         AND ls_mapping-source <> zif_che_tcmb=>source-bn_buy
         AND ls_mapping-source <> zif_che_tcmb=>source-bn_sell
         AND ls_mapping-source <> zif_che_tcmb=>source-fx_avg
         AND ls_mapping-source <> zif_che_tcmb=>source-bn_avg.
        config_error( |Unknown TCMB source "{ ls_mapping-source }" in mapping for { ls_mapping-rate_type }| ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
