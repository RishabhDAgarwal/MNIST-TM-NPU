module argmax (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire [3:0] current_index,
    input wire signed [63:0] current_val, 
    output reg [3:0] predicted_digit
);

    reg signed [63:0] max_val_so_far;     

    always @(posedge clk) begin
        if (reset) begin
            max_val_so_far <= 64'd0;
            predicted_digit <= 4'd0;
        end else if (enable) begin
           
            if ((current_index == 4'd0) || (current_val > max_val_so_far)) begin
                max_val_so_far <= current_val;
                predicted_digit <= current_index;
            end
        end
    end
    
endmodule