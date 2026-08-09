`default_nettype none

module cisco_interface_simulator #(
        parameter CLK_FREQ = 50000000,
        parameter PWM_DUTY_RATIO_WIDTH = 8,
        parameter RPM_WIDTH = 14
    )(
        input logic clk,
        input logic rst,
        
        input logic cisco_fan1234_pwm,
        input logic cisco_fan5678_pwm,
        output logic[7:0] cisco_fan_fb,
        
        output logic[PWM_DUTY_RATIO_WIDTH - 1:0] cisco_fan1234_pwm_duty_ratio,
        output logic[PWM_DUTY_RATIO_WIDTH - 1:0] cisco_fan5678_pwm_duty_ratio,
        output logic[RPM_WIDTH - 1:0] cisco_fan1234_rpm,
        output logic[RPM_WIDTH - 1:0] cisco_fan5678_rpm
    );
    
    localparam CNT_WIDTH = 16;
    localparam FREQ_DIVIDE_WIDTH = 26;
    
    logic[CNT_WIDTH - 1:0] fan1234_pwm_high_level_cnt;
    logic[CNT_WIDTH - 1:0] fan1234_pwm_total_cnt;
    logic[CNT_WIDTH - 1:0] fan5678_pwm_high_level_cnt;
    logic[CNT_WIDTH - 1:0] fan5678_pwm_total_cnt;
    logic[FREQ_DIVIDE_WIDTH - 1:0] fan1234_pwm_freq_divide;
    logic[FREQ_DIVIDE_WIDTH - 1:0] fan5678_pwm_freq_divide; 
    logic fan1234_fb;
    logic fan5678_fb;
    
    genvar i;
    
    signal_measurer #(
        .CNT_WIDTH(CNT_WIDTH),
        .TIMEOUT_CNT(CLK_FREQ / 1000)
    )signal_measurer_fan1234_pwm_inst(
        .clk(clk),
        .rst(rst),
        .signal(~cisco_fan1234_pwm),
        .high_level_cnt(fan1234_pwm_high_level_cnt),
        .low_level_cnt(),
        .total_cnt(fan1234_pwm_total_cnt),
        .period_valid()
    );
    
    signal_measurer #(
        .CNT_WIDTH(CNT_WIDTH),
        .TIMEOUT_CNT(CLK_FREQ / 1000)
    )signal_measurer_fan5678_pwm_inst(
        .clk(clk),
        .rst(rst),
        .signal(~cisco_fan5678_pwm),
        .high_level_cnt(fan5678_pwm_high_level_cnt),
        .low_level_cnt(),
        .total_cnt(fan5678_pwm_total_cnt),
        .period_valid()
    );
    
    dual_pwm_duty_ratio_calculator #(
        .CNT_WIDTH(CNT_WIDTH),
        .DUTY_RATIO_WIDTH(PWM_DUTY_RATIO_WIDTH)
    )dual_pwm_duty_ratio_calculator_inst(
        .clk(clk),
        .rst(rst),
        .high_level_cnt_a(fan1234_pwm_high_level_cnt),
        .total_cnt_a(fan1234_pwm_total_cnt),
        .high_level_cnt_b(fan5678_pwm_high_level_cnt),
        .total_cnt_b(fan5678_pwm_total_cnt),
        .duty_ratio_a(cisco_fan1234_pwm_duty_ratio),
        .duty_ratio_b(cisco_fan5678_pwm_duty_ratio)
    );
    
    cisco_fan_fb_freq_lut #(
        .DUTY_RATIO_WIDTH(PWM_DUTY_RATIO_WIDTH),
        .FREQ_DIVIDE_WIDTH(FREQ_DIVIDE_WIDTH)
    )cisco_fan_fb_freq_lut_inst(
        .clk(clk),
        .pwm_duty_ratio_a(cisco_fan1234_pwm_duty_ratio),
        .pwm_duty_ratio_b(cisco_fan5678_pwm_duty_ratio),
        .freq_divide_a(fan1234_pwm_freq_divide),
        .freq_divide_b(fan5678_pwm_freq_divide),
        .rpm_a(cisco_fan1234_rpm),
        .rpm_b(cisco_fan5678_rpm)
    );
    
    square_wave_generator #(
        .FREQ_DIVIDE_WIDTH(FREQ_DIVIDE_WIDTH),
        .ASSERT_LEVEL(1'b1)
    )square_wave_generator_fan1234_inst(
        .clk(clk),
        .rst(rst),
        .freq_divide(fan1234_pwm_freq_divide),
        .out(fan1234_fb)
    );

    square_wave_generator #(
        .FREQ_DIVIDE_WIDTH(FREQ_DIVIDE_WIDTH),
        .ASSERT_LEVEL(1'b1)
    )square_wave_generator_fan5678_inst(
        .clk(clk),
        .rst(rst),
        .freq_divide(fan5678_pwm_freq_divide),
        .out(fan5678_fb)
    );

    assign cisco_fan_fb[3:0] = {4{fan1234_fb}};
    assign cisco_fan_fb[7:4] = {4{fan5678_fb}};
endmodule