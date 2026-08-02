`default_nettype none

module lcd_page_main #(
        parameter LINE_ID_WIDTH = 5,
        parameter LINE_DATA_WIDTH = 128
    )(
        input logic clk,
        input logic rst,

        input logic[LINE_ID_WIDTH - 1:0] line_id,
        output logic[LINE_DATA_WIDTH - 1:0] line_data
    );

    always_ff @(posedge clk) begin
        if(rst) begin
            line_data <= '0;
        end
        else begin
            line_data <= '0;

            case(line_id)
                'd0: begin
                    line_data <= "7654321087654321";
                end

                'd1: begin
                    line_data <= 128'h36_C3_BA_35_34_33_32_31_E7_BD_C0_CA_C3_BA_E3_C4;
                end

                'd2: begin
                    line_data <= 128'hFEB9_FEB9_FEB9_FEB9_FEB9_FEB9_FEB9_FEB9;
                end

                'd3: begin
                    line_data <= "1234567801234567";
                end
            endcase
        end
    end
endmodule