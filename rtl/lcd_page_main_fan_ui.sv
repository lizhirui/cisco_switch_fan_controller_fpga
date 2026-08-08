`default_nettype none

import lcd_ui_config_pkg::*;
import lcd_ui_page_config_pkg::*;
import lcd_ui_bitmap_pkg::*;

module lcd_page_main_fan_ui #(
        parameter CONFIG_ADDR_WIDTH = 4,
        parameter LCD_PIXEL_LINE_NUM = 64,
        parameter LCD_PIXEL_COL_NUM = 128,
        parameter CHAR_WIDTH = 8,
        parameter CHAR_HEIGHT = 16,
        parameter PWM_DUTY_RATIO_WIDTH = 8,
        parameter RPM_WIDTH = 14,
        parameter MAIN_FAN_NUM = 8
    )(
        input logic clk,
        input logic rst,
        input logic[CONFIG_ADDR_WIDTH - 1:0] config_addr,
        output lcd_ui_config_pkg::lcd_ui_config_data_t config_data,
        
        input logic[PAGE_ID_WIDTH - 1:0] page_id,
        input logic key_add_pulse,
        input logic key_sub_pulse,
        output logic[PWM_DUTY_RATIO_WIDTH - 1:0] main_fan_pwm_duty_ratio_wdata[0:MAIN_FAN_NUM - 1],
        output logic[MAIN_FAN_NUM - 1:0] main_fan_pwm_duty_ratio_we,
        input logic[PWM_DUTY_RATIO_WIDTH - 1:0] main_fan_pwm_duty_ratio[0:MAIN_FAN_NUM - 1],
        input logic[RPM_WIDTH - 1:0] main_fan_rpm[0:MAIN_FAN_NUM - 1]
    );
    
    localparam PWM_DUTY_RATIO_TEXT_LEN = 3;
    localparam RPM_TEXT_LEN = 5;
    
    logic[$clog2(MAIN_FAN_NUM) - 1:0] cur_id;
    logic[PWM_DUTY_RATIO_TEXT_LEN * 8 - 1:0] pwm_duty_ratio_text;
    logic[RPM_TEXT_LEN * 8 - 1:0] rpm_text;
    
    genvar i;
    
    assign cur_id = (page_id >= PAGE_MAIN_FAN_BASE_ID) && (page_id < unsigned'(PAGE_MAIN_FAN_BASE_ID + MAIN_FAN_NUM)) ? (page_id - PAGE_MAIN_FAN_BASE_ID) : '0;
    
    binary_decimal_converter #(
        .VALUE_WIDTH(PWM_DUTY_RATIO_WIDTH),
        .DIGIT_NUM(PWM_DUTY_RATIO_TEXT_LEN)
    )binary_decimal_converter_pwm_inst(
        .clk(clk),
        .rst(rst),
        .value(main_fan_pwm_duty_ratio[cur_id]),
        .text(pwm_duty_ratio_text)
    );
    
    binary_decimal_converter #(
        .VALUE_WIDTH(RPM_WIDTH),
        .DIGIT_NUM(RPM_TEXT_LEN)
    )binary_decimal_converter_rpm_inst(
        .clk(clk),
        .rst(rst),
        .value(main_fan_rpm[cur_id]),
        .text(rpm_text)
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
                    config_data <= make_draw_text_config(lcd_ui_x_t'((LCD_PIXEL_COL_NUM - CHAR_WIDTH * 11) / 2), lcd_ui_y_t'('d0), LCD_UI_COLOR_WHITE, lcd_ui_text_data_t'({8'hac, 8'hcc, 8'hb4, 8'hd7, 8'(8'h31 + cur_id), 8'hc8, 8'hc9, 8'he7, 8'hb7, 8'hf7, 8'hd6}));
                end
                
                'd3: begin
                    config_data <= make_draw_text_config(lcd_ui_x_t'((LCD_PIXEL_COL_NUM - CHAR_WIDTH * 14) / 2), lcd_ui_y_t'(CHAR_HEIGHT * 1.5), LCD_UI_COLOR_BLACK, lcd_ui_text_data_t'({pwm_duty_ratio_text, 8'hba, 8'ha3, 8'hc8, 8'hb1, 8'hd5, 8'hbf, 8'hbc, 8'hd5, 8'h4d, 8'h57, 8'h50}));
                end
                
                'd4: begin
                    config_data <= make_draw_text_config(lcd_ui_x_t'((LCD_PIXEL_COL_NUM - CHAR_WIDTH * 15) / 2), lcd_ui_y_t'(CHAR_HEIGHT * 2.5), LCD_UI_COLOR_BLACK, lcd_ui_text_data_t'({8'h4d, 8'h50, 8'h52, 8'h20, rpm_text, 8'hba, 8'ha3, 8'hd9, 8'hcb, 8'haa, 8'hd7}));
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
    
    generate
        for(i = 0;i < MAIN_FAN_NUM;i++) begin:main_fan_pwm_duty_ratio_wdata_gen
            always_ff @(posedge clk) begin
                if(rst) begin
                    main_fan_pwm_duty_ratio_wdata[i] <= '0;
                    main_fan_pwm_duty_ratio_we[i] <= 1'b0;
                end
                else if(key_add_pulse && (main_fan_pwm_duty_ratio[i] != '1) && (page_id == unsigned'(PAGE_MAIN_FAN_BASE_ID + i))) begin
                    main_fan_pwm_duty_ratio_wdata[i] <= main_fan_pwm_duty_ratio[i] + 'b1;
                    main_fan_pwm_duty_ratio_we[i] <= 1'b1;
                end
                else if(key_sub_pulse && (main_fan_pwm_duty_ratio[i] != '0) && (page_id == unsigned'(PAGE_MAIN_FAN_BASE_ID + i))) begin
                    main_fan_pwm_duty_ratio_wdata[i] <= main_fan_pwm_duty_ratio[i] - 'b1;
                    main_fan_pwm_duty_ratio_we[i] <= 1'b1;
                end
                else begin
                    main_fan_pwm_duty_ratio_wdata[i] <= '0;
                    main_fan_pwm_duty_ratio_we[i] <= 1'b0;
                end
            end
        end
    endgenerate
endmodule