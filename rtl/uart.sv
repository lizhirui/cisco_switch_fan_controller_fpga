`default_nettype none

module uart #(
        parameter CLOCK_FREQUENCY = 50000000,
        parameter BAUD_RATE = 2500000,
        parameter DATA_WIDTH = 8
    )(
        input logic clk,
        input logic rst,
        
        input logic rxd,
        output logic[DATA_WIDTH - 1:0] rx_data,
        output logic rx_data_valid,
        output logic rx_error,
        
        output logic txd,
        input logic[DATA_WIDTH - 1:0] tx_data,
        input logic tx_start,
        output logic tx_busy
    );
    
    uart_receiver #(
        .CLOCK_FREQUENCY(CLOCK_FREQUENCY),
        .BAUD_RATE(BAUD_RATE),
        .DATA_WIDTH(DATA_WIDTH)
    )uart_receiver_inst(
        .clk(clk),
        .rst(rst),
        .rxd(rxd),
        .rx_data(rx_data),
        .rx_data_valid(rx_data_valid),
        .rx_error(rx_error)
    );
    
    uart_transmitter #(
        .CLOCK_FREQUENCY(CLOCK_FREQUENCY),
        .BAUD_RATE(BAUD_RATE),
        .DATA_WIDTH(DATA_WIDTH)
    )uart_transmitter_inst(
        .clk(clk),
        .rst(rst),
        .txd(txd),
        .tx_data(tx_data),
        .tx_start(tx_start),
        .tx_busy(tx_busy)
    );
endmodule