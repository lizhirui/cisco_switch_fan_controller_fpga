`default_nettype none

module multi_pwm_generator #(
        parameter CLK_FREQ = 50000000,
        parameter PWM_FREQ = 200000,
        parameter PWM_NUM = 8,
        parameter DUTY_RATIO_WIDTH = 8,
        parameter ASSERT_LEVEL = 1'b0
    )(
        input logic clk,
        input logic rst,
        input logic[DUTY_RATIO_WIDTH - 1:0] duty_ratio[0:PWM_NUM - 1],
        output logic[PWM_NUM - 1:0] out
    );

    localparam PWM_PERIOD = CLK_FREQ / PWM_FREQ;
    localparam PWM_PERIOD_COUNTER_WIDTH = (PWM_PERIOD <= 1) ? 1 : $clog2(PWM_PERIOD);
    localparam PWM_LEVEL_NUM = 1 << DUTY_RATIO_WIDTH;
    localparam PWM_RAMP_EXTRA = PWM_LEVEL_NUM - PWM_PERIOD;

    localparam logic[PWM_PERIOD_COUNTER_WIDTH - 1:0] PWM_PERIOD_COUNTER_MAX = PWM_PERIOD_COUNTER_WIDTH'(PWM_PERIOD - 1);
    localparam logic[DUTY_RATIO_WIDTH - 1:0] PWM_RAMP_START = DUTY_RATIO_WIDTH'((PWM_LEVEL_NUM + PWM_PERIOD - 1) / PWM_PERIOD);
    localparam logic[PWM_PERIOD_COUNTER_WIDTH - 1:0] PWM_RAMP_ERROR_START = PWM_PERIOD_COUNTER_WIDTH'(PWM_RAMP_EXTRA);
    localparam logic[PWM_PERIOD_COUNTER_WIDTH - 1:0] PWM_RAMP_ERROR_THRESHOLD = PWM_PERIOD_COUNTER_WIDTH'(PWM_PERIOD - PWM_RAMP_EXTRA);

    logic[PWM_PERIOD_COUNTER_WIDTH - 1:0] period_counter;
    logic[DUTY_RATIO_WIDTH - 1:0] ramp_threshold;
    logic[PWM_PERIOD_COUNTER_WIDTH - 1:0] ramp_error;

    always_ff @(posedge clk) begin
        if(rst) begin
            period_counter <= '0;
            ramp_threshold <= PWM_RAMP_START;
            ramp_error <= PWM_RAMP_ERROR_START;
        end
        else if(period_counter == PWM_PERIOD_COUNTER_MAX) begin
            period_counter <= '0;
            ramp_threshold <= PWM_RAMP_START;
            ramp_error <= PWM_RAMP_ERROR_START;
        end
        else begin
            period_counter <= period_counter + 1'b1;

            if(&ramp_threshold) begin
                ramp_threshold <= ramp_threshold;
            end
            else if(ramp_error > PWM_RAMP_ERROR_THRESHOLD) begin
                ramp_threshold <= ramp_threshold + 2'd2;
                ramp_error <= ramp_error - PWM_RAMP_ERROR_THRESHOLD;
            end
            else begin
                ramp_threshold <= ramp_threshold + 1'b1;
                ramp_error <= ramp_error + PWM_PERIOD_COUNTER_WIDTH'(PWM_RAMP_EXTRA);
            end
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            out <= {PWM_NUM{~ASSERT_LEVEL}};
        end
        else begin
            for(integer i = 0;i < PWM_NUM;i = i + 1) begin
                if(&duty_ratio[i]) begin
                    out[i] <= ASSERT_LEVEL;
                end
                else if(duty_ratio[i] >= ramp_threshold) begin
                    out[i] <= ASSERT_LEVEL;
                end
                else begin
                    out[i] <= ~ASSERT_LEVEL;
                end
            end
        end
    end
endmodule