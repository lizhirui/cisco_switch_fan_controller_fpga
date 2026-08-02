`default_nettype none

module clock_enable_generator #(
        parameter CLOCK_FREQUENCY = 50000000,
        parameter ENABLE_FREQUENCY = 1000
    )(
        input logic clk,
        input logic rst,
        output logic enable
    );

    localparam DIVIDE = unsigned'(CLOCK_FREQUENCY / ENABLE_FREQUENCY);
    localparam COUNTER_WIDTH = (DIVIDE <= 1) ? 1 : $clog2(DIVIDE);

    logic[COUNTER_WIDTH - 1:0] counter;
    
    always_ff @(posedge clk) begin
        if(rst) begin
            counter <= '0;
            enable <= 1'b0;
        end
        else if(DIVIDE <= 'b1) begin
            counter <= '0;
            enable <= 1'b1;
        end
        else if(counter >= (DIVIDE - 1'b1)) begin
            counter <= '0;
            enable <= 1'b1;
        end
        else begin
            counter <= counter + 1'b1;
            enable <= 1'b0;
        end
    end

endmodule