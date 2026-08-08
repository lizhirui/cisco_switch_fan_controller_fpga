`default_nettype none

module at24c02_controller #(
        parameter CLK_FREQ = 50000000,
        parameter I2C_FREQ = 100000,
        parameter DATA_NUM = 8,
        parameter EEPROM_ADDR = 3'b000,
        parameter EEPROM_START_ADDR = 8'h00,
        parameter ACK_POLL_MAX = 100,
        parameter AUTO_LOAD = 1'b1,
        parameter AUTO_LOAD_DELAY_CYCLES = CLK_FREQ / 100
    )(
        input logic clk,
        input logic rst,

        input logic save,
        input logic load,
        input logic[7:0] save_data[0:DATA_NUM - 1],
        output logic[7:0] load_data[0:DATA_NUM - 1],
        output logic load_data_valid,
        output logic save_done,
        output logic busy,
        output logic error,

        output logic[2:0] eeprom_addr,
        inout wire eeprom_sda,
        output logic eeprom_scl,
        output logic eeprom_wp
    );

    localparam DATA_ID_WIDTH = (DATA_NUM <= 1) ? 1 : $clog2(DATA_NUM);
    localparam ACK_POLL_COUNTER_WIDTH = (ACK_POLL_MAX <= 1) ? 1 : $clog2(ACK_POLL_MAX);
    localparam AUTO_LOAD_COUNTER_WIDTH = (AUTO_LOAD_DELAY_CYCLES <= 1) ? 1 : $clog2(AUTO_LOAD_DELAY_CYCLES);
    
    localparam STATE_WIDTH = 6;
    localparam STATE_IDLE = STATE_WIDTH'('d0);
    
    localparam STATE_SAVE_START_REQUEST = STATE_WIDTH'('d1);
    localparam STATE_SAVE_START_WAIT = STATE_WIDTH'('d2);
    localparam STATE_SAVE_DEVICE_REQUEST = STATE_WIDTH'('d3);
    localparam STATE_SAVE_DEVICE_WAIT = STATE_WIDTH'('d4);
    localparam STATE_SAVE_ADDR_REQUEST = STATE_WIDTH'('d5);
    localparam STATE_SAVE_ADDR_WAIT = STATE_WIDTH'('d6);
    localparam STATE_SAVE_DATA_REQUEST = STATE_WIDTH'('d7);
    localparam STATE_SAVE_DATA_WAIT = STATE_WIDTH'('d8);
    localparam STATE_SAVE_STOP_REQUEST = STATE_WIDTH'('d9);
    localparam STATE_SAVE_STOP_WAIT = STATE_WIDTH'('d10);

    localparam STATE_POLL_START_REQUEST = STATE_WIDTH'('d11);
    localparam STATE_POLL_START_WAIT = STATE_WIDTH'('d12);
    localparam STATE_POLL_DEVICE_REQUEST = STATE_WIDTH'('d13);
    localparam STATE_POLL_DEVICE_WAIT = STATE_WIDTH'('d14);
    localparam STATE_POLL_STOP_REQUEST = STATE_WIDTH'('d15);
    localparam STATE_POLL_STOP_WAIT = STATE_WIDTH'('d16);

    localparam STATE_LOAD_START_REQUEST = STATE_WIDTH'('d17);
    localparam STATE_LOAD_START_WAIT = STATE_WIDTH'('d18);
    localparam STATE_LOAD_DEVICE_WRITE_REQUEST = STATE_WIDTH'('d19);
    localparam STATE_LOAD_DEVICE_WRITE_WAIT = STATE_WIDTH'('d20);
    localparam STATE_LOAD_ADDR_REQUEST = STATE_WIDTH'('d21);
    localparam STATE_LOAD_ADDR_WAIT = STATE_WIDTH'('d22);
    localparam STATE_LOAD_RESTART_REQUEST = STATE_WIDTH'('d23);
    localparam STATE_LOAD_RESTART_WAIT = STATE_WIDTH'('d24);
    localparam STATE_LOAD_DEVICE_READ_REQUEST = STATE_WIDTH'('d25);
    localparam STATE_LOAD_DEVICE_READ_WAIT = STATE_WIDTH'('d26);
    localparam STATE_LOAD_DATA_REQUEST = STATE_WIDTH'('d27);
    localparam STATE_LOAD_DATA_WAIT = STATE_WIDTH'('d28);
    localparam STATE_LOAD_STOP_REQUEST = STATE_WIDTH'('d29);
    localparam STATE_LOAD_STOP_WAIT = STATE_WIDTH'('d30);

    localparam STATE_ERROR_STOP_REQUEST = STATE_WIDTH'('d31);
    localparam STATE_ERROR_STOP_WAIT = STATE_WIDTH'('d32);

    localparam logic[7:0] DEVICE_WRITE_ADDR = {4'b1010, EEPROM_ADDR[2:0], 1'b0};
    localparam logic[7:0] DEVICE_READ_ADDR = {4'b1010, EEPROM_ADDR[2:0], 1'b1};

    logic[STATE_WIDTH - 1:0] cur_state;

    logic i2c_start_request;
    logic i2c_stop_request;
    logic i2c_write_request;
    logic i2c_read_request;
    logic[7:0] i2c_write_data;
    logic i2c_read_nack;
    logic[7:0] i2c_read_data;
    logic i2c_write_ack;
    logic i2c_busy;
    logic i2c_done;
    
    logic[AUTO_LOAD_COUNTER_WIDTH - 1:0] auto_load_counter;
    logic auto_load_pending;
    logic[DATA_ID_WIDTH - 1:0] data_id;
    logic[ACK_POLL_COUNTER_WIDTH - 1:0] ack_poll_counter;
    logic poll_ack;

    logic[7:0] save_data_internal[0:DATA_NUM - 1];

    assign busy = cur_state != STATE_IDLE;
    assign eeprom_addr = EEPROM_ADDR;
    assign eeprom_wp = 1'b0;

    i2c_master_byte #(
        .CLK_FREQ(CLK_FREQ),
        .I2C_FREQ(I2C_FREQ)
    )i2c_master_byte_inst(
        .clk(clk),
        .rst(rst),
        .start_request(i2c_start_request),
        .stop_request(i2c_stop_request),
        .write_request(i2c_write_request),
        .read_request(i2c_read_request),
        .write_data(i2c_write_data),
        .read_nack(i2c_read_nack),
        .read_data(i2c_read_data),
        .write_ack(i2c_write_ack),
        .busy(i2c_busy),
        .done(i2c_done),
        .scl(eeprom_scl),
        .sda(eeprom_sda)
    );

    always_ff @(posedge clk) begin
        if(rst) begin
            cur_state <= STATE_IDLE;

            i2c_start_request <= 1'b0;
            i2c_stop_request <= 1'b0;
            i2c_write_request <= 1'b0;
            i2c_read_request <= 1'b0;
            i2c_write_data <= '0;
            i2c_read_nack <= 1'b0;

            auto_load_counter <= '0;
            auto_load_pending <= AUTO_LOAD;
            data_id <= '0;
            ack_poll_counter <= '0;
            poll_ack <= 1'b0;

            load_data_valid <= 1'b0;
            save_done <= 1'b0;
            error <= 1'b0;

            for(integer i = 0;i < DATA_NUM;i = i + 1) begin
                save_data_internal[i] <= '0;
                load_data[i] <= '0;
            end
        end
        else begin
            i2c_start_request <= 1'b0;
            i2c_stop_request <= 1'b0;
            i2c_write_request <= 1'b0;
            i2c_read_request <= 1'b0;
            load_data_valid <= 1'b0;
            save_done <= 1'b0;

            case(cur_state)
                STATE_IDLE: begin
                    if(save) begin
                        error <= 1'b0;
                        auto_load_pending <= 1'b0;
                        data_id <= '0;

                        for(integer i = 0;i < DATA_NUM;i = i + 1) begin
                            save_data_internal[i] <= save_data[i];
                        end

                        cur_state <= STATE_SAVE_START_REQUEST;
                    end
                    else if(load) begin
                        error <= 1'b0;
                        auto_load_pending <= 1'b0;
                        data_id <= '0;
                        cur_state <= STATE_LOAD_START_REQUEST;
                    end
                    else if(auto_load_pending) begin
                        if((AUTO_LOAD_DELAY_CYCLES <= 1) || (auto_load_counter >= AUTO_LOAD_DELAY_CYCLES - 1)) begin
                            auto_load_pending <= 1'b0;
                            auto_load_counter <= '0;
                            error <= 1'b0;
                            data_id <= '0;
                            cur_state <= STATE_LOAD_START_REQUEST;
                        end
                        else begin
                            auto_load_counter <= auto_load_counter + 1'b1;
                        end
                    end
                end

                STATE_SAVE_START_REQUEST: begin
                    i2c_start_request <= 1'b1;
                    cur_state <= STATE_SAVE_START_WAIT;
                end

                STATE_SAVE_START_WAIT: begin
                    if(i2c_done) begin
                        cur_state <= STATE_SAVE_DEVICE_REQUEST;
                    end
                end

                STATE_SAVE_DEVICE_REQUEST: begin
                    i2c_write_data <= DEVICE_WRITE_ADDR;
                    i2c_write_request <= 1'b1;
                    cur_state <= STATE_SAVE_DEVICE_WAIT;
                end

                STATE_SAVE_DEVICE_WAIT: begin
                    if(i2c_done) begin
                        if(i2c_write_ack) begin
                            cur_state <= STATE_SAVE_ADDR_REQUEST;
                        end
                        else begin
                            error <= 1'b1;
                            cur_state <= STATE_ERROR_STOP_REQUEST;
                        end
                    end
                end

                STATE_SAVE_ADDR_REQUEST: begin
                    i2c_write_data <= EEPROM_START_ADDR;
                    i2c_write_request <= 1'b1;
                    cur_state <= STATE_SAVE_ADDR_WAIT;
                end

                STATE_SAVE_ADDR_WAIT: begin
                    if(i2c_done) begin
                        if(i2c_write_ack) begin
                            data_id <= '0;
                            cur_state <= STATE_SAVE_DATA_REQUEST;
                        end
                        else begin
                            error <= 1'b1;
                            cur_state <= STATE_ERROR_STOP_REQUEST;
                        end
                    end
                end

                STATE_SAVE_DATA_REQUEST: begin
                    i2c_write_data <= save_data_internal[data_id];
                    i2c_write_request <= 1'b1;
                    cur_state <= STATE_SAVE_DATA_WAIT;
                end

                STATE_SAVE_DATA_WAIT: begin
                    if(i2c_done) begin
                        if(!i2c_write_ack) begin
                            error <= 1'b1;
                            cur_state <= STATE_ERROR_STOP_REQUEST;
                        end
                        else if(data_id >= DATA_NUM - 1) begin
                            cur_state <= STATE_SAVE_STOP_REQUEST;
                        end
                        else begin
                            data_id <= data_id + 1'b1;
                            cur_state <= STATE_SAVE_DATA_REQUEST;
                        end
                    end
                end

                STATE_SAVE_STOP_REQUEST: begin
                    i2c_stop_request <= 1'b1;
                    cur_state <= STATE_SAVE_STOP_WAIT;
                end

                STATE_SAVE_STOP_WAIT: begin
                    if(i2c_done) begin
                        ack_poll_counter <= '0;
                        cur_state <= STATE_POLL_START_REQUEST;
                    end
                end

                STATE_POLL_START_REQUEST: begin
                    i2c_start_request <= 1'b1;
                    cur_state <= STATE_POLL_START_WAIT;
                end

                STATE_POLL_START_WAIT: begin
                    if(i2c_done) begin
                        cur_state <= STATE_POLL_DEVICE_REQUEST;
                    end
                end

                STATE_POLL_DEVICE_REQUEST: begin
                    i2c_write_data <= DEVICE_WRITE_ADDR;
                    i2c_write_request <= 1'b1;
                    cur_state <= STATE_POLL_DEVICE_WAIT;
                end

                STATE_POLL_DEVICE_WAIT: begin
                    if(i2c_done) begin
                        poll_ack <= i2c_write_ack;
                        cur_state <= STATE_POLL_STOP_REQUEST;
                    end
                end

                STATE_POLL_STOP_REQUEST: begin
                    i2c_stop_request <= 1'b1;
                    cur_state <= STATE_POLL_STOP_WAIT;
                end

                STATE_POLL_STOP_WAIT: begin
                    if(i2c_done) begin
                        if(poll_ack) begin
                            save_done <= 1'b1;
                            cur_state <= STATE_IDLE;
                        end
                        else if(ack_poll_counter >= ACK_POLL_MAX - 1) begin
                            error <= 1'b1;
                            cur_state <= STATE_IDLE;
                        end
                        else begin
                            ack_poll_counter <= ack_poll_counter + 1'b1;
                            cur_state <= STATE_POLL_START_REQUEST;
                        end
                    end
                end

                STATE_LOAD_START_REQUEST: begin
                    i2c_start_request <= 1'b1;
                    cur_state <= STATE_LOAD_START_WAIT;
                end

                STATE_LOAD_START_WAIT: begin
                    if(i2c_done) begin
                        cur_state <= STATE_LOAD_DEVICE_WRITE_REQUEST;
                    end
                end

                STATE_LOAD_DEVICE_WRITE_REQUEST: begin
                    i2c_write_data <= DEVICE_WRITE_ADDR;
                    i2c_write_request <= 1'b1;
                    cur_state <= STATE_LOAD_DEVICE_WRITE_WAIT;
                end

                STATE_LOAD_DEVICE_WRITE_WAIT: begin
                    if(i2c_done) begin
                        if(i2c_write_ack) begin
                            cur_state <= STATE_LOAD_ADDR_REQUEST;
                        end
                        else begin
                            error <= 1'b1;
                            cur_state <= STATE_ERROR_STOP_REQUEST;
                        end
                    end
                end

                STATE_LOAD_ADDR_REQUEST: begin
                    i2c_write_data <= EEPROM_START_ADDR;
                    i2c_write_request <= 1'b1;
                    cur_state <= STATE_LOAD_ADDR_WAIT;
                end

                STATE_LOAD_ADDR_WAIT: begin
                    if(i2c_done) begin
                        if(i2c_write_ack) begin
                            cur_state <= STATE_LOAD_RESTART_REQUEST;
                        end
                        else begin
                            error <= 1'b1;
                            cur_state <= STATE_ERROR_STOP_REQUEST;
                        end
                    end
                end

                STATE_LOAD_RESTART_REQUEST: begin
                    i2c_start_request <= 1'b1;
                    cur_state <= STATE_LOAD_RESTART_WAIT;
                end

                STATE_LOAD_RESTART_WAIT: begin
                    if(i2c_done) begin
                        cur_state <= STATE_LOAD_DEVICE_READ_REQUEST;
                    end
                end

                STATE_LOAD_DEVICE_READ_REQUEST: begin
                    i2c_write_data <= DEVICE_READ_ADDR;
                    i2c_write_request <= 1'b1;
                    cur_state <= STATE_LOAD_DEVICE_READ_WAIT;
                end

                STATE_LOAD_DEVICE_READ_WAIT: begin
                    if(i2c_done) begin
                        if(i2c_write_ack) begin
                            data_id <= '0;
                            cur_state <= STATE_LOAD_DATA_REQUEST;
                        end
                        else begin
                            error <= 1'b1;
                            cur_state <= STATE_ERROR_STOP_REQUEST;
                        end
                    end
                end

                STATE_LOAD_DATA_REQUEST: begin
                    i2c_read_nack <= data_id >= DATA_NUM - 1;
                    i2c_read_request <= 1'b1;
                    cur_state <= STATE_LOAD_DATA_WAIT;
                end

                STATE_LOAD_DATA_WAIT: begin
                    if(i2c_done) begin
                        load_data[data_id] <= i2c_read_data;

                        if(data_id >= DATA_NUM - 1) begin
                            cur_state <= STATE_LOAD_STOP_REQUEST;
                        end
                        else begin
                            data_id <= data_id + 1'b1;
                            cur_state <= STATE_LOAD_DATA_REQUEST;
                        end
                    end
                end

                STATE_LOAD_STOP_REQUEST: begin
                    i2c_stop_request <= 1'b1;
                    cur_state <= STATE_LOAD_STOP_WAIT;
                end

                STATE_LOAD_STOP_WAIT: begin
                    if(i2c_done) begin
                        load_data_valid <= 1'b1;
                        cur_state <= STATE_IDLE;
                    end
                end

                STATE_ERROR_STOP_REQUEST: begin
                    i2c_stop_request <= 1'b1;
                    cur_state <= STATE_ERROR_STOP_WAIT;
                end

                STATE_ERROR_STOP_WAIT: begin
                    if(i2c_done) begin
                        cur_state <= STATE_IDLE;
                    end
                end

                default: begin
                    error <= 1'b1;
                    cur_state <= STATE_IDLE;
                end
            endcase
        end
    end
endmodule