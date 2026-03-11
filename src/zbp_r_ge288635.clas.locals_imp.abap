CLASS lsc_zr_ge288635 DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

ENDCLASS.

CLASS lsc_zr_ge288635 IMPLEMENTATION.

  METHOD save_modified.

*    DATA(check) = ''.
*    IF check = 'X'.
*      DATA start_sales_order_create TYPE REF TO zcl_ac_salesorder_api.
*      DATA error_message TYPE string.
*      start_sales_order_create = NEW zcl_ac_salesorder_api(
*
*      "In one the next steps you will create your own implementation
*      "start_sales_order_create = NEW zcl_GE288635_so_api(
*                                      i_material = 'TG11'
*                                      i_purchase_order_by_customer = 'TEST'
*                                      i_quantity = 1
*                                      i_requested_delivery_date = '20270101'
*                                      ).
*
*      DATA(r_data) = start_sales_order_create->CreateSalesorder(
*                    IMPORTING
*                      r_error_message = error_message ).
*    ENDIF.

    DATA : ShoppingCarts       TYPE STANDARD TABLE OF zGE288635,
           ShoppingCart        TYPE                   zGE288635,
           events_to_be_raised TYPE TABLE FOR EVENT zr_GE288635~statusUpdated.

    IF create-shoppingcart IS NOT INITIAL.
      LOOP AT create-shoppingcart INTO DATA(create_shoppingcart).
        IF create_shoppingcart-%control-OverallStatus = if_abap_behv=>mk-on
          " AND create_shoppingcart-OverallStatus = zbp_r_GE288635=>order_state-in_process.
          AND create_shoppingcart-OverallStatus = zbp_r_GE288635=>order_state-saved.
          zcl_GE288635_start_bgpf=>run_via_bgpf_tx_uncontrolled( i_rap_bo_key = create_shoppingcart-OrderUuid ).
        ENDIF.
      ENDLOOP.
    ENDIF.

    "the salesorder and the status is updated via BGPF
    IF update-shoppingcart IS NOT INITIAL.
      LOOP AT update-shoppingcart INTO DATA(update_shoppingcart).
        IF update_shoppingcart-%control-SalesOrderStatus = if_abap_behv=>mk-on.
          CLEAR events_to_be_raised.
          APPEND INITIAL LINE TO events_to_be_raised.
          events_to_be_raised[ 1 ] = CORRESPONDING #( update_shoppingcart ).
          RAISE ENTITY EVENT zr_GE288635~statusUpdated FROM events_to_be_raised.
        ENDIF.

        IF update_shoppingcart-%control-OverallStatus = if_abap_behv=>mk-on
          "AND update_shoppingcart-OverallStatus = zbp_r_GE288635=>order_state-in_process.
          AND update_shoppingcart-OverallStatus = zbp_r_GE288635=>order_state-saved.
          zcl_GE288635_start_bgpf=>run_via_bgpf_tx_uncontrolled( i_rap_bo_key = update_shoppingcart-OrderUuid ).
        ENDIF.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_zr_ge288635 DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS:
      get_global_authorizations FOR GLOBAL AUTHORIZATION
        IMPORTING
        REQUEST requested_authorizations FOR ShoppingCart
        RESULT result,
      setStatusToNew FOR DETERMINE ON MODIFY
        IMPORTING keys FOR ShoppingCart~setStatusToNew.

    METHODS calculateOrderID FOR DETERMINE ON SAVE
      IMPORTING keys FOR ShoppingCart~calculateOrderID.

    METHODS setStatusToSaved FOR DETERMINE ON SAVE
      IMPORTING keys FOR ShoppingCart~setStatusToSaved.
    METHODS validateOrderedItem FOR VALIDATE ON SAVE
      IMPORTING keys FOR ShoppingCart~validateOrderedItem.

    METHODS validateOrderQuantity FOR VALIDATE ON SAVE
      IMPORTING keys FOR ShoppingCart~validateOrderQuantity.

    METHODS validateRequestedDeliveryDate FOR VALIDATE ON SAVE
      IMPORTING keys FOR ShoppingCart~validateRequestedDeliveryDate.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR ShoppingCart RESULT result.
ENDCLASS.

