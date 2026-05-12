`timescale 1ns / 1ps

module lsu #(
    parameter int DEPTH_WORDS = 1024,
    parameter string INIT_FILE = ""
) (
    input  logic        clk,

    input  logic        mem_read,
    input  logic        mem_write,

    input  logic [31:0] addr,
    input  logic [31:0] write_data,

    input  logic [1:0]  mem_size,
    input  logic        mem_unsigned,

    output logic [31:0] read_data,
    output logic        misaligned
);

  localparam logic [1:0] MEM_BYTE = 2'd0;
  localparam logic [1:0] MEM_HALF = 2'd1;
  localparam logic [1:0] MEM_WORD = 2'd2;

  localparam int ADDR_WIDTH = $clog2(DEPTH_WORDS);

  logic [31:0] mem [0:DEPTH_WORDS-1];

  logic [ADDR_WIDTH-1:0] word_addr;
  logic [31:0] read_word;

  assign word_addr = addr[ADDR_WIDTH+1:2];
  assign read_word = mem[word_addr];

  initial begin
    if (INIT_FILE != "") begin
      $display("LSU: loading data memory from %s", INIT_FILE);
      $readmemh(INIT_FILE, mem);
    end
  end

  always_comb begin
    read_data  = 32'h0000_0000;
    misaligned = 1'b0;

    case (mem_size)

      MEM_BYTE: begin
        case (addr[1:0])
          2'd0: read_data = mem_unsigned ? {24'b0, read_word[7:0]}
                                          : {{24{read_word[7]}}, read_word[7:0]};

          2'd1: read_data = mem_unsigned ? {24'b0, read_word[15:8]}
                                          : {{24{read_word[15]}}, read_word[15:8]};

          2'd2: read_data = mem_unsigned ? {24'b0, read_word[23:16]}
                                          : {{24{read_word[23]}}, read_word[23:16]};

          2'd3: read_data = mem_unsigned ? {24'b0, read_word[31:24]}
                                          : {{24{read_word[31]}}, read_word[31:24]};
        endcase
      end

      MEM_HALF: begin
        if (addr[0] != 1'b0) begin
          misaligned = 1'b1;
          read_data  = 32'h0000_0000;
        end else begin
          case (addr[1])
            1'b0: read_data = mem_unsigned ? {16'b0, read_word[15:0]}
                                            : {{16{read_word[15]}}, read_word[15:0]};

            1'b1: read_data = mem_unsigned ? {16'b0, read_word[31:16]}
                                            : {{16{read_word[31]}}, read_word[31:16]};
          endcase
        end
      end

      MEM_WORD: begin
        if (addr[1:0] != 2'b00) begin
          misaligned = 1'b1;
          read_data  = 32'h0000_0000;
        end else begin
          read_data = read_word;
        end
      end

      default: begin
        misaligned = 1'b1;
        read_data  = 32'h0000_0000;
      end

    endcase
  end

  always_ff @(posedge clk) begin
    if (mem_write && !misaligned) begin
      case (mem_size)

        MEM_BYTE: begin
          case (addr[1:0])
            2'd0: mem[word_addr][7:0]   <= write_data[7:0];
            2'd1: mem[word_addr][15:8]  <= write_data[7:0];
            2'd2: mem[word_addr][23:16] <= write_data[7:0];
            2'd3: mem[word_addr][31:24] <= write_data[7:0];
          endcase
        end

        MEM_HALF: begin
          case (addr[1])
            1'b0: mem[word_addr][15:0]  <= write_data[15:0];
            1'b1: mem[word_addr][31:16] <= write_data[15:0];
          endcase
        end

        MEM_WORD: begin
          mem[word_addr] <= write_data;
        end

        default: begin
          // Do nothing.
        end

      endcase
    end
  end

endmodule