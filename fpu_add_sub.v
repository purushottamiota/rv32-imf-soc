`timescale 1ns / 1ps

// Multi-cycle IEEE 754 Single-Precision Floating-Point Adder/Subtractor
module fpu_add_sub(
    input wire clk,
    input wire reset,
    input wire start,
    input wire is_sub, // 0 for add, 1 for sub
    input wire [31:0] a,
    input wire [31:0] b,
    output reg [31:0] result,
    output reg done
);

    parameter IDLE=0, ALIGN=1, ADD=2, NORMALIZE=3, PACK=4;
    reg [2:0] state;

    reg sign_a, sign_b;
    reg [7:0] exp_a, exp_b;
    reg [24:0] mant_a, mant_b; // 24 bits + 1 overflow bit
    
    reg sign_res;
    reg [7:0] exp_res;
    reg [24:0] mant_res;
    
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            sign_a <= 0; sign_b <= 0; exp_a <= 0; exp_b <= 0; mant_a <= 0; mant_b <= 0;
            sign_res <= 0; exp_res <= 0; mant_res <= 0;
        end else begin
            case(state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        sign_a <= a[31];
                        exp_a <= a[30:23];
                        mant_a <= (a[30:23] == 0) ? {2'b00, a[22:0]} : {2'b01, a[22:0]};
                        
                        sign_b <= b[31] ^ is_sub;
                        exp_b <= b[30:23];
                        mant_b <= (b[30:23] == 0) ? {2'b00, b[22:0]} : {2'b01, b[22:0]};
                        
                        // Shortcut for zero
                        if (a[30:0] == 0) begin
                            result <= {b[31] ^ is_sub, b[30:0]};
                            done <= 1;
                        end else if (b[30:0] == 0) begin
                            result <= a;
                            done <= 1;
                        end else begin
                            state <= ALIGN;
                        end
                    end
                end
                
                ALIGN: begin
                    if (exp_a > exp_b) begin
                        exp_b <= exp_b + 1;
                        mant_b <= mant_b >> 1;
                    end else if (exp_a < exp_b) begin
                        exp_a <= exp_a + 1;
                        mant_a <= mant_a >> 1;
                    end else begin
                        exp_res <= exp_a;
                        state <= ADD;
                    end
                end
                
                ADD: begin
                    if (sign_a == sign_b) begin
                        mant_res <= mant_a + mant_b;
                        sign_res <= sign_a;
                    end else begin
                        if (mant_a >= mant_b) begin
                            mant_res <= mant_a - mant_b;
                            sign_res <= sign_a;
                        end else begin
                            mant_res <= mant_b - mant_a;
                            sign_res <= sign_b;
                        end
                    end
                    state <= NORMALIZE;
                end
                
                NORMALIZE: begin
                    if (mant_res[24]) begin
                        mant_res <= mant_res >> 1;
                        exp_res <= exp_res + 1;
                        state <= PACK;
                    end else if (mant_res[23] == 0 && mant_res != 0) begin
                        mant_res <= mant_res << 1;
                        exp_res <= exp_res - 1;
                    end else begin
                        state <= PACK;
                    end
                end
                
                PACK: begin
                    if (mant_res == 0) begin
                        result <= 0;
                    end else begin
                        result <= {sign_res, exp_res, mant_res[22:0]};
                    end
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
