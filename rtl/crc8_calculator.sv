`default_nettype none

module crc8_calculator #(
        parameter logic[7:0] POLYNOMIAL = 8'h07,
        parameter logic[7:0] INITIAL_VALUE = 8'h00,
        parameter logic[7:0] XOR_OUT = 8'h00
    )(
        input logic clk,
        input logic rst,
        
        input logic crc_start,
        input logic[7:0] crc_data,
        input logic crc_data_valid,
        output logic[7:0] crc8_value
    );
    
    logic[7:0] crc8_raw;
    
    function automatic logic[7:0] calculate_crc8_byte(
            input logic[7:0] crc8_input,
            input logic[7:0] data
        );
        
        logic[7:0] crc8_work;
        integer bit_id;
        
        begin
            crc8_work = crc8_input ^ data;
            
            for(bit_id = 0; bit_id < 8; bit_id = bit_id + 1) begin
                if(crc8_work[7]) begin
                    crc8_work = (crc8_work << 1) ^ POLYNOMIAL;
                end
                else begin
                    crc8_work = crc8_work << 1;
                end
            end
            
            calculate_crc8_byte = crc8_work;
        end
    endfunction
    
    assign crc8_value = crc8_raw ^ XOR_OUT;
    
    always_ff @(posedge clk) begin
        if(rst) begin
            crc8_raw <= INITIAL_VALUE;
        end
        else if(crc_start) begin
            if(crc_data_valid) begin
                crc8_raw <= calculate_crc8_byte(INITIAL_VALUE, crc_data);
            end
            else begin
                crc8_raw <= INITIAL_VALUE;
            end
        end
        else if(crc_data_valid) begin
            crc8_raw <= calculate_crc8_byte(crc8_raw, crc_data);
        end
    end
endmodule