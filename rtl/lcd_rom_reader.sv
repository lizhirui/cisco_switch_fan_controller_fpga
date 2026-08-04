`default_nettype none

module lcd_rom_reader #(
        parameter CLK_FREQ = 50000000,
        parameter FREQ_DIVIDE = 2,
        parameter ADDR_WIDTH = 24,
        parameter DATA_WIDTH = 8,
        parameter LEN_WIDTH = 6
    )(
        input logic clk,
        input logic rst,

        output logic lcd_rom_cs,
        output logic lcd_rom_sck,
        output logic lcd_rom_si,
        input logic lcd_rom_so,

        input logic[ADDR_WIDTH - 1:0] addr,
        input logic[LEN_WIDTH - 1:0] len,
        input logic start,
        output logic busy,

        output logic[DATA_WIDTH - 1:0] data,
        output logic[LEN_WIDTH - 1:0] data_len,
        output logic data_valid,
        input logic data_full
    );

    localparam SEND_BIT_NUM = 8 + ADDR_WIDTH;
    localparam SEND_BIT_CNT_WIDTH = $clog2(SEND_BIT_NUM);
    localparam RECV_BIT_CNT_WIDTH = (DATA_WIDTH <= 1) ? 1 : $clog2(DATA_WIDTH);

    localparam STATE_WIDTH = 3;
    localparam STATE_IDLE = STATE_WIDTH'('d0);
    localparam STATE_ASSERT_CS = STATE_WIDTH'('d1);
    localparam STATE_LOAD_DATA = STATE_WIDTH'('d2);
    localparam STATE_CAPTURE_DATA = STATE_WIDTH'('d3);
    localparam STATE_GET_DATA = STATE_WIDTH'('d4);
    localparam STATE_READ_DATA = STATE_WIDTH'('d5);
    localparam STATE_DEASSERT_CS = STATE_WIDTH'('d6);

    logic clken;
    logic[STATE_WIDTH - 1:0] cur_state;
    logic[STATE_WIDTH - 1:0] next_state;
    logic[SEND_BIT_NUM - 1:0] send_data;
    logic[SEND_BIT_CNT_WIDTH - 1:0] send_bit_cnt;
    logic[RECV_BIT_CNT_WIDTH - 1:0] recv_bit_cnt;
    logic[LEN_WIDTH - 1:0] recv_len_cnt;

    clock_enable_generator #(
        .CLOCK_FREQUENCY(CLK_FREQ),
        .ENABLE_FREQUENCY(CLK_FREQ / FREQ_DIVIDE)
    )clock_enable_generator_inst(
        .clk(clk),
        .rst(rst),
        .enable(clken)
    );

    always_ff @(posedge clk) begin
        if(rst) begin
            cur_state <= STATE_IDLE;
        end
        else if(cur_state == STATE_IDLE) begin
            cur_state <= next_state;
        end
        else if(clken) begin
            cur_state <= next_state;
        end
    end

    always_comb begin
        next_state = cur_state;

        case(cur_state)
            STATE_IDLE: begin
                if(start && (len != '0)) begin
                    next_state = STATE_ASSERT_CS;
                end
            end

            STATE_ASSERT_CS: begin
                next_state = STATE_LOAD_DATA;
            end

            STATE_LOAD_DATA: begin
                next_state = STATE_CAPTURE_DATA;
            end

            STATE_CAPTURE_DATA: begin
                if(send_bit_cnt == 'b0) begin
                    next_state = STATE_GET_DATA;
                end
                else begin
                    next_state = STATE_LOAD_DATA;
                end
            end

            STATE_GET_DATA: begin
                next_state = STATE_READ_DATA;
            end

            STATE_READ_DATA: begin
                if(data_full && (recv_bit_cnt == 'b0)) begin
                    next_state = STATE_READ_DATA;
                end
                else if((recv_bit_cnt == 'b0) && (recv_len_cnt == 'b0)) begin
                    next_state = STATE_DEASSERT_CS;
                end
                else begin
                    next_state = STATE_GET_DATA;
                end
            end

            STATE_DEASSERT_CS: begin
                next_state = STATE_IDLE;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            lcd_rom_cs <= 1'b1;
        end
        else if((cur_state == STATE_ASSERT_CS) && clken) begin
            lcd_rom_cs <= 1'b0;
        end
        else if((cur_state == STATE_DEASSERT_CS) && clken) begin
            lcd_rom_cs <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            lcd_rom_sck <= 1'b1;
        end
        else if(((cur_state == STATE_LOAD_DATA) || (cur_state == STATE_GET_DATA)) && clken) begin
            lcd_rom_sck <= 1'b0;
        end
        else if(((cur_state == STATE_CAPTURE_DATA) || (cur_state == STATE_READ_DATA)) && clken) begin
            lcd_rom_sck <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            lcd_rom_si <= 1'b0;
        end
        else if((cur_state == STATE_LOAD_DATA) && clken) begin
            lcd_rom_si <= send_data[send_bit_cnt];
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            busy <= 1'b0;
        end
        else if((cur_state == STATE_IDLE) && (next_state != STATE_IDLE)) begin
            busy <= 1'b1;
        end
        else if(cur_state == STATE_DEASSERT_CS && clken) begin
            busy <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            data <= '0;
        end
        else if((cur_state == STATE_READ_DATA) && clken) begin
            data <= {data[DATA_WIDTH - 2:0], lcd_rom_so};
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            data_len <= '0;
        end
        else if((cur_state == STATE_IDLE) && (next_state != STATE_IDLE)) begin
            data_len <= len;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            data_valid <= 1'b0;
        end
        else if((cur_state == STATE_READ_DATA) && (next_state != STATE_READ_DATA) && clken && (recv_bit_cnt == 'b0)) begin
            data_valid <= 1'b1;
        end
        else begin
            data_valid <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            send_data <= '0;
        end
        else if((cur_state == STATE_IDLE) && (next_state != STATE_IDLE)) begin
            send_data <= {8'h03, addr};
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            send_bit_cnt <= '0;
        end
        else if((cur_state == STATE_ASSERT_CS) && clken) begin
            send_bit_cnt <= SEND_BIT_NUM - 'b1;
        end
        else if((cur_state == STATE_CAPTURE_DATA) && clken) begin
            send_bit_cnt <= send_bit_cnt - 'b1;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            recv_bit_cnt <= '0;
        end
        else if((cur_state == STATE_ASSERT_CS) && clken) begin
            recv_bit_cnt <= '0;
        end
        else if((cur_state != STATE_GET_DATA) && (next_state == STATE_GET_DATA) && clken) begin
            if(recv_bit_cnt == '0) begin
                recv_bit_cnt <= DATA_WIDTH - 'b1;
            end
            else begin
                recv_bit_cnt <= recv_bit_cnt - 'b1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            recv_len_cnt <= '0;
        end
        else if((cur_state == STATE_IDLE) && (next_state != STATE_IDLE)) begin
            recv_len_cnt <= len - 'b1;
        end
        else if((cur_state == STATE_READ_DATA) && (next_state != STATE_READ_DATA) && clken && (recv_bit_cnt == '0)) begin
            recv_len_cnt <= recv_len_cnt - 'b1;
        end
    end
endmodule