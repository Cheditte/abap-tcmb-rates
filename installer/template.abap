* Standalone bootstrap: no Z objects are required to activate this report.
* MIT License, Copyright (c) 2026 Ali Emre Altuntas
REPORT zche_tcmb_install.
CONSTANTS gc_modify TYPE c LENGTH 8 VALUE 'MODIFY'.
CONSTANTS gc_free TYPE c LENGTH 8 VALUE 'FREE'.

PARAMETERS p_pack TYPE devclass OBLIGATORY DEFAULT 'ZCHE_TCMB'.
PARAMETERS p_task TYPE trkorr.
PARAMETERS p_test AS CHECKBOX DEFAULT abap_true.

TYPES: BEGIN OF ty_item,
         kind TYPE tadir-object,
         name TYPE tadir-obj_name,
         xml TYPE string,
         source TYPE string_table,
         tests TYPE string_table,
       END OF ty_item.
DATA gt_items TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY.
DATA gv_line TYPE string.
DATA gv_context TYPE string.

CLASS lcx_install DEFINITION INHERITING FROM cx_static_check.
  PUBLIC SECTION.
    DATA detail TYPE string READ-ONLY.
    METHODS constructor IMPORTING detail TYPE string.
    METHODS if_message~get_text REDEFINITION.
ENDCLASS.
CLASS lcx_install IMPLEMENTATION.
  METHOD constructor.
    super->constructor( ).
    me->detail = detail.
  ENDMETHOD.
  METHOD if_message~get_text.
    result = detail.
  ENDMETHOD.
ENDCLASS.

CLASS lcl_guard DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS require IMPORTING ok TYPE abap_bool message TYPE string RAISING lcx_install.
ENDCLASS.
CLASS lcl_guard IMPLEMENTATION.
  METHOD require.
    IF ok = abap_false.
      RAISE EXCEPTION TYPE lcx_install EXPORTING detail = message.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

INITIALIZATION.
  %_p_pack_%_app_%-text = 'Existing target package'.
  %_p_task_%_app_%-text = 'Your Workbench task'.
  %_p_test_%_app_%-text = 'Check only - create nothing'.

START-OF-SELECTION.
  TRY.
      PERFORM embedded_payload.
      PERFORM preflight.
      IF p_test = abap_true.
        WRITE: / 'Preflight passed. No repository objects or rates were changed.',
               / 'Clear Check only to install in this DEV/sandbox system.'.
      ELSE.
        PERFORM install.
        WRITE: / 'Installation completed. No profiles or exchange rates were written.',
               / 'Run ZCHE_TCMB_CONFIG to prepare a profile, then ZCHE_TCMB_LOAD.',
               / 'Run package ABAP Unit / ATC and perform SAP acceptance tests.'.
      ENDIF.
    CATCH lcx_install INTO DATA(lx_install).
      ROLLBACK WORK.
      WRITE: / 'INSTALLATION STOPPED:', gv_context, / lx_install->detail,
             / 'Earlier objects may already exist. Review the log and transport.',
             / 'Do not delete objects or use an overwrite workaround to retry.'.
    CATCH cx_root INTO DATA(lx_unexpected).
      ROLLBACK WORK.
      WRITE: / 'INSTALLATION STOPPED:', gv_context, / lx_unexpected->get_text( ),
             / 'Review partially created objects before attempting recovery.'.
  ENDTRY.


