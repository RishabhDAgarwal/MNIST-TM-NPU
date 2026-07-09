module neural_net_top (
    input wire clk,
    input wire start_inference,
    input wire write_enable,
    input wire [9:0] external_addr,
    input wire [7:0] external_pixel,
    
    output wire [3:0] final_predicted_digit, 
    output reg calculation_done
);

   
    // 1. THE INTERNAL WIRES
    
    wire signed [63:0] final_neuron_value; 
    wire signed [63:0] relu_output;
    
   
    wire [7:0] pixel_to_mac;
    wire signed [7:0] weight_to_mac;
    wire signed [7:0] output_weight_data;
   wire signed [31:0] hidden_bias_data; 
    wire signed [31:0] output_bias_data;
    
    
    wire signed [63:0] hidden_layer_data; 
   
    wire signed [25:0] mac_weight_in;
    wire signed [25:0] mac_data_in;
    wire signed [63:0] mac_bias_in;
    
    reg mac_enable;
    reg mac_clear;    
    reg hidden_write_enable;
    reg is_phase_2; //  Phase Switch
    
    //  switches for the ArgMax chip
    reg argmax_enable;
    reg argmax_reset;
    
    reg [9:0] current_pixel;   // Counts 0 to 783
    reg [5:0] current_neuron;  // Counts 0 to 63

    
    // 1.5 DATAPATH ROUTING, MUXES & QUANTIZATION
    assign mac_weight_in = is_phase_2 ? {{18{output_weight_data[7]}}, output_weight_data} : 
                                        {{18{weight_to_mac[7]}}, weight_to_mac};
    
    assign mac_data_in   = is_phase_2 ? hidden_layer_data[25:0] : 
                                        {18'd0, pixel_to_mac};
    
    assign mac_bias_in   = is_phase_2 ? {{32{output_bias_data[31]}}, output_bias_data} : 
                                        {{32{hidden_bias_data[31]}}, hidden_bias_data};

     
   
    // 1.6 ADDRESS ROUTING & COUNTERS
    
    wire [5:0] hidden_ram_addr;
    assign hidden_ram_addr = is_phase_2 ? current_pixel[5:0] : current_neuron;

    reg [15:0] hidden_weight_addr_counter; 
    reg [9:0]  output_weight_addr_counter;

    
    // 2. PLACING THE CHIPS ON THE MOTHERBOARD
    

    // The Memory Primitives
    output_layer_rom my_output_weight_memory (
        .clk(clk),
        .address(output_weight_addr_counter), 
        .weight_out(output_weight_data)       
    );

    hidden_bias_rom1 my_hidden_biases (
        .clk(clk),
        .address(current_neuron), 
        .bias_out(hidden_bias_data)           
    );

    output_bias_rom my_output_biases (
        .clk(clk),
        .address(current_neuron[3:0]), 
        .bias_out(output_bias_data)          
    );
    
    image_ram my_pixel_memory (
        .clk(clk),
        .write_enable(write_enable),
        .address(write_enable ? external_addr : current_pixel), 
        .data_in(external_pixel),
        .data_out(pixel_to_mac)               
    );

   hidden_layer_rom my_weight_memory (
        .clk(clk),
        .address(hidden_weight_addr_counter), 
        .weight_out(weight_to_mac)            
    );

    // The Datapath Chips
    mac_unit my_math_engine (
        .clk(clk),
        .clear_accum(mac_clear),
        .enable(mac_enable),
        .weight_in(mac_weight_in),            
        .data_in(mac_data_in),                
        .bias_in(mac_bias_in),               
        .accumulator(final_neuron_value)      
    );

    relu_activation my_activation (
        .data_in(final_neuron_value),        
        .data_out(relu_output)      //64 bit o/p          
    );
     
    hidden_layer_ram my_hidden_memory (
        .clk(clk),
        .write_enable(hidden_write_enable),
        .address(hidden_ram_addr),            
        .data_in(relu_output),           
        .data_out(hidden_layer_data)          
    );
    
    argmax my_classifier (
        .clk(clk),
        .reset(argmax_reset),                 
        .enable(argmax_enable),               
        .current_index(current_neuron[3:0]),  
        .current_val(final_neuron_value),     // Reads the live 64-bit MAC output in phase 2
        .predicted_digit(final_predicted_digit)
    );

   
    // 3. THE FINITE STATE MACHINE (THE BRAIN)
    
    
   localparam STATE_IDLE         = 4'd0;

localparam STATE_LOAD         = 4'd1;   

localparam STATE_CALC         = 4'd2;

localparam STATE_SAVE         = 4'd3;

localparam STATE_SAVE_HOLD    = 4'd4;   

localparam STATE_ARGMAX       = 4'd5;

localparam STATE_ARGMAX_HOLD  = 4'd6;   

localparam STATE_DONE         = 4'd7;

localparam STATE_LOAD2        = 4'd8;

localparam STATE_PHASE2_PRELOAD = 4'd9;  

    reg [3:0] current_state = STATE_IDLE; 

    always @(posedge clk) begin
        case (current_state)
            
            STATE_IDLE: begin
                argmax_reset <= 1'b1;         
                argmax_enable <= 1'b0;        
                calculation_done <= 1'b0;
                mac_enable <= 1'b0;
                mac_clear <= 1'b0; 
                hidden_write_enable <= 1'b0;
                
                current_pixel <= 10'd0;
                current_neuron <= 6'd0;
                is_phase_2 <= 1'b0;            
                hidden_weight_addr_counter <= 16'd0;
                output_weight_addr_counter <= 10'd0;
                
                if (start_inference) begin
                    current_state <= STATE_LOAD;
                end
            end
            
            STATE_LOAD: begin
                argmax_reset <= 1'b0;
                argmax_enable <= 1'b0;
                hidden_write_enable <= 1'b0;
                
                // Cycle 1: Addresses are presented to BRAM/ROM.
                // We assert mac_clear NOW so it is high for the next clock edge.
                mac_clear <= 1'b1; 
                mac_enable <= 1'b0;
                current_state <= STATE_LOAD2;
            end

            STATE_LOAD2: begin
                // Cycle 2: BRAM/ROM output valid data (Bias arrives).
                // mac_clear IS 1 right now. MAC loads bias on the next clock edge.
                mac_clear <= 1'b0;  // Turn off clear for Cycle 3
                mac_enable <= 1'b1; // Turn ON enable for Cycle 3
                current_state <= STATE_CALC;
            end
            
            STATE_CALC: begin
                // Cycle 3+: mac_enable IS 1. MAC safely accumulates Pixel 0.
                if (!is_phase_2) begin
                    if (current_pixel < 10'd783) begin
                        current_pixel <= current_pixel + 1;
                        hidden_weight_addr_counter <= hidden_weight_addr_counter + 1;
                    end else begin
                        mac_enable <= 1'b0;
                        current_state <= STATE_SAVE;
                    end
                end else begin 
                    if (current_pixel < 10'd63) begin
                        current_pixel <= current_pixel + 1;
                        output_weight_addr_counter <= output_weight_addr_counter + 1;
                    end else begin
                        mac_enable <= 1'b0;
                        current_state <= STATE_ARGMAX;
                    end
                end
            end
            
            STATE_SAVE: begin
                hidden_write_enable <= 1'b1;
                mac_enable <= 1'b0;
                current_state <= STATE_SAVE_HOLD;
            end

            STATE_SAVE_HOLD: begin
                hidden_write_enable <= 1'b0;

                if (current_neuron < 6'd63) begin
                    current_neuron <= current_neuron + 1;
                    current_pixel <= 10'd0;
                    
                    
                    hidden_weight_addr_counter <= hidden_weight_addr_counter + 1; 
                    
                    current_state <= STATE_LOAD;
                end else begin
                    is_phase_2 <= 1'b1;
                    current_neuron <= 6'd0;
                    current_pixel <= 10'd0;
                    output_weight_addr_counter <= 10'd0;
                    mac_enable <= 1'b0;
                    current_state <= STATE_PHASE2_PRELOAD;
                end
            end

            STATE_PHASE2_PRELOAD: begin
               
                current_state <= STATE_LOAD;
            end

            STATE_ARGMAX: begin
                argmax_enable <= 1'b1;
                current_state <= STATE_ARGMAX_HOLD;
            end

            STATE_ARGMAX_HOLD: begin
                argmax_enable <= 1'b0;
                
                if (current_neuron < 6'd9) begin
                    current_neuron <= current_neuron + 1;
                    current_pixel <= 10'd0;
                    
                    
                    output_weight_addr_counter <= output_weight_addr_counter + 1;
                    
                    current_state <= STATE_LOAD;
                end else begin
                    current_state <= STATE_DONE;
                end
            end
            
            STATE_DONE: begin
                argmax_enable <= 1'b0;        
                calculation_done <= 1'b1;     
                
                if (!start_inference) begin
                    current_state <= STATE_IDLE;
                end
            end
            
        endcase
    end
endmodule