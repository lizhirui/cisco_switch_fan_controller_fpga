`default_nettype none

module key_controller #(
        parameter CLK_FREQ = 50000000
    )(
        input logic clk,
        input logic rst,
        
        input logic key_add_in,
        input logic key_sub_in,
        input logic key_save_in,
        input logic key_load_in,
        input logic key_page_prev_in,
        input logic key_page_next_in,
        input logic key_bright_up_in,
        input logic key_bright_down_in,
        input logic key_lcd_openclose_in,

        output logic key_add_pulse,
        output logic key_sub_pulse,
        output logic key_save_pulse,
        output logic key_load_pulse,
        output logic key_page_prev_pulse,
        output logic key_page_next_pulse,
        output logic key_bright_up_pulse,
        output logic key_bright_down_pulse,
        output logic key_lcd_openclose_pulse
    );

    logic tick_1ms;

    clock_enable_generator #(
        .CLOCK_FREQUENCY(CLK_FREQ),
        .ENABLE_FREQUENCY(1000)
    )clock_enable_generator_inst(
        .clk(clk),
        .rst(rst),
        .enable(tick_1ms)
    );

    key_handler key_handler_add(
        .clk(clk),
        .rst(rst),
        .tick_1ms(tick_1ms),
        .key_in(key_add_in),
        .repeat_pulse(key_add_pulse)
    );

    key_handler key_handler_sub(
        .clk(clk),
        .rst(rst),
        .tick_1ms(tick_1ms),
        .key_in(key_sub_in),
        .repeat_pulse(key_sub_pulse)
    );

    key_handler key_handler_save(
        .clk(clk),
        .rst(rst),
        .tick_1ms(tick_1ms),
        .key_in(key_save_in),
        .press_pulse(key_save_pulse)
    );

    key_handler key_handler_load(
        .clk(clk),
        .rst(rst),
        .tick_1ms(tick_1ms),
        .key_in(key_load_in),
        .press_pulse(key_load_pulse)
    );

    key_handler key_handler_page_prev(
        .clk(clk),
        .rst(rst),
        .tick_1ms(tick_1ms),
        .key_in(key_page_prev_in),
        .press_pulse(key_page_prev_pulse)
    );

    key_handler key_handler_page_next(
        .clk(clk),
        .rst(rst),
        .tick_1ms(tick_1ms),
        .key_in(key_page_next_in),
        .press_pulse(key_page_next_pulse)
    );

    key_handler key_handler_bright_up(
        .clk(clk),
        .rst(rst),
        .tick_1ms(tick_1ms),
        .key_in(key_bright_up_in),
        .repeat_pulse(key_bright_up_pulse)
    );

    key_handler key_handler_bright_down(
        .clk(clk),
        .rst(rst),
        .tick_1ms(tick_1ms),
        .key_in(key_bright_down_in),
        .repeat_pulse(key_bright_down_pulse)
    );

    key_handler key_handler_lcd_openclose(
        .clk(clk),
        .rst(rst),
        .tick_1ms(tick_1ms),
        .key_in(key_lcd_openclose_in),
        .press_pulse(key_lcd_openclose_pulse)
    );
endmodule