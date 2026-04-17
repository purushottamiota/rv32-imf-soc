`timescale 1ns / 1ps

// Multi-cycle IEEE 754 Single-Precision Floating-Point Multiplier
module fpu_mult(
    input wire clk,
    input wire reset,
    input wire start,
    input wire [31:0] a,
    input wire [31:0] b,
    output reg [31:0] result,
    output reg done
);

    parameter IDLE=0, NORMALIZE=1, PACK=2;
    reg [1:0] state;

    reg sign_res;
    reg [8:0] exp_res;
    reg [47:0] mant_res; // 24x24 = 48 bits
    
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            sign_res <= 0; exp_res <= 0; mant_res <= 0;
        end else begin
            case(state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        if (a[30:0] == 0 || b[30:0] == 0) begin
                            result <= 0;
                            done <= 1;
                        end else begin
                            sign_res <= a[31] ^ b[31];
                            exp_res <= a[30:23] + b[30:23] - 127;
                            mant_res <= {1'b1, a[22:0]} * {1'b1, b[22:0]};
                            state <= NORMALIZE;
                        end
                    end
                end
                
                NORMALIZE: begin
                    if (mant_res[47]) begin
                        mant_res <= mant_res >> 1;
                        exp_res <= exp_res + 1;
                        state <= PACK;
                    end else if (mant_res[46] == 0 && mant_res != 0) begin
                        mant_res <= mant_res << 1;
                        exp_res <= exp_res - 1;
                    end else begin
                        state <= PACK;
                    end
                end
                
                PACK: begin
                    result <= {sign_res, exp_res[7:0], mant_res[45:23]}; 
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
