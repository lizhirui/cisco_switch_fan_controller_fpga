`default_nettype none

module double_buffered_vram #(
        parameter ADDR_WIDTH = 8,
        parameter DATA_WIDTH = 8
    )(
        input logic clk,
        input logic rst,

        input logic[ADDR_WIDTH - 1:0] waddr,
        input logic[DATA_WIDTH - 1:0] wdata,
        input logic we,
        input logic[ADDR_WIDTH - 1:0] write_buffer_raddr,
        output logic[DATA_WIDTH - 1:0] write_buffer_rdata,
        input logic submit,
        output logic submitting,
        
        input logic[ADDR_WIDTH - 1:0] raddr,
        output logic[DATA_WIDTH - 1:0] rdata,
        input logic switch
    );

    logic[DATA_WIDTH - 1:0] a_rdata;
    logic[DATA_WIDTH - 1:0] write_buffer_a_rdata;
    logic[DATA_WIDTH - 1:0] b_rdata;
    logic[DATA_WIDTH - 1:0] write_buffer_b_rdata;

    logic cur_ram;

    true_dual_port_ram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    )true_dual_port_ram_a_inst(
        .clk(clk),
        .a_addr(we ? waddr : write_buffer_raddr),
        .a_wdata(wdata),
        .a_we(~cur_ram & we & !submit & !submitting),
        .a_rdata(write_buffer_a_rdata),
        .b_addr(raddr),
        .b_wdata('0),
        .b_we(1'b0),
        .b_rdata(a_rdata)
    );

    true_dual_port_ram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    )true_dual_port_ram_b_inst(
        .clk(clk),
        .a_addr(we ? waddr : write_buffer_raddr),
        .a_wdata(wdata),
        .a_we(cur_ram & we & !submit & !submitting),
        .a_rdata(write_buffer_b_rdata),
        .b_addr(raddr),
        .b_wdata('0),
        .b_we(1'b0),
        .b_rdata(b_rdata)
    );

    always_ff @(posedge clk) begin
        if(rst) begin
            cur_ram <= 1'b0;
        end
        else if((submit | submitting) && switch) begin
            cur_ram <= ~cur_ram;
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            submitting <= 1'b0;
        end
        else if(submit && !switch) begin
            submitting <= 1'b1;
        end
        else if(switch) begin
            submitting <= 1'b0;
        end
    end
    
    assign write_buffer_rdata = cur_ram ? write_buffer_b_rdata : write_buffer_a_rdata;
    assign rdata = cur_ram ? a_rdata : b_rdata;
endmodule