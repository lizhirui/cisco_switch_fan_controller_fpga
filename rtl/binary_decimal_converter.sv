`default_nettype none

module binary_decimal_converter #(
        parameter VALUE_WIDTH = 8,
        parameter DIGIT_NUM = 3
    )(
        input logic clk,
        input logic rst,
        input logic[VALUE_WIDTH - 1:0] value,
        output logic[DIGIT_NUM * 8 - 1:0] text
    );

    localparam BCD_WIDTH = DIGIT_NUM * 4;
    localparam SHIFT_WIDTH = BCD_WIDTH + VALUE_WIDTH;
    localparam ITERATION_WIDTH = (VALUE_WIDTH <= 1) ? 1 : $clog2(VALUE_WIDTH);

    logic[SHIFT_WIDTH - 1:0] shift_data;
    logic[SHIFT_WIDTH - 1:0] shift_data_adjusted;
    logic[SHIFT_WIDTH - 1:0] shift_data_next;
    logic[ITERATION_WIDTH - 1:0] iteration;
    logic initialized;

    always_comb begin
        shift_data_adjusted = shift_data;

        for(integer i = 0;i < DIGIT_NUM;i = i + 1) begin
            if(shift_data_adjusted[VALUE_WIDTH + i * 4 +: 4] >= 4'd5) begin
                shift_data_adjusted[VALUE_WIDTH + i * 4 +: 4] = shift_data_adjusted[VALUE_WIDTH + i * 4 +: 4] + 4'd3;
            end
        end

        shift_data_next = shift_data_adjusted << 1;
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            shift_data <= '0;
            iteration <= '0;
            text <= '0;
            initialized <= 1'b0;
        end
        else if(!initialized) begin
            shift_data <= {{BCD_WIDTH{1'b0}}, value};
            iteration <= '0;
            initialized <= 1'b1;
        end
        else if(iteration >= VALUE_WIDTH - 1) begin
            for(integer i = 0;i < DIGIT_NUM;i = i + 1) begin
                text[i * 8 +: 8] <= 8'h30 + shift_data_next[VALUE_WIDTH + (DIGIT_NUM - 1 - i) * 4 +: 4];
            end

            shift_data <= {{BCD_WIDTH{1'b0}}, value};
            iteration <= '0;
        end
        else begin
            shift_data <= shift_data_next;
            iteration <= iteration + 1'b1;
        end
    end
endmodule