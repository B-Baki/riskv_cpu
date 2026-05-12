`timescale 1ns / 1ps

module tb_pc_unit;

  logic        done;

  logic        clk;
  logic        rst_n;
  logic        stall;

  logic        branch;
  logic        branch_taken;

  logic        jump;
  logic        jalr;

  logic [31:0] imm;
  logic [31:0] rs1_data;

  logic [31:0] pc;
  logic [31:0] pc_next;
  logic [31:0] pc_plus4;

  pc_unit #(
      .RESET_PC(32'h0000_0000)
  ) dut (
      .clk          (clk),
      .rst_n        (rst_n),
      .stall        (stall),
      .branch       (branch),
      .branch_taken (branch_taken),
      .jump         (jump),
      .jalr         (jalr),
      .imm          (imm),
      .rs1_data     (rs1_data),
      .pc           (pc),
      .pc_next      (pc_next),
      .pc_plus4     (pc_plus4)
  );

  always begin
    #5 clk = ~clk;
  end

  task automatic check_comb;
    input string       name;
    input logic [31:0] expected_pc_next;
    input logic [31:0] expected_pc_plus4;

    begin
      #1;

      if (pc_next !== expected_pc_next || pc_plus4 !== expected_pc_plus4) begin
        $display("FAIL: %s expected_pc_next=%h got_pc_next=%h expected_pc_plus4=%h got_pc_plus4=%h",
                 name, expected_pc_next, pc_next, expected_pc_plus4, pc_plus4);
        $fatal;
      end else begin
        $display("PASS: %s pc=%h pc_next=%h pc_plus4=%h",
                 name, pc, pc_next, pc_plus4);
      end
    end
  endtask

  task automatic step_clock;
    begin
      @(posedge clk);
      #1;
    end
  endtask

  task automatic check_pc;
    input string       name;
    input logic [31:0] expected_pc;

    begin
      #1;

      if (pc !== expected_pc) begin
        $display("FAIL: %s expected_pc=%h got_pc=%h",
                 name, expected_pc, pc);
        $fatal;
      end else begin
        $display("PASS: %s pc=%h", name, pc);
      end
    end
  endtask

  initial begin
    done = 1'b0;

    clk          = 1'b0;
    rst_n        = 1'b0;
    stall        = 1'b0;

    branch       = 1'b0;
    branch_taken = 1'b0;

    jump         = 1'b0;
    jalr         = 1'b0;

    imm          = 32'h0000_0000;
    rs1_data     = 32'h0000_0000;

    $display("Starting PC unit tests...");

    // ------------------------------------------------------------
    // Reset
    // ------------------------------------------------------------

    repeat (2) @(posedge clk);
    #1;
    check_pc("reset sets PC to RESET_PC", 32'h0000_0000);

    rst_n = 1'b1;
    #1;

    // ------------------------------------------------------------
    // Normal PC + 4
    // ------------------------------------------------------------

    branch       = 1'b0;
    branch_taken = 1'b0;
    jump         = 1'b0;
    jalr         = 1'b0;
    imm          = 32'h0000_0000;
    rs1_data     = 32'h0000_0000;

    check_comb("normal pc_next = pc + 4", 32'h0000_0004, 32'h0000_0004);

    step_clock();
    check_pc("after normal step PC = 4", 32'h0000_0004);

    check_comb("normal pc_next = 8", 32'h0000_0008, 32'h0000_0008);

    step_clock();
    check_pc("after normal step PC = 8", 32'h0000_0008);

    // ------------------------------------------------------------
    // Branch not taken
    // ------------------------------------------------------------

    branch       = 1'b1;
    branch_taken = 1'b0;
    imm          = 32'h0000_0010;

    check_comb("branch not taken uses pc + 4", 32'h0000_000C, 32'h0000_000C);

    step_clock();
    check_pc("branch not taken PC = C", 32'h0000_000C);

    // ------------------------------------------------------------
    // Branch taken
    // Current PC = 0xC, imm = 0x10, next should be 0x1C
    // ------------------------------------------------------------

    branch       = 1'b1;
    branch_taken = 1'b1;
    jump         = 1'b0;
    jalr         = 1'b0;
    imm          = 32'h0000_0010;

    check_comb("branch taken uses pc + imm", 32'h0000_001C, 32'h0000_0010);

    step_clock();
    check_pc("branch taken PC = 1C", 32'h0000_001C);

    // ------------------------------------------------------------
    // JAL
    // Current PC = 0x1C, imm = 0x20, next should be 0x3C
    // ------------------------------------------------------------

    branch       = 1'b0;
    branch_taken = 1'b0;
    jump         = 1'b1;
    jalr         = 1'b0;
    imm          = 32'h0000_0020;

    check_comb("JAL uses pc + imm", 32'h0000_003C, 32'h0000_0020);

    step_clock();
    check_pc("JAL PC = 3C", 32'h0000_003C);

    // ------------------------------------------------------------
    // JALR
    // rs1_data + imm = 0x101 + 0x4 = 0x105
    // JALR clears bit 0, so target should be 0x104
    // ------------------------------------------------------------

    jump         = 1'b1;
    jalr         = 1'b1;
    imm          = 32'h0000_0004;
    rs1_data     = 32'h0000_0101;

    check_comb("JALR clears bit 0", 32'h0000_0104, 32'h0000_0040);

    step_clock();
    check_pc("JALR PC = 104", 32'h0000_0104);

    // ------------------------------------------------------------
    // Stall
    // Current PC = 0x104.
    // pc_next may calculate 0x108, but PC should not update.
    // ------------------------------------------------------------

    stall        = 1'b1;
    branch       = 1'b0;
    branch_taken = 1'b0;
    jump         = 1'b0;
    jalr         = 1'b0;
    imm          = 32'h0000_0000;
    rs1_data     = 32'h0000_0000;

    check_comb("stall still computes pc_next", 32'h0000_0108, 32'h0000_0108);

    step_clock();
    check_pc("stall holds PC", 32'h0000_0104);

    // ------------------------------------------------------------
    // Release stall
    // ------------------------------------------------------------

    stall = 1'b0;

    check_comb("after stall release pc_next = pc + 4", 32'h0000_0108, 32'h0000_0108);

    step_clock();
    check_pc("after stall release PC = 108", 32'h0000_0108);

    // ------------------------------------------------------------
    // Reset again after nonzero PC
    // ------------------------------------------------------------

    rst_n = 1'b0;

    step_clock();
    check_pc("reset again clears PC", 32'h0000_0000);

    $display("All PC unit tests passed.");
    done = 1'b1;
    $finish;
  end

  initial begin
    #1000;
    if (!done) begin
      $display("TIMEOUT: tb_pc_unit did not finish.");
      $fatal;
    end
  end

endmodule