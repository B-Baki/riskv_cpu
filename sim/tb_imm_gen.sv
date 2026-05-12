`timescale 1ns / 1ps

module tb_imm_gen;

  logic        done;
  logic [31:0] instr;
  logic [ 2:0] imm_sel;
  logic [31:0] imm;

  localparam logic [2:0] IMM_I     = 3'd0;
  localparam logic [2:0] IMM_S     = 3'd1;
  localparam logic [2:0] IMM_B     = 3'd2;
  localparam logic [2:0] IMM_U     = 3'd3;
  localparam logic [2:0] IMM_J     = 3'd4;
  localparam logic [2:0] IMM_SHAMT = 3'd5;

  imm_gen dut (
      .instr   (instr),
      .imm_sel (imm_sel),
      .imm     (imm)
  );

  function automatic logic [31:0] make_i(input logic [11:0] imm12);
    begin
      make_i = {imm12, 5'd1, 3'b000, 5'd2, 7'b0010011};
    end
  endfunction

  function automatic logic [31:0] make_s(input logic [11:0] imm12);
    begin
      make_s = {imm12[11:5], 5'd5, 5'd2, 3'b010, imm12[4:0], 7'b0100011};
    end
  endfunction

  function automatic logic [31:0] make_b(input logic [12:0] imm13);
    begin
      make_b = {
        imm13[12],
        imm13[10:5],
        5'd2,
        5'd1,
        3'b000,
        imm13[4:1],
        imm13[11],
        7'b1100011
      };
    end
  endfunction

  function automatic logic [31:0] make_u(input logic [19:0] imm20);
    begin
      make_u = {imm20, 5'd2, 7'b0110111};
    end
  endfunction

  function automatic logic [31:0] make_j(input logic [20:0] imm21);
    begin
      make_j = {
        imm21[20],
        imm21[10:1],
        imm21[11],
        imm21[19:12],
        5'd1,
        7'b1101111
      };
    end
  endfunction

  function automatic logic [31:0] make_shamt(input logic [4:0] shamt);
    begin
      make_shamt = {7'b0000000, shamt, 5'd1, 3'b001, 5'd2, 7'b0010011};
    end
  endfunction

  task check;
    input string       name;
    input logic [31:0] test_instr;
    input logic [ 2:0] test_imm_sel;
    input logic [31:0] expected;

    begin
      instr   = test_instr;
      imm_sel = test_imm_sel;

      #1;

      if (imm !== expected) begin
        $display("FAIL: %s instr=%h imm_sel=%0d expected=%h got=%h",
                 name, instr, imm_sel, expected, imm);
        $fatal;
      end else begin
        $display("PASS: %s instr=%h imm=%h", name, instr, imm);
      end
    end
  endtask

  initial begin
    done = 1'b0;

    instr   = 32'h0000_0000;
    imm_sel = IMM_I;

    $display("Starting immediate generator tests...");

    // I-type positive: +5
    check("I +5", make_i(12'h005), IMM_I, 32'h0000_0005);

    // I-type negative: -1
    check("I -1", make_i(12'hFFF), IMM_I, 32'hFFFF_FFFF);

    // S-type positive: +12
    check("S +12", make_s(12'h00C), IMM_S, 32'h0000_000C);

    // S-type negative: -4
    check("S -4", make_s(12'hFFC), IMM_S, 32'hFFFF_FFFC);

    // B-type positive branch offset: +16
    check("B +16", make_b(13'h010), IMM_B, 32'h0000_0010);

    // B-type negative branch offset: -4
    // 13-bit two's-complement -4 = 13'h1FFC
    check("B -4", make_b(13'h1FFC), IMM_B, 32'hFFFF_FFFC);

    // U-type: 0x12345 << 12
    check("U 0x12345", make_u(20'h12345), IMM_U, 32'h1234_5000);

    // U-type with top bit set
    check("U 0xFFFFF", make_u(20'hFFFFF), IMM_U, 32'hFFFF_F000);

    // J-type positive jump offset: +2048
    check("J +2048", make_j(21'h00800), IMM_J, 32'h0000_0800);

    // J-type negative jump offset: -2048
    // 21-bit two's-complement -2048 = 21'h1FF800
    check("J -2048", make_j(21'h1FF800), IMM_J, 32'hFFFF_F800);

    // Shift amount: 31
    check("SHAMT 31", make_shamt(5'd31), IMM_SHAMT, 32'h0000_001F);

    // Default case
    check("DEFAULT", 32'hFFFF_FFFF, 3'd7, 32'h0000_0000);

    $display("All immediate generator tests passed.");
    done = 1'b1;
    $finish;
  end

  initial begin
    #1000;
    if (!done) begin
      $display("TIMEOUT: tb_imm_gen did not finish.");
      $fatal;
    end
  end

endmodule