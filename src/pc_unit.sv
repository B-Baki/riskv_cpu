`timescale 1ns / 1ps

module pc_unit #(
    parameter logic [31:0] RESET_PC = 32'h0000_0000
) (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        stall,

    input  logic        branch,
    input  logic        branch_taken,

    input  logic        jump,
    input  logic        jalr,

    input  logic [31:0] imm,
    input  logic [31:0] rs1_data,

    output logic [31:0] pc,
    output logic [31:0] pc_next,
    output logic [31:0] pc_plus4
);

  always_comb begin
    pc_plus4 = pc + 32'd4;

    if (jump && jalr) begin
      pc_next = (rs1_data + imm) & 32'hFFFF_FFFE;
    end else if (jump) begin
      pc_next = pc + imm;
    end else if (branch && branch_taken) begin
      pc_next = pc + imm;
    end else begin
      pc_next = pc_plus4;
    end
  end
  
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      pc <= RESET_PC;
    end else if (!stall) begin
      pc <= pc_next;
    end
  end

endmodule