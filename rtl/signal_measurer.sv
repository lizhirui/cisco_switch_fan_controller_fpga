`default_nettype none

module signal_measurer #(
        parameter CNT_WIDTH = 32,
        parameter TIMEOUT_CNT = 50000000
    )(
        input logic clk,
        input logic rst,
        input logic signal,
        output logic[CNT_WIDTH - 1:0] high_level_cnt,
        output logic[CNT_WIDTH - 1:0] low_level_cnt,
        output logic[CNT_WIDTH - 1:0] total_cnt,
        output logic period_valid
    );
    
    logic signal_sync_last;
    logic signal_sync;
    logic signal_sync_ready;
    logic signal_sync_ready_last;
    logic signal_edge_ready;
    logic signal_rise;
    logic signal_fall;
    logic signal_edge;
    logic[CNT_WIDTH - 1:0] counter;
    logic[CNT_WIDTH - 1:0] rise_timestamp;
    logic[CNT_WIDTH - 1:0] fall_timestamp;
    logic[CNT_WIDTH - 1:0] last_edge_timestamp;
    logic[CNT_WIDTH - 1:0] high_level_cnt_pending;
    logic have_rise;
    logic have_fall;
    logic signal_static;
    logic signal_timeout;
    
    always_ff @(posedge clk) begin
        if(rst) begin
            high_level_cnt <= '0;
            low_level_cnt <= '0;
            total_cnt <= '0;
            period_valid <= 1'b0;
        end
        else if(signal_timeout) begin
            if(signal_sync) begin
                high_level_cnt <= TIMEOUT_CNT;
                low_level_cnt <= '0;
            end
            else begin
                high_level_cnt <= '0;
                low_level_cnt <= TIMEOUT_CNT;
            end
            
            total_cnt <= TIMEOUT_CNT;
            period_valid <= 1'b0;
        end
        else if(signal_rise && have_rise && have_fall) begin
            high_level_cnt <= high_level_cnt_pending;
            low_level_cnt <= counter - fall_timestamp;
            total_cnt <= counter - rise_timestamp;
            period_valid <= 1'b1;
        end
    end
    
    signal_syncer #(
        .WIDTH(1),
        .STAGE(4),
        .RESET_VALUE(1'b0)
    )signal_syncer_inst(
        .clk(clk),
        .rst(rst),
        .din(signal),
        .dout(signal_sync),
        .dout_valid(signal_sync_ready)
    );
    
    always_ff @(posedge clk) begin
        if(rst) begin
            signal_sync_last <= 1'b0;
        end
        else begin
            signal_sync_last <= signal_sync;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            signal_sync_ready_last <= 1'b0;
        end
        else begin
            signal_sync_ready_last <= signal_sync_ready;
        end
    end
    
    assign signal_edge_ready = signal_sync_ready & signal_sync_ready_last;
    assign signal_rise = signal_edge_ready & signal_sync & ~signal_sync_last;
    assign signal_fall = signal_edge_ready & ~signal_sync & signal_sync_last;
    assign signal_edge = signal_rise | signal_fall;
    
    always_ff @(posedge clk) begin
        if(rst) begin
            counter <= '0;
        end
        else begin
            counter <= counter + 'b1;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            rise_timestamp <= '0;
            fall_timestamp <= '0;
            high_level_cnt_pending <= '0;
            have_rise <= 1'b0;
            have_fall <= 1'b0;
        end
        else if(signal_timeout) begin
            have_rise <= 1'b0;
            have_fall <= 1'b0;
        end
        else if(signal_rise) begin
            rise_timestamp <= counter;
            have_rise <= 1'b1;
            have_fall <= 1'b0;
        end
        else if(signal_fall && have_rise && ~have_fall) begin
            high_level_cnt_pending <= counter - rise_timestamp;
            fall_timestamp <= counter;
            have_fall <= 1'b1;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            last_edge_timestamp <= '0;
        end
        else if(signal_edge || !signal_edge_ready) begin
            last_edge_timestamp <= counter;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            signal_static <= 1'b0;
        end
        else if(signal_edge) begin
            signal_static <= 1'b0;
        end
        else if(signal_timeout) begin
            signal_static <= 1'b1;
        end
    end
    
    assign signal_timeout = (signal_edge_ready && !signal_static && !signal_edge && ((counter - last_edge_timestamp) >= TIMEOUT_CNT)) ? 1'b1 : 1'b0;
endmodule