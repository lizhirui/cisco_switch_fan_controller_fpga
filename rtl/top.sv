`default_nettype none

import lcd_ui_config_pkg::*;

module top(
        input logic clk,
        input logic rst_n,
        output logic cisco_fan1234_pwm,
        output logic cisco_fan5678_pwm,
        output logic cisco_led_status_green,
        output logic cisco_led_status_red,
        input logic[7:0] cisco_fan_fb,
        output logic[7:0] main_fan_pwm,
        input logic[7:0] main_fan_fb,
        output logic[2:0] eeprom_addr,
        inout logic eeprom_sda,
        output logic eeprom_scl,
        output logic eeprom_wp,
        output logic lcd_rst,
        output logic lcd_cs,
        output logic lcd_rs,
        output logic lcd_sclk,
        output logic lcd_sda,
        output logic lcd_rom_cs,
        output logic lcd_rom_sck,
        output logic lcd_rom_si,
        input logic lcd_rom_so,
        output logic lcd_leda_pwm,
        input logic key_add,
        input logic key_sub,
        input logic key_save,
        input logic key_load,
        input logic key_page_prev,
        input logic key_page_next,
        input logic key_bright_up,
        input logic key_bright_down,
        input logic key_lcd_openclose,
        input logic uart_rxd,
        output logic uart_txd
    );
    
    localparam CLK_FREQ = 50000000;
    localparam LCD_BRIGHT_WIDTH = 4;
    localparam LCD_PIXEL_LINE_NUM = 64;
    localparam LCD_PIXEL_COL_NUM = 128;
    localparam LCD_DATA_WIDTH = 8;
    localparam CHAR_HEIGHT = 16;
    localparam CHAR_WIDTH = 8;
    localparam LCD_LINE_NUM = LCD_PIXEL_LINE_NUM / CHAR_HEIGHT;
    localparam LCD_COL_NUM = LCD_PIXEL_COL_NUM / CHAR_WIDTH;
    localparam PAGE_ID_WIDTH = 2;
    localparam LINE_ID_WIDTH = (LCD_LINE_NUM <= 1) ? 1 : $clog2(LCD_LINE_NUM);
    localparam LINE_DATA_WIDTH = 128;
    localparam CHAR_DATA_WIDTH = 8;
    localparam CONFIG_ADDR_WIDTH = 4;

    logic rst_poweron;
    logic rst_ext;
    logic rst;
    logic key_add_pulse;
    logic key_sub_pulse;
    logic key_save_pulse;
    logic key_load_pulse;
    logic key_page_prev_pulse;
    logic key_page_next_pulse;
    logic key_bright_up_pulse;
    logic key_bright_down_pulse;
    logic key_lcd_openclose_pulse;
    logic[CONFIG_ADDR_WIDTH - 1:0] page_config_addr;
    lcd_ui_config_data_t page_config_data;
    lcd_ui_config_data_t page_main_config_data;

    poweron_reset_generator poweron_reset_generator_inst(
        .clk(clk),
        .rst_out(rst_poweron)
    );

    reset_synchronizer reset_synchronizer_inst(
        .clk(clk),
        .rst_n(rst_n),
        .rst(rst_ext)
    );

    assign rst = rst_poweron | rst_ext;

    key_controller #(
        .CLK_FREQ(CLK_FREQ)
    )key_controller_inst(
        .clk(clk),
        .rst(rst),
        .key_add_in(key_add),
        .key_sub_in(key_sub),
        .key_save_in(key_save),
        .key_load_in(key_load),
        .key_page_prev_in(key_page_prev),
        .key_page_next_in(key_page_next),
        .key_bright_up_in(key_bright_up),
        .key_bright_down_in(key_bright_down),
        .key_lcd_openclose_in(key_lcd_openclose),
        .key_add_pulse(key_add_pulse),
        .key_sub_pulse(key_sub_pulse),
        .key_save_pulse(key_save_pulse),
        .key_load_pulse(key_load_pulse),
        .key_page_prev_pulse(key_page_prev_pulse),
        .key_page_next_pulse(key_page_next_pulse),
        .key_bright_up_pulse(key_bright_up_pulse),
        .key_bright_down_pulse(key_bright_down_pulse),
        .key_lcd_openclose_pulse(key_lcd_openclose_pulse)
    );

    lcd_controller #(
        .CLK_FREQ(CLK_FREQ),
        .LCD_BRIGHT_WIDTH(LCD_BRIGHT_WIDTH),
        .LCD_PIXEL_LINE_NUM(LCD_PIXEL_LINE_NUM),
        .LCD_PIXEL_COL_NUM(LCD_PIXEL_COL_NUM),
        .LCD_DATA_WIDTH(LCD_DATA_WIDTH),
        .CHAR_HEIGHT(CHAR_HEIGHT),
        .CHAR_WIDTH(CHAR_WIDTH),
        .PAGE_ID_WIDTH(PAGE_ID_WIDTH),
        .CONFIG_ADDR_WIDTH(CONFIG_ADDR_WIDTH)
    )lcd_controller_inst(
        .clk(clk),
        .rst(rst),
        .lcd_rst(lcd_rst),
        .lcd_cs(lcd_cs),
        .lcd_rs(lcd_rs),
        .lcd_sclk(lcd_sclk),
        .lcd_sda(lcd_sda),
        .lcd_rom_cs(lcd_rom_cs),
        .lcd_rom_sck(lcd_rom_sck),
        .lcd_rom_si(lcd_rom_si),
        .lcd_rom_so(lcd_rom_so),
        .lcd_leda_pwm(lcd_leda_pwm),
        .key_bright_up_pulse(key_bright_up_pulse),
        .key_bright_down_pulse(key_bright_down_pulse),
        .key_lcd_openclose_pulse(key_lcd_openclose_pulse),
        .bright_in('0),
        .bright_in_valid(1'b0),
        .bright(),
        .page_id_in('0),
        .page_id_in_valid(1'b0),
        .page_id(),
        .page_config_addr(page_config_addr),
        .page_config_data(page_config_data)
    );

    lcd_page_main_ui #(
        .CONFIG_ADDR_WIDTH(CONFIG_ADDR_WIDTH)
    )lcd_page_main_inst(
        .clk(clk),
        .rst(rst),
        .config_addr(page_config_addr),
        .config_data(page_main_config_data)
    );
    
    assign page_config_data = page_main_config_data;
endmodule