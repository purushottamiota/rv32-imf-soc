`timescale 1ns/1ps

module fpu_cmp (
    input  wire        clk,
    input  wire        reset,
    input  wire        start,
    
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [1:0]  cmp_op, // 00: FLE.S, 01: FLT.S, 10: FEQ.S
    
    output reg  [31:0] result,
    output reg  [4:0]  fflags,
    output reg         ready
);

    wire a_sign = a[31];
    wire b_sign = b[31];
    wire [7:0] a_exp = a[30:23];
    wire [7:0] b_exp = b[30:23];
    wire [22:0] a_frac = a[22:0];
    wire [22:0] b_frac = b[22:0];

    wire a_is_nan = (a_exp == 8'hFF && a_frac != 0);
    wire b_is_nan = (b_exp == 8'hFF && b_frac != 0);
    wire a_is_snan = a_is_nan && !a_frac[22];
    wire b_is_snan = b_is_nan && !b_frac[22];
    wire has_nan = a_is_nan || b_is_nan;
    wire has_snan = a_is_snan || b_is_snan;

    wire a_is_zero = (a_exp == 0 && a_frac == 0);
    wire b_is_zero = (b_exp == 0 && b_frac == 0);
    wire both_zero = a_is_zero && b_is_zero;

    // Magnitude Comparison
    wire a_lt_b_mag = (a[30:0] < b[30:0]);
    wire a_eq_b_mag = (a[30:0] == b[30:0]);

    // Signed comparison
    wire a_eq_b = both_zero || (a_sign == b_sign && a_eq_b_mag);
    wire a_lt_b = (!both_zero) && (
                  (a_sign && !b_sign) ||
                  (a_sign && b_sign && !a_lt_b_mag && !a_eq_b_mag) ||
                  (!a_sign && !b_sign && a_lt_b_mag)
                 );

    wire a_le_b = a_lt_b || a_eq_b;

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            result <= 32'h0;
            fflags <= 5'h0;
            ready  <= 1'b0;
        end else if (start) begin
            ready <= 1'b1;
            
            // Default no exception
            fflags <= 5'h0;
            
            if (has_nan) begin
                result <= 32'h0;
                // FEQ sets NV only on sNaN. FLT/FLE sets NV on any NaN.
                if (cmp_op == 2'b10) begin
                    if (has_snan) fflags[4] <= 1'b1; // NV
                end else begin
                    fflags[4] <= 1'b1; // NV
                end
            end else begin
                case (cmp_op)
                    2'b00: result <= {31'h0, a_le_b}; // FLE.S
                    2'b01: result <= {31'h0, a_lt_b}; // FLT.S
                    2'b10: result <= {31'h0, a_eq_b}; // FEQ.S
                    default: result <= 32'h0;
                endcase
            end
        end else begin
            ready <= 1'b0;
        end
    end

endmodule
