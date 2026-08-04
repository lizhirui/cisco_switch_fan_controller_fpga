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
        input logic switch,
        
        input logic[ADDR_WIDTH - 1:0] clone_vram_raddr,
        output logic[DATA_WIDTH - 1:0] clone_vram_rdata,
        input logic clone_vram_start,
        output logic clone_vram_busy
    );
    
    localparam STATE_WIDTH = 2;
    localparam STATE_IDLE = STATE_WIDTH'('d0);
    localparam STATE_WAIT_FIRST_SUBMIT = STATE_WIDTH'('d1);
    localparam STATE_WAIT_SECOND_SUBMIT = STATE_WIDTH'('d2);

    logic[DATA_WIDTH - 1:0] a_rdata;
    logic[DATA_WIDTH - 1:0] write_buffer_a_rdata;
    logic[DATA_WIDTH - 1:0] b_rdata;
    logic[DATA_WIDTH - 1:0] write_buffer_b_rdata;

    logic cur_ram;
    
    logic[ADDR_WIDTH - 1:0] raddr_sync;

    logic[STATE_WIDTH - 1:0] cur_state;
    logic[STATE_WIDTH - 1:0] next_state;

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
        else if((submit || submitting) && switch) begin
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
    
    simple_dual_port_ram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    )simple_dual_port_ram_clone_inst(
        .clk(clk),
        .waddr(raddr_sync),
        .wdata(rdata),
        .we((cur_state == STATE_WAIT_SECOND_SUBMIT) ? 1'b1 : 1'b0),
        .raddr(clone_vram_raddr),
        .rdata(clone_vram_rdata)
    );
    
    always_ff @(posedge clk) begin
        if(rst) begin
            raddr_sync <= '0;
        end
        else begin
            raddr_sync <= raddr;
        end
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            cur_state <= STATE_IDLE;
        end
        else begin
            cur_state <= next_state;
        end
    end
    
    always_comb begin
        next_state = cur_state;
        
        case(cur_state)
            STATE_IDLE: begin
                if(clone_vram_start) begin
                    if((submit || submitting) && switch) begin
                        next_state = STATE_WAIT_SECOND_SUBMIT; 
                    end
                    else begin
                        next_state = STATE_WAIT_FIRST_SUBMIT;
                    end
                end
            end
            
            STATE_WAIT_FIRST_SUBMIT: begin
                if((submit || submitting) && switch) begin
                    next_state = STATE_WAIT_SECOND_SUBMIT;
                end
            end
            
            STATE_WAIT_SECOND_SUBMIT: begin
                if((submit || submitting) && switch) begin
                    next_state = STATE_IDLE;
                end
            end
        endcase
    end
    
    always_ff @(posedge clk) begin
        if(rst) begin
            clone_vram_busy <= 1'b0;
        end
        else if((cur_state == STATE_IDLE) && (cur_state != next_state)) begin
            clone_vram_busy <= 1'b1;
        end
        else if((cur_state != next_state) && (next_state == STATE_IDLE)) begin
            clone_vram_busy <= 1'b0;
        end
    end
endmodule