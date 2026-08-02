`default_nettype none

import lcd_ui_config_pkg::*;

module lcd_ui_config_decoder(
        input lcd_ui_config_data_t config_data,
        output lcd_ui_config_type_t config_type,
        output logic config_nop,
        output logic config_draw_text,
        output logic config_draw_bitmap,
        output logic config_fill_rect,
        output logic config_draw_line,
        output logic config_clear,
        output logic config_frame_end,
        output logic config_error,
        output lcd_ui_x_t draw_text_x,
        output lcd_ui_y_t draw_text_y,
        output lcd_ui_color_t draw_text_color,
        output lcd_ui_text_data_t draw_text_text
    );
    
    lcd_ui_draw_text_config_t draw_text_config;

    assign config_type = config_data[LCD_UI_CONFIG_TYPE_WIDTH - 1:0];
    assign draw_text_config = config_data[LCD_UI_CONFIG_PAYLOAD_LSB +: LCD_UI_DRAW_TEXT_CONFIG_WIDTH];

    always_comb begin
        config_nop = 1'b0;
        config_draw_text = 1'b0;
        config_draw_bitmap = 1'b0;
        config_fill_rect = 1'b0;
        config_draw_line = 1'b0;
        config_clear = 1'b0;
        config_frame_end = 1'b0;
        config_error = 1'b0;
        draw_text_x = '0;
        draw_text_y = '0;
        draw_text_color = 1'b0;
        draw_text_text = '0;

        case(config_type)
            LCD_UI_CONFIG_TYPE_NOP: begin
                config_nop = 1'b1;
            end

            LCD_UI_CONFIG_TYPE_DRAW_TEXT: begin
                config_draw_text = 1'b1;
                draw_text_x = draw_text_config.x;
                draw_text_y = draw_text_config.y;
                draw_text_color = draw_text_config.color;
                draw_text_text = draw_text_config.text;
            end
            
            LCD_UI_CONFIG_TYPE_DRAW_BITMAP: begin
                config_draw_bitmap = 1'b1;
            end
            
            LCD_UI_CONFIG_TYPE_FILL_RECT: begin
                config_fill_rect = 1'b1;
            end
            
            LCD_UI_CONFIG_TYPE_DRAW_LINE: begin
                config_draw_line = 1'b1;
            end
            
            LCD_UI_CONFIG_TYPE_CLEAR: begin
                config_clear = 1'b1;
            end

            LCD_UI_CONFIG_TYPE_FRAME_END: begin
                config_frame_end = 1'b1;
            end
            
            default: begin
                config_error = 1'b1;
            end
        endcase
    end
endmodule