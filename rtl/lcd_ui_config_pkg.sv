`default_nettype none

package lcd_ui_config_pkg;
    localparam LCD_UI_CONFIG_TYPE_WIDTH = 8;
    localparam LCD_UI_CONFIG_DATA_WIDTH = 256;
    localparam LCD_UI_CONFIG_PAYLOAD_WIDTH = LCD_UI_CONFIG_DATA_WIDTH - LCD_UI_CONFIG_TYPE_WIDTH;
    localparam LCD_UI_CONFIG_PAYLOAD_LSB = LCD_UI_CONFIG_TYPE_WIDTH;
    
    localparam LCD_UI_X_WIDTH = 8;
    localparam LCD_UI_Y_WIDTH = 8;
    localparam LCD_UI_SIZE_WIDTH = 8;
    localparam LCD_UI_COLOR_WIDTH = 1;
    
    localparam LCD_UI_TEXT_DATA_WIDTH = 128;
    
    typedef logic[LCD_UI_CONFIG_TYPE_WIDTH - 1:0] lcd_ui_config_type_t;
    typedef logic[LCD_UI_CONFIG_DATA_WIDTH - 1:0] lcd_ui_config_data_t;
    typedef logic[LCD_UI_CONFIG_PAYLOAD_WIDTH - 1:0] lcd_ui_config_payload_t;
    
    typedef logic[LCD_UI_X_WIDTH - 1:0] lcd_ui_x_t;
    typedef logic[LCD_UI_Y_WIDTH - 1:0] lcd_ui_y_t;
    typedef logic[LCD_UI_SIZE_WIDTH - 1:0] lcd_ui_size_t;
    typedef logic[LCD_UI_COLOR_WIDTH - 1:0] lcd_ui_color_t;
    
    typedef logic[LCD_UI_TEXT_DATA_WIDTH - 1:0] lcd_ui_text_data_t;
    
    localparam lcd_ui_config_type_t LCD_UI_CONFIG_TYPE_NOP = LCD_UI_CONFIG_TYPE_WIDTH'('h00);
    localparam lcd_ui_config_type_t LCD_UI_CONFIG_TYPE_DRAW_TEXT = LCD_UI_CONFIG_TYPE_WIDTH'('h01);
    localparam lcd_ui_config_type_t LCD_UI_CONFIG_TYPE_BITMAP = LCD_UI_CONFIG_TYPE_WIDTH'('h02);
    localparam lcd_ui_config_type_t LCD_UI_CONFIG_TYPE_FILL_RECT = LCD_UI_CONFIG_TYPE_WIDTH'('h03);
    localparam lcd_ui_config_type_t LCD_UI_CONFIG_TYPE_DRAW_LINE = LCD_UI_CONFIG_TYPE_WIDTH'('h04);
    localparam lcd_ui_config_type_t LCD_UI_CONFIG_TYPE_CLEAR = LCD_UI_CONFIG_TYPE_WIDTH'('h05);
    localparam lcd_ui_config_type_t LCD_UI_CONFIG_TYPE_FRAME_END = LCD_UI_CONFIG_TYPE_WIDTH'('hff);
    
    localparam lcd_ui_color_t LCD_UI_COLOR_WHITE = LCD_UI_COLOR_WIDTH'('d0);
    localparam lcd_ui_color_t LCD_UI_COLOR_BLACK = LCD_UI_COLOR_WIDTH'('d1);
    
    typedef struct packed
    {
        lcd_ui_x_t x;
        lcd_ui_y_t y;
        lcd_ui_color_t color;
        lcd_ui_text_data_t text;
    }lcd_ui_draw_text_config_t;
    
    typedef struct packed
    {
        lcd_ui_x_t x;
        lcd_ui_y_t y;
        lcd_ui_size_t width;
        lcd_ui_size_t height;
        lcd_ui_color_t color;
    }lcd_ui_fill_rect_config_t;
    
    typedef struct packed
    {
        lcd_ui_x_t x0;
        lcd_ui_y_t y0;
        lcd_ui_x_t x1;
        lcd_ui_y_t y1;
        lcd_ui_color_t color;
    }lcd_ui_draw_line_config_t;
    
    typedef struct packed
    {
        lcd_ui_color_t color;
    }lcd_ui_clear_config_t;
    
    localparam LCD_UI_DRAW_TEXT_CONFIG_WIDTH = $bits(lcd_ui_draw_text_config_t);
    localparam LCD_UI_FILL_RECT_CONFIG_WIDTH = $bits(lcd_ui_fill_rect_config_t);
    localparam LCD_UI_DRAW_LINE_CONFIG_WIDTH = $bits(lcd_ui_draw_line_config_t);
    localparam LCD_UI_CLEAR_CONFIG_WIDTH = $bits(lcd_ui_clear_config_t);
    
    function automatic lcd_ui_config_data_t make_config(
            input lcd_ui_config_type_t config_type,
            input lcd_ui_config_payload_t config_payload
        );
        
        lcd_ui_config_data_t result;
        
        begin
            result = '0;
            result[LCD_UI_CONFIG_TYPE_WIDTH - 1:0] = config_type;
            result[LCD_UI_CONFIG_PAYLOAD_LSB +: LCD_UI_CONFIG_PAYLOAD_WIDTH] = config_payload;
            make_config = result;
        end
    endfunction
    
    function automatic lcd_ui_config_data_t make_empty_config(
            input lcd_ui_config_type_t config_type
        );

        begin
            make_empty_config = make_config(config_type, '0);
        end
    endfunction

    function automatic lcd_ui_config_data_t make_draw_text_config(
            input lcd_ui_x_t x,
            input lcd_ui_y_t y,
            input lcd_ui_color_t color,
            input lcd_ui_text_data_t text
        );

        lcd_ui_config_payload_t config_payload;
        lcd_ui_draw_text_config_t draw_text_config;

        begin
            config_payload = '0;
            draw_text_config = '0;
            draw_text_config.x = x;
            draw_text_config.y = y;
            draw_text_config.color = color;
            draw_text_config.text = text;
            config_payload[LCD_UI_DRAW_TEXT_CONFIG_WIDTH - 1:0] = draw_text_config;
            make_draw_text_config = make_config(LCD_UI_CONFIG_TYPE_DRAW_TEXT, config_payload);
        end
    endfunction
    
    function automatic lcd_ui_config_data_t make_fill_rect_config(
            input lcd_ui_x_t x,
            input lcd_ui_y_t y,
            input lcd_ui_size_t width,
            input lcd_ui_size_t height,
            input lcd_ui_color_t color
        );
        
        lcd_ui_config_payload_t config_payload;
        lcd_ui_fill_rect_config_t fill_rect_config;
        
        begin
            config_payload = '0;
            fill_rect_config = '0;
            fill_rect_config.x = x;
            fill_rect_config.y = y;
            fill_rect_config.width = width;
            fill_rect_config.height = height;
            fill_rect_config.color = color;
            config_payload[LCD_UI_FILL_RECT_CONFIG_WIDTH - 1:0] = fill_rect_config;
            make_fill_rect_config = make_config(LCD_UI_CONFIG_TYPE_FILL_RECT, config_payload);
        end
    endfunction
    
    function automatic lcd_ui_config_data_t make_draw_line_config(
            input lcd_ui_x_t x0,
            input lcd_ui_y_t y0,
            input lcd_ui_x_t x1,
            input lcd_ui_y_t y1,
            input lcd_ui_color_t color
        );
        
        lcd_ui_config_payload_t config_payload;
        lcd_ui_draw_line_config_t draw_line_config;
        
        begin
            config_payload = '0;
            draw_line_config = '0;
            draw_line_config.x0 = x0;
            draw_line_config.y0 = y0;
            draw_line_config.x1 = x1;
            draw_line_config.y1 = y1;
            draw_line_config.color = color;
            config_payload[LCD_UI_DRAW_LINE_CONFIG_WIDTH - 1:0] = draw_line_config;
            make_draw_line_config = make_config(LCD_UI_CONFIG_TYPE_DRAW_LINE, config_payload);
        end
    endfunction
    
    function automatic lcd_ui_config_data_t make_clear_config(
            input lcd_ui_color_t color
        );
        
        lcd_ui_config_payload_t config_payload;
        lcd_ui_clear_config_t clear_config;
        
        begin
            config_payload = '0;
            clear_config = '0;
            clear_config.color = color;
            config_payload[LCD_UI_CLEAR_CONFIG_WIDTH - 1:0] = clear_config;
            make_clear_config = make_config(LCD_UI_CONFIG_TYPE_CLEAR, config_payload);
        end
    endfunction
    
    function automatic lcd_ui_config_type_t get_config_type(
            input lcd_ui_config_data_t config_data
        );
        
        begin
            get_config_type = config_data[LCD_UI_CONFIG_TYPE_WIDTH - 1:0];
        end
    endfunction
    
    function automatic lcd_ui_config_payload_t get_config_payload(
            input lcd_ui_config_data_t config_data
        );
        
        begin
            get_config_payload = config_data[LCD_UI_CONFIG_PAYLOAD_LSB +: LCD_UI_CONFIG_PAYLOAD_WIDTH];
        end
    endfunction
endpackage