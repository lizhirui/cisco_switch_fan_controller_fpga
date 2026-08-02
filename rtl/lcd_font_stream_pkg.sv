`default_nettype none

package lcd_font_stream_pkg;
    import lcd_ui_config_pkg::*;
    
    localparam LCD_FONT_DATA_WIDTH = 8;
    localparam LCD_FONT_DATA_LEN_WIDTH = 6;
    
    typedef logic[LCD_FONT_DATA_WIDTH - 1:0] lcd_font_data_t;
    typedef logic[LCD_FONT_DATA_LEN_WIDTH - 1:0] lcd_font_data_len_t;
    
    typedef struct packed
    {
        lcd_ui_x_t char_x;
        lcd_ui_y_t char_y;
        lcd_ui_color_t char_color;
        lcd_font_data_len_t data_len;
    }lcd_font_side_data_t;
    
    typedef struct packed
    {
        lcd_font_side_data_t side_data;
        lcd_font_data_t data;
    }lcd_font_stream_data_t;
    
    localparam LCD_FONT_SIDE_DATA_WIDTH = $bits(lcd_font_side_data_t);
    localparam LCD_FONT_STREAM_DATA_WIDTH = $bits(lcd_font_stream_data_t);
endpackage