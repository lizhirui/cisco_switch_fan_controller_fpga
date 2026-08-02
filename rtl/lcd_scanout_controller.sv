`default_nettype none

module lcd_scanout_controller #(
        parameter CLK_FREQ = 50000000,
        parameter LCD_PIXEL_LINE_NUM = 64,
        parameter LCD_PIXEL_COL_NUM = 128,
        parameter DATA_WIDTH = 8,
        parameter ADDR_WIDTH = (LCD_PIXEL_LINE_NUM * LCD_PIXEL_COL_NUM / DATA_WIDTH <= 1) ? 1 : $clog2(LCD_PIXEL_LINE_NUM * LCD_PIXEL_COL_NUM / DATA_WIDTH)
    )(
        input logic clk,
        input logic rst,

        output logic phy_rs,
        output logic[DATA_WIDTH - 1:0] phy_db,
        output logic phy_start,
        input logic phy_busy,
        
        output logic[ADDR_WIDTH - 1:0] vram_addr,
        input logic[DATA_WIDTH - 1:0] vram_data,
        output logic frame_end 
    );

    logic[DATA_WIDTH - 1:0] reader_out_data;
    logic reader_out_data_push;
    logic reader_out_data_full;
    logic[DATA_WIDTH - 1:0] transposer_in_data;
    logic transposer_in_data_valid;
    logic transposer_in_data_pop;
    logic[DATA_WIDTH - 1:0] transposer_out_data;
    logic transposer_out_data_push;
    logic transposer_out_data_full;
    logic[DATA_WIDTH - 1:0] command_generator_data;
    logic command_generator_data_valid;
    logic command_generator_data_pop;
    
    lcd_vram_reader #(
        .LCD_PIXEL_LINE_NUM(LCD_PIXEL_LINE_NUM),
        .LCD_PIXEL_COL_NUM(LCD_PIXEL_COL_NUM),
        .DATA_WIDTH(DATA_WIDTH)
    )lcd_vram_reader(
        .clk(clk),
        .rst(rst),
        .vram_addr(vram_addr),
        .vram_data(vram_data),
        .frame_end(frame_end),
        .out_data(reader_out_data),
        .out_data_push(reader_out_data_push),
        .out_data_full(reader_out_data_full)
    );

    fwft_fifo #(
        .WIDTH(DATA_WIDTH),
        .DEPTH(DATA_WIDTH)
    )fwft_fifo_transposer_input_inst(
        .clk(clk),
        .rst(rst),
        .data_in(reader_out_data),
        .push(reader_out_data_push),
        .full(reader_out_data_full),
        .flush(1'b0),
        .data_out(transposer_in_data),
        .data_out_valid(transposer_in_data_valid),
        .pop(transposer_in_data_pop),
        .empty()
    );

    lcd_data_transposer #(
        .DATA_WIDTH(DATA_WIDTH),
        .SIDE_DATA_WIDTH(1)
    )lcd_data_transposer_inst(
        .clk(clk),
        .rst(rst),
        .in_data(transposer_in_data),
        .in_side_data(1'b0),
        .in_data_valid(transposer_in_data_valid),
        .in_data_pop(transposer_in_data_pop),
        .out_data(transposer_out_data),
        .out_side_data(),
        .out_data_push(transposer_out_data_push),
        .out_data_full(transposer_out_data_full),
        .idle()
    );

    fwft_fifo #(
        .WIDTH(DATA_WIDTH),
        .DEPTH(DATA_WIDTH)
    )fwft_fifo_transposer_output_inst(
        .clk(clk),
        .rst(rst),
        .data_in(transposer_out_data),
        .push(transposer_out_data_push),
        .full(transposer_out_data_full),
        .flush(1'b0),
        .data_out(command_generator_data),
        .data_out_valid(command_generator_data_valid),
        .pop(command_generator_data_pop),
        .empty()
    );

    lcd_command_generator #(
        .CLK_FREQ(CLK_FREQ),
        .LCD_PIXEL_LINE_NUM(LCD_PIXEL_LINE_NUM),
        .LCD_PIXEL_COL_NUM(LCD_PIXEL_COL_NUM),
        .DATA_WIDTH(DATA_WIDTH)
    )lcd_command_generator_inst(
        .clk(clk),
        .rst(rst),
        .vram_data(command_generator_data),
        .vram_data_valid(command_generator_data_valid),
        .vram_data_pop(command_generator_data_pop),
        .phy_rs(phy_rs),
        .phy_db(phy_db),
        .phy_start(phy_start),
        .phy_busy(phy_busy)
    );
endmodule