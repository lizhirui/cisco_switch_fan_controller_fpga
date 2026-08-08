`default_nettype none

module square_wave_generator #(
        parameter FREQ_DIVIDE_WIDTH = 26,
        parameter ASSERT_LEVEL = 1'b1
    )(
        input logic clk,
        input logic rst,
        input logic[FREQ_DIVIDE_WIDTH - 1:0] freq_divide,
        output logic out
    );

    logic[FREQ_DIVIDE_WIDTH - 1:0] freq_divide_internal;
    logic[FREQ_DIVIDE_WIDTH - 1:0] period_counter;
    logic[FREQ_DIVIDE_WIDTH - 1:0] duty_count;

    always_ff @(posedge clk) begin
        if(rst) begin
            freq_divide_internal <= '0;
            duty_count <= '0;
        end
        else if((freq_divide_internal <= 'b1) || (period_counter >= (freq_divide_internal - 'b1))) begin
            freq_divide_internal <= freq_divide;
            duty_count <= freq_divide >> 1;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            period_counter <= '0;
        end
        else if(freq_divide_internal <= 'b1) begin
            period_counter <= '0;
        end
        else if(period_counter >= (freq_divide_internal - 'b1)) begin
            period_counter <= '0;
        end
        else begin
            period_counter <= period_counter + 'b1;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            out <= ~ASSERT_LEVEL;
        end
        else if(freq_divide_internal <= 'b1) begin
            out <= ASSERT_LEVEL;
        end
        else if(period_counter < duty_count) begin
            out <= ASSERT_LEVEL;
        end
        else begin
            out <= ~ASSERT_LEVEL;
        end
    end
endmodule