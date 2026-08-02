`default_nettype none

module uart_receiver #(
        parameter CLOCK_FREQUENCY = 50000000,
        parameter BAUD_RATE = 2500000,
        parameter DATA_WIDTH = 8
    )(
        input logic clk,
        input logic rst,
        
        input logic rxd,
        output logic[DATA_WIDTH - 1:0] rx_data,
        output logic rx_data_valid,
        output logic rx_error
    );
    
    localparam CLOCKS_PER_BIT = CLOCK_FREQUENCY / BAUD_RATE;
    localparam HALF_CLOCKS_PER_BIT = CLOCKS_PER_BIT / 2;
    localparam BAUD_COUNT_WIDTH = (CLOCKS_PER_BIT <= 1) ? 1 : $clog2(CLOCKS_PER_BIT);
    localparam DATA_BIT_COUNT_WIDTH = (DATA_WIDTH <= 1) ? 1 : $clog2(DATA_WIDTH);
    
    localparam logic[BAUD_COUNT_WIDTH - 1:0] BAUD_COUNT_LAST = BAUD_COUNT_WIDTH'(CLOCKS_PER_BIT - 1);
    localparam logic[BAUD_COUNT_WIDTH - 1:0] HALF_BAUD_COUNT_LAST = BAUD_COUNT_WIDTH'(HALF_CLOCKS_PER_BIT - 1);
    localparam logic[DATA_BIT_COUNT_WIDTH - 1:0] DATA_BIT_COUNT_LAST = DATA_BIT_COUNT_WIDTH'(DATA_WIDTH - 1);
    
    localparam STATE_WIDTH = 3;
    localparam logic[STATE_WIDTH - 1:0] STATE_IDLE = STATE_WIDTH'('d0);
    localparam logic[STATE_WIDTH - 1:0] STATE_START = STATE_WIDTH'('d1);
    localparam logic[STATE_WIDTH - 1:0] STATE_DATA = STATE_WIDTH'('d2);
    localparam logic[STATE_WIDTH - 1:0] STATE_STOP = STATE_WIDTH'('d3);
    localparam logic[STATE_WIDTH - 1:0] STATE_DONE = STATE_WIDTH'('d4);
    localparam logic[STATE_WIDTH - 1:0] STATE_ERROR = STATE_WIDTH'('d5);
    
    logic[STATE_WIDTH - 1:0] cur_state;
    logic[STATE_WIDTH - 1:0] next_state;
    
    logic rxd_meta;
    logic rxd_sync;
    logic rxd_sync_loaded;
    logic rxd_fall;
    
    logic[BAUD_COUNT_WIDTH - 1:0] baud_count;
    logic baud_count_done;
    
    logic[DATA_BIT_COUNT_WIDTH - 1:0] data_bit_count;
    logic data_bit_last;
    logic[DATA_WIDTH - 1:0] rx_data_loaded;
    
    always_ff @(posedge clk) begin
        if(rst) begin
            cur_state <= STATE_IDLE;
        end
        else begin
            cur_state <= next_state;
        end
    end
    
    always_comb begin
        next_state = cur_state;
        
        case(cur_state)
            STATE_IDLE: begin
                if(rxd_fall) begin
                    next_state = STATE_START;
                end
            end
            
            STATE_START: begin
                if(baud_count_done) begin
                    if(!rxd_sync) begin
                        next_state = STATE_DATA;
                    end
                    else begin
                        next_state = STATE_ERROR;
                    end
                end
            end
            
            STATE_DATA: begin
                if(baud_count_done && data_bit_last) begin
                    next_state = STATE_STOP;
                end
            end
            
            STATE_STOP: begin
                if(baud_count_done) begin
                    if(rxd_sync) begin
                        next_state = STATE_DONE;
                    end
                    else begin
                        next_state = STATE_ERROR;
                    end
                end
            end
            
            STATE_DONE: begin
                next_state = STATE_IDLE;
            end
            
            STATE_ERROR: begin
                next_state = STATE_IDLE;
            end
        endcase
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            rx_data <= '0;
        end
        else if((cur_state == STATE_STOP) && ((next_state == STATE_DONE) || (next_state == STATE_ERROR))) begin
            rx_data <= rx_data_loaded;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            rx_data_valid <= 1'b0;
        end
        else if((cur_state != STATE_DONE) && (next_state == STATE_DONE)) begin
            rx_data_valid <= 1'b1;
        end
        else begin
            rx_data_valid <= 1'b0;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            rx_error <= 1'b0;
        end
        else if((cur_state != STATE_ERROR) && (next_state == STATE_ERROR)) begin
            rx_error <= 1'b1;
        end
        else begin
            rx_error <= 1'b0;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            rxd_meta <= 1'b1;
            rxd_sync <= 1'b1;
            rxd_sync_loaded <= 1'b1;
        end
        else begin
            rxd_meta <= rxd;
            rxd_sync <= rxd_meta;
            rxd_sync_loaded <= rxd_sync;
        end
    end
    
    assign rxd_fall = (rxd_sync_loaded && !rxd_sync) ? 1'b1 : 1'b0;
    
    always_ff @(posedge clk) begin
        if(rst) begin
            baud_count <= '0;
        end
        else if((cur_state != STATE_START) && (cur_state != STATE_DATA) && (cur_state != STATE_STOP)) begin
            baud_count <= '0;
        end
        else if(baud_count_done) begin
            baud_count <= '0;
        end
        else begin
            baud_count <= baud_count + 'b1;
        end
    end
    
    assign baud_count_done = (cur_state == STATE_START) ? ((baud_count == HALF_BAUD_COUNT_LAST) ? 1'b1 : 1'b0) : ((baud_count == BAUD_COUNT_LAST) ? 1'b1 : 1'b0);
    
    always_ff @(posedge clk) begin
        if(rst) begin
            data_bit_count <= '0;
        end
        else if((cur_state == STATE_START) && (next_state == STATE_DATA)) begin
            data_bit_count <= '0;
        end
        else if((cur_state == STATE_DATA) && baud_count_done && !data_bit_last) begin
            data_bit_count <= data_bit_count + 'b1;
        end
    end
    
    assign data_bit_last = (data_bit_count == DATA_BIT_COUNT_LAST) ? 1'b1 : 1'b0;
    
    always_ff @(posedge clk) begin
        if(rst) begin
            rx_data_loaded <= '0;
        end
        else if((cur_state == STATE_DATA) && baud_count_done) begin
            rx_data_loaded[data_bit_count] <= rxd_sync;
        end
    end
endmodule