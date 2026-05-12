`timescale 1ns / 1ps

module rv32_core #(
    parameter logic [31:0] RESET_PC   = 32'h0000_0000,
    parameter int          IMEM_WORDS = 1024,
    parameter int          DMEM_WORDS = 1024,
    parameter string       IMEM_INIT_FILE = "/home/baki/projects/riskv_cpu/programs/core_basic.hex",
    parameter string       DMEM_INIT_FILE = ""
) (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        stall,

    output logic [31:0] pc,
    output logic [31:0] instr,

    output logic        halted,
    output logic        trap
);

  // ------------------------------------------------------------
  // Decoder outputs
  // ------------------------------------------------------------

  logic [4:0] rs1_addr;
  logic [4:0] rs2_addr;
  logic [4:0] rd_addr;

  logic [3:0] alu_op;
  logic [2:0] imm_sel;

  logic [1:0] op_a_sel;
  logic       op_b_sel;

  logic       reg_write;
  logic [1:0] wb_sel;

  logic       mem_read;
  logic       mem_write;
  logic [1:0] mem_size;
  logic       mem_unsigned;

  logic       branch;
  logic [2:0] branch_op;

  logic       jump;
  logic       jalr;

  logic       fence;
  logic       ecall;
  logic       ebreak;

  logic       illegal_instr;

  // ------------------------------------------------------------
  // Datapath signals
  // ------------------------------------------------------------

  logic [31:0] rs1_data;
  logic [31:0] rs2_data;

  logic [31:0] imm;

  logic [31:0] alu_a;
  logic [31:0] alu_b;
  logic [31:0] alu_y;

  logic [31:0] pc_next;
  logic [31:0] pc_plus4;

  logic        branch_taken;

  logic [31:0] load_data;
  logic [31:0] wb_data;

  logic        instr_misaligned;
  logic        data_misaligned;

  logic        data_access_misaligned;
  logic        halt_pending;
  logic        core_stall;

  // ------------------------------------------------------------
  // Constants matching decoder.sv
  // ------------------------------------------------------------

  localparam logic [1:0] OP_A_RS1  = 2'd0;
  localparam logic [1:0] OP_A_PC   = 2'd1;
  localparam logic [1:0] OP_A_ZERO = 2'd2;

  localparam logic       OP_B_RS2  = 1'b0;
  localparam logic       OP_B_IMM  = 1'b1;

  localparam logic [1:0] WB_ALU = 2'd0;
  localparam logic [1:0] WB_MEM = 2'd1;
  localparam logic [1:0] WB_PC4 = 2'd2;

  // ------------------------------------------------------------
  // Instruction fetch
  // ------------------------------------------------------------

  fiu #(
    .DEPTH_WORDS(IMEM_WORDS),
    .INIT_FILE  (IMEM_INIT_FILE)
) u_fiu (
      .addr       (pc),
      .instr      (instr),
      .misaligned (instr_misaligned)
  );

  // ------------------------------------------------------------
  // Decode
  // ------------------------------------------------------------

  decoder u_decoder (
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

  // ------------------------------------------------------------
  // Register file
  // ------------------------------------------------------------

  regfile u_regfile (
      .clk      (clk),
      .rst_n    (rst_n),

      .rs1_addr (rs1_addr),
      .rs2_addr (rs2_addr),
      .rs1_data (rs1_data),
      .rs2_data (rs2_data),

      .we       (reg_write && !halt_pending && !halted),
      .rd_addr  (rd_addr),
      .rd_data  (wb_data)
  );

  // ------------------------------------------------------------
  // Immediate generation
  // ------------------------------------------------------------

  imm_gen u_imm_gen (
      .instr   (instr),
      .imm_sel (imm_sel),
      .imm     (imm)
  );

  // ------------------------------------------------------------
  // ALU operand muxes
  // ------------------------------------------------------------

  always_comb begin
    case (op_a_sel)
      OP_A_RS1:  alu_a = rs1_data;
      OP_A_PC:   alu_a = pc;
      OP_A_ZERO: alu_a = 32'h0000_0000;
      default:   alu_a = rs1_data;
    endcase

    case (op_b_sel)
      OP_B_RS2: alu_b = rs2_data;
      OP_B_IMM: alu_b = imm;
      default:  alu_b = rs2_data;
    endcase
  end

  // ------------------------------------------------------------
  // ALU
  // ------------------------------------------------------------

  alu u_alu (
      .a  (alu_a),
      .b  (alu_b),
      .op (alu_op),
      .y  (alu_y)
  );

  // ------------------------------------------------------------
  // Branch comparator
  // ------------------------------------------------------------

  branch_comp u_branch_comp (
      .a         (rs1_data),
      .b         (rs2_data),
      .branch_op (branch_op),
      .taken     (branch_taken)
  );

  // ------------------------------------------------------------
  // Load/store unit
  // ------------------------------------------------------------

  lsu #(
    .DEPTH_WORDS(DMEM_WORDS),
    .INIT_FILE  (DMEM_INIT_FILE)
) u_lsu (
      .clk          (clk),

      .mem_read     (mem_read && !halt_pending && !halted),
      .mem_write    (mem_write && !halt_pending && !halted),

      .addr         (alu_y),
      .write_data   (rs2_data),

      .mem_size     (mem_size),
      .mem_unsigned (mem_unsigned),

      .read_data    (load_data),
      .misaligned   (data_misaligned)
  );

  assign data_access_misaligned = (mem_read || mem_write) && data_misaligned;

  // ------------------------------------------------------------
  // Writeback mux
  // ------------------------------------------------------------

  always_comb begin
    case (wb_sel)
      WB_ALU: wb_data = alu_y;
      WB_MEM: wb_data = load_data;
      WB_PC4: wb_data = pc_plus4;
      default: wb_data = alu_y;
    endcase
  end

  // ------------------------------------------------------------
  // Trap / halt logic
  // ------------------------------------------------------------

  assign halt_pending =
      illegal_instr        ||
      instr_misaligned     ||
      data_access_misaligned ||
      ecall                ||
      ebreak;

  assign trap = halt_pending || halted;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      halted <= 1'b0;
    end else if (halt_pending) begin
      halted <= 1'b1;
    end
  end

  assign core_stall = stall || halted || halt_pending;

  // ------------------------------------------------------------
  // Program counter
  // ------------------------------------------------------------

  pc_unit #(
      .RESET_PC(RESET_PC)
  ) u_pc_unit (
      .clk          (clk),
      .rst_n        (rst_n),

      .stall        (core_stall),

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

endmodule