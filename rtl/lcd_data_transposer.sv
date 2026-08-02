`default_nettype none

module lcd_data_transposer #(
        parameter DATA_WIDTH = 8,
        parameter SIDE_DATA_WIDTH = 1
    )(
        input logic clk,
        input logic rst,

        input logic[DATA_WIDTH - 1:0] in_data,
        input logic[SIDE_DATA_WIDTH - 1:0] in_side_data,
        input logic in_data_valid,
        output logic in_data_pop,

        output logic[DATA_WIDTH - 1:0] out_data,
        output logic[SIDE_DATA_WIDTH - 1:0] out_side_data,
        output logic out_data_push,
        input logic out_data_full,
        
        output logic idle
    );

    localparam OFFSET_WIDTH = (DATA_WIDTH <= 1) ? 1 : $clog2(DATA_WIDTH);

    logic[DATA_WIDTH - 1:0] transpose_buffer[0:1][0:DATA_WIDTH - 1];
    logic[SIDE_DATA_WIDTH - 1:0] side_data_buffer[0:1];
    logic write_bank;
    logic read_bank;

    logic[OFFSET_WIDTH - 1:0] write_offset;
    logic[OFFSET_WIDTH - 1:0] read_offset;
    logic[1:0] tile_count;
    logic input_ready;
    logic input_fire;
    logic input_tile_finish;
    logic output_fire;
    logic output_tile_finish;

    assign output_fire = (tile_count != '0) && !out_data_full;
    assign output_tile_finish = output_fire && (read_offset == (DATA_WIDTH - 'b1));
    assign input_ready = (tile_count != 2'd2) || output_tile_finish;
    assign in_data_pop = in_data_valid && input_ready;
    assign input_fire = in_data_pop;
    assign input_tile_finish = input_fire && (write_offset == (DATA_WIDTH - 'b1));
    assign out_data = (tile_count != 'b0) ? transpose_buffer[read_bank][read_offset] : '0;
    assign out_side_data = (tile_count != '0) ? side_data_buffer[read_bank] : '0;
    assign out_data_push = output_fire;

    integer column_idx;

    always_ff @(posedge clk) begin
        if(rst) begin
            side_data_buffer[0] <= '0;
            side_data_buffer[1] <= '0;
        end
        else if(input_fire && (write_offset == '0)) begin
            side_data_buffer[write_bank] <= in_side_data;
        end
    end

    always_ff @(posedge clk) begin
        if(input_fire) begin
            for(column_idx = 0;column_idx < DATA_WIDTH;column_idx = column_idx + 1) begin
                transpose_buffer[write_bank][column_idx][write_offset] <= in_data[column_idx];
            end
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            write_offset <= '0;
            write_bank <= 1'b0;
        end
        else if(input_fire) begin
            if(write_offset == (DATA_WIDTH - 'b1)) begin
                write_offset <= '0;
                write_bank <= ~write_bank;
            end
            else begin
                write_offset <= write_offset + 'b1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            read_offset <= '0;
            read_bank <= 1'b0;
        end
        else if(output_fire) begin
            if(read_offset == (DATA_WIDTH - 'b1)) begin
                read_offset <= '0;
                read_bank <= ~read_bank;
            end
            else begin
                read_offset <= read_offset + 'b1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            tile_count <= '0;
        end
        else begin
            case({input_tile_finish, output_tile_finish})
                2'b01: begin
                    tile_count <= tile_count - 'b1;
                end

                2'b10: begin
                    tile_count <= tile_count + 'b1;
                end

                default: begin
                    tile_count <= tile_count;
                end
            endcase
        end
    end
    
    assign idle = ((tile_count == '0) && (write_offset == '0) && !input_fire) ? 1'b1 : 1'b0;
endmodule