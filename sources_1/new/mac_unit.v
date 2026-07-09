module mac_unit (
    input wire clk,
    input wire clear_accum,             
    input wire enable,                  
    input wire signed [25:0] weight_in,  
    input wire signed [25:0] data_in,    
    input wire signed [63:0] bias_in,    
    output reg signed [63:0] accumulator 
);

    // 26-bit * 26-bit requires a 52-bit product register
    wire signed [51:0] product;
    assign product = weight_in * data_in;

    initial begin
        accumulator = 64'd0;
    end

    always @(posedge clk) begin
        if (clear_accum) begin
            accumulator <= bias_in; // Pre-load 64-bit sign-extended bias
        end 
        else if (enable) begin
            accumulator <= accumulator + {{12{product[51]}}, product}; // Sign-extend product to 64-bit
        end
    end

endmodule