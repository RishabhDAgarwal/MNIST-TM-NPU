module hidden_layer_rom (
    input wire clk,
    input wire [15:0] address,         
    output reg signed [7:0] weight_out 
);

    reg signed [7:0] memory_array [0:50175];

    initial begin
        
        $readmemh("C:/Users/sriri/hidden_weights.hex", memory_array);
    end

    always @(posedge clk) begin
        weight_out <= memory_array[address];
    end

endmodule