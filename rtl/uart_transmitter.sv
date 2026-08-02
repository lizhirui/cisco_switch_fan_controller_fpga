`default_nettype none

module uart_transmitter #(
        parameter CLOCK_FREQUENCY = 50000000,
        parameter BAUD_RATE = 2500000,
        parameter DATA_WIDTH = 8
    )(
        input logic clk,
        input logic rst,
        
        output logic txd,
        input logic[DATA_WIDTH - 1:0] tx_data,
        input logic tx_start,
        output logic tx_busy
    );
    
    localparam CLOCKS_PER_BIT = CLOCK_FREQUENCY / BAUD_RATE;
    localparam BAUD_COUNT_WIDTH = (CLOCKS_PER_BIT <= 1) ? 1 : $clog2(CLOCKS_PER_BIT);
    localparam DATA_BIT_COUNT_WIDTH = (DATA_WIDTH <= 1) ? 1 : $clog2(DATA_WIDTH);
    
    localparam logic[BAUD_COUNT_WIDTH - 1:0] BAUD_COUNT_LAST = BAUD_COUNT_WIDTH'(CLOCKS_PER_BIT - 1);
    localparam logic[DATA_BIT_COUNT_WIDTH - 1:0] DATA_BIT_COUNT_LAST = DATA_BIT_COUNT_WIDTH'(DATA_WIDTH - 1);
    
    localparam STATE_WIDTH = 2;
    localparam logic[STATE_WIDTH - 1:0] STATE_IDLE = STATE_WIDTH'('d0);
    localparam logic[STATE_WIDTH - 1:0] STATE_START = STATE_WIDTH'('d1);
    localparam logic[STATE_WIDTH - 1:0] STATE_DATA = STATE_WIDTH'('d2);
    localparam logic[STATE_WIDTH - 1:0] STATE_STOP = STATE_WIDTH'('d3);
    
    logic[STATE_WIDTH - 1:0] cur_state;
    logic[STATE_WIDTH - 1:0] next_state;
    
    logic[BAUD_COUNT_WIDTH - 1:0] baud_count;
    logic baud_count_done;
    
    logic[DATA_BIT_COUNT_WIDTH - 1:0] data_bit_count;
    logic data_bit_last;
    logic[DATA_WIDTH - 1:0] tx_data_loaded;
    
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
                if(tx_start) begin
                    next_state = STATE_START;
                end
            end
            
            STATE_START: begin
                if(baud_count_done) begin
                    next_state = STATE_DATA;
                end
            end
            
            STATE_DATA: begin
                if(baud_count_done && data_bit_last) begin
                    next_state = STATE_STOP;
                end
            end
            
            STATE_STOP: begin
                if(baud_count_done) begin
                    next_state = STATE_IDLE;
                end
            end
        endcase
    end
    
    always_comb begin
        txd = 1'b1;
        
        case(cur_state)
            STATE_START: begin
                txd = 1'b0;
            end
            
            STATE_DATA: begin
                txd = tx_data_loaded[data_bit_count];
            end
        endcase
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            tx_busy <= 1'b0;
        end
        else if((cur_state == STATE_IDLE) && (next_state != STATE_IDLE)) begin
            tx_busy <= 1'b1;
        end
        else if((cur_state != STATE_IDLE) && (next_state == STATE_IDLE)) begin
            tx_busy <= 1'b0;
        end
    end
    
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
    
    assign baud_count_done = (baud_count == BAUD_COUNT_LAST) ? 1'b1 : 1'b0;
    
    always_ff @(posedge clk) begin
        if(rst) begin
            data_bit_count <= '0;
        end
        else if((cur_state == STATE_IDLE) && (next_state == STATE_START)) begin
            data_bit_count <= '0;
        end
        else if((cur_state == STATE_DATA) && baud_count_done && !data_bit_last) begin
            data_bit_count <= data_bit_count + 'b1;
        end
    end
    
    assign data_bit_last = (data_bit_count == DATA_BIT_COUNT_LAST) ? 1'b1 : 1'b0;
    
    always_ff @(posedge clk) begin
        if(rst) begin
            tx_data_loaded <= '0;
        end
        else if((cur_state == STATE_IDLE) && (next_state == STATE_START)) begin
            tx_data_loaded <= tx_data;
        end
    end
endmodule