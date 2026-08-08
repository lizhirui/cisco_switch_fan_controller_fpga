`default_nettype none

import lcd_ui_page_config_pkg::*;

module register_controller #(
        parameter ADDR_WIDTH = 8,
        parameter DATA_WIDTH = 8,
        parameter LCD_BRIGHT_WIDTH = 4,
        parameter PWM_DUTY_RATIO_WIDTH = 8,
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
        
        output logic[LCD_BRIGHT_WIDTH - 1:0] bright_wdata,
        output logic bright_we,
        input logic[LCD_BRIGHT_WIDTH - 1:0] bright_rdata,
        
        output logic[PAGE_ID_WIDTH - 1:0] page_id_wdata,
        output logic page_id_we,
        input logic[PAGE_ID_WIDTH - 1:0] page_id_rdata
    );
    
    localparam MAIN_FAN_ADDR = ADDR_WIDTH'('h00);
    localparam BRIGHT_ADDR = ADDR_WIDTH'('h80);
    localparam PAGE_ID_ADDR = ADDR_WIDTH'('h81);
    
    genvar i;
    
    always_ff @(posedge clk) begin
        if(rst) begin
            rdata <= '0;
        end
        else begin
            rdata <= '0;
            
            if((addr >= MAIN_FAN_ADDR) && (addr < unsigned'(MAIN_FAN_ADDR + MAIN_FAN_NUM))) begin
                rdata <= main_fan_pwm_duty_ratio_rdata[addr - MAIN_FAN_ADDR];
            end
            else begin
                case(addr)
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