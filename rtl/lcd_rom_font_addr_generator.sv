`default_nettype none

module lcd_rom_font_addr_generator #(
        parameter CHAR_DATA_WIDTH = 8,
        parameter ADDR_WIDTH = 24
    )(
        input logic[CHAR_DATA_WIDTH - 1:0] cur_char,
        input logic[CHAR_DATA_WIDTH - 1:0] next_char,
        input logic next_char_valid,
        output logic[ADDR_WIDTH - 1:0] addr,
        output logic char_inc2
    );

    always_comb begin
        if((cur_char >= 'h20) && (cur_char <= 'h7e)) begin
            addr = (cur_char - 'h20) * 'd16 + 'h3cf80;
            char_inc2 = 1'b0;
        end
        else if((cur_char >= 'ha1) && (cur_char <= 'ha3) && next_char_valid && (next_char >= 'ha1) && (next_char <= 'hfe)) begin
            addr = ((cur_char - 'ha1) * 94 + (next_char - 'ha1)) * 'd32;
            char_inc2 = 1'b1;
        end
        else if((cur_char >= 'hb0) && (cur_char <= 'hf7) && next_char_valid && (next_char >= 'ha1) && (next_char <= 'hfe)) begin
            addr = (((cur_char - 'hb0) * 94) + (next_char - 'ha1) + 'd846) * 'd32;
            char_inc2 = 1'b1;
        end
        else begin
            addr = 'h3cf80;
            char_inc2 = 1'b0;
        end
    end
endmodule