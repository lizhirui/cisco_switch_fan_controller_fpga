`default_nettype none

module lcd_bright_controller #(
        parameter CLK_FREQ = 50000000,
        parameter LCD_PWM_FREQ = 20000,
        parameter LCD_BRIGHT_WIDTH = 4
    )(
        input logic clk,
        input logic rst,

        output logic lcd_leda_pwm,

        input logic key_bright_up_pulse,
        input logic key_bright_down_pulse,
        input logic key_lcd_openclose_pulse,

        input logic[LCD_BRIGHT_WIDTH - 1:0] bright_in,
        input logic bright_in_valid,
        
        output logic[LCD_BRIGHT_WIDTH - 1:0] bright
    );

    localparam FREQ_DIVIDE = unsigned'(CLK_FREQ / LCD_PWM_FREQ);
    localparam FREQ_DIVIDE_WIDTH = ($clog2(FREQ_DIVIDE + 1) <= 1) ? 1 : $clog2(FREQ_DIVIDE + 1);

    logic lcd_enable;
    logic lcd_leda_pwm_internal;

    pwm_generator #(
        .FREQ_DIVIDE_BIT_WIDTH(FREQ_DIVIDE_WIDTH),
        .DUTY_RATIO_BIT_WIDTH(LCD_BRIGHT_WIDTH),
        .ASSERT_LEVEL(1'b0)
    )pwm_generator_inst(
        .clk(clk),
        .rst(rst),
        .freq_divide(FREQ_DIVIDE),
        .duty_ratio(bright),
        .out(lcd_leda_pwm_internal)
    );

    assign lcd_leda_pwm = lcd_enable ? lcd_leda_pwm_internal : 1'b1;

    always_ff @(posedge clk) begin
        if(rst) begin
            lcd_enable <= 1'b1;
        end
        else if(key_lcd_openclose_pulse) begin
            lcd_enable <= ~lcd_enable;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            bright <= 2 ** LCD_BRIGHT_WIDTH / 2;
        end
        else if(bright_in_valid) begin
            bright <= bright_in;
        end
        else if(key_bright_up_pulse) begin
            if(bright != '1) begin
                bright <= bright + 'b1;
            end
        end
        else if(key_bright_down_pulse) begin
            if(bright != '0) begin
                bright <= bright - 'b1;
            end
        end
    end
endmodule