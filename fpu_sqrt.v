`timescale 1ns / 1ps

// Multi-cycle IEEE 754 Single-Precision Floating-Point Square Root
module fpu_sqrt(
    input wire clk,
    input wire reset,
    
    input wire start,
    input wire [31:0] a,
    
    output reg [31:0] result,
    output reg done
);

    localparam IDLE=0, SQRT=1, NORMALIZE=2, PACK=3;
    reg [1:0] state;

    reg sign_res;
    reg [8:0] exp_res;
    
    reg [51:0] N;
    reg [25:0] Q;
    reg [27:0] rem;
    reg [5:0] count;
    
    wire signed [9:0] exp_in_s = {2'b0, a[30:23]};
    wire signed [9:0] exp_out_even = ((exp_in_s - 128) >>> 1) + 127;
    wire signed [9:0] exp_out_odd  = ((exp_in_s - 127) >>> 1) + 127;

    wire [27:0] new_rem = {rem[25:0], N[51:50]};
    wire [27:0] test_res = {Q, 2'b01};
    wire        sub_ok = (new_rem >= test_res);

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            sign_res <= 0;
            exp_res <= 0;
            N <= 0;
            Q <= 0;
            rem <= 0;
            count <= 0;
        end else begin
            case(state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        if (a[31] && a[30:0] != 0) begin // negative -> NaN
                            result <= 32'h7FC00000;
                            done <= 1;
                        end else if (a[30:0] == 0) begin // zero
                            result <= a; // preserve sign
                            done <= 1;
                        end else begin
                            sign_res <= a[31];
                            
                            if (a[23] == 0) begin // Exponent is even
                                exp_res <= exp_out_even[8:0];
                                N <= {1'b1, a[22:0], 28'b0};
                            end else begin
                                exp_res <= exp_out_odd[8:0];
                                N <= {1'b0, 1'b1, a[22:0], 27'b0};
                            end
                            
                            Q <= 0;
                            rem <= 0;
                            count <= 26;
                            state <= SQRT;
                        end
                    end
                end
                
                SQRT: begin
                    if (count > 0) begin
                        if (sub_ok) begin
                            rem <= new_rem - test_res;
                            Q   <= {Q[24:0], 1'b1};
                        end else begin
                            rem <= new_rem;
                            Q   <= {Q[24:0], 1'b0};
                        end
                        N <= {N[49:0], 2'b00};
                        count <= count - 1;
                    end else begin
                        state <= NORMALIZE;
                    end
                end
                
                NORMALIZE: begin
                    // Q is in Q[25:0]. 
                    // Square root of [1.0, 4.0) is in [1.0, 2.0). 
                    // Thus Q[25] should ALWAYS be 1 if Q is properly calculated!
                    if (Q[25]) begin
                        state <= PACK;
                    end else if (Q[24]) begin
                        // Edge case mitigation (shouldn't realistically happen due to math)
                        Q <= Q << 1;
                        exp_res <= exp_res - 1;
                        state <= PACK;
                    end else begin
                        state <= PACK;
                    end
                end
                
                PACK: begin
                    // Q[25] is implicit 1
                    // Q[24:2] are the 23 mantissa bits
                    if ($signed(exp_res) <= 0) begin // underflow
                        result <= {sign_res, 31'b0};
                    end else if (exp_res >= 255) begin // overflow
                        result <= {sign_res, 8'hFF, 23'b0};
                    end else begin
                        result <= {sign_res, exp_res[7:0], Q[24:2]};
                    end
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
