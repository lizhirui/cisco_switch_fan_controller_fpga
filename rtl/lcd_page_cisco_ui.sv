`default_nettype none

import lcd_ui_config_pkg::*;
import lcd_ui_bitmap_pkg::*;

module lcd_page_cisco_ui #(
        parameter CONFIG_ADDR_WIDTH = 4,
        parameter LCD_PIXEL_LINE_NUM = 64,
        parameter LCD_PIXEL_COL_NUM = 128,
        parameter CHAR_WIDTH = 8,
        parameter CHAR_HEIGHT = 16,
        parameter PWM_DUTY_RATIO_WIDTH = 8,
        parameter RPM_WIDTH = 14
    )(
        input logic clk,
        input logic rst,
        input logic[CONFIG_ADDR_WIDTH - 1:0] config_addr,
        output lcd_ui_config_pkg::lcd_ui_config_data_t config_data,
        
        input logic cisco_led_status_green,
        input logic cisco_led_status_red,
        input logic[PWM_DUTY_RATIO_WIDTH - 1:0] cisco_fan1234_pwm_duty_ratio,
        input logic[PWM_DUTY_RATIO_WIDTH - 1:0] cisco_fan5678_pwm_duty_ratio,
        input logic[RPM_WIDTH - 1:0] cisco_fan1234_rpm,
        input logic[RPM_WIDTH - 1:0] cisco_fan5678_rpm
    );
    
    localparam PWM_DUTY_RATIO_TEXT_LEN = 3;
    localparam RPM_TEXT_LEN = 5;
    
    logic[PWM_DUTY_RATIO_TEXT_LEN * 8 - 1:0] fan1234_pwm_duty_ratio_text;
    logic[PWM_DUTY_RATIO_TEXT_LEN * 8 - 1:0] fan5678_pwm_duty_ratio_text;
    logic[RPM_TEXT_LEN * 8 - 1:0] fan1234_rpm_text;
    logic[RPM_TEXT_LEN * 8 - 1:0] fan5678_rpm_text;
    
    binary_decimal_converter #(
        .VALUE_WIDTH(PWM_DUTY_RATIO_WIDTH),
        .DIGIT_NUM(PWM_DUTY_RATIO_TEXT_LEN)
    )binary_decimal_converter_fan1234_pwm_inst(
        .clk(clk),
        .rst(rst),
        .value(cisco_fan1234_pwm_duty_ratio),
        .text(fan1234_pwm_duty_ratio_text)
    );
    
    binary_decimal_converter #(
        .VALUE_WIDTH(PWM_DUTY_RATIO_WIDTH),
        .DIGIT_NUM(PWM_DUTY_RATIO_TEXT_LEN)
    )binary_decimal_converter_fan5678_pwm_inst(
        .clk(clk),
        .rst(rst),
        .value(cisco_fan5678_pwm_duty_ratio),
        .text(fan5678_pwm_duty_ratio_text)
    );
    
    binary_decimal_converter #(
        .VALUE_WIDTH(PWM_DUTY_RATIO_WIDTH),
        .DIGIT_NUM(RPM_TEXT_LEN)
    )binary_decimal_converter_fan1234_rpm_inst(
        .clk(clk),
        .rst(rst),
        .value(cisco_fan1234_rpm),
        .text(fan1234_rpm_text)
    );
    
    binary_decimal_converter #(
        .VALUE_WIDTH(PWM_DUTY_RATIO_WIDTH),
        .DIGIT_NUM(RPM_TEXT_LEN)
    )binary_decimal_converter_fan5678_rpm_inst(
        .clk(clk),
        .rst(rst),
        .value(cisco_fan5678_rpm),
        .text(fan5678_rpm_text)
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
                    config_data <= make_draw_text_config(lcd_ui_x_t'((LCD_PIXEL_COL_NUM - CHAR_WIDTH * 13) / 2), lcd_ui_y_t'('d0), LCD_UI_COLOR_WHITE, lcd_ui_text_data_t'({8'hac, 8'hcc, 8'hb4, 8'hd7, 8'hda, 8'hbf, 8'hd3, 8'hbd, 8'h4f, 8'h43, 8'h53, 8'h49, 8'h43}));
                end
                
                'd3: begin
                    config_data <= make_draw_text_config(lcd_ui_x_t'((LCD_PIXEL_COL_NUM - CHAR_WIDTH * 14) / 2), lcd_ui_y_t'(CHAR_HEIGHT * 1), LCD_UI_COLOR_BLACK, lcd_ui_text_data_t'({8'h20, 8'h4d, 8'h50, 8'h52, 8'h20, 8'h20, 8'h4d, 8'h57, 8'h50, 8'h20, 8'h20, 8'h44, 8'h49, 8'h20}));
                end
                
                'd4: begin
                    config_data <= make_draw_text_config(lcd_ui_x_t'((LCD_PIXEL_COL_NUM - CHAR_WIDTH * 14) / 2), lcd_ui_y_t'(CHAR_HEIGHT * 2), LCD_UI_COLOR_BLACK, lcd_ui_text_data_t'({fan1234_rpm_text, 8'h20, fan1234_pwm_duty_ratio_text, 8'h20, 8'h34, 8'h33, 8'h32, 8'h31}));
                end
                
                'd5: begin
                    config_data <= make_draw_text_config(lcd_ui_x_t'((LCD_PIXEL_COL_NUM - CHAR_WIDTH * 14) / 2), lcd_ui_y_t'(CHAR_HEIGHT * 3), LCD_UI_COLOR_BLACK, lcd_ui_text_data_t'({fan5678_rpm_text, 8'h20, fan5678_pwm_duty_ratio_text, 8'h20, 8'h38, 8'h37, 8'h36, 8'h35}));
                end
                
                'd6: begin
                    config_data <= make_fill_rect_config(lcd_ui_x_t'('d0), lcd_ui_y_t'(CHAR_HEIGHT * 1), lcd_ui_size_t'(CHAR_WIDTH), lcd_ui_size_t'(CHAR_HEIGHT), cisco_led_status_green ? LCD_UI_COLOR_BLACK : LCD_UI_COLOR_WHITE);
                end
                
                'd7: begin
                    config_data <= make_fill_rect_config(lcd_ui_x_t'(CHAR_WIDTH * 'd15), lcd_ui_y_t'(CHAR_HEIGHT * 1), lcd_ui_size_t'(CHAR_WIDTH), lcd_ui_size_t'(CHAR_HEIGHT), cisco_led_status_red ? LCD_UI_COLOR_BLACK : LCD_UI_COLOR_WHITE);
                end
                
                'd8: begin
                    config_data <= make_draw_text_config(lcd_ui_x_t'('d0), lcd_ui_y_t'(CHAR_HEIGHT * 1), cisco_led_status_green ? LCD_UI_COLOR_WHITE : LCD_UI_COLOR_BLACK, lcd_ui_text_data_t'("G"));
                end
                
                'd9: begin
                    config_data <= make_draw_text_config(lcd_ui_x_t'(CHAR_WIDTH * 'd15), lcd_ui_y_t'(CHAR_HEIGHT * 1), cisco_led_status_red ? LCD_UI_COLOR_WHITE : LCD_UI_COLOR_BLACK, lcd_ui_text_data_t'("R"));
                end

                'd10: begin
                    config_data <= make_empty_config(LCD_UI_CONFIG_TYPE_FRAME_END);
                end

                default: begin
                    config_data <= make_empty_config(LCD_UI_CONFIG_TYPE_FRAME_END);
                end
            endcase
        end
    end
endmodule