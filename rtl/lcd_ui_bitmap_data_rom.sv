`default_nettype none

import lcd_ui_bitmap_pkg::*;

module lcd_ui_bitmap_data_rom(
        input logic clk,
        input lcd_ui_bitmap_rom_addr_t addr,
        output lcd_ui_bitmap_data_t data
    );
    
    always_ff @(posedge clk) begin
        case(addr)
            'd0: data <= 8'hff;
            'd1: data <= 8'hff;
            
            'd2: data <= 8'h03;
            'd3: data <= 8'hc0;
            
            'd4: data <= 8'h05;
            'd5: data <= 8'ha0;
            
            'd6: data <= 8'h09;
            'd7: data <= 8'h90;
            
            'd8: data <= 8'h11;
            'd9: data <= 8'h88;
            
            'd10: data <= 8'h21;
            'd11: data <= 8'h84;
            
            'd12: data <= 8'h41;
            'd13: data <= 8'h82;
            
            'd14: data <= 8'h81;
            'd15: data <= 8'h81;
            
            'd16: data <= 8'h81;
            'd17: data <= 8'h81;
            
            'd18: data <= 8'h41;
            'd19: data <= 8'h82;
            
            'd20: data <= 8'h21;
            'd21: data <= 8'h84;
            
            'd22: data <= 8'h11;
            'd23: data <= 8'h88;
            
            'd24: data <= 8'h09;
            'd25: data <= 8'h90;
            
            'd26: data <= 8'h05;
            'd27: data <= 8'ha0;
            
            'd28: data <= 8'h03;
            'd29: data <= 8'hc0;
            
            'd30: data <= 8'hff;
            'd31: data <= 8'hff;
            
            default: data <= '0;
        endcase
    end
    
endmodule