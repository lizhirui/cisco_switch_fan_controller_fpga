`default_nettype none

module reset_synchronizer #(
        parameter SYNC_STAGE = 4
    )(
        input logic clk,
        input logic rst_n,
        output logic rst
    );

    logic[SYNC_STAGE - 1:0] reset_sync_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            reset_sync_reg <= '1;
        end
        else begin
            reset_sync_reg <= {reset_sync_reg[SYNC_STAGE - 2:0], 1'b0};
        end
    end

    assign rst = reset_sync_reg[SYNC_STAGE - 1];
endmodule