`default_nettype none

module pwm_duty_ratio_calculator #(
        parameter CNT_WIDTH = 32,
        parameter DUTY_RATIO_WIDTH = 8
    )(
        input logic clk,
        input logic rst,

        input logic[CNT_WIDTH - 1:0] high_level_cnt,
        input logic[CNT_WIDTH - 1:0] total_cnt,

        output logic[DUTY_RATIO_WIDTH - 1:0] duty_ratio
    );

        localparam CALC_WIDTH = CNT_WIDTH + DUTY_RATIO_WIDTH;
        localparam ITERATION_WIDTH = (DUTY_RATIO_WIDTH <= 1) ? 1 : $clog2(DUTY_RATIO_WIDTH);

        logic[CALC_WIDTH - 1:0] remainder;
        logic[CALC_WIDTH - 1:0] divisor;
        logic[CALC_WIDTH - 1:0] denominator;
        logic[DUTY_RATIO_WIDTH - 1:0] quotient;
        logic[ITERATION_WIDTH - 1:0] iteration;
        logic busy;

        logic subtract_enable;
        logic[CALC_WIDTH - 1:0] remainder_next;
        logic[DUTY_RATIO_WIDTH - 1:0] quotient_next;
        logic[CALC_WIDTH - 1:0] round_threshold;

        assign subtract_enable = remainder >= divisor;

        assign remainder_next =
            subtract_enable ?
            remainder - divisor :
            remainder;

        always_comb begin
            quotient_next = quotient << 1;
            quotient_next[0] = subtract_enable;
        end

        assign round_threshold =
            (denominator >> 1) +
            {{(CALC_WIDTH - 1){1'b0}}, denominator[0]};

        always_ff @(posedge clk) begin
            if(rst) begin
                remainder <= '0;
                divisor <= '0;
                denominator <= '0;
                quotient <= '0;
                iteration <= '0;
                duty_ratio <= '0;
                busy <= 1'b0;
            end
            else if(!busy) begin
                if(total_cnt == '0) begin
                    duty_ratio <= '0;
                end
                else if(high_level_cnt >= total_cnt) begin
                    duty_ratio <= {DUTY_RATIO_WIDTH{1'b1}};
                end
                else begin
                    remainder <=
                        {high_level_cnt, {DUTY_RATIO_WIDTH{1'b0}}} -
                        {{DUTY_RATIO_WIDTH{1'b0}}, high_level_cnt};

                    denominator <=
                        {{DUTY_RATIO_WIDTH{1'b0}}, total_cnt};

                    divisor <=
                        {{DUTY_RATIO_WIDTH{1'b0}}, total_cnt}
                        << (DUTY_RATIO_WIDTH - 1);

                    quotient <= '0;
                    iteration <= '0;
                    busy <= 1'b1;
                end
            end
            else begin
                remainder <= remainder_next;
                quotient <= quotient_next;

                if(iteration >= (DUTY_RATIO_WIDTH - 1)) begin
                    if(remainder_next >= round_threshold) begin
                        duty_ratio <= quotient_next + 1'b1;
                    end
                    else begin
                        duty_ratio <= quotient_next;
                    end

                    busy <= 1'b0;
                end
                else begin
                    divisor <= divisor >> 1;
                    iteration <= iteration + 1'b1;
                end
            end
        end
endmodule