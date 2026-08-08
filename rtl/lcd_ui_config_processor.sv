`default_nettype none

import lcd_ui_config_pkg::*;
import lcd_ui_page_config_pkg::*;

module lcd_ui_config_processor #(
        parameter CONFIG_ADDR_WIDTH = 4
    )(
        input logic clk,
        input logic rst,
        
        input logic start,
        output logic busy,
        
        input logic[PAGE_ID_WIDTH - 1:0] page_id_in,
        input logic page_id_in_valid,
        output logic[PAGE_ID_WIDTH - 1:0] page_id,
        
        output logic[CONFIG_ADDR_WIDTH - 1:0] page_config_addr,
        input lcd_ui_config_data_t page_config_data,
        
        output logic config_start,
        input logic config_busy,
        output lcd_ui_config_data_t config_data
    );
    
    localparam STATE_WIDTH = 2;
    localparam logic[STATE_WIDTH - 1:0] STATE_IDLE = STATE_WIDTH'('d0);
    localparam logic[STATE_WIDTH - 1:0] STATE_CONFIG_WAIT = STATE_WIDTH'('d1);
    localparam logic[STATE_WIDTH - 1:0] STATE_CONFIG_START = STATE_WIDTH'('d2);
    localparam logic[STATE_WIDTH - 1:0] STATE_CONFIG_BUSY = STATE_WIDTH'('d3);
    
    logic[STATE_WIDTH - 1:0] cur_state;
    logic[STATE_WIDTH - 1:0] next_state;
    
    lcd_ui_config_type_t cur_config_type;
    logic[PAGE_ID_WIDTH - 1:0] page_id_loaded;
    
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
                    next_state = STATE_CONFIG_WAIT;
                end
            end
            
            STATE_CONFIG_WAIT: begin
                next_state = STATE_CONFIG_START;
            end
            
            STATE_CONFIG_START: begin
                next_state = STATE_CONFIG_BUSY;
            end
            
            STATE_CONFIG_BUSY: begin
                if(!config_busy) begin
                    if(cur_config_type == LCD_UI_CONFIG_TYPE_FRAME_END) begin
                        next_state = STATE_IDLE;
                    end
                    else begin
                        next_state = STATE_CONFIG_WAIT;
                    end
                end
            end
        endcase
    end
    
    assign busy = (cur_state != STATE_IDLE) ? 1'b1 : 1'b0;
    
    always_ff @(posedge clk) begin
        if(rst) begin
            page_id <= '0;
        end
        else if((cur_state != next_state) && (next_state == STATE_IDLE)) begin
            page_id <= page_id_loaded;
        end
    end
        
    always_ff @(posedge clk) begin
        if(rst) begin
            page_config_addr <= '0;
        end
        else if((cur_state == STATE_IDLE) && (next_state != STATE_IDLE)) begin
            page_config_addr <= '0;
        end
        else if((cur_state == STATE_CONFIG_BUSY) && (next_state == STATE_CONFIG_WAIT)) begin
            page_config_addr <= page_config_addr + 'b1;
        end
    end
    
    assign config_start = (cur_state == STATE_CONFIG_START) ? 1'b1 : 1'b0;
    assign config_data = page_config_data;
    assign cur_config_type = get_config_type(page_config_data);
    
    always_ff @(posedge clk) begin
        if(rst) begin
            page_id_loaded <= PAGE_CISCO_ID;
        end
        else if(page_id_in_valid) begin
            page_id_loaded <= page_id_in;
        end
    end
endmodule