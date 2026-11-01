"! <p class="shorttext synchronized">TCMB exchange rates: bulletin from a server folder</p>
"! For SAP systems that cannot reach TCMB: a scheduled task on the SAP
"! host (or a share) saves each bulletin as DDMMYYYY.xml in the folder
"! given in ZCHE_TCMB_PROF-FILE_FOLDER.
"! An unavailable file is an error: OPEN DATASET does not distinguish
"! a missing bulletin from an operating-system access failure.
CLASS zcl_che_tcmb_source_file DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_che_tcmb_source.

    "! Full name of the file of one day
    CLASS-METHODS file_name
      IMPORTING
        iv_folder      TYPE csequence
        iv_date        TYPE d
      RETURNING
        VALUE(rv_file) TYPE string.

  PRIVATE SECTION.
    METHODS check_open_result
      IMPORTING
        iv_file    TYPE string
        iv_subrc   TYPE sysubrc
        iv_message TYPE string
      RAISING
        zcx_che_tcmb.

ENDCLASS.



CLASS zcl_che_tcmb_source_file IMPLEMENTATION.

  METHOD zif_che_tcmb_source~get_bulletin.
    IF is_profile-file_folder IS INITIAL.
      RAISE EXCEPTION TYPE zcx_che_tcmb
        EXPORTING
          kind = zcx_che_tcmb=>kinds-config
          text = |Profile { is_profile-profile } has no file folder (ZCHE_TCMB_PROF-FILE_FOLDER)|.
    ENDIF.

    DATA(lv_file) = file_name( iv_folder = is_profile-file_folder iv_date = iv_date ).
    DATA lv_os_message TYPE c LENGTH 100.
    TRY.
        OPEN DATASET lv_file FOR INPUT IN BINARY MODE MESSAGE lv_os_message.
        DATA(lv_open_subrc) = sy-subrc.
      CATCH cx_sy_file_authority cx_sy_file_open cx_sy_file_access_error cx_sy_too_many_files INTO DATA(lx_open).
        RAISE EXCEPTION TYPE zcx_che_tcmb
          EXPORTING
            kind     = zcx_che_tcmb=>kinds-file
            text     = |Cannot open { lv_file }: { lx_open->get_text( ) }|
            previous = lx_open.
    ENDTRY.
    check_open_result( iv_file    = lv_file
                       iv_subrc   = lv_open_subrc
                       iv_message = CONV string( lv_os_message ) ).

    TRY.
        READ DATASET lv_file INTO rv_xml.
      CATCH cx_sy_file_io INTO DATA(lx_read).
        CLOSE DATASET lv_file.
        RAISE EXCEPTION TYPE zcx_che_tcmb
          EXPORTING
            kind     = zcx_che_tcmb=>kinds-file
            text     = |Cannot read { lv_file }: { lx_read->get_text( ) }|
            previous = lx_read.
    ENDTRY.
    CLOSE DATASET lv_file.
  ENDMETHOD.


  METHOD file_name.
    DATA(lv_folder) = CONV string( iv_folder ).
    DATA(lv_separator) = COND string( WHEN lv_folder CA '\' THEN `\` ELSE `/` ).
    IF lv_folder IS NOT INITIAL
       AND substring( val = lv_folder off = strlen( lv_folder ) - 1 len = 1 ) <> lv_separator.
      lv_folder = lv_folder && lv_separator.
    ENDIF.
    rv_file = |{ lv_folder }{ iv_date+6(2) }{ iv_date+4(2) }{ iv_date(4) }.xml|.
  ENDMETHOD.


  METHOD check_open_result.
    IF iv_subrc = 0.
      RETURN.
    ENDIF.
    RAISE EXCEPTION TYPE zcx_che_tcmb
      EXPORTING
        kind = zcx_che_tcmb=>kinds-file
        text = |Cannot open { iv_file }: { iv_message }. Check the download, folder and access permissions; |
            && |a missing file is not proof that TCMB published no bulletin|.
  ENDMETHOD.

ENDCLASS.
