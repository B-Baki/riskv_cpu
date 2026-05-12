`timescale 1ns / 1ps

module fiu #(
    parameter int DEPTH_WORDS = 1024,
    parameter string INIT_FILE = ""
) (
    input  logic [31:0] addr,
    output logic [31:0] instr,
    output logic        misaligned
);

  localparam int ADDR_WIDTH = $clog2(DEPTH_WORDS);

  logic [31:0] mem [0:DEPTH_WORDS-1];

  logic [ADDR_WIDTH-1:0] word_addr;

  assign word_addr = addr[ADDR_WIDTH+1:2];

  initial begin
    if (INIT_FILE != "") begin
      $display("FIU: loading instruction memory from %s", INIT_FILE);
      $readmemh(INIT_FILE, mem);
    end
  end

  always_comb begin
    misaligned = (addr[1:0] != 2'b00);
    instr      = mem[word_addr];
  end

endmodule