module image_ram (
    input wire clk,
    input wire write_enable,           
    input wire [9:0] address,          
    input wire [7:0] data_in,   
    output reg [7:0] data_out   
);

    
    reg [7:0] memory_array [0:783];

    
    always @(posedge clk) begin
        
        if (write_enable) begin
            memory_array[address] <= data_in;
        end
        
        
        data_out <= memory_array[address];
    end

endmodule