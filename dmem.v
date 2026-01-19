module dmem(
  input clk,
  input we,
  input [3:0] wmask,
  input [31:0] addr,
  input [31:0] wdata,
  output [31:0] rdata
);
parameter DMEM_BYTES = 16384;
localparam DMEM_WORDS = DMEM_BYTES / 4;
localparam IMEM_MIRROR_BYTES = 16384;
(* ram_style = "block" *) reg [7:0] mem[0:DMEM_BYTES-1];
reg [31:0] init_words[0:DMEM_WORDS-1];
integer i;
integer w;
`ifndef SYNTHESIS
reg [11:0] wi;
reg [31:0] imem_word;
/* verilator lint_off UNUSEDSIGNAL */
reg [31:0] byte_addr;
/* verilator lint_on UNUSEDSIGNAL */
reg [1:0] byte_sel;
reg [7:0] byte_data;
`endif

initial begin
  for (i = 0; i < DMEM_BYTES; i = i + 1) begin
    mem[i] = 8'h00;
  end
  for (w = 0; w < DMEM_WORDS; w = w + 1) begin
    init_words[w] = 32'h00000000;
  end
  $readmemh("rom.hex", init_words);
  for (w = 0; w < DMEM_WORDS; w = w + 1) begin
    mem[w * 4] = init_words[w][7:0];
    mem[w * 4 + 1] = init_words[w][15:8];
    mem[w * 4 + 2] = init_words[w][23:16];
    mem[w * 4 + 3] = init_words[w][31:24];
  end
end

function [7:0] mem_read_byte;
  input [31:0] a;
  begin
    if (a < DMEM_BYTES)
      mem_read_byte = mem[a];
    else
      mem_read_byte = 8'h00;
  end
endfunction

reg [31:0] rdata_r;
reg [31:0] addr_r;

always @(posedge clk) begin
  addr_r <= addr;
  rdata_r <= {mem_read_byte(addr_r + 32'd3),
              mem_read_byte(addr_r + 32'd2),
              mem_read_byte(addr_r + 32'd1),
              mem_read_byte(addr_r)};
  if (we) begin
    if (wmask[0] && (addr < DMEM_BYTES)) mem[addr] <= wdata[7:0];
    if (wmask[1] && ((addr + 32'd1) < DMEM_BYTES)) mem[addr + 32'd1] <= wdata[15:8];
    if (wmask[2] && ((addr + 32'd2) < DMEM_BYTES)) mem[addr + 32'd2] <= wdata[23:16];
    if (wmask[3] && ((addr + 32'd3) < DMEM_BYTES)) mem[addr + 32'd3] <= wdata[31:24];
`ifndef SYNTHESIS
    // Mirror data writes into instruction memory to model fence.i with self-modifying code.
    /* verilator lint_off BLKSEQ */
    if (wmask[0] && (addr < IMEM_MIRROR_BYTES)) begin
      byte_addr = addr;
      byte_data = wdata[7:0];
      wi = byte_addr[13:2];
      byte_sel = byte_addr[1:0];
      imem_word = tb_rv32i.u_imem.mem[wi];
      case (byte_sel)
        2'd0: imem_word[7:0] = byte_data;
        2'd1: imem_word[15:8] = byte_data;
        2'd2: imem_word[23:16] = byte_data;
        2'd3: imem_word[31:24] = byte_data;
      endcase
      tb_rv32i.u_imem.mem[wi] = imem_word;
    end
    if (wmask[1] && ((addr + 32'd1) < IMEM_MIRROR_BYTES)) begin
      byte_addr = addr + 32'd1;
      byte_data = wdata[15:8];
      wi = byte_addr[13:2];
      byte_sel = byte_addr[1:0];
      imem_word = tb_rv32i.u_imem.mem[wi];
      case (byte_sel)
        2'd0: imem_word[7:0] = byte_data;
        2'd1: imem_word[15:8] = byte_data;
        2'd2: imem_word[23:16] = byte_data;
        2'd3: imem_word[31:24] = byte_data;
      endcase
      tb_rv32i.u_imem.mem[wi] = imem_word;
    end
    if (wmask[2] && ((addr + 32'd2) < IMEM_MIRROR_BYTES)) begin
      byte_addr = addr + 32'd2;
      byte_data = wdata[23:16];
      wi = byte_addr[13:2];
      byte_sel = byte_addr[1:0];
      imem_word = tb_rv32i.u_imem.mem[wi];
      case (byte_sel)
        2'd0: imem_word[7:0] = byte_data;
        2'd1: imem_word[15:8] = byte_data;
        2'd2: imem_word[23:16] = byte_data;
        2'd3: imem_word[31:24] = byte_data;
      endcase
      tb_rv32i.u_imem.mem[wi] = imem_word;
    end
    if (wmask[3] && ((addr + 32'd3) < IMEM_MIRROR_BYTES)) begin
      byte_addr = addr + 32'd3;
      byte_data = wdata[31:24];
      wi = byte_addr[13:2];
      byte_sel = byte_addr[1:0];
      imem_word = tb_rv32i.u_imem.mem[wi];
      case (byte_sel)
        2'd0: imem_word[7:0] = byte_data;
        2'd1: imem_word[15:8] = byte_data;
        2'd2: imem_word[23:16] = byte_data;
        2'd3: imem_word[31:24] = byte_data;
      endcase
      tb_rv32i.u_imem.mem[wi] = imem_word;
    end
    /* verilator lint_on BLKSEQ */
`endif
  end
end

assign rdata = rdata_r;
endmodule
