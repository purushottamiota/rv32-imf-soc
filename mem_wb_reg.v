`timescale 1ns/1ps

module mem_wb_reg (
    input  wire        clk,
    input  wire        reset,
    
    // Data inputs
    input  wire [31:0] ex_result_i,
    
    // Control inputs
    input  wire [4:0]  dest_reg_sel_i,
    input  wire        mem_to_reg_i,
    input  wire        alu_to_reg_i,
    input  wire [2:0]  alu_op_i, // Load type
    input  wire [1:0]  mem_read_address_offset_i, // 2 LSB bits of addr
    input  wire        stall,

    // Outputs
    output reg  [31:0] ex_result_o,
    output reg  [4:0]  dest_reg_sel_o,
    output reg         mem_to_reg_o,
    output reg         alu_to_reg_o,
    output reg  [2:0]  alu_op_o,
    output reg  [1:0]  mem_read_address_offset_o
);

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            ex_result_o               <= 32'h0;
            dest_reg_sel_o            <= 5'h0;
            mem_to_reg_o              <= 1'b0;
            alu_to_reg_o              <= 1'b0;
            alu_op_o                  <= 3'h0;
            mem_read_address_offset_o <= 2'h0;
        end
        else if (!stall) begin
            ex_result_o               <= ex_result_i;
            dest_reg_sel_o            <= dest_reg_sel_i;
            mem_to_reg_o              <= mem_to_reg_i;
            alu_to_reg_o              <= alu_to_reg_i;
            alu_op_o                  <= alu_op_i;
            mem_read_address_offset_o <= mem_read_address_offset_i;
        end
    end

endmodule
