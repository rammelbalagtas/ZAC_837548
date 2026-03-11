CLASS zcl_GE288635_start_bgpf DEFINITION
    PUBLIC
    FINAL
    CREATE PUBLIC.

    PUBLIC SECTION.

    INTERFACES if_serializable_object.
    INTERFACES if_bgmc_operation.
    INTERFACES if_bgmc_op_single_tx_uncontr.
    INTERFACES if_bgmc_op_single.

    CLASS-METHODS run_via_bgpf
      IMPORTING i_rap_bo_key                    TYPE sysuuid_x16
      RETURNING VALUE(r_process_monitor_string) TYPE string.

    CLASS-METHODS run_via_bgpf_tx_uncontrolled
      IMPORTING i_rap_bo_key                    TYPE sysuuid_x16
      RETURNING VALUE(r_process_monitor_string) TYPE string.

    METHODS constructor
      IMPORTING i_rap_bo_key TYPE sysuuid_x16.

    CONSTANTS:
      BEGIN OF bgpf_state,
        unknown         TYPE int1 VALUE IS INITIAL,
        erroneous       TYPE int1 VALUE 1,
        new             TYPE int1 VALUE 2,
        running         TYPE int1 VALUE 3,
        successful      TYPE int1 VALUE 4,
        started_from_bo TYPE int1 VALUE 99,
      END OF bgpf_state.

    PROTECTED SECTION.
    PRIVATE SECTION.
    DATA rap_bo_key TYPE sysuuid_x16.
    CONSTANTS wait_time_in_seconds TYPE i VALUE 5.
   ENDCLASS.


   CLASS zcl_GE288635_start_bgpf IMPLEMENTATION.
   METHOD constructor.
     rap_bo_key = i_rap_bo_key.
   ENDMETHOD.

   METHOD if_bgmc_op_single~execute.
     "implement if controlled behavior is needed
   ENDMETHOD.

   METHOD if_bgmc_op_single_tx_uncontr~execute.
     "implement if uncontrolled behavior is needed, e.g. commit work statements

     "There is already a global class **zcl_ac_salesorder_api** available
     DATA start_sales_order_create TYPE REF TO zcl_GE288635_so_api.
     "In one the next steps you will create your own implementation
     "DATA start_sales_order_create TYPE REF TO zcl_GE288635_so_api.

     DATA update TYPE TABLE FOR UPDATE zr_GE288635\\ShoppingCart.
     DATA update_line TYPE STRUCTURE FOR UPDATE zr_GE288635\\ShoppingCart .

     DATA error_message TYPE string.

     READ ENTITIES OF zr_GE288635
             ENTITY ShoppingCart
             ALL FIELDS
             WITH VALUE #( ( %is_draft = if_abap_behv=>mk-off
                             %key-OrderUuid = rap_bo_key
                            )  )
             RESULT DATA(entities)
             FAILED DATA(failed).

     IF entities IS NOT INITIAL.
       LOOP AT entities INTO DATA(entity).
         "There is already a global class **zcl_ac_salesorder_api** available
*         start_sales_order_create = NEW zcl_ac_salesorder_api(

         "In one the next steps you will create your own implementation
         start_sales_order_create = NEW zcl_GE288635_so_api(
                                         i_material = entity-OrderedItem
                                         i_purchase_order_by_customer = CONV #( sy-uname )
                                         i_quantity = entity-OrderQuantity
                                         i_requested_delivery_date = entity-RequestedDeliveryDate
                                         ).

         DATA(r_data) = start_sales_order_create->CreateSalesorder(
                       IMPORTING
                         r_error_message = error_message
                     ).

         update_line-%is_draft = if_abap_behv=>mk-off.
         update_line-OrderUuid = entity-OrderUuid.

         IF r_data-sales_order IS NOT INITIAL.
           update_line-Salesorder    = r_data-sales_order.
           update_line-TotalPrice    = r_data-total_net_amount.
           update_line-SalesOrderStatus = zbp_r_GE288635=>sales_order_state-created.
           update_line-OverallStatus = zbp_r_GE288635=>order_state-released.
           update_line-ManageSalesOrderUrl =
            | https://my413601.s4hana.cloud.sap/ui#SalesOrder-manageV2&/SalesOrderManage('{ r_data-sales_order }') |.
         ELSE.
           update_line-Notes = error_message.
           update_line-OverallStatus = zbp_r_GE288635=>order_state-new.
           update_line-SalesOrderStatus = zbp_r_GE288635=>sales_order_state-failed.
         ENDIF.

         APPEND update_line TO update.
       ENDLOOP.

       MODIFY ENTITIES OF zr_GE288635
        ENTITY ShoppingCart
          UPDATE FIELDS ( SalesOrder OverallStatus SalesOrderStatus TotalPrice  ManageSalesOrderUrl Notes )
            WITH update
        REPORTED DATA(reported_ready)
        FAILED DATA(failed_ready).
     ENDIF.

     COMMIT WORK.
   ENDMETHOD.

   METHOD run_via_bgpf.
      TRY.
        DATA(process_monitor) = cl_bgmc_process_factory=>get_default( )->create(
                                              )->set_name( |Calculate order data { i_rap_bo_key }|
                                              )->set_operation(  NEW zcl_GE288635_start_bgpf( i_rap_bo_key = i_rap_bo_key )
                                              )->save_for_execution( ).

        r_process_monitor_string = process_monitor->to_string( ).
        CATCH cx_bgmc INTO DATA(lx_bgmc).
      ENDTRY.
   ENDMETHOD.

   METHOD run_via_bgpf_tx_uncontrolled.
     TRY.
        DATA(process_monitor) = cl_bgmc_process_factory=>get_default( )->create(
                                              )->set_name( |Calculate order data { i_rap_bo_key }|
                                              )->set_operation_tx_uncontrolled(  NEW zcl_GE288635_start_bgpf( i_rap_bo_key = i_rap_bo_key )
                                              )->save_for_execution( ).

       r_process_monitor_string = process_monitor->to_string( ).
       CATCH cx_bgmc INTO DATA(lx_bgmc).
     ENDTRY.
   ENDMETHOD.

ENDCLASS.

