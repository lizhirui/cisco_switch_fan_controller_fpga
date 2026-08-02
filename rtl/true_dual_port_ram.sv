`default_nettype none

module true_dual_port_ram #(
        parameter ADDR_WIDTH = 8,
        parameter DATA_WIDTH = 8
    )(
        input logic clk,
        
        input logic[ADDR_WIDTH - 1:0] a_addr,
        input logic[DATA_WIDTH - 1:0] a_wdata,
        input logic a_we,
        output logic[DATA_WIDTH - 1:0] a_rdata,
        
        input logic[ADDR_WIDTH - 1:0] b_addr,
        input logic[DATA_WIDTH - 1:0] b_wdata,
        input logic b_we,
        output logic[DATA_WIDTH - 1:0] b_rdata
    );
    
    localparam DEPTH = 2 ** ADDR_WIDTH;
    
    (* ramstyle = "M9K" *)logic[DATA_WIDTH - 1:0] buffer[0:DEPTH - 1];
    
    always_ff @(posedge clk) begin
        if(a_we) begin
            buffer[a_addr] <= a_wdata;
        end
        
        a_rdata <= buffer[a_addr];
    end
    
    always_ff @(posedge clk) begin
        if(b_we) begin
            buffer[b_addr] <= b_wdata;
        end
        
        b_rdata <= buffer[b_addr];
    end
endmodule