`timescale 1ns / 1ps

module tb_branch_comp;

  logic        done;

  logic [31:0] a;
  logic [31:0] b;
  logic [ 2:0] branch_op;
  logic        taken;

  localparam logic [2:0] BR_NONE = 3'd0;
  localparam logic [2:0] BR_BEQ  = 3'd1;
  localparam logic [2:0] BR_BNE  = 3'd2;
  localparam logic [2:0] BR_BLT  = 3'd3;
  localparam logic [2:0] BR_BGE  = 3'd4;
  localparam logic [2:0] BR_BLTU = 3'd5;
  localparam logic [2:0] BR_BGEU = 3'd6;

  branch_comp dut (
      .a         (a),
      .b         (b),
      .branch_op (branch_op),
      .taken     (taken)
  );

  task automatic check;
    input string       name;
    input logic [31:0] test_a;
    input logic [31:0] test_b;
    input logic [ 2:0] test_branch_op;
    input logic        expected_taken;

    begin
      a         = test_a;
      b         = test_b;
      branch_op = test_branch_op;

      #1;

      if (taken !== expected_taken) begin
        $display("FAIL: %s a=%h b=%h branch_op=%0d expected=%b got=%b",
                 name, a, b, branch_op, expected_taken, taken);
        $fatal;
      end else begin
        $display("PASS: %s a=%h b=%h branch_op=%0d taken=%b",
                 name, a, b, branch_op, taken);
      end
    end
  endtask

  initial begin
    done = 1'b0;

    a         = 32'h0000_0000;
    b         = 32'h0000_0000;
    branch_op = BR_NONE;

    $display("Starting branch comparator tests...");

    // ------------------------------------------------------------
    // BR_NONE
    // ------------------------------------------------------------
    check("BR_NONE equal",     32'd5, 32'd5, BR_NONE, 1'b0);
    check("BR_NONE not equal", 32'd5, 32'd7, BR_NONE, 1'b0);

    // ------------------------------------------------------------
    // BEQ: branch if equal
    // ------------------------------------------------------------
    check("BEQ equal",     32'd5, 32'd5, BR_BEQ, 1'b1);
    check("BEQ not equal", 32'd5, 32'd7, BR_BEQ, 1'b0);

    // ------------------------------------------------------------
    // BNE: branch if not equal
    // ------------------------------------------------------------
    check("BNE equal",     32'd5, 32'd5, BR_BNE, 1'b0);
    check("BNE not equal", 32'd5, 32'd7, BR_BNE, 1'b1);

    // ------------------------------------------------------------
    // BLT: signed less than
    // ------------------------------------------------------------
    check("BLT signed 5 < 7",
          32'd5, 32'd7, BR_BLT, 1'b1);

    check("BLT signed 7 < 5 false",
          32'd7, 32'd5, BR_BLT, 1'b0);

    check("BLT signed -1 < 1",
          32'hFFFF_FFFF, 32'd1, BR_BLT, 1'b1);

    check("BLT signed 1 < -1 false",
          32'd1, 32'hFFFF_FFFF, BR_BLT, 1'b0);

    check("BLT signed equal false",
          32'd5, 32'd5, BR_BLT, 1'b0);

    // ------------------------------------------------------------
    // BGE: signed greater than or equal
    // ------------------------------------------------------------
    check("BGE signed 7 >= 5",
          32'd7, 32'd5, BR_BGE, 1'b1);

    check("BGE signed 5 >= 7 false",
          32'd5, 32'd7, BR_BGE, 1'b0);

    check("BGE signed -1 >= 1 false",
          32'hFFFF_FFFF, 32'd1, BR_BGE, 1'b0);

    check("BGE signed 1 >= -1",
          32'd1, 32'hFFFF_FFFF, BR_BGE, 1'b1);

    check("BGE signed equal true",
          32'd5, 32'd5, BR_BGE, 1'b1);

    // ------------------------------------------------------------
    // BLTU: unsigned less than
    // ------------------------------------------------------------
    check("BLTU unsigned 5 < 7",
          32'd5, 32'd7, BR_BLTU, 1'b1);

    check("BLTU unsigned 7 < 5 false",
          32'd7, 32'd5, BR_BLTU, 1'b0);

    check("BLTU unsigned 0xFFFFFFFF < 1 false",
          32'hFFFF_FFFF, 32'd1, BR_BLTU, 1'b0);

    check("BLTU unsigned 1 < 0xFFFFFFFF",
          32'd1, 32'hFFFF_FFFF, BR_BLTU, 1'b1);

    check("BLTU unsigned equal false",
          32'd5, 32'd5, BR_BLTU, 1'b0);

    // ------------------------------------------------------------
    // BGEU: unsigned greater than or equal
    // ------------------------------------------------------------
    check("BGEU unsigned 7 >= 5",
          32'd7, 32'd5, BR_BGEU, 1'b1);

    check("BGEU unsigned 5 >= 7 false",
          32'd5, 32'd7, BR_BGEU, 1'b0);

    check("BGEU unsigned 0xFFFFFFFF >= 1",
          32'hFFFF_FFFF, 32'd1, BR_BGEU, 1'b1);

    check("BGEU unsigned 1 >= 0xFFFFFFFF false",
          32'd1, 32'hFFFF_FFFF, BR_BGEU, 1'b0);

    check("BGEU unsigned equal true",
          32'd5, 32'd5, BR_BGEU, 1'b1);

    // ------------------------------------------------------------
    // Default / invalid branch_op
    // ------------------------------------------------------------
    check("invalid branch_op 7",
          32'd5, 32'd5, 3'd7, 1'b0);

    $display("All branch comparator tests passed.");
    done = 1'b1;
    $finish;
  end

  initial begin
    #1000;
    if (!done) begin
      $display("TIMEOUT: tb_branch_comp did not finish.");
      $fatal;
    end
  end

endmodule