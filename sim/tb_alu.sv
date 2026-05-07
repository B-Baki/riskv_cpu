`timescale 1ns / 1ps

module tb_alu;

  logic [31:0] a;
  logic [31:0] b;
  logic [ 3:0] op;
  logic [31:0] y;

  alu dut (
      .a (a), //.module_port_name(local_signal_name)
      .b (b),
      .op(op),
      .y (y)
  );

  task check;
    input logic [31:0] test_a;
    input logic [31:0] test_b;
    input logic [ 3:0] test_op;
    input logic [31:0] expected;

    begin
      a  = test_a;
      b  = test_b;
      op = test_op;

      #1;

      if (y !== expected) begin
        $display("FAIL: a=%h b=%h op=%0d expected=%h got=%h",
                 a, b, op, expected, y);
        $fatal;
      end else begin
        $display("PASS: a=%h b=%h op=%0d y=%h",
                 a, b, op, y);
      end
    end
  endtask

  initial begin
    $display("Starting ALU tests...");

    // ADD
    check(32'd5, 32'd7, 4'd0, 32'd12);

    // SUB
    check(32'd10, 32'd3, 4'd1, 32'd7);

    // AND
    check(32'b1100, 32'b1010, 4'd2, 32'b1000);

    // OR
    check(32'b1100, 32'b1010, 4'd3, 32'b1110);

    // XOR
    check(32'b1100, 32'b1010, 4'd4, 32'b0110);

    // SLL
    check(32'd1, 32'd3, 4'd5, 32'd8);

    // SRL
    check(32'h8000_0000, 32'd1, 4'd6, 32'h4000_0000);

    // SRA
    check(32'h8000_0000, 32'd1, 4'd7, 32'hC000_0000);

    // SLT signed: -1 < 1 is true
    check(32'hFFFF_FFFF, 32'd1, 4'd8, 32'd1);

    // SLTU unsigned: 0xFFFF_FFFF < 1 is false
    check(32'hFFFF_FFFF, 32'd1, 4'd9, 32'd0);

    // SLTU unsigned: 1 < 0xFFFF_FFFF is true
    check(32'd1, 32'hFFFF_FFFF, 4'd9, 32'd1);

    // Default case
    check(32'd5, 32'd7, 4'd15, 32'd0);

    $display("All ALU tests passed.");
    $finish;
  end

endmodule