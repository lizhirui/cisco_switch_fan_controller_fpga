`default_nettype none

package lcd_ui_page_config_pkg;
    localparam PAGE_ID_WIDTH = 4;
    localparam USER_PAGE_NUM = 10;
    localparam PAGE_MAIN_ID = PAGE_ID_WIDTH'('h00);
    localparam PAGE_CISCO_ID = PAGE_ID_WIDTH'('h01);
    localparam PAGE_MAIN_FAN_BASE_ID = PAGE_ID_WIDTH'('h02);
    localparam PAGE_SAVE_SUCCESS_ID = PAGE_ID_WIDTH'('h0e);
    localparam PAGE_LOAD_SUCCESS_ID = PAGE_ID_WIDTH'('h0f);
endpackage