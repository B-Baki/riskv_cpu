`timescale 1ns / 1ps

module tb_rv32_core;

  logic        done;

  logic        clk;
  logic        rst_n;
  logic        stall;

  logic [31:0] pc;
  logic [31:0] instr;

  logic        halted;
  logic        trap;

  rv32_core #(
      .RESET_PC   (32'h0000_0000),
      .IMEM_WORDS (64),
      .DMEM_WORDS (64),
      .IMEM_INIT_FILE ("/home/baki/projects/riskv_cpu/programs/core_basic.hex"),
      .DMEM_INIT_FILE ("")
  ) dut (
      .clk    (clk),
      .rst_n  (rst_n),
      .stall  (stall),
      .pc     (pc),
      .instr  (instr),
      .halted (halted),
      .trap   (trap)
  );

  always begin
    #5 clk = ~clk;
  end

  // ------------------------------------------------------------
  // Instruction encoders
  // ------------------------------------------------------------

  localparam logic [6:0] OPCODE_OP_IMM = 7'b0010011;
  localparam logic [6:0] OPCODE_OP     = 7'b0110011;
  localparam logic [6:0] OPCODE_LOAD   = 7'b0000011;
  localparam logic [6:0] OPCODE_STORE  = 7'b0100011;
  localparam logic [6:0] OPCODE_BRANCH = 7'b1100011;
  localparam logic [6:0] OPCODE_JAL    = 7'b1101111;
  localparam logic [6:0] OPCODE_SYSTEM = 7'b1110011;

  function automatic logic [31:0] enc_addi(
      input logic [4:0]  rd,
      input logic [4:0]  rs1,
      input logic [11:0] imm12
  );
    begin
      enc_addi = {imm12, rs1, 3'b000, rd, OPCODE_OP_IMM};
    end
  endfunction

  function automatic logic [31:0] enc_add(
      input logic [4:0] rd,
      input logic [4:0] rs1,
      input logic [4:0] rs2
  );
    begin
      enc_add = {7'b0000000, rs2, rs1, 3'b000, rd, OPCODE_OP};
    end
  endfunction

  function automatic logic [31:0] enc_lw(
      input logic [4:0]  rd,
      input logic [4:0]  rs1,
      input logic [11:0] imm12
  );
    begin
      enc_lw = {imm12, rs1, 3'b010, rd, OPCODE_LOAD};
    end
  endfunction

  function automatic logic [31:0] enc_sw(
      input logic [4:0]  rs2,
      input logic [4:0]  rs1,
      input logic [11:0] imm12
  );
    begin
      enc_sw = {imm12[11:5], rs2, rs1, 3'b010, imm12[4:0], OPCODE_STORE};
    end
  endfunction

  function automatic logic [31:0] enc_beq(
      input logic [4:0]  rs1,
      input logic [4:0]  rs2,
      input logic [12:0] imm13
  );
    begin
      enc_beq = {
        imm13[12],
        imm13[10:5],
        rs2,
        rs1,
        3'b000,
        imm13[4:1],
        imm13[11],
        OPCODE_BRANCH
      };
    end
  endfunction

  function automatic logic [31:0] enc_jal(
      input logic [4:0]  rd,
      input logic [20:0] imm21
  );
    begin
      enc_jal = {
        imm21[20],
        imm21[10:1],
        imm21[11],
        imm21[19:12],
        rd,
        OPCODE_JAL
      };
    end
  endfunction

  function automatic logic [31:0] enc_ebreak();
    begin
      enc_ebreak = {12'h001, 5'd0, 3'b000, 5'd0, OPCODE_SYSTEM};
    end
  endfunction

  // ------------------------------------------------------------
  // Check helpers
  // ------------------------------------------------------------

  task automatic check_reg;
    input logic [4:0]  reg_addr;
    input logic [31:0] expected;

    begin
      if (dut.u_regfile.regs[reg_addr] !== expected) begin
        $display("FAIL: x%0d expected=%h got=%h",
                 reg_addr, expected, dut.u_regfile.regs[reg_addr]);
        $fatal;
      end else begin
        $display("PASS: x%0d = %h", reg_addr, dut.u_regfile.regs[reg_addr]);
      end
    end
  endtask

  task automatic check_dmem;
    input logic [31:0] word_index;
    input logic [31:0] expected;

    begin
      if (dut.u_lsu.mem[word_index] !== expected) begin
        $display("FAIL: dmem[%0d] expected=%h got=%h",
                 word_index, expected, dut.u_lsu.mem[word_index]);
        $fatal;
      end else begin
        $display("PASS: dmem[%0d] = %h", word_index, dut.u_lsu.mem[word_index]);
      end
    end
  endtask

  // ------------------------------------------------------------
  // Main test
  // ------------------------------------------------------------

  initial begin
    done  = 1'b0;

    clk   = 1'b0;
    rst_n = 1'b0;
    stall = 1'b0;

    $display("Starting RV32 core test...");

    // Clear data memory word 0.
    dut.u_lsu.mem[0] = 32'h0000_0000;

    // Hold reset for two cycles.
    repeat (2) @(posedge clk);
    #1;

    rst_n = 1'b1;

    // Run until the core halts or timeout.
    repeat (50) begin
      @(posedge clk);
      #1;

      $display("cycle pc=%h instr=%h halted=%b trap=%b",
               pc, instr, halted, trap);

      if (halted) begin
        break;
      end
    end

    if (!halted) begin
      $display("FAIL: core did not halt");
      $fatal;
    end

    // ------------------------------------------------------------
    // Final architectural checks
    // ------------------------------------------------------------

    check_reg(5'd1, 32'd5);
    check_reg(5'd2, 32'd7);
    check_reg(5'd3, 32'd12);
    check_reg(5'd4, 32'd12);
    check_reg(5'd5, 32'd222);
    check_reg(5'd6, 32'h0000_0024);
    check_reg(5'd7, 32'h0000_0000);
    check_reg(5'd8, 32'hFFFF_FFFF);

    check_dmem(32'd0, 32'd12);

    if (pc !== 32'h0000_002C) begin
      $display("FAIL: expected halted PC=0000002c got=%h", pc);
      $fatal;
    end else begin
      $display("PASS: halted PC = %h", pc);
    end

    $display("All RV32 core tests passed.");
    done = 1'b1;
    $finish;
  end

  initial begin
    #2000;
    if (!done) begin
      $display("TIMEOUT: tb_rv32_core did not finish.");
      $fatal;
    end
  end

endmodule