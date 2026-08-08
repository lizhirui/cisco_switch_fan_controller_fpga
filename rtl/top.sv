`default_nettype none

import lcd_ui_config_pkg::*;
import lcd_ui_page_config_pkg::*;

module top #(
        parameter MAIN_FAN_NUM = 8
    )(
        input logic clk,
        input logic rst_n,
        input logic cisco_fan1234_pwm,
        input logic cisco_fan5678_pwm,
        input logic cisco_led_status_green,
        input logic cisco_led_status_red,
        output logic[7:0] cisco_fan_fb,
        output logic[MAIN_FAN_NUM - 1:0] main_fan_pwm,
        input logic[MAIN_FAN_NUM - 1:0] main_fan_fb,
        output logic[2:0] eeprom_addr,
        inout wire eeprom_sda,
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
    localparam FREQ_DIVIDE_WIDTH = 26;
    localparam PWM_DUTY_RATIO_WIDTH = 8;
    localparam PPR = 2;
    localparam RPM_WIDTH = 14;
    localparam UART_DATA_WIDTH = 8;
    localparam UART_PROTOCOL_RECV_PACKET_BYTE_LENGTH = 4;
    localparam UART_PROTOCOL_SEND_PACKET_BYTE_LENGTH = 10;
    localparam REG_ADDR_WIDTH = 8;
    localparam REG_DATA_WIDTH = 8;
    localparam KEY_ID_WIDTH = 4;
    localparam LCD_BRIGHT_WIDTH = 4;
    localparam LCD_PIXEL_LINE_NUM = 64;
    localparam LCD_PIXEL_COL_NUM = 128;
    localparam LCD_DATA_WIDTH = 8;
    localparam CHAR_WIDTH = 8;
    localparam CHAR_HEIGHT = 16;
    localparam LCD_LINE_NUM = LCD_PIXEL_LINE_NUM / CHAR_HEIGHT;
    localparam LCD_COL_NUM = LCD_PIXEL_COL_NUM / CHAR_WIDTH;
    localparam LINE_ID_WIDTH = (LCD_LINE_NUM <= 1) ? 1 : $clog2(LCD_LINE_NUM);
    localparam LINE_DATA_WIDTH = 128;
    localparam CHAR_DATA_WIDTH = 8;
    localparam CONFIG_ADDR_WIDTH = 4;
    localparam VRAM_DEPTH = LCD_PIXEL_LINE_NUM * LCD_PIXEL_COL_NUM / LCD_DATA_WIDTH;
    localparam VRAM_ADDR_WIDTH = (VRAM_DEPTH <= 1) ? 1 : $clog2(VRAM_DEPTH);

    logic rst_poweron;
    logic rst_ext;
    logic rst;
    logic[PWM_DUTY_RATIO_WIDTH - 1:0] cisco_fan1234_pwm_duty_ratio;
    logic[PWM_DUTY_RATIO_WIDTH - 1:0] cisco_fan5678_pwm_duty_ratio;
    logic[RPM_WIDTH - 1:0] cisco_fan1234_rpm;
    logic[RPM_WIDTH - 1:0] cisco_fan5678_rpm;
    logic cisco_led_status_green_sync;
    logic cisco_led_status_red_sync;
    logic[PWM_DUTY_RATIO_WIDTH - 1:0] main_fan_pwm_duty_ratio_cfg_wdata[0:MAIN_FAN_NUM - 1];
    logic[MAIN_FAN_NUM - 1:0] main_fan_pwm_duty_ratio_cfg_we;
    logic[PWM_DUTY_RATIO_WIDTH - 1:0] main_fan_pwm_duty_ratio_reg_wdata[0:MAIN_FAN_NUM - 1];
    logic[MAIN_FAN_NUM - 1:0] main_fan_pwm_duty_ratio_reg_we;
    logic[PWM_DUTY_RATIO_WIDTH - 1:0] main_fan_pwm_duty_ratio_main_wdata[0:MAIN_FAN_NUM - 1];
    logic[MAIN_FAN_NUM - 1:0] main_fan_pwm_duty_ratio_main_we;
    logic[PWM_DUTY_RATIO_WIDTH - 1:0] main_fan_pwm_duty_ratio[0:MAIN_FAN_NUM - 1];
    logic[RPM_WIDTH - 1:0] main_fan_rpm[0:MAIN_FAN_NUM - 1];
    logic eeprom_load_data_valid;
    logic eeprom_save_done;
    logic eeprom_busy;
    logic eeprom_error;
    logic[REG_ADDR_WIDTH - 1:0] reg_addr;
    logic[REG_DATA_WIDTH - 1:0] reg_wdata;
    logic reg_we;
    logic[REG_DATA_WIDTH - 1:0] reg_rdata;
    logic[PAGE_ID_WIDTH - 1:0] reg_page_id_wdata;
    logic reg_page_id_we;
    logic[KEY_ID_WIDTH - 1:0] press_key_id;
    logic press_key_id_valid;
    logic key_add_pulse;
    logic key_sub_pulse;
    logic key_save_pulse;
    logic key_load_pulse;
    logic key_page_prev_pulse;
    logic key_page_next_pulse;
    logic key_bright_up_pulse;
    logic key_bright_down_pulse;
    logic key_lcd_openclose_pulse;
    logic[LCD_BRIGHT_WIDTH - 1:0] bright_in;
    logic bright_in_valid;
    logic[LCD_BRIGHT_WIDTH - 1:0] bright;
    logic[PAGE_ID_WIDTH - 1:0] page_id_in;
    logic page_id_in_valid;
    logic[PAGE_ID_WIDTH - 1:0] page_id;
    logic[CONFIG_ADDR_WIDTH - 1:0] page_config_addr;
    lcd_ui_config_data_t page_config_data;
    logic[VRAM_ADDR_WIDTH - 1:0] clone_vram_raddr;
    logic[LCD_DATA_WIDTH - 1:0] clone_vram_rdata;
    logic clone_vram_start;
    logic clone_vram_busy;
    logic[UART_DATA_WIDTH - 1:0] rx_data;
    logic rx_data_valid;
    logic rx_error;
    logic[UART_DATA_WIDTH - 1:0] tx_data;
    logic tx_start;
    logic tx_busy;
    logic[UART_PROTOCOL_RECV_PACKET_BYTE_LENGTH * 8 - 1:0] recv_packet;
    logic recv_packet_valid;
    logic recv_packet_full;
    logic[UART_PROTOCOL_RECV_PACKET_BYTE_LENGTH * 8 - 1:0] fifo_recv_packet;
    logic fifo_recv_packet_valid;
    logic fifo_recv_packet_pop;
    logic[UART_PROTOCOL_SEND_PACKET_BYTE_LENGTH * 8 - 1:0] fifo_send_packet;
    logic fifo_send_packet_valid;
    logic fifo_send_packet_full;
    logic[UART_PROTOCOL_SEND_PACKET_BYTE_LENGTH * 8 - 1:0] send_packet;
    logic send_packet_valid;
    logic send_packet_pop;
    logic[PAGE_ID_WIDTH - 1:0] page_switcher_page_id_wdata;
    logic page_switcher_page_id_we;
    lcd_ui_config_data_t page_main_config_data;
    lcd_ui_config_data_t page_cisco_config_data;
    lcd_ui_config_data_t page_main_fan_config_data;
    lcd_ui_config_data_t page_message_config_data;
    
    genvar i;

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
    
    cisco_interface_simulator #(
        .CLK_FREQ(CLK_FREQ),
        .PWM_DUTY_RATIO_WIDTH(PWM_DUTY_RATIO_WIDTH),
        .RPM_WIDTH(RPM_WIDTH)
    )cisco_interface_simulator_inst(
        .clk(clk),
        .rst(rst),
        .cisco_fan1234_pwm(cisco_fan1234_pwm),
        .cisco_fan5678_pwm(cisco_fan5678_pwm),
        .cisco_fan_fb(cisco_fan_fb),
        .cisco_fan1234_pwm_duty_ratio(cisco_fan1234_pwm_duty_ratio),
        .cisco_fan5678_pwm_duty_ratio(cisco_fan5678_pwm_duty_ratio),
        .cisco_fan1234_rpm(cisco_fan1234_rpm),
        .cisco_fan5678_rpm(cisco_fan5678_rpm)
    );
    
    signal_syncer #(
        .WIDTH(4),
        .RESET_VALUE(1'b0)
    )signal_syncer_cisco_led_status_inst(
        .clk(clk),
        .rst(rst),
        .din({cisco_led_status_green, cisco_led_status_red}),
        .dout({cisco_led_status_green_sync, cisco_led_status_red_sync}),
        .dout_valid()
    );
    
    main_fan_regfile #(
        .PWM_DUTY_RATIO_WIDTH(PWM_DUTY_RATIO_WIDTH),
        .MAIN_FAN_NUM(MAIN_FAN_NUM)
    )main_fan_regfile_inst(
        .clk(clk),
        .rst(rst),
        .main_fan_pwm_duty_ratio_cfg_wdata(main_fan_pwm_duty_ratio_cfg_wdata),
        .main_fan_pwm_duty_ratio_cfg_we(main_fan_pwm_duty_ratio_cfg_we),
        .main_fan_pwm_duty_ratio_reg_wdata(main_fan_pwm_duty_ratio_reg_wdata),
        .main_fan_pwm_duty_ratio_reg_we(main_fan_pwm_duty_ratio_reg_we),
        .main_fan_pwm_duty_ratio_main_wdata(main_fan_pwm_duty_ratio_main_wdata),
        .main_fan_pwm_duty_ratio_main_we(main_fan_pwm_duty_ratio_main_we),
        .main_fan_pwm_duty_ratio(main_fan_pwm_duty_ratio)
    );
    
    generate
        for(i = 0;i < MAIN_FAN_NUM;i++) begin: main_fan_pwm_generator_gen
            pwm_generator #(
                .FREQ_DIVIDE_WIDTH(FREQ_DIVIDE_WIDTH),
                .DUTY_RATIO_WIDTH(PWM_DUTY_RATIO_WIDTH),
                .ASSERT_LEVEL(1'b1)
            )pwm_generator_inst(
                .clk(clk),
                .rst(rst),
                .freq_divide(CLK_FREQ / 200000),
                .duty_ratio(main_fan_pwm_duty_ratio[i]),
                .out(main_fan_pwm[i])  
            );
        end
    endgenerate
    
    multi_fan_rpm_measurer #(
        .CLK_FREQ(CLK_FREQ),
        .PPR(PPR),
        .FAN_NUM(MAIN_FAN_NUM),
        .RPM_WIDTH(RPM_WIDTH),
        .RPM_SCALE_SHIFT(6)
    )multi_fan_rpm_measurer_inst(
        .clk(clk),
        .rst(rst),
        .fan_fb(main_fan_fb),
        .rpm(main_fan_rpm)
    );
    
    at24c02_controller #(
        .CLK_FREQ(CLK_FREQ),
        .I2C_FREQ(100000),
        .DATA_NUM(MAIN_FAN_NUM),
        .EEPROM_ADDR(3'b000),
        .EEPROM_START_ADDR(8'h00),
        .AUTO_LOAD(1'b1),
        .AUTO_LOAD_DELAY_CYCLES(CLK_FREQ / 100)
    )at24c02_controller_inst(
        .clk(clk),
        .rst(rst),
        .save(key_save_pulse),
        .load(key_load_pulse),
        .save_data(main_fan_pwm_duty_ratio),
        .load_data(main_fan_pwm_duty_ratio_cfg_wdata),
        .load_data_valid(eeprom_load_data_valid),
        .save_done(eeprom_save_done),
        .busy(eeprom_busy),
        .error(eeprom_error),
        .eeprom_addr(eeprom_addr),
        .eeprom_sda(eeprom_sda),
        .eeprom_scl(eeprom_scl),
        .eeprom_wp(eeprom_wp)
    );

    assign main_fan_pwm_duty_ratio_cfg_we = {MAIN_FAN_NUM{eeprom_load_data_valid}};
    
    uart #(
        .CLOCK_FREQUENCY(CLK_FREQ),
        .BAUD_RATE(10000000),
        .DATA_WIDTH(UART_DATA_WIDTH)
    )uart_inst(
        .clk(clk),
        .rst(rst),
        .rxd(uart_rxd),
        .rx_data(rx_data),
        .rx_data_valid(rx_data_valid),
        .rx_error(rx_error),
        .txd(uart_txd),
        .tx_data(tx_data),
        .tx_start(tx_start),
        .tx_busy(tx_busy)
    );
    
    uart_protocol_phy #(
        .DATA_WIDTH(UART_DATA_WIDTH),
        .RECV_PACKET_BYTE_LENGTH(UART_PROTOCOL_RECV_PACKET_BYTE_LENGTH),
        .SEND_PACKET_BYTE_LENGTH(UART_PROTOCOL_SEND_PACKET_BYTE_LENGTH)
    )uart_protocol_phy_inst(
        .clk(clk),
        .rst(rst),
        .rx_data(rx_data),
        .rx_data_valid(rx_data_valid),
        .rx_error(rx_error),
        .tx_data(tx_data),
        .tx_start(tx_start),
        .tx_busy(tx_busy),
        .recv_packet(recv_packet),
        .recv_packet_valid(recv_packet_valid),
        .recv_packet_full(recv_packet_full),
        .send_packet(send_packet),
        .send_packet_valid(send_packet_valid),
        .send_packet_pop(send_packet_pop)
    );
    
    fwft_fifo #(
        .WIDTH(UART_PROTOCOL_RECV_PACKET_BYTE_LENGTH * 8),
        .DEPTH(256)
    )fwft_fifo_uart_protocol_recv_inst(
        .clk(clk),
        .rst(rst),
        .data_in(recv_packet),
        .push(recv_packet_valid),
        .full(recv_packet_full),
        .flush(1'b0),
        .data_out(fifo_recv_packet),
        .data_out_valid(fifo_recv_packet_valid),
        .pop(fifo_recv_packet_pop),
        .empty()
    );
    
    uart_protocol_processor #(
        .RECV_PACKET_BYTE_LENGTH(UART_PROTOCOL_RECV_PACKET_BYTE_LENGTH),
        .SEND_PACKET_BYTE_LENGTH(UART_PROTOCOL_SEND_PACKET_BYTE_LENGTH),
        .VRAM_ADDR_WIDTH(VRAM_ADDR_WIDTH),
        .VRAM_DATA_WIDTH(LCD_DATA_WIDTH),
        .KEY_ID_WIDTH(KEY_ID_WIDTH),
        .REG_ADDR_WIDTH(REG_ADDR_WIDTH),
        .REG_DATA_WIDTH(REG_DATA_WIDTH)
    )uart_protocol_processor_inst(
        .clk(clk),
        .rst(rst),
        .recv_packet(fifo_recv_packet),
        .recv_packet_valid(fifo_recv_packet_valid),
        .recv_packet_pop(fifo_recv_packet_pop),
        .send_packet(fifo_send_packet),
        .send_packet_valid(fifo_send_packet_valid),
        .send_packet_full(fifo_send_packet_full),
        .clone_vram_raddr(clone_vram_raddr),
        .clone_vram_rdata(clone_vram_rdata),
        .clone_vram_start(clone_vram_start),
        .clone_vram_busy(clone_vram_busy),
        .press_key_id(press_key_id),
        .press_key_id_valid(press_key_id_valid),
        .reg_addr(reg_addr),
        .reg_wdata(reg_wdata),
        .reg_we(reg_we),
        .reg_rdata(reg_rdata)
    );
    
    fwft_fifo #(
        .WIDTH(UART_PROTOCOL_SEND_PACKET_BYTE_LENGTH * 8),
        .DEPTH(256)
    )fwft_fifo_uart_protocol_send_inst(
        .clk(clk),
        .rst(rst),
        .data_in(fifo_send_packet),
        .push(fifo_send_packet_valid),
        .full(fifo_send_packet_full),
        .flush(1'b0),
        .data_out(send_packet),
        .data_out_valid(send_packet_valid),
        .pop(send_packet_pop)
    );
    
    register_controller #(
        .ADDR_WIDTH(REG_ADDR_WIDTH),
        .DATA_WIDTH(REG_DATA_WIDTH),
        .LCD_BRIGHT_WIDTH(LCD_BRIGHT_WIDTH),
        .PWM_DUTY_RATIO_WIDTH(PWM_DUTY_RATIO_WIDTH),
        .MAIN_FAN_NUM(MAIN_FAN_NUM)
    )register_controller_inst(
        .clk(clk),
        .rst(rst),
        .addr(reg_addr),
        .wdata(reg_wdata),
        .we(reg_we),
        .rdata(reg_rdata),
        .main_fan_pwm_duty_ratio_wdata(main_fan_pwm_duty_ratio_reg_wdata),
        .main_fan_pwm_duty_ratio_we(main_fan_pwm_duty_ratio_reg_we),
        .main_fan_pwm_duty_ratio_rdata(main_fan_pwm_duty_ratio),
        .bright_wdata(bright_in),
        .bright_we(bright_in_valid),
        .bright_rdata(bright),
        .page_id_wdata(reg_page_id_wdata),
        .page_id_we(reg_page_id_we),
        .page_id_rdata(page_id)
    );

    key_controller #(
        .CLK_FREQ(CLK_FREQ)
    )key_controller_inst(
        .clk(clk),
        .rst(rst),
        .press_key_id(press_key_id),
        .press_key_id_valid(press_key_id_valid),
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
        .CHAR_WIDTH(CHAR_WIDTH),
        .CHAR_HEIGHT(CHAR_HEIGHT),
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
        .bright_in(bright_in),
        .bright_in_valid(bright_in_valid),
        .bright(bright),
        .page_id_in(page_id_in),
        .page_id_in_valid(page_id_in_valid),
        .page_id(page_id),
        .page_config_addr(page_config_addr),
        .page_config_data(page_config_data),
        .clone_vram_raddr(clone_vram_raddr),
        .clone_vram_rdata(clone_vram_rdata),
        .clone_vram_start(clone_vram_start),
        .clone_vram_busy(clone_vram_busy)
    );
    
    page_switcher page_switcher_inst(
        .page_id(page_id),
        .page_id_wdata(page_switcher_page_id_wdata),
        .page_id_we(page_switcher_page_id_we),
        .key_page_prev_pulse(key_page_prev_pulse),
        .key_page_next_pulse(key_page_next_pulse),
        .reg_page_id_wdata(reg_page_id_wdata),
        .reg_page_id_we(reg_page_id_we)
    );
    
    page_message_controller #(
        .CLK_FREQ(CLK_FREQ)
    )page_message_controller_inst(
        .clk(clk),
        .rst(rst),
        .page_id(page_id),
        .page_id_wdata_in(page_switcher_page_id_wdata),
        .page_id_we_in(page_switcher_page_id_we),
        .page_id_wdata(page_id_in),
        .page_id_we(page_id_in_valid),
        .key_save_pulse(key_save_pulse),
        .key_load_pulse(key_load_pulse),
        .eeprom_save_done(eeprom_save_done),
        .eeprom_load_done(eeprom_load_data_valid),
        .eeprom_busy(eeprom_busy),
        .eeprom_error(eeprom_error)
    );

    page_manager #(
        .MAIN_FAN_NUM(MAIN_FAN_NUM)
    )page_manager_inst(
        .page_id(page_id),
        .page_config_data(page_config_data),
        .page_main_config_data(page_main_config_data),
        .page_cisco_config_data(page_cisco_config_data),
        .page_main_fan_config_data(page_main_fan_config_data),
        .page_message_config_data(page_message_config_data)
    );

    lcd_page_main_ui #(
        .CONFIG_ADDR_WIDTH(CONFIG_ADDR_WIDTH),
        .LCD_PIXEL_LINE_NUM(LCD_PIXEL_LINE_NUM),
        .LCD_PIXEL_COL_NUM(LCD_PIXEL_COL_NUM),
        .CHAR_WIDTH(CHAR_WIDTH),
        .CHAR_HEIGHT(CHAR_HEIGHT)
    )lcd_page_main_inst(
        .clk(clk),
        .rst(rst),
        .config_addr(page_config_addr),
        .config_data(page_main_config_data)
    );
    
    lcd_page_cisco_ui #(
        .CONFIG_ADDR_WIDTH(CONFIG_ADDR_WIDTH),
        .LCD_PIXEL_LINE_NUM(LCD_PIXEL_LINE_NUM),
        .LCD_PIXEL_COL_NUM(LCD_PIXEL_COL_NUM),
        .CHAR_WIDTH(CHAR_WIDTH),
        .CHAR_HEIGHT(CHAR_HEIGHT)
    )lcd_page_cisco_inst(
        .clk(clk),
        .rst(rst),
        .config_addr(page_config_addr),
        .config_data(page_cisco_config_data),
        .cisco_led_status_green(cisco_led_status_green_sync),
        .cisco_led_status_red(cisco_led_status_red_sync),
        .cisco_fan1234_pwm_duty_ratio(cisco_fan1234_pwm_duty_ratio),
        .cisco_fan5678_pwm_duty_ratio(cisco_fan5678_pwm_duty_ratio),
        .cisco_fan1234_rpm(cisco_fan1234_rpm),
        .cisco_fan5678_rpm(cisco_fan5678_rpm)
    );
    
    lcd_page_main_fan_ui #(
        .CONFIG_ADDR_WIDTH(CONFIG_ADDR_WIDTH),
        .LCD_PIXEL_LINE_NUM(LCD_PIXEL_LINE_NUM),
        .LCD_PIXEL_COL_NUM(LCD_PIXEL_COL_NUM),
        .CHAR_WIDTH(CHAR_WIDTH),
        .CHAR_HEIGHT(CHAR_HEIGHT),
        .PWM_DUTY_RATIO_WIDTH(PWM_DUTY_RATIO_WIDTH),
        .RPM_WIDTH(RPM_WIDTH),
        .MAIN_FAN_NUM(MAIN_FAN_NUM)
    )lcd_page_main_fan_ui_inst(
        .clk(clk),
        .rst(rst),
        .config_addr(page_config_addr),
        .config_data(page_main_fan_config_data),
        .page_id(page_id),
        .key_add_pulse(key_add_pulse),
        .key_sub_pulse(key_sub_pulse),
        .main_fan_pwm_duty_ratio_wdata(main_fan_pwm_duty_ratio_main_wdata),
        .main_fan_pwm_duty_ratio_we(main_fan_pwm_duty_ratio_main_we),
        .main_fan_pwm_duty_ratio(main_fan_pwm_duty_ratio),
        .main_fan_rpm(main_fan_rpm)
    );
    
    lcd_page_message_ui #(
        .CONFIG_ADDR_WIDTH(CONFIG_ADDR_WIDTH),
        .LCD_PIXEL_LINE_NUM(LCD_PIXEL_LINE_NUM),
        .LCD_PIXEL_COL_NUM(LCD_PIXEL_COL_NUM),
        .CHAR_WIDTH(CHAR_WIDTH),
        .CHAR_HEIGHT(CHAR_HEIGHT)
    )lcd_page_message_ui_inst(
        .clk(clk),
        .rst(rst),
        .page_id(page_id),
        .config_addr(page_config_addr),
        .config_data(page_message_config_data)
    );
endmodule