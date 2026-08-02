`default_nettype none

module vram_write_controller #(
        parameter VRAM_ADDR_WIDTH = 8,
        parameter VRAM_DATA_WIDTH = 8
    )(
        input logic clk,
        input logic rst,

        input logic[VRAM_ADDR_WIDTH - 1:0] vwc_waddr,
        input logic[VRAM_DATA_WIDTH - 1:0] vwc_wdata,
        input logic vwc_we,
        input logic vwc_submit,
        output logic vwc_busy,

        output logic[VRAM_ADDR_WIDTH - 1:0] vram_waddr,
        output logic[VRAM_DATA_WIDTH - 1:0] vram_wdata,
        output logic vram_we,
        output logic vram_submit,
        input logic vram_submitting
    );

    localparam STATE_WIDTH = 3;
    localparam STATE_RESET_VRAM_A_WRITE_ALL_ZERO = STATE_WIDTH'('d0);
    localparam STATE_RESET_VRAM_SUBMIT = STATE_WIDTH'('d1);
    localparam STATE_RESET_VRAM_WAIT_SUBMITTING = STATE_WIDTH'('d2);
    localparam STATE_RESET_VRAM_B_WRITE_ALL_ZERO = STATE_WIDTH'('d3);
    localparam STATE_NORMAL = STATE_WIDTH'('d4);

    logic[STATE_WIDTH - 1:0] cur_state;
    logic[STATE_WIDTH - 1:0] next_state;

    logic[VRAM_ADDR_WIDTH - 1:0] reset_vram_waddr;

    always_ff @(posedge clk) begin
        if(rst) begin
            cur_state <= STATE_RESET_VRAM_A_WRITE_ALL_ZERO;
        end
        else begin
            cur_state <= next_state;
        end
    end

    always_comb begin
        next_state = cur_state;

        case(cur_state)
            STATE_RESET_VRAM_A_WRITE_ALL_ZERO: begin
                if(reset_vram_waddr == '1) begin
                    next_state = STATE_RESET_VRAM_SUBMIT;
                end
            end

            STATE_RESET_VRAM_SUBMIT: begin
                if(!vram_submitting) begin
                    next_state = STATE_RESET_VRAM_WAIT_SUBMITTING;
                end
            end

            STATE_RESET_VRAM_WAIT_SUBMITTING: begin
                if(!vram_submitting) begin
                    next_state = STATE_RESET_VRAM_B_WRITE_ALL_ZERO;
                end
            end

            STATE_RESET_VRAM_B_WRITE_ALL_ZERO: begin
                if(reset_vram_waddr == '1) begin
                    next_state = STATE_NORMAL;
                end
            end
        endcase
    end

    assign vram_waddr = (cur_state == STATE_NORMAL) ? vwc_waddr : reset_vram_waddr;
    assign vram_wdata = (cur_state == STATE_NORMAL) ? vwc_wdata : '0;
    assign vram_we = (cur_state == STATE_NORMAL) ? vwc_we : ((cur_state == STATE_RESET_VRAM_A_WRITE_ALL_ZERO) || (cur_state == STATE_RESET_VRAM_B_WRITE_ALL_ZERO)) ? 1'b1 : 1'b0;
    assign vram_submit = (cur_state == STATE_NORMAL) ? vwc_submit : (cur_state == STATE_RESET_VRAM_SUBMIT) ? 1'b1 : 1'b0;
    assign vwc_busy = (cur_state == STATE_NORMAL) ? vram_submitting : 1'b1;

    always_ff @(posedge clk) begin
        if(rst) begin
            reset_vram_waddr <= '0;
        end
        else if((cur_state == STATE_RESET_VRAM_A_WRITE_ALL_ZERO) || (cur_state == STATE_RESET_VRAM_B_WRITE_ALL_ZERO)) begin
            reset_vram_waddr <= reset_vram_waddr + 'b1;
        end
    end
endmodule