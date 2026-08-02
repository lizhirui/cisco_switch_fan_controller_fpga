`default_nettype none

import lcd_ui_config_pkg::*;

module lcd_ui_draw_writer #(
        parameter LCD_PIXEL_LINE_NUM = 64,
        parameter LCD_PIXEL_COL_NUM = 128,
        parameter VRAM_ADDR_WIDTH = 10,
        parameter VRAM_DATA_WIDTH = 8
    )(
        input logic clk,
        input logic rst,
        
        input logic start,
        output logic busy,
        input lcd_ui_config_data_t config_data,
        
        output logic[VRAM_ADDR_WIDTH - 1:0] vwc_raddr,
        input logic[VRAM_DATA_WIDTH - 1:0] vwc_rdata,
        output logic[VRAM_ADDR_WIDTH - 1:0] vwc_waddr,
        output logic[VRAM_DATA_WIDTH - 1:0] vwc_wdata,
        output logic vwc_we,
        input logic vwc_busy
    );
    
    localparam VRAM_BYTE_COL_NUM = LCD_PIXEL_COL_NUM / VRAM_DATA_WIDTH;
    localparam VRAM_BYTE_COL_WIDTH = $clog2(VRAM_BYTE_COL_NUM);
    localparam VRAM_DATA_OFFSET_WIDTH = $clog2(VRAM_DATA_WIDTH);
    localparam VRAM_DEPTH = LCD_PIXEL_LINE_NUM * VRAM_BYTE_COL_NUM;
    
    localparam logic[VRAM_ADDR_WIDTH - 1:0]VRAM_LAST_ADDR = VRAM_ADDR_WIDTH'(VRAM_DEPTH - 1);
    localparam logic[VRAM_DATA_OFFSET_WIDTH - 1:0] VRAM_DATA_OFFSET_MAX = VRAM_DATA_OFFSET_WIDTH'(VRAM_DATA_WIDTH - 1);
    localparam logic[LCD_UI_X_WIDTH:0] LCD_PIXEL_COL_NUM_VALUE = LCD_PIXEL_COL_NUM;
    localparam logic[LCD_UI_Y_WIDTH:0] LCD_PIXEL_LINE_NUM_VALUE = LCD_PIXEL_LINE_NUM;
    
    localparam DRAW_LINE_COORD_WIDTH = (LCD_UI_X_WIDTH > LCD_UI_Y_WIDTH) ? LCD_UI_X_WIDTH : LCD_UI_Y_WIDTH;
    localparam DRAW_LINE_CALC_WIDTH = DRAW_LINE_COORD_WIDTH + 3;
    
    localparam STATE_WIDTH = 4;
    
    localparam STATE_IDLE = STATE_WIDTH'('d0);
    localparam STATE_WAIT_VWC_IDLE = STATE_WIDTH'('d1);
    
    localparam STATE_FILL_RECT_INIT = STATE_WIDTH'('d2);
    localparam STATE_FILL_RECT_CHECK = STATE_WIDTH'('d3);
    localparam STATE_FILL_RECT_READ = STATE_WIDTH'('d4);
    localparam STATE_FILL_RECT_WAIT = STATE_WIDTH'('d5);
    localparam STATE_FILL_RECT_WRITE = STATE_WIDTH'('d6);
    
    localparam STATE_DRAW_LINE_INIT = STATE_WIDTH'('d7);
    localparam STATE_DRAW_LINE_CHECK = STATE_WIDTH'('d8);
    localparam STATE_DRAW_LINE_READ = STATE_WIDTH'('d9);
    localparam STATE_DRAW_LINE_WAIT = STATE_WIDTH'('d10);
    localparam STATE_DRAW_LINE_WRITE = STATE_WIDTH'('d11);
    localparam STATE_DRAW_LINE_NEXT = STATE_WIDTH'('d12);
    
    localparam STATE_CLEAR_INIT = STATE_WIDTH'('d13);
    localparam STATE_CLEAR_WRITE = STATE_WIDTH'('d14);
    
    logic[STATE_WIDTH - 1:0] cur_state;
    logic[STATE_WIDTH - 1:0] next_state;
    
    lcd_ui_config_data_t config_data_loaded;
    lcd_ui_config_type_t config_type_loaded;
    lcd_ui_fill_rect_config_t fill_rect_config_loaded;
    lcd_ui_clear_config_t clear_config_loaded;
    
    logic fill_rect_config_valid_cal;
    logic fill_rect_config_valid_loaded;
    
    logic[LCD_UI_X_WIDTH:0] fill_rect_x_end_cal;
    logic[LCD_UI_X_WIDTH:0] fill_rect_x_end_clipped_cal;
    logic[LCD_UI_X_WIDTH:0] fill_rect_x_last_cal;
    
    logic[LCD_UI_Y_WIDTH:0] fill_rect_y_end_cal;
    logic[LCD_UI_Y_WIDTH:0] fill_rect_y_end_clipped_cal;
    logic[LCD_UI_Y_WIDTH:0] fill_rect_y_last_cal;
    
    logic[VRAM_BYTE_COL_WIDTH - 1:0] fill_rect_first_byte_cal;
    logic[VRAM_BYTE_COL_WIDTH - 1:0] fill_rect_last_byte_cal;
    logic[VRAM_DATA_OFFSET_WIDTH - 1:0] fill_rect_start_offset_cal;
    logic[VRAM_DATA_OFFSET_WIDTH - 1:0] fill_rect_end_offset_cal;
    
    logic[VRAM_BYTE_COL_WIDTH - 1:0] fill_rect_first_byte;
    logic[VRAM_BYTE_COL_WIDTH - 1:0] fill_rect_last_byte;
    logic[VRAM_DATA_OFFSET_WIDTH - 1:0] fill_rect_start_offset;
    logic[VRAM_DATA_OFFSET_WIDTH - 1:0] fill_rect_end_offset;
    lcd_ui_y_t fill_rect_first_y;
    lcd_ui_y_t fill_rect_last_y;
    
    logic[VRAM_BYTE_COL_WIDTH - 1:0] fill_rect_byte;
    lcd_ui_y_t fill_rect_y;
    
    logic[VRAM_ADDR_WIDTH - 1:0] fill_rect_addr;
    logic[VRAM_DATA_WIDTH - 1:0] fill_rect_left_mask;
    logic[VRAM_DATA_WIDTH - 1:0] fill_rect_right_mask;
    logic[VRAM_DATA_WIDTH - 1:0] fill_rect_mask;
    logic fill_rect_mask_full;
    logic[VRAM_DATA_WIDTH - 1:0] fill_rect_color_data;
    logic[VRAM_DATA_WIDTH - 1:0] fill_rect_wdata_loaded;
    logic[VRAM_DATA_WIDTH - 1:0] fill_rect_wdata;
    logic fill_rect_last_write;
    
    lcd_ui_draw_line_config_t draw_line_config_loaded;

    logic[LCD_UI_X_WIDTH - 1:0] draw_line_dx_abs_cal;
    logic[LCD_UI_Y_WIDTH - 1:0] draw_line_dy_abs_cal;

    logic signed[DRAW_LINE_CALC_WIDTH - 1:0] draw_line_dx_cal;
    logic signed[DRAW_LINE_CALC_WIDTH - 1:0] draw_line_dy_cal;
    logic signed[DRAW_LINE_CALC_WIDTH - 1:0] draw_line_err_init_cal;

    lcd_ui_x_t draw_line_x;
    lcd_ui_y_t draw_line_y;
    logic draw_line_x_increase;
    logic draw_line_y_increase;

    logic signed[DRAW_LINE_CALC_WIDTH - 1:0] draw_line_dx;
    logic signed[DRAW_LINE_CALC_WIDTH - 1:0] draw_line_dy;
    logic signed[DRAW_LINE_CALC_WIDTH - 1:0] draw_line_err;
    logic signed[DRAW_LINE_CALC_WIDTH - 1:0] draw_line_e2;

    lcd_ui_x_t draw_line_x_next;
    lcd_ui_y_t draw_line_y_next;
    logic signed[DRAW_LINE_CALC_WIDTH - 1:0] draw_line_err_next;

    logic draw_line_step_x;
    logic draw_line_step_y;
    logic draw_line_last_pixel;
    logic draw_line_pixel_visible;

    logic[VRAM_ADDR_WIDTH - 1:0] draw_line_addr;
    logic[VRAM_DATA_WIDTH - 1:0] draw_line_mask;
    logic[VRAM_DATA_WIDTH - 1:0] draw_line_wdata_cal;
    logic[VRAM_DATA_WIDTH - 1:0] draw_line_wdata_loaded;
    
    logic[VRAM_ADDR_WIDTH - 1:0] clear_addr;
    logic[VRAM_DATA_WIDTH - 1:0] clear_wdata;
    
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
                if(start) begin
                    next_state = STATE_WAIT_VWC_IDLE;
                end
            end
            
            STATE_WAIT_VWC_IDLE: begin
                if(!vwc_busy) begin
                    if(config_type_loaded == LCD_UI_CONFIG_TYPE_FILL_RECT) begin
                        next_state = STATE_FILL_RECT_INIT;
                    end
                    else if(config_type_loaded == LCD_UI_CONFIG_TYPE_DRAW_LINE) begin
                        next_state = STATE_DRAW_LINE_INIT;
                    end
                    else if(config_type_loaded == LCD_UI_CONFIG_TYPE_CLEAR) begin
                        next_state = STATE_CLEAR_INIT;
                    end
                    else begin
                        next_state = STATE_IDLE;
                    end
                end
            end
            
            STATE_FILL_RECT_INIT: begin
                next_state = STATE_FILL_RECT_CHECK;
            end
            
            STATE_FILL_RECT_CHECK: begin
                if(!fill_rect_config_valid_loaded) begin
                    next_state = STATE_IDLE;
                end
                else if(fill_rect_mask_full) begin
                    next_state = STATE_FILL_RECT_WRITE;
                end
                else begin
                    next_state = STATE_FILL_RECT_READ;
                end
            end
            
            STATE_FILL_RECT_READ: begin
                next_state = STATE_FILL_RECT_WAIT;
            end
            
            STATE_FILL_RECT_WAIT: begin
                next_state = STATE_FILL_RECT_WRITE;
            end
            
            STATE_FILL_RECT_WRITE: begin
                if(fill_rect_last_write) begin
                    next_state = STATE_IDLE;
                end
                else begin
                    next_state = STATE_FILL_RECT_CHECK;
                end
            end
            
            STATE_DRAW_LINE_INIT: begin
                next_state = STATE_DRAW_LINE_CHECK;
            end
            
            STATE_DRAW_LINE_CHECK: begin
                if(draw_line_pixel_visible) begin
                    next_state = STATE_DRAW_LINE_READ;
                end
                else if(draw_line_last_pixel) begin
                    next_state = STATE_IDLE;
                end
                else begin
                    next_state = STATE_DRAW_LINE_NEXT;
                end
            end
            
            STATE_DRAW_LINE_READ: begin
                next_state = STATE_DRAW_LINE_WAIT;
            end
            
            STATE_DRAW_LINE_WAIT: begin
                next_state = STATE_DRAW_LINE_WRITE;
            end
            
            STATE_DRAW_LINE_WRITE: begin
                if(draw_line_last_pixel) begin
                    next_state = STATE_IDLE;
                end
                else begin
                    next_state = STATE_DRAW_LINE_NEXT;
                end
            end
            
            STATE_DRAW_LINE_NEXT: begin
                next_state = STATE_DRAW_LINE_CHECK;
            end
            
            STATE_CLEAR_INIT: begin
                next_state = STATE_CLEAR_WRITE;
            end
            
            STATE_CLEAR_WRITE: begin
                if(clear_addr == VRAM_LAST_ADDR) begin
                    next_state = STATE_IDLE;
                end
            end
        endcase
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            busy <= 1'b0;
        end
        else if((cur_state == STATE_IDLE) && (next_state != STATE_IDLE)) begin
            busy <= 1'b1;
        end
        else if((cur_state == STATE_IDLE) && (next_state == STATE_IDLE)) begin
            busy <= 1'b0;
        end
    end
    
    assign vwc_raddr = (config_type_loaded == LCD_UI_CONFIG_TYPE_DRAW_LINE) ? draw_line_addr : fill_rect_addr;
    assign vwc_waddr = (config_type_loaded == LCD_UI_CONFIG_TYPE_CLEAR) ? clear_addr : ((config_type_loaded == LCD_UI_CONFIG_TYPE_DRAW_LINE) ? draw_line_addr : fill_rect_addr);
    assign vwc_wdata = (config_type_loaded == LCD_UI_CONFIG_TYPE_CLEAR) ? clear_wdata : ((config_type_loaded == LCD_UI_CONFIG_TYPE_DRAW_LINE) ? draw_line_wdata_loaded : fill_rect_wdata);
    assign vwc_we = ((cur_state == STATE_FILL_RECT_WRITE) || (cur_state == STATE_DRAW_LINE_WRITE) || (cur_state == STATE_CLEAR_WRITE)) ? 1'b1 : 1'b0;
    
    always_ff @(posedge clk) begin
        if(rst) begin
            config_data_loaded <= '0;
        end
        else if((cur_state == STATE_IDLE) && (next_state == STATE_WAIT_VWC_IDLE)) begin
            config_data_loaded <= config_data;
        end
    end
    
    assign config_type_loaded = get_config_type(config_data_loaded);
    assign fill_rect_config_loaded = config_data_loaded[LCD_UI_CONFIG_PAYLOAD_LSB +: LCD_UI_FILL_RECT_CONFIG_WIDTH];
    assign draw_line_config_loaded = config_data_loaded[LCD_UI_CONFIG_PAYLOAD_LSB +: LCD_UI_DRAW_LINE_CONFIG_WIDTH];
    assign clear_config_loaded = config_data_loaded[LCD_UI_CONFIG_PAYLOAD_LSB +: LCD_UI_CLEAR_CONFIG_WIDTH];
    
    assign fill_rect_x_end_cal = {1'b0, fill_rect_config_loaded.x} + {1'b0, fill_rect_config_loaded.width};
    assign fill_rect_x_end_clipped_cal = (fill_rect_x_end_cal > LCD_PIXEL_COL_NUM_VALUE) ? LCD_PIXEL_COL_NUM_VALUE : fill_rect_x_end_cal;
    assign fill_rect_x_last_cal = fill_rect_x_end_clipped_cal - 'b1;
    
    assign fill_rect_y_end_cal = {1'b0, fill_rect_config_loaded.y} + {1'b0, fill_rect_config_loaded.height};
    assign fill_rect_y_end_clipped_cal = (fill_rect_y_end_cal > LCD_PIXEL_LINE_NUM_VALUE) ? LCD_PIXEL_LINE_NUM_VALUE : fill_rect_y_end_cal;
    assign fill_rect_y_last_cal = fill_rect_y_end_clipped_cal - 'b1;
    
    assign fill_rect_config_valid_cal = ((fill_rect_config_loaded.width != '0) && (fill_rect_config_loaded.height != '0) && ({1'b0, fill_rect_config_loaded.x} < LCD_PIXEL_COL_NUM_VALUE) && ({1'b0, fill_rect_config_loaded.y} < LCD_PIXEL_LINE_NUM_VALUE)) ? 1'b1 : 1'b0;
    
    assign fill_rect_first_byte_cal = fill_rect_config_loaded.x >> VRAM_DATA_OFFSET_WIDTH;
    assign fill_rect_last_byte_cal = fill_rect_x_last_cal >> VRAM_DATA_OFFSET_WIDTH;
    assign fill_rect_start_offset_cal = fill_rect_config_loaded.x[VRAM_DATA_OFFSET_WIDTH - 1:0];
    assign fill_rect_end_offset_cal = fill_rect_x_last_cal[VRAM_DATA_OFFSET_WIDTH - 1:0];
    
    always_ff @(posedge clk) begin
        if(rst) begin
            fill_rect_config_valid_loaded <= 1'b0;
            fill_rect_first_byte <= '0;
            fill_rect_last_byte <= '0;
            fill_rect_start_offset <= '0;
            fill_rect_end_offset <= '0;
            fill_rect_first_y <= '0;
            fill_rect_last_y <= '0;
        end
        else if(cur_state == STATE_FILL_RECT_INIT) begin
            fill_rect_config_valid_loaded <= fill_rect_config_valid_cal;
            fill_rect_first_byte <= fill_rect_first_byte_cal;
            fill_rect_last_byte <= fill_rect_last_byte_cal;
            fill_rect_start_offset <= fill_rect_start_offset_cal;
            fill_rect_end_offset <= fill_rect_end_offset_cal;
            fill_rect_first_y <= fill_rect_config_loaded.y;
            fill_rect_last_y <= fill_rect_y_last_cal[LCD_UI_Y_WIDTH - 1:0];
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            fill_rect_byte <= '0;
            fill_rect_y <= '0;
        end
        else if(cur_state == STATE_FILL_RECT_INIT) begin
            fill_rect_byte <= fill_rect_first_byte_cal;
            fill_rect_y <= fill_rect_config_loaded.y;
        end
        else if((cur_state == STATE_FILL_RECT_WRITE) && !fill_rect_last_write) begin
            if(fill_rect_byte == fill_rect_last_byte) begin
                fill_rect_byte <= fill_rect_first_byte;
                fill_rect_y <= fill_rect_y + 'b1;
            end
            else begin
                fill_rect_byte <= fill_rect_byte + 'b1;
            end
        end
    end
    
    assign fill_rect_addr = fill_rect_y * VRAM_BYTE_COL_NUM + fill_rect_byte;
    
    assign fill_rect_left_mask = {VRAM_DATA_WIDTH{1'b1}} << fill_rect_start_offset;
    assign fill_rect_right_mask = {VRAM_DATA_WIDTH{1'b1}} >> (VRAM_DATA_OFFSET_MAX - fill_rect_end_offset);
    assign fill_rect_mask = ((fill_rect_byte == fill_rect_first_byte) ? fill_rect_left_mask : {VRAM_DATA_WIDTH{1'b1}}) & ((fill_rect_byte == fill_rect_last_byte) ? fill_rect_right_mask : {VRAM_DATA_WIDTH{1'b1}});
    assign fill_rect_mask_full = (fill_rect_mask == {VRAM_DATA_WIDTH{1'b1}}) ? 1'b1 : 1'b0;
    
    assign fill_rect_color_data = {VRAM_DATA_WIDTH{fill_rect_config_loaded.color}};
    
    always_ff @(posedge clk) begin
        if(rst) begin
            fill_rect_wdata_loaded <= '0;
        end
        else if((cur_state == STATE_FILL_RECT_WAIT) && (next_state == STATE_FILL_RECT_WRITE)) begin
            fill_rect_wdata_loaded <= (vwc_rdata & ~fill_rect_mask) | (fill_rect_color_data & fill_rect_mask);
        end
    end
    
    assign fill_rect_wdata = fill_rect_mask_full ? fill_rect_color_data : fill_rect_wdata_loaded;
    assign fill_rect_last_write = ((fill_rect_byte == fill_rect_last_byte) && (fill_rect_y == fill_rect_last_y)) ? 1'b1 : 1'b0;
    
    assign draw_line_dx_abs_cal = (draw_line_config_loaded.x1 >= draw_line_config_loaded.x0) ? (draw_line_config_loaded.x1 - draw_line_config_loaded.x0) : (draw_line_config_loaded.x0 - draw_line_config_loaded.x1);
    assign draw_line_dy_abs_cal = (draw_line_config_loaded.y1 >= draw_line_config_loaded.y0) ? (draw_line_config_loaded.y1 - draw_line_config_loaded.y0) : (draw_line_config_loaded.y0 - draw_line_config_loaded.y1);
    assign draw_line_dx_cal = $signed({{(DRAW_LINE_CALC_WIDTH - LCD_UI_X_WIDTH){1'b0}}, draw_line_dx_abs_cal});
    assign draw_line_dy_cal = -$signed({{(DRAW_LINE_CALC_WIDTH - LCD_UI_Y_WIDTH){1'b0}}, draw_line_dy_abs_cal});
    assign draw_line_err_init_cal = draw_line_dx_cal + draw_line_dy_cal;
    
    always_ff @(posedge clk) begin
        if(rst) begin
            draw_line_x <= '0;
            draw_line_y <= '0;
            draw_line_x_increase <= 1'b0;
            draw_line_y_increase <= 1'b0;
            draw_line_dx <= '0;
            draw_line_dy <= '0;
            draw_line_err <= '0;
        end
        else if(cur_state == STATE_DRAW_LINE_INIT) begin
            draw_line_x <= draw_line_config_loaded.x0;
            draw_line_y <= draw_line_config_loaded.y0;
            draw_line_x_increase <= (draw_line_config_loaded.x0 < draw_line_config_loaded.x1) ? 1'b1 : 1'b0;
            draw_line_y_increase <= (draw_line_config_loaded.y0 < draw_line_config_loaded.y1) ? 1'b1 : 1'b0;
            draw_line_dx <= draw_line_dx_cal;
            draw_line_dy <= draw_line_dy_cal;
            draw_line_err <= draw_line_err_init_cal;
        end
        else if(cur_state == STATE_DRAW_LINE_NEXT) begin
            draw_line_x <= draw_line_x_next;
            draw_line_y <= draw_line_y_next;
            draw_line_err <= draw_line_err_next;
        end
    end
    
    assign draw_line_e2 = draw_line_err <<< 'b1;
    assign draw_line_step_x = (draw_line_e2 >= draw_line_dy) ? 1'b1 : 1'b0;
    assign draw_line_step_y = (draw_line_e2 <= draw_line_dx) ? 1'b1 : 1'b0;
    
    always_comb begin
        draw_line_x_next = draw_line_x;
        draw_line_y_next = draw_line_y;
        draw_line_err_next = draw_line_err;
        
        if(draw_line_step_x) begin
            draw_line_err_next = draw_line_err_next + draw_line_dy;
            
            if(draw_line_x_increase) begin
                draw_line_x_next = draw_line_x + 'b1;
            end
            else begin
                draw_line_x_next = draw_line_x - 'b1;
            end
        end
        
        if(draw_line_step_y) begin
            draw_line_err_next = draw_line_err_next + draw_line_dx;
            
            if(draw_line_y_increase) begin
                draw_line_y_next = draw_line_y + 'b1;
            end
            else begin
                draw_line_y_next = draw_line_y - 'b1;
            end
        end
    end
    
    assign draw_line_last_pixel = ((draw_line_x == draw_line_config_loaded.x1) && (draw_line_y == draw_line_config_loaded.y1)) ? 1'b1 : 1'b0;
    assign draw_line_pixel_visible = (({1'b0, draw_line_x} < LCD_PIXEL_COL_NUM_VALUE) && ({1'b0, draw_line_y} < LCD_PIXEL_LINE_NUM_VALUE)) ? 1'b1 : 1'b0;
    assign draw_line_addr = draw_line_y * VRAM_BYTE_COL_NUM + (draw_line_x >> VRAM_DATA_OFFSET_WIDTH);
    assign draw_line_mask = {{(VRAM_DATA_WIDTH - 1){1'b0}}, 1'b1} << draw_line_x[VRAM_DATA_OFFSET_WIDTH - 1:0];
    assign draw_line_wdata_cal = draw_line_config_loaded.color ? (vwc_rdata | draw_line_mask) : (vwc_rdata & ~draw_line_mask);
    
    always_ff @(posedge clk) begin
        if(rst) begin
            draw_line_wdata_loaded <= '0;
        end
        else if((cur_state == STATE_DRAW_LINE_WAIT) && (next_state == STATE_DRAW_LINE_WRITE)) begin
            draw_line_wdata_loaded <= draw_line_wdata_cal;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            clear_addr <= '0;
        end
        else if(cur_state == STATE_CLEAR_INIT) begin
            clear_addr <= '0;
        end
        else if((cur_state == STATE_CLEAR_WRITE) && (next_state == STATE_CLEAR_WRITE)) begin
            clear_addr <= clear_addr + 'b1;
        end
    end
endmodule