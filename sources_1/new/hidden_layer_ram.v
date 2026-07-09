module hidden_layer_ram (
    input wire clk,
    input wire write_enable,          
    input wire [5:0] address,         
    input wire signed [63:0] data_in, 
    output reg signed [63:0] data_out 
);

    // 64 memory slots, each holding a 64-bit signed number
    reg signed [63:0] memory_array [0:63];

    always @(posedge clk) begin
        if (write_enable) begin
            memory_array[address] <= data_in;
        end
        
        // Always output the currently addressed data
        data_out <= memory_array[address];
    end

endmodule