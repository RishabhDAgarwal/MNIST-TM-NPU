`timescale 1ns / 1ps

module relu_activation (
    input wire signed [63:0] data_in,   
    output wire signed [63:0] data_out  
);
    // If negative output 0. Otherwise pass the 64-bit value 
    assign data_out = (data_in > 64'sd0) ? data_in : 64'sd0;
endmodule