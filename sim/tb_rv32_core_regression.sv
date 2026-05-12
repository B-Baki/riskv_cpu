`timescale 1ns / 1ps

module tb_rv32_core_regression;

  localparam int IMEM_WORDS = 4096;
  localparam int DMEM_WORDS = 1024;

  // Increase this if you want a longer stress run.
  // 100000 iterations gives roughly 300000+ executed instructions.
  localparam int STRESS_ITERS = 100000;
  localparam logic [31:0] STRESS_SUM_EXPECTED = 32'h2A06_B550; // sum 1..100000 mod 2^32

  logic        done;
  logic        clk;
  logic        rst_n;
  logic        stall;

  logic [31:0] pc;
  logic [31:0] instr;
  logic        halted;
  logic        trap;

  int prog_idx;

  rv32_core #(
      .RESET_PC       (32'h0000_0000),
      .IMEM_WORDS     (IMEM_WORDS),
      .DMEM_WORDS     (DMEM_WORDS),
      .IMEM_INIT_FILE (""),
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
  // Opcodes
  // ------------------------------------------------------------

  localparam logic [6:0] OPCODE_LUI     = 7'b0110111;
  localparam logic [6:0] OPCODE_AUIPC   = 7'b0010111;
  localparam logic [6:0] OPCODE_JAL     = 7'b1101111;
  localparam logic [6:0] OPCODE_JALR    = 7'b1100111;
  localparam logic [6:0] OPCODE_BRANCH  = 7'b1100011;
  localparam logic [6:0] OPCODE_LOAD    = 7'b0000011;
  localparam logic [6:0] OPCODE_STORE   = 7'b0100011;
  localparam logic [6:0] OPCODE_OP_IMM  = 7'b0010011;
  localparam logic [6:0] OPCODE_OP      = 7'b0110011;
  localparam logic [6:0] OPCODE_MISC    = 7'b0001111;
  localparam logic [6:0] OPCODE_SYSTEM  = 7'b1110011;

  // ------------------------------------------------------------
  // Instruction encoders
  // ------------------------------------------------------------

  function automatic logic [31:0] enc_lui(
      input logic [4:0]  rd,
      input logic [19:0] imm20
  );
    begin
      enc_lui = {imm20, rd, OPCODE_LUI};
    end
  endfunction

  function automatic logic [31:0] enc_auipc(
      input logic [4:0]  rd,
      input logic [19:0] imm20
  );
    begin
      enc_auipc = {imm20, rd, OPCODE_AUIPC};
    end
  endfunction

  function automatic logic [31:0] enc_i(
      input logic [6:0]  opcode,
      input logic [4:0]  rd,
      input logic [4:0]  rs1,
      input logic [2:0]  funct3,
      input logic [11:0] imm12
  );
    begin
      enc_i = {imm12, rs1, funct3, rd, opcode};
    end
  endfunction

  function automatic logic [31:0] enc_r(
      input logic [4:0] rd,
      input logic [4:0] rs1,
      input logic [4:0] rs2,
      input logic [2:0] funct3,
      input logic [6:0] funct7
  );
    begin
      enc_r = {funct7, rs2, rs1, funct3, rd, OPCODE_OP};
    end
  endfunction

  function automatic logic [31:0] enc_s(
      input logic [4:0]  rs2,
      input logic [4:0]  rs1,
      input logic [2:0]  funct3,
      input logic [11:0] imm12
  );
    begin
      enc_s = {imm12[11:5], rs2, rs1, funct3, imm12[4:0], OPCODE_STORE};
    end
  endfunction

  function automatic logic [31:0] enc_b(
      input logic [4:0]  rs1,
      input logic [4:0]  rs2,
      input logic [2:0]  funct3,
      input logic [12:0] imm13
  );
    begin
      enc_b = {
        imm13[12],
        imm13[10:5],
        rs2,
        rs1,
        funct3,
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

  function automatic logic [31:0] enc_addi(input logic [4:0] rd, input logic [4:0] rs1, input logic [11:0] imm12);
    begin
      enc_addi = enc_i(OPCODE_OP_IMM, rd, rs1, 3'b000, imm12);
    end
  endfunction

  function automatic logic [31:0] enc_slti(input logic [4:0] rd, input logic [4:0] rs1, input logic [11:0] imm12);
    begin
      enc_slti = enc_i(OPCODE_OP_IMM, rd, rs1, 3'b010, imm12);
    end
  endfunction

  function automatic logic [31:0] enc_sltiu(input logic [4:0] rd, input logic [4:0] rs1, input logic [11:0] imm12);
    begin
      enc_sltiu = enc_i(OPCODE_OP_IMM, rd, rs1, 3'b011, imm12);
    end
  endfunction

  function automatic logic [31:0] enc_xori(input logic [4:0] rd, input logic [4:0] rs1, input logic [11:0] imm12);
    begin
      enc_xori = enc_i(OPCODE_OP_IMM, rd, rs1, 3'b100, imm12);
    end
  endfunction

  function automatic logic [31:0] enc_ori(input logic [4:0] rd, input logic [4:0] rs1, input logic [11:0] imm12);
    begin
      enc_ori = enc_i(OPCODE_OP_IMM, rd, rs1, 3'b110, imm12);
    end
  endfunction

  function automatic logic [31:0] enc_andi(input logic [4:0] rd, input logic [4:0] rs1, input logic [11:0] imm12);
    begin
      enc_andi = enc_i(OPCODE_OP_IMM, rd, rs1, 3'b111, imm12);
    end
  endfunction

  function automatic logic [31:0] enc_slli(input logic [4:0] rd, input logic [4:0] rs1, input logic [4:0] shamt);
    begin
      enc_slli = enc_i(OPCODE_OP_IMM, rd, rs1, 3'b001, {7'b0000000, shamt});
    end
  endfunction

  function automatic logic [31:0] enc_srli(input logic [4:0] rd, input logic [4:0] rs1, input logic [4:0] shamt);
    begin
      enc_srli = enc_i(OPCODE_OP_IMM, rd, rs1, 3'b101, {7'b0000000, shamt});
    end
  endfunction

  function automatic logic [31:0] enc_srai(input logic [4:0] rd, input logic [4:0] rs1, input logic [4:0] shamt);
    begin
      enc_srai = enc_i(OPCODE_OP_IMM, rd, rs1, 3'b101, {7'b0100000, shamt});
    end
  endfunction

  function automatic logic [31:0] enc_lw(input logic [4:0] rd, input logic [4:0] rs1, input logic [11:0] imm12);
    begin
      enc_lw = enc_i(OPCODE_LOAD, rd, rs1, 3'b010, imm12);
    end
  endfunction

  function automatic logic [31:0] enc_lh(input logic [4:0] rd, input logic [4:0] rs1, input logic [11:0] imm12);
    begin
      enc_lh = enc_i(OPCODE_LOAD, rd, rs1, 3'b001, imm12);
    end
  endfunction

  function automatic logic [31:0] enc_lb(input logic [4:0] rd, input logic [4:0] rs1, input logic [11:0] imm12);
    begin
      enc_lb = enc_i(OPCODE_LOAD, rd, rs1, 3'b000, imm12);
    end
  endfunction

  function automatic logic [31:0] enc_lhu(input logic [4:0] rd, input logic [4:0] rs1, input logic [11:0] imm12);
    begin
      enc_lhu = enc_i(OPCODE_LOAD, rd, rs1, 3'b101, imm12);
    end
  endfunction

  function automatic logic [31:0] enc_lbu(input logic [4:0] rd, input logic [4:0] rs1, input logic [11:0] imm12);
    begin
      enc_lbu = enc_i(OPCODE_LOAD, rd, rs1, 3'b100, imm12);
    end
  endfunction

  function automatic logic [31:0] enc_sw(input logic [4:0] rs2, input logic [4:0] rs1, input logic [11:0] imm12);
    begin
      enc_sw = enc_s(rs2, rs1, 3'b010, imm12);
    end
  endfunction

  function automatic logic [31:0] enc_sh(input logic [4:0] rs2, input logic [4:0] rs1, input logic [11:0] imm12);
    begin
      enc_sh = enc_s(rs2, rs1, 3'b001, imm12);
    end
  endfunction

  function automatic logic [31:0] enc_sb(input logic [4:0] rs2, input logic [4:0] rs1, input logic [11:0] imm12);
    begin
      enc_sb = enc_s(rs2, rs1, 3'b000, imm12);
    end
  endfunction

  function automatic logic [31:0] enc_jalr(input logic [4:0] rd, input logic [4:0] rs1, input logic [11:0] imm12);
    begin
      enc_jalr = enc_i(OPCODE_JALR, rd, rs1, 3'b000, imm12);
    end
  endfunction

  function automatic logic [31:0] enc_ebreak();
    begin
      enc_ebreak = {12'h001, 5'd0, 3'b000, 5'd0, OPCODE_SYSTEM};
    end
  endfunction

  function automatic logic [31:0] enc_ecall();
    begin
      enc_ecall = {12'h000, 5'd0, 3'b000, 5'd0, OPCODE_SYSTEM};
    end
  endfunction

  function automatic logic [31:0] enc_fence();
    begin
      enc_fence = {12'h000, 5'd0, 3'b000, 5'd0, OPCODE_MISC};
    end
  endfunction

  // ------------------------------------------------------------
  // Testbench infrastructure
  // ------------------------------------------------------------

  task automatic emit(input logic [31:0] insn);
    begin
      dut.u_fiu.mem[prog_idx] = insn;
      prog_idx = prog_idx + 1;
    end
  endtask

  task automatic clear_memories;
    int i;
    begin
      for (i = 0; i < IMEM_WORDS; i = i + 1) begin
        dut.u_fiu.mem[i] = enc_ebreak();
      end

      for (i = 0; i < DMEM_WORDS; i = i + 1) begin
        dut.u_lsu.mem[i] = 32'h0000_0000;
      end
    end
  endtask

  task automatic start_program(input string name);
    begin
      $display("");
      $display("============================================================");
      $display("START PROGRAM: %s", name);
      $display("============================================================");

      clear_memories();
      prog_idx = 0;

      rst_n = 1'b0;
      stall = 1'b0;
      repeat (2) @(posedge clk);
      #1;
    end
  endtask

  task automatic run_until_halt(input int max_cycles);
    int cycle;
    begin
      rst_n = 1'b1;

      for (cycle = 0; cycle < max_cycles; cycle = cycle + 1) begin
        @(posedge clk);
        #1;

        if (halted) begin
          $display("Core halted after %0d cycles at PC=%h instr=%h trap=%b",
                   cycle + 1, pc, instr, trap);
          return;
        end
      end

      $display("FAIL: core did not halt within %0d cycles. pc=%h instr=%h",
               max_cycles, pc, instr);
      $fatal;
    end
  endtask

  task automatic check_reg(input int reg_num, input logic [31:0] expected);
    begin
      if (reg_num == 0) begin
        if (dut.u_regfile.regs[0] !== 32'h0000_0000) begin
          $display("FAIL: internal x0 storage expected 00000000 got %h", dut.u_regfile.regs[0]);
          $fatal;
        end
      end else if (dut.u_regfile.regs[reg_num] !== expected) begin
        $display("FAIL: x%0d expected=%h got=%h",
                 reg_num, expected, dut.u_regfile.regs[reg_num]);
        $fatal;
      end else begin
        $display("PASS: x%0d = %h", reg_num, dut.u_regfile.regs[reg_num]);
      end
    end
  endtask

  task automatic check_dmem(input int word_index, input logic [31:0] expected);
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

  task automatic expect_halted_at(input logic [31:0] expected_pc);
    begin
      if (!halted || !trap) begin
        $display("FAIL: expected halted/trap. halted=%b trap=%b pc=%h", halted, trap, pc);
        $fatal;
      end

      if (pc !== expected_pc) begin
        $display("FAIL: expected halt PC=%h got=%h", expected_pc, pc);
        $fatal;
      end

      $display("PASS: halted/trapped at PC=%h", pc);
    end
  endtask

  // ------------------------------------------------------------
  // Program 1: ALU, immediates, LUI, AUIPC
  // ------------------------------------------------------------

  task automatic test_alu_and_immediates;
    logic [31:0] auipc_expected;
    begin
      start_program("ALU + immediates + LUI/AUIPC");

      emit(enc_lui(5'd1, 20'h12345));                 // x1 = 0x12345000
      emit(enc_addi(5'd1, 5'd1, 12'h678));            // x1 = 0x12345678

      auipc_expected = (prog_idx * 32'd4) + 32'h0000_2000;
      emit(enc_auipc(5'd21, 20'h00002));              // x21 = PC + 0x2000

      emit(enc_addi(5'd2, 5'd0, 12'hFFF));            // x2 = -1
      emit(enc_slti(5'd3, 5'd2, 12'h000));            // -1 < 0 = 1
      emit(enc_sltiu(5'd4, 5'd2, 12'h001));           // UINT_MAX < 1 = 0
      emit(enc_xori(5'd5, 5'd2, 12'h0FF));            // 0xFFFFFFFF ^ 0x0FF
      emit(enc_ori(5'd6, 5'd0, 12'h123));             // x6 = 0x123
      emit(enc_andi(5'd7, 5'd2, 12'h0F0));            // x7 = 0x0F0

      emit(enc_slli(5'd8, 5'd6, 5'd4));               // x8 = 0x1230
      emit(enc_srli(5'd9, 5'd2, 5'd4));               // x9 = 0x0FFFFFFF
      emit(enc_srai(5'd10, 5'd2, 5'd4));              // x10 = 0xFFFFFFFF

      emit(enc_r(5'd11, 5'd6, 5'd7, 3'b000, 7'b0000000)); // ADD
      emit(enc_r(5'd12, 5'd6, 5'd7, 3'b000, 7'b0100000)); // SUB
      emit(enc_r(5'd13, 5'd6, 5'd3, 3'b001, 7'b0000000)); // SLL
      emit(enc_r(5'd14, 5'd2, 5'd0, 3'b010, 7'b0000000)); // SLT
      emit(enc_r(5'd15, 5'd2, 5'd0, 3'b011, 7'b0000000)); // SLTU
      emit(enc_r(5'd16, 5'd6, 5'd7, 3'b100, 7'b0000000)); // XOR
      emit(enc_r(5'd17, 5'd2, 5'd3, 3'b101, 7'b0000000)); // SRL
      emit(enc_r(5'd18, 5'd2, 5'd3, 3'b101, 7'b0100000)); // SRA
      emit(enc_r(5'd19, 5'd6, 5'd7, 3'b110, 7'b0000000)); // OR
      emit(enc_r(5'd20, 5'd6, 5'd7, 3'b111, 7'b0000000)); // AND

      emit(enc_ebreak());

      run_until_halt(100);

      check_reg(1,  32'h1234_5678);
      check_reg(2,  32'hFFFF_FFFF);
      check_reg(3,  32'h0000_0001);
      check_reg(4,  32'h0000_0000);
      check_reg(5,  32'hFFFF_FF00);
      check_reg(6,  32'h0000_0123);
      check_reg(7,  32'h0000_00F0);
      check_reg(8,  32'h0000_1230);
      check_reg(9,  32'h0FFF_FFFF);
      check_reg(10, 32'hFFFF_FFFF);
      check_reg(11, 32'h0000_0213);
      check_reg(12, 32'h0000_0033);
      check_reg(13, 32'h0000_0246);
      check_reg(14, 32'h0000_0001);
      check_reg(15, 32'h0000_0000);
      check_reg(16, 32'h0000_01D3);
      check_reg(17, 32'h7FFF_FFFF);
      check_reg(18, 32'hFFFF_FFFF);
      check_reg(19, 32'h0000_01F3);
      check_reg(20, 32'h0000_0020);
      check_reg(21, auipc_expected);
    end
  endtask

  // ------------------------------------------------------------
  // Program 2: loads and stores
  // ------------------------------------------------------------

  task automatic test_load_store_all;
    begin
      start_program("loads/stores LB LH LW LBU LHU SB SH SW");

      emit(enc_addi(5'd1, 5'd0, 12'd64));             // base = 64
      emit(enc_addi(5'd2, 5'd0, 12'hFFF));            // x2 = -1
      emit(enc_sw(5'd2, 5'd1, 12'd0));                // mem[64] = FFFFFFFF

      emit(enc_lb(5'd3, 5'd1, 12'd0));                // signed byte -> FFFFFFFF
      emit(enc_lbu(5'd4, 5'd1, 12'd0));               // unsigned byte -> 000000FF
      emit(enc_lh(5'd5, 5'd1, 12'd0));                // signed half -> FFFFFFFF
      emit(enc_lhu(5'd6, 5'd1, 12'd0));               // unsigned half -> 0000FFFF
      emit(enc_lw(5'd7, 5'd1, 12'd0));                // word -> FFFFFFFF

      emit(enc_addi(5'd8, 5'd0, 12'd128));            // 0x80
      emit(enc_sb(5'd8, 5'd1, 12'd4));                // byte at 68
      emit(enc_lb(5'd9, 5'd1, 12'd4));                // signed -> FFFFFF80
      emit(enc_lbu(5'd10, 5'd1, 12'd4));              // unsigned -> 00000080

      emit(enc_lui(5'd11, 20'h0000B));                // 0x0000B000
      emit(enc_addi(5'd11, 5'd11, 12'hA55));          // 0x0000AA55
      emit(enc_sh(5'd11, 5'd1, 12'd8));               // low half at 72

      emit(enc_lui(5'd12, 20'h00001));                // 0x00001000
      emit(enc_addi(5'd12, 5'd12, 12'h234));          // 0x00001234
      emit(enc_sh(5'd12, 5'd1, 12'd10));              // high half at 74

      emit(enc_lh(5'd13, 5'd1, 12'd8));               // signed 0xAA55 -> FFFFAA55
      emit(enc_lhu(5'd14, 5'd1, 12'd8));              // unsigned -> 0000AA55
      emit(enc_lh(5'd15, 5'd1, 12'd10));              // signed 0x1234 -> 00001234
      emit(enc_lhu(5'd16, 5'd1, 12'd10));             // unsigned -> 00001234
      emit(enc_lw(5'd17, 5'd1, 12'd8));               // 1234AA55

      emit(enc_lw(5'd0, 5'd1, 12'd0));                // write to x0 must be ignored
      emit(enc_addi(5'd18, 5'd0, 12'd3));             // proves x0 still reads zero

      emit(enc_ebreak());

      run_until_halt(150);

      check_reg(3,  32'hFFFF_FFFF);
      check_reg(4,  32'h0000_00FF);
      check_reg(5,  32'hFFFF_FFFF);
      check_reg(6,  32'h0000_FFFF);
      check_reg(7,  32'hFFFF_FFFF);
      check_reg(9,  32'hFFFF_FF80);
      check_reg(10, 32'h0000_0080);
      check_reg(11, 32'h0000_AA55);
      check_reg(12, 32'h0000_1234);
      check_reg(13, 32'hFFFF_AA55);
      check_reg(14, 32'h0000_AA55);
      check_reg(15, 32'h0000_1234);
      check_reg(16, 32'h0000_1234);
      check_reg(17, 32'h1234_AA55);
      check_reg(18, 32'h0000_0003);

      check_dmem(16, 32'hFFFF_FFFF); // byte address 64 / 4 = word 16
      check_dmem(17, 32'h0000_0080); // byte store at 68
      check_dmem(18, 32'h1234_AA55); // byte address 72 / 4 = word 18
    end
  endtask

  // ------------------------------------------------------------
  // Program 3: branches, JAL, JALR
  // ------------------------------------------------------------

  task automatic test_branch_jump_corner_cases;
    int jal_pc;
    int jalr_pc;
    int target_addr;
    begin
      start_program("branches + jumps");

      emit(enc_addi(5'd1, 5'd0, 12'd5));              // x1 = 5
      emit(enc_addi(5'd2, 5'd0, 12'd5));              // x2 = 5
      emit(enc_addi(5'd3, 5'd0, 12'd7));              // x3 = 7
      emit(enc_addi(5'd4, 5'd0, 12'hFFF));            // x4 = -1 / UINT_MAX
      emit(enc_addi(5'd10, 5'd0, 12'd0));             // accumulator

      // Taken branches: skip the first addi, execute the second.
      emit(enc_b(5'd1, 5'd2, 3'b000, 13'd8));         // BEQ taken
      emit(enc_addi(5'd10, 5'd10, 12'd1));
      emit(enc_addi(5'd10, 5'd10, 12'd10));

      emit(enc_b(5'd1, 5'd3, 3'b001, 13'd8));         // BNE taken
      emit(enc_addi(5'd10, 5'd10, 12'd2));
      emit(enc_addi(5'd10, 5'd10, 12'd20));

      emit(enc_b(5'd1, 5'd3, 3'b100, 13'd8));         // BLT signed taken
      emit(enc_addi(5'd10, 5'd10, 12'd3));
      emit(enc_addi(5'd10, 5'd10, 12'd30));

      emit(enc_b(5'd3, 5'd1, 3'b101, 13'd8));         // BGE signed taken
      emit(enc_addi(5'd10, 5'd10, 12'd4));
      emit(enc_addi(5'd10, 5'd10, 12'd40));

      emit(enc_b(5'd1, 5'd4, 3'b110, 13'd8));         // BLTU taken: 5 < UINT_MAX
      emit(enc_addi(5'd10, 5'd10, 12'd5));
      emit(enc_addi(5'd10, 5'd10, 12'd50));

      emit(enc_b(5'd4, 5'd1, 3'b111, 13'd8));         // BGEU taken: UINT_MAX >= 5
      emit(enc_addi(5'd10, 5'd10, 12'd6));
      emit(enc_addi(5'd10, 5'd10, 12'd60));

      // Not-taken branches: execute the following addi.
      emit(enc_b(5'd1, 5'd3, 3'b000, 13'd8));         // BEQ not taken
      emit(enc_addi(5'd10, 5'd10, 12'd1));

      emit(enc_b(5'd1, 5'd2, 3'b001, 13'd8));         // BNE not taken
      emit(enc_addi(5'd10, 5'd10, 12'd2));

      emit(enc_b(5'd3, 5'd1, 3'b100, 13'd8));         // BLT not taken
      emit(enc_addi(5'd10, 5'd10, 12'd3));

      emit(enc_b(5'd1, 5'd3, 3'b101, 13'd8));         // BGE not taken
      emit(enc_addi(5'd10, 5'd10, 12'd4));

      emit(enc_b(5'd4, 5'd1, 3'b110, 13'd8));         // BLTU not taken
      emit(enc_addi(5'd10, 5'd10, 12'd5));

      emit(enc_b(5'd1, 5'd4, 3'b111, 13'd8));         // BGEU not taken
      emit(enc_addi(5'd10, 5'd10, 12'd6));

      // JAL skips one instruction and writes PC+4.
      jal_pc = prog_idx * 4;
      emit(enc_jal(5'd5, 21'd8));
      emit(enc_addi(5'd10, 5'd10, 12'd99));           // skipped
      emit(enc_addi(5'd10, 5'd10, 12'd7));            // target

      // JALR clears bit 0.
      target_addr = (prog_idx + 3) * 4;
      emit(enc_addi(5'd6, 5'd0, target_addr[11:0] + 12'd1)); // odd pointer
      jalr_pc = prog_idx * 4;
      emit(enc_jalr(5'd7, 5'd6, 12'd0));              // target = x6 & ~1
      emit(enc_addi(5'd10, 5'd10, 12'd99));           // skipped
      emit(enc_addi(5'd10, 5'd10, 12'd8));            // target

      emit(enc_ebreak());

      run_until_halt(250);

      check_reg(10, 32'd246);
      check_reg(5,  jal_pc + 32'd4);
      check_reg(7,  jalr_pc + 32'd4);
    end
  endtask

  // ------------------------------------------------------------
  // Program 4: x0 architectural behavior
  // ------------------------------------------------------------

  task automatic test_x0_behavior;
    begin
      start_program("x0 behavior");

      emit(enc_addi(5'd0, 5'd0, 12'd123));            // ignored
      emit(enc_lui(5'd0, 20'hFFFFF));                 // ignored
      emit(enc_jal(5'd0, 21'd8));                     // no link, skip next
      emit(enc_addi(5'd2, 5'd0, 12'd111));            // skipped
      emit(enc_addi(5'd1, 5'd0, 12'd5));              // should see x0 as 0

      emit(enc_sw(5'd1, 5'd0, 12'd0));                // mem[0] = 5
      emit(enc_lw(5'd0, 5'd0, 12'd0));                // ignored
      emit(enc_addi(5'd3, 5'd0, 12'd9));              // should still see x0 as 0

      emit(enc_ebreak());

      run_until_halt(100);

      check_reg(0, 32'h0000_0000);
      check_reg(1, 32'h0000_0005);
      check_reg(2, 32'h0000_0000);
      check_reg(3, 32'h0000_0009);
      check_dmem(0, 32'h0000_0005);
    end
  endtask

  // ------------------------------------------------------------
  // Program 5: FENCE and ECALL
  // ------------------------------------------------------------

  task automatic test_fence_and_ecall;
    begin
      start_program("FENCE behaves as no-op");

      emit(enc_fence());
      emit(enc_addi(5'd1, 5'd0, 12'd77));
      emit(enc_ebreak());

      run_until_halt(50);

      check_reg(1, 32'd77);

      start_program("ECALL traps");

      emit(enc_ecall());
      emit(enc_addi(5'd1, 5'd0, 12'd99));             // should not execute

      run_until_halt(20);

      expect_halted_at(32'h0000_0000);
      check_reg(1, 32'h0000_0000);
    end
  endtask

  // ------------------------------------------------------------
  // Trap helpers
  // ------------------------------------------------------------

  task automatic run_single_trap_program(
      input string name,
      input logic [31:0] insn,
      input logic [31:0] expected_pc
  );
    begin
      start_program(name);

      emit(insn);
      emit(enc_addi(5'd1, 5'd0, 12'd99));             // should not execute

      run_until_halt(20);

      expect_halted_at(expected_pc);
      check_reg(1, 32'h0000_0000);
    end
  endtask

  // ------------------------------------------------------------
  // Program 6: illegal instruction traps
  // ------------------------------------------------------------

  task automatic test_illegal_instructions;
    begin
      run_single_trap_program("illegal unknown opcode", 32'h0000_0000, 32'h0000_0000);

      run_single_trap_program("illegal R funct7",
          enc_r(5'd1, 5'd2, 5'd3, 3'b000, 7'b1111111), 32'h0000_0000);

      run_single_trap_program("illegal SLLI funct7",
          enc_i(OPCODE_OP_IMM, 5'd1, 5'd2, 3'b001, {7'b1111111, 5'd1}), 32'h0000_0000);

      run_single_trap_program("illegal SRLI/SRAI funct7",
          enc_i(OPCODE_OP_IMM, 5'd1, 5'd2, 3'b101, {7'b1111111, 5'd1}), 32'h0000_0000);

      run_single_trap_program("illegal load funct3",
          enc_i(OPCODE_LOAD, 5'd1, 5'd2, 3'b011, 12'd0), 32'h0000_0000);

      run_single_trap_program("illegal store funct3",
          enc_s(5'd1, 5'd2, 3'b011, 12'd0), 32'h0000_0000);

      run_single_trap_program("illegal branch funct3",
          enc_b(5'd1, 5'd2, 3'b010, 13'd8), 32'h0000_0000);

      run_single_trap_program("illegal JALR funct3",
          enc_i(OPCODE_JALR, 5'd1, 5'd2, 3'b001, 12'd0), 32'h0000_0000);

      run_single_trap_program("illegal MISC funct3",
          {12'h000, 5'd0, 3'b001, 5'd0, OPCODE_MISC}, 32'h0000_0000);

      run_single_trap_program("illegal SYSTEM CSR not implemented",
          {12'h000, 5'd1, 3'b001, 5'd2, OPCODE_SYSTEM}, 32'h0000_0000);

      run_single_trap_program("illegal SYSTEM unknown imm",
          {12'h123, 5'd0, 3'b000, 5'd0, OPCODE_SYSTEM}, 32'h0000_0000);
    end
  endtask

  // ------------------------------------------------------------
  // Program 7: misaligned traps
  // ------------------------------------------------------------

  task automatic test_misaligned_traps;
    begin
      start_program("misaligned LW trap");
      emit(enc_addi(5'd1, 5'd0, 12'd1));
      emit(enc_lw(5'd2, 5'd1, 12'd0));
      emit(enc_addi(5'd3, 5'd0, 12'd99));
      run_until_halt(20);
      expect_halted_at(32'h0000_0004);
      check_reg(2, 32'h0000_0000);
      check_reg(3, 32'h0000_0000);

      start_program("misaligned LH trap");
      emit(enc_addi(5'd1, 5'd0, 12'd1));
      emit(enc_lh(5'd2, 5'd1, 12'd0));
      emit(enc_addi(5'd3, 5'd0, 12'd99));
      run_until_halt(20);
      expect_halted_at(32'h0000_0004);
      check_reg(2, 32'h0000_0000);
      check_reg(3, 32'h0000_0000);

      start_program("misaligned SW trap");
      emit(enc_addi(5'd1, 5'd0, 12'd1));
      emit(enc_addi(5'd2, 5'd0, 12'd55));
      emit(enc_sw(5'd2, 5'd1, 12'd0));
      emit(enc_addi(5'd3, 5'd0, 12'd99));
      run_until_halt(30);
      expect_halted_at(32'h0000_0008);
      check_dmem(0, 32'h0000_0000);
      check_reg(3, 32'h0000_0000);

      start_program("misaligned instruction fetch trap via branch +2");
      emit(enc_addi(5'd1, 5'd0, 12'd0));
      emit(enc_b(5'd1, 5'd1, 3'b000, 13'd2));         // target PC = 0x00000006
      emit(enc_addi(5'd2, 5'd0, 12'd99));
      run_until_halt(30);
      expect_halted_at(32'h0000_0006);
      check_reg(2, 32'h0000_0000);
    end
  endtask

  // ------------------------------------------------------------
  // Program 8: long backward-branch stress test
  // ------------------------------------------------------------

  task automatic test_stress_loop;
    begin
      start_program("long backward branch stress loop");

      // x1 = counter = 0
      // x2 = limit = 100000
      // x3 = running sum
      emit(enc_addi(5'd1, 5'd0, 12'd0));
      emit(enc_lui(5'd2, 20'h00018));                 // 0x00018000 = 98304
      emit(enc_addi(5'd2, 5'd2, 12'd1696));           // 98304 + 1696 = 100000
      emit(enc_addi(5'd3, 5'd0, 12'd0));

      // loop:
      //   addi x1, x1, 1
      //   add  x3, x3, x1
      //   blt  x1, x2, loop
      emit(enc_addi(5'd1, 5'd1, 12'd1));
      emit(enc_r(5'd3, 5'd3, 5'd1, 3'b000, 7'b0000000));
      emit(enc_b(5'd1, 5'd2, 3'b100, 13'h1FF8));      // -8 bytes back to addi

      emit(enc_ebreak());

      run_until_halt(STRESS_ITERS * 4);

      check_reg(1, STRESS_ITERS[31:0]);
      check_reg(2, STRESS_ITERS[31:0]);
      check_reg(3, STRESS_SUM_EXPECTED);
    end
  endtask

  // ------------------------------------------------------------
  // Main
  // ------------------------------------------------------------

  initial begin
    done  = 1'b0;
    clk   = 1'b0;
    rst_n = 1'b0;
    stall = 1'b0;

    $display("Starting RV32 core functional regression...");

    test_alu_and_immediates();
    test_load_store_all();
    test_branch_jump_corner_cases();
    test_x0_behavior();
    test_fence_and_ecall();
    test_illegal_instructions();
    test_misaligned_traps();
    test_stress_loop();

    $display("");
    $display("============================================================");
    $display("ALL RV32 CORE REGRESSION TESTS PASSED");
    $display("============================================================");

    done = 1'b1;
    $finish;
  end

  initial begin
    // Large because the stress test intentionally runs many cycles.
    #20_000_000;
    if (!done) begin
      $display("TIMEOUT: tb_rv32_core_regression did not finish.");
      $fatal;
    end
  end

endmodule