`default_nettype none

import lcd_ui_config_pkg::*;
import lcd_font_stream_pkg::*;

module lcd_ui_renderer #(
        parameter LCD_PIXEL_LINE_NUM = 64,
        parameter LCD_PIXEL_COL_NUM = 128,
        parameter ROM_ADDR_WIDTH = 24,
        parameter ENABLE_DRAW_BITMAP = 1'b1
    )(
        input logic clk,
        input logic rst,
        
        input logic config_start,
        output logic config_busy,
        input lcd_ui_config_data_t config_data,
        
        output logic[ROM_ADDR_WIDTH - 1:0] rom_reader_addr,
        output lcd_font_data_len_t rom_reader_len,
        output logic rom_reader_start,
        input logic rom_reader_busy,
        
        output lcd_ui_x_t char_x,
        output lcd_ui_y_t char_y,
        output lcd_ui_color_t char_color,
        
        output logic draw_writer_start,
        input logic draw_writer_busy,
        output lcd_ui_config_data_t draw_writer_config_data,
        
        input logic render_pipeline_idle,
        output logic frame_submit,
        input logic frame_submit_busy
    );
    
    localparam TEXT_CHAR_NUM = LCD_UI_TEXT_DATA_WIDTH / LCD_FONT_DATA_WIDTH;
    localparam CHAR_ID_WIDTH = (TEXT_CHAR_NUM <= 1) ? 1 : $clog2(TEXT_CHAR_NUM);
    
    localparam STATE_WIDTH = 5;
    
    localparam STATE_WAIT_CONFIG = STATE_WIDTH'('d0);
    
    localparam STATE_NOP = STATE_WIDTH'('d1);
    
    localparam STATE_DRAW_TEXT_CHECK = STATE_WIDTH'('d2);
    localparam STATE_DRAW_TEXT_CAL_ROM_READER_ADDR = STATE_WIDTH'('d3);
    localparam STATE_DRAW_TEXT_SEND_REQ_TO_ROM_READER = STATE_WIDTH'('d4);
    localparam STATE_DRAW_TEXT_WAIT_ROM_READER_OK = STATE_WIDTH'('d5);
    
    localparam STATE_DRAW_BITMAP_WAIT_RENDER_PIPELINE_IDLE = STATE_WIDTH'('d6);
    localparam STATE_DRAW_BITMAP_START = STATE_WIDTH'('d7);
    localparam STATE_DRAW_BITMAP_WAIT = STATE_WIDTH'('d8);
    
    localparam STATE_FILL_RECT_WAIT_RENDER_PIPELINE_IDLE = STATE_WIDTH'('d9);
    localparam STATE_FILL_RECT_START = STATE_WIDTH'('d10);
    localparam STATE_FILL_RECT_WAIT = STATE_WIDTH'('d11);
    
    localparam STATE_DRAW_LINE_WAIT_RENDER_PIPELINE_IDLE = STATE_WIDTH'('d12);
    localparam STATE_DRAW_LINE_START = STATE_WIDTH'('d13);
    localparam STATE_DRAW_LINE_WAIT = STATE_WIDTH'('d14);
    
    localparam STATE_CLEAR_WAIT_RENDER_PIPELINE_IDLE = STATE_WIDTH'('d15);
    localparam STATE_CLEAR_START = STATE_WIDTH'('d16);
    localparam STATE_CLEAR_WAIT = STATE_WIDTH'('d17);
    
    localparam STATE_FRAME_END_WAIT_RENDER_PIPELINE_IDLE = STATE_WIDTH'('d18);
    localparam STATE_FRAME_END_FRAME_SUBMIT = STATE_WIDTH'('d19);
    localparam STATE_FRAME_END_WAIT_FRAME_SUBMIT_OK = STATE_WIDTH'('d20);
    
    logic[STATE_WIDTH - 1:0] cur_state;
    logic[STATE_WIDTH - 1:0] next_state;
    
    lcd_ui_config_type_t decoded_config_type;
    logic decoded_config_nop;
    logic decoded_config_draw_text;
    logic decoded_config_draw_bitmap;
    logic decoded_config_fill_rect;
    logic decoded_config_draw_line;
    logic decoded_config_clear;
    logic decoded_config_frame_end;
    logic decoded_config_error;
    lcd_ui_x_t decoded_draw_text_x;
    lcd_ui_y_t decoded_draw_text_y;
    lcd_ui_color_t decoded_draw_text_color;
    lcd_ui_text_data_t decoded_draw_text_text;
    
    lcd_ui_y_t draw_text_y_loaded;
    lcd_ui_color_t draw_text_color_loaded;
    lcd_ui_text_data_t draw_text_text_loaded;
    logic[CHAR_ID_WIDTH - 1:0] char_id;
    logic[LCD_UI_X_WIDTH:0] text_cursor_x;
    
    lcd_font_data_t cur_char;
    lcd_font_data_t next_char;
    logic next_char_valid;
    logic[ROM_ADDR_WIDTH - 1:0] rom_addr_cal;
    logic char_inc2;
    logic char_last;
    logic text_end;
    
    logic draw_writer_config_load;
    
    always_ff @(posedge clk) begin
        if(rst) begin
            cur_state <= STATE_WAIT_CONFIG;
        end
        else begin
            cur_state <= next_state;
        end
    end
    
    always_comb begin
        next_state = cur_state;
        
        case(cur_state)
            STATE_WAIT_CONFIG: begin
                if(config_start) begin
                    if(decoded_config_nop) begin
                        next_state = STATE_NOP;
                    end
                    else if(decoded_config_draw_text) begin
                        next_state = STATE_DRAW_TEXT_CHECK;
                    end
                    else if(ENABLE_DRAW_BITMAP && decoded_config_draw_bitmap) begin
                        next_state = STATE_DRAW_BITMAP_WAIT_RENDER_PIPELINE_IDLE;
                    end
                    else if(decoded_config_fill_rect) begin
                        next_state = STATE_FILL_RECT_WAIT_RENDER_PIPELINE_IDLE;
                    end
                    else if(decoded_config_draw_line) begin
                        next_state = STATE_DRAW_LINE_WAIT_RENDER_PIPELINE_IDLE;
                    end
                    else if(decoded_config_clear) begin
                        next_state = STATE_CLEAR_WAIT_RENDER_PIPELINE_IDLE;
                    end
                    else if(decoded_config_frame_end) begin
                        next_state = STATE_FRAME_END_WAIT_RENDER_PIPELINE_IDLE;
                    end
                end
            end
            
            STATE_NOP: begin
                next_state = STATE_WAIT_CONFIG;
            end
            
            STATE_DRAW_TEXT_CHECK: begin
                if(text_end) begin
                    next_state = STATE_WAIT_CONFIG;
                end
                else begin
                    next_state = STATE_DRAW_TEXT_CAL_ROM_READER_ADDR;
                end
            end
            
            STATE_DRAW_TEXT_CAL_ROM_READER_ADDR: begin
                next_state = STATE_DRAW_TEXT_SEND_REQ_TO_ROM_READER;
            end
            
            STATE_DRAW_TEXT_SEND_REQ_TO_ROM_READER: begin
                next_state = STATE_DRAW_TEXT_WAIT_ROM_READER_OK;
            end
            
            STATE_DRAW_TEXT_WAIT_ROM_READER_OK: begin
                if(!rom_reader_busy) begin
                    if(char_last) begin
                        next_state = STATE_WAIT_CONFIG;
                    end
                    else begin
                        next_state = STATE_DRAW_TEXT_CHECK;
                    end
                end
            end
            
            STATE_DRAW_BITMAP_WAIT_RENDER_PIPELINE_IDLE: begin
                if(render_pipeline_idle) begin
                    next_state = STATE_DRAW_BITMAP_START;
                end
            end
            
            STATE_DRAW_BITMAP_START: begin
                next_state = STATE_DRAW_BITMAP_WAIT;
            end
            
            STATE_DRAW_BITMAP_WAIT: begin
                if(!draw_writer_busy) begin
                    next_state = STATE_WAIT_CONFIG;
                end
            end
            
            STATE_FILL_RECT_WAIT_RENDER_PIPELINE_IDLE: begin
                if(render_pipeline_idle) begin
                    next_state = STATE_FILL_RECT_START;
                end
            end

            STATE_FILL_RECT_START: begin
                next_state = STATE_FILL_RECT_WAIT;
            end

            STATE_FILL_RECT_WAIT: begin
                if(!draw_writer_busy) begin
                    next_state = STATE_WAIT_CONFIG;
                end
            end
            
            STATE_DRAW_LINE_WAIT_RENDER_PIPELINE_IDLE: begin
                if(render_pipeline_idle) begin
                    next_state = STATE_DRAW_LINE_START;
                end
            end

            STATE_DRAW_LINE_START: begin
                next_state = STATE_DRAW_LINE_WAIT;
            end

            STATE_DRAW_LINE_WAIT: begin
                if(!draw_writer_busy) begin
                    next_state = STATE_WAIT_CONFIG;
                end
            end
            
            STATE_CLEAR_WAIT_RENDER_PIPELINE_IDLE: begin
                if(render_pipeline_idle) begin
                    next_state = STATE_CLEAR_START;
                end
            end

            STATE_CLEAR_START: begin
                next_state = STATE_CLEAR_WAIT;
            end

            STATE_CLEAR_WAIT: begin
                if(!draw_writer_busy) begin
                    next_state = STATE_WAIT_CONFIG;
                end
            end
            
            STATE_FRAME_END_WAIT_RENDER_PIPELINE_IDLE: begin
                if(render_pipeline_idle && !frame_submit_busy) begin
                    next_state = STATE_FRAME_END_FRAME_SUBMIT;
                end
            end
            
            STATE_FRAME_END_FRAME_SUBMIT: begin
                next_state = STATE_FRAME_END_WAIT_FRAME_SUBMIT_OK;
            end
            
            STATE_FRAME_END_WAIT_FRAME_SUBMIT_OK: begin
                if(!frame_submit_busy) begin
                    next_state = STATE_WAIT_CONFIG;
                end
            end
        endcase
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            config_busy <= 1'b0;
        end
        else if((cur_state == STATE_WAIT_CONFIG) && (next_state != STATE_WAIT_CONFIG)) begin
            config_busy <= 1'b1;
        end
        else if((cur_state != STATE_WAIT_CONFIG) && (next_state == STATE_WAIT_CONFIG)) begin
            config_busy <= 1'b0;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            rom_reader_addr <= '0;
        end
        else if(cur_state == STATE_DRAW_TEXT_CAL_ROM_READER_ADDR) begin
            rom_reader_addr <= rom_addr_cal;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            rom_reader_len <= '0;
        end
        else if(cur_state == STATE_DRAW_TEXT_CAL_ROM_READER_ADDR) begin
            rom_reader_len <= char_inc2 ? 'd32 : 'd16;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            rom_reader_start <= 1'b0;
        end
        else if((cur_state != next_state) && (next_state == STATE_DRAW_TEXT_SEND_REQ_TO_ROM_READER)) begin
            rom_reader_start <= 1'b1;
        end
        else begin
            rom_reader_start <= 1'b0;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            char_x <= '0;
            char_y <= '0;
            char_color <= LCD_UI_COLOR_BLACK;
        end
        else if(cur_state == STATE_DRAW_TEXT_CAL_ROM_READER_ADDR) begin
            char_x <= text_cursor_x[LCD_UI_X_WIDTH - 1:0];
            char_y <= draw_text_y_loaded;
            char_color <= draw_text_color_loaded;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            draw_writer_start <= 1'b0;
        end
        else if((ENABLE_DRAW_BITMAP && (next_state == STATE_DRAW_BITMAP_START)) || (next_state == STATE_FILL_RECT_START) || (next_state == STATE_DRAW_LINE_START) || (next_state == STATE_CLEAR_START)) begin
            draw_writer_start <= 1'b1;
        end
        else begin
            draw_writer_start <= 1'b0;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            draw_writer_config_data <= '0;
        end
        else if(draw_writer_config_load) begin
            draw_writer_config_data <= config_data;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            frame_submit <= 1'b0;
        end
        else if((cur_state != next_state) && (next_state == STATE_FRAME_END_FRAME_SUBMIT)) begin
            frame_submit <= 1'b1;
        end
        else begin
            frame_submit <= 1'b0;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            draw_text_y_loaded <= '0;
            draw_text_color_loaded <= LCD_UI_COLOR_BLACK;
            draw_text_text_loaded <= '0;
        end
        else if((cur_state == STATE_WAIT_CONFIG) && (next_state == STATE_DRAW_TEXT_CHECK)) begin
            draw_text_y_loaded <= decoded_draw_text_y;
            draw_text_color_loaded <= decoded_draw_text_color;
            draw_text_text_loaded <= decoded_draw_text_text;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            char_id <= '0;
        end
        else if((cur_state == STATE_WAIT_CONFIG) && (next_state == STATE_DRAW_TEXT_CHECK)) begin
            char_id <= '0;
        end
        else if((cur_state == STATE_DRAW_TEXT_WAIT_ROM_READER_OK) && (next_state == STATE_DRAW_TEXT_CHECK)) begin
            char_id <= char_id + (char_inc2 ? 'd2 : 'd1);
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            text_cursor_x <= '0;
        end
        else if((cur_state == STATE_WAIT_CONFIG) && (next_state == STATE_DRAW_TEXT_CHECK)) begin
            text_cursor_x <= decoded_draw_text_x;
        end
        else if((cur_state == STATE_DRAW_TEXT_WAIT_ROM_READER_OK) && (next_state == STATE_DRAW_TEXT_CHECK)) begin
            text_cursor_x <= text_cursor_x + (char_inc2 ? 'd16 : 'd8);
        end
    end
    
    assign cur_char = draw_text_text_loaded[char_id * LCD_FONT_DATA_WIDTH +: LCD_FONT_DATA_WIDTH];
    assign next_char = (char_id >= unsigned'(TEXT_CHAR_NUM - 'b1)) ? '0 : draw_text_text_loaded[(char_id + 'b1) * LCD_FONT_DATA_WIDTH +: LCD_FONT_DATA_WIDTH];
    assign next_char_valid = (char_id >= unsigned'(TEXT_CHAR_NUM - 'b1)) ? 1'b0 : 1'b1;
    assign char_last = (char_id >= (TEXT_CHAR_NUM - (char_inc2 ? 'd2 : 'd1))) ? 1'b1 : 1'b0;
    assign text_end = ((cur_char == '0) || (text_cursor_x >= unsigned'(LCD_PIXEL_COL_NUM)) || (draw_text_y_loaded >= unsigned'(LCD_PIXEL_LINE_NUM))) ? 1'b1 : 1'b0;
    
    lcd_ui_config_decoder lcd_ui_config_decoder_inst(
        .config_data(config_data),
        .config_type(decoded_config_type),
        .config_nop(decoded_config_nop),
        .config_draw_text(decoded_config_draw_text),
        .config_draw_bitmap(decoded_config_draw_bitmap),
        .config_fill_rect(decoded_config_fill_rect),
        .config_draw_line(decoded_config_draw_line),
        .config_clear(decoded_config_clear),
        .config_frame_end(decoded_config_frame_end),
        .config_error(decoded_config_error),
        .draw_text_x(decoded_draw_text_x),
        .draw_text_y(decoded_draw_text_y),
        .draw_text_color(decoded_draw_text_color),
        .draw_text_text(decoded_draw_text_text)
    );
    
    lcd_rom_font_addr_generator #(
        .CHAR_DATA_WIDTH(LCD_FONT_DATA_WIDTH),
        .ADDR_WIDTH(ROM_ADDR_WIDTH)
    )lcd_rom_font_addr_generator_inst(
        .cur_char(cur_char),
        .next_char(next_char),
        .next_char_valid(next_char_valid),
        .addr(rom_addr_cal),
        .char_inc2(char_inc2)
    );
    
    assign draw_writer_config_load = ((cur_state == STATE_WAIT_CONFIG) && ((ENABLE_DRAW_BITMAP && (next_state == STATE_DRAW_BITMAP_WAIT_RENDER_PIPELINE_IDLE)) || (next_state == STATE_FILL_RECT_WAIT_RENDER_PIPELINE_IDLE) || (next_state == STATE_DRAW_LINE_WAIT_RENDER_PIPELINE_IDLE) || (next_state == STATE_CLEAR_WAIT_RENDER_PIPELINE_IDLE))) ? 1'b1 : 1'b0;
endmodule