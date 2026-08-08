`default_nettype none

module fwft_fifo #(
        parameter WIDTH = 1,
        parameter DEPTH = 1
    )(
        input logic clk,
        input logic rst,
        
        input logic[WIDTH - 1:0] data_in,
        input logic push,
        output logic full,
        input logic flush,
        
        output logic[WIDTH - 1:0] data_out,
        output logic data_out_valid,
        input logic pop,
        output logic empty
    );

    localparam DEPTH_WIDTH = $clog2(DEPTH);

    logic[DEPTH_WIDTH:0] rptr;
    logic[DEPTH_WIDTH:0] wptr;
    (* ramstyle = "M9K" *)logic[WIDTH - 1:0] buffer[0:DEPTH - 1];
    logic push_fire;
    logic pop_fire;

    assign push_fire = push && ~full && ~flush;
    assign pop_fire = pop && ~empty && ~flush;

    generate
        if(DEPTH_WIDTH == 0) begin
            assign full = wptr != rptr;
        end
        else begin
            assign full = (rptr[DEPTH_WIDTH - 1:0] == wptr[DEPTH_WIDTH - 1:0]) && (rptr[DEPTH_WIDTH] != wptr[DEPTH_WIDTH]);
        end
    endgenerate
    
    assign empty = (rptr == wptr) ? 'b1 : 'b0;

    always_ff @(posedge clk) begin
        if(rst || flush) begin
            wptr <= '0;
        end
        else if(push_fire) begin
            wptr <= wptr + 'b1;
        end
    end

    always_ff @(posedge clk) begin
        if(rst || flush) begin
            rptr <= '0;
        end
        else if(pop_fire) begin
            rptr <= rptr + 'b1;
        end
    end

    generate
        if(DEPTH_WIDTH == 0) begin
            always_ff @(posedge clk) begin
                if(!rst && push_fire) begin
                    buffer[0] <= data_in;
                end
            end
        end
        else begin
            always_ff @(posedge clk) begin
                if(!rst && push_fire) begin
                    buffer[wptr[DEPTH_WIDTH - 1:0]] <= data_in;
                end
            end
        end
    endgenerate

    generate
        if(DEPTH_WIDTH == 0) begin
            assign data_out = buffer[0];
        end
        else begin
            assign data_out = buffer[rptr[DEPTH_WIDTH - 1:0]];
        end
    endgenerate
    
    assign data_out_valid = !empty;
endmodule