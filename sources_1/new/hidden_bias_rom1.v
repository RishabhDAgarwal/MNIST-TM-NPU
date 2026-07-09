`timescale 1ns / 1ps

module hidden_bias_rom1 (
    input wire clk,
    input wire [5:0] address,         // 64 Hidden Neurons (0 to 63)
    output reg signed [31:0] bias_out 
);

    reg signed [31:0] memory_array [0:63];

    initial begin
        $readmemh("C:/Users/sriri/hidden_biases.hex", memory_array);
    end

    always @(posedge clk) begin
        bias_out <= memory_array[address];
    end

endmodule
