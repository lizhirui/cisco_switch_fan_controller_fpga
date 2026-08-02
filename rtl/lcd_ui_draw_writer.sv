`default_nettype none

import lcd_ui_config_pkg::*;

module lcd_ui_draw_writer #(
        parameter LCD_PIXEL_LINE_NUM = 64,
        parameter LCD_PIXEL_COL_NUM = 128,
        parameter VRAM_ADDR_WIDTH = 10,
        parameter VRAM_DATA_WIDTH = 8
    )(
        input logic clk,
        input logic rst,
        
        input logic start,
        output logic busy,
        input lcd_ui_config_data_t config_data,
        
        output logic[VRAM_ADDR_WIDTH - 1:0] vwc_raddr,
        input logic[VRAM_DATA_WIDTH - 1:0] vwc_rdata,
        output logic[VRAM_ADDR_WIDTH - 1:0] vwc_waddr,
        output logic[VRAM_DATA_WIDTH - 1:0] vwc_wdata,
        output logic vwc_we,
        input logic vwc_busy
    );
    
    localparam VRAM_BYTE_COL_NUM = LCD_PIXEL_COL_NUM / VRAM_DATA_WIDTH;
    localparam VRAM_DEPTH = LCD_PIXEL_LINE_NUM * VRAM_BYTE_COL_NUM;
    localparam logic[VRAM_ADDR_WIDTH - 1:0]VRAM_LAST_ADDR = VRAM_ADDR_WIDTH'(VRAM_DEPTH - 1);
    
    localparam STATE_WIDTH = 2;
    localparam STATE_IDLE = STATE_WIDTH'('d0);
    localparam STATE_WAIT_VWC_IDLE = STATE_WIDTH'('d1);
    localparam STATE_CLEAR_INIT = STATE_WIDTH'('d2);
    localparam STATE_CLEAR_WRITE = STATE_WIDTH'('d3);
    
    logic[STATE_WIDTH - 1:0] cur_state;
    logic[STATE_WIDTH - 1:0] next_state;
    
    lcd_ui_config_data_t config_data_loaded;
    lcd_ui_config_type_t config_type_loaded;
    lcd_ui_clear_config_t clear_config_loaded;
    
    logic[VRAM_ADDR_WIDTH - 1:0] clear_addr;
    
    always_ff @(posedge clk) begin
        if(rst) begin
            cur_state <= STATE_IDLE;
        end
        else begin
            cur_state <= next_state;
        end
    end
    
    always_comb begin
        next_state = cur_state;
        
        case(cur_state)
            STATE_IDLE: begin
                if(start) begin
                    next_state = STATE_WAIT_VWC_IDLE;
                end
            end
            
            STATE_WAIT_VWC_IDLE: begin
                if(!vwc_busy) begin
                    if(config_type_loaded == LCD_UI_CONFIG_TYPE_CLEAR) begin
                        next_state = STATE_CLEAR_INIT;
                    end
                    else begin
                        next_state = STATE_IDLE;
                    end
                end
            end
            
            STATE_CLEAR_INIT: begin
                next_state = STATE_CLEAR_WRITE;
            end
            
            STATE_CLEAR_WRITE: begin
                if(clear_addr == VRAM_LAST_ADDR) begin
                    next_state = STATE_IDLE;
                end
            end
        endcase
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            busy <= 1'b0;
        end
        else if((cur_state == STATE_IDLE) && (next_state != STATE_IDLE)) begin
            busy <= 1'b1;
        end
        else if((cur_state == STATE_IDLE) && (next_state == STATE_IDLE)) begin
            busy <= 1'b0;
        end
    end
    
    assign vwc_raddr = '0;
    assign vwc_waddr = clear_addr;
    assign vwc_wdata = {VRAM_DATA_WIDTH{clear_config_loaded.color}};
    assign vwc_we = (cur_state == STATE_CLEAR_WRITE) ? 1'b1 : 1'b0;
    
    always_ff @(posedge clk) begin
        if(rst) begin
            config_data_loaded <= '0;
        end
        else if((cur_state == STATE_IDLE) && (next_state == STATE_WAIT_VWC_IDLE)) begin
            config_data_loaded <= config_data;
        end
    end
    
    assign config_type_loaded = get_config_type(config_data_loaded);
    assign clear_config_loaded = config_data_loaded[LCD_UI_CONFIG_PAYLOAD_LSB +: LCD_UI_CLEAR_CONFIG_WIDTH];
    
    always_ff @(posedge clk) begin
        if(rst) begin
            clear_addr <= '0;
        end
        else if(cur_state == STATE_CLEAR_INIT) begin
            clear_addr <= '0;
        end
        else if((cur_state == STATE_CLEAR_WRITE) && (next_state == STATE_CLEAR_WRITE)) begin
            clear_addr <= clear_addr + 'b1;
        end
    end
endmodule