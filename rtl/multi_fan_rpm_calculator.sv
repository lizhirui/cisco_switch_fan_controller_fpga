`default_nettype none

module multi_fan_rpm_calculator #(
        parameter CLK_FREQ = 50000000,
        parameter PPR = 2,
        parameter FAN_NUM = 8,
        parameter CNT_WIDTH = 32,
        parameter RPM_WIDTH = 14
    )(
        input logic clk,
        input logic rst,

        input logic[CNT_WIDTH - 1:0] total_cnt[0:FAN_NUM - 1],
        input logic[FAN_NUM - 1:0] period_valid,
        output logic[RPM_WIDTH - 1:0] rpm[0:FAN_NUM - 1]
    );

    localparam FAN_ID_WIDTH = (FAN_NUM <= 1) ? 1 : $clog2(FAN_NUM);
    localparam PPR_WIDTH = (PPR <= 1) ? 1 : $clog2(PPR + 1);
    localparam DENOMINATOR_WIDTH = CNT_WIDTH + PPR_WIDTH;
    localparam logic[63:0] RPM_NUMERATOR_VALUE = CLK_FREQ * 64'd60;
    localparam NUMERATOR_WIDTH = $clog2(RPM_NUMERATOR_VALUE + 64'd1);
    localparam DIV_WIDTH = (NUMERATOR_WIDTH > DENOMINATOR_WIDTH) ? NUMERATOR_WIDTH : DENOMINATOR_WIDTH;
    localparam ITERATION_WIDTH = (NUMERATOR_WIDTH <= 1) ? 1 : $clog2(NUMERATOR_WIDTH);
    localparam logic[NUMERATOR_WIDTH - 1:0] RPM_NUMERATOR = CLK_FREQ * 60;

    logic[FAN_ID_WIDTH - 1:0] fan_id;
    logic[DENOMINATOR_WIDTH - 1:0] denominator;
    logic[DIV_WIDTH:0] remainder;
    logic[NUMERATOR_WIDTH - 1:0] dividend;
    logic[NUMERATOR_WIDTH - 1:0] quotient;
    logic[ITERATION_WIDTH - 1:0] iteration;
    logic running;
    logic[DIV_WIDTH:0] remainder_shifted;
    logic[DIV_WIDTH:0] remainder_next;
    logic[NUMERATOR_WIDTH - 1:0] quotient_next;
    logic subtract_enable;

    assign remainder_shifted = {remainder[DIV_WIDTH - 1:0], dividend[NUMERATOR_WIDTH - 1]};
    assign subtract_enable = remainder_shifted >= denominator;

    always_comb begin
        remainder_next = remainder_shifted;
        quotient_next = quotient << 1;

        if(subtract_enable) begin
            remainder_next = remainder_shifted - denominator;
            quotient_next[0] = 1'b1;
        end
        else begin
            quotient_next[0] = 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            fan_id <= '0;
            denominator <= '0;
            remainder <= '0;
            dividend <= '0;
            quotient <= '0;
            iteration <= '0;
            running <= 1'b0;

            for(integer i = 0;i < FAN_NUM;i = i + 1) begin
                rpm[i] <= '0;
            end
        end
        else if(!running) begin
            if(!period_valid[fan_id] || (total_cnt[fan_id] == '0)) begin
                rpm[fan_id] <= '0;

                if(fan_id >= FAN_NUM - 1) begin
                    fan_id <= '0;
                end
                else begin
                    fan_id <= fan_id + 1'b1;
                end
            end
            else begin
                denominator <= total_cnt[fan_id] * PPR;
                remainder <= '0;
                dividend <= RPM_NUMERATOR;
                quotient <= '0;
                iteration <= '0;
                running <= 1'b1;
            end
        end
        else begin
            remainder <= remainder_next;
            dividend <= dividend << 1;
            quotient <= quotient_next;

            if(iteration >= NUMERATOR_WIDTH - 1) begin
                if(|quotient_next[NUMERATOR_WIDTH - 1:RPM_WIDTH]) begin
                    rpm[fan_id] <= {RPM_WIDTH{1'b1}};
                end
                else if((remainder_next << 1) >= denominator) begin
                    if(&quotient_next[RPM_WIDTH - 1:0]) begin
                        rpm[fan_id] <= quotient_next[RPM_WIDTH - 1:0];
                    end
                    else begin
                        rpm[fan_id] <= quotient_next[RPM_WIDTH - 1:0] + 1'b1;
                    end
                end
                else begin
                    rpm[fan_id] <= quotient_next[RPM_WIDTH - 1:0];
                end

                running <= 1'b0;

                if(fan_id >= FAN_NUM - 1) begin
                    fan_id <= '0;
                end
                else begin
                    fan_id <= fan_id + 1'b1;
                end
            end
            else begin
                iteration <= iteration + 1'b1;
            end
        end
    end
endmodule