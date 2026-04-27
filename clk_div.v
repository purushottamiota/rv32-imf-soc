`timescale 1ns / 1ps

module clk_div (
    input  wire clk_in,   // 100MHz from the board
    input  wire reset,    // Active-high reset
    output wire clk_out   // 50MHz output
);

    reg toggle_reg = 1'b0;

    // Toggle the register on every rising edge of the 100MHz clock
    always @(posedge clk_in or posedge reset) begin
        if (reset) begin
            toggle_reg <= 1'b0;
        end else begin
            toggle_reg <= ~toggle_reg;
        end
    end

    // XILINX SPECIFIC: Force the signal onto the global clock tree
    BUFG bufg_inst (
        .I(toggle_reg),
        .O(clk_out)
    );

endmodule