// ============================================================
// testbench.sv
// Minimal UVM testbench skeleton for the AXI4-Lite slave.
// Paste this into the "Testbench" pane on EDA Playground.
// Set the UVM/OVM dropdown to a real UVM version (e.g. 1.2)
// before running.
// ============================================================

`include "if.sv"
`include "axi4lite_pkg.sv"    // pastes the package block in right here, before anything below
`include "test_pkg.sv"        // needs axi4lite_pkg already defined - satisfied, since it's textually above

// ------------------------------------------------------------
// Top-level: clock/reset, DUT, interface binding, run_test
// ------------------------------------------------------------
module top;
  	
  	import uvm_pkg::*;	
  
    logic clk;
    logic rst_n;

    always #5 clk = ~clk;

    initial begin
        clk   = 0;
        rst_n = 0;
        #20 rst_n = 1;
    end

    axi4lite_if #(.ADDR_WIDTH(8), .DATA_WIDTH(32)) vif(.ACLK(clk), .ARESETn(rst_n));

    axi4lite_slave #(.ADDR_WIDTH(8), .DATA_WIDTH(32)) dut (
        .ACLK    (clk),
        .ARESETn (rst_n),
        .AWADDR  (vif.AWADDR),  .AWVALID(vif.AWVALID), .AWREADY(vif.AWREADY),
        .WDATA   (vif.WDATA),   .WSTRB(vif.WSTRB), .WVALID(vif.WVALID), .WREADY(vif.WREADY),
        .BRESP   (vif.BRESP),   .BVALID(vif.BVALID), .BREADY(vif.BREADY),
        .ARADDR  (vif.ARADDR),  .ARVALID(vif.ARVALID), .ARREADY(vif.ARREADY),
        .RDATA   (vif.RDATA),   .RRESP(vif.RRESP), .RVALID(vif.RVALID), .RREADY(vif.RREADY)
    );

    initial begin
        uvm_config_db#(virtual axi4lite_if)::set(null, "*", "vif", vif);
        run_test("axi4lite_base_test");
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, top);
    end
endmodule
