`default_nettype none

module single_port_ram #(
        parameter ADDR_WIDTH = 8,
        parameter DATA_WIDTH = 8
    )(
        input logic clk,
        input logic[ADDR_WIDTH - 1:0] addr,
        input logic[DATA_WIDTH - 1:0] din,
        input logic we,
        output logic[DATA_WIDTH - 1:0] dout
    );

    (* ramstyle = "M9K" *)logic[DATA_WIDTH - 1:0] mem[0:2 ** ADDR_WIDTH - 1];

    always_ff @(posedge clk) begin
        if(we) begin
            mem[addr] <= din;
        end
    end

    always_ff @(posedge clk) begin
        dout <= mem[addr];
    end
endmodule