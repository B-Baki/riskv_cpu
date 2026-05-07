`timescale 1ns / 1ps

module tb_regfile;
  logic        clk;
  logic        rst_n;

  logic [ 4:0] rs1_addr;
  logic [ 4:0] rs2_addr;
  logic [31:0] rs1_data;
  logic [31:0] rs2_data;

  logic        we;
  logic [ 4:0] rd_addr;
  logic [31:0] rd_data;


  logic done;

  regfile dut (
      .clk     (clk),
      .rst_n   (rst_n),
      .rs1_addr(rs1_addr),
      .rs2_addr(rs2_addr),
      .rs1_data(rs1_data),
      .rs2_data(rs2_data),
      .we      (we),
      .rd_addr (rd_addr),
      .rd_data (rd_data)
  );

  always begin
    #5 clk = ~clk;
  end

  task write_reg;
    input logic [4:0] addr;
    input logic [31:0] data;

    begin
      @(negedge clk);
      we      = 1'b1;
      rd_addr = addr;
      rd_data = data;

      @(posedge clk);
      #1;

      we      = 1'b0;
      rd_addr = 5'd0;
      rd_data = 32'h0000_0000;
    end
  endtask

  task check_read;
    input logic [4:0] addr1;
    input logic [31:0] expected1;
    input logic [4:0] addr2;
    input logic [31:0] expected2;

    begin
      rs1_addr = addr1;
      rs2_addr = addr2;

      #1;

      if ((rs1_data !== expected1) || (rs2_data !== expected2)) begin
        $display("FAIL: rs1_addr=%0d expected1=%h got1=%h | rs2_addr=%0d expected2=%h got2=%h",
                 addr1, expected1, rs1_data, addr2, expected2, rs2_data);
        $fatal;
      end else begin
        $display("PASS: rs1_addr=%0d data1=%h | rs2_addr=%0d data2=%h", addr1, rs1_data, addr2,
                 rs2_data);
      end
    end
  endtask

  initial begin
    $display("Starting register file tests...");

    clk      = 1'b0;
    rst_n    = 1'b0;
    rs1_addr = 5'd0;
    rs2_addr = 5'd0;
    we       = 1'b0;
    rd_addr  = 5'd0;
    rd_data  = 32'h0000_0000;
    done = 1'b0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;
    #1;

    // After reset, registers should read as zero.
    check_read(5'd0, 32'h0000_0000, 5'd1, 32'h0000_0000);

    // Write x1 and x2.
    write_reg(5'd1, 32'h0000_1234);
    write_reg(5'd2, 32'hDEAD_BEEF);

    // Read two registers at the same time.
    check_read(5'd1, 32'h0000_1234, 5'd2, 32'hDEAD_BEEF);

    // Try to write x0. It must stay zero.
    write_reg(5'd0, 32'hFFFF_FFFF);
    check_read(5'd0, 32'h0000_0000, 5'd1, 32'h0000_1234);

    // Overwrite x1.
    write_reg(5'd1, 32'hCAFE_BABE);
    check_read(5'd1, 32'hCAFE_BABE, 5'd2, 32'hDEAD_BEEF);

    // Make sure write enable actually matters.
    @(negedge clk);
    we      = 1'b0;
    rd_addr = 5'd3;
    rd_data = 32'h1111_2222;

    @(posedge clk);
    #1;

    check_read(5'd3, 32'h0000_0000, 5'd0, 32'h0000_0000);


    //robust reset

    // Write random values.
    write_reg(5'd4, 32'hAAAA_5555);
    write_reg(5'd5, 32'h1234_5678);
    check_read(5'd4, 32'hAAAA_5555, 5'd5, 32'h1234_5678);

    // Assert active-low reset again.
    @(negedge clk);
    rst_n = 1'b0;

    @(posedge clk);
    #1;

    // Release reset.
    rst_n = 1'b1;
    #1;

    // Now x4 and x5 should have been cleared.
    check_read(5'd4, 32'h0000_0000, 5'd5, 32'h0000_0000);

    $display("All register file tests passed.");

    done = 1'b1;
    $finish;
  end

  initial begin
  #1000;
  if (!done) begin
    $display("TIMEOUT: tb_regfile did not finish.");
    $fatal;
  end
end

endmodule
