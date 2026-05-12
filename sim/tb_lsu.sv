`timescale 1ns / 1ps

module tb_lsu;

  logic        done;

  logic        clk;

  logic        mem_read;
  logic        mem_write;

  logic [31:0] addr;
  logic [31:0] write_data;

  logic [1:0]  mem_size;
  logic        mem_unsigned;

  logic [31:0] read_data;
  logic        misaligned;

  localparam logic [1:0] MEM_BYTE = 2'd0;
  localparam logic [1:0] MEM_HALF = 2'd1;
  localparam logic [1:0] MEM_WORD = 2'd2;

  lsu #(
      .DEPTH_WORDS(16)
  ) dut (
      .clk          (clk),
      .mem_read     (mem_read),
      .mem_write    (mem_write),
      .addr         (addr),
      .write_data   (write_data),
      .mem_size     (mem_size),
      .mem_unsigned (mem_unsigned),
      .read_data    (read_data),
      .misaligned   (misaligned)
  );

  always begin
    #5 clk = ~clk;
  end

  task automatic write_mem;
    input string       name;
    input logic [31:0] test_addr;
    input logic [31:0] test_write_data;
    input logic [1:0]  test_mem_size;
    input logic        expected_misaligned;

    begin
      @(negedge clk);

      mem_read     = 1'b0;
      mem_write    = 1'b1;
      addr         = test_addr;
      write_data   = test_write_data;
      mem_size     = test_mem_size;
      mem_unsigned = 1'b0;

      #1;

      if (misaligned !== expected_misaligned) begin
        $display("FAIL: %s before write addr=%h expected_misaligned=%b got_misaligned=%b",
                 name, addr, expected_misaligned, misaligned);
        $fatal;
      end

      @(posedge clk);
      #1;

      mem_write = 1'b0;

      $display("PASS: %s write addr=%h data=%h size=%0d misaligned=%b",
               name, test_addr, test_write_data, test_mem_size, misaligned);
    end
  endtask

  task automatic read_mem;
    input string       name;
    input logic [31:0] test_addr;
    input logic [1:0]  test_mem_size;
    input logic        test_mem_unsigned;
    input logic [31:0] expected_read_data;
    input logic        expected_misaligned;

    begin
      mem_read     = 1'b1;
      mem_write    = 1'b0;
      addr         = test_addr;
      write_data   = 32'h0000_0000;
      mem_size     = test_mem_size;
      mem_unsigned = test_mem_unsigned;

      #1;

      if ((read_data !== expected_read_data) || (misaligned !== expected_misaligned)) begin
        $display("FAIL: %s addr=%h size=%0d unsigned=%b expected_data=%h got_data=%h expected_misaligned=%b got_misaligned=%b",
                 name, addr, mem_size, mem_unsigned,
                 expected_read_data, read_data,
                 expected_misaligned, misaligned);
        $fatal;
      end else begin
        $display("PASS: %s addr=%h size=%0d unsigned=%b data=%h misaligned=%b",
                 name, addr, mem_size, mem_unsigned, read_data, misaligned);
      end
    end
  endtask

  initial begin
    done = 1'b0;

    clk          = 1'b0;
    mem_read     = 1'b0;
    mem_write    = 1'b0;
    addr         = 32'h0000_0000;
    write_data   = 32'h0000_0000;
    mem_size     = MEM_WORD;
    mem_unsigned = 1'b0;

    $display("Starting LSU tests...");

    // ------------------------------------------------------------
    // Word store/load
    // ------------------------------------------------------------

    write_mem("SW word at 0x00", 32'h0000_0000, 32'h1234_5678, MEM_WORD, 1'b0);
    read_mem ("LW word at 0x00", 32'h0000_0000, MEM_WORD, 1'b0, 32'h1234_5678, 1'b0);

    write_mem("SW word at 0x04", 32'h0000_0004, 32'hDEAD_BEEF, MEM_WORD, 1'b0);
    read_mem ("LW word at 0x04", 32'h0000_0004, MEM_WORD, 1'b0, 32'hDEAD_BEEF, 1'b0);

    // ------------------------------------------------------------
    // Byte stores into one word
    // Expected little-endian byte placement:
    // addr + 0 -> bits [7:0]
    // addr + 1 -> bits [15:8]
    // addr + 2 -> bits [23:16]
    // addr + 3 -> bits [31:24]
    // ------------------------------------------------------------

    write_mem("clear word at 0x08", 32'h0000_0008, 32'h0000_0000, MEM_WORD, 1'b0);

    write_mem("SB byte 0 at 0x08", 32'h0000_0008, 32'h0000_0011, MEM_BYTE, 1'b0);
    write_mem("SB byte 1 at 0x09", 32'h0000_0009, 32'h0000_0022, MEM_BYTE, 1'b0);
    write_mem("SB byte 2 at 0x0A", 32'h0000_000A, 32'h0000_0033, MEM_BYTE, 1'b0);
    write_mem("SB byte 3 at 0x0B", 32'h0000_000B, 32'h0000_0044, MEM_BYTE, 1'b0);

    read_mem("LW after byte stores", 32'h0000_0008, MEM_WORD, 1'b0, 32'h4433_2211, 1'b0);

    // ------------------------------------------------------------
    // Byte loads: signed and unsigned
    // ------------------------------------------------------------

    write_mem("SW byte test word", 32'h0000_000C, 32'h80FF_7F01, MEM_WORD, 1'b0);

    read_mem("LB +0 signed positive",   32'h0000_000C, MEM_BYTE, 1'b0, 32'h0000_0001, 1'b0);
    read_mem("LBU +0 unsigned",         32'h0000_000C, MEM_BYTE, 1'b1, 32'h0000_0001, 1'b0);

    read_mem("LB +1 signed positive",   32'h0000_000D, MEM_BYTE, 1'b0, 32'h0000_007F, 1'b0);
    read_mem("LBU +1 unsigned",         32'h0000_000D, MEM_BYTE, 1'b1, 32'h0000_007F, 1'b0);

    read_mem("LB +2 signed negative",   32'h0000_000E, MEM_BYTE, 1'b0, 32'hFFFF_FFFF, 1'b0);
    read_mem("LBU +2 unsigned",         32'h0000_000E, MEM_BYTE, 1'b1, 32'h0000_00FF, 1'b0);

    read_mem("LB +3 signed negative",   32'h0000_000F, MEM_BYTE, 1'b0, 32'hFFFF_FF80, 1'b0);
    read_mem("LBU +3 unsigned",         32'h0000_000F, MEM_BYTE, 1'b1, 32'h0000_0080, 1'b0);

    // ------------------------------------------------------------
    // Halfword stores and loads
    // ------------------------------------------------------------

    write_mem("clear word at 0x10", 32'h0000_0010, 32'h0000_0000, MEM_WORD, 1'b0);

    write_mem("SH low half at 0x10",  32'h0000_0010, 32'h0000_AA55, MEM_HALF, 1'b0);
    write_mem("SH high half at 0x12", 32'h0000_0012, 32'h0000_1234, MEM_HALF, 1'b0);

    read_mem("LW after half stores", 32'h0000_0010, MEM_WORD, 1'b0, 32'h1234_AA55, 1'b0);

    read_mem("LH low signed negative",  32'h0000_0010, MEM_HALF, 1'b0, 32'hFFFF_AA55, 1'b0);
    read_mem("LHU low unsigned",        32'h0000_0010, MEM_HALF, 1'b1, 32'h0000_AA55, 1'b0);

    read_mem("LH high signed positive", 32'h0000_0012, MEM_HALF, 1'b0, 32'h0000_1234, 1'b0);
    read_mem("LHU high unsigned",       32'h0000_0012, MEM_HALF, 1'b1, 32'h0000_1234, 1'b0);

    // ------------------------------------------------------------
    // Misalignment checks
    // ------------------------------------------------------------

    read_mem("misaligned LH at 0x11", 32'h0000_0011, MEM_HALF, 1'b0, 32'h0000_0000, 1'b1);
    read_mem("misaligned LW at 0x01", 32'h0000_0001, MEM_WORD, 1'b0, 32'h0000_0000, 1'b1);
    read_mem("misaligned LW at 0x02", 32'h0000_0002, MEM_WORD, 1'b0, 32'h0000_0000, 1'b1);
    read_mem("misaligned LW at 0x03", 32'h0000_0003, MEM_WORD, 1'b0, 32'h0000_0000, 1'b1);

    // Misaligned store should not modify memory.
    write_mem("SW known word before bad store", 32'h0000_0014, 32'hCAFE_BABE, MEM_WORD, 1'b0);
    write_mem("misaligned SW at 0x15 ignored", 32'h0000_0015, 32'h1111_2222, MEM_WORD, 1'b1);
    read_mem ("LW after ignored bad store",     32'h0000_0014, MEM_WORD, 1'b0, 32'hCAFE_BABE, 1'b0);

    // ------------------------------------------------------------
    // Invalid mem_size
    // ------------------------------------------------------------

    read_mem("invalid mem_size", 32'h0000_0000, 2'd3, 1'b0, 32'h0000_0000, 1'b1);

    $display("All LSU tests passed.");
    done = 1'b1;
    $finish;
  end

  initial begin
    #2000;
    if (!done) begin
      $display("TIMEOUT: tb_lsu did not finish.");
      $fatal;
    end
  end

endmodule