`timescale 1ns / 1ps

module tb_fdiv;

    reg clk;
    reg rst;
    reg fp_en;
    reg [31:0] a;
    reg [31:0] b;
    reg [2:0] funct3;
    reg [4:0] rs2_sel;
    reg [4:0] funct5;
    
    wire [31:0] result;
    wire stall_fpu;
    wire fpu_exception;
    
    fpu uut (
        .clk(clk),
        .reset(rst),
        .a(a),
        .b(b),
        .funct5(funct5),
        .funct3(funct3),
        .rs2_sel(rs2_sel),
        .fp_en(fp_en),
        .result(result),
        .stall_fpu(stall_fpu),
        .fpu_exception(fpu_exception)
    );

    always #5 clk = ~clk;

    initial begin
        // Initialize Inputs
        clk = 0;
        fp_en = 0;
        a = 0;
        b = 0;
        funct3 = 0;
        rs2_sel = 0;
        funct5 = 0;
        rst = 0;

        // Reset
        #20;
        rst = 1;
        
        // Wait for IDLE
        #20;

        // Test FDIV_S: 3.50 / 0.50
        // a = 3.50 = 0x40600000
        // b = 0.50 = 0x3F000000
        // expected result = 7.0 = 0x40E00000
        
        $display("Starting FDIV_S Test: 3.50 / 0.50");
        a = 32'h40600000;
        b = 32'h3F000000;
        funct5 = 5'b00011; // FDIV_S
        fp_en = 1;
        
        #10;
        fp_en = 0;
        
        // Wait for computation to finish (FPU state machine will return to IDLE)
        // Wait approx 40 clock cycles for division
        #400;
        
        $display("Result: %h", result);
        if (result == 32'h40E00000) begin
            $display("Test PASSED");
        end else begin
            $display("Test FAILED");
        end

        // Additional test: 5.25 / 1.75 = 3.0 (0x40400000)
        // a = 5.25 = 0x40A80000
        // b = 1.75 = 0x3FE00000
        $display("Starting FDIV_S Test: 5.25 / 1.75");
        a = 32'h40A80000;
        b = 32'h3FE00000;
        funct5 = 5'b00011; // FDIV_S
        fp_en = 1;
        
        #10;
        fp_en = 0;
        
        #400;
        $display("Result: %h", result);
        if (result == 32'h40400000) begin
            $display("Test PASSED");
        end else begin
            $display("Test FAILED");
        end
        $finish;
    end

    always @(posedge clk) begin
        $display("time=%0t state=%d iter_count=%d iter_acc=%x div_upper=%x iter_div=%x div_sub_ok=%b mant_res=%x exp_res=%d result=%x", 
                 $time, uut.state, uut.iter_count, uut.iter_acc, uut.div_upper, uut.iter_div, uut.div_sub_ok, uut.mant_res, uut.exp_res, result);
    end

endmodule
