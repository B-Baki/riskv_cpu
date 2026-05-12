`timescale 1ns / 1ps

module decoder (
    input  logic [31:0] instr,

    output logic [4:0]  rs1_addr,
    output logic [4:0]  rs2_addr,
    output logic [4:0]  rd_addr,

    output logic [3:0]  alu_op,
    output logic [2:0]  imm_sel,

    output logic [1:0]  op_a_sel,
    output logic        op_b_sel,

    output logic        reg_write,
    output logic [1:0]  wb_sel,

    output logic        mem_read,
    output logic        mem_write,
    output logic [1:0]  mem_size,
    output logic        mem_unsigned,

    output logic        branch,
    output logic [2:0]  branch_op,

    output logic        jump,
    output logic        jalr,

    output logic        fence,
    output logic        ecall,
    output logic        ebreak,

    output logic        illegal_instr

// rs1_addr      which first source register to read
// rs2_addr      which second source register to read
// rd_addr       which destination register to write
// alu_op        what operation the ALU performs
// imm_sel       what immediate format to extract
// op_a_sel      what feeds ALU input A
// op_b_sel      what feeds ALU input B
// reg_write     whether to write rd
// wb_sel        what value gets written to rd
// mem_read      whether LSU reads memory
// mem_write     whether LSU writes memory
// mem_size      byte/halfword/word access size
// mem_unsigned  sign-extend or zero-extend load data
// branch        whether instruction is conditional branch
// branch_op     which branch comparison to perform
// jump          whether instruction is unconditional jump
// jalr          whether jump target is rs1+imm instead of pc+imm
// fence         FENCE instruction detected
// ecall         ECALL instruction detected
// ebreak        EBREAK instruction detected
// illegal_instr invalid/unsupported instruction detected
);

  // ---------------------------- 
  // RISC-V instruction fields
  // ----------------------------

  logic [6:0] opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;

  assign opcode = instr[6:0];
  assign rd_addr = instr[11:7];
  assign funct3 = instr[14:12];
  assign rs1_addr = instr[19:15];
  assign rs2_addr = instr[24:20];
  assign funct7 = instr[31:25];

  // ----------------------------
  // RV32I opcodes
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
  // Must match alu.sv
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
  // Must match imm_gen.sv
  // ----------------------------

  localparam logic [2:0] IMM_I     = 3'd0;
  localparam logic [2:0] IMM_S     = 3'd1;
  localparam logic [2:0] IMM_B     = 3'd2;
  localparam logic [2:0] IMM_U     = 3'd3;
  localparam logic [2:0] IMM_J     = 3'd4;
  localparam logic [2:0] IMM_SHAMT = 3'd5;

  // ----------------------------
  // ALU operand A selector
  // ----------------------------

  localparam logic [1:0] OP_A_RS1  = 2'd0;
  localparam logic [1:0] OP_A_PC   = 2'd1;
  localparam logic [1:0] OP_A_ZERO = 2'd2;

  // ----------------------------
  // ALU operand B selector
  // ----------------------------

  localparam logic OP_B_RS2 = 1'b0;
  localparam logic OP_B_IMM = 1'b1;

  // ----------------------------
  // Writeback selector
  // ----------------------------

  localparam logic [1:0] WB_ALU = 2'd0;
  localparam logic [1:0] WB_MEM = 2'd1;
  localparam logic [1:0] WB_PC4 = 2'd2;

  // ----------------------------
  // Memory size selector
  // ----------------------------

  localparam logic [1:0] MEM_BYTE = 2'd0;
  localparam logic [1:0] MEM_HALF = 2'd1;
  localparam logic [1:0] MEM_WORD = 2'd2;

  // ----------------------------
  // Branch operation selector
  // ----------------------------

  localparam logic [2:0] BR_NONE = 3'd0;
  localparam logic [2:0] BR_BEQ  = 3'd1;
  localparam logic [2:0] BR_BNE  = 3'd2;
  localparam logic [2:0] BR_BLT  = 3'd3;
  localparam logic [2:0] BR_BGE  = 3'd4;
  localparam logic [2:0] BR_BLTU = 3'd5;
  localparam logic [2:0] BR_BGEU = 3'd6;

  // ----------------------------
  // Main decode logic
  // ----------------------------

  always_comb begin
    // Safe defaults
    alu_op        = ALU_ADD;
    imm_sel       = IMM_I;

    op_a_sel      = OP_A_RS1;
    op_b_sel      = OP_B_RS2;

    reg_write     = 1'b0;
    wb_sel        = WB_ALU;

    mem_read      = 1'b0;
    mem_write     = 1'b0;
    mem_size      = MEM_WORD;
    mem_unsigned  = 1'b0;

    branch        = 1'b0;
    branch_op     = BR_NONE;

    jump          = 1'b0;
    jalr          = 1'b0;

    fence         = 1'b0;
    ecall         = 1'b0;
    ebreak        = 1'b0;

    illegal_instr = 1'b0;

    case (opcode)

      // ----------------------------
      // LUI
      // rd = imm_u
      // Implemented as:
      // ALU result = 0 + imm
      // ----------------------------
      OPCODE_LUI: begin
        reg_write = 1'b1;
        imm_sel   = IMM_U;
        op_a_sel  = OP_A_ZERO;
        op_b_sel  = OP_B_IMM;
        alu_op    = ALU_ADD;
        wb_sel    = WB_ALU;
      end

      // ----------------------------
      // AUIPC
      // rd = PC + imm_u
      // ----------------------------
      OPCODE_AUIPC: begin
        reg_write = 1'b1;
        imm_sel   = IMM_U;
        op_a_sel  = OP_A_PC;
        op_b_sel  = OP_B_IMM;
        alu_op    = ALU_ADD;
        wb_sel    = WB_ALU;
      end

      // ----------------------------
      // JAL
      // rd = PC + 4
      // PC = PC + imm_j
      // ----------------------------
      OPCODE_JAL: begin
        reg_write = 1'b1;
        imm_sel   = IMM_J;
        jump      = 1'b1;
        jalr      = 1'b0;
        wb_sel    = WB_PC4;
      end

      // ----------------------------
      // JALR
      // rd = PC + 4
      // PC = (rs1 + imm_i) & ~1
      // ----------------------------
      OPCODE_JALR: begin
        if (funct3 == 3'b000) begin
          reg_write = 1'b1;
          imm_sel   = IMM_I;
          op_a_sel  = OP_A_RS1;
          op_b_sel  = OP_B_IMM;
          alu_op    = ALU_ADD;
          jump      = 1'b1;
          jalr      = 1'b1;
          wb_sel    = WB_PC4;
        end else begin
          illegal_instr = 1'b1;
        end
      end

      // ----------------------------
      // Branches
      // beq, bne, blt, bge, bltu, bgeu
      // ----------------------------
      OPCODE_BRANCH: begin
        branch   = 1'b1;
        imm_sel  = IMM_B;
        op_a_sel = OP_A_RS1;
        op_b_sel = OP_B_RS2;

        case (funct3)
          3'b000: branch_op = BR_BEQ;
          3'b001: branch_op = BR_BNE;
          3'b100: branch_op = BR_BLT;
          3'b101: branch_op = BR_BGE;
          3'b110: branch_op = BR_BLTU;
          3'b111: branch_op = BR_BGEU;
          default: begin
            branch        = 1'b0;
            branch_op     = BR_NONE;
            illegal_instr = 1'b1;
          end
        endcase
      end

      // ----------------------------
      // Loads
      // lb, lh, lw, lbu, lhu
      // address = rs1 + imm_i
      // ----------------------------
      OPCODE_LOAD: begin
        reg_write = 1'b1;
        mem_read  = 1'b1;
        imm_sel   = IMM_I;
        op_a_sel  = OP_A_RS1;
        op_b_sel  = OP_B_IMM;
        alu_op    = ALU_ADD;
        wb_sel    = WB_MEM;

        case (funct3)
          3'b000: begin
            mem_size     = MEM_BYTE;  // LB
            mem_unsigned = 1'b0;
          end

          3'b001: begin
            mem_size     = MEM_HALF;  // LH
            mem_unsigned = 1'b0;
          end

          3'b010: begin
            mem_size     = MEM_WORD;  // LW
            mem_unsigned = 1'b0;
          end

          3'b100: begin
            mem_size     = MEM_BYTE;  // LBU
            mem_unsigned = 1'b1;
          end

          3'b101: begin
            mem_size     = MEM_HALF;  // LHU
            mem_unsigned = 1'b1;
          end

          default: begin
            reg_write     = 1'b0;
            mem_read      = 1'b0;
            illegal_instr = 1'b1;
          end
        endcase
      end

      // ----------------------------
      // Stores
      // sb, sh, sw
      // address = rs1 + imm_s
      // ----------------------------
      OPCODE_STORE: begin
        mem_write = 1'b1;
        imm_sel   = IMM_S;
        op_a_sel  = OP_A_RS1;
        op_b_sel  = OP_B_IMM;
        alu_op    = ALU_ADD;

        case (funct3)
          3'b000: mem_size = MEM_BYTE;  // SB
          3'b001: mem_size = MEM_HALF;  // SH
          3'b010: mem_size = MEM_WORD;  // SW

          default: begin
            mem_write     = 1'b0;
            illegal_instr = 1'b1;
          end
        endcase
      end

      // ----------------------------
      // I-type ALU
      // addi, slti, sltiu, xori, ori, andi,
      // slli, srli, srai
      // ----------------------------
      OPCODE_OP_IMM: begin
        reg_write = 1'b1;
        imm_sel   = IMM_I;
        op_a_sel  = OP_A_RS1;
        op_b_sel  = OP_B_IMM;
        wb_sel    = WB_ALU;

        case (funct3)
          3'b000: begin
            alu_op  = ALU_ADD;   // ADDI
            imm_sel = IMM_I;
          end

          3'b010: begin
            alu_op  = ALU_SLT;   // SLTI
            imm_sel = IMM_I;
          end

          3'b011: begin
            alu_op  = ALU_SLTU;  // SLTIU
            imm_sel = IMM_I;
          end

          3'b100: begin
            alu_op  = ALU_XOR;   // XORI
            imm_sel = IMM_I;
          end

          3'b110: begin
            alu_op  = ALU_OR;    // ORI
            imm_sel = IMM_I;
          end

          3'b111: begin
            alu_op  = ALU_AND;   // ANDI
            imm_sel = IMM_I;
          end

          3'b001: begin
            // SLLI
            if (funct7 == 7'b0000000) begin
              alu_op  = ALU_SLL;
              imm_sel = IMM_SHAMT;
            end else begin
              reg_write     = 1'b0;
              illegal_instr = 1'b1;
            end
          end

          3'b101: begin
            imm_sel = IMM_SHAMT;

            if (funct7 == 7'b0000000) begin
              alu_op = ALU_SRL;  // SRLI
            end else if (funct7 == 7'b0100000) begin
              alu_op = ALU_SRA;  // SRAI
            end else begin
              reg_write     = 1'b0;
              illegal_instr = 1'b1;
            end
          end

          default: begin
            reg_write     = 1'b0;
            illegal_instr = 1'b1;
          end
        endcase
      end

      // ----------------------------
      // R-type ALU
      // add, sub, sll, slt, sltu, xor, srl, sra, or, and
      // ----------------------------
      OPCODE_OP: begin
        reg_write = 1'b1;
        op_a_sel  = OP_A_RS1;
        op_b_sel  = OP_B_RS2;
        wb_sel    = WB_ALU;

        case (funct3)
          3'b000: begin
            if (funct7 == 7'b0000000) begin
              alu_op = ALU_ADD;  // ADD
            end else if (funct7 == 7'b0100000) begin
              alu_op = ALU_SUB;  // SUB
            end else begin
              reg_write     = 1'b0;
              illegal_instr = 1'b1;
            end
          end

          3'b001: begin
            if (funct7 == 7'b0000000) begin
              alu_op = ALU_SLL;  // SLL
            end else begin
              reg_write     = 1'b0;
              illegal_instr = 1'b1;
            end
          end

          3'b010: begin
            if (funct7 == 7'b0000000) begin
              alu_op = ALU_SLT;  // SLT
            end else begin
              reg_write     = 1'b0;
              illegal_instr = 1'b1;
            end
          end

          3'b011: begin
            if (funct7 == 7'b0000000) begin
              alu_op = ALU_SLTU;  // SLTU
            end else begin
              reg_write     = 1'b0;
              illegal_instr = 1'b1;
            end
          end

          3'b100: begin
            if (funct7 == 7'b0000000) begin
              alu_op = ALU_XOR;  // XOR
            end else begin
              reg_write     = 1'b0;
              illegal_instr = 1'b1;
            end
          end

          3'b101: begin
            if (funct7 == 7'b0000000) begin
              alu_op = ALU_SRL;  // SRL
            end else if (funct7 == 7'b0100000) begin
              alu_op = ALU_SRA;  // SRA
            end else begin
              reg_write     = 1'b0;
              illegal_instr = 1'b1;
            end
          end

          3'b110: begin
            if (funct7 == 7'b0000000) begin
              alu_op = ALU_OR;  // OR
            end else begin
              reg_write     = 1'b0;
              illegal_instr = 1'b1;
            end
          end

          3'b111: begin
            if (funct7 == 7'b0000000) begin
              alu_op = ALU_AND;  // AND
            end else begin
              reg_write     = 1'b0;
              illegal_instr = 1'b1;
            end
          end

          default: begin
            reg_write     = 1'b0;
            illegal_instr = 1'b1;
          end
        endcase
      end

      // ----------------------------
      // FENCE
      // For a simple single-core CPU, FENCE can be a no-op.
      // ----------------------------
      OPCODE_MISC: begin
        if (funct3 == 3'b000) begin
          fence = 1'b1;
        end else begin
          illegal_instr = 1'b1;
        end
      end

      // ----------------------------
      // SYSTEM
      // Only ECALL and EBREAK for now.
      // CSR instructions are not implemented here.
      // ----------------------------
      OPCODE_SYSTEM: begin
        if (funct3 == 3'b000) begin
          if (instr[31:20] == 12'h000) begin
            ecall = 1'b1;
          end else if (instr[31:20] == 12'h001) begin
            ebreak = 1'b1;
          end else begin
            illegal_instr = 1'b1;
          end
        end else begin
          illegal_instr = 1'b1;
        end
      end

      // ----------------------------
      // Unknown opcode
      // ----------------------------
      default: begin
        illegal_instr = 1'b1;
      end

    endcase
  end

endmodule