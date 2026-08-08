`default_nettype none

import lcd_ui_config_pkg::*;
import lcd_ui_bitmap_pkg::*;

module lcd_page_main_ui #(
        parameter CONFIG_ADDR_WIDTH = 4,
        parameter LCD_PIXEL_LINE_NUM = 64,
        parameter LCD_PIXEL_COL_NUM = 128,
        parameter CHAR_WIDTH = 8,
        parameter CHAR_HEIGHT = 16
    )(
        input logic clk,
        input logic rst,
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
                    config_data <= make_clear_config(LCD_UI_COLOR_WHITE);
                end

                'd1: begin
                    config_data <= make_fill_rect_config(lcd_ui_x_t'('d0), lcd_ui_y_t'('d0), lcd_ui_size_t'(LCD_PIXEL_COL_NUM), lcd_ui_size_t'(CHAR_HEIGHT), LCD_UI_COLOR_BLACK);
                end
                
                'd2: begin
                    config_data <= make_draw_text_config(lcd_ui_x_t'(CHAR_WIDTH / 2), lcd_ui_y_t'('d0), LCD_UI_COLOR_WHITE, lcd_ui_text_data_t'({8'hf7, 8'hc6, 8'hc6, 8'hd6, 8'hd8, 8'hbf, 8'hc8, 8'hc9, 8'he7, 8'hb7, 8'h4f, 8'h43, 8'h53, 8'h49, 8'h43}));
                end
                
                'd3: begin
                    config_data <= make_draw_text_config(lcd_ui_x_t'((LCD_PIXEL_COL_NUM - CHAR_WIDTH * 6) / 2), lcd_ui_y_t'(CHAR_HEIGHT * 1.5), LCD_UI_COLOR_BLACK, lcd_ui_text_data_t'({8'hf1, 8'hc8, 8'hbe, 8'hd6, 8'hee, 8'hc0}));
                end
                
                'd4: begin
                    config_data <= make_draw_text_config(lcd_ui_x_t'((LCD_PIXEL_COL_NUM - CHAR_WIDTH * 8) / 2), lcd_ui_y_t'(CHAR_HEIGHT * 2.5), LCD_UI_COLOR_BLACK, lcd_ui_text_data_t'({8'h38, 8'h30, 8'h38, 8'h30, 8'h36, 8'h32, 8'h30, 8'h32}));
                end

                'd5: begin
                    config_data <= make_empty_config(LCD_UI_CONFIG_TYPE_FRAME_END);
                end

                default: begin
                    config_data <= make_empty_config(LCD_UI_CONFIG_TYPE_FRAME_END);
                end
            endcase
        end
    end
endmodule