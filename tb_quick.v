`timescale 1ns/1ps

module tb_quick_soc;
    reg clk;
    reg reset;

    wire uart_tx;
    wire [15:0] led;

    top_fpga SOC_CORE (
        .clk(clk),
        .reset(reset),
        .uart_rx(1'b1),
        .uart_tx(uart_tx),
        .led(led)
    );

    axi_cordic_slave HW_ACCEL (
        .clk(clk), .reset(reset),
        .s_axi_awaddr(SOC_CORE.m_axi_awaddr), .s_axi_awprot(SOC_CORE.m_axi_awprot),
        .s_axi_awvalid(SOC_CORE.m_axi_awvalid), .s_axi_awready(SOC_CORE.m_axi_awready),
        .s_axi_wdata(SOC_CORE.m_axi_wdata), .s_axi_wstrb(SOC_CORE.m_axi_wstrb),
        .s_axi_wvalid(SOC_CORE.m_axi_wvalid), .s_axi_wready(SOC_CORE.m_axi_wready),
        .s_axi_bresp(SOC_CORE.m_axi_bresp), .s_axi_bvalid(SOC_CORE.m_axi_bvalid),
        .s_axi_bready(SOC_CORE.m_axi_bready),
        .s_axi_araddr(SOC_CORE.m_axi_araddr), .s_axi_arprot(SOC_CORE.m_axi_arprot),
        .s_axi_arvalid(SOC_CORE.m_axi_arvalid), .s_axi_arready(SOC_CORE.m_axi_arready),
        .s_axi_rdata(SOC_CORE.m_axi_rdata), .s_axi_rresp(SOC_CORE.m_axi_rresp),
        .s_axi_rvalid(SOC_CORE.m_axi_rvalid), .s_axi_rready(SOC_CORE.m_axi_rready)
    );

    always #5 clk = ~clk;

    integer cycle_cnt;
    always @(posedge clk) begin
        if (!reset) cycle_cnt <= 0;
        else cycle_cnt <= cycle_cnt + 1;
    end

    // Watch for AXI CORDIC master activity - ONLY print when state changes or is non-idle
    reg [3:0] prev_cord_state;
    always @(posedge clk) begin
        if (reset) begin
            prev_cord_state <= SOC_CORE.axi_master_inst.state;
            
            if (SOC_CORE.axi_master_inst.state != prev_cord_state)
                $display("[C%0d] CORDIC AXI st: %0d->%0d busy=%b req_en=%b wr=%b addr=%h rdata=%h",
                    cycle_cnt, prev_cord_state, SOC_CORE.axi_master_inst.state,
                    SOC_CORE.cordic_busy,
                    SOC_CORE.axi_master_inst.req_enable,
                    SOC_CORE.axi_master_inst.req_write,
                    SOC_CORE.axi_master_inst.req_addr,
                    SOC_CORE.axi_master_inst.axi_rdata);

            // PC progress check every 200k cycles
            if (cycle_cnt % 200000 == 0)
                $display("=== cycle %0d | PC=%h | cord_busy=%b sys_busy=%b ===",
                    cycle_cnt, SOC_CORE.current_pc, SOC_CORE.cordic_busy, SOC_CORE.systolic_busy);
        end
    end

    initial begin
        clk = 0;
        reset = 0;
        cycle_cnt = 0;
        #50 reset = 1;
        force SOC_CORE.cpu_reset = reset;
        
        // 2M cycles = 20ms
        #20000000;
        $display("Sim ended at cycle=%0d PC=%h", cycle_cnt, SOC_CORE.current_pc);
        $finish;
    end
endmodule
