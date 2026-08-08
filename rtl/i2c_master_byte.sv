`default_nettype none

module i2c_master_byte #(
        parameter CLK_FREQ = 50000000,
        parameter I2C_FREQ = 100000
    )(
        input logic clk,
        input logic rst,

        input logic start_request,
        input logic stop_request,
        input logic write_request,
        input logic read_request,
        input logic[7:0] write_data,
        input logic read_nack,
        output logic[7:0] read_data,
        output logic write_ack,
        output logic busy,
        output logic done,

        output logic scl,
        inout wire sda
    );

    localparam HALF_PERIOD = CLK_FREQ / (I2C_FREQ * 2);
    localparam HALF_PERIOD_COUNTER_WIDTH = (HALF_PERIOD <= 1) ? 1 : $clog2(HALF_PERIOD);
    localparam STATE_WIDTH = 4;
    localparam STATE_IDLE = STATE_WIDTH'('d0);
    localparam STATE_START_A = STATE_WIDTH'('d1);
    localparam STATE_START_B = STATE_WIDTH'('d2);
    localparam STATE_STOP_A = STATE_WIDTH'('d3);
    localparam STATE_STOP_B = STATE_WIDTH'('d4);
    localparam STATE_WRITE_LOW = STATE_WIDTH'('d5);
    localparam STATE_WRITE_HIGH = STATE_WIDTH'('d6);
    localparam STATE_WRITE_ACK_LOW = STATE_WIDTH'('d7);
    localparam STATE_WRITE_ACK_HIGH = STATE_WIDTH'('d8);
    localparam STATE_READ_LOW = STATE_WIDTH'('d9);
    localparam STATE_READ_HIGH = STATE_WIDTH'('d10);
    localparam STATE_READ_ACK_LOW = STATE_WIDTH'('d11);
    localparam STATE_READ_ACK_HIGH = STATE_WIDTH'('d12);
    localparam STATE_START_LOW = STATE_WIDTH'('d13);

    logic[STATE_WIDTH - 1:0] cur_state;
    logic[HALF_PERIOD_COUNTER_WIDTH - 1:0] half_period_counter;
    logic half_period_timeout;
    logic[7:0] write_data_internal;
    logic[7:0] read_data_internal;
    logic[2:0] bit_id;
    logic read_nack_internal;
    logic sda_low;

    assign sda = sda_low ? 1'b0 : 1'bz;
    assign busy = cur_state != STATE_IDLE;
    assign half_period_timeout = (HALF_PERIOD <= 1) || (half_period_counter >= (HALF_PERIOD - 1));

    always_ff @(posedge clk) begin
        if(rst || (cur_state == STATE_IDLE)) begin
            half_period_counter <= '0;
        end
        else if(half_period_timeout) begin
            half_period_counter <= '0;
        end
        else begin
            half_period_counter <= half_period_counter + 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            cur_state <= STATE_IDLE;
            write_data_internal <= '0;
            read_data_internal <= '0;
            read_data <= '0;
            write_ack <= 1'b0;
            bit_id <= '0;
            read_nack_internal <= 1'b0;
            scl <= 1'b1;
            sda_low <= 1'b0;
            done <= 1'b0;
        end
        else begin
            done <= 1'b0;

            case(cur_state)
                STATE_IDLE: begin
                    if(start_request) begin
                        sda_low <= 1'b0;

                        if(scl) begin
                            cur_state <= STATE_START_A;
                        end
                        else begin
                            cur_state <= STATE_START_LOW;
                        end
                    end
                    else if(stop_request) begin
                        scl <= 1'b0;
                        sda_low <= 1'b1;
                        cur_state <= STATE_STOP_A;
                    end
                    else if(write_request) begin
                        write_data_internal <= write_data;
                        bit_id <= 3'd7;
                        scl <= 1'b0;
                        sda_low <= ~write_data[7];
                        cur_state <= STATE_WRITE_LOW;
                    end
                    else if(read_request) begin
                        read_data_internal <= '0;
                        bit_id <= 3'd7;
                        read_nack_internal <= read_nack;
                        scl <= 1'b0;
                        sda_low <= 1'b0;
                        cur_state <= STATE_READ_LOW;
                    end
                end

                STATE_START_LOW: begin
                    if(half_period_timeout) begin
                        scl <= 1'b1;
                        cur_state <= STATE_START_A;
                    end
                end

                STATE_START_A: begin
                    if(half_period_timeout) begin
                        sda_low <= 1'b1;
                        cur_state <= STATE_START_B;
                    end
                end

                STATE_START_B: begin
                    if(half_period_timeout) begin
                        scl <= 1'b0;
                        cur_state <= STATE_IDLE;
                        done <= 1'b1;
                    end
                end

                STATE_STOP_A: begin
                    if(half_period_timeout) begin
                        scl <= 1'b1;
                        cur_state <= STATE_STOP_B;
                    end
                end

                STATE_STOP_B: begin
                    if(half_period_timeout) begin
                        sda_low <= 1'b0;
                        cur_state <= STATE_IDLE;
                        done <= 1'b1;
                    end
                end

                STATE_WRITE_LOW: begin
                    if(half_period_timeout) begin
                        scl <= 1'b1;
                        cur_state <= STATE_WRITE_HIGH;
                    end
                end

                STATE_WRITE_HIGH: begin
                    if(half_period_timeout) begin
                        scl <= 1'b0;

                        if(bit_id == '0) begin
                            sda_low <= 1'b0;
                            cur_state <= STATE_WRITE_ACK_LOW;
                        end
                        else begin
                            bit_id <= bit_id - 1'b1;
                            sda_low <= ~write_data_internal[bit_id - 1'b1];
                            cur_state <= STATE_WRITE_LOW;
                        end
                    end
                end

                STATE_WRITE_ACK_LOW: begin
                    if(half_period_timeout) begin
                        scl <= 1'b1;
                        cur_state <= STATE_WRITE_ACK_HIGH;
                    end
                end

                STATE_WRITE_ACK_HIGH: begin
                    if(half_period_timeout) begin
                        write_ack <= ~sda;
                        scl <= 1'b0;
                        cur_state <= STATE_IDLE;
                        done <= 1'b1;
                    end
                end

                STATE_READ_LOW: begin
                    if(half_period_timeout) begin
                        scl <= 1'b1;
                        cur_state <= STATE_READ_HIGH;
                    end
                end

                STATE_READ_HIGH: begin
                    if(half_period_timeout) begin
                        read_data_internal[bit_id] <= sda;
                        scl <= 1'b0;

                        if(bit_id == '0) begin
                            sda_low <= ~read_nack_internal;
                            cur_state <= STATE_READ_ACK_LOW;
                        end
                        else begin
                            bit_id <= bit_id - 1'b1;
                            cur_state <= STATE_READ_LOW;
                        end
                    end
                end

                STATE_READ_ACK_LOW: begin
                    if(half_period_timeout) begin
                        scl <= 1'b1;
                        cur_state <= STATE_READ_ACK_HIGH;
                    end
                end

                STATE_READ_ACK_HIGH: begin
                    if(half_period_timeout) begin
                        scl <= 1'b0;
                        sda_low <= 1'b0;
                        read_data <= read_data_internal;
                        cur_state <= STATE_IDLE;
                        done <= 1'b1;
                    end
                end

                default: begin
                    cur_state <= STATE_IDLE;
                    scl <= 1'b1;
                    sda_low <= 1'b0;
                end
            endcase
        end
    end
endmodule