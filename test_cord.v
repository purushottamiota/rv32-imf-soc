module tb_cord_verif;
reg clk = 0;
always #5 clk = ~clk;
reg reset = 0;
reg start = 0;
reg [31:0] target_angle = 32'h1921FB54;
wire valid_out;
wire [31:0] sin_out, cos_out;

cordic_iterative dut(
    .clk(clk),
    .reset(reset),
    .start(start),
    .target_angle(target_angle),
    .valid_out(valid_out),
    .sin_out(sin_out),
    .cos_out(cos_out)
);

initial begin
    #10 reset = 1;
    #10 start = 1;
    #10 start = 0;
    wait(valid_out);
    #10;
    $display("Sin: %x, Cos: %x", sin_out, cos_out);
    $finish;
end
endmodule
