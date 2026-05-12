`timescale 1ns / 1ps

module tb_fiu;

  logic        done;

  logic [31:0] addr;
  logic [31:0] instr;
  logic        misaligned;

  fiu #(
      .DEPTH_WORDS(16)
  ) dut (
      .addr       (addr),
      .instr      (instr),
      .misaligned (misaligned)
  );

  task automatic check_fetch;
    input string       name;
    input logic [31:0] test_addr;
    input logic [31:0] expected_instr;
    input logic        expected_misaligned;

    begin
      addr = test_addr;
      #1;

      if ((instr !== expected_instr) || (misaligned !== expected_misaligned)) begin
        $display("FAIL: %s addr=%h expected_instr=%h got_instr=%h expected_misaligned=%b got_misaligned=%b",
                 name, addr, expected_instr, instr, expected_misaligned, misaligned);
        $fatal;
      end else begin
        $display("PASS: %s addr=%h instr=%h misaligned=%b",
                 name, addr, instr, misaligned);
      end
    end
  endtask

  initial begin
    done = 1'b0;
    addr = 32'h0000_0000;

    $display("Starting FIU tests...");

    // Preload instruction memory directly for simulation.
    // Address 0x00 -> mem[0]
    // Address 0x04 -> mem[1]
    // Address 0x08 -> mem[2]
    // Address 0x0C -> mem[3]
    dut.mem[0] = 32'h0000_0013;  // nop = addi x0, x0, 0
    dut.mem[1] = 32'h0050_0093;  // addi x1, x0, 5
    dut.mem[2] = 32'h0070_0113;  // addi x2, x0, 7
    dut.mem[3] = 32'h0020_81B3;  // add x3, x1, x2

    check_fetch("fetch addr 0x00", 32'h0000_0000, 32'h0000_0013, 1'b0);
    check_fetch("fetch addr 0x04", 32'h0000_0004, 32'h0050_0093, 1'b0);
    check_fetch("fetch addr 0x08", 32'h0000_0008, 32'h0070_0113, 1'b0);
    check_fetch("fetch addr 0x0C", 32'h0000_000C, 32'h0020_81B3, 1'b0);

    // Misaligned instruction fetches.
    // RV32I base instructions are 4 bytes, so these are invalid for our simple FIU.
    check_fetch("misaligned addr 0x01", 32'h0000_0001, 32'h0000_0013, 1'b1);
    check_fetch("misaligned addr 0x02", 32'h0000_0002, 32'h0000_0013, 1'b1);
    check_fetch("misaligned addr 0x03", 32'h0000_0003, 32'h0000_0013, 1'b1);

    $display("All FIU tests passed.");
    done = 1'b1;
    $finish;
  end

  initial begin
    #1000;
    if (!done) begin
      $display("TIMEOUT: tb_fiu did not finish.");
      $fatal;
    end
  end

endmodule