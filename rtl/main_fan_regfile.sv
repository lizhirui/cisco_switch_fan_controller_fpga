`default_nettype none

module main_fan_regfile #(
        parameter PWM_DUTY_RATIO_WIDTH = 8,
        parameter MAIN_FAN_NUM = 8
    )(
        input logic clk,
        input logic rst,
        
        input logic[PWM_DUTY_RATIO_WIDTH - 1:0] main_fan_pwm_duty_ratio_cfg_wdata[0:MAIN_FAN_NUM - 1],
        input logic[MAIN_FAN_NUM - 1:0] main_fan_pwm_duty_ratio_cfg_we,
        input logic[PWM_DUTY_RATIO_WIDTH - 1:0] main_fan_pwm_duty_ratio_reg_wdata[0:MAIN_FAN_NUM - 1],
        input logic[MAIN_FAN_NUM - 1:0] main_fan_pwm_duty_ratio_reg_we,
        input logic[PWM_DUTY_RATIO_WIDTH - 1:0] main_fan_pwm_duty_ratio_main_wdata[0:MAIN_FAN_NUM - 1],
        input logic[MAIN_FAN_NUM - 1:0] main_fan_pwm_duty_ratio_main_we,
        output logic[PWM_DUTY_RATIO_WIDTH - 1:0] main_fan_pwm_duty_ratio[0:MAIN_FAN_NUM - 1]
    );
    
    genvar i;
    
    generate
        for(i = 0;i < MAIN_FAN_NUM;i++) begin: main_fan_pwm_duty_ratio_gen
            always_ff @(posedge clk) begin
                if(rst) begin
                    main_fan_pwm_duty_ratio[i] <= '0;
                end
                else if(main_fan_pwm_duty_ratio_cfg_we[i]) begin
                    main_fan_pwm_duty_ratio[i] <= main_fan_pwm_duty_ratio_cfg_wdata[i];
                end
                else if(main_fan_pwm_duty_ratio_reg_we[i]) begin
                    main_fan_pwm_duty_ratio[i] <= main_fan_pwm_duty_ratio_reg_wdata[i];
                end
                else if(main_fan_pwm_duty_ratio_main_we[i]) begin
                    main_fan_pwm_duty_ratio[i] <= main_fan_pwm_duty_ratio_main_wdata[i];
                end
            end
        end
    endgenerate
endmodule