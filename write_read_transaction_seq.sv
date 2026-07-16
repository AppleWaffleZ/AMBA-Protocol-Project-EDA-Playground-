// ============================================================
// write_read_transaction_seq.sv
// Depends on: sequence_item.sv, sequencer.sv
// Must compile BEFORE: test.sv
// ============================================================

class write_read_transaction_seq extends uvm_sequence #(axi4lite_seq_item);
    `uvm_object_utils(write_read_transaction_seq)

    function new(string name = "write_read_transaction_seq");
        super.new(name);
    endfunction

    task body();
        repeat (10) begin  // however many random transactions you want
            axi4lite_seq_item wr;
            axi4lite_seq_item rd;

            wr = axi4lite_seq_item::type_id::create("wr");
            start_item(wr);
            if (!wr.randomize() with { is_write == 1; })
                `uvm_error(get_type_name(), "wr.randomize() failed")
            finish_item(wr);
            `uvm_info(get_type_name(),
                $sformatf("WRITE addr=0x%0h data=0x%0h -> resp=%0d",
                          wr.addr, wr.data, wr.resp), UVM_LOW)

            rd = axi4lite_seq_item::type_id::create("rd");
            start_item(rd);
            if (!rd.randomize() with { is_write == 0; addr == wr.addr; })
                `uvm_error(get_type_name(), "rd.randomize() failed")
            finish_item(rd);
            `uvm_info(get_type_name(),
                $sformatf("READ  addr=0x%0h <- data=0x%0h resp=%0d",
                          rd.addr, rd.data, rd.resp), UVM_LOW)
        end
    endtask
endclass
