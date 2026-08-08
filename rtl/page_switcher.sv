`default_nettype none

import lcd_ui_page_config_pkg::*;

module page_switcher(
        input logic[PAGE_ID_WIDTH - 1:0] page_id,
        output logic[PAGE_ID_WIDTH - 1:0] page_id_wdata,
        output logic page_id_we,
        
        input logic key_page_prev_pulse,
        input logic key_page_next_pulse,
        
        input logic[PAGE_ID_WIDTH - 1:0] reg_page_id_wdata,
        input logic reg_page_id_we
    );
    
    always_comb begin
        page_id_wdata = '0;
        page_id_we = 1'b0;
        
        if((page_id < unsigned'(USER_PAGE_NUM)) && key_page_prev_pulse) begin
            if(page_id == '0) begin
                page_id_wdata = unsigned'(USER_PAGE_NUM - 'b1);
            end
            else begin
                page_id_wdata = unsigned'(page_id - 'b1);
            end
            
            page_id_we = 1'b1;
        end
        else if((page_id < unsigned'(USER_PAGE_NUM)) && key_page_next_pulse) begin
            if(page_id == unsigned'(USER_PAGE_NUM - 'b1)) begin
                page_id_wdata = '0;
            end
            else begin
                page_id_wdata = unsigned'(page_id + 'b1);
            end
            
            page_id_we = 1'b1;
        end
        else if((reg_page_id_wdata < unsigned'(USER_PAGE_NUM)) && reg_page_id_we) begin
            page_id_wdata = reg_page_id_wdata;
            page_id_we = 1'b1;
        end
    end
endmodule