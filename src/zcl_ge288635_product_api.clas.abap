CLASS zcl_GE288635_product_api DEFINITION

 PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    METHODS constructor
      RAISING
        cx_http_dest_provider_error
        cx_web_http_client_error
        /iwbep/cx_gateway.

    INTERFACES if_oo_adt_classrun .

    TYPES t_business_data_external TYPE TABLE OF zi_GE288635_vh_products..

    TYPES tys_a_clfn_product_type TYPE zsc_GE288635_api_product=>tys_a_clfn_product_type.
    TYPES tyt_a_clfn_product_type TYPE STANDARD TABLE OF tys_a_clfn_product_type WITH DEFAULT KEY.
    "! <p class="shorttext synchronized">Filter range for property PRODUCT.</p>
    TYPES tyt_range_product       TYPE RANGE OF tys_a_clfn_product_type-product.

    METHODS get_products
      IMPORTING
        it_filter_cond   TYPE if_rap_query_filter=>tt_name_range_pairs   OPTIONAL
        top              TYPE i OPTIONAL
        skip             TYPE i OPTIONAL
      EXPORTING
        et_business_data TYPE t_business_data_external
      RAISING
        /iwbep/cx_cp_remote
        /iwbep/cx_gateway
        cx_web_http_client_error
        cx_http_dest_provider_error
      .

  PROTECTED SECTION.
  PRIVATE SECTION.

    DATA odata_client_proxy TYPE REF TO /iwbep/if_cp_client_proxy.
    DATA use_mock_data TYPE abap_bool VALUE abap_true.

ENDCLASS.

CLASS zcl_GE288635_product_api IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
   DATA business_data TYPE t_business_data_external.
    DATA filter_conditions  TYPE if_rap_query_filter=>tt_name_range_pairs .
    DATA ranges_table TYPE if_rap_query_filter=>tt_range_option .
    ranges_table = VALUE #(
                            (  sign = 'I' option = 'EQ' low = 'MZ-TG-Y240' )
                            (  sign = 'I' option = 'BT' low = 'TG' high = 'TH' )
                          ).
    filter_conditions = VALUE #( ( name = 'PRODUCT'  range = ranges_table ) ).

    TRY.
        get_products(
          EXPORTING
            it_filter_cond    = filter_conditions
            top               =  5
            skip              =  0
          IMPORTING
            et_business_data  = business_data
          ) .
        out->write( business_data ).
      CATCH cx_root INTO DATA(exception).
        out->write( cl_message_helper=>get_latest_t100_exception( exception )->if_message~get_longtext( ) ).
    ENDTRY.
  ENDMETHOD.

  METHOD get_products.

*    IF use_mock_data = abap_true.
*      et_business_data = VALUE #( ( Product = 'TG11'  )
*                                  ( Product = 'TG12'  )
*                                  ( Product = 'TG13'  )
*                                  ( Product = 'TG15_not_exists' ) ).
*      EXIT.
*    ENDIF.

    DATA lt_business_data TYPE TABLE OF zsc_ge288635_api_product=>tys_a_clfn_product_type.

    DATA: filter_factory   TYPE REF TO /iwbep/if_cp_filter_factory,
          filter_node      TYPE REF TO /iwbep/if_cp_filter_node,
          root_filter_node TYPE REF TO /iwbep/if_cp_filter_node.

    DATA: http_client        TYPE REF TO if_web_http_client,
          odata_client_proxy TYPE REF TO /iwbep/if_cp_client_proxy,
          read_list_request  TYPE REF TO /iwbep/if_cp_request_read_list,
          read_list_response TYPE REF TO /iwbep/if_cp_response_read_lst.

    DATA(http_destination) =
    cl_http_destination_provider=>create_by_cloud_destination(
                                  i_name = 'S4HANA_ODATA_Products_ABAP_ReadOnly'
                                  i_authn_mode            = if_a4c_cp_service=>service_specific
                               ).

    http_client = cl_web_http_client_manager=>create_by_http_destination( i_destination = http_destination ).

    odata_client_proxy = /iwbep/cl_cp_factory_remote=>create_v2_remote_proxy(
      EXPORTING
         is_proxy_model_key       = VALUE #( repository_id       = 'DEFAULT'
                                             proxy_model_id      = 'ZSC_GE288635_API_PRODUCT'
                                             proxy_model_version = '0001' )
        io_http_client             = http_client
        iv_relative_service_root   = '' ).

    " Navigate to the resource and create a request for the read operation
    read_list_request = odata_client_proxy->create_resource_for_entity_set( 'A_CLFN_PRODUCT' )->create_request_for_read( ).

    " Create the filter tree
    filter_factory = read_list_request->create_filter_factory( ).

    LOOP AT it_filter_cond  INTO DATA(filter_condition).
      filter_node  = filter_factory->create_by_range( iv_property_path     = filter_condition-name
                                                              it_range     = filter_condition-range ).
      IF root_filter_node IS INITIAL.
        root_filter_node = filter_node.
      ELSE.
        root_filter_node = root_filter_node->and( filter_node ).
      ENDIF.
    ENDLOOP.

    IF root_filter_node IS NOT INITIAL.
      read_list_request->set_filter( root_filter_node ).
    ENDIF.

    IF top > 0 .
      read_list_request->set_top( top ).
    ENDIF.

    read_list_request->set_skip( skip ).

    " Execute the request and retrieve the business data
    read_list_response = read_list_request->execute( ).
    read_list_response->get_business_data( IMPORTING et_business_data = lt_business_data ).

    et_business_data = CORRESPONDING #( lt_business_data ).

*    DATA read_products TYPE REF TO lcl_read_a_clfn_product.
*    read_products = NEW #( odata_client_proxy ).
*    et_business_data = read_products->execute( it_range_product = it_range_product
*                                               i_top            = i_top
*                                               i_skip           = i_skip ).
  ENDMETHOD.

  METHOD constructor.
    DATA http_client        TYPE REF TO if_web_http_client.
    DATA proxy_model_id     TYPE /iwbep/if_cp_runtime_types=>ty_proxy_model_id.

    proxy_model_id = to_upper( 'ZSC_GE288635_API_PRODUCT' ).

    DATA(http_destination) =
    cl_http_destination_provider=>create_by_cloud_destination( i_name       = 'S4HANA_ODATA_Products_ABAP_ReadOnly'
                                                               i_authn_mode = if_a4c_cp_service=>service_specific ).

    http_client = cl_web_http_client_manager=>create_by_http_destination( i_destination = http_destination ).

    odata_client_proxy = /iwbep/cl_cp_factory_remote=>create_v2_remote_proxy(
                             is_proxy_model_key       = VALUE #( repository_id       = 'DEFAULT'
                                                                 proxy_model_id      = proxy_model_id
                                                                 proxy_model_version = '0001' )
                             io_http_client           = http_client
                             iv_relative_service_root = '' ).

  ENDMETHOD.

ENDCLASS.
