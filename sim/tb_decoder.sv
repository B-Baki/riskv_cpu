`timescale 1ns / 1ps

module tb_decoder;

  logic        done;
  logic [31:0] instr;

  logic [4:0]  rs1_addr;
  logic [4:0]  rs2_addr;
  logic [4:0]  rd_addr;

  logic [3:0]  alu_op;
  logic [2:0]  imm_sel;

  logic [1:0]  op_a_sel;
  logic        op_b_sel;

  logic        reg_write;
  logic [1:0]  wb_sel;

  logic        mem_read;
  logic        mem_write;
  logic [1:0]  mem_size;
  logic        mem_unsigned;

  logic        branch;
  logic [2:0]  branch_op;

  logic        jump;
  logic        jalr;

  logic        fence;
  logic        ecall;
  logic        ebreak;

  logic        illegal_instr;

  decoder dut (
      .instr         (instr),
      .rs1_addr     (rs1_addr),
      .rs2_addr     (rs2_addr),
      .rd_addr      (rd_addr),
      .alu_op       (alu_op),
      .imm_sel      (imm_sel),
      .op_a_sel     (op_a_sel),
      .op_b_sel     (op_b_sel),
      .reg_write    (reg_write),
      .wb_sel       (wb_sel),
      .mem_read     (mem_read),
      .mem_write    (mem_write),
      .mem_size     (mem_size),
      .mem_unsigned (mem_unsigned),
      .branch       (branch),
      .branch_op    (branch_op),
      .jump         (jump),
      .jalr         (jalr),
      .fence        (fence),
      .ecall        (ecall),
      .ebreak       (ebreak),
      .illegal_instr(illegal_instr)
  );

  // ----------------------------
  // Opcode constants
  // ----------------------------

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

  // ----------------------------
  // ALU operations
  // Must match decoder.sv and alu.sv
  // ----------------------------

  localparam logic [3:0] ALU_ADD  = 4'd0;
  localparam logic [3:0] ALU_SUB  = 4'd1;
  localparam logic [3:0] ALU_AND  = 4'd2;
  localparam logic [3:0] ALU_OR   = 4'd3;
  localparam logic [3:0] ALU_XOR  = 4'd4;
  localparam logic [3:0] ALU_SLL  = 4'd5;
  localparam logic [3:0] ALU_SRL  = 4'd6;
  localparam logic [3:0] ALU_SRA  = 4'd7;
  localparam logic [3:0] ALU_SLT  = 4'd8;
  localparam logic [3:0] ALU_SLTU = 4'd9;

  // ----------------------------
  // Immediate selector
  // Must match decoder.sv and imm_gen.sv
  // ----------------------------

  localparam logic [2:0] IMM_I     = 3'd0;
  localparam logic [2:0] IMM_S     = 3'd1;
  localparam logic [2:0] IMM_B     = 3'd2;
  localparam logic [2:0] IMM_U     = 3'd3;
  localparam logic [2:0] IMM_J     = 3'd4;
  localparam logic [2:0] IMM_SHAMT = 3'd5;

  // ----------------------------
  // Operand selectors
  // ----------------------------

  localparam logic [1:0] OP_A_RS1  = 2'd0;
  localparam logic [1:0] OP_A_PC   = 2'd1;
  localparam logic [1:0] OP_A_ZERO = 2'd2;

  localparam logic       OP_B_RS2  = 1'b0;
  localparam logic       OP_B_IMM  = 1'b1;

  // ----------------------------
  // Writeback selectors
  // ----------------------------

  localparam logic [1:0] WB_ALU = 2'd0;
  localparam logic [1:0] WB_MEM = 2'd1;
  localparam logic [1:0] WB_PC4 = 2'd2;

  // ----------------------------
  // Memory size selectors
  // ----------------------------

  localparam logic [1:0] MEM_BYTE = 2'd0;
  localparam logic [1:0] MEM_HALF = 2'd1;
  localparam logic [1:0] MEM_WORD = 2'd2;

  // ----------------------------
  // Branch selectors
  // ----------------------------

  localparam logic [2:0] BR_NONE = 3'd0;
  localparam logic [2:0] BR_BEQ  = 3'd1;
  localparam logic [2:0] BR_BNE  = 3'd2;
  localparam logic [2:0] BR_BLT  = 3'd3;
  localparam logic [2:0] BR_BGE  = 3'd4;
  localparam logic [2:0] BR_BLTU = 3'd5;
  localparam logic [2:0] BR_BGEU = 3'd6;

  // ----------------------------
  // Expected values
  // ----------------------------

  logic [3:0] exp_alu_op;
  logic [2:0] exp_imm_sel;

  logic [1:0] exp_op_a_sel;
  logic       exp_op_b_sel;

  logic       exp_reg_write;
  logic [1:0] exp_wb_sel;

  logic       exp_mem_read;
  logic       exp_mem_write;
  logic [1:0] exp_mem_size;
  logic       exp_mem_unsigned;

  logic       exp_branch;
  logic [2:0] exp_branch_op;

  logic       exp_jump;
  logic       exp_jalr;

  logic       exp_fence;
  logic       exp_ecall;
  logic       exp_ebreak;

  logic       exp_illegal_instr;

  // ----------------------------
  // Instruction builders
  // ----------------------------

  function automatic logic [31:0] make_r(
      input logic [6:0] funct7,
      input logic [4:0] rs2,
      input logic [4:0] rs1,
      input logic [2:0] funct3,
      input logic [4:0] rd
  );
    begin
      make_r = {funct7, rs2, rs1, funct3, rd, OPCODE_OP};
    end
  endfunction

  function automatic logic [31:0] make_i(
      input logic [11:0] imm12,
      input logic [4:0]  rs1,
      input logic [2:0]  funct3,
      input logic [4:0]  rd,
      input logic [6:0]  opcode
  );
    begin
      make_i = {imm12, rs1, funct3, rd, opcode};
    end
  endfunction

  function automatic logic [31:0] make_s(
      input logic [11:0] imm12,
      input logic [4:0]  rs2,
      input logic [4:0]  rs1,
      input logic [2:0]  funct3
  );
    begin
      make_s = {imm12[11:5], rs2, rs1, funct3, imm12[4:0], OPCODE_STORE};
    end
  endfunction

  function automatic logic [31:0] make_b(
      input logic [12:0] imm13,
      input logic [4:0]  rs2,
      input logic [4:0]  rs1,
      input logic [2:0]  funct3
  );
    begin
      make_b = {
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

  function automatic logic [31:0] make_u(
      input logic [19:0] imm20,
      input logic [4:0]  rd,
      input logic [6:0]  opcode
  );
    begin
      make_u = {imm20, rd, opcode};
    end
  endfunction

  function automatic logic [31:0] make_j(
      input logic [20:0] imm21,
      input logic [4:0]  rd
  );
    begin
      make_j = {
        imm21[20],
        imm21[10:1],
        imm21[11],
        imm21[19:12],
        rd,
        OPCODE_JAL
      };
    end
  endfunction

  function automatic logic [31:0] make_system(
      input logic [11:0] sys_imm
  );
    begin
      make_system = {sys_imm, 5'd0, 3'b000, 5'd0, OPCODE_SYSTEM};
    end
  endfunction

  // ----------------------------
  // Expected default state
  // Must match decoder.sv defaults
  // ----------------------------

  task automatic set_defaults;
    begin
      exp_alu_op        = ALU_ADD;
      exp_imm_sel       = IMM_I;

      exp_op_a_sel      = OP_A_RS1;
      exp_op_b_sel      = OP_B_RS2;

      exp_reg_write     = 1'b0;
      exp_wb_sel        = WB_ALU;

      exp_mem_read      = 1'b0;
      exp_mem_write     = 1'b0;
      exp_mem_size      = MEM_WORD;
      exp_mem_unsigned  = 1'b0;

      exp_branch        = 1'b0;
      exp_branch_op     = BR_NONE;

      exp_jump          = 1'b0;
      exp_jalr          = 1'b0;

      exp_fence         = 1'b0;
      exp_ecall         = 1'b0;
      exp_ebreak        = 1'b0;

      exp_illegal_instr = 1'b0;
    end
  endtask

  task automatic expect_eq(
      input string       signal_name,
      input logic [31:0] got,
      input logic [31:0] expected
  );
    begin
      if (got !== expected) begin
        $display("FAIL: %s expected=%h got=%h", signal_name, expected, got);
        $display("      instr=%h", instr);
        $fatal;
      end
    end
  endtask

  task automatic check_valid(
      input string       name,
      input logic [31:0] test_instr
  );
    begin
      instr = test_instr;
      #1;

      expect_eq({name, ".rs1_addr"}, rs1_addr, test_instr[19:15]);
      expect_eq({name, ".rs2_addr"}, rs2_addr, test_instr[24:20]);
      expect_eq({name, ".rd_addr"},  rd_addr,  test_instr[11:7]);

      expect_eq({name, ".alu_op"},        alu_op,        exp_alu_op);
      expect_eq({name, ".imm_sel"},       imm_sel,       exp_imm_sel);
      expect_eq({name, ".op_a_sel"},      op_a_sel,      exp_op_a_sel);
      expect_eq({name, ".op_b_sel"},      op_b_sel,      exp_op_b_sel);
      expect_eq({name, ".reg_write"},     reg_write,     exp_reg_write);
      expect_eq({name, ".wb_sel"},        wb_sel,        exp_wb_sel);
      expect_eq({name, ".mem_read"},      mem_read,      exp_mem_read);
      expect_eq({name, ".mem_write"},     mem_write,     exp_mem_write);
      expect_eq({name, ".mem_size"},      mem_size,      exp_mem_size);
      expect_eq({name, ".mem_unsigned"},  mem_unsigned,  exp_mem_unsigned);
      expect_eq({name, ".branch"},        branch,        exp_branch);
      expect_eq({name, ".branch_op"},     branch_op,     exp_branch_op);
      expect_eq({name, ".jump"},          jump,          exp_jump);
      expect_eq({name, ".jalr"},          jalr,          exp_jalr);
      expect_eq({name, ".fence"},         fence,         exp_fence);
      expect_eq({name, ".ecall"},         ecall,         exp_ecall);
      expect_eq({name, ".ebreak"},        ebreak,        exp_ebreak);
      expect_eq({name, ".illegal_instr"}, illegal_instr, exp_illegal_instr);

      $display("PASS: %s instr=%h", name, instr);
    end
  endtask

  task automatic check_illegal(
      input string       name,
      input logic [31:0] test_instr
  );
    begin
      instr = test_instr;
      #1;

      if (illegal_instr !== 1'b1) begin
        $display("FAIL: %s expected illegal_instr=1 got=%b instr=%h",
                 name, illegal_instr, instr);
        $fatal;
      end else begin
        $display("PASS: %s illegal instruction detected instr=%h", name, instr);
      end
    end
  endtask

  // ----------------------------
  // Main tests
  // ----------------------------

  initial begin
    done  = 1'b0;
    instr = 32'h0000_0000;

    $display("Starting decoder tests...");

    // ============================================================
    // R-type ALU instructions
    // ============================================================

    set_defaults();
    exp_reg_write = 1'b1;
    exp_alu_op    = ALU_ADD;
    exp_wb_sel    = WB_ALU;
    check_valid("R ADD", make_r(7'b0000000, 5'd2, 5'd1, 3'b000, 5'd3));

    set_defaults();
    exp_reg_write = 1'b1;
    exp_alu_op    = ALU_SUB;
    exp_wb_sel    = WB_ALU;
    check_valid("R SUB", make_r(7'b0100000, 5'd2, 5'd1, 3'b000, 5'd3));

    set_defaults();
    exp_reg_write = 1'b1;
    exp_alu_op    = ALU_SLL;
    exp_wb_sel    = WB_ALU;
    check_valid("R SLL", make_r(7'b0000000, 5'd2, 5'd1, 3'b001, 5'd3));

    set_defaults();
    exp_reg_write = 1'b1;
    exp_alu_op    = ALU_SLT;
    exp_wb_sel    = WB_ALU;
    check_valid("R SLT", make_r(7'b0000000, 5'd2, 5'd1, 3'b010, 5'd3));

    set_defaults();
    exp_reg_write = 1'b1;
    exp_alu_op    = ALU_SLTU;
    exp_wb_sel    = WB_ALU;
    check_valid("R SLTU", make_r(7'b0000000, 5'd2, 5'd1, 3'b011, 5'd3));

    set_defaults();
    exp_reg_write = 1'b1;
    exp_alu_op    = ALU_XOR;
    exp_wb_sel    = WB_ALU;
    check_valid("R XOR", make_r(7'b0000000, 5'd2, 5'd1, 3'b100, 5'd3));

    set_defaults();
    exp_reg_write = 1'b1;
    exp_alu_op    = ALU_SRL;
    exp_wb_sel    = WB_ALU;
    check_valid("R SRL", make_r(7'b0000000, 5'd2, 5'd1, 3'b101, 5'd3));

    set_defaults();
    exp_reg_write = 1'b1;
    exp_alu_op    = ALU_SRA;
    exp_wb_sel    = WB_ALU;
    check_valid("R SRA", make_r(7'b0100000, 5'd2, 5'd1, 3'b101, 5'd3));

    set_defaults();
    exp_reg_write = 1'b1;
    exp_alu_op    = ALU_OR;
    exp_wb_sel    = WB_ALU;
    check_valid("R OR", make_r(7'b0000000, 5'd2, 5'd1, 3'b110, 5'd3));

    set_defaults();
    exp_reg_write = 1'b1;
    exp_alu_op    = ALU_AND;
    exp_wb_sel    = WB_ALU;
    check_valid("R AND", make_r(7'b0000000, 5'd2, 5'd1, 3'b111, 5'd3));

    // ============================================================
    // I-type ALU instructions
    // ============================================================

    set_defaults();
    exp_reg_write = 1'b1;
    exp_op_b_sel  = OP_B_IMM;
    exp_imm_sel   = IMM_I;
    exp_alu_op    = ALU_ADD;
    exp_wb_sel    = WB_ALU;
    check_valid("I ADDI", make_i(12'h123, 5'd1, 3'b000, 5'd3, OPCODE_OP_IMM));

    set_defaults();
    exp_reg_write = 1'b1;
    exp_op_b_sel  = OP_B_IMM;
    exp_imm_sel   = IMM_I;
    exp_alu_op    = ALU_SLT;
    exp_wb_sel    = WB_ALU;
    check_valid("I SLTI", make_i(12'h123, 5'd1, 3'b010, 5'd3, OPCODE_OP_IMM));

    set_defaults();
    exp_reg_write = 1'b1;
    exp_op_b_sel  = OP_B_IMM;
    exp_imm_sel   = IMM_I;
    exp_alu_op    = ALU_SLTU;
    exp_wb_sel    = WB_ALU;
    check_valid("I SLTIU", make_i(12'h123, 5'd1, 3'b011, 5'd3, OPCODE_OP_IMM));

    set_defaults();
    exp_reg_write = 1'b1;
    exp_op_b_sel  = OP_B_IMM;
    exp_imm_sel   = IMM_I;
    exp_alu_op    = ALU_XOR;
    exp_wb_sel    = WB_ALU;
    check_valid("I XORI", make_i(12'h123, 5'd1, 3'b100, 5'd3, OPCODE_OP_IMM));

    set_defaults();
    exp_reg_write = 1'b1;
    exp_op_b_sel  = OP_B_IMM;
    exp_imm_sel   = IMM_I;
    exp_alu_op    = ALU_OR;
    exp_wb_sel    = WB_ALU;
    check_valid("I ORI", make_i(12'h123, 5'd1, 3'b110, 5'd3, OPCODE_OP_IMM));

    set_defaults();
    exp_reg_write = 1'b1;
    exp_op_b_sel  = OP_B_IMM;
    exp_imm_sel   = IMM_I;
    exp_alu_op    = ALU_AND;
    exp_wb_sel    = WB_ALU;
    check_valid("I ANDI", make_i(12'h123, 5'd1, 3'b111, 5'd3, OPCODE_OP_IMM));

    set_defaults();
    exp_reg_write = 1'b1;
    exp_op_b_sel  = OP_B_IMM;
    exp_imm_sel   = IMM_SHAMT;
    exp_alu_op    = ALU_SLL;
    exp_wb_sel    = WB_ALU;
    check_valid("I SLLI", make_i({7'b0000000, 5'd7}, 5'd1, 3'b001, 5'd3, OPCODE_OP_IMM));

    set_defaults();
    exp_reg_write = 1'b1;
    exp_op_b_sel  = OP_B_IMM;
    exp_imm_sel   = IMM_SHAMT;
    exp_alu_op    = ALU_SRL;
    exp_wb_sel    = WB_ALU;
    check_valid("I SRLI", make_i({7'b0000000, 5'd7}, 5'd1, 3'b101, 5'd3, OPCODE_OP_IMM));

    set_defaults();
    exp_reg_write = 1'b1;
    exp_op_b_sel  = OP_B_IMM;
    exp_imm_sel   = IMM_SHAMT;
    exp_alu_op    = ALU_SRA;
    exp_wb_sel    = WB_ALU;
    check_valid("I SRAI", make_i({7'b0100000, 5'd7}, 5'd1, 3'b101, 5'd3, OPCODE_OP_IMM));

    // ============================================================
    // Loads
    // ============================================================

    set_defaults();
    exp_reg_write = 1'b1;
    exp_mem_read  = 1'b1;
    exp_op_b_sel  = OP_B_IMM;
    exp_imm_sel   = IMM_I;
    exp_alu_op    = ALU_ADD;
    exp_wb_sel    = WB_MEM;
    exp_mem_size  = MEM_BYTE;
    exp_mem_unsigned = 1'b0;
    check_valid("LOAD LB", make_i(12'h010, 5'd1, 3'b000, 5'd3, OPCODE_LOAD));

    set_defaults();
    exp_reg_write = 1'b1;
    exp_mem_read  = 1'b1;
    exp_op_b_sel  = OP_B_IMM;
    exp_imm_sel   = IMM_I;
    exp_alu_op    = ALU_ADD;
    exp_wb_sel    = WB_MEM;
    exp_mem_size  = MEM_HALF;
    exp_mem_unsigned = 1'b0;
    check_valid("LOAD LH", make_i(12'h010, 5'd1, 3'b001, 5'd3, OPCODE_LOAD));

    set_defaults();
    exp_reg_write = 1'b1;
    exp_mem_read  = 1'b1;
    exp_op_b_sel  = OP_B_IMM;
    exp_imm_sel   = IMM_I;
    exp_alu_op    = ALU_ADD;
    exp_wb_sel    = WB_MEM;
    exp_mem_size  = MEM_WORD;
    exp_mem_unsigned = 1'b0;
    check_valid("LOAD LW", make_i(12'h010, 5'd1, 3'b010, 5'd3, OPCODE_LOAD));

    set_defaults();
    exp_reg_write = 1'b1;
    exp_mem_read  = 1'b1;
    exp_op_b_sel  = OP_B_IMM;
    exp_imm_sel   = IMM_I;
    exp_alu_op    = ALU_ADD;
    exp_wb_sel    = WB_MEM;
    exp_mem_size  = MEM_BYTE;
    exp_mem_unsigned = 1'b1;
    check_valid("LOAD LBU", make_i(12'h010, 5'd1, 3'b100, 5'd3, OPCODE_LOAD));

    set_defaults();
    exp_reg_write = 1'b1;
    exp_mem_read  = 1'b1;
    exp_op_b_sel  = OP_B_IMM;
    exp_imm_sel   = IMM_I;
    exp_alu_op    = ALU_ADD;
    exp_wb_sel    = WB_MEM;
    exp_mem_size  = MEM_HALF;
    exp_mem_unsigned = 1'b1;
    check_valid("LOAD LHU", make_i(12'h010, 5'd1, 3'b101, 5'd3, OPCODE_LOAD));

    // ============================================================
    // Stores
    // ============================================================

    set_defaults();
    exp_mem_write = 1'b1;
    exp_op_b_sel  = OP_B_IMM;
    exp_imm_sel   = IMM_S;
    exp_alu_op    = ALU_ADD;
    exp_mem_size  = MEM_BYTE;
    check_valid("STORE SB", make_s(12'h010, 5'd2, 5'd1, 3'b000));

    set_defaults();
    exp_mem_write = 1'b1;
    exp_op_b_sel  = OP_B_IMM;
    exp_imm_sel   = IMM_S;
    exp_alu_op    = ALU_ADD;
    exp_mem_size  = MEM_HALF;
    check_valid("STORE SH", make_s(12'h010, 5'd2, 5'd1, 3'b001));

    set_defaults();
    exp_mem_write = 1'b1;
    exp_op_b_sel  = OP_B_IMM;
    exp_imm_sel   = IMM_S;
    exp_alu_op    = ALU_ADD;
    exp_mem_size  = MEM_WORD;
    check_valid("STORE SW", make_s(12'h010, 5'd2, 5'd1, 3'b010));

    // ============================================================
    // Branches
    // ============================================================

    set_defaults();
    exp_branch    = 1'b1;
    exp_imm_sel   = IMM_B;
    exp_branch_op = BR_BEQ;
    check_valid("BR BEQ", make_b(13'h010, 5'd2, 5'd1, 3'b000));

    set_defaults();
    exp_branch    = 1'b1;
    exp_imm_sel   = IMM_B;
    exp_branch_op = BR_BNE;
    check_valid("BR BNE", make_b(13'h010, 5'd2, 5'd1, 3'b001));

    set_defaults();
    exp_branch    = 1'b1;
    exp_imm_sel   = IMM_B;
    exp_branch_op = BR_BLT;
    check_valid("BR BLT", make_b(13'h010, 5'd2, 5'd1, 3'b100));

    set_defaults();
    exp_branch    = 1'b1;
    exp_imm_sel   = IMM_B;
    exp_branch_op = BR_BGE;
    check_valid("BR BGE", make_b(13'h010, 5'd2, 5'd1, 3'b101));

    set_defaults();
    exp_branch    = 1'b1;
    exp_imm_sel   = IMM_B;
    exp_branch_op = BR_BLTU;
    check_valid("BR BLTU", make_b(13'h010, 5'd2, 5'd1, 3'b110));

    set_defaults();
    exp_branch    = 1'b1;
    exp_imm_sel   = IMM_B;
    exp_branch_op = BR_BGEU;
    check_valid("BR BGEU", make_b(13'h010, 5'd2, 5'd1, 3'b111));

    // ============================================================
    // U/J instructions
    // ============================================================

    set_defaults();
    exp_reg_write = 1'b1;
    exp_imm_sel   = IMM_U;
    exp_op_a_sel  = OP_A_ZERO;
    exp_op_b_sel  = OP_B_IMM;
    exp_alu_op    = ALU_ADD;
    exp_wb_sel    = WB_ALU;
    check_valid("LUI", make_u(20'h12345, 5'd3, OPCODE_LUI));

    set_defaults();
    exp_reg_write = 1'b1;
    exp_imm_sel   = IMM_U;
    exp_op_a_sel  = OP_A_PC;
    exp_op_b_sel  = OP_B_IMM;
    exp_alu_op    = ALU_ADD;
    exp_wb_sel    = WB_ALU;
    check_valid("AUIPC", make_u(20'h12345, 5'd3, OPCODE_AUIPC));

    set_defaults();
    exp_reg_write = 1'b1;
    exp_imm_sel   = IMM_J;
    exp_jump      = 1'b1;
    exp_jalr      = 1'b0;
    exp_wb_sel    = WB_PC4;
    check_valid("JAL", make_j(21'h00800, 5'd1));

    set_defaults();
    exp_reg_write = 1'b1;
    exp_imm_sel   = IMM_I;
    exp_op_a_sel  = OP_A_RS1;
    exp_op_b_sel  = OP_B_IMM;
    exp_alu_op    = ALU_ADD;
    exp_jump      = 1'b1;
    exp_jalr      = 1'b1;
    exp_wb_sel    = WB_PC4;
    check_valid("JALR", make_i(12'h004, 5'd5, 3'b000, 5'd1, OPCODE_JALR));

    // ============================================================
    // FENCE / SYSTEM
    // ============================================================

    set_defaults();
    exp_fence = 1'b1;
    check_valid("FENCE", {12'h000, 5'd0, 3'b000, 5'd0, OPCODE_MISC});

    set_defaults();
    exp_ecall = 1'b1;
    check_valid("ECALL", make_system(12'h000));

    set_defaults();
    exp_ebreak = 1'b1;
    check_valid("EBREAK", make_system(12'h001));

    // ============================================================
    // Illegal instruction checks
    // ============================================================

    check_illegal("ILLEGAL unknown opcode", 32'h0000_0000);

    check_illegal("ILLEGAL JALR funct3",
                  make_i(12'h000, 5'd1, 3'b001, 5'd2, OPCODE_JALR));

    check_illegal("ILLEGAL branch funct3",
                  make_b(13'h010, 5'd2, 5'd1, 3'b010));

    check_illegal("ILLEGAL load funct3",
                  make_i(12'h000, 5'd1, 3'b011, 5'd2, OPCODE_LOAD));

    check_illegal("ILLEGAL store funct3",
                  make_s(12'h000, 5'd2, 5'd1, 3'b011));

    check_illegal("ILLEGAL SLLI funct7",
                  make_i({7'b1111111, 5'd1}, 5'd1, 3'b001, 5'd2, OPCODE_OP_IMM));

    check_illegal("ILLEGAL SRLI/SRAI funct7",
                  make_i({7'b1111111, 5'd1}, 5'd1, 3'b101, 5'd2, OPCODE_OP_IMM));

    check_illegal("ILLEGAL R-type funct7",
                  make_r(7'b1111111, 5'd2, 5'd1, 3'b000, 5'd3));

    check_illegal("ILLEGAL MISC funct3",
                  {12'h000, 5'd0, 3'b001, 5'd0, OPCODE_MISC});

    check_illegal("ILLEGAL SYSTEM CSR not implemented",
                  {12'h000, 5'd1, 3'b001, 5'd2, OPCODE_SYSTEM});

    check_illegal("ILLEGAL SYSTEM unknown imm",
                  make_system(12'h123));

    $display("All decoder tests passed.");
    done = 1'b1;
    $finish;
  end

  initial begin
    #1000;
    if (!done) begin
      $display("TIMEOUT: tb_decoder did not finish.");
      $fatal;
    end
  end

endmodule