`default_nettype none

module lcd_phy #(
        parameter CLK_FREQ = 50000000,
        parameter FREQ_DIVIDE = 2,
        parameter DATA_WIDTH = 8
    )(
        input logic clk,
        input logic rst,

        output logic lcd_rst,
        output logic lcd_cs,
        output logic lcd_rs,
        output logic lcd_sclk,
        output logic lcd_sda,

        input logic rs_in,
        input logic[DATA_WIDTH - 1:0] db_in,
        input logic start,
        output logic busy
    );

    localparam BIT_CNT_WIDTH = (DATA_WIDTH <= 1) ? 1 : $clog2(DATA_WIDTH);
    localparam RESET_ASSERT_CYCLE = unsigned'((3 * CLK_FREQ + 1000000 - 1) / 1000000);//3us
    localparam RESET_ASSERT_CYCLE_WIDTH = (RESET_ASSERT_CYCLE <= 1) ? 1 : $clog2(RESET_ASSERT_CYCLE);
    localparam RESET_DEASSERT_CYCLE = unsigned'((6 * CLK_FREQ + 1000 - 1) / 1000);//6ms
    localparam RESET_DEASSERT_CYCLE_WIDTH = (RESET_DEASSERT_CYCLE <= 1) ? 1 : $clog2(RESET_DEASSERT_CYCLE);

    localparam STATE_WIDTH = 3;
    localparam STATE_ASSERT_RESET = STATE_WIDTH'('d0);
    localparam STATE_WAIT_RESET_DEASSERT = STATE_WIDTH'('d1);
    localparam STATE_WAIT_RESET_FINISH = STATE_WIDTH'('d2);
    localparam STATE_IDLE = STATE_WIDTH'('d3);
    localparam STATE_ASSERT_CS = STATE_WIDTH'('d4);
    localparam STATE_LOAD_DATA = STATE_WIDTH'('d5);
    localparam STATE_CAPTURE_DATA = STATE_WIDTH'('d6);
    localparam STATE_DEASSERT_CS = STATE_WIDTH'('d7);

    logic clken;
    logic[STATE_WIDTH - 1:0] cur_state;
    logic[STATE_WIDTH - 1:0] next_state;
    logic[RESET_ASSERT_CYCLE_WIDTH - 1:0] reset_assert_cnt;
    logic[RESET_DEASSERT_CYCLE_WIDTH - 1:0] reset_deassert_cnt;
    logic[BIT_CNT_WIDTH - 1:0] bit_cnt;
    logic[DATA_WIDTH - 1:0] db_loaded;

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
            cur_state <= STATE_ASSERT_RESET;
        end
        else if((cur_state == STATE_ASSERT_RESET) || (cur_state == STATE_WAIT_RESET_DEASSERT) || (cur_state == STATE_WAIT_RESET_FINISH) || (cur_state == STATE_IDLE)) begin
            cur_state <= next_state;
        end
        else if(clken) begin
            cur_state <= next_state;
        end
    end

    always_comb begin
        next_state = cur_state;

        case(cur_state)
            STATE_ASSERT_RESET: begin
                next_state = STATE_WAIT_RESET_DEASSERT;
            end
            
            STATE_WAIT_RESET_DEASSERT: begin
                if(reset_assert_cnt >= (RESET_ASSERT_CYCLE - 'b1)) begin
                    next_state = STATE_WAIT_RESET_FINISH;
                end
            end

            STATE_WAIT_RESET_FINISH: begin
                if(reset_deassert_cnt >= (RESET_DEASSERT_CYCLE - 'b1)) begin
                    next_state = STATE_IDLE;
                end
            end

            STATE_IDLE: begin
                if(start) begin
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
                if(bit_cnt == 'b0) begin
                    next_state = STATE_DEASSERT_CS;
                end
                else begin
                    next_state = STATE_LOAD_DATA;
                end
            end
            
            STATE_DEASSERT_CS: begin
                next_state = STATE_IDLE;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            reset_assert_cnt <= '0;
        end
        else if(cur_state == STATE_WAIT_RESET_DEASSERT) begin
            reset_assert_cnt <= reset_assert_cnt + 'b1;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            reset_deassert_cnt <= '0;
        end
        else if(cur_state == STATE_WAIT_RESET_FINISH) begin
            reset_deassert_cnt <= reset_deassert_cnt + 'b1;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            bit_cnt <= '0;
        end
        else if((cur_state == STATE_ASSERT_CS) && clken) begin
            bit_cnt <= DATA_WIDTH - 'b1;
        end
        else if((cur_state == STATE_CAPTURE_DATA) && clken) begin
            bit_cnt <= bit_cnt - 'b1;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            db_loaded <= '0;
        end
        else if((cur_state == STATE_IDLE) && (next_state == STATE_ASSERT_CS)) begin
            db_loaded <= db_in;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            lcd_rst <= 1'b0;
        end
        else if(cur_state == STATE_ASSERT_RESET) begin
            lcd_rst <= 1'b0;
        end
        else if((cur_state == STATE_WAIT_RESET_DEASSERT) && (next_state == STATE_WAIT_RESET_FINISH)) begin
            lcd_rst <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            lcd_cs <= 1'b1;
        end
        else if((cur_state == STATE_ASSERT_CS) && clken) begin
            lcd_cs <= 1'b0;
        end
        else if((cur_state == STATE_DEASSERT_CS) && clken) begin
            lcd_cs <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            lcd_rs <= 1'b0;
        end
        else if((cur_state == STATE_IDLE) && (next_state == STATE_ASSERT_CS)) begin
            lcd_rs <= rs_in;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            lcd_sclk <= 1'b1;
        end
        else if((cur_state == STATE_LOAD_DATA) && clken) begin
            lcd_sclk <= 1'b0;
        end
        else if((cur_state == STATE_CAPTURE_DATA) && clken) begin
            lcd_sclk <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            lcd_sda <= 1'b0;
        end
        else if((cur_state == STATE_LOAD_DATA) && clken) begin
            lcd_sda <= db_loaded[bit_cnt];
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            busy <= 1'b1;
        end
        else if((cur_state == STATE_WAIT_RESET_FINISH) && (next_state == STATE_IDLE)) begin
            busy <= 1'b0;
        end
        else if((cur_state == STATE_IDLE) && (next_state == STATE_ASSERT_CS)) begin
            busy <= 1'b1;
        end
        else if((cur_state == STATE_DEASSERT_CS) && clken) begin
            busy <= 1'b0;
        end
    end
endmodule