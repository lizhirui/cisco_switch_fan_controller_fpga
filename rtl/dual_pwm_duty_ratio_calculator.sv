`default_nettype none

module dual_pwm_duty_ratio_calculator #(
        parameter CNT_WIDTH = 16,
        parameter DUTY_RATIO_WIDTH = 8
    )(
        input logic clk,
        input logic rst,
        input logic[CNT_WIDTH - 1:0] high_level_cnt_a,
        input logic[CNT_WIDTH - 1:0] total_cnt_a,
        input logic[CNT_WIDTH - 1:0] high_level_cnt_b,
        input logic[CNT_WIDTH - 1:0] total_cnt_b,
        output logic[DUTY_RATIO_WIDTH - 1:0] duty_ratio_a,
        output logic[DUTY_RATIO_WIDTH - 1:0] duty_ratio_b
    );

    localparam CALC_WIDTH = CNT_WIDTH + DUTY_RATIO_WIDTH;
    localparam ITERATION_WIDTH = (DUTY_RATIO_WIDTH <= 1) ? 1 : $clog2(DUTY_RATIO_WIDTH);

    logic channel;
    logic busy;
    logic[CNT_WIDTH - 1:0] high_level_cnt_selected;
    logic[CNT_WIDTH - 1:0] total_cnt_selected;
    logic[CALC_WIDTH - 1:0] remainder;
    logic[CALC_WIDTH - 1:0] divisor;
    logic[CALC_WIDTH - 1:0] denominator;
    logic[CALC_WIDTH - 1:0] remainder_next;
    logic[CALC_WIDTH - 1:0] round_threshold;
    logic[DUTY_RATIO_WIDTH - 1:0] quotient;
    logic[DUTY_RATIO_WIDTH - 1:0] quotient_next;
    logic[DUTY_RATIO_WIDTH - 1:0] duty_ratio_next;
    logic[ITERATION_WIDTH - 1:0] iteration;
    logic subtract_enable;

    assign high_level_cnt_selected = channel ? high_level_cnt_b : high_level_cnt_a;
    assign total_cnt_selected = channel ? total_cnt_b : total_cnt_a;
    assign subtract_enable = remainder >= divisor;
    assign remainder_next = subtract_enable ? remainder - divisor : remainder;
    assign round_threshold = (denominator >> 1) + denominator[0];
    assign duty_ratio_next = (remainder_next >= round_threshold) ? quotient_next + 1'b1 : quotient_next;

    always_comb begin
        quotient_next = quotient << 1;
        quotient_next[0] = subtract_enable;
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            channel <= 1'b0;
            busy <= 1'b0;
            remainder <= '0;
            divisor <= '0;
            denominator <= '0;
            quotient <= '0;
            iteration <= '0;
            duty_ratio_a <= '0;
            duty_ratio_b <= '0;
        end
        else if(!busy) begin
            if(total_cnt_selected == '0) begin
                if(channel) begin
                    duty_ratio_b <= '0;
                end
                else begin
                    duty_ratio_a <= '0;
                end

                channel <= ~channel;
            end
            else if(high_level_cnt_selected >= total_cnt_selected) begin
                if(channel) begin
                    duty_ratio_b <= {DUTY_RATIO_WIDTH{1'b1}};
                end
                else begin
                    duty_ratio_a <= {DUTY_RATIO_WIDTH{1'b1}};
                end

                channel <= ~channel;
            end
            else begin
                remainder <= {high_level_cnt_selected, {DUTY_RATIO_WIDTH{1'b0}}} - {{DUTY_RATIO_WIDTH{1'b0}}, high_level_cnt_selected};
                denominator <= {{DUTY_RATIO_WIDTH{1'b0}}, total_cnt_selected};
                divisor <= {{DUTY_RATIO_WIDTH{1'b0}}, total_cnt_selected} << (DUTY_RATIO_WIDTH - 1);
                quotient <= '0;
                iteration <= '0;
                busy <= 1'b1;
            end
        end
        else begin
            remainder <= remainder_next;
            quotient <= quotient_next;

            if(iteration >= DUTY_RATIO_WIDTH - 1) begin
                if(channel) begin
                    duty_ratio_b <= duty_ratio_next;
                end
                else begin
                    duty_ratio_a <= duty_ratio_next;
                end

                channel <= ~channel;
                busy <= 1'b0;
            end
            else begin
                divisor <= divisor >> 1;
                iteration <= iteration + 1'b1;
            end
        end
    end
endmodule