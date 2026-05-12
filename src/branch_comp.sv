`timescale 1ns / 1ps

module branch_comp (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [2:0]  branch_op,
    output logic        taken
);

  localparam logic [2:0] BR_NONE = 3'd0;
  localparam logic [2:0] BR_BEQ  = 3'd1;
  localparam logic [2:0] BR_BNE  = 3'd2;
  localparam logic [2:0] BR_BLT  = 3'd3;
  localparam logic [2:0] BR_BGE  = 3'd4;
  localparam logic [2:0] BR_BLTU = 3'd5;
  localparam logic [2:0] BR_BGEU = 3'd6;

  always_comb begin
    case (branch_op)

      BR_BEQ: begin
        taken = (a == b);
      end

      BR_BNE: begin
        taken = (a != b);
      end

      BR_BLT: begin
        taken = ($signed(a) < $signed(b));
      end

      BR_BGE: begin
        taken = ($signed(a) >= $signed(b));
      end

      BR_BLTU: begin
        taken = (a < b);
      end

      BR_BGEU: begin
        taken = (a >= b);
      end

      BR_NONE: begin
        taken = 1'b0;
      end

      default: begin
        taken = 1'b0;
      end

    endcase
  end

endmodule