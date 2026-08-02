`default_nettype none

package lcd_ui_bitmap_pkg;
    import lcd_ui_config_pkg::*;
    
    localparam LCD_UI_BITMAP_DATA_WIDTH = 8;
    localparam LCD_UI_BITMAP_ROM_ADDR_WIDTH = 12;
    
    typedef logic[LCD_UI_BITMAP_DATA_WIDTH - 1:0] lcd_ui_bitmap_data_t;
    typedef logic[LCD_UI_BITMAP_ROM_ADDR_WIDTH - 1:0] lcd_ui_bitmap_rom_addr_t;
    
    typedef struct packed
    {
        lcd_ui_bitmap_rom_addr_t base_addr;
        lcd_ui_size_t width;
        lcd_ui_size_t height;
    }lcd_ui_bitmap_info_t;
    
    localparam lcd_ui_bitmap_id_t LCD_UI_BITMAP_ID_TEST_X_BOX = LCD_UI_BITMAP_ID_WIDTH'('d0);
endpackage