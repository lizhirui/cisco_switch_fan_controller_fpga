`default_nettype none

module cisco_fan_fb_freq_lut #(
        parameter DUTY_RATIO_WIDTH = 8,
        parameter FREQ_DIVIDE_WIDTH = 26,
        parameter RPM_WIDTH = 14
    )(
        input logic clk,

        input logic[DUTY_RATIO_WIDTH - 1:0] pwm_duty_ratio_a,
        input logic[DUTY_RATIO_WIDTH - 1:0] pwm_duty_ratio_b,
        output logic[FREQ_DIVIDE_WIDTH - 1:0] freq_divide_a,
        output logic[FREQ_DIVIDE_WIDTH - 1:0] freq_divide_b,
        output logic[RPM_WIDTH - 1:0] rpm_a,
        output logic[RPM_WIDTH - 1:0] rpm_b
    );

    localparam LUT_DATA_WIDTH = FREQ_DIVIDE_WIDTH + RPM_WIDTH;

    (* romstyle = "M9K" *)logic[LUT_DATA_WIDTH - 1:0] fan_fb_lut[0:(1 << DUTY_RATIO_WIDTH) - 1];

    initial begin
        $readmemh("cisco_fan_fb_freq_lut.hex", fan_fb_lut);
    end

    always_ff @(posedge clk) begin
        {rpm_a, freq_divide_a} <= fan_fb_lut[pwm_duty_ratio_a];
        {rpm_b, freq_divide_b} <= fan_fb_lut[pwm_duty_ratio_b];
    end
endmodule