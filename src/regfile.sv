`timescale 1ns / 1ps

module regfile (
    input logic clk,
    input logic rst_n, //active low reset

    input  logic [ 4:0] rs1_addr,
    input  logic [ 4:0] rs2_addr,
    output logic [31:0] rs1_data,
    output logic [31:0] rs2_data,

    input logic        we,
    input logic [ 4:0] rd_addr,
    input logic [31:0] rd_data
);

  logic [31:0] regs[31:0];

  integer i;

  //write
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      for (i = 0; i < 32; i = i + 1) begin
        regs[i] <= 32'h0000_0000;
      end
    end else begin
      if (we && (rd_addr != 5'd0)) begin
        regs[rd_addr] <= rd_data;
      end
    end
  end

  //read
  always_comb begin
    rs1_data = (rs1_addr == 5'd0) ? 32'h0000_0000 : regs[rs1_addr];
    rs2_data = (rs2_addr == 5'd0) ? 32'h0000_0000 : regs[rs2_addr];
  end

endmodule
