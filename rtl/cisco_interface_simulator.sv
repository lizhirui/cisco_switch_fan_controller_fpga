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
        input logic cisco_led_status_green,
        input logic cisco_led_status_red,
        output logic[7:0] cisco_fan_fb,
        
        output logic[PWM_DUTY_RATIO_WIDTH - 1:0] cisco_fan1234_pwm_duty_ratio,
        output logic[PWM_DUTY_RATIO_WIDTH - 1:0] cisco_fan5678_pwm_duty_ratio,
        output logic[RPM_WIDTH - 1:0] cisco_fan1234_rpm,
        output logic[RPM_WIDTH - 1:0] cisco_fan5678_rpm
    );
    
    localparam CNT_WIDTH = 32;
    localparam FREQ_DIVIDE_WIDTH = 26;
    
    logic[CNT_WIDTH - 1:0] fan1234_pwm_high_level_cnt;
    logic[CNT_WIDTH - 1:0] fan1234_pwm_total_cnt;
    logic[CNT_WIDTH - 1:0] fan5678_pwm_high_level_cnt;
    logic[CNT_WIDTH - 1:0] fan5678_pwm_total_cnt;
    logic[FREQ_DIVIDE_WIDTH - 1:0] fan1234_pwm_freq_divide;
    logic[FREQ_DIVIDE_WIDTH - 1:0] fan5678_pwm_freq_divide; 
    
    genvar i;
    
    signal_measurer #(
        .CNT_WIDTH(CNT_WIDTH),
        .TIMEOUT_CNT(CLK_FREQ / 1000)
    )signal_measurer_fan1234_pwm_inst(
        .clk(clk),
        .rst(rst),
        .signal(cisco_fan1234_pwm),
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
        .signal(cisco_fan5678_pwm),
        .high_level_cnt(fan5678_pwm_high_level_cnt),
        .low_level_cnt(),
        .total_cnt(fan5678_pwm_total_cnt),
        .period_valid()
    );
    
    pwm_duty_ratio_calculator #(
        .CNT_WIDTH(CNT_WIDTH),
        .DUTY_RATIO_WIDTH(PWM_DUTY_RATIO_WIDTH)
    )pwm_duty_ratio_calculator_fan1234_pwm_inst(
        .high_level_cnt(fan1234_pwm_high_level_cnt),
        .total_cnt(fan1234_pwm_total_cnt),
        .duty_ratio(cisco_fan1234_pwm_duty_ratio)
    );
    
    pwm_duty_ratio_calculator #(
        .CNT_WIDTH(CNT_WIDTH),
        .DUTY_RATIO_WIDTH(PWM_DUTY_RATIO_WIDTH)
    )pwm_duty_ratio_calculator_fan5678_pwm_inst(
        .high_level_cnt(fan5678_pwm_high_level_cnt),
        .total_cnt(fan5678_pwm_total_cnt),
        .duty_ratio(cisco_fan5678_pwm_duty_ratio)
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
    
    generate
        for(i = 0;i < 8;i++) begin: pwm_generator
            pwm_generator #(
                .FREQ_DIVIDE_WIDTH(FREQ_DIVIDE_WIDTH),
                .DUTY_RATIO_WIDTH(PWM_DUTY_RATIO_WIDTH),
                .ASSERT_LEVEL(1'b1)
            )pwm_generator_inst(
                .clk(clk),
                .rst(rst),
                .freq_divide((i < 4) ? fan1234_pwm_freq_divide : fan5678_pwm_freq_divide),
                .duty_ratio({1'b1, {(PWM_DUTY_RATIO_WIDTH - 1){1'b0}}}),
                .out(cisco_fan_fb[i])
            );
        end
    endgenerate
endmodule