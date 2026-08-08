`default_nettype none

module fan_rpm_calculator #(
        parameter CLK_FREQ = 50000000,
        parameter PPR = 2,
        parameter CNT_WIDTH = 32,
        parameter RPM_WIDTH = 17
    )(
        input logic clk,
        input logic rst,

        input logic[CNT_WIDTH - 1:0] total_cnt,
        input logic period_valid,
        output logic[RPM_WIDTH - 1:0] rpm
    );

    localparam PPR_WIDTH = (PPR <= 1) ? 1 : $clog2(PPR + 1);
    localparam CALC_WIDTH = CNT_WIDTH + PPR_WIDTH + RPM_WIDTH;
    localparam ITERATION_WIDTH = (RPM_WIDTH <= 1) ? 1 : $clog2(RPM_WIDTH);
    localparam logic[CALC_WIDTH - 1:0] RPM_NUMERATOR = CLK_FREQ * 64'd60;

    logic[CALC_WIDTH - 1:0] denominator_input;
    logic[CALC_WIDTH - 1:0] denominator;
    logic[CALC_WIDTH - 1:0] divisor;
    logic[CALC_WIDTH - 1:0] remainder;
    logic[CALC_WIDTH - 1:0] remainder_next;
    logic[CALC_WIDTH - 1:0] round_threshold;
    logic[RPM_WIDTH - 1:0] quotient;
    logic[RPM_WIDTH - 1:0] quotient_next;
    logic[ITERATION_WIDTH - 1:0] iteration;
    logic running;
    logic subtract_enable;
    logic overflow;

    assign denominator_input = {{(CALC_WIDTH - CNT_WIDTH){1'b0}}, total_cnt} * PPR;
    assign subtract_enable = remainder >= divisor;
    assign overflow = RPM_NUMERATOR >= (denominator_input << RPM_WIDTH);
    assign round_threshold = (denominator >> 1) + denominator[0];

    always_comb begin
        remainder_next = remainder;
        quotient_next = quotient << 1;
        quotient_next[0] = 1'b0;

        if(subtract_enable) begin
            remainder_next = remainder - divisor;
            quotient_next[0] = 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            denominator <= '0;
            divisor <= '0;
            remainder <= '0;
            quotient <= '0;
            iteration <= '0;
            rpm <= '0;
            running <= 1'b0;
        end
        else if(!period_valid || (total_cnt == '0)) begin
            rpm <= '0;
            running <= 1'b0;
        end
        else if(!running) begin
            if(overflow) begin
                rpm <= {RPM_WIDTH{1'b1}};
            end
            else begin
                denominator <= denominator_input;
                divisor <= denominator_input << (RPM_WIDTH - 1);
                remainder <= RPM_NUMERATOR;
                quotient <= '0;
                iteration <= '0;
                running <= 1'b1;
            end
        end
        else begin
            remainder <= remainder_next;
            quotient <= quotient_next;

            if(iteration >= (RPM_WIDTH - 1)) begin
                if(remainder_next >= round_threshold) begin
                    if(&quotient_next) begin
                        rpm <= quotient_next;
                    end
                    else begin
                        rpm <= quotient_next + 1'b1;
                    end
                end
                else begin
                    rpm <= quotient_next;
                end

                running <= 1'b0;
            end
            else begin
                divisor <= divisor >> 1;
                iteration <= iteration + 1'b1;
            end
        end
    end
endmodule