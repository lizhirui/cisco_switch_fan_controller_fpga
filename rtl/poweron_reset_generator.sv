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

    assign rst_out = ~&cnt;
endmodule