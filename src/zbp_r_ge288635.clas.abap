CLASS zbp_r_ge288635 DEFINITION
  PUBLIC
  ABSTRACT
  FINAL
  FOR BEHAVIOR OF zr_ge288635 .

  PUBLIC SECTION.
    CONSTANTS :
      BEGIN OF order_state,
        saved      TYPE string VALUE 'order_saved',
        new        TYPE string VALUE 'new',
        in_process TYPE string VALUE 'in_process',
        unknown    TYPE string VALUE 'unkown',
        released   TYPE string VALUE 'released',
      END OF order_state,

      BEGIN OF sales_order_state,
        created    TYPE string VALUE 'sales_order_created',
        unknown    TYPE string VALUE 'unkown',
        failed     TYPE string VALUE 'failed',
        in_process TYPE string VALUE 'in_process',
      END OF sales_order_state.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zbp_r_ge288635 IMPLEMENTATION.
ENDCLASS.
