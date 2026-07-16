// ------------------------------------------------------------
// Sequence item: one logical write or read transaction
// ------------------------------------------------------------
class axi4lite_seq_item extends uvm_sequence_item;
    `uvm_object_utils(axi4lite_seq_item)

    rand bit         is_write;
    rand bit [7:0]   addr;
    rand bit [31:0]  data;      // write data, or captured read data
    bit      [1:0]   resp;      // captured response (BRESP or RRESP)

    function new(string name = "axi4lite_seq_item");
        super.new(name);
    endfunction

    //constraint c_addr_range { addr inside {8'h00, 8'h04, 8'h08, 8'h0C}; }

    function string convert2string();
        return $sformatf("%s addr=0x%0h data=0x%0h resp=%0d",
                          is_write ? "WRITE" : "READ", addr, data, resp);
    endfunction
endclass
