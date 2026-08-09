`default_nettype none

module multi_fan_rpm_measurer #(
        parameter CLK_FREQ = 50000000,
        parameter PPR = 2,
        parameter FAN_NUM = 8,
        parameter RPM_WIDTH = 14,
        parameter RPM_SCALE_SHIFT = 6
    )(
        input logic clk,
        input logic rst,
        input logic[FAN_NUM - 1:0] fan_fb,
        output logic[RPM_WIDTH - 1:0] rpm[0:FAN_NUM - 1]
    );

    localparam logic[63:0] GATE_CYCLES_VALUE = (CLK_FREQ * 64'd60) / (PPR * (64'd1 << RPM_SCALE_SHIFT));
    localparam GATE_COUNTER_WIDTH = (GATE_CYCLES_VALUE <= 1) ? 1 : $clog2(GATE_CYCLES_VALUE);
    localparam PULSE_COUNTER_WIDTH = RPM_WIDTH - RPM_SCALE_SHIFT;
    localparam RPM_HALF_BIT = (RPM_SCALE_SHIFT == 0) ? 0 : RPM_SCALE_SHIFT - 1;
    localparam logic[GATE_COUNTER_WIDTH - 1:0] GATE_COUNTER_MAX = GATE_COUNTER_WIDTH'(GATE_CYCLES_VALUE - 1);
    localparam logic[RPM_WIDTH - 1:0] RPM_HALF_STEP = (RPM_SCALE_SHIFT == 0) ? '0 : (RPM_WIDTH'(1) << RPM_HALF_BIT);

    logic[FAN_NUM - 1:0] fan_fb_sync;
    logic[FAN_NUM - 1:0] fan_fb_sync_last;
    logic[FAN_NUM - 1:0] fan_fb_rise;
    logic fan_fb_sync_valid;
    logic fan_fb_sync_valid_last;
    logic fan_fb_edge_ready;
    logic[GATE_COUNTER_WIDTH - 1:0] gate_counter;
    logic[PULSE_COUNTER_WIDTH - 1:0] pulse_counter[0:FAN_NUM - 1];

    logic[PULSE_COUNTER_WIDTH - 1:0] rpm_pulse_base[0:FAN_NUM - 1];
    logic signed[PULSE_COUNTER_WIDTH:0] pulse_delta[0:FAN_NUM - 1];
    logic[FAN_NUM - 1:0] pulse_delta_zero;
    logic[FAN_NUM - 1:0] pulse_delta_positive_one;
    logic[FAN_NUM - 1:0] pulse_delta_negative_one;
    logic[FAN_NUM - 1:0] rpm_half;

    genvar i;

    signal_syncer #(
        .WIDTH(FAN_NUM),
        .STAGE(4),
        .RESET_VALUE(1'b0)
    )signal_syncer_inst(
        .clk(clk),
        .rst(rst),
        .din(fan_fb),
        .dout(fan_fb_sync),
        .dout_valid(fan_fb_sync_valid)
    );

    always_ff @(posedge clk) begin
        if(rst) begin
            fan_fb_sync_last <= '0;
            fan_fb_sync_valid_last <= 1'b0;
        end
        else begin
            fan_fb_sync_last <= fan_fb_sync;
            fan_fb_sync_valid_last <= fan_fb_sync_valid;
        end
    end

    assign fan_fb_edge_ready = fan_fb_sync_valid & fan_fb_sync_valid_last;
    assign fan_fb_rise = {FAN_NUM{fan_fb_edge_ready}} & fan_fb_sync & ~fan_fb_sync_last;

    generate
        for(i = 0;i < FAN_NUM;i = i + 1) begin:rpm_filter_gen
            assign rpm_pulse_base[i] = rpm[i][RPM_WIDTH - 1:RPM_SCALE_SHIFT];

            assign pulse_delta[i] =
                $signed({1'b0, pulse_counter[i]}) -
                $signed({1'b0, rpm_pulse_base[i]});

            assign pulse_delta_zero[i] = ~|pulse_delta[i];

            assign pulse_delta_positive_one[i] =
                pulse_delta[i][0] &
                ~|pulse_delta[i][PULSE_COUNTER_WIDTH:1];

            assign pulse_delta_negative_one[i] = &pulse_delta[i];

            assign rpm_half[i] =
                (RPM_SCALE_SHIFT == 0) ?
                1'b0 :
                rpm[i][RPM_HALF_BIT];
        end
    endgenerate

    always_ff @(posedge clk) begin
        if(rst) begin
            gate_counter <= '0;

            for(integer i = 0;i < FAN_NUM;i = i + 1) begin
                pulse_counter[i] <= '0;
                rpm[i] <= '0;
            end
        end
        else if(!fan_fb_edge_ready) begin
            gate_counter <= '0;

            for(integer i = 0;i < FAN_NUM;i = i + 1) begin
                pulse_counter[i] <= '0;
            end
        end
        else if(gate_counter == GATE_COUNTER_MAX) begin
            gate_counter <= '0;

            for(integer i = 0;i < FAN_NUM;i = i + 1) begin
                if(pulse_counter[i] == '0) begin
                    rpm[i] <= '0;
                end
                else if(rpm[i] == '0) begin
                    rpm[i] <= {pulse_counter[i], {RPM_SCALE_SHIFT{1'b0}}};
                end
                else if(RPM_SCALE_SHIFT == 0) begin
                    rpm[i] <= pulse_counter[i];
                end
                else if(rpm_half[i]) begin
                    if(!(pulse_delta_zero[i] || pulse_delta_positive_one[i])) begin
                        rpm[i] <= {pulse_counter[i], {RPM_SCALE_SHIFT{1'b0}}};
                    end
                end
                else begin
                    if(pulse_delta_positive_one[i]) begin
                        rpm[i] <= {rpm_pulse_base[i], {RPM_SCALE_SHIFT{1'b0}}} | RPM_HALF_STEP;
                    end
                    else if(pulse_delta_negative_one[i]) begin
                        rpm[i] <= {pulse_counter[i], {RPM_SCALE_SHIFT{1'b0}}} | RPM_HALF_STEP;
                    end
                    else if(!pulse_delta_zero[i]) begin
                        rpm[i] <= {pulse_counter[i], {RPM_SCALE_SHIFT{1'b0}}};
                    end
                end

                if(fan_fb_rise[i]) begin
                    pulse_counter[i] <= PULSE_COUNTER_WIDTH'(1);
                end
                else begin
                    pulse_counter[i] <= '0;
                end
            end
        end
        else begin
            gate_counter <= gate_counter + 1'b1;

            for(integer i = 0;i < FAN_NUM;i = i + 1) begin
                if(fan_fb_rise[i] && ~&pulse_counter[i]) begin
                    pulse_counter[i] <= pulse_counter[i] + 1'b1;
                end
            end
        end
    end
endmodule