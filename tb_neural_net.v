`timescale 1ns / 1ps

module tb_neural_net();

    
    // 1. MOTHERBOARD WIRES
    
    reg clk;
    reg start_inference;
    reg write_enable;
    reg [9:0] external_addr;
    reg signed [7:0] external_pixel;

    wire calculation_done;
    wire [3:0] final_predicted_digit;

    
    reg [7:0] image_data [0:783]; 

    
    // 2. DROPPING ONTO THE TESTBENCH
    
    neural_net_top uut (
        .clk(clk),
        .start_inference(start_inference),
        .write_enable(write_enable),
        .external_addr(external_addr),
        .external_pixel(external_pixel),
        .calculation_done(calculation_done),
        .final_predicted_digit(final_predicted_digit)
    );

   
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period
    end

    
    // 4. THE MASTER VERIFICATION SEQUENCE
   
    integer i;

    initial begin
        // Step A: Load the image file from your hard drive into testbench memory
        $readmemh("C:/Users/sriri/test_image.hex", image_data);

        // Step B: Power-on Reset State
        start_inference = 0;
        write_enable = 0;
        external_addr = 0;
        external_pixel = 0;
        
        // Let the silicon settle for 10 clock cycles
        #100; 

        $display(" Loading Image into RAM ");

        // Step C: The Loading Phase
        // Flip the hardware MUX so the testbench controls the Image RAM
        write_enable = 1; 
        
        for (i = 0; i < 784; i = i + 1) begin
            @(negedge clk); // Always change inputs on the falling edge to prevent setup/hold violations
            external_addr = i;
            external_pixel = image_data[i];
        end

        // Step D: Disconnect Testbench, Hand Control to FSM
        @(negedge clk);
        write_enable = 0; 
        
        #20;

        // Step E: Trigger the Brain
        $display("INFERENCE STARTED: Waking up FSM");
        @(negedge clk);
        start_inference = 1; // Press the ignition button
        @(negedge clk);
        start_inference = 0; // Release the button

        // Step F: Wait for the Chip to Finish
        // The testbench will pause on this line until the FSM asserts calculation_done
        wait (calculation_done == 1'b1);

        // Step G: Read the Results
       
        $display("INFERENCE COMPLETE!");
        $display("Predicted Digit: %d", final_predicted_digit);
       

        // End simulation
        #50;
        $finish;
    end

endmodule