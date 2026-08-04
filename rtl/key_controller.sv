`default_nettype none

module key_controller #(
        parameter CLK_FREQ = 50000000,
        parameter KEY_ID_WIDTH = 4
    )(
        input logic clk,
        input logic rst,
        
        input logic[KEY_ID_WIDTH - 1:0] press_key_id,
        input logic press_key_id_valid,
        
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
    
    localparam KEY_ID_ADD = KEY_ID_WIDTH'('h00);
    localparam KEY_ID_SUB = KEY_ID_WIDTH'('h01);
    localparam KEY_ID_SAVE = KEY_ID_WIDTH'('h02);
    localparam KEY_ID_LOAD = KEY_ID_WIDTH'('h03);
    localparam KEY_ID_PAGE_PREV = KEY_ID_WIDTH'('h04);
    localparam KEY_ID_PAGE_NEXT = KEY_ID_WIDTH'('h05);
    localparam KEY_ID_BRIGHT_UP = KEY_ID_WIDTH'('h06);
    localparam KEY_ID_BRIGHT_DOWN = KEY_ID_WIDTH'('h07);
    localparam KEY_ID_LCD_OPENCLOSE = KEY_ID_WIDTH'('h08);

    logic tick_1ms;
    logic key_add_pulse_ext;
    logic key_sub_pulse_ext;
    logic key_save_pulse_ext;
    logic key_load_pulse_ext;
    logic key_page_prev_pulse_ext;
    logic key_page_next_pulse_ext;
    logic key_bright_up_pulse_ext;
    logic key_bright_down_pulse_ext;
    logic key_lcd_openclose_pulse_ext;
    logic key_add_pulse_internal;
    logic key_sub_pulse_internal;
    logic key_save_pulse_internal;
    logic key_load_pulse_internal;
    logic key_page_prev_pulse_internal;
    logic key_page_next_pulse_internal;
    logic key_bright_up_pulse_internal;
    logic key_bright_down_pulse_internal;
    logic key_lcd_openclose_pulse_internal;

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
        .repeat_pulse(key_add_pulse_ext)
    );

    key_handler key_handler_sub(
        .clk(clk),
        .rst(rst),
        .tick_1ms(tick_1ms),
        .key_in(key_sub_in),
        .repeat_pulse(key_sub_pulse_ext)
    );

    key_handler key_handler_save(
        .clk(clk),
        .rst(rst),
        .tick_1ms(tick_1ms),
        .key_in(key_save_in),
        .press_pulse(key_save_pulse_ext)
    );

    key_handler key_handler_load(
        .clk(clk),
        .rst(rst),
        .tick_1ms(tick_1ms),
        .key_in(key_load_in),
        .press_pulse(key_load_pulse_ext)
    );

    key_handler key_handler_page_prev(
        .clk(clk),
        .rst(rst),
        .tick_1ms(tick_1ms),
        .key_in(key_page_prev_in),
        .press_pulse(key_page_prev_pulse_ext)
    );

    key_handler key_handler_page_next(
        .clk(clk),
        .rst(rst),
        .tick_1ms(tick_1ms),
        .key_in(key_page_next_in),
        .press_pulse(key_page_next_pulse_ext)
    );

    key_handler key_handler_bright_up(
        .clk(clk),
        .rst(rst),
        .tick_1ms(tick_1ms),
        .key_in(key_bright_up_in),
        .repeat_pulse(key_bright_up_pulse_ext)
    );

    key_handler key_handler_bright_down(
        .clk(clk),
        .rst(rst),
        .tick_1ms(tick_1ms),
        .key_in(key_bright_down_in),
        .repeat_pulse(key_bright_down_pulse_ext)
    );

    key_handler key_handler_lcd_openclose(
        .clk(clk),
        .rst(rst),
        .tick_1ms(tick_1ms),
        .key_in(key_lcd_openclose_in),
        .press_pulse(key_lcd_openclose_pulse_ext)
    );
    
    always_ff @(posedge clk) begin
        key_add_pulse_internal <= 1'b0;
        key_sub_pulse_internal <= 1'b0;
        key_save_pulse_internal <= 1'b0;
        key_load_pulse_internal <= 1'b0;
        key_page_prev_pulse_internal <= 1'b0;
        key_page_next_pulse_internal <= 1'b0;
        key_bright_up_pulse_internal <= 1'b0;
        key_bright_down_pulse_internal <= 1'b0;
        key_lcd_openclose_pulse_internal <= 1'b0;
        
        if(!rst && press_key_id_valid) begin
            case(press_key_id)
                KEY_ID_ADD: begin
                    key_add_pulse_internal <= 1'b1;
                end
                
                KEY_ID_SUB: begin
                    key_sub_pulse_internal <= 1'b1;
                end
                
                KEY_ID_SAVE: begin
                    key_save_pulse_internal <= 1'b1;
                end
                
                KEY_ID_LOAD: begin
                    key_load_pulse_internal <= 1'b1;
                end
                
                KEY_ID_PAGE_PREV: begin
                    key_page_prev_pulse_internal <= 1'b1;
                end
                
                KEY_ID_PAGE_NEXT: begin
                    key_page_next_pulse_internal <= 1'b1;
                end
                
                KEY_ID_BRIGHT_UP: begin
                    key_bright_up_pulse_internal <= 1'b1;
                end
                
                KEY_ID_BRIGHT_DOWN: begin
                    key_bright_down_pulse_internal <= 1'b1;
                end
                
                KEY_ID_LCD_OPENCLOSE: begin
                    key_lcd_openclose_pulse_internal <= 1'b1;
                end
            endcase
        end
    end
    
    assign key_add_pulse = key_add_pulse_ext | key_add_pulse_internal;
    assign key_sub_pulse = key_sub_pulse_ext | key_sub_pulse_internal;
    assign key_save_pulse = key_save_pulse_ext | key_save_pulse_internal;
    assign key_load_pulse = key_load_pulse_ext | key_load_pulse_internal;
    assign key_page_prev_pulse = key_page_prev_pulse_ext | key_page_prev_pulse_internal;
    assign key_page_next_pulse = key_page_next_pulse_ext | key_page_next_pulse_internal;
    assign key_bright_up_pulse = key_bright_up_pulse_ext | key_bright_up_pulse_internal;
    assign key_bright_down_pulse = key_bright_down_pulse_ext | key_bright_down_pulse_internal;
    assign key_lcd_openclose_pulse = key_lcd_openclose_pulse_ext | key_lcd_openclose_pulse_internal;
endmodule