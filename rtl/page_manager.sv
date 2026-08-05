`default_nettype none

import lcd_ui_config_pkg::*;

module page_manager #(
        parameter PAGE_ID_WIDTH = 2,
        parameter CONFIG_ADDR_WIDTH = 4,
    )(
        input logic[PAGE_ID_WIDTH - 1:0] page_id,

        input logic[CONFIG_ADDR_WIDTH - 1:0] page_config_addr,
        output lcd_ui_config_data_t page_config_data,

        output logic[CONFIG_ADDR_WIDTH - 1:0] page_main_config_addr,
        input lcd_ui_config_data_t page_main_config_data
    );

    localparam PAGE_MAIN_ID = PAGE_ID_WIDTH'('h00);

    assign page_main_config_addr = page_config_addr;

    always_comb begin
        page_main_config_data = '0;

        case(page_id)
            PAGE_MAIN_ID: begin
                page_config_data = page_main_config_data;
            end
        endcase
    end
endmodule