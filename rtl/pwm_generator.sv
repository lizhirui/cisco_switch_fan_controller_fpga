`default_nettype none

module pwm_generator #(
        parameter FREQ_DIVIDE_WIDTH = 26,
        parameter DUTY_RATIO_WIDTH = 8,
        parameter ASSERT_LEVEL = 1'b1
    )(
        input logic clk,
        input logic rst,
        input logic[FREQ_DIVIDE_WIDTH - 1:0] freq_divide,
        input logic[DUTY_RATIO_WIDTH - 1:0] duty_ratio,
        output logic out
    );

    localparam DUTY_PRODUCT_WIDTH = FREQ_DIVIDE_WIDTH + DUTY_RATIO_WIDTH;

    logic[FREQ_DIVIDE_WIDTH - 1:0] freq_divide_internal;
    logic[DUTY_RATIO_WIDTH - 1:0] duty_ratio_internal;
    logic[FREQ_DIVIDE_WIDTH - 1:0] period_counter;
    logic[DUTY_PRODUCT_WIDTH - 1:0] duty_product;
    logic[FREQ_DIVIDE_WIDTH - 1:0] duty_count;

    assign duty_product = freq_divide * duty_ratio;

    always_ff @(posedge clk) begin
        if(rst) begin
            freq_divide_internal <= '0;
            duty_ratio_internal <= '0;
            duty_count <= '0;
        end
        else if((freq_divide_internal <= 'b1) || (period_counter >= (freq_divide_internal - 'b1))) begin
            freq_divide_internal <= freq_divide;
            duty_ratio_internal <= duty_ratio;
            duty_count <= duty_product[DUTY_PRODUCT_WIDTH - 1:DUTY_RATIO_WIDTH];
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
            if(duty_ratio_internal == 'b0) begin
                out <= ~ASSERT_LEVEL;
            end
            else begin
                out <= ASSERT_LEVEL;
            end
        end
        else if(duty_ratio_internal == 'b0) begin
            out <= ~ASSERT_LEVEL;
        end
        else if(&duty_ratio_internal) begin
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