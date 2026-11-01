"! <p class="shorttext synchronized">TCMB exchange rates: error</p>
"! KIND tells what went wrong, so callers can react (for example a day
"! without a bulletin is not an error); the text says who can fix it.
CLASS zcx_che_tcmb DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF kinds,
        config      TYPE string VALUE `CONFIG`,
        connection  TYPE string VALUE `CONNECTION`,
        ssl         TYPE string VALUE `SSL`,
        http        TYPE string VALUE `HTTP`,
        no_bulletin TYPE string VALUE `NO_BULLETIN`,
        parse       TYPE string VALUE `PARSE`,
        file        TYPE string VALUE `FILE`,
      END OF kinds.

    DATA kind TYPE string READ-ONLY.
    DATA text TYPE string READ-ONLY.

    METHODS constructor
      IMPORTING
        kind     TYPE string OPTIONAL
        text     TYPE string OPTIONAL
        previous TYPE REF TO cx_root OPTIONAL.

    METHODS if_message~get_text REDEFINITION.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcx_che_tcmb IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor( previous = previous ).
    me->kind = kind.
    me->text = text.
  ENDMETHOD.


  METHOD if_message~get_text.
    result = text.
    IF result IS INITIAL.
      result = super->if_message~get_text( ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
