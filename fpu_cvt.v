`timescale 1ns/1ps

module fpu_cvt (
    input  wire        clk,
    input  wire        reset,
    input  wire        start,
    
    input  wire [31:0] a,
    input  wire        is_unsigned, // 0 for FCVT.W.S (signed), 1 for FCVT.WU.S (unsigned)
    input  wire [2:0]  frm,         // Rounding Mode
    
    output reg  [31:0] result,
    output reg  [4:0]  fflags,
    output reg         ready
);

    wire sign = a[31];
    wire [7:0] exp = a[30:23];
    wire [22:0] frac = a[22:0];

    wire is_nan = (exp == 8'hFF && frac != 0);
    wire is_inf = (exp == 8'hFF && frac == 0);
    wire is_zero = (exp == 8'h00 && frac == 0);

    // True exponent
    wire signed [9:0] true_exp = {2'b0, exp} - 10'd127;
    
    // Shift fraction to integer (add hidden bit)
    wire [55:0] shift_frac = {1'b1, frac, 32'h0};
    
    // Position of the radix point is between shift_frac[32] and shift_frac[31]
    // If true_exp is 0, integer is shift_frac[55] (which is bit 32 of 33-bit integer).
    // We shift right by (23 - true_exp)
    
    integer shift_amt;
    reg [47:0] shifted_val;
    reg sticky;
    reg round_bit;
    
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            result <= 32'h0;
            fflags <= 5'h0;
            ready  <= 1'b0;
        end else if (start) begin
            ready <= 1'b1;
            fflags <= 5'h0;
            
            if (is_nan || is_inf) begin
                fflags[4] <= 1'b1; // NV
                // Standard IEEE to int clamping for NaN/Inf
                if (is_unsigned) begin
                    result <= (is_nan || !sign) ? 32'hFFFF_FFFF : 32'h0000_0000;
                end else begin
                    result <= (is_nan || !sign) ? 32'h7FFF_FFFF : 32'h8000_0000;
                end
            end else if (true_exp >= 10'sd31 || (is_unsigned && true_exp >= 10'sd32)) begin
                // Out of bounds for 32-bit int
                // Edge case: exactly -2^31 is valid for signed
                if (!is_unsigned && sign && true_exp == 10'sd31 && frac == 0) begin
                    result <= 32'h8000_0000;
                end else begin
                    fflags[4] <= 1'b1; // NV
                    if (is_unsigned) begin
                        result <= sign ? 32'h0000_0000 : 32'hFFFF_FFFF;
                    end else begin
                        result <= sign ? 32'h8000_0000 : 32'h7FFF_FFFF;
                    end
                end
            end else if (true_exp < -10'sd1) begin
                // Returns 0 or 1 depending on rounding
                result <= 32'h0;
                if (!is_zero) fflags[0] <= 1'b1; // NX
            end else begin
                shift_amt = 23 - true_exp;
                if (shift_amt >= 0 && shift_amt <= 23) begin
                    shifted_val = {16'h0, 1'b1, frac, 8'h0} >> shift_amt;
                    round_bit = shifted_val[7];
                    sticky = (shifted_val[6:0] != 0);
                    
                    // Simple truncating towards zero
                    result <= sign ? -shifted_val[39:8] : shifted_val[39:8];
                    
                    if (round_bit || sticky) begin
                        fflags[0] <= 1'b1; // NX (Inexact)
                    end
                end else begin
                    shift_amt = true_exp - 23;
                    result <= sign ? -({1'b1, frac} << shift_amt) : ({1'b1, frac} << shift_amt);
                end
            end
        end else begin
            ready <= 1'b0;
        end
    end

endmodule
