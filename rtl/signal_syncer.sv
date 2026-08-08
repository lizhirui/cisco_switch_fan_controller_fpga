`default_nettype none

module signal_syncer #(
        parameter WIDTH = 1,
        parameter STAGE = 4,
        parameter RESET_VALUE = 1'b1
    )(
        input logic clk,
        input logic rst,
        input logic[WIDTH - 1:0] din,
        output logic[WIDTH - 1:0] dout,
        output logic dout_valid
    );
    
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)logic[WIDTH - 1:0] din_sync_0;
    logic[WIDTH - 1:0] din_sync[1:STAGE - 1];
    logic[STAGE - 1:0] sync_flag;
    genvar i;

    generate
        for(i = 0;i < STAGE;i++) begin: din_sync_gen
            always_ff @(posedge clk) begin
                if(i == 0) begin
                    if(rst) begin
                        din_sync_0 <= RESET_VALUE;
                        sync_flag[i] <= 1'b0;
                    end
                    else begin
                        din_sync_0 <= din;
                        sync_flag[i] <= 1'b1;
                    end
                end
                else begin
                    if(rst) begin
                        din_sync[i] <= RESET_VALUE;
                        sync_flag[i] <= 1'b0;
                    end
                    else if(i == 1) begin
                        din_sync[i] <= din_sync_0;
                        sync_flag[i] <= sync_flag[i - 1];
                    end
                    else begin
                        din_sync[i] <= din_sync[i - 1];
                        sync_flag[i] <= sync_flag[i - 1];
                    end
                end
            end
        end
    endgenerate
    
    assign dout = din_sync[STAGE - 1];
    assign dout_valid = sync_flag[STAGE- 1];
endmodule