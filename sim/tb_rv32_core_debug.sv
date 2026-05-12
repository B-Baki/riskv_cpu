`timescale 1ns / 1ps

module tb_rv32_core_debug;

  localparam int IMEM_WORDS = 256;
  localparam int DMEM_WORDS = 256;
  localparam int MAX_CYCLES = 200;

  logic        clk;
  logic        rst_n;
  logic        stall;

  logic [31:0] pc;
  logic [31:0] instr;
  logic        halted;
  logic        trap;

  int cycle;
  int i;

  // Snapshot signals for the instruction being executed.
  logic [31:0] trace_pc;
  logic [31:0] trace_instr;
  logic [4:0]  trace_rs1_addr;
  logic [4:0]  trace_rs2_addr;
  logic [4:0]  trace_rd_addr;
  logic [31:0] trace_rs1_data;
  logic [31:0] trace_rs2_data;
  logic [31:0] trace_imm;
  logic [31:0] trace_alu_y;
  logic [31:0] trace_wb_data;
  logic [31:0] trace_load_data;

  logic        trace_reg_write;
  logic        trace_mem_read;
  logic        trace_mem_write;
  logic        trace_branch;
  logic        trace_branch_taken;
  logic        trace_jump;
  logic        trace_jalr;
  logic        trace_halt_pending;
  logic        trace_illegal_instr;
  logic        trace_ecall;
  logic        trace_ebreak;
  logic        trace_instr_misaligned;
  logic        trace_data_misaligned;

  rv32_core #(
      .RESET_PC       (32'h0000_0000),
      .IMEM_WORDS     (IMEM_WORDS),
      .DMEM_WORDS     (DMEM_WORDS),
      .IMEM_INIT_FILE ("/home/baki/projects/riskv_cpu/programs/core_basic.hex"),
      .DMEM_INIT_FILE ("")
  ) dut (
      .clk    (clk),
      .rst_n  (rst_n),
      .stall  (stall),
      .pc     (pc),
      .instr  (instr),
      .halted (halted),
      .trap   (trap)
  );

  always begin
    #5 clk = ~clk;
  end

  task automatic sample_current_instruction;
    begin
      trace_pc               = pc;
      trace_instr            = instr;

      trace_rs1_addr         = dut.rs1_addr;
      trace_rs2_addr         = dut.rs2_addr;
      trace_rd_addr          = dut.rd_addr;

      trace_rs1_data         = dut.rs1_data;
      trace_rs2_data         = dut.rs2_data;
      trace_imm              = dut.imm;
      trace_alu_y            = dut.alu_y;
      trace_wb_data          = dut.wb_data;
      trace_load_data        = dut.load_data;

      trace_reg_write        = dut.reg_write && !dut.halt_pending && !halted;
      trace_mem_read         = dut.mem_read && !dut.halt_pending && !halted;
      trace_mem_write        = dut.mem_write && !dut.halt_pending && !halted;

      trace_branch           = dut.branch;
      trace_branch_taken     = dut.branch_taken;
      trace_jump             = dut.jump;
      trace_jalr             = dut.jalr;

      trace_halt_pending     = dut.halt_pending;
      trace_illegal_instr    = dut.illegal_instr;
      trace_ecall            = dut.ecall;
      trace_ebreak           = dut.ebreak;
      trace_instr_misaligned = dut.instr_misaligned;
      trace_data_misaligned  = dut.data_access_misaligned;
    end
  endtask

  task automatic print_current_instruction;
    begin
      $display("");
      $display("CYCLE %0d", cycle);
      $display("  PC=%h INSTR=%h", trace_pc, trace_instr);
      $display("  rs1=x%0d value=%h | rs2=x%0d value=%h | rd=x%0d",
               trace_rs1_addr, trace_rs1_data,
               trace_rs2_addr, trace_rs2_data,
               trace_rd_addr);
      $display("  imm=%h alu_y=%h wb_data=%h load_data=%h",
               trace_imm, trace_alu_y, trace_wb_data, trace_load_data);

      if (trace_reg_write) begin
        $display("  REG WRITE: x%0d <= %h", trace_rd_addr, trace_wb_data);
      end

      if (trace_mem_read) begin
        $display("  MEM READ : addr=%h data=%h", trace_alu_y, trace_load_data);
      end

      if (trace_mem_write) begin
        $display("  MEM WRITE: addr=%h data=%h", trace_alu_y, trace_rs2_data);
      end

      if (trace_branch) begin
        $display("  BRANCH: taken=%b target_candidate=%h",
                 trace_branch_taken, trace_pc + trace_imm);
      end

      if (trace_jump && !trace_jalr) begin
        $display("  JAL: target=%h return_address=%h",
                 trace_pc + trace_imm, trace_pc + 32'd4);
      end

      if (trace_jump && trace_jalr) begin
        $display("  JALR: target=%h return_address=%h",
                 (trace_rs1_data + trace_imm) & 32'hFFFF_FFFE,
                 trace_pc + 32'd4);
      end

      if (trace_halt_pending) begin
        $display("  HALT/TRAP PENDING");
        $display("    illegal_instr=%b ecall=%b ebreak=%b instr_misaligned=%b data_misaligned=%b",
                 trace_illegal_instr,
                 trace_ecall,
                 trace_ebreak,
                 trace_instr_misaligned,
                 trace_data_misaligned);
      end
    end
  endtask

  task automatic dump_registers;
    begin
      $display("");
      $display("============================================================");
      $display("REGISTER FILE DUMP");
      $display("============================================================");

      for (i = 0; i < 32; i = i + 1) begin
        $display("x%0d = %h", i, dut.u_regfile.regs[i]);
      end
    end
  endtask

  task automatic dump_data_memory;
    input int words_to_dump;
    begin
      $display("");
      $display("============================================================");
      $display("DATA MEMORY DUMP");
      $display("============================================================");

      for (i = 0; i < words_to_dump; i = i + 1) begin
        $display("mem[%0d] byte_addr=%h word=%h",
                 i, i * 4, dut.u_lsu.mem[i]);
      end
    end
  endtask

  initial begin
    clk   = 1'b0;
    rst_n = 1'b0;
    stall = 1'b0;
    cycle = 0;

    $display("Starting RV32 core visual/debug run...");

    // Optional: clear data memory before running.
    for (i = 0; i < DMEM_WORDS; i = i + 1) begin
      dut.u_lsu.mem[i] = 32'h0000_0000;
    end

    // Hold reset for a couple cycles.
    repeat (2) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;

    while (!halted && cycle < MAX_CYCLES) begin
      @(negedge clk);
      sample_current_instruction();

      @(posedge clk);
      #1;
      print_current_instruction();

      cycle = cycle + 1;
    end

    if (!halted) begin
      $display("ERROR: core did not halt within %0d cycles", MAX_CYCLES);
      $fatal;
    end

    dump_registers();
    dump_data_memory(32);

    $display("");
    $display("Debug run finished.");
    $finish;
  end

endmodule