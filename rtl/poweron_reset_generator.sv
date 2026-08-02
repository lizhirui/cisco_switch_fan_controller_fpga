module poweron_reset_generator(
        input logic clk,
        output logic rst_out
    );

    logic[3:0] cnt = '0;

    always_ff @(posedge clk) begin
        if(cnt != '1) begin
            cnt <= cnt + 'b1;
        end
    end

    always_ff @(posedge clk) begin
        if(cnt != '1) begin
            rst_out <= 1'b1;
        end
        else begin
            rst_out <= 1'b0;
        end
    end
endmodule