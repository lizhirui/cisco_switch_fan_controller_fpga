`default_nettype none

module register_controller #(
        parameter ADDR_WIDTH = 8,
        parameter DATA_WIDTH = 8,
        parameter LCD_BRIGHT_WIDTH = 4,
        parameter PAGE_ID_WIDTH = 4
    )(
        input logic clk,
        input logic rst,
        
        input logic[ADDR_WIDTH - 1:0] addr,
        input logic[DATA_WIDTH - 1:0] wdata,
        input logic we,
        output logic[DATA_WIDTH - 1:0] rdata,
        
        output logic[LCD_BRIGHT_WIDTH - 1:0] bright_wdata,
        output logic bright_we,
        input logic[LCD_BRIGHT_WIDTH - 1:0] bright_rdata,
        
        output logic[PAGE_ID_WIDTH - 1:0] page_id_wdata,
        output logic page_id_we,
        input logic[PAGE_ID_WIDTH - 1:0] page_id_rdata
    );
    
    localparam BRIGHT_ADDR = ADDR_WIDTH'('h80);
    localparam PAGE_ID_ADDR = ADDR_WIDTH'('h81);
    
    always_ff @(posedge clk) begin
        if(rst) begin
            rdata <= '0;
        end
        else begin
            rdata <= '0;
            
            case(addr)
                BRIGHT_ADDR: begin
                    rdata <= bright_rdata;
                end
                
                PAGE_ID_ADDR: begin
                    rdata <= page_id_rdata;
                end
            endcase
        end
    end
    
    assign bright_wdata = wdata;
    assign bright_we = ((addr == BRIGHT_ADDR) && we) ? 1'b1 : 1'b0;
    
    assign page_id_wdata = wdata;
    assign page_id_we = ((addr == PAGE_ID_ADDR) && we) ? 1'b1 : 1'b0;
endmodule