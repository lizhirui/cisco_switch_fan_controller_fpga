`default_nettype none

import lcd_ui_config_pkg::*;
import lcd_ui_page_config_pkg::*;

module lcd_page_message_ui #(
        parameter CONFIG_ADDR_WIDTH = 4,
        parameter LCD_PIXEL_LINE_NUM = 64,
        parameter LCD_PIXEL_COL_NUM = 128,
        parameter CHAR_WIDTH = 8,
        parameter CHAR_HEIGHT = 16
    )(
        input logic clk,
        input logic rst,

        input logic[PAGE_ID_WIDTH - 1:0] page_id,
        input logic[CONFIG_ADDR_WIDTH - 1:0] config_addr,
        output lcd_ui_config_pkg::lcd_ui_config_data_t config_data
    );

    always_ff @(posedge clk) begin
        if(rst) begin
            config_data <= make_empty_config(LCD_UI_CONFIG_TYPE_FRAME_END);
        end
        else begin
            case(config_addr)
                'd0: begin
                    config_data <= make_fill_rect_config(
                        lcd_ui_x_t'((LCD_PIXEL_COL_NUM - CHAR_WIDTH * 11) / 2),
                        lcd_ui_y_t'(CHAR_HEIGHT + (LCD_PIXEL_LINE_NUM - CHAR_HEIGHT - CHAR_HEIGHT * 2) / 2),
                        lcd_ui_size_t'(CHAR_WIDTH * 11),
                        lcd_ui_size_t'(CHAR_HEIGHT * 2),
                        LCD_UI_COLOR_BLACK
                    );
                end

                'd1: begin
                    if(page_id == PAGE_SAVE_SUCCESS_ID) begin
                        config_data <= make_draw_text_config(
                            lcd_ui_x_t'((LCD_PIXEL_COL_NUM - CHAR_WIDTH * 8) / 2),
                            lcd_ui_y_t'(CHAR_HEIGHT + (LCD_PIXEL_LINE_NUM - CHAR_HEIGHT - CHAR_HEIGHT) / 2),
                            LCD_UI_COLOR_WHITE,
                            lcd_ui_text_data_t'({8'ha6, 8'hb9, 8'hc9, 8'hb3, 8'he6, 8'hb4, 8'ha3, 8'hb1})
                        );
                    end
                    else begin
                        config_data <= make_draw_text_config(
                            lcd_ui_x_t'((LCD_PIXEL_COL_NUM - CHAR_WIDTH * 8) / 2),
                            lcd_ui_y_t'(CHAR_HEIGHT + (LCD_PIXEL_LINE_NUM - CHAR_HEIGHT - CHAR_HEIGHT) / 2),
                            LCD_UI_COLOR_WHITE,
                            lcd_ui_text_data_t'({8'ha6, 8'hb9, 8'hc9, 8'hb3, 8'hd8, 8'hd4, 8'hd3, 8'hbc})
                        );
                    end
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