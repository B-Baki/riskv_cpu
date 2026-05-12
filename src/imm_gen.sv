`timescale 1ns / 1ps

module imm_gen (
    input  logic [31:0] instr,
    input  logic [2:0]  imm_sel,
    output logic [31:0] imm
);

  localparam logic [2:0] IMM_I     = 3'd0;
  localparam logic [2:0] IMM_S     = 3'd1;
  localparam logic [2:0] IMM_B     = 3'd2;
  localparam logic [2:0] IMM_U     = 3'd3;
  localparam logic [2:0] IMM_J     = 3'd4;
  localparam logic [2:0] IMM_SHAMT = 3'd5;

  always_comb begin
    case (imm_sel)

      // I-type:
      // imm[11:0] = instr[31:20]
      //
      // Used by:
      // addi, slti, sltiu, xori, ori, andi
      // lb, lh, lw, lbu, lhu
      // jalr
      IMM_I: begin
        imm = {{20{instr[31]}}, instr[31:20]};
      end

      // S-type:
      // imm[11:5] = instr[31:25]
      // imm[4:0]  = instr[11:7]
      //
      // Used by:
      // sb, sh, sw
      IMM_S: begin
        imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
      end

      // B-type:
      // imm[12]   = instr[31]
      // imm[10:5] = instr[30:25]
      // imm[4:1]  = instr[11:8]
      // imm[11]   = instr[7]
      // imm[0]    = 0
      //
      // Used by:
      // beq, bne, blt, bge, bltu, bgeu
      IMM_B: begin
        imm = {{19{instr[31]}},
               instr[31],
               instr[7],
               instr[30:25],
               instr[11:8],
               1'b0};
      end

      // U-type:
      // imm[31:12] = instr[31:12]
      // imm[11:0]  = 0
      //
      // Used by:
      // lui, auipc
      IMM_U: begin
        imm = {instr[31:12], 12'b0000_0000_0000};
      end

      // J-type:
      // imm[20]    = instr[31]
      // imm[10:1]  = instr[30:21]
      // imm[11]    = instr[20]
      // imm[19:12] = instr[19:12]
      // imm[0]     = 0
      //
      // Used by:
      // jal
      IMM_J: begin
        imm = {{11{instr[31]}},
               instr[31],
               instr[19:12],
               instr[20],
               instr[30:21],
               1'b0};
      end

      // Shift-immediate helper:
      // shamt = instr[24:20]
      //
      // Used by:
      // slli, srli, srai
      //
      // In RV32I, shift amount is 5 bits.
      IMM_SHAMT: begin
        imm = {27'b0, instr[24:20]};
      end

      default: begin
        imm = 32'h0000_0000;
      end

    endcase
  end

endmodule