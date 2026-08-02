`default_nettype none

module signal_syncer #(
        parameter WIDTH = 1,
        parameter STAGE = 4,
        parameter RESET_VALUE = 1'b1
    )(
        input logic clk,
        input logic rst,
        input logic[WIDTH - 1:0] din,
        output logic[WIDTH - 1:0] dout
    );

    logic[WIDTH - 1:0] din_sync[0:STAGE - 1];
    genvar i;

    generate
        for(i = 0;i < STAGE;i++) begin: din_sync_gen
            always_ff @(posedge clk) begin
                if(rst) begin
                    din_sync[i] <= RESET_VALUE ? '1 : '0;
                end
                else if(i == 0) begin
                    din_sync[i] <= din;
                end
                else begin
                    din_sync[i] <= din_sync[i - 1];
                end
            end
        end
    endgenerate
    
    assign dout = din_sync[STAGE - 1];
endmodule