FORM preflight RAISING lcx_install.
  gv_context = 'Preflight'.
  lcl_guard=>require( ok = xsdbool( sy-batch = abap_false )
      message = `Run the installer interactively in DEV, not as a background job.` ).
  SELECT SINGLE devclass FROM tdevc WHERE devclass = @p_pack INTO @DATA(package).
  lcl_guard=>require( ok = xsdbool( sy-subrc = 0 AND package IS NOT INITIAL )
      message = `Create the target package in SE80 first.` ).
  IF p_pack = '$TMP'.
    lcl_guard=>require( ok = xsdbool( p_task IS INITIAL )
      message = `$TMP must not have a transport task.` ).
  ELSE.
    lcl_guard=>require( ok = xsdbool( p_pack(1) CA 'ZY' )
      message = `Use an existing Z/Y customer package or $TMP.` ).
    SELECT SINGLE * FROM e070 WHERE trkorr = @p_task INTO @DATA(task).
    lcl_guard=>require( ok = xsdbool( sy-subrc = 0 AND task-trstatus = 'D'
      AND task-as4user = sy-uname AND task-trfunction = 'S' AND task-strkorr IS NOT INITIAL )
      message = `Select your own modifiable Workbench development task in SE09; not the parent request.` ).
    SELECT SINGLE * FROM e070 WHERE trkorr = @task-strkorr INTO @DATA(request).
    lcl_guard=>require( ok = xsdbool( sy-subrc = 0 AND request-trstatus = 'D' AND request-trfunction = 'K' )
      message = `The parent must be a modifiable Workbench request.` ).
  ENDIF.
  " Both source APIs are selected dynamically; no newer static dependency.
  SELECT SINGLE clsname FROM seoclass
    WHERE clsname = 'CL_OO_FACTORY' OR clsname = 'CL_OO_SOURCE' INTO @DATA(source_api).
  lcl_guard=>require( ok = xsdbool( sy-subrc = 0 AND source_api IS NOT INITIAL )
    message = `Neither CL_OO_FACTORY nor CL_OO_SOURCE is available.` ).
  DATA functions TYPE STANDARD TABLE OF rs38l_fnam WITH EMPTY KEY.
  functions = VALUE #( ( 'RS_CORR_INSERT' ) ( 'DDIF_DOMA_PUT' ) ( 'DDIF_DOMA_ACTIVATE' )
    ( 'DDIF_DTEL_PUT' ) ( 'DDIF_DTEL_ACTIVATE' ) ( 'DD_TABL_EXPAND' ) ( 'DDIF_TABL_PUT' ) ( 'DDIF_TABL_ACTIVATE' )
    ( 'SEO_CLASS_CREATE_COMPLETE' ) ( 'SEO_INTERFACE_CREATE_COMPLETE' ) ( 'RS_WORKING_OBJECTS_ACTIVATE' ) ).
  LOOP AT functions INTO DATA(function).
    CALL FUNCTION 'FUNCTION_EXISTS' EXPORTING funcname = function EXCEPTIONS OTHERS = 1.
    lcl_guard=>require( ok = xsdbool( sy-subrc = 0 )
      message = |Required SAP function is missing: { function }| ).
  ENDLOOP.
  " Validate native metadata lengths/row types before creating any object.
  LOOP AT gt_items INTO DATA(payload_item).
    gv_context = |Validating payload { payload_item-kind } { payload_item-name }|.
    PERFORM check_payload USING payload_item.
  ENDLOOP.
  LOOP AT gt_items INTO DATA(item).
    gv_context = |Preflight { item-kind } { item-name }|.
    AUTHORITY-CHECK OBJECT 'S_DEVELOP'
      ID 'DEVCLASS' FIELD p_pack ID 'OBJTYPE' FIELD item-kind
      ID 'OBJNAME' FIELD item-name ID 'P_GROUP' DUMMY ID 'ACTVT' FIELD '01'.
    lcl_guard=>require( ok = xsdbool( sy-subrc = 0 )
      message = |Missing create authorization for { item-name }.| ).
    AUTHORITY-CHECK OBJECT 'S_DEVELOP'
      ID 'DEVCLASS' FIELD p_pack ID 'OBJTYPE' FIELD item-kind
      ID 'OBJNAME' FIELD item-name ID 'P_GROUP' DUMMY ID 'ACTVT' FIELD '02'.
    lcl_guard=>require( ok = xsdbool( sy-subrc = 0 )
      message = |Missing change authorization for { item-name }.| ).
    SELECT SINGLE obj_name FROM tadir
      WHERE pgmid = 'R3TR' AND object = @item-kind AND obj_name = @item-name INTO @DATA(existing).
    lcl_guard=>require( ok = xsdbool( sy-subrc <> 0 AND existing IS INITIAL )
      message = |Object already exists: { item-name }. Fresh installation only; nothing is overwritten.| ).
    PERFORM check_native USING item.
    WRITE: / 'READY', item-kind, item-name.
  ENDLOOP.
ENDFORM.

