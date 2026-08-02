`default_nettype none

module lcd_command_generator #(
        parameter CLK_FREQ = 50000000,
        parameter LCD_PIXEL_LINE_NUM = 64,
        parameter LCD_PIXEL_COL_NUM = 128,
        parameter DATA_WIDTH = 8
    )(
        input logic clk,
        input logic rst,

        input logic[DATA_WIDTH - 1:0] vram_data,
        input logic vram_data_valid,
        output logic vram_data_pop,
        
        output logic phy_rs,
        output logic[DATA_WIDTH - 1:0] phy_db,
        output logic phy_start,
        input logic phy_busy
    );

    localparam STATE_WIDTH = 5;
    localparam STATE_RESET_WAIT_PHY_READY = STATE_WIDTH'('d0);
    localparam STATE_RESET_GEN_COMMAND = STATE_WIDTH'('d1);
    localparam STATE_RESET_SEND_COMMAND = STATE_WIDTH'('d2);
    localparam STATE_RESET_WAIT_COMMAND_OK = STATE_WIDTH'('d3);
    localparam STATE_RESET_WAIT_DELAY = STATE_WIDTH'('d4);
    localparam STATE_GEN_SET_PAGE_COMMAND = STATE_WIDTH'('d5);
    localparam STATE_SEND_SET_PAGE_COMMAND = STATE_WIDTH'('d6);
    localparam STATE_WAIT_SET_PAGE_COMMAND_OK = STATE_WIDTH'('d7);
    localparam STATE_GEN_SET_COLUMN_COMMAND_HIGH = STATE_WIDTH'('d8);
    localparam STATE_SEND_SET_COLUMN_COMMAND_HIGH = STATE_WIDTH'('d9);
    localparam STATE_WAIT_SET_COLUMN_COMMAND_HIGH_OK = STATE_WIDTH'('d10);
    localparam STATE_GEN_SET_COLUMN_COMMAND_LOW = STATE_WIDTH'('d11);
    localparam STATE_SEND_SET_COLUMN_COMMAND_LOW = STATE_WIDTH'('d12);
    localparam STATE_WAIT_SET_COLUMN_COMMAND_LOW_OK = STATE_WIDTH'('d13);
    localparam STATE_GEN_DATA = STATE_WIDTH'('d14);
    localparam STATE_SEND_DATA = STATE_WIDTH'('d15);
    localparam STATE_WAIT_SEND_DATA_OK = STATE_WIDTH'('d16);

    localparam LCD_RESET_COMMAND_ADDR_WIDTH = 4;
    localparam LCD_RESET_COMMAND_DELAY_MS_WIDTH = 4;
    localparam VRAM_ADDR_WIDTH = (LCD_PIXEL_LINE_NUM * LCD_PIXEL_COL_NUM / DATA_WIDTH <= 1) ? 1 : $clog2(LCD_PIXEL_LINE_NUM * LCD_PIXEL_COL_NUM / DATA_WIDTH);
    localparam PAGE_NUM = LCD_PIXEL_LINE_NUM / DATA_WIDTH;
    localparam PAGE_ID_WIDTH = (PAGE_NUM <= 1) ? 1 : $clog2(PAGE_NUM);
    localparam COLUMN_ID_WIDTH = VRAM_ADDR_WIDTH - PAGE_ID_WIDTH;

    logic tick_1ms;
    logic[LCD_RESET_COMMAND_ADDR_WIDTH - 1:0] rom_addr;
    logic rom_phy_rs;
    logic[DATA_WIDTH - 1:0] rom_phy_db;
    logic rom_need_delay;
    logic[LCD_RESET_COMMAND_DELAY_MS_WIDTH - 1:0] rom_delay_ms;
    logic rom_last_command;

    logic[STATE_WIDTH - 1:0] cur_state;
    logic[STATE_WIDTH - 1:0] next_state;

    logic[LCD_RESET_COMMAND_DELAY_MS_WIDTH - 1:0] delay_countdown;
    logic[VRAM_ADDR_WIDTH - 1:0] vram_addr;

    clock_enable_generator #(
        .CLOCK_FREQUENCY(CLK_FREQ),
        .ENABLE_FREQUENCY(1000)
    )clock_enable_generator_inst(
        .clk(clk),
        .rst((cur_state != STATE_RESET_WAIT_DELAY)),
        .enable(tick_1ms)
    );

    lcd_reset_command_rom #(
        .ADDR_WIDTH(LCD_RESET_COMMAND_ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .DELAY_MS_WIDTH(LCD_RESET_COMMAND_DELAY_MS_WIDTH)
    )lcd_reset_command_rom_inst(
        .addr(rom_addr),
        .phy_rs(rom_phy_rs),
        .phy_db(rom_phy_db),
        .need_delay(rom_need_delay),
        .delay_ms(rom_delay_ms),
        .last_command(rom_last_command)
    );

    always_ff @(posedge clk) begin
        if(rst) begin
            cur_state <= STATE_RESET_WAIT_PHY_READY;
        end
        else begin
            cur_state <= next_state;
        end
    end
    
    always_comb begin
        next_state = cur_state;

        case(cur_state)
            STATE_RESET_WAIT_PHY_READY: begin
                if(!phy_busy) begin
                    next_state = STATE_RESET_GEN_COMMAND;
                end
            end

            STATE_RESET_GEN_COMMAND: begin
                next_state = STATE_RESET_SEND_COMMAND;
            end

            STATE_RESET_SEND_COMMAND: begin
                next_state = STATE_RESET_WAIT_COMMAND_OK;
            end

            STATE_RESET_WAIT_COMMAND_OK: begin
                if(!phy_busy) begin
                    if(rom_need_delay) begin
                        next_state = STATE_RESET_WAIT_DELAY;
                    end
                    else if(rom_last_command) begin
                        next_state = STATE_GEN_SET_PAGE_COMMAND;
                    end
                    else begin
                        next_state = STATE_RESET_GEN_COMMAND;
                    end
                end
            end

            STATE_RESET_WAIT_DELAY: begin
                if(delay_countdown == '0) begin
                    if(rom_last_command) begin
                        next_state = STATE_GEN_SET_PAGE_COMMAND;
                    end
                    else begin
                        next_state = STATE_RESET_GEN_COMMAND;
                    end
                end
            end

            STATE_GEN_SET_PAGE_COMMAND: begin
                next_state = STATE_SEND_SET_PAGE_COMMAND;
            end

            STATE_SEND_SET_PAGE_COMMAND: begin
                next_state = STATE_WAIT_SET_PAGE_COMMAND_OK;
            end

            STATE_WAIT_SET_PAGE_COMMAND_OK: begin
                if(!phy_busy) begin
                    next_state = STATE_GEN_SET_COLUMN_COMMAND_HIGH;
                end
            end

            STATE_GEN_SET_COLUMN_COMMAND_HIGH: begin
                next_state = STATE_SEND_SET_COLUMN_COMMAND_HIGH;
            end

            STATE_SEND_SET_COLUMN_COMMAND_HIGH: begin
                next_state = STATE_WAIT_SET_COLUMN_COMMAND_HIGH_OK;
            end

            STATE_WAIT_SET_COLUMN_COMMAND_HIGH_OK: begin
                if(!phy_busy) begin
                    next_state = STATE_GEN_SET_COLUMN_COMMAND_LOW;
                end
            end

            STATE_GEN_SET_COLUMN_COMMAND_LOW: begin
                next_state = STATE_SEND_SET_COLUMN_COMMAND_LOW;
            end

            STATE_SEND_SET_COLUMN_COMMAND_LOW: begin
                next_state = STATE_WAIT_SET_COLUMN_COMMAND_LOW_OK;
            end

            STATE_WAIT_SET_COLUMN_COMMAND_LOW_OK: begin
                if(!phy_busy) begin
                    next_state = STATE_GEN_DATA;
                end
            end

            STATE_GEN_DATA: begin
                if(vram_data_valid) begin
                    next_state = STATE_SEND_DATA;
                end
            end

            STATE_SEND_DATA: begin
                next_state = STATE_WAIT_SEND_DATA_OK;
            end

            STATE_WAIT_SEND_DATA_OK: begin
                if(!phy_busy) begin
                    if(vram_addr[COLUMN_ID_WIDTH - 1:0] == '0) begin
                        next_state = STATE_GEN_SET_PAGE_COMMAND;
                    end
                    else begin
                        next_state = STATE_GEN_DATA;
                    end
                end
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            phy_rs <= 1'b0;
            phy_db <= '0;
            phy_start <= 1'b0;
        end
        else if(cur_state == STATE_RESET_GEN_COMMAND) begin
            phy_rs <= rom_phy_rs;
            phy_db <= rom_phy_db;
            phy_start <= 1'b1;
        end
        else if(cur_state == STATE_RESET_SEND_COMMAND) begin
            phy_start <= 1'b0;
        end
        else if(cur_state == STATE_GEN_SET_PAGE_COMMAND) begin
            phy_rs <= 1'b0;
            phy_db <= {4'b1011, 4'(vram_addr[COLUMN_ID_WIDTH +: PAGE_ID_WIDTH])};
            phy_start <= 1'b1;
        end
        else if(cur_state == STATE_SEND_SET_PAGE_COMMAND) begin
            phy_start <= 1'b0;
        end
        else if(cur_state == STATE_GEN_SET_COLUMN_COMMAND_HIGH) begin
            phy_rs <= 1'b0;

            if(COLUMN_ID_WIDTH >= 4) begin
                phy_db <= {4'b0001, 4'(vram_addr[COLUMN_ID_WIDTH - 1:4])};
            end
            else begin
                phy_db <= 8'b0001_0000;
            end
            
            phy_start <= 1'b1;
        end
        else if(cur_state == STATE_SEND_SET_COLUMN_COMMAND_HIGH) begin
            phy_start <= 1'b0;
        end
        else if(cur_state == STATE_GEN_SET_COLUMN_COMMAND_LOW) begin
            phy_rs <= 1'b0;
            phy_db <= {4'b0000, 4'(vram_addr[3:0] & (2 ** COLUMN_ID_WIDTH - 'b1))};
            phy_start <= 1'b1;
        end
        else if(cur_state == STATE_SEND_SET_COLUMN_COMMAND_LOW) begin
            phy_start <= 1'b0;
        end
        else if(cur_state == STATE_GEN_DATA) begin
            phy_rs <= 1'b1;
            phy_db <= vram_data;
            phy_start <= vram_data_valid;
        end
        else if(cur_state == STATE_SEND_DATA) begin
            phy_start <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            vram_data_pop <= 1'b0;
        end
        else if((cur_state == STATE_GEN_DATA) && (next_state != STATE_GEN_DATA)) begin
            vram_data_pop <= 1'b1;
        end
        else begin
            vram_data_pop <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            rom_addr <= '0;
        end
        else if(((cur_state == STATE_RESET_WAIT_COMMAND_OK) || (cur_state == STATE_RESET_WAIT_DELAY)) && (next_state == STATE_RESET_GEN_COMMAND)) begin
            rom_addr <= rom_addr + 'b1;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            delay_countdown <= '0;
        end
        else if((cur_state == STATE_RESET_WAIT_COMMAND_OK) && (next_state != STATE_RESET_WAIT_COMMAND_OK)) begin
            delay_countdown <= rom_delay_ms;
        end
        else if(tick_1ms && (delay_countdown != '0)) begin
            delay_countdown <= delay_countdown - 'b1;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            vram_addr <= '0;
        end
        else if((cur_state == STATE_GEN_DATA) && (next_state != STATE_GEN_DATA)) begin
            vram_addr <= vram_addr + 'b1;
        end
    end
endmodule