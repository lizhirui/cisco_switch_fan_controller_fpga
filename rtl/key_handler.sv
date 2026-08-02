`default_nettype none

module key_handler #(
        parameter ASSERT_LEVEL = 1'b0,
        parameter DEBOUNCE_TIME_MS = 20,
        parameter REPEAT_START_TIME_MS = 500,
        parameter REPEAT_INTERVAL_MS = 100
    )(
        input logic clk,
        input logic rst,

        input logic tick_1ms,
        input logic key_in,
        
        output logic pressed,
        output logic press_pulse,
        output logic release_pulse,
        output logic repeat_pulse
    );

    localparam DEBOUNCE_COUNTER_WIDTH = (DEBOUNCE_TIME_MS <= 1) ? 1 : $clog2(DEBOUNCE_TIME_MS);
    localparam REPEAT_START_COUNTER_WIDTH = (REPEAT_START_TIME_MS <= 1) ? 1 : $clog2(REPEAT_START_TIME_MS);
    localparam REPEAT_COUNTER_WIDTH = (REPEAT_INTERVAL_MS <= 1) ? 1 : $clog2(REPEAT_INTERVAL_MS);
    
    logic key_in_sync;
    logic[DEBOUNCE_COUNTER_WIDTH - 1:0] debounce_counter;
    logic debounce_counter_timeout;
    logic[REPEAT_START_COUNTER_WIDTH - 1:0] repeat_start_counter;
    logic[REPEAT_COUNTER_WIDTH - 1:0] repeat_counter;
    logic key_active;
    logic debounce_accept;
    logic press_accept;
    logic release_accept;

    assign key_active = key_in_sync == ASSERT_LEVEL;
    assign debounce_counter_timeout = ((DEBOUNCE_TIME_MS <= 1) || (debounce_counter >= (DEBOUNCE_TIME_MS - 1'b1)));
    assign debounce_accept = tick_1ms && (key_active != pressed) && debounce_counter_timeout;
    assign press_accept = debounce_accept && key_active;
    assign release_accept = debounce_accept && !key_active;

    signal_syncer #(
        .WIDTH(1),
        .RESET_VALUE(~ASSERT_LEVEL)
    )signal_syncer_key(
        .clk(clk),
        .rst(rst),
        .din(key_in),
        .dout(key_in_sync)
    );

    always_ff @(posedge clk) begin
        if(rst) begin
            pressed <= 1'b0;
            debounce_counter <= 'b0;
            press_pulse <= 1'b0;
            release_pulse <= 1'b0;
        end
        else begin
            press_pulse <= 1'b0;
            release_pulse <= 1'b0;

            if(tick_1ms) begin
                if(key_active == pressed) begin
                    debounce_counter <= '0;
                end
                else if(debounce_counter_timeout) begin
                    debounce_counter <= '0;
                    pressed <= key_active;

                    if(key_active) begin
                        press_pulse <= 1'b1;
                    end
                    else begin
                        release_pulse <= 1'b1;
                    end
                end
                else begin
                    debounce_counter <= debounce_counter + 'b1;
                end
            end
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            repeat_start_counter <= '0;
            repeat_counter <= '0;
            repeat_pulse <= 1'b0;
        end
        else begin
            repeat_pulse <= 1'b0;

            if(tick_1ms) begin
                if(release_accept) begin
                    repeat_start_counter <= '0;
                    repeat_counter <= '0;
                end
                else if(press_accept) begin
                    repeat_start_counter <= '0;
                    repeat_counter <= REPEAT_INTERVAL_MS - 1'b1;
                    repeat_pulse <= 1'b1;
                end
                else if(pressed) begin
                    if((REPEAT_START_TIME_MS <= 1) || (repeat_start_counter >= (REPEAT_START_TIME_MS - 1'b1))) begin
                        if((REPEAT_INTERVAL_MS <= 1) || (repeat_counter >= (REPEAT_INTERVAL_MS - 1'b1))) begin
                            repeat_counter <= '0;
                            repeat_pulse <= 1'b1;
                        end
                        else begin
                            repeat_counter <= repeat_counter + 'b1;
                        end
                    end
                    else begin
                        repeat_start_counter <= repeat_start_counter + 'b1;
                    end
                end
                else begin
                    repeat_start_counter <= '0;
                    repeat_counter <= '0;
                end
            end
        end
    end
endmodule