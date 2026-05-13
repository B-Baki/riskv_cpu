`timescale 1ns / 1ps

module cmod_a7_top (
    input  logic       sysclk,
    input  logic [1:0] btn,
    output logic [1:0] led,
    output logic       led0_r,
    output logic       led0_g,
    output logic       led0_b
);

  logic rst_n;
  logic [7:0] rst_shift;

  (* keep = "true" *) logic [31:0] pc;
  (* keep = "true" *) logic [31:0] instr;
  (* keep = "true" *) logic [31:0] debug_x3;
  (* keep = "true" *) logic        halted;
  (* keep = "true" *) logic        trap;

  // Button 0 as active-high reset request.
  // rst_n becomes high only after several clean clock cycles.
  always_ff @(posedge sysclk) begin
    if (btn[0]) begin
      rst_shift <= 8'h00;
    end else begin
      rst_shift <= {rst_shift[6:0], 1'b1};
    end
  end

  assign rst_n = &rst_shift;

  (* DONT_TOUCH = "true" *)
  rv32_core #(
      .RESET_PC       (32'h0000_0000),
      .IMEM_WORDS     (64),
      .DMEM_WORDS     (64),
      .IMEM_INIT_FILE ("/home/baki/projects/riskv_cpu/programs/core_basic.hex"),
      .DMEM_INIT_FILE ("")
  ) u_core (
      .clk    (sysclk),
      .rst_n  (rst_n),
      .stall  (btn[1]),
      .pc     (pc),
      .instr  (instr),
      .halted (halted),
      .trap   (trap),
      .debug_x3 (debug_x3)
  );

  // Expected program:
  // 0x0000: addi x1, x0, 5
  // 0x0004: addi x2, x0, 7
  // 0x0008: add  x3, x1, x2
  // 0x000C: ebreak
  //
  // This does not prove x3 == 12 yet, but it proves the core fetched
  // through the whole program and halted at the expected ebreak.
    wire expected_ebreak =
      (pc == 32'h0000_000C) &&
      (instr == 32'h0010_0073);

  wire pass =
      halted &&
      expected_ebreak &&
      (debug_x3 == 32'd12);

  assign led[0] = halted;
  assign led[1] = pass;

  // RGB LED: red if trap somewhere unexpected, green if expected halt.
  assign led0_r = trap && !pass;
  assign led0_g = pass;
  assign led0_b = !rst_n;

endmodule