CLASS lhc_zr_ge288635 IMPLEMENTATION.
  METHOD get_global_authorizations.
  ENDMETHOD.
  METHOD setStatusToNew.

    READ ENTITIES OF zr_ge288635 IN LOCAL MODE
      ENTITY ShoppingCart
        FIELDS ( OverallStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(entities).

    " If OverallStatus is already set, do nothing
    DELETE entities WHERE OverallStatus IS NOT INITIAL.
    CHECK entities IS NOT INITIAL.

    " Update OverallStatus to 'new' using the class attribute order_state
    MODIFY ENTITIES OF zr_ge288635 IN LOCAL MODE
      ENTITY ShoppingCart
        UPDATE FIELDS ( OverallStatus )
        WITH VALUE #(
          FOR entity IN entities (
            %tky          = entity-%tky
            OverallStatus = zbp_r_ge288635=>order_state-new
          )
        ).
  ENDMETHOD.

  METHOD calculateOrderID.
    DATA: lv_count        TYPE i,
          lv_semantic_key TYPE string.

    " Count the number of entries in the table ZGE288635
    SELECT COUNT(*) FROM zGE288635 INTO @lv_count.

    " Calculate the semantic key based on the count
    lv_semantic_key = |SEM-{ lv_count + 1 }|.

    " Read the entities to be updated
    READ ENTITIES OF zr_GE288635 IN LOCAL MODE
      ENTITY ShoppingCart
        FIELDS ( OrderID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(entities).

    " Update the OrderID with the calculated semantic key
    LOOP AT entities INTO DATA(entity).
      MODIFY ENTITIES OF zr_GE288635 IN LOCAL MODE
        ENTITY ShoppingCart
          UPDATE FIELDS ( OrderID )
          WITH VALUE #(
            ( %tky = entity-%tky
              OrderID = lv_semantic_key )
          ).
      APPEND VALUE #(
          %tky        = entity-%tky
          %state_area = 'Determination'
      ) TO reported-ShoppingCart.
    ENDLOOP.
  ENDMETHOD.

  METHOD setStatusToSaved.
    READ ENTITIES OF zr_GE288635 IN LOCAL MODE
        ENTITY ShoppingCart
          FIELDS ( OverallStatus )
          WITH CORRESPONDING #( keys )
        RESULT DATA(entities).

    LOOP AT entities INTO DATA(entity).
      MODIFY ENTITIES OF zr_GE288635 IN LOCAL MODE
        ENTITY ShoppingCart
          UPDATE FIELDS ( OverallStatus )
          WITH VALUE #(
            ( %tky = entity-%tky
              OverallStatus = zbp_r_GE288635=>order_state-saved )
          ).
      APPEND VALUE #(
          %tky        = entity-%tky
          %state_area = 'Determination'
      ) TO reported-ShoppingCart.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateOrderedItem.

    READ ENTITIES OF zr_GE288635 IN LOCAL MODE
      ENTITY ShoppingCart
        FIELDS ( OrderedItem )
        WITH CORRESPONDING #( keys )
      RESULT DATA(entities).

    LOOP AT entities INTO DATA(entity).
      " Check if the OrderedItem is initial
      IF entity-OrderedItem IS INITIAL.
        APPEND VALUE #( %tky = entity-%tky ) TO failed-ShoppingCart.
        APPEND VALUE #(
            %tky        = entity-%tky
            %state_area = 'Validation'
            %msg        = new_message_with_text(
              text     = 'Ordered Item must not be initial'
              severity = if_abap_behv_message=>severity-error
            )
        ) TO reported-ShoppingCart.
      ELSE.
        " Create an instance of the product API class
        DATA(lo_product_api) = NEW zcl_ac_product_api( ).

        " Check if the product exists using the product_exists method
*        IF NOT lo_product_api->product_exists( entity-OrderedItem ).
*          APPEND VALUE #( %tky = entity-%tky ) TO failed-ShoppingCart.
*          APPEND VALUE #(
*              %tky        = entity-%tky
*              %state_area = 'Validation'
*              %msg        = new_message_with_text(
*                text     = 'Ordered Item does not exist'
*                severity = if_abap_behv_message=>severity-error
*              )
*          ) TO reported-ShoppingCart.
*        ENDIF.
      ENDIF.
    ENDLOOP.


  ENDMETHOD.

  METHOD validateOrderQuantity.

    READ ENTITIES OF zr_GE288635 IN LOCAL MODE
      ENTITY ShoppingCart
        FIELDS ( OrderQuantity )
        WITH CORRESPONDING #( keys )
      RESULT DATA(entities).

    LOOP AT entities INTO DATA(entity).
      IF entity-OrderQuantity IS INITIAL.
        APPEND VALUE #( %tky = entity-%tky ) TO failed-ShoppingCart.
        APPEND VALUE #(
            %tky        = entity-%tky
            %state_area = 'Validation'
            %msg        = new_message_with_text(
              text     = 'Order Quantity must not be initial'
              severity = if_abap_behv_message=>severity-error
            )
        ) TO reported-ShoppingCart.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD validateRequestedDeliveryDate.

    READ ENTITIES OF zr_GE288635 IN LOCAL MODE
      ENTITY ShoppingCart
        FIELDS ( RequestedDeliveryDate )
        WITH CORRESPONDING #( keys )
      RESULT DATA(entities).

    LOOP AT entities INTO DATA(entity).
      " Check if the RequestedDeliveryDate is initial
      IF entity-RequestedDeliveryDate IS INITIAL.
        APPEND VALUE #( %tky = entity-%tky ) TO failed-ShoppingCart.
        APPEND VALUE #(
            %tky        = entity-%tky
            %state_area = 'Validation'
            %msg        = new_message_with_text(
              text     = 'Requested Delivery Date must not be initial'
              severity = if_abap_behv_message=>severity-error
            )
        ) TO reported-ShoppingCart.
      ELSE.
        " Check if the RequestedDeliveryDate is in the future
        IF entity-RequestedDeliveryDate <= cl_abap_context_info=>get_system_date( ).
          APPEND VALUE #( %tky = entity-%tky ) TO failed-ShoppingCart.
          APPEND VALUE #(
              %tky        = entity-%tky
              %state_area = 'Validation'
              %msg        = new_message_with_text(
                text     = 'Requested Delivery Date must be in the future'
                severity = if_abap_behv_message=>severity-error
              )
          ) TO reported-ShoppingCart.
        ENDIF.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD get_instance_features.

    " read relevant shopping cart instance data
    READ ENTITIES OF zr_ge288635 IN LOCAL MODE
      ENTITY ShoppingCart
        FIELDS ( OrderUuid OverallStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(entities)
      FAILED failed.

    " evaluate the conditions, set the operation state, and set result parameter
    result = VALUE #( FOR entity IN entities
                    ( %tky                   = entity-%tky

                      %features-%update      = COND #( WHEN entity-OverallStatus = zbp_r_GE288635=>order_state-released
                                                       THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled   )
                      %features-%delete      = COND #( WHEN entity-OverallStatus = zbp_r_GE288635=>order_state-released
                                                       THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled )
                      %action-Edit           = COND #( WHEN entity-OverallStatus = zbp_r_GE288635=>order_state-released
                                                       THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled )
                    ) ).

  ENDMETHOD.

ENDCLASS.
