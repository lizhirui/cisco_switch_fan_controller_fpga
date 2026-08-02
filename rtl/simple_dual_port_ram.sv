`default_nettype none

module simple_dual_port_ram #(
        parameter ADDR_WIDTH = 8,
        parameter DATA_WIDTH = 8
    )(
        input logic clk,
        input logic[ADDR_WIDTH - 1:0] waddr,
        input logic[DATA_WIDTH - 1:0] wdata,
        input logic we,
        input logic[ADDR_WIDTH - 1:0] raddr,
        output logic[DATA_WIDTH - 1:0] rdata
    );

    (* ramstyle = "M9K" *)logic[DATA_WIDTH - 1:0] mem[0:2 ** ADDR_WIDTH - 1];

    always_ff @(posedge clk) begin
        if(we) begin
            mem[waddr] <= wdata;
        end
    end

    always_ff @(posedge clk) begin
        rdata <= mem[raddr];
    end
endmodule