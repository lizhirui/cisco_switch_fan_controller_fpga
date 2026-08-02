`default_nettype none

import lcd_ui_config_pkg::*;
import lcd_ui_bitmap_pkg::*;

module lcd_page_main_ui #(
        parameter CONFIG_ADDR_WIDTH = 4
    )(
        input logic clk,
        input logic rst,
        input logic[CONFIG_ADDR_WIDTH - 1:0] config_addr,
        output lcd_ui_config_pkg::lcd_ui_config_data_t config_data
    );
    
    localparam lcd_ui_text_data_t TEXT_0 = "321";
    localparam lcd_ui_text_data_t TEXT_1 =
    {
        8'hC3,
        8'hBA,
        8'hE3,
        8'hC4
    };

    always_ff @(posedge clk) begin
        if(rst) begin
            config_data <= make_empty_config(LCD_UI_CONFIG_TYPE_FRAME_END);
        end
        else begin
            case(config_addr)
                'd0: begin
                    config_data <= make_clear_config(LCD_UI_COLOR_WHITE);
                end

                'd1: begin
                    config_data <= make_draw_bitmap_config(lcd_ui_x_t'('d121), lcd_ui_y_t'('d57), LCD_UI_BITMAP_ID_TEST_X_BOX, LCD_UI_COLOR_BLACK);
                end

                'd2: begin
                    config_data <= make_empty_config(LCD_UI_CONFIG_TYPE_FRAME_END);
                end

                default: begin
                    config_data <= make_empty_config(LCD_UI_CONFIG_TYPE_FRAME_END);
                end
            endcase
        end
    end
endmodule