// ============================================================
// Minimal AXI4-Lite slave: 4 x 32-bit memory-mapped registers
// ============================================================

module axi4lite_slave #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32
)(
    input  logic                    ACLK,
    input  logic                    ARESETn,

    // Write address channel
    input  logic [ADDR_WIDTH-1:0]   AWADDR,
    input  logic                    AWVALID,
    output logic                    AWREADY,

    // Write data channel
    input  logic [DATA_WIDTH-1:0]   WDATA,
    input  logic [DATA_WIDTH/8-1:0] WSTRB,
    input  logic                    WVALID,
    output logic                    WREADY,

    // Write response channel
    output logic [1:0]              BRESP,
    output logic                    BVALID,
    input  logic                    BREADY,

    // Read address channel
    input  logic [ADDR_WIDTH-1:0]   ARADDR,
    input  logic                    ARVALID,
    output logic                    ARREADY,

    // Read data channel
    output logic [DATA_WIDTH-1:0]   RDATA,
    output logic [1:0]              RRESP,
    output logic                    RVALID,
    input  logic                    RREADY
);

    localparam OKAY   = 2'b00;
    localparam SLVERR = 2'b10;

    // 4 registers at word-aligned offsets 0x0, 0x4, 0x8, 0xC
    logic [DATA_WIDTH-1:0] regs [0:3];

    logic [ADDR_WIDTH-1:0] awaddr_l, araddr_l;
    logic                  aw_hs, w_hs, ar_hs;

   // ---------------- Write address handshake ----------------
    assign AWREADY = !ARESETn ? 1'b0 : (!AWVALID ? 1'b0 : (BVALID ? 1'b0 : 1'b1));
    // simple: accept AWADDR when both AW and W arrive; latch on handshake
    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) awaddr_l <= '0;
        else if (AWVALID && AWREADY) awaddr_l <= AWADDR;
    end

    // ---------------- Write data handshake --------------------
    assign WREADY = AWREADY;

    // ---------------- Write response ---------------------------
    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            BVALID <= 1'b0;
            BRESP  <= OKAY;
        end else if (AWVALID && AWREADY && WVALID && WREADY) begin
            int idx;
            idx = awaddr_l[3:2]; // word index (fallback to AWADDR since same cycle)
            idx = AWADDR[3:2];
            if (AWADDR[ADDR_WIDTH-1:4] == '0) begin
                regs[idx] <= WDATA;
                BRESP     <= OKAY;
            end else begin
                BRESP     <= SLVERR; // out of range
            end
            BVALID <= 1'b1;
        end else if (BVALID && BREADY) begin
            BVALID <= 1'b0;
        end
    end

// ---------------- Read address handshake -------------------
    assign ARREADY = !ARESETn ? 1'b0 : !RVALID;

    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) araddr_l <= '0;
        else if (ARVALID && ARREADY) araddr_l <= ARADDR;
    end

    // ---------------- Read data ---------------------------------
    always_ff @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            RVALID <= 1'b0;
            RDATA  <= '0;
            RRESP  <= OKAY;
        end else if (ARVALID && ARREADY) begin
            if (ARADDR[ADDR_WIDTH-1:4] == '0) begin
                RDATA <= regs[ARADDR[3:2]];
                RRESP <= OKAY;
            end else begin 
                // TEMP bug injection: corrupt reads from 0x04 and 0x0C only,
                // Uncomment if want to see failure (to test whether our scoreboard working).
            /*if (ARADDR[ADDR_WIDTH-1:4] == '0) begin
                if (ARADDR[3:2] == 2'd1 || ARADDR[3:2] == 2'd3) begin
                    RDATA <= regs[ARADDR[3:2]] ^ 32'h0000_0001;
                end else begin
                    RDATA <= regs[ARADDR[3:2]];
                end
                RRESP <= OKAY;
            end else begin*/
                RDATA <= '0;
                RRESP <= SLVERR;
            end
            RVALID <= 1'b1;
        end else if (RVALID && RREADY) begin
            RVALID <= 1'b0;
        end
    end

endmodule
