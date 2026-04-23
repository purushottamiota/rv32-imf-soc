`timescale 1ns/1ps

// Standalone AXI Master + CORDIC Slave testbench
// Drives the AXI master directly (no pipeline, no UART) to verify:
//   1. Write transaction delivers angle to CORDIC
//   2. STATUS read correctly polls latched_valid
//   3. SINE read returns correct value
//   4. COSINE read returns correct value
//   5. Back-to-back transactions (same bus, different addresses) work

module tb_axi_master;

    reg clk, reset;

    // CPU interface
    reg        req_enable;
    reg        req_write;
    reg [31:0] req_addr;
    reg [31:0] req_wdata;
    reg [3:0]  req_wstrb;
    wire       axi_busy;
    wire [31:0] axi_rdata;

    // AXI bus wires
    wire [31:0] m_awaddr;
    wire [2:0]  m_awprot;
    wire        m_awvalid, m_awready;
    wire [31:0] m_wdata;
    wire [3:0]  m_wstrb;
    wire        m_wvalid, m_wready;
    wire [1:0]  m_bresp;
    wire        m_bvalid, m_bready;
    wire [31:0] m_araddr;
    wire [2:0]  m_arprot;
    wire        m_arvalid, m_arready;
    wire [31:0] m_rdata;
    wire [1:0]  m_rresp;
    wire        m_rvalid, m_rready;

    // ---- DUT: AXI Master ----
    axi4_lite_master DUT (
        .clk(clk), .reset(reset),
        .req_enable(req_enable), .req_write(req_write),
        .req_addr(req_addr), .req_wdata(req_wdata), .req_wstrb(req_wstrb),
        .axi_busy(axi_busy), .axi_rdata(axi_rdata),
        .m_axi_awaddr(m_awaddr),   .m_axi_awprot(m_awprot),
        .m_axi_awvalid(m_awvalid), .m_axi_awready(m_awready),
        .m_axi_wdata(m_wdata),     .m_axi_wstrb(m_wstrb),
        .m_axi_wvalid(m_wvalid),   .m_axi_wready(m_wready),
        .m_axi_bresp(m_bresp),     .m_axi_bvalid(m_bvalid),
        .m_axi_bready(m_bready),   .m_axi_araddr(m_araddr),
        .m_axi_arprot(m_arprot),   .m_axi_arvalid(m_arvalid),
        .m_axi_arready(m_arready), .m_axi_rdata_in(m_rdata),
        .m_axi_rresp(m_rresp),     .m_axi_rvalid(m_rvalid),
        .m_axi_rready(m_rready)
    );

    // ---- DUT: CORDIC Slave ----
    axi_cordic_slave SLAVE (
        .clk(clk), .reset(reset),
        .s_axi_awaddr(m_awaddr),   .s_axi_awprot(m_awprot),
        .s_axi_awvalid(m_awvalid), .s_axi_awready(m_awready),
        .s_axi_wdata(m_wdata),     .s_axi_wstrb(m_wstrb),
        .s_axi_wvalid(m_wvalid),   .s_axi_wready(m_wready),
        .s_axi_bresp(m_bresp),     .s_axi_bvalid(m_bvalid),
        .s_axi_bready(m_bready),   .s_axi_araddr(m_araddr),
        .s_axi_arprot(m_arprot),   .s_axi_arvalid(m_arvalid),
        .s_axi_arready(m_arready), .s_axi_rdata(m_rdata),
        .s_axi_rresp(m_rresp),     .s_axi_rvalid(m_rvalid),
        .s_axi_rready(m_rready)
    );

    // Clock: 10ns period
    always #5 clk = ~clk;

    // Helper: drive a single AXI transaction and wait for it to complete.
    // Models real pipeline: req_enable=1 while stalled, drops on the one cycle
    // axi_busy=0 (pipeline advances), then stays 0 (non-memory instruction in MEM).
    task drive_req;
        input        is_write;
        input [31:0] addr;
        input [31:0] wdata;
        begin
            @(posedge clk); #1;
            req_enable = 1;
            req_write  = is_write;
            req_addr   = addr;
            req_wdata  = wdata;
            req_wstrb  = 4'hF;

            // Wait until axi_busy de-asserts (transaction complete OR latched).
            // axi_busy = 0 means req_latched=1 and state=IDLE — this is the
            // one cycle where the real pipeline advances to the next instruction.
            @(negedge axi_busy);  // wait for falling edge of busy

            // On this cycle, axi_rdata holds the valid read result.
            // Deassert immediately — next cycle a different instruction is in MEM.
            #1;
            req_enable = 0;
            req_write  = 0;
            @(posedge clk); #1; // Let req_latched clear propagate
        end
    endtask

    integer PASS = 0, FAIL = 0;
    task check;
        input [127:0] test_name;
        input [31:0]  got;
        input [31:0]  expected;
        begin
            if (got === expected) begin
                $display("  PASS: %0s | got=%h", test_name, got);
                PASS = PASS + 1;
            end else begin
                $display("  FAIL: %0s | got=%h  expected=%h", test_name, got, expected);
                FAIL = FAIL + 1;
            end
        end
    endtask

    // PI/2 in Q4.28 = 0x1921FB54
    localparam [31:0] ANGLE_90  = 32'h1921FB54;
    localparam [31:0] ANGLE_45  = 32'h0C90FDAB;

    localparam [31:0] CORDIC_ANGLE  = 32'h40000000;
    localparam [31:0] CORDIC_STATUS = 32'h40000004;
    localparam [31:0] CORDIC_SINE   = 32'h40000008;
    localparam [31:0] CORDIC_COSINE = 32'h4000000C;

    reg [31:0] status_val, sin_val, cos_val;

    initial begin
        clk = 0; reset = 0;
        req_enable = 0; req_write = 0;
        req_addr = 0; req_wdata = 0; req_wstrb = 0;

        #20 reset = 1;
        #20;

        $display("\n=== AXI Master Standalone Verification ===");

        // ---- Test 1: Write angle=PI/2=90 degrees ----
        $display("\n[TEST 1] Writing CORDIC_ANGLE = PI/2 (90 deg)...");
        drive_req(1, CORDIC_ANGLE, ANGLE_90);
        $display("  Write transaction complete (angle=%h)", ANGLE_90);

        // ---- Test 2: Poll STATUS until done (CORDIC takes ~35 cycles) ----
        $display("[TEST 2] Polling CORDIC_STATUS...");
        status_val = 0;
        while (status_val === 0) begin
            drive_req(0, CORDIC_STATUS, 0);
            status_val = axi_rdata;
            $display("  STATUS poll: got=%h", status_val);
        end
        $display("  CORDIC done! status=%h", status_val);

        // ---- Test 3: Read SINE ----
        $display("[TEST 3] Reading CORDIC_SINE...");
        drive_req(0, CORDIC_SINE, 0);
        sin_val = axi_rdata;
        $display("  SIN = %h (expected ~0x10000000 for 90 deg)", sin_val);

        // ---- Test 4: Read COSINE ----
        $display("[TEST 4] Reading CORDIC_COSINE...");
        drive_req(0, CORDIC_COSINE, 0);
        cos_val = axi_rdata;
        $display("  COS = %h (expected ~0x00000000 for 90 deg)", cos_val);

        // Check results (sin(90) ~ 1.0, cos(90) ~ 0.0 in Q4.28)
        // sin(90) = 1.0 = 0x10000000, cos(90) = 0.0 = 0x00000000
        $display("\n--- 90-degree Results ---");
        if (sin_val[31:24] === 8'h10)
            $display("  PASS: SIN 90deg (got %h, ~1.0 Q4.28)", sin_val);
        else
            $display("  FAIL: SIN 90deg (got %h, expected ~0x10000000)", sin_val);

        if (cos_val[31:16] === 16'h0000)
            $display("  PASS: COS 90deg is near zero (got %h)", cos_val);
        else
            $display("  FAIL: COS 90deg (got %h, expected ~0x00000000)", cos_val);

        // ---- Test 5: 45-degree test (sin==cos==0.7071) ----
        $display("\n[TEST 5] Writing CORDIC_ANGLE = PI/4 (45 deg)...");
        drive_req(1, CORDIC_ANGLE, ANGLE_45);
        status_val = 0;
        while (status_val === 0) begin
            drive_req(0, CORDIC_STATUS, 0);
            status_val = axi_rdata;
        end
        drive_req(0, CORDIC_SINE, 0);
        sin_val = axi_rdata;
        drive_req(0, CORDIC_COSINE, 0);
        cos_val = axi_rdata;
        $display("  45deg: SIN=%h  COS=%h", sin_val, cos_val);
        // sin(45) = cos(45) = 0.7071 ≈ 0x0B504F33
        if (sin_val[31:8] === cos_val[31:8])
            $display("  PASS: SIN 45 == COS 45 (both should be ~0x0B504F33)");
        else
            $display("  FAIL: SIN 45 != COS 45 (sin=%h cos=%h)", sin_val, cos_val);

        #50;
        $display("\n=== SIMULATION COMPLETE ===\n");
        $finish;
    end

    // Timeout watchdog
    initial begin
        #200000;
        $display("TIMEOUT - simulation stalled!");
        $finish;
    end

endmodule