FORM check_payload USING item TYPE ty_item RAISING lcx_install.
  DATA domain TYPE dd01v.
  DATA values TYPE STANDARD TABLE OF dd07v WITH EMPTY KEY.
  DATA element TYPE dd04v.
  DATA header TYPE dd02v.
  DATA technical TYPE dd09l.
  DATA fields TYPE STANDARD TABLE OF dd03p WITH EMPTY KEY.
  DATA foreign_keys TYPE STANDARD TABLE OF dd05m WITH EMPTY KEY.
  DATA checks TYPE STANDARD TABLE OF dd08v WITH EMPTY KEY.
  DATA interface TYPE vseointerf.
  DATA class TYPE vseoclass.
  DATA texts TYPE STANDARD TABLE OF textpool WITH EMPTY KEY.
  TRY.
      CASE item-kind.
        WHEN 'DOMA'.
          CALL TRANSFORMATION id SOURCE XML item-xml RESULT dd01v = domain dd07v_tab = values.
        WHEN 'DTEL'.
          CALL TRANSFORMATION id SOURCE XML item-xml RESULT dd04v = element.
        WHEN 'TABL'.
          CALL TRANSFORMATION id SOURCE XML item-xml
            RESULT dd02v = header dd09l = technical dd03p_table = fields dd05m_table = foreign_keys dd08v_table = checks.
        WHEN 'INTF'.
          CALL TRANSFORMATION id SOURCE XML item-xml RESULT vseointerf = interface.
        WHEN 'CLAS'.
          CALL TRANSFORMATION id SOURCE XML item-xml RESULT vseoclass = class.
        WHEN 'PROG'.
          CALL TRANSFORMATION id SOURCE XML item-xml RESULT tpool = texts.
      ENDCASE.
    CATCH cx_root INTO DATA(error).
      DATA detail TYPE string.
      detail = error->get_text( ).
      WHILE error->previous IS BOUND.
        error = error->previous.
        detail = detail && ` / ` && error->get_text( ).
      ENDWHILE.
      RAISE EXCEPTION TYPE lcx_install EXPORTING detail = |Invalid payload { item-name }: { detail }|.
  ENDTRY.
ENDFORM.

FORM check_native USING item TYPE ty_item RAISING lcx_install.
  DATA found TYPE abap_bool.
  DATA name TYPE ddobjname.
  name = item-name.
  CASE item-kind.
    WHEN 'DOMA'.
      SELECT SINGLE @abap_true FROM dd01l WHERE domname = @name INTO @found.
    WHEN 'DTEL'.
      SELECT SINGLE @abap_true FROM dd04l WHERE rollname = @name INTO @found.
    WHEN 'TABL'.
      SELECT SINGLE @abap_true FROM dd02l WHERE tabname = @name INTO @found.
    WHEN 'CLAS' OR 'INTF'.
      SELECT SINGLE @abap_true FROM seoclass WHERE clsname = @name INTO @found.
    WHEN 'PROG'.
      SELECT SINGLE @abap_true FROM trdir WHERE name = @name INTO @found.
  ENDCASE.
  lcl_guard=>require( ok = xsdbool( found = abap_false )
      message = |Repository object { item-name } exists, even without a directory entry. Stop and review.| ).
ENDFORM.

FORM register USING item TYPE ty_item RAISING lcx_install.
  " CTS performs the package/system-change/transport lock checks too.
  CALL FUNCTION 'RS_CORR_INSERT'
    EXPORTING object = item-name object_class = item-kind devclass = p_pack
      master_language = 'E' korrnum = p_task mode = 'I'
      global_lock = abap_true suppress_dialog = abap_true
    EXCEPTIONS OTHERS = 1.
  lcl_guard=>require( ok = xsdbool( sy-subrc = 0 )
      message = |CTS registration failed for { item-name }.| ).
ENDFORM.

