`timescale 1ns/1ps

module axi4_lite_master (
    input  wire        clk,
    input  wire        reset,

    // CPU Interface
    input  wire        req_enable,   // is_axi_addr && (dmem_read_ready || dmem_write_ready)
    input  wire        req_write,    // 1 for Write, 0 for Read
    input  wire [31:0] req_addr,
    input  wire [31:0] req_wdata,
    input  wire [3:0]  req_wstrb,
    output wire        axi_busy,
    output reg  [31:0] axi_rdata,

    // AXI4-Lite Master Interface
    output reg  [31:0] m_axi_awaddr,
    output wire [2:0]  m_axi_awprot,
    output reg         m_axi_awvalid,
    input  wire        m_axi_awready,
    
    output reg  [31:0] m_axi_wdata,
    output reg  [3:0]  m_axi_wstrb,
    output reg         m_axi_wvalid,
    input  wire        m_axi_wready,
    
    input  wire [1:0]  m_axi_bresp,
    input  wire        m_axi_bvalid,
    output reg         m_axi_bready,
    
    output reg  [31:0] m_axi_araddr,
    output wire [2:0]  m_axi_arprot,
    output reg         m_axi_arvalid,
    input  wire        m_axi_arready,
    
    input  wire [31:0] m_axi_rdata_in,
    input  wire [1:0]  m_axi_rresp,
    input  wire        m_axi_rvalid,
    output reg         m_axi_rready
);

    assign m_axi_awprot = 3'b000;
    assign m_axi_arprot = 3'b000;

    localparam STATE_IDLE  = 3'd0;
    localparam STATE_WADDR = 3'd1;
    localparam STATE_BRESP = 3'd2;
    localparam STATE_RADDR = 3'd3;
    localparam STATE_RDATA = 3'd4;
    localparam STATE_DONE  = 3'd5;

    reg [2:0] state;
    reg aw_done, w_done; 

    // CPU stalls while the state machine is active (but not once it's completely done)
    assign axi_busy = req_enable && (state != STATE_DONE);

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            state <= STATE_IDLE;
            m_axi_awvalid <= 0;
            m_axi_wvalid  <= 0;
            m_axi_bready  <= 0;
            m_axi_arvalid <= 0;
            m_axi_rready  <= 0;
            aw_done       <= 0;
            w_done        <= 0;
            axi_rdata     <= 0;
            
            m_axi_awaddr <= 0;
            m_axi_wdata  <= 0;
            m_axi_wstrb  <= 0;
            m_axi_araddr <= 0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (req_enable) begin
                        if (req_write) begin
                            state <= STATE_WADDR;
                            m_axi_awaddr  <= req_addr;
                            m_axi_wdata   <= req_wdata;
                            m_axi_wstrb   <= req_wstrb;
                            m_axi_awvalid <= 1;
                            m_axi_wvalid  <= 1;
                            m_axi_bready  <= 1;
                            aw_done       <= 0;
                            w_done        <= 0;
                        end else begin
                            state <= STATE_RADDR;
                            m_axi_araddr  <= req_addr;
                            m_axi_arvalid <= 1;
                            m_axi_rready  <= 1;
                        end
                    end
                end

                STATE_WADDR: begin
                    // Handle parallel AW and W handshakes natively
                    if (m_axi_awready && m_axi_awvalid) begin
                        m_axi_awvalid <= 0;
                        aw_done <= 1;
                    end
                    if (m_axi_wready && m_axi_wvalid) begin
                        m_axi_wvalid <= 0;
                        w_done <= 1;
                    end
                    
                    if ((aw_done || (m_axi_awready && m_axi_awvalid)) && 
                        (w_done  || (m_axi_wready && m_axi_wvalid))) begin
                        state <= STATE_BRESP;
                    end
                end

                STATE_BRESP: begin
                    if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_bready <= 0;
                        state <= STATE_DONE;
                    end
                end

                STATE_RADDR: begin
                    if (m_axi_arready && m_axi_arvalid) begin
                        m_axi_arvalid <= 0;
                        state <= STATE_RDATA;
                    end
                end

                STATE_RDATA: begin
                    // Wait for Master Read Data to return
                    if (m_axi_rvalid && m_axi_rready) begin
                        axi_rdata <= m_axi_rdata_in;
                        m_axi_rready <= 0;
                        state <= STATE_DONE;
                    end
                end

                STATE_DONE: begin
                    // 1 Cycle combinatorial transparent delay. At this cycle axi_busy = 0.
                    // The CPU pipeline catches the result and shifts forwards!
                    state <= STATE_IDLE;
                end
                
                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end
endmodule
