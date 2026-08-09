`default_nettype none

import lcd_ui_page_config_pkg::*;

module register_controller #(
        parameter ADDR_WIDTH = 8,
        parameter DATA_WIDTH = 8,
        parameter LCD_BRIGHT_WIDTH = 4,
        parameter PWM_DUTY_RATIO_WIDTH = 8,
        parameter RPM_WIDTH = 14,
        parameter MAIN_FAN_NUM = 8
    )(
        input logic clk,
        input logic rst,
        
        input logic[ADDR_WIDTH - 1:0] addr,
        input logic[DATA_WIDTH - 1:0] wdata,
        input logic we,
        output logic[DATA_WIDTH - 1:0] rdata,
        
        output logic[PWM_DUTY_RATIO_WIDTH - 1:0] main_fan_pwm_duty_ratio_wdata[0:MAIN_FAN_NUM - 1],
        output logic[MAIN_FAN_NUM - 1:0] main_fan_pwm_duty_ratio_we,
        input logic[PWM_DUTY_RATIO_WIDTH - 1:0] main_fan_pwm_duty_ratio_rdata[0:MAIN_FAN_NUM - 1],
        input logic[RPM_WIDTH - 1:0] main_fan_rpm[0:MAIN_FAN_NUM - 1],
        
        input logic[PWM_DUTY_RATIO_WIDTH - 1:0] cisco_fan1234_pwm_duty_ratio,
        input logic[PWM_DUTY_RATIO_WIDTH - 1:0] cisco_fan5678_pwm_duty_ratio,
        input logic[RPM_WIDTH - 1:0] cisco_fan1234_rpm,
        input logic[RPM_WIDTH - 1:0] cisco_fan5678_rpm,
        
        output logic[LCD_BRIGHT_WIDTH - 1:0] bright_wdata,
        output logic bright_we,
        input logic[LCD_BRIGHT_WIDTH - 1:0] bright_rdata,
        
        output logic[PAGE_ID_WIDTH - 1:0] page_id_wdata,
        output logic page_id_we,
        input logic[PAGE_ID_WIDTH - 1:0] page_id_rdata
    );
    
    localparam MAIN_FAN_ADDR = ADDR_WIDTH'('h00);
    localparam CISCO_FAN1234_PWM_DUTY_RATIO_ADDR = ADDR_WIDTH'('h20);
    localparam CISCO_FAN5678_PWM_DUTY_RATIO_ADDR = ADDR_WIDTH'('h21);
    localparam CISCO_FAN1234_RPM_LOW_ADDR = ADDR_WIDTH'('h22);
    localparam CISCO_FAN1234_RPM_HIGH_ADDR = ADDR_WIDTH'('h23);
    localparam CISCO_FAN5678_RPM_LOW_ADDR = ADDR_WIDTH'('h24);
    localparam CISCO_FAN5678_RPM_HIGH_ADDR = ADDR_WIDTH'('h25);
    localparam BRIGHT_ADDR = ADDR_WIDTH'('h80);
    localparam PAGE_ID_ADDR = ADDR_WIDTH'('h81);
    
    logic[ADDR_WIDTH - 1:0] main_fan_rpm_addr;
    
    genvar i;
    
    assign main_fan_rpm_addr = unsigned'(addr - MAIN_FAN_ADDR - MAIN_FAN_NUM);
    
    always_ff @(posedge clk) begin
        if(rst) begin
            rdata <= '0;
        end
        else begin
            rdata <= '0;
            
            if((addr >= MAIN_FAN_ADDR) && (addr < unsigned'(MAIN_FAN_ADDR + MAIN_FAN_NUM))) begin
                rdata <= main_fan_pwm_duty_ratio_rdata[addr - MAIN_FAN_ADDR];
            end
            else if((addr >= unsigned'(MAIN_FAN_ADDR + MAIN_FAN_NUM)) && (addr < unsigned'(MAIN_FAN_ADDR + MAIN_FAN_NUM + MAIN_FAN_NUM * 2))) begin
                rdata <= main_fan_rpm_addr[0] ? main_fan_rpm[main_fan_rpm_addr >> 1][RPM_WIDTH - 1:DATA_WIDTH] : main_fan_rpm[main_fan_rpm_addr >> 1][DATA_WIDTH - 1:0];
            end
            else begin
                case(addr)
                    CISCO_FAN1234_PWM_DUTY_RATIO_ADDR: begin
                        rdata <= cisco_fan1234_pwm_duty_ratio;
                    end
                    
                    CISCO_FAN5678_PWM_DUTY_RATIO_ADDR: begin
                        rdata <= cisco_fan5678_pwm_duty_ratio;
                    end
                    
                    CISCO_FAN1234_RPM_LOW_ADDR: begin
                        rdata <= cisco_fan1234_rpm[DATA_WIDTH - 1:0];
                    end
                    
                    CISCO_FAN1234_RPM_HIGH_ADDR: begin
                        rdata <= cisco_fan1234_rpm[RPM_WIDTH - 1:DATA_WIDTH];
                    end
                    
                    CISCO_FAN5678_RPM_LOW_ADDR: begin
                        rdata <= cisco_fan5678_rpm[DATA_WIDTH - 1:0];
                    end
                    
                    CISCO_FAN5678_RPM_HIGH_ADDR: begin
                        rdata <= cisco_fan5678_rpm[RPM_WIDTH - 1:DATA_WIDTH];
                    end
                    
                    BRIGHT_ADDR: begin
                        rdata <= bright_rdata;
                    end
                    
                    PAGE_ID_ADDR: begin
                        rdata <= page_id_rdata;
                    end
                endcase
            end
        end
    end
    
    generate
        for(i = 0;i < MAIN_FAN_NUM;i++) begin: main_fan_reg_write_signal_gen
            assign main_fan_pwm_duty_ratio_wdata[i] = wdata;
            assign main_fan_pwm_duty_ratio_we[i] = ((addr == unsigned'(MAIN_FAN_ADDR + i)) && we) ? 1'b1 : 1'b0;
        end
    endgenerate
    
    assign bright_wdata = wdata;
    assign bright_we = ((addr == BRIGHT_ADDR) && we) ? 1'b1 : 1'b0;
    
    assign page_id_wdata = wdata;
    assign page_id_we = ((addr == PAGE_ID_ADDR) && we) ? 1'b1 : 1'b0;
endmodule