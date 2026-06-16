`timescale 1ns/1ps

module tb_compare_test;
    reg clk;
    reg reset;
    
    reg [31:0] a;
    reg [31:0] b;
    reg [4:0]  funct5;
    reg [2:0]  funct3;
    reg [4:0]  rs2_sel;
    reg        fp_en;
    
    wire [31:0] result;
    
    fpu uut (
        .clk(clk),
        .reset(reset),
        .a(a),
        .b(b),
        .funct5(funct5),
        .funct3(funct3),
        .rs2_sel(rs2_sel),
        .fp_en(fp_en),
        .result(result)
    );
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        reset = 0;
        fp_en = 0;
        a = 0;
        b = 0;
        funct5 = 5'b10100; // FCMP_S
        funct3 = 0;
        rs2_sel = 0;
        #20;
        reset = 1;
        #20;
        
        fp_en = 1;
        
        $display("--- Floating Point Comparison Test ---");
        
        // Test 1: +0.0 == -0.0
        // +0.0 = 0x00000000, -0.0 = 0x80000000
        a = 32'h00000000;
        b = 32'h80000000;
        funct3 = 3'b010; // FEQ.S
        #10;
        $display("Test 1: +0.0 == -0.0 (FEQ.S): Result = %0d (Expected: 1)", result[0]);
        
        // Test 2: -2.0 < -1.0
        // -2.0 = 0xC0000000, -1.0 = 0xBF800000
        a = 32'hC0000000;
        b = 32'hBF800000;
        funct3 = 3'b001; // FLT.S
        #10;
        $display("Test 2: -2.0 < -1.0 (FLT.S): Result = %0d (Expected: 1)", result[0]);

        // Test 3: -1.0 < -2.0
        a = 32'hBF800000;
        b = 32'hC0000000;
        funct3 = 3'b001; // FLT.S
        #10;
        $display("Test 3: -1.0 < -2.0 (FLT.S): Result = %0d (Expected: 0)", result[0]);
        
        // Test 4: 1.5 < 2.5
        // 1.5 = 0x3FC00000, 2.5 = 0x40200000
        a = 32'h3FC00000;
        b = 32'h40200000;
        funct3 = 3'b001; // FLT.S
        #10;
        $display("Test 4: 1.5 < 2.5 (FLT.S): Result = %0d (Expected: 1)", result[0]);

        // Test 5: 2.5 <= 2.5
        a = 32'h40200000;
        b = 32'h40200000;
        funct3 = 3'b000; // FLE.S
        #10;
        $display("Test 5: 2.5 <= 2.5 (FLE.S): Result = %0d (Expected: 1)", result[0]);

        // Test 6: -2.5 <= -1.5
        // -2.5 = 0xC0200000, -1.5 = 0xBFC00000
        a = 32'hC0200000;
        b = 32'hBFC00000;
        funct3 = 3'b000; // FLE.S
        #10;
        $display("Test 6: -2.5 <= -1.5 (FLE.S): Result = %0d (Expected: 1)", result[0]);

        // Test 7: -1.5 <= -2.5
        a = 32'hBFC00000;
        b = 32'hC0200000;
        funct3 = 3'b000; // FLE.S
        #10;
        $display("Test 7: -1.5 <= -2.5 (FLE.S): Result = %0d (Expected: 0)", result[0]);
        
        $finish;
    end
endmodule