FORM install RAISING lcx_install.
  LOOP AT gt_items INTO DATA(item).
    gv_context = |Creating { item-kind } { item-name }|.
    " Recheck immediately before mutation, including objects without TADIR.
    PERFORM check_native USING item.
    PERFORM register USING item.
    CASE item-kind.
      WHEN 'DOMA' OR 'DTEL' OR 'TABL'.
        PERFORM create_ddic USING item.
      WHEN 'CLAS' OR 'INTF'.
        PERFORM create_shell USING item.
      WHEN 'PROG'.
        PERFORM create_report USING item.
    ENDCASE.
    WRITE: / 'CREATED', item-kind, item-name.
  ENDLOOP.
  " Create all shells before saving mutually referring method sources.
  READ TABLE gt_items INTO item WITH KEY name = 'ZCX_CHE_TCMB'.
  IF sy-subrc = 0.
    gv_context = |Saving source { item-name }|.
    PERFORM save_oo_source USING item.
  ENDIF.
  LOOP AT gt_items INTO item WHERE kind = 'INTF' OR kind = 'CLAS'.
    IF item-name = 'ZCX_CHE_TCMB'.
      CONTINUE.
    ENDIF.
    gv_context = |Saving source { item-name }|.
    PERFORM save_oo_source USING item.
  ENDLOOP.
  DATA objects TYPE STANDARD TABLE OF dwinactiv WITH EMPTY KEY.
  LOOP AT gt_items INTO item WHERE kind = 'INTF' OR kind = 'CLAS' OR kind = 'PROG'.
    " Repository programs are activated as source objects, not R3TR PROG.
    APPEND VALUE #( object = COND #( WHEN item-kind = 'PROG' THEN 'REPS' ELSE item-kind )
      obj_name = item-name ) TO objects.
    IF item-kind = 'PROG'.
      APPEND VALUE #( object = 'REPT' obj_name = item-name ) TO objects.
    ENDIF.
  ENDLOOP.
  gv_context = 'Activating classes, interfaces and reports'.
  COMMIT WORK AND WAIT.
  lcl_guard=>require( ok = xsdbool( sy-subrc = 0 )
    message = `Cannot commit saved source before activation. Review SM13.` ).
  CALL FUNCTION 'RS_WORKING_OBJECTS_ACTIVATE'
    TABLES objects = objects EXCEPTIONS OTHERS = 1.
  lcl_guard=>require( ok = xsdbool( sy-subrc = 0 )
      message = `Activation failed. Review SAP activation messages.` ).
  LOOP AT gt_items INTO item WHERE kind = 'PROG'.
    DATA message TYPE string.
    DATA line TYPE i.
    DATA word TYPE string.
    " Compile the installed report with its own fixed-point/Unicode attributes.
    GENERATE REPORT item-name MESSAGE message LINE line WORD word.
    lcl_guard=>require( ok = xsdbool( sy-subrc = 0 )
      message = |{ item-name } line { line }, token { word }: { message }| ).
  ENDLOOP.
  LOOP AT gt_items INTO item WHERE kind = 'CLAS' OR kind = 'INTF'.
    DATA pool TYPE syrepid.
    DATA class_name TYPE seoclsname.
    class_name = item-name.
    IF item-kind = 'CLAS'.
      pool = cl_oo_classname_service=>get_classpool_name( class_name ).
    ELSE.
      pool = cl_oo_classname_service=>get_interfacepool_name( class_name ).
    ENDIF.
    gv_context = |Generating { item-name }|.
    GENERATE REPORT pool MESSAGE message LINE line WORD word.
    lcl_guard=>require( ok = xsdbool( sy-subrc = 0 )
      message = |{ item-name } line { line }, token { word }: { message }| ).
  ENDLOOP.
  COMMIT WORK AND WAIT.
  lcl_guard=>require( ok = xsdbool( sy-subrc = 0 )
      message = `Final commit failed. Review update status in SM13.` ).
ENDFORM.

