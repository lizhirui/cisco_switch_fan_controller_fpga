`default_nettype none

import lcd_ui_page_config_pkg::*;

module page_message_controller #(
        parameter CLK_FREQ = 50000000
    )(
        input logic clk,
        input logic rst,

        input logic[PAGE_ID_WIDTH - 1:0] page_id,

        input logic[PAGE_ID_WIDTH - 1:0] page_id_wdata_in,
        input logic page_id_we_in,
        output logic[PAGE_ID_WIDTH - 1:0] page_id_wdata,
        output logic page_id_we,

        input logic key_save_pulse,
        input logic key_load_pulse,

        input logic eeprom_save_done,
        input logic eeprom_load_done,
        input logic eeprom_busy,
        input logic eeprom_error
    );

    localparam MESSAGE_COUNTER_WIDTH = (CLK_FREQ <= 1) ? 1 : $clog2(CLK_FREQ);
    localparam logic[MESSAGE_COUNTER_WIDTH - 1:0] MESSAGE_COUNTER_RELOAD = MESSAGE_COUNTER_WIDTH'(CLK_FREQ - 1);

    localparam STATE_WIDTH = 2;
    localparam logic[STATE_WIDTH - 1:0] STATE_IDLE = STATE_WIDTH'('d0);
    localparam logic[STATE_WIDTH - 1:0] STATE_WAIT_SHOW = STATE_WIDTH'('d1);
    localparam logic[STATE_WIDTH - 1:0] STATE_COUNT = STATE_WIDTH'('d2);
    localparam logic[STATE_WIDTH - 1:0] STATE_WAIT_RETURN = STATE_WIDTH'('d3);

    logic[STATE_WIDTH - 1:0] cur_state;

    logic manual_save_pending;
    logic manual_load_pending;

    logic[PAGE_ID_WIDTH - 1:0] return_page_id;
    logic[PAGE_ID_WIDTH - 1:0] message_page_id;

    logic[MESSAGE_COUNTER_WIDTH - 1:0] message_counter;

    logic[PAGE_ID_WIDTH - 1:0] page_id_override_wdata;
    logic page_id_override_we;

    always_ff @(posedge clk) begin
        if(rst) begin
            cur_state <= STATE_IDLE;
            manual_save_pending <= 1'b0;
            manual_load_pending <= 1'b0;
            return_page_id <= '0;
            message_page_id <= '0;
            message_counter <= '0;
            page_id_override_wdata <= '0;
            page_id_override_we <= 1'b0;
        end
        else begin
            page_id_override_we <= 1'b0;

            case(cur_state)
                STATE_IDLE: begin
                    if(key_save_pulse) begin
                        manual_save_pending <= 1'b1;
                        manual_load_pending <= 1'b0;
                        return_page_id <= page_id;
                    end
                    else if(key_load_pulse) begin
                        manual_save_pending <= 1'b0;
                        manual_load_pending <= 1'b1;
                        return_page_id <= page_id;
                    end

                    if(eeprom_save_done && manual_save_pending) begin
                        manual_save_pending <= 1'b0;
                        message_page_id <= PAGE_SAVE_SUCCESS_ID;
                        page_id_override_wdata <= PAGE_SAVE_SUCCESS_ID;
                        page_id_override_we <= 1'b1;
                        cur_state <= STATE_WAIT_SHOW;
                    end
                    else if(eeprom_load_done && manual_load_pending) begin
                        manual_load_pending <= 1'b0;
                        message_page_id <= PAGE_LOAD_SUCCESS_ID;
                        page_id_override_wdata <= PAGE_LOAD_SUCCESS_ID;
                        page_id_override_we <= 1'b1;
                        cur_state <= STATE_WAIT_SHOW;
                    end
                    else if(!eeprom_busy && eeprom_error) begin
                        manual_save_pending <= 1'b0;
                        manual_load_pending <= 1'b0;
                    end
                end

                STATE_WAIT_SHOW: begin
                    if(page_id == message_page_id) begin
                        message_counter <= MESSAGE_COUNTER_RELOAD;
                        cur_state <= STATE_COUNT;
                    end
                end

                STATE_COUNT: begin
                    if(message_counter == '0) begin
                        page_id_override_wdata <= return_page_id;
                        page_id_override_we <= 1'b1;
                        cur_state <= STATE_WAIT_RETURN;
                    end
                    else begin
                        message_counter <= message_counter - 1'b1;
                    end
                end

                STATE_WAIT_RETURN: begin
                    if(page_id == return_page_id) begin
                        cur_state <= STATE_IDLE;
                    end
                end

                default: begin
                    cur_state <= STATE_IDLE;
                end
            endcase
        end
    end

    always_comb begin
        page_id_wdata = page_id_wdata_in;
        page_id_we = page_id_we_in;

        if(cur_state != STATE_IDLE) begin
            page_id_wdata = '0;
            page_id_we = 1'b0;
        end

        if(page_id_override_we) begin
            page_id_wdata = page_id_override_wdata;
            page_id_we = 1'b1;
        end
    end
endmodule