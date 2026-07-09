module output_layer_rom (
    input wire clk,
    input wire [9:0] address,         
    output reg signed [7:0] weight_out 
);

    reg signed [7:0] memory_array [0:639];

    initial begin
        
        $readmemh("C:/Users/sriri/output_weights.hex", memory_array);
    end

    always @(posedge clk) begin
        weight_out <= memory_array[address];
    end

endmodule