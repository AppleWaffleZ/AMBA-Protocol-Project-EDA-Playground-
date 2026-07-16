// ============================================================
// monitor.sv
// Depends on: if.sv, sequence_item.sv
// Must compile BEFORE: agent.sv
// ============================================================

class axi4lite_monitor extends uvm_monitor;
    `uvm_component_utils(axi4lite_monitor)

    virtual axi4lite_if vif;
    uvm_analysis_port #(axi4lite_seq_item) ap;

    // Holds read addresses whose AR handshake has completed but whose
    // R data hasn't arrived yet.
    bit [7:0] ar_addr_q[$];

    // Holds address+data for writes whose AW/W handshake has completed
    // but whose B response hasn't arrived yet (BRESP always lands one
    // cycle later - see design.sv). Without this, a write transaction
    // would get published with resp defaulting to OKAY regardless of
    // what the DUT actually returned.
    typedef struct packed {
        bit [7:0]  addr;
        bit [31:0] data;
    } aw_pend_t;
    aw_pend_t aw_pend_q[$];

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual axi4lite_if)::get(this, "", "vif", vif))
            `uvm_fatal("MON", "virtual interface not set")
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            @(posedge vif.ACLK);

            // Write address+data phase: remember it, BRESP isn't back yet.
            if (vif.AWVALID && vif.AWREADY && vif.WVALID && vif.WREADY) begin
                aw_pend_t p;
                p.addr = vif.AWADDR;
                p.data = vif.WDATA;
                aw_pend_q.push_back(p);
            end

            // Write response phase: pair BRESP with the oldest pending
            // write and publish the completed write transaction.
            if (vif.BVALID && vif.BREADY) begin
                axi4lite_seq_item tr = axi4lite_seq_item::type_id::create("tr");
                tr.is_write = 1;
                tr.resp     = vif.BRESP;
                if (aw_pend_q.size() == 0) begin
                    `uvm_warning("MON", "B beat seen with no pending AW/W - check AW/W/B sequencing")
                    tr.addr = 8'h00;
                    tr.data = 32'h0;
                end else begin
                    aw_pend_t p = aw_pend_q.pop_front();
                    tr.addr = p.addr;
                    tr.data = p.data;
                end
                ap.write(tr);
            end

            // Read address phase: remember the address, data isn't back yet.
            if (vif.ARVALID && vif.ARREADY) begin
                ar_addr_q.push_back(vif.ARADDR);
            end

            // Read data phase: pair the returned data with the oldest
            // pending address and publish the completed read transaction.
            if (vif.RVALID && vif.RREADY) begin
                axi4lite_seq_item tr = axi4lite_seq_item::type_id::create("tr");
                tr.is_write = 0;
                tr.data     = vif.RDATA;
                tr.resp     = vif.RRESP;
                if (ar_addr_q.size() == 0) begin
                    `uvm_warning("MON", "R beat seen with no pending AR address - check AR/R sequencing")
                    tr.addr = 8'h00;
                end else begin
                    tr.addr = ar_addr_q.pop_front();
                end
                ap.write(tr);
            end
        end
    endtask
endclass
