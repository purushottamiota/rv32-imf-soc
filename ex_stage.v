`timescale 1ns/1ps

module ex_stage (
    input  wire [31:0] pc_i,
    input  wire [31:0] immediate_i,
    input  wire [31:0] reg_rdata1_i,
    input  wire [31:0] reg_rdata2_i,
    input  wire [2:0]  alu_op_i,

    input  wire        immediate_sel_i,
    input  wire        alu_i,
    input  wire        lui_i,
    input  wire        jal_i,
    input  wire        jalr_i,
    input  wire        branch_i,
    input  wire        arithsubtype_i,

    // Forwarding logic
    input  wire [1:0]  forward_a,
    input  wire [1:0]  forward_b,
    input  wire [31:0] forward_ex_mem_val,
    input  wire [31:0] forward_mem_wb_val,

    // Outputs
    output reg  [31:0] ex_result,
    output wire [31:0] write_data_out, // the value to be stored in mem
    output reg         branch_taken,
    output reg  [31:0] branch_target
);

    `include "opcode.vh"

    // ----------------------------------------------------
    // Forwarding Muxes
    // ----------------------------------------------------
    reg [31:0] fw_operand1;
    reg [31:0] fw_operand2;

    always @(*) begin
        case (forward_a)
            2'b00: fw_operand1 = reg_rdata1_i;
            2'b01: fw_operand1 = forward_mem_wb_val;
            2'b10: fw_operand1 = forward_ex_mem_val;
            default: fw_operand1 = reg_rdata1_i;
        endcase

        case (forward_b)
            2'b00: fw_operand2 = reg_rdata2_i;
            2'b01: fw_operand2 = forward_mem_wb_val;
            2'b10: fw_operand2 = forward_ex_mem_val;
            default: fw_operand2 = reg_rdata2_i;
        endcase
    end

    // The data to store is the pure forwarded reg2 value
    assign write_data_out = fw_operand2;

    wire [31:0] alu_operand1 = fw_operand1;
    wire [31:0] alu_operand2 = immediate_sel_i ? immediate_i : fw_operand2;

    // ----------------------------------------------------
    // Calculate next PC / branch
    // ----------------------------------------------------
    always @(*) begin
        branch_taken  = 1'b0;
        branch_target = 32'h0;

        if (jal_i) begin
            branch_taken  = 1'b1;
            branch_target = pc_i + immediate_i;
        end
        else if (jalr_i) begin
            branch_taken  = 1'b1;
            branch_target = (alu_operand1 + immediate_i) & ~32'd1;
        end
        else if (branch_i) begin
            branch_target = pc_i + immediate_i;
            case (alu_op_i)
                BEQ:  branch_taken = (alu_operand1 == alu_operand2);
                BNE:  branch_taken = (alu_operand1 != alu_operand2);
                BLT:  branch_taken = ($signed(alu_operand1) < $signed(alu_operand2));
                BGE:  branch_taken = ($signed(alu_operand1) >= $signed(alu_operand2));
                BLTU: branch_taken = (alu_operand1 < alu_operand2);
                BGEU: branch_taken = (alu_operand1 >= alu_operand2);
                default: branch_taken = 1'b0;
            endcase
        end
    end

    // ----------------------------------------------------
    // ALU functionality
    // ----------------------------------------------------
    // We are maintaining a clean switch/case so a multiplier
    // or divider state machine could be easily spliced here later.
    always @(*) begin
        ex_result = 32'hx;

        if (jal_i || jalr_i) begin
            ex_result = pc_i + 4; // return address
        end
        else if (lui_i) begin
            ex_result = immediate_i;
        end
        else if (alu_i) begin
            case (alu_op_i)
                ADD: ex_result = arithsubtype_i ? alu_operand1 - alu_operand2 : alu_operand1 + alu_operand2;
                SLL: ex_result = alu_operand1 << alu_operand2[4:0];
                SLT: ex_result = {31'b0, $signed(alu_operand1) < $signed(alu_operand2)};
                SLTU: ex_result = {31'b0, alu_operand1 < alu_operand2};
                XOR: ex_result = alu_operand1 ^ alu_operand2;
                SR:  ex_result = arithsubtype_i ? $signed(alu_operand1) >>> alu_operand2[4:0] : alu_operand1 >> alu_operand2[4:0];
                OR:  ex_result = alu_operand1 | alu_operand2;
                AND: ex_result = alu_operand1 & alu_operand2;
                default: ex_result = 32'hx;
            endcase
        end
        else begin
            // For LOAD, STORE, AUIPC, or undefined:
            // Calculate sum for memory address or bounds
            ex_result = alu_operand1 + immediate_i;
        end
    end

endmodule