FORM create_ddic USING item TYPE ty_item RAISING lcx_install.
  DATA activation_rc TYPE sy-subrc.
  CASE item-kind.
    WHEN 'DOMA'.
      DATA domain TYPE dd01v.
      DATA values TYPE STANDARD TABLE OF dd07v WITH EMPTY KEY.
      CALL TRANSFORMATION id SOURCE XML item-xml RESULT dd01v = domain dd07v_tab = values.
      LOOP AT values ASSIGNING FIELD-SYMBOL(<value>).
        <value>-domname = domain-domname.
      ENDLOOP.
      CALL FUNCTION 'DDIF_DOMA_PUT' EXPORTING name = domain-domname dd01v_wa = domain
        TABLES dd07v_tab = values EXCEPTIONS OTHERS = 1.
      lcl_guard=>require( ok = xsdbool( sy-subrc = 0 )
      message = |Cannot save domain { item-name }: rc { sy-subrc }, { sy-msgid } { sy-msgno } { sy-msgv1 } { sy-msgv2 } { sy-msgv3 } { sy-msgv4 }.| ).
      CALL FUNCTION 'DDIF_DOMA_ACTIVATE' EXPORTING name = domain-domname IMPORTING rc = activation_rc EXCEPTIONS OTHERS = 1.
    WHEN 'DTEL'.
      DATA element TYPE dd04v.
      CALL TRANSFORMATION id SOURCE XML item-xml RESULT dd04v = element.
      CALL FUNCTION 'DDIF_DTEL_PUT' EXPORTING name = element-rollname dd04v_wa = element EXCEPTIONS OTHERS = 1.
      lcl_guard=>require( ok = xsdbool( sy-subrc = 0 )
      message = |Cannot save data element { item-name }.| ).
      CALL FUNCTION 'DDIF_DTEL_ACTIVATE' EXPORTING name = element-rollname IMPORTING rc = activation_rc EXCEPTIONS OTHERS = 1.
    WHEN 'TABL'.
      DATA header TYPE dd02v.
      DATA technical TYPE dd09l.
      DATA fields TYPE STANDARD TABLE OF dd03p WITH EMPTY KEY.
      DATA foreign_keys TYPE STANDARD TABLE OF dd05m WITH EMPTY KEY.
      DATA checks TYPE STANDARD TABLE OF dd08v WITH EMPTY KEY.
      CALL TRANSFORMATION id SOURCE XML item-xml
        RESULT dd02v = header dd09l = technical dd03p_table = fields dd05m_table = foreign_keys dd08v_table = checks.
      LOOP AT fields ASSIGNING FIELD-SYMBOL(<field>).
        <field>-tabname = header-tabname.
        <field>-position = sy-tabix.
        <field>-ddlanguage = header-ddlanguage.
      ENDLOOP.
      LOOP AT checks ASSIGNING FIELD-SYMBOL(<check>).
        <check>-tabname = header-tabname.
        <check>-ddlanguage = header-ddlanguage.
      ENDLOOP.
      LOOP AT foreign_keys ASSIGNING FIELD-SYMBOL(<foreign_key>).
        <foreign_key>-tabname = header-tabname.
      ENDLOOP.
      " Field attributes omitted by the serializer must be restored from DDIC.
      CALL FUNCTION 'DD_TABL_EXPAND' EXPORTING dd02v_wa = header
        TABLES dd03p_tab = fields dd05m_tab = foreign_keys dd08v_tab = checks
        EXCEPTIONS OTHERS = 1.
      lcl_guard=>require( ok = xsdbool( sy-subrc = 0 )
        message = |Cannot expand table metadata { item-name }.| ).
      " HANA storage selection is absent on older SAP releases.
      ASSIGN COMPONENT 'ROWORCOLST' OF STRUCTURE technical TO FIELD-SYMBOL(<storage>).
      IF sy-subrc = 0 AND <storage> IS INITIAL.
        <storage> = 'C'.
      ENDIF.
      CALL FUNCTION 'DDIF_TABL_PUT' EXPORTING name = header-tabname dd02v_wa = header dd09l_wa = technical
        TABLES dd03p_tab = fields dd05m_tab = foreign_keys dd08v_tab = checks EXCEPTIONS OTHERS = 1.
      lcl_guard=>require( ok = xsdbool( sy-subrc = 0 )
      message = |Cannot save table { item-name }: rc { sy-subrc }, { sy-msgid } { sy-msgno } { sy-msgv1 } { sy-msgv2 } { sy-msgv3 } { sy-msgv4 }.| ).
      CALL FUNCTION 'DDIF_TABL_ACTIVATE' EXPORTING name = header-tabname IMPORTING rc = activation_rc EXCEPTIONS OTHERS = 1.
  ENDCASE.
  lcl_guard=>require( ok = xsdbool( sy-subrc = 0 AND activation_rc <= 4 )
      message = |Cannot activate DDIC object { item-name }: rc { activation_rc }, { sy-msgid } { sy-msgno } { sy-msgv1 } { sy-msgv2 }.| ).
  " Dependent definitions must see the activated object across DDIC APIs.
  COMMIT WORK AND WAIT.
  lcl_guard=>require( ok = xsdbool( sy-subrc = 0 )
      message = |DDIC commit failed for { item-name }. Review SM13.| ).
ENDFORM.

FORM create_shell USING item TYPE ty_item RAISING lcx_install.
  IF item-kind = 'INTF'.
    DATA interface TYPE vseointerf.
    CALL TRANSFORMATION id SOURCE XML item-xml RESULT vseointerf = interface.
    CALL FUNCTION 'SEO_INTERFACE_CREATE_COMPLETE'
      EXPORTING devclass = p_pack corrnr = p_task version = '0' overwrite = abap_false
      CHANGING interface = interface EXCEPTIONS OTHERS = 1.
  ELSE.
    DATA class TYPE vseoclass.
    CALL TRANSFORMATION id SOURCE XML item-xml RESULT vseoclass = class.
    CALL FUNCTION 'SEO_CLASS_CREATE_COMPLETE'
      EXPORTING devclass = p_pack corrnr = p_task version = '0' overwrite = abap_false
      CHANGING class = class EXCEPTIONS OTHERS = 1.
  ENDIF.
  lcl_guard=>require( ok = xsdbool( sy-subrc = 0 )
      message = |Cannot create class/interface { item-name }.| ).
ENDFORM.

FORM save_oo_source USING item TYPE ty_item RAISING lcx_install.
  DATA factory TYPE REF TO object.
  DATA source TYPE REF TO object.
  DATA key TYPE seoclskey.
  DATA modern TYPE abap_bool.
  DATA locked TYPE abap_bool.
  key-clsname = item-name.
  TRY.
      " Select API before acquiring locks or saving; no fallback after a failed write.
      TRY.
          CALL METHOD ('CL_OO_FACTORY')=>('CREATE_INSTANCE') RECEIVING result = factory.
          CALL METHOD factory->('CREATE_CLIF_SOURCE') EXPORTING clif_name = key-clsname RECEIVING result = source.
          modern = abap_true.
        CATCH cx_sy_dyn_call_error.
          CREATE OBJECT source TYPE ('CL_OO_SOURCE') EXPORTING clskey = key EXCEPTIONS OTHERS = 1.
          lcl_guard=>require( ok = xsdbool( sy-subrc = 0 )
      message = |Cannot open source editor for { item-name }.| ).
      ENDTRY.
      IF modern = abap_true.
        CALL METHOD source->('IF_OO_CLIF_SOURCE~LOCK').
        locked = abap_true.
        CALL METHOD source->('IF_OO_CLIF_SOURCE~SET_SOURCE') EXPORTING source = item-source.
        CALL METHOD source->('IF_OO_CLIF_SOURCE~SAVE').
        CALL METHOD source->('IF_OO_CLIF_SOURCE~UNLOCK').
      ELSE.
        CALL METHOD source->('ACCESS_PERMISSION') EXPORTING access_mode = gc_modify.
        locked = abap_true.
        CALL METHOD source->('SET_SOURCE') EXPORTING i_source = item-source.
        CALL METHOD source->('SAVE').
        CALL METHOD source->('ACCESS_PERMISSION') EXPORTING access_mode = gc_free.
      ENDIF.
      locked = abap_false.
      IF item-tests IS NOT INITIAL.
        DATA include TYPE syrepid.
        include = cl_oo_classname_service=>get_ccau_name( key-clsname ).
        INSERT REPORT include FROM item-tests STATE 'I' PROGRAM TYPE 'I' FIXED-POINT ARITHMETIC 'X' UNICODE ENABLING 'X'.
        lcl_guard=>require( ok = xsdbool( sy-subrc = 0 )
      message = |Cannot save unit tests for { item-name }.| ).
      ENDIF.
    CATCH cx_root INTO DATA(error).
      IF locked = abap_true.
        TRY.
            IF modern = abap_true.
              CALL METHOD source->('IF_OO_CLIF_SOURCE~UNLOCK').
            ELSE.
              CALL METHOD source->('ACCESS_PERMISSION') EXPORTING access_mode = gc_free.
            ENDIF.
          CATCH cx_root.
            WRITE: / 'Could not release source lock:', item-name.
        ENDTRY.
      ENDIF.
      RAISE EXCEPTION TYPE lcx_install EXPORTING detail = |{ item-name }: { error->get_text( ) }|.
  ENDTRY.
ENDFORM.

FORM create_report USING item TYPE ty_item RAISING lcx_install.
  DATA texts TYPE STANDARD TABLE OF textpool WITH EMPTY KEY.
  CALL TRANSFORMATION id SOURCE XML item-xml RESULT tpool = texts.
  " Serialized selection labels omit SAP's eight-character control prefix.
  LOOP AT texts ASSIGNING FIELD-SYMBOL(<text>).
    <text>-length = strlen( <text>-entry ).
    IF <text>-id = 'S'.
      <text>-entry = `        ` && <text>-entry.
      <text>-length = <text>-length + 8.
    ENDIF.
  ENDLOOP.
  INSERT REPORT item-name FROM item-source STATE 'I' PROGRAM TYPE '1' FIXED-POINT ARITHMETIC 'X' UNICODE ENABLING 'X'.
  lcl_guard=>require( ok = xsdbool( sy-subrc = 0 )
      message = |Cannot create report { item-name }.| ).
  INSERT TEXTPOOL item-name FROM texts LANGUAGE 'E' STATE 'I'.
  lcl_guard=>require( ok = xsdbool( sy-subrc = 0 )
      message = |Cannot save labels for { item-name }.| ).
ENDFORM.
