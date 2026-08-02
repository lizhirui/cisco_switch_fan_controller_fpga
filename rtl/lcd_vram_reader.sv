`default_nettype none

module lcd_vram_reader #(
        parameter LCD_PIXEL_LINE_NUM = 64,
        parameter LCD_PIXEL_COL_NUM = 128,
        parameter DATA_WIDTH = 8,
        parameter ADDR_WIDTH = (LCD_PIXEL_LINE_NUM * LCD_PIXEL_COL_NUM / DATA_WIDTH <= 1) ? 1 : $clog2(LCD_PIXEL_LINE_NUM * LCD_PIXEL_COL_NUM / DATA_WIDTH)
    )(
        input logic clk,
        input logic rst,

        output logic[ADDR_WIDTH - 1:0] vram_addr,
        input logic[DATA_WIDTH - 1:0] vram_data,
        output logic frame_end,
        
        output logic[DATA_WIDTH - 1:0] out_data,
        output logic out_data_push,
        input logic out_data_full
    );

    localparam PAGE_NUM = LCD_PIXEL_LINE_NUM / DATA_WIDTH;
    localparam PAGE_ID_WIDTH = (PAGE_NUM <= 1) ? 1 : $clog2(PAGE_NUM);
    localparam TILE_NUM = LCD_PIXEL_COL_NUM / DATA_WIDTH;
    localparam TILE_ID_WIDTH = (TILE_NUM <= 1) ? 1 : $clog2(TILE_NUM);
    localparam TILE_OFFSET_WIDTH = ADDR_WIDTH - PAGE_ID_WIDTH - TILE_ID_WIDTH;

    localparam STATE_WIDTH = 2;
    localparam STATE_SEND_ADDR = STATE_WIDTH'('d0);
    localparam STATE_WAIT_DATA = STATE_WIDTH'('d1);
    
    logic[STATE_WIDTH - 1:0] cur_state;
    logic[STATE_WIDTH - 1:0] next_state;
    logic[ADDR_WIDTH - 1:0] read_cnt;
    logic[ADDR_WIDTH - 1:0] vram_addr_cnt;
    logic out_data_load;

    assign out_data_load = (cur_state == STATE_WAIT_DATA) && (!out_data_push || !out_data_full);
    
    always_comb begin
        vram_addr_cnt = read_cnt;

        if(out_data_load) begin
            vram_addr_cnt = read_cnt + 'b1;
        end
    end

    assign vram_addr = {vram_addr_cnt[TILE_OFFSET_WIDTH + TILE_ID_WIDTH +: PAGE_ID_WIDTH], vram_addr_cnt[0 +: TILE_OFFSET_WIDTH], vram_addr_cnt[TILE_OFFSET_WIDTH +: TILE_ID_WIDTH]};

    always_ff @(posedge clk) begin
        if(rst) begin
            cur_state <= STATE_SEND_ADDR;
        end
        else begin
            cur_state <= next_state;
        end
    end

    always_comb begin
        next_state = cur_state;

        case(cur_state)
            STATE_SEND_ADDR: begin
                next_state = STATE_WAIT_DATA;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            read_cnt <= '0;
        end
        else if(out_data_load) begin
            read_cnt <= read_cnt + 'b1;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            out_data <= '0;
            out_data_push <= 1'b0;
        end
        else if(out_data_load) begin
            out_data <= vram_data;
            out_data_push <= 1'b1;
        end
        else if(out_data_push && !out_data_full) begin
            out_data <= '0;
            out_data_push <= 1'b0;
        end
    end

    assign frame_end = out_data_load && (read_cnt == '1);
endmodule