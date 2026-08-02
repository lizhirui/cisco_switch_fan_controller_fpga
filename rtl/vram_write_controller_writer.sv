`default_nettype none

import lcd_ui_config_pkg::*;
import lcd_font_stream_pkg::*;

module vram_write_controller_writer #(
        parameter LCD_PIXEL_LINE_NUM = 64,
        parameter LCD_PIXEL_COL_NUM = 128,
        parameter VRAM_ADDR_WIDTH = 10
    )(
        input logic clk,
        input logic rst,

        input lcd_font_stream_data_t wdata,
        input logic wdata_valid,
        output logic wdata_pop,
        
        output logic[VRAM_ADDR_WIDTH - 1:0] vwc_raddr,
        input lcd_font_data_t vwc_rdata,

        output logic[VRAM_ADDR_WIDTH - 1:0] vwc_waddr,
        output lcd_font_data_t vwc_wdata,
        output logic vwc_we,
        input logic vwc_busy,
        
        output logic idle
    );

    localparam VRAM_BYTE_COL_NUM = LCD_PIXEL_COL_NUM / LCD_FONT_DATA_WIDTH;
    localparam VRAM_BYTE_COL_ID_WIDTH = (VRAM_BYTE_COL_NUM <= 1) ? 1 : $clog2(VRAM_BYTE_COL_NUM);
    localparam DATA_OFFSET_WIDTH = (LCD_FONT_DATA_WIDTH <= 1) ? 1 : $clog2(LCD_FONT_DATA_WIDTH);
    localparam ROW_IN_BLOCK_WIDTH = (LCD_FONT_DATA_WIDTH <= 1) ? 1 : $clog2(LCD_FONT_DATA_WIDTH);
    localparam SHIFT_DATA_WIDTH = LCD_FONT_DATA_WIDTH * 2;

    localparam STATE_WIDTH = 3;
    localparam STATE_WAIT_DATA = STATE_WIDTH'('d0);
    localparam STATE_LOW_READ = STATE_WIDTH'('d1);
    localparam STATE_LOW_WAIT = STATE_WIDTH'('d2);
    localparam STATE_LOW_WRITE = STATE_WIDTH'('d3);
    localparam STATE_HIGH_READ = STATE_WIDTH'('d4);
    localparam STATE_HIGH_WAIT = STATE_WIDTH'('d5);
    localparam STATE_HIGH_WRITE = STATE_WIDTH'('d6);
    localparam STATE_DATA_DONE = STATE_WIDTH'('d7);

    logic[STATE_WIDTH - 1:0] cur_state;
    logic[STATE_WIDTH - 1:0] next_state;
    
    logic[1:0] block_id;
    logic[2:0] row_in_block;
    
    logic wide_char;
    logic block_x;
    logic block_y;
    logic last_block;
    
    logic[LCD_UI_X_WIDTH:0] fragment_x;
    logic[LCD_UI_Y_WIDTH:0] fragment_y;
    logic[VRAM_BYTE_COL_ID_WIDTH - 1:0] fragment_byte_x;
    logic[DATA_OFFSET_WIDTH - 1:0] fragment_offset;
    logic fragment_visible;
    logic high_fragment_visible;
    
    lcd_font_data_t color_data;
    logic[SHIFT_DATA_WIDTH - 1:0] shifted_data;
    logic[SHIFT_DATA_WIDTH - 1:0] shifted_mask;
    lcd_font_data_t low_data;
    lcd_font_data_t high_data;
    lcd_font_data_t low_mask;
    lcd_font_data_t high_mask;
    
    logic[VRAM_ADDR_WIDTH - 1:0] low_addr_cal;
    logic[VRAM_ADDR_WIDTH - 1:0] high_addr_cal;
    lcd_font_data_t low_wdata_cal;
    lcd_font_data_t high_wdata_cal;
    
    lcd_font_side_data_t side_data_loaded;
    lcd_font_side_data_t side_data_cur;

    always_ff @(posedge clk) begin
        if(rst) begin
            cur_state <= STATE_WAIT_DATA;
        end
        else begin
            cur_state <= next_state;
        end
    end

    always_comb begin
        next_state = cur_state;

        case(cur_state)
            STATE_WAIT_DATA: begin
                if(wdata_valid && !vwc_busy) begin
                    if(fragment_visible) begin
                        next_state = STATE_LOW_READ;
                    end
                    else begin
                        next_state = STATE_DATA_DONE;
                    end
                end
            end
            
             STATE_LOW_READ: begin
                next_state = STATE_LOW_WAIT;
            end
            
            STATE_LOW_WAIT: begin
                next_state = STATE_LOW_WRITE;
            end
            
            STATE_LOW_WRITE: begin
                if(high_fragment_visible) begin
                    next_state = STATE_HIGH_READ;
                end
                else begin
                    next_state = STATE_DATA_DONE;
                end
            end
            
            STATE_HIGH_READ: begin
                next_state = STATE_HIGH_WAIT;
            end
            
            STATE_HIGH_WAIT: begin
                next_state = STATE_HIGH_WRITE;
            end
            
            STATE_HIGH_WRITE: begin
                next_state = STATE_DATA_DONE;
            end
            
            STATE_DATA_DONE: begin
                next_state = STATE_WAIT_DATA;
            end
        endcase
    end

    assign wdata_pop = (cur_state == STATE_DATA_DONE) ? 1'b1 : 1'b0;
    
    always_ff @(posedge clk) begin
        if(rst) begin
            vwc_raddr <= '0;
        end
        else if((cur_state != STATE_LOW_READ) && (next_state == STATE_LOW_READ)) begin
            vwc_raddr <= low_addr_cal;
        end
        else if((cur_state != STATE_HIGH_READ) && (next_state == STATE_HIGH_READ)) begin
            vwc_raddr <= high_addr_cal;
        end
    end
    
    assign vwc_waddr = vwc_raddr;
    
    always_ff @(posedge clk) begin
        if(rst) begin
            vwc_wdata <= '0;
        end
        else if((cur_state != STATE_LOW_WRITE) && (next_state == STATE_LOW_WRITE)) begin
            vwc_wdata <= low_wdata_cal;
        end
        else if((cur_state != STATE_HIGH_WRITE) && (next_state == STATE_HIGH_WRITE)) begin
            vwc_wdata <= high_wdata_cal;
        end
    end
    
    assign vwc_we = ((cur_state == STATE_LOW_WRITE) || (cur_state == STATE_HIGH_WRITE)) ? 1'b1 : 1'b0;
    assign idle = (cur_state == STATE_WAIT_DATA) ? 1'b1 : 1'b0;

    always_ff @(posedge clk) begin
        if(rst) begin
            block_id <= '0;
            row_in_block <= '0;
        end
        else if(cur_state == STATE_DATA_DONE) begin
            if(row_in_block == (LCD_FONT_DATA_WIDTH - 'b1)) begin
                row_in_block <= '0;
                
                if(last_block) begin
                    block_id <= '0;
                end
                else begin
                    block_id <= block_id + 'b1;
                end
            end
            else begin
                row_in_block <= row_in_block + 'b1;
            end
        end
    end
    
    assign wide_char = (side_data_cur.data_len == 'd32) ? 1'b1 : 1'b0;
    assign block_x = wide_char ? block_id[0] : 1'b0;
    assign block_y = wide_char ? block_id[1] : block_id[0];
    assign last_block = wide_char ? ((block_id == 2'd3) ? 1'b1 : 1'b0) : ((block_id == 2'd1) ? 1'b1 : 1'b0);
    
    assign fragment_x = {1'b0, side_data_cur.char_x} + (block_x ? LCD_FONT_DATA_WIDTH : '0);
    assign fragment_y = {1'b0, side_data_cur.char_y} + (block_y ? LCD_FONT_DATA_WIDTH : '0) + row_in_block;
    assign fragment_byte_x = fragment_x >> DATA_OFFSET_WIDTH;
    assign fragment_offset = fragment_x[DATA_OFFSET_WIDTH - 1:0];
    
    assign fragment_visible = ((fragment_x < LCD_PIXEL_COL_NUM) && (fragment_y < LCD_PIXEL_LINE_NUM)) ? 1'b1 : 1'b0;
    assign high_fragment_visible = (fragment_visible && (fragment_offset != '0) && (fragment_byte_x < (VRAM_BYTE_COL_NUM - 'b1))) ? 1'b1 : 1'b0;
    
    assign color_data = {LCD_FONT_DATA_WIDTH{side_data_cur.char_color}};
assign shifted_data = {{LCD_FONT_DATA_WIDTH{1'b0}}, color_data} << fragment_offset;
assign shifted_mask = {{LCD_FONT_DATA_WIDTH{1'b0}}, wdata.data} << fragment_offset;
    
    assign low_data = shifted_data[LCD_FONT_DATA_WIDTH - 1:0];
    assign high_data = shifted_data[SHIFT_DATA_WIDTH - 1:LCD_FONT_DATA_WIDTH];
    assign low_mask = shifted_mask[LCD_FONT_DATA_WIDTH - 1:0];
    assign high_mask = shifted_mask[SHIFT_DATA_WIDTH - 1:LCD_FONT_DATA_WIDTH];
    
    assign low_addr_cal = fragment_y * VRAM_BYTE_COL_NUM + fragment_byte_x;
    assign high_addr_cal = low_addr_cal + 'b1;
    
    assign low_wdata_cal = (vwc_rdata & ~low_mask) | (low_data & low_mask);
    assign high_wdata_cal = (vwc_rdata & ~high_mask) | (high_data & high_mask);
    
    always_ff @(posedge clk) begin
        if(rst) begin
            side_data_loaded <= '0;
        end
        else if((cur_state == STATE_WAIT_DATA) && (next_state != STATE_WAIT_DATA) && (block_id == '0) && (row_in_block == '0)) begin
            side_data_loaded <= wdata.side_data;
        end
    end
    
    assign side_data_cur = ((block_id == '0) && (row_in_block == '0)) ? wdata.side_data : side_data_loaded;
endmodule