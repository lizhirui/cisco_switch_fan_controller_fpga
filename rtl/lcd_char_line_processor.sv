`default_nettype none

module lcd_char_line_processor #(
        parameter PAGE_ID_WIDTH = 2,
        parameter LCD_LINE_NUM = 4,
        parameter LINE_ID_WIDTH = (LCD_LINE_NUM <= 1) ? 1 : $clog2(LCD_LINE_NUM),
        parameter LINE_DATA_WIDTH = 128,
        parameter CHAR_DATA_WIDTH = 8,
        parameter ROM_ADDR_WIDTH = 24,
        parameter ROM_LEN_WIDTH = 6
    )(
        input logic clk,
        input logic rst,

        input logic[PAGE_ID_WIDTH - 1:0] page_id_in,
        input logic page_id_in_valid,

        output logic[PAGE_ID_WIDTH - 1:0] page_id,
        output logic[LINE_ID_WIDTH - 1:0] line_id,
        input logic[LINE_DATA_WIDTH - 1:0] line_data,

        output logic[ROM_ADDR_WIDTH - 1:0] rom_reader_addr,
        output logic[ROM_LEN_WIDTH - 1:0] rom_reader_len,
        output logic rom_reader_start,
        input logic rom_reader_busy
    );

    localparam LINE_CHAR_NUM = LINE_DATA_WIDTH / CHAR_DATA_WIDTH;
    localparam CHAR_ID_WIDTH = (LINE_CHAR_NUM <= 1) ? 1 : $clog2(LINE_CHAR_NUM);

    localparam STATE_WIDTH = 3;
    localparam STATE_WAIT_LINE_DATA = STATE_WIDTH'('d0);
    localparam STATE_GET_LINE_DATA = STATE_WIDTH'('d1);
    localparam STATE_CAL_ROM_READER_ADDR = STATE_WIDTH'('d2);
    localparam STATE_SEND_REQ_TO_ROM_READER = STATE_WIDTH'('d3);
    localparam STATE_WAIT_ROM_READER_OK = STATE_WIDTH'('d4);

    logic[STATE_WIDTH - 1:0] cur_state;
    logic[STATE_WIDTH - 1:0] next_state;
    logic[PAGE_ID_WIDTH - 1:0] page_id_loaded;
    logic[LINE_DATA_WIDTH - 1:0] line_data_loaded;
    logic[CHAR_ID_WIDTH - 1:0] char_id;
    logic[ROM_ADDR_WIDTH - 1:0] rom_addr_cal;
    logic char_inc2;

    always_ff @(posedge clk) begin
        if(rst) begin
            cur_state <= STATE_WAIT_LINE_DATA;
        end
        else begin
            cur_state <= next_state;
        end
    end
    
    always_comb begin
        next_state = cur_state;

        case(cur_state)
            STATE_WAIT_LINE_DATA: begin
                next_state = STATE_GET_LINE_DATA;
            end

            STATE_GET_LINE_DATA: begin
                next_state = STATE_CAL_ROM_READER_ADDR;
            end

            STATE_CAL_ROM_READER_ADDR: begin
                next_state = STATE_SEND_REQ_TO_ROM_READER;
            end

            STATE_SEND_REQ_TO_ROM_READER: begin
                next_state = STATE_WAIT_ROM_READER_OK;
            end

            STATE_WAIT_ROM_READER_OK: begin
                if(!rom_reader_busy) begin
                    if(char_id == '0) begin
                        next_state = STATE_GET_LINE_DATA;
                    end
                    else begin
                        next_state = STATE_CAL_ROM_READER_ADDR;
                    end
                end
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            page_id <= '0;
        end
        else if((cur_state == STATE_GET_LINE_DATA) && (line_id >= unsigned'(LCD_LINE_NUM - 'b1))) begin
            page_id <= page_id_loaded;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            line_id <= '0;
        end
        else if(cur_state == STATE_GET_LINE_DATA) begin
            if(line_id >= unsigned'(LCD_LINE_NUM - 'b1)) begin
                line_id <= '0;
            end
            else begin
                line_id <= line_id + 'b1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            rom_reader_addr <= '0;
            rom_reader_len <= '0;
        end
        else if(cur_state == STATE_CAL_ROM_READER_ADDR) begin
            rom_reader_addr <= rom_addr_cal;
            rom_reader_len <= char_inc2 ? 'd32 : 'd16;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            rom_reader_start <= 1'b0;
        end
        else if(cur_state == STATE_CAL_ROM_READER_ADDR) begin
            rom_reader_start <= 1'b1;
        end
        else begin
            rom_reader_start <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            page_id_loaded <= '0;
        end
        else if(page_id_in_valid) begin
            page_id_loaded <= page_id_in;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            line_data_loaded <= '0;
        end
        else if(cur_state == STATE_GET_LINE_DATA) begin
            line_data_loaded <= line_data;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            char_id <= '0;
        end
        else if(cur_state == STATE_CAL_ROM_READER_ADDR) begin
            if(char_id >= (LINE_CHAR_NUM - (char_inc2 ? 'd2 : 'd1))) begin
                char_id <= '0;
            end
            else begin
                char_id <= char_id + (char_inc2 ? 'd2 : 'd1);
            end
        end
    end

    lcd_rom_font_addr_generator #(
        .CHAR_DATA_WIDTH(CHAR_DATA_WIDTH),
        .ADDR_WIDTH(ROM_ADDR_WIDTH)
    )lcd_rom_font_addr_generator_inst(
        .cur_char(line_data_loaded[char_id * CHAR_DATA_WIDTH +: CHAR_DATA_WIDTH]),
        .next_char((char_id >= unsigned'(LINE_CHAR_NUM - 'b1)) ? '0 : line_data_loaded[(char_id + 'b1) * CHAR_DATA_WIDTH +: CHAR_DATA_WIDTH]),
        .next_char_valid((char_id >= unsigned'(LINE_CHAR_NUM - 'b1)) ? 1'b0 : 1'b1),
        .addr(rom_addr_cal),
        .char_inc2(char_inc2)
    );
endmodule