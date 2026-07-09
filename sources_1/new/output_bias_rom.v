`timescale 1ns / 1ps

module output_bias_rom (
    input wire clk,
    input wire [3:0] address,         // 10 Output Neurons (0 to 9)
    output reg signed [31:0] bias_out 
);

    reg signed [31:0] memory_array [0:9];

    initial begin
        $readmemh("C:/Users/sriri/output_biases.hex", memory_array);
    end

    always @(posedge clk) begin
        bias_out <= memory_array[address];
    end

endmodule