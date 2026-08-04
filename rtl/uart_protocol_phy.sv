`default_nettype none

module uart_protocol_phy #(
        parameter DATA_WIDTH = 8,
        parameter RECV_PACKET_BYTE_LENGTH = 3,
        parameter SEND_PACKET_BYTE_LENGTH = 3
    )(
        input logic clk,
        input logic rst,
        
        input logic[DATA_WIDTH - 1:0] rx_data,
        input logic rx_data_valid,
        input logic rx_error,
        
        output logic[DATA_WIDTH - 1:0] tx_data,
        output logic tx_start,
        input logic tx_busy,
        
        output logic[RECV_PACKET_BYTE_LENGTH * 8 - 1:0] recv_packet,
        output logic recv_packet_valid,
        input logic recv_packet_full,
        
        input logic[SEND_PACKET_BYTE_LENGTH * 8 - 1:0] send_packet,
        input logic send_packet_valid,
        output logic send_packet_pop
    );
    
    localparam RECV_CNT_WIDTH = (RECV_PACKET_BYTE_LENGTH <= 1) ? 1 : $clog2(RECV_PACKET_BYTE_LENGTH);
    localparam SEND_CNT_WIDTH = (SEND_PACKET_BYTE_LENGTH <= 1) ? 1 : $clog2(SEND_PACKET_BYTE_LENGTH);
    
    localparam RECV_STATE_WIDTH = 3;
    localparam RECV_STATE_WAIT_SYNC = RECV_STATE_WIDTH'('d0);
    localparam RECV_STATE_WAIT_DATA_LOW = RECV_STATE_WIDTH'('d1);
    localparam RECV_STATE_WAIT_DATA_HIGH = RECV_STATE_WIDTH'('d2);
    localparam RECV_STATE_WAIT_CRC_LOW = RECV_STATE_WIDTH'('d3);
    localparam RECV_STATE_WAIT_CRC_HIGH = RECV_STATE_WIDTH'('d4);
    localparam RECV_STATE_WAIT_PACKET_RECV = RECV_STATE_WIDTH'('d5);
    
    localparam SEND_STATE_WIDTH = 4;
    localparam SEND_STATE_IDLE = SEND_STATE_WIDTH'('d0);
    localparam SEND_STATE_SEND_SYNC = SEND_STATE_WIDTH'('d1);
    localparam SEND_STATE_WAIT_SYNC = SEND_STATE_WIDTH'('d2);
    localparam SEND_STATE_SEND_DATA_LOW = SEND_STATE_WIDTH'('d3);
    localparam SEND_STATE_WAIT_DATA_LOW = SEND_STATE_WIDTH'('d4);
    localparam SEND_STATE_SEND_DATA_HIGH = SEND_STATE_WIDTH'('d5);
    localparam SEND_STATE_WAIT_DATA_HIGH = SEND_STATE_WIDTH'('d6);
    localparam SEND_STATE_SEND_CRC_LOW = SEND_STATE_WIDTH'('d7);
    localparam SEND_STATE_WAIT_CRC_LOW = SEND_STATE_WIDTH'('d8);
    localparam SEND_STATE_SEND_CRC_HIGH = SEND_STATE_WIDTH'('d9);
    localparam SEND_STATE_WAIT_CRC_HIGH = SEND_STATE_WIDTH'('d10);
    
    logic[RECV_STATE_WIDTH - 1:0] cur_recv_state;
    logic[RECV_STATE_WIDTH - 1:0] next_recv_state;
    
    logic recv_found_sync;
    logic[RECV_CNT_WIDTH - 1:0] recv_cnt;
    logic[DATA_WIDTH - 1:0] recv_crc_value;
    logic[DATA_WIDTH - 1:0] recv_cal_crc_value;
    
    logic[SEND_STATE_WIDTH - 1:0] cur_send_state;
    logic[SEND_STATE_WIDTH - 1:0] next_send_state;
    
    logic[SEND_PACKET_BYTE_LENGTH * 8 - 1:0] send_packet_loaded;
    logic[SEND_CNT_WIDTH - 1:0] send_cnt;
    logic[DATA_WIDTH - 1:0] send_cal_crc_value;
    
    always_ff @(posedge clk) begin
        if(rst) begin
            cur_recv_state <= RECV_STATE_WAIT_SYNC;
        end
        else begin
            cur_recv_state <= next_recv_state;
        end
    end
    
    always_comb begin
        next_recv_state = cur_recv_state;
        
        if(cur_recv_state == RECV_STATE_WAIT_PACKET_RECV) begin
            if(!recv_packet_full) begin
                next_recv_state = RECV_STATE_WAIT_SYNC;
            end
        end
        else if(rx_error) begin
            next_recv_state = RECV_STATE_WAIT_SYNC;
        end
        else if(recv_found_sync) begin
            next_recv_state = RECV_STATE_WAIT_DATA_LOW;
        end
        else if(rx_data_valid && (rx_data[7:4] != '0)) begin
            next_recv_state = RECV_STATE_WAIT_SYNC;
        end
        else begin
            case(cur_recv_state)
                RECV_STATE_WAIT_DATA_LOW: begin
                    if(rx_data_valid) begin
                        next_recv_state = RECV_STATE_WAIT_DATA_HIGH;
                    end
                end
                
                RECV_STATE_WAIT_DATA_HIGH: begin
                    if(rx_data_valid) begin
                        if(recv_cnt >= unsigned'(RECV_PACKET_BYTE_LENGTH - 'b1)) begin
                            next_recv_state = RECV_STATE_WAIT_CRC_LOW;
                        end
                        else begin
                            next_recv_state = RECV_STATE_WAIT_DATA_LOW; 
                        end
                    end
                end
                
                RECV_STATE_WAIT_CRC_LOW: begin
                    if(rx_data_valid) begin
                        next_recv_state = RECV_STATE_WAIT_CRC_HIGH;
                    end
                end
                
                RECV_STATE_WAIT_CRC_HIGH: begin
                    if(rx_data_valid) begin
                        if({rx_data[3:0], recv_crc_value[3:0]} == recv_cal_crc_value) begin
                            next_recv_state = RECV_STATE_WAIT_PACKET_RECV;
                        end
                        else begin
                            next_recv_state = RECV_STATE_WAIT_SYNC;
                        end
                    end
                end
            endcase
        end
    end
    
    assign recv_found_sync = (rx_data_valid && (rx_data == 'h5a)) ? 1'b1 : 1'b0;
    
    always_ff @(posedge clk) begin
        if(rst) begin
            recv_cnt <= '0;
        end
        else if(recv_found_sync) begin
            recv_cnt <= '0;
        end
        else if((cur_recv_state != next_recv_state) && (next_recv_state == RECV_STATE_WAIT_DATA_LOW)) begin
            recv_cnt <= recv_cnt + 'b1;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            recv_packet <= '0;
        end
        else if((cur_recv_state == RECV_STATE_WAIT_DATA_LOW) && (cur_recv_state != next_recv_state)) begin
            recv_packet[recv_cnt * DATA_WIDTH +: 4] <= rx_data[3:0];
        end
        else if((cur_recv_state == RECV_STATE_WAIT_DATA_HIGH) && (cur_recv_state != next_recv_state)) begin
            recv_packet[recv_cnt * DATA_WIDTH + 4 +: 4] <= rx_data[3:0];
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            recv_packet_valid <= 1'b0;
        end
        else if((cur_recv_state != next_recv_state) && (next_recv_state == RECV_STATE_WAIT_PACKET_RECV)) begin
            recv_packet_valid <= 1'b1;
        end
        else if((cur_recv_state == RECV_STATE_WAIT_PACKET_RECV) && (cur_recv_state != next_recv_state)) begin
            recv_packet_valid <= 1'b0;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            recv_crc_value <= '0;
        end
        else if((cur_recv_state == RECV_STATE_WAIT_CRC_LOW) && (cur_recv_state != next_recv_state)) begin
            recv_crc_value[3:0] <= rx_data[3:0];
        end
        else if((cur_recv_state == RECV_STATE_WAIT_CRC_HIGH) && (cur_recv_state != next_recv_state)) begin
            recv_crc_value[DATA_WIDTH - 1:4] <= rx_data[3:0];
        end
    end
    
    crc8_calculator crc8_calculator_recv_inst(
        .clk(clk),
        .rst(rst),
        .crc_start(recv_found_sync),
        .crc_data({rx_data[3:0], recv_packet[recv_cnt * DATA_WIDTH +: 4]}),
        .crc_data_valid(((cur_recv_state == RECV_STATE_WAIT_DATA_HIGH) && (cur_recv_state != next_recv_state) && !recv_found_sync) ? 1'b1 : 1'b0),
        .crc8_value(recv_cal_crc_value)
    );
    
    always_ff @(posedge clk) begin
        if(rst) begin
            cur_send_state <= SEND_STATE_IDLE;
        end
        else begin
            cur_send_state <= next_send_state;
        end
    end
    
    always_comb begin
        next_send_state = cur_send_state;
        
        case(cur_send_state)
            SEND_STATE_IDLE: begin
                if(send_packet_valid) begin
                    next_send_state = SEND_STATE_SEND_SYNC;
                end
            end
            
            SEND_STATE_SEND_SYNC: begin
                next_send_state = SEND_STATE_WAIT_SYNC;
            end
            
            SEND_STATE_WAIT_SYNC: begin
                if(!tx_busy) begin
                    next_send_state = SEND_STATE_SEND_DATA_LOW;
                end
            end
            
            SEND_STATE_SEND_DATA_LOW: begin
                next_send_state = SEND_STATE_WAIT_DATA_LOW;
            end
            
            SEND_STATE_WAIT_DATA_LOW: begin
                if(!tx_busy) begin
                    next_send_state = SEND_STATE_SEND_DATA_HIGH;
                end
            end
            
            SEND_STATE_SEND_DATA_HIGH: begin
                next_send_state = SEND_STATE_WAIT_DATA_HIGH;
            end
            
            SEND_STATE_WAIT_DATA_HIGH: begin
                if(!tx_busy) begin
                    if(send_cnt >= unsigned'(SEND_PACKET_BYTE_LENGTH - 'b1)) begin
                        next_send_state = SEND_STATE_SEND_CRC_LOW;
                    end
                    else begin
                        next_send_state = SEND_STATE_SEND_DATA_LOW;
                    end
                end
            end
            
            SEND_STATE_SEND_CRC_LOW: begin
                next_send_state = SEND_STATE_WAIT_CRC_LOW;
            end
            
            SEND_STATE_WAIT_CRC_LOW: begin
                if(!tx_busy) begin
                    next_send_state = SEND_STATE_SEND_CRC_HIGH;
                end
            end
            
            SEND_STATE_SEND_CRC_HIGH: begin
                next_send_state = SEND_STATE_WAIT_CRC_HIGH;
            end
            
            SEND_STATE_WAIT_CRC_HIGH: begin
                if(!tx_busy) begin
                    next_send_state = SEND_STATE_IDLE;
                end
            end
        endcase
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            tx_data <= '0;
            tx_start <= 1'b0;
        end
        else if((cur_send_state != next_send_state) && (next_send_state == SEND_STATE_SEND_SYNC)) begin
            tx_data <= 'h5a;
            tx_start <= 1'b1;
        end
        else if((cur_send_state == SEND_STATE_WAIT_SYNC) && (next_send_state == SEND_STATE_SEND_DATA_LOW)) begin
            tx_data <= send_packet_loaded[0 +: 4];
            tx_start <= 1'b1;
        end
        else if((cur_send_state == SEND_STATE_WAIT_DATA_LOW) && (next_send_state == SEND_STATE_SEND_DATA_HIGH)) begin
            tx_data <= send_packet_loaded[send_cnt * DATA_WIDTH + 4 +: 4];
            tx_start <= 1'b1;
        end
        else if((cur_send_state == SEND_STATE_WAIT_DATA_HIGH) && (next_send_state == SEND_STATE_SEND_DATA_LOW)) begin
            tx_data <= send_packet_loaded[(send_cnt + 'b1) * DATA_WIDTH +: 4];
            tx_start <= 1'b1;
        end
        else if((cur_send_state == SEND_STATE_WAIT_DATA_HIGH) && (next_send_state == SEND_STATE_SEND_CRC_LOW)) begin
            tx_data <= send_cal_crc_value[3:0];
            tx_start <= 1'b1;
        end
        else if((cur_send_state == SEND_STATE_WAIT_CRC_LOW) && (next_send_state == SEND_STATE_SEND_CRC_HIGH)) begin
            tx_data <= send_cal_crc_value[7:4];
            tx_start <= 1'b1;
        end
        else begin
            tx_data <= '0;
            tx_start <= 1'b0;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            send_packet_pop <= 1'b0;
        end
        else if((cur_send_state == SEND_STATE_IDLE) && (cur_send_state != next_send_state)) begin
            send_packet_pop <= 1'b1;
        end
        else begin
            send_packet_pop <= 1'b0;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            send_packet_loaded <= '0;
        end
        else if((cur_send_state == SEND_STATE_IDLE) && (cur_send_state != next_send_state)) begin
            send_packet_loaded <= send_packet;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            send_cnt <= '0;
        end
        else if((cur_send_state == SEND_STATE_IDLE) && (cur_send_state != next_send_state)) begin
            send_cnt <= '0;
        end
        else if((cur_send_state == SEND_STATE_WAIT_DATA_HIGH) && (next_send_state == SEND_STATE_SEND_DATA_LOW)) begin
            send_cnt <= send_cnt + 'b1;
        end
    end
    
    crc8_calculator crc8_calculator_send_inst(
        .clk(clk),
        .rst(rst),
        .crc_start(((cur_send_state == SEND_STATE_SEND_SYNC) && (cur_send_state != next_send_state)) ? 1'b1 : 1'b0),
        .crc_data(send_packet_loaded[send_cnt * DATA_WIDTH +: DATA_WIDTH]),
        .crc_data_valid(((cur_send_state == SEND_STATE_SEND_DATA_LOW) && (cur_send_state != next_send_state)) ? 1'b1 : 1'b0),
        .crc8_value(send_cal_crc_value)
    );
endmodule