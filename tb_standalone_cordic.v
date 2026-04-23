`timescale 1ns/1ps

// Standalone CORDIC test: AXI Master -> AXI Slave -> CORDIC Core
// Tests the full write-poll-read sequence without any CPU involvement.
module tb_standalone_cordic;
    reg clk = 0;
    always #5 clk = ~clk;
    reg reset = 0;

    // AXI bus wires
    wire [31:0] m_awaddr, m_araddr, m_wdata, m_rdata;
    wire [2:0]  m_awprot, m_arprot;
    wire        m_awvalid, m_awready, m_wvalid, m_wready;
    wire [3:0]  m_wstrb;
    wire [1:0]  m_bresp, m_rresp;
    wire        m_bvalid, m_bready;
    wire        m_arvalid, m_arready, m_rvalid, m_rready;

    // Master control signals
    reg         req_enable = 0;
    reg         req_write  = 0;
    reg  [31:0] req_addr   = 0;
    reg  [31:0] req_wdata  = 0;
    reg  [3:0]  req_wstrb  = 4'hF;
    wire        axi_busy;
    wire [31:0] axi_rdata;

    axi4_lite_master MASTER (
        .clk(clk), .reset(reset),
        .req_enable(req_enable), .req_write(req_write),
        .req_addr(req_addr), .req_wdata(req_wdata), .req_wstrb(req_wstrb),
        .axi_busy(axi_busy), .axi_rdata(axi_rdata),
        .m_axi_awaddr(m_awaddr), .m_axi_awprot(m_awprot),
        .m_axi_awvalid(m_awvalid), .m_axi_awready(m_awready),
        .m_axi_wdata(m_wdata), .m_axi_wstrb(m_wstrb),
        .m_axi_wvalid(m_wvalid), .m_axi_wready(m_wready),
        .m_axi_bresp(m_bresp), .m_axi_bvalid(m_bvalid), .m_axi_bready(m_bready),
        .m_axi_araddr(m_araddr), .m_axi_arprot(m_arprot),
        .m_axi_arvalid(m_arvalid), .m_axi_arready(m_arready),
        .m_axi_rdata_in(m_rdata), .m_axi_rresp(m_rresp),
        .m_axi_rvalid(m_rvalid), .m_axi_rready(m_rready)
    );

    axi_cordic_slave SLAVE (
        .clk(clk), .reset(reset),
        .s_axi_awaddr(m_awaddr), .s_axi_awprot(m_awprot),
        .s_axi_awvalid(m_awvalid), .s_axi_awready(m_awready),
        .s_axi_wdata(m_wdata), .s_axi_wstrb(m_wstrb),
        .s_axi_wvalid(m_wvalid), .s_axi_wready(m_wready),
        .s_axi_bresp(m_bresp), .s_axi_bvalid(m_bvalid), .s_axi_bready(m_bready),
        .s_axi_araddr(m_araddr), .s_axi_arprot(m_arprot),
        .s_axi_arvalid(m_arvalid), .s_axi_arready(m_arready),
        .s_axi_rdata(m_rdata), .s_axi_rresp(m_rresp),
        .s_axi_rvalid(m_rvalid), .s_axi_rready(m_rready)
    );

    // Task: Write to a register
    task axi_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            req_enable <= 1; req_write <= 1;
            req_addr <= addr; req_wdata <= data;
            @(posedge clk); // Master sees it in IDLE, starts transaction
            // Wait for busy to assert then deassert
            wait(axi_busy);
            wait(!axi_busy);
            @(posedge clk);
            req_enable <= 0; req_write <= 0;
            @(posedge clk);
        end
    endtask

    // Task: Read from a register, return data
    task axi_read(input [31:0] addr, output [31:0] data);
        begin
            @(posedge clk);
            req_enable <= 1; req_write <= 0;
            req_addr <= addr;
            @(posedge clk);
            wait(axi_busy);
            wait(!axi_busy);
            data = axi_rdata;
            @(posedge clk);
            req_enable <= 0;
            @(posedge clk);
        end
    endtask

    reg [31:0] rdata;
    integer poll_count;

    initial begin
        $display("=== STANDALONE CORDIC TEST ===");
        #20 reset = 1;
        #20;

        // --- TEST 1: sin(90°) = 1.0, cos(90°) = 0.0 ---
        $display("\n--- Test 1: 90 degrees (PI/2 = 0x1921FB54 in Q4.28) ---");
        axi_write(32'h40000000, 32'h1921FB54); // Write angle (offset 0x00)
        
        // Poll STATUS (offset 0x04)
        poll_count = 0;
        rdata = 0;
        while (rdata == 0) begin
            axi_read(32'h40000004, rdata);
            poll_count = poll_count + 1;
            if (poll_count > 100) begin
                $display("ERROR: CORDIC timed out after %0d polls!", poll_count);
                $finish;
            end
        end
        $display("CORDIC done after %0d polls", poll_count);

        // Read results
        axi_read(32'h40000008, rdata); // SINE (offset 0x08)
        $display("  Sine   = 0x%08h (expect ~0x10000000 = 1.0 in Q4.28)", rdata);
        
        axi_read(32'h4000000C, rdata); // COSINE (offset 0x0C)
        $display("  Cosine = 0x%08h (expect ~0x00000000 = 0.0 in Q4.28)", rdata);

        // --- TEST 2: sin(45°) ≈ 0.7071, cos(45°) ≈ 0.7071 ---
        $display("\n--- Test 2: 45 degrees (PI/4 = 0x0C90FDAB in Q4.28) ---");
        axi_write(32'h40000000, 32'h0C90FDAB);
        
        poll_count = 0; rdata = 0;
        while (rdata == 0) begin
            axi_read(32'h40000004, rdata);
            poll_count = poll_count + 1;
            if (poll_count > 100) begin $display("ERROR: timeout!"); $finish; end
        end
        $display("CORDIC done after %0d polls", poll_count);
        
        axi_read(32'h40000008, rdata);
        $display("  Sine   = 0x%08h (expect ~0x0B504F33 = 0.7071 in Q4.28)", rdata);
        axi_read(32'h4000000C, rdata);
        $display("  Cosine = 0x%08h (expect ~0x0B504F33 = 0.7071 in Q4.28)", rdata);

        // --- TEST 3: sin(30°) ≈ 0.5, cos(30°) ≈ 0.8660 ---
        $display("\n--- Test 3: 30 degrees (PI/6 = 0x0860A91C in Q4.28) ---");
        axi_write(32'h40000000, 32'h0860A91C);
        
        poll_count = 0; rdata = 0;
        while (rdata == 0) begin
            axi_read(32'h40000004, rdata);
            poll_count = poll_count + 1;
            if (poll_count > 100) begin $display("ERROR: timeout!"); $finish; end
        end
        $display("CORDIC done after %0d polls", poll_count);
        
        axi_read(32'h40000008, rdata);
        $display("  Sine   = 0x%08h (expect ~0x08000000 = 0.5 in Q4.28)", rdata);
        axi_read(32'h4000000C, rdata);
        $display("  Cosine = 0x%08h (expect ~0x0DDB3D74 = 0.866 in Q4.28)", rdata);

        $display("\n=== CORDIC STANDALONE TESTS COMPLETE ===");
        $finish;
    end
endmodule
