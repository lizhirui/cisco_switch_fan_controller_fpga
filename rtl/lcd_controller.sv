`default_nettype none

import lcd_ui_config_pkg::*;
import lcd_ui_page_config_pkg::*;
import lcd_font_stream_pkg::*;

module lcd_controller #(
        parameter CLK_FREQ = 50000000,
        parameter LCD_BRIGHT_WIDTH = 8,
        parameter LCD_PIXEL_LINE_NUM = 64,
        parameter LCD_PIXEL_COL_NUM = 128,
        parameter LCD_DATA_WIDTH = 8,
        parameter CHAR_WIDTH = 8,
        parameter CHAR_HEIGHT = 16,
        parameter LCD_LINE_NUM = LCD_PIXEL_LINE_NUM / CHAR_HEIGHT,
        parameter LCD_COL_NUM = LCD_PIXEL_COL_NUM / CHAR_WIDTH,
        parameter CONFIG_ADDR_WIDTH = 4,
        parameter VRAM_DEPTH = LCD_PIXEL_LINE_NUM * LCD_PIXEL_COL_NUM / LCD_DATA_WIDTH,
        parameter VRAM_ADDR_WIDTH = (VRAM_DEPTH <= 1) ? 1 : $clog2(VRAM_DEPTH),
        parameter ENABLE_DRAW_BITMAP = 1'b0
    )(
        input logic clk,
        input logic rst,

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

        input logic key_bright_up_pulse,
        input logic key_bright_down_pulse,
        input logic key_lcd_openclose_pulse,

        input logic[LCD_BRIGHT_WIDTH - 1:0] bright_in,
        input logic bright_in_valid,

        output logic[LCD_BRIGHT_WIDTH - 1:0] bright,

        input logic[PAGE_ID_WIDTH - 1:0] page_id_in,
        input logic page_id_in_valid,

        output logic[PAGE_ID_WIDTH - 1:0] page_id,
        output logic[CONFIG_ADDR_WIDTH - 1:0] page_config_addr,
        input lcd_ui_config_data_t page_config_data,
        
        input logic[VRAM_ADDR_WIDTH - 1:0] clone_vram_raddr,
        output logic[LCD_DATA_WIDTH - 1:0] clone_vram_rdata,
        input logic clone_vram_start,
        output logic clone_vram_busy
    );
    
    localparam ROM_ADDR_WIDTH = 24;
    
    logic ui_config_start;
    logic ui_config_busy;
    lcd_ui_config_data_t ui_config_data;
    lcd_ui_x_t char_x;
    lcd_ui_y_t char_y;
    lcd_ui_color_t char_color;
    logic ui_draw_writer_start;
    logic ui_draw_writer_busy;
    lcd_ui_config_data_t ui_draw_writer_config_data;
    logic[ROM_ADDR_WIDTH - 1:0] rom_reader_addr;
    lcd_font_data_len_t rom_reader_len;
    logic rom_reader_start;
    logic rom_reader_busy;
    lcd_font_data_t rom_reader_data;
    lcd_font_data_len_t rom_reader_data_len;
    logic rom_reader_data_valid;
    logic rom_reader_data_full;
    lcd_font_stream_data_t font_raw_fifo_data_in;
    lcd_font_stream_data_t font_raw_fifo_data_out;
    logic font_raw_fifo_data_out_valid;
    logic font_raw_fifo_data_pop;
    logic font_raw_fifo_empty;
    lcd_font_data_t font_transposer_out_data;
    lcd_font_stream_data_t font_transposed_fifo_data_in;
    lcd_font_stream_data_t font_transposed_fifo_data_out;
    lcd_font_side_data_t font_transposer_out_side_data;
    logic font_transposer_out_push;
    logic font_transposer_out_full;
    logic font_transposer_idle;
    logic font_transposed_fifo_empty;
    logic vwcw_wdata_valid;
    logic vwcw_wdata_pop;
    logic[VRAM_ADDR_WIDTH - 1:0] font_vwc_raddr;
    logic[VRAM_ADDR_WIDTH - 1:0] font_vwc_waddr;
    logic[LCD_DATA_WIDTH - 1:0] font_vwc_wdata;
    logic font_vwc_we;
    logic[VRAM_ADDR_WIDTH - 1:0] draw_vwc_raddr;
    logic[VRAM_ADDR_WIDTH - 1:0] draw_vwc_waddr;
    logic[LCD_DATA_WIDTH - 1:0] draw_vwc_wdata;
    logic draw_vwc_we;
    logic[VRAM_ADDR_WIDTH - 1:0] vwc_raddr;
    logic[LCD_DATA_WIDTH - 1:0] vwc_rdata;
    logic[VRAM_ADDR_WIDTH - 1:0] vwc_waddr;
    logic[LCD_DATA_WIDTH - 1:0] vwc_wdata;
    logic vwc_we;
    logic vwc_busy;
    logic vwc_submit;
    logic vwcw_idle;
    logic[VRAM_ADDR_WIDTH - 1:0] vram_waddr;
    logic[LCD_DATA_WIDTH - 1:0] vram_wdata;
    logic vram_we;
    logic vram_submit;
    logic vram_submitting;
    logic render_pipeline_idle;
    logic[VRAM_ADDR_WIDTH - 1:0] vram_raddr;
    logic[LCD_DATA_WIDTH - 1:0] vram_rdata;
    logic vram_switch;
    logic phy_rs_in;
    logic[LCD_DATA_WIDTH - 1:0] phy_db_in;
    logic phy_start;
    logic phy_busy;

    lcd_bright_controller #(
        .CLK_FREQ(CLK_FREQ),
        .LCD_PWM_FREQ(20000),
        .LCD_BRIGHT_WIDTH(LCD_BRIGHT_WIDTH)
    )lcd_bright_controller_inst(
        .clk(clk),
        .rst(rst),
        .lcd_leda_pwm(lcd_leda_pwm),
        .key_bright_up_pulse(key_bright_up_pulse),
        .key_bright_down_pulse(key_bright_down_pulse),
        .key_lcd_openclose_pulse(key_lcd_openclose_pulse),
        .bright_in(bright_in),
        .bright_in_valid(bright_in_valid),
        .bright(bright)
    );

    lcd_ui_config_processor #(
        .CONFIG_ADDR_WIDTH(CONFIG_ADDR_WIDTH)
    )lcd_ui_config_processor_inst(
        .clk(clk),
        .rst(rst),
        .start(1'b1),
        .busy(),
        .page_id_in(page_id_in),
        .page_id_in_valid(page_id_in_valid),
        .page_id(page_id),
        .page_config_addr(page_config_addr),
        .page_config_data(page_config_data),
        .config_start(ui_config_start),
        .config_busy(ui_config_busy),
        .config_data(ui_config_data)
    );
    
    lcd_ui_renderer #(
        .LCD_PIXEL_LINE_NUM(LCD_PIXEL_LINE_NUM),
        .LCD_PIXEL_COL_NUM(LCD_PIXEL_COL_NUM),
        .ROM_ADDR_WIDTH(ROM_ADDR_WIDTH),
        .ENABLE_DRAW_BITMAP(ENABLE_DRAW_BITMAP)
    )lcd_ui_renderer_inst(
        .clk(clk),
        .rst(rst),
        .config_start(ui_config_start),
        .config_busy(ui_config_busy),
        .config_data(ui_config_data),
        .rom_reader_addr(rom_reader_addr),
        .rom_reader_len(rom_reader_len),
        .rom_reader_start(rom_reader_start),
        .rom_reader_busy(rom_reader_busy),
        .char_x(char_x),
        .char_y(char_y),
        .char_color(char_color),
        .draw_writer_start(ui_draw_writer_start),
        .draw_writer_busy(ui_draw_writer_busy),
        .draw_writer_config_data(ui_draw_writer_config_data),
        .render_pipeline_idle(render_pipeline_idle),
        .frame_submit(vwc_submit),
        .frame_submit_busy(vwc_busy)
    );

    lcd_rom_reader #(
        .CLK_FREQ(CLK_FREQ),
        .FREQ_DIVIDE(1),
        .ADDR_WIDTH(ROM_ADDR_WIDTH),
        .DATA_WIDTH(LCD_FONT_DATA_WIDTH),
        .LEN_WIDTH(LCD_FONT_DATA_LEN_WIDTH)
    )lcd_rom_reader_inst(
        .clk(clk),
        .rst(rst),
        .lcd_rom_cs(lcd_rom_cs),
        .lcd_rom_sck(lcd_rom_sck),
        .lcd_rom_si(lcd_rom_si),
        .lcd_rom_so(lcd_rom_so),
        .addr(rom_reader_addr),
        .len(rom_reader_len),
        .start(rom_reader_start),
        .busy(rom_reader_busy),
        .data(rom_reader_data),
        .data_len(rom_reader_data_len),
        .data_valid(rom_reader_data_valid),
        .data_full(rom_reader_data_full)
    );
    
    assign font_raw_fifo_data_in.side_data.char_x = char_x;
    assign font_raw_fifo_data_in.side_data.char_y = char_y;
    assign font_raw_fifo_data_in.side_data.char_color = char_color;
    assign font_raw_fifo_data_in.side_data.data_len = rom_reader_data_len;
    assign font_raw_fifo_data_in.data = rom_reader_data;

    fwft_fifo #(
        .WIDTH(LCD_FONT_STREAM_DATA_WIDTH),
        .DEPTH(LCD_FONT_DATA_WIDTH)
    )fwft_fifo_font_raw_inst(
        .clk(clk),
        .rst(rst),
        .data_in(font_raw_fifo_data_in),
        .push(rom_reader_data_valid),
        .full(rom_reader_data_full),
        .flush(1'b0),
        .data_out(font_raw_fifo_data_out),
        .data_out_valid(font_raw_fifo_data_out_valid),
        .pop(font_raw_fifo_data_pop),
        .empty(font_raw_fifo_empty)
    );

    lcd_data_transposer #(
        .DATA_WIDTH(LCD_FONT_DATA_WIDTH),
        .SIDE_DATA_WIDTH(LCD_FONT_SIDE_DATA_WIDTH) 
    )lcd_data_transposer_font_data_inst(
        .clk(clk),
        .rst(rst),
        .in_data(font_raw_fifo_data_out.data),
        .in_side_data(font_raw_fifo_data_out.side_data),
        .in_data_valid(font_raw_fifo_data_out_valid),
        .in_data_pop(font_raw_fifo_data_pop),
        .out_data(font_transposer_out_data),
        .out_side_data(font_transposer_out_side_data),
        .out_data_push(font_transposer_out_push),
        .out_data_full(font_transposer_out_full),
        .idle(font_transposer_idle)
    );
    
    assign font_transposed_fifo_data_in.side_data = font_transposer_out_side_data;
    assign font_transposed_fifo_data_in.data = font_transposer_out_data;

    fwft_fifo #(
        .WIDTH(LCD_FONT_STREAM_DATA_WIDTH),
        .DEPTH(32)
    )fwft_fifo_font_transposed_inst(
        .clk(clk),
        .rst(rst),
        .data_in(font_transposed_fifo_data_in),
        .push(font_transposer_out_push),
        .full(font_transposer_out_full),
        .flush(1'b0),
        .data_out(font_transposed_fifo_data_out),
        .data_out_valid(vwcw_wdata_valid),
        .pop(vwcw_wdata_pop),
        .empty(font_transposed_fifo_empty)
    );

    vram_write_controller_writer #(
        .LCD_PIXEL_LINE_NUM(LCD_PIXEL_LINE_NUM),
        .LCD_PIXEL_COL_NUM(LCD_PIXEL_COL_NUM),
        .VRAM_ADDR_WIDTH(VRAM_ADDR_WIDTH)
    )vram_write_controller_writer_inst(
        .clk(clk),
        .rst(rst),
        .wdata(font_transposed_fifo_data_out),
        .wdata_valid(vwcw_wdata_valid),
        .wdata_pop(vwcw_wdata_pop),
        .vwc_raddr(font_vwc_raddr),
        .vwc_rdata(vwc_rdata),
        .vwc_waddr(font_vwc_waddr),
        .vwc_wdata(font_vwc_wdata),
        .vwc_we(font_vwc_we),
        .vwc_busy(vwc_busy),
        .idle(vwcw_idle)
    );
    
    lcd_ui_draw_writer #(
        .LCD_PIXEL_LINE_NUM(LCD_PIXEL_LINE_NUM),
        .LCD_PIXEL_COL_NUM(LCD_PIXEL_COL_NUM),
        .VRAM_ADDR_WIDTH(VRAM_ADDR_WIDTH),
        .VRAM_DATA_WIDTH(LCD_DATA_WIDTH),
        .ENABLE_DRAW_BITMAP(ENABLE_DRAW_BITMAP)
    )lcd_ui_draw_writer_inst(
        .clk(clk),
        .rst(rst),
        .start(ui_draw_writer_start),
        .busy(ui_draw_writer_busy),
        .config_data(ui_draw_writer_config_data),
        .vwc_raddr(draw_vwc_raddr),
        .vwc_rdata(vwc_rdata),
        .vwc_waddr(draw_vwc_waddr),
        .vwc_wdata(draw_vwc_wdata),
        .vwc_we(draw_vwc_we),
        .vwc_busy(vwc_busy)
    );
    
    assign vwc_raddr = ui_draw_writer_busy ? draw_vwc_raddr : font_vwc_raddr;
    assign vwc_waddr = ui_draw_writer_busy ? draw_vwc_waddr : font_vwc_waddr;
    assign vwc_wdata = ui_draw_writer_busy ? draw_vwc_wdata : font_vwc_wdata;
    assign vwc_we = ui_draw_writer_busy ? draw_vwc_we : font_vwc_we;
    
    assign render_pipeline_idle = (!rom_reader_busy && font_raw_fifo_empty && font_transposer_idle && font_transposed_fifo_empty && vwcw_idle && !ui_draw_writer_busy && !vwc_busy) ? 1'b1 : 1'b0;

    vram_write_controller #(
        .VRAM_ADDR_WIDTH(VRAM_ADDR_WIDTH),
        .VRAM_DATA_WIDTH(LCD_DATA_WIDTH)
    )vram_write_controller_inst(
        .clk(clk),
        .rst(rst),
        .vwc_waddr(vwc_waddr),
        .vwc_wdata(vwc_wdata),
        .vwc_we(vwc_we),
        .vwc_submit(vwc_submit),
        .vwc_busy(vwc_busy),
        .vram_waddr(vram_waddr),
        .vram_wdata(vram_wdata),
        .vram_we(vram_we),
        .vram_submit(vram_submit),
        .vram_submitting(vram_submitting)
    );

    double_buffered_vram #(
        .ADDR_WIDTH(VRAM_ADDR_WIDTH),
        .DATA_WIDTH(LCD_DATA_WIDTH)
    )double_buffered_vram(
        .clk(clk),
        .rst(rst),
        .waddr(vram_waddr),
        .wdata(vram_wdata),
        .we(vram_we),
        .write_buffer_raddr(vwc_raddr),
        .write_buffer_rdata(vwc_rdata),
        .submit(vram_submit),
        .submitting(vram_submitting),
        .raddr(vram_raddr),
        .rdata(vram_rdata),
        .switch(vram_switch),
        .clone_vram_raddr(clone_vram_raddr),
        .clone_vram_rdata(clone_vram_rdata),
        .clone_vram_start(clone_vram_start),
        .clone_vram_busy(clone_vram_busy)
    );

    lcd_scanout_controller #(
        .CLK_FREQ(CLK_FREQ),
        .LCD_PIXEL_LINE_NUM(LCD_PIXEL_LINE_NUM),
        .LCD_PIXEL_COL_NUM(LCD_PIXEL_COL_NUM),
        .DATA_WIDTH(LCD_DATA_WIDTH)
    )lcd_scanout_controller_inst(
        .clk(clk),
        .rst(rst),
        .phy_rs(phy_rs_in),
        .phy_db(phy_db_in),
        .phy_start(phy_start),
        .phy_busy(phy_busy),
        .vram_addr(vram_raddr),
        .vram_data(vram_rdata),
        .frame_end(vram_switch)
    );

    lcd_phy #(
        .CLK_FREQ(CLK_FREQ),
        .FREQ_DIVIDE(2),
        .DATA_WIDTH(LCD_DATA_WIDTH)
    )lcd_phy_inst(
        .clk(clk),
        .rst(rst),
        .lcd_rst(lcd_rst),
        .lcd_cs(lcd_cs),
        .lcd_rs(lcd_rs),
        .lcd_sclk(lcd_sclk),
        .lcd_sda(lcd_sda),
        .rs_in(phy_rs_in),
        .db_in(phy_db_in),
        .start(phy_start),
        .busy(phy_busy)
    );
endmodule