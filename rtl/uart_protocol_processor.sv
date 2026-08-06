`default_nettype none

module uart_protocol_processor #(
        parameter RECV_PACKET_BYTE_LENGTH = 4,
        parameter SEND_PACKET_BYTE_LENGTH = 10,
        parameter VRAM_ADDR_WIDTH = 10,
        parameter VRAM_DATA_WIDTH = 8,
        parameter KEY_ID_WIDTH = 4,
        parameter REG_ADDR_WIDTH = 8,
        parameter REG_DATA_WIDTH = 8
    )(
        input logic clk,
        input logic rst,
        
        input logic[RECV_PACKET_BYTE_LENGTH * 8 - 1:0] recv_packet,
        input logic recv_packet_valid,
        output logic recv_packet_pop,
        
        output logic[SEND_PACKET_BYTE_LENGTH * 8 - 1:0] send_packet,
        output logic send_packet_valid,
        input logic send_packet_full,
        
        output logic[VRAM_ADDR_WIDTH - 1:0] clone_vram_raddr,
        input logic[VRAM_DATA_WIDTH - 1:0] clone_vram_rdata,
        output logic clone_vram_start,
        input logic clone_vram_busy,
        
        output logic[KEY_ID_WIDTH - 1:0] press_key_id,
        output logic press_key_id_valid,
        
        output logic[REG_ADDR_WIDTH - 1:0] reg_addr,
        output logic[REG_DATA_WIDTH - 1:0] reg_wdata,
        output logic reg_we,
        input logic[REG_DATA_WIDTH - 1:0] reg_rdata
    );
    
    localparam RECV_PACKET_ID_OFFSET = 0;
    localparam RECV_PACKET_ID_WIDTH = 8;
    localparam RECV_PACKET_COMMAND_OFFSET = RECV_PACKET_ID_OFFSET + RECV_PACKET_ID_WIDTH;
    localparam RECV_PACKET_COMMAND_WIDTH = 8;
    localparam RECV_PACKET_PARAMETER_OFFSET = RECV_PACKET_COMMAND_OFFSET + RECV_PACKET_COMMAND_WIDTH;
    localparam RECV_PACKET_PARAMETER_WIDTH = 16;
    
    localparam SEND_PACKET_ID_OFFSET = 0;
    localparam SEND_PACKET_ID_WIDTH = 8;
    localparam SEND_PACKET_RETURN_CODE_OFFSET = SEND_PACKET_ID_OFFSET + SEND_PACKET_ID_WIDTH;
    localparam SEND_PACKET_RETURN_CODE_WIDTH = 8;
    localparam SEND_PACKET_RETURN_VALUE_OFFSET = SEND_PACKET_RETURN_CODE_OFFSET + SEND_PACKET_RETURN_CODE_WIDTH;
    localparam SEND_PACKET_RETURN_VALUE_WIDTH = 64;
    
    localparam CMD_CLONE_VRAM = RECV_PACKET_COMMAND_WIDTH'('h00);
    localparam CMD_READ_VRAM = RECV_PACKET_COMMAND_WIDTH'('h01);
    localparam CMD_PRESS_KEY = RECV_PACKET_COMMAND_WIDTH'('h02);
    localparam CMD_READ_REG = RECV_PACKET_COMMAND_WIDTH'('h03);
    localparam CMD_WRITE_REG = RECV_PACKET_COMMAND_WIDTH'('h04);
    
    localparam RETURN_CODE_SUCC = SEND_PACKET_RETURN_CODE_WIDTH'('h00);
    localparam RETURN_CODE_FAIL = SEND_PACKET_RETURN_CODE_WIDTH'('h01);
    
    localparam READ_VRAM_CNT = 8;
    localparam READ_VRAM_CNT_WIDTH = (READ_VRAM_CNT <= 1) ? 1 : $clog2(READ_VRAM_CNT);
    
    localparam STATE_WIDTH = 4;
    localparam STATE_READ_RECV_PACKET = STATE_WIDTH'('d0);
    localparam STATE_DECODE_COMMAND = STATE_WIDTH'('d1);
    localparam STATE_INVALID_CMD_SEND_RESP = STATE_WIDTH'('d2);
    localparam STATE_CLONE_VRAM_CMD_EXECUTE = STATE_WIDTH'('d3);
    localparam STATE_CLONE_VRAM_CMD_WAIT_FINISH = STATE_WIDTH'('d4);
    localparam STATE_CLONE_VRAM_CMD_SEND_RESP = STATE_WIDTH'('d5);
    localparam STATE_READ_VRAM_CMD_EXECUTE_SET_ADDRESS = STATE_WIDTH'('d6);
    localparam STATE_READ_VRAM_CMD_EXECUTE_GET_DATA = STATE_WIDTH'('d7);
    localparam STATE_READ_VRAM_CMD_SEND_RESP = STATE_WIDTH'('d8);
    localparam STATE_PRESS_KEY_CMD_EXECUTE = STATE_WIDTH'('d9);
    localparam STATE_PRESS_KEY_CMD_SEND_RESP = STATE_WIDTH'('d10);
    localparam STATE_READ_REG_CMD_EXECUTE = STATE_WIDTH'('d11);
    localparam STATE_READ_REG_CMD_SEND_RESP = STATE_WIDTH'('d12);
    localparam STATE_WRITE_REG_CMD_EXECUTE = STATE_WIDTH'('d13);
    localparam STATE_WRITE_REG_CMD_SEND_RESP = STATE_WIDTH'('d14);
    localparam STATE_WAIT_SEND_RESP = STATE_WIDTH'('d15);
    
    logic[STATE_WIDTH - 1:0] cur_state;
    logic[STATE_WIDTH - 1:0] next_state;
    
    logic[RECV_PACKET_BYTE_LENGTH * 8 - 1:0] recv_packet_loaded;
    logic[READ_VRAM_CNT_WIDTH - 1:0] read_vram_cnt;
    logic[READ_VRAM_CNT * VRAM_DATA_WIDTH - 1:0] read_vram_buffer;
    
    always_ff @(posedge clk) begin
        if(rst) begin
            cur_state <= STATE_READ_RECV_PACKET;
        end
        else begin
            cur_state <= next_state;
        end
    end
    
    always_comb begin
        next_state = cur_state;
        
        case(cur_state)
            STATE_READ_RECV_PACKET: begin
                if(recv_packet_valid) begin
                    next_state = STATE_DECODE_COMMAND;
                end
            end
            
            STATE_DECODE_COMMAND: begin
                case(recv_packet_loaded[RECV_PACKET_COMMAND_OFFSET +: RECV_PACKET_COMMAND_WIDTH])
                    CMD_CLONE_VRAM: begin
                        next_state = STATE_CLONE_VRAM_CMD_EXECUTE;
                    end
                    
                    CMD_READ_VRAM: begin
                        next_state = STATE_READ_VRAM_CMD_EXECUTE_SET_ADDRESS;
                    end
                    
                    CMD_PRESS_KEY: begin
                        next_state = STATE_PRESS_KEY_CMD_EXECUTE;
                    end
                    
                    CMD_READ_REG: begin
                        next_state = STATE_READ_REG_CMD_EXECUTE;
                    end
                    
                    CMD_WRITE_REG: begin
                        next_state = STATE_WRITE_REG_CMD_EXECUTE;
                    end
                    
                    default: begin
                        next_state = STATE_INVALID_CMD_SEND_RESP;
                    end
                endcase
            end
            
            STATE_INVALID_CMD_SEND_RESP: begin
                next_state = STATE_WAIT_SEND_RESP;
            end
            
            STATE_CLONE_VRAM_CMD_EXECUTE: begin
                next_state = STATE_CLONE_VRAM_CMD_WAIT_FINISH;
            end
            
            STATE_CLONE_VRAM_CMD_WAIT_FINISH: begin
                if(!clone_vram_busy) begin
                    next_state = STATE_CLONE_VRAM_CMD_SEND_RESP;
                end
            end
            
            STATE_CLONE_VRAM_CMD_SEND_RESP: begin
                next_state = STATE_WAIT_SEND_RESP;
            end
            
            STATE_READ_VRAM_CMD_EXECUTE_SET_ADDRESS: begin
                next_state = STATE_READ_VRAM_CMD_EXECUTE_GET_DATA;
            end
            
            STATE_READ_VRAM_CMD_EXECUTE_GET_DATA: begin
                if(read_vram_cnt >= unsigned'(READ_VRAM_CNT - 'b1)) begin
                    next_state = STATE_READ_VRAM_CMD_SEND_RESP;
                end
                else begin
                    next_state = STATE_READ_VRAM_CMD_EXECUTE_SET_ADDRESS;
                end
            end
            
            STATE_READ_VRAM_CMD_SEND_RESP: begin
                next_state = STATE_WAIT_SEND_RESP;
            end
            
            STATE_PRESS_KEY_CMD_EXECUTE: begin
                next_state = STATE_PRESS_KEY_CMD_SEND_RESP;
            end
            
            STATE_PRESS_KEY_CMD_SEND_RESP: begin
                next_state = STATE_WAIT_SEND_RESP;
            end
            
            STATE_READ_REG_CMD_EXECUTE: begin
                next_state = STATE_READ_REG_CMD_SEND_RESP;
            end
            
            STATE_READ_REG_CMD_SEND_RESP: begin
                next_state = STATE_WAIT_SEND_RESP;
            end
            
            STATE_WRITE_REG_CMD_EXECUTE: begin
                next_state = STATE_WRITE_REG_CMD_SEND_RESP;
            end
            
            STATE_WRITE_REG_CMD_SEND_RESP: begin
                next_state = STATE_WAIT_SEND_RESP;
            end
            
            STATE_WAIT_SEND_RESP: begin
                if(!send_packet_full) begin
                    next_state = STATE_READ_RECV_PACKET;
                end
            end
        endcase
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            recv_packet_pop <= 1'b0;
        end
        else if((cur_state == STATE_READ_RECV_PACKET) && (cur_state != next_state)) begin
            recv_packet_pop <= 1'b1;
        end
        else begin
            recv_packet_pop <= 1'b0;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            send_packet <= '0;
            send_packet_valid <= 1'b0;
        end
        else begin
            send_packet[SEND_PACKET_ID_OFFSET +: SEND_PACKET_ID_WIDTH] <= recv_packet_loaded[RECV_PACKET_ID_OFFSET +: RECV_PACKET_ID_WIDTH];
            
            case(cur_state)
                STATE_INVALID_CMD_SEND_RESP: begin
                    send_packet[SEND_PACKET_RETURN_CODE_OFFSET +: SEND_PACKET_RETURN_CODE_WIDTH] <= RETURN_CODE_FAIL;
                    send_packet[SEND_PACKET_RETURN_VALUE_OFFSET +: SEND_PACKET_RETURN_VALUE_WIDTH] <= '0;
                    send_packet_valid <= 1'b1;
                end
                
                STATE_CLONE_VRAM_CMD_SEND_RESP: begin
                    send_packet[SEND_PACKET_RETURN_CODE_OFFSET +: SEND_PACKET_RETURN_CODE_WIDTH] <= RETURN_CODE_SUCC;
                    send_packet[SEND_PACKET_RETURN_VALUE_OFFSET +: SEND_PACKET_RETURN_VALUE_WIDTH] <= '0;
                    send_packet_valid <= 1'b1;
                end
                
                STATE_READ_VRAM_CMD_SEND_RESP: begin
                    send_packet[SEND_PACKET_RETURN_CODE_OFFSET +: SEND_PACKET_RETURN_CODE_WIDTH] <= RETURN_CODE_SUCC;
                    send_packet[SEND_PACKET_RETURN_VALUE_OFFSET +: SEND_PACKET_RETURN_VALUE_WIDTH] <= read_vram_buffer;
                    send_packet_valid <= 1'b1;
                end
                
                STATE_PRESS_KEY_CMD_SEND_RESP: begin
                    send_packet[SEND_PACKET_RETURN_CODE_OFFSET +: SEND_PACKET_RETURN_CODE_WIDTH] <= RETURN_CODE_SUCC;
                    send_packet[SEND_PACKET_RETURN_VALUE_OFFSET +: SEND_PACKET_RETURN_VALUE_WIDTH] <= '0;
                    send_packet_valid <= 1'b1;
                end
                
                STATE_READ_REG_CMD_SEND_RESP: begin
                    send_packet[SEND_PACKET_RETURN_CODE_OFFSET +: SEND_PACKET_RETURN_CODE_WIDTH] <= RETURN_CODE_SUCC;
                    send_packet[SEND_PACKET_RETURN_VALUE_OFFSET +: SEND_PACKET_RETURN_VALUE_WIDTH] <= reg_rdata;
                    send_packet_valid <= 1'b1;
                end
                
                STATE_WRITE_REG_CMD_SEND_RESP: begin
                    send_packet[SEND_PACKET_RETURN_CODE_OFFSET +: SEND_PACKET_RETURN_CODE_WIDTH] <= RETURN_CODE_SUCC;
                    send_packet[SEND_PACKET_RETURN_VALUE_OFFSET +: SEND_PACKET_RETURN_VALUE_WIDTH] <= '0;
                    send_packet_valid <= 1'b1;
                end
                
                STATE_WAIT_SEND_RESP: begin
                    if(next_state != STATE_WAIT_SEND_RESP) begin
                        send_packet_valid <= 1'b0;
                    end
                end
            endcase
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            clone_vram_raddr <= '0;
        end
        else if(next_state == STATE_READ_VRAM_CMD_EXECUTE_SET_ADDRESS) begin
            if(cur_state == STATE_DECODE_COMMAND) begin
                clone_vram_raddr <= recv_packet_loaded[RECV_PACKET_PARAMETER_OFFSET +: VRAM_ADDR_WIDTH];
            end
            else begin
                clone_vram_raddr <= clone_vram_raddr + 'b1;
            end
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            clone_vram_start <= 1'b0;
        end
        else if(next_state == STATE_CLONE_VRAM_CMD_EXECUTE) begin
            clone_vram_start <= 1'b1;
        end
        else begin
            clone_vram_start <= 1'b0;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            press_key_id <= '0;
            press_key_id_valid <= 1'b0;
        end
        else if(next_state == STATE_PRESS_KEY_CMD_EXECUTE) begin
            press_key_id <= recv_packet_loaded[RECV_PACKET_PARAMETER_OFFSET +: KEY_ID_WIDTH];
            press_key_id_valid <= 1'b1;
        end
        else begin
            press_key_id_valid <= 1'b0;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            reg_addr <= '0;
            reg_wdata <= '0;
            reg_we <= 1'b0;
        end
        else if(next_state == STATE_READ_REG_CMD_EXECUTE) begin
            reg_addr <= recv_packet_loaded[RECV_PACKET_PARAMETER_OFFSET +: REG_ADDR_WIDTH];
        end
        else if(next_state == STATE_WRITE_REG_CMD_EXECUTE) begin
            reg_addr <= recv_packet_loaded[RECV_PACKET_PARAMETER_OFFSET +: REG_ADDR_WIDTH];
            reg_wdata <= recv_packet_loaded[RECV_PACKET_PARAMETER_OFFSET + REG_ADDR_WIDTH +: REG_DATA_WIDTH];
            reg_we <= 1'b1;
        end
        else begin
            reg_we <= 1'b0;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            recv_packet_loaded <= '0;
        end
        else if((cur_state == STATE_READ_RECV_PACKET) && (cur_state != next_state)) begin
            recv_packet_loaded <= recv_packet;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            read_vram_cnt <= '0;
        end
        else if((cur_state == STATE_DECODE_COMMAND) && (next_state == STATE_READ_VRAM_CMD_EXECUTE_SET_ADDRESS)) begin
            read_vram_cnt <= 'b0;
        end
        else if((cur_state == STATE_READ_VRAM_CMD_EXECUTE_GET_DATA) && (next_state == STATE_READ_VRAM_CMD_EXECUTE_SET_ADDRESS)) begin
            read_vram_cnt <= read_vram_cnt + 'b1;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            read_vram_buffer <= '0;
        end
        else if((cur_state == STATE_DECODE_COMMAND) && (next_state == STATE_READ_VRAM_CMD_EXECUTE_SET_ADDRESS)) begin
            read_vram_buffer <= '0;
        end
        else if(cur_state == STATE_READ_VRAM_CMD_EXECUTE_GET_DATA) begin
            read_vram_buffer[read_vram_cnt * VRAM_DATA_WIDTH +: VRAM_DATA_WIDTH] <= clone_vram_rdata;
        end
    end
endmodule