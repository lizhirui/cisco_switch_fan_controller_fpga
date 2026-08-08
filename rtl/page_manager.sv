`default_nettype none

import lcd_ui_config_pkg::*;
import lcd_ui_page_config_pkg::*;

module page_manager #(
        parameter MAIN_FAN_NUM = 8
    )(
        input logic[PAGE_ID_WIDTH - 1:0] page_id,
        output lcd_ui_config_data_t page_config_data,
        input lcd_ui_config_data_t page_main_config_data,
        input lcd_ui_config_data_t page_cisco_config_data,
        input lcd_ui_config_data_t page_main_fan_config_data,
        input lcd_ui_config_data_t page_message_config_data
    );

    always_comb begin
        page_config_data = '0;
        
        if((page_id >= PAGE_MAIN_FAN_BASE_ID) && (page_id < unsigned'(PAGE_MAIN_FAN_BASE_ID + MAIN_FAN_NUM))) begin
            page_config_data = page_main_fan_config_data;
        end
        else if((page_id == PAGE_SAVE_SUCCESS_ID) || (page_id == PAGE_LOAD_SUCCESS_ID)) begin
            page_config_data = page_message_config_data;
        end
        else begin
            case(page_id)
                PAGE_MAIN_ID: begin
                    page_config_data = page_main_config_data;
                end
                
                PAGE_CISCO_ID: begin
                    page_config_data = page_cisco_config_data;
                end
            endcase
        end
    end
endmodule