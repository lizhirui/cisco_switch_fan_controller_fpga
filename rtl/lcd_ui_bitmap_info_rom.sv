`default_nettype none

import lcd_ui_config_pkg::*;
import lcd_ui_bitmap_pkg::*;

module lcd_ui_bitmap_info_rom(
        input lcd_ui_bitmap_id_t bitmap_id,
        output lcd_ui_bitmap_info_t bitmap_info
    );
    
    always_comb begin
        bitmap_info = '0;
        
        case(bitmap_id)
            LCD_UI_BITMAP_ID_TEST_X_BOX: begin
                bitmap_info.base_addr = 'd0;
                bitmap_info.width = 'd16;
                bitmap_info.height = 'd16;
            end
        endcase
    end
endmodule