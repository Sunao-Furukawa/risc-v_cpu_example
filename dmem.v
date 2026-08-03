// The dmem -> imem write mirror below models fence.i for self-modifying code.
// It is a simulation-only construct: on real hardware imem and dmem are
// separate block RAMs, so self-modifying code is not supported. Define
// SIM_IMEM_MIRROR to keep the mirror when simulating the synthesizable
// configuration (-DSYNTHESIS), which is what run_riscv_tests.sh does so the
// rv32ui-p-fence_i test can still exercise the core.
`ifdef SYNTHESIS
  `ifdef SIM_IMEM_MIRROR
    `define DMEM_MIRROR_IMEM
  `endif
`else
  `define DMEM_MIRROR_IMEM
`endif

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

// Word-wide storage with byte write enables. All four byte lanes share a
// single word index, which is the pattern Vivado/Quartus recognise as a
// byte-write-enabled block RAM. A byte-addressed array would instead need four
// independently addressed read and write ports, which no BRAM can provide and
// which would collapse into (very large) distributed RAM.
(* ram_style = "block" *) reg [31:0] mem[0:DMEM_WORDS-1];
integer w;

// The core works in byte addresses and keeps sub-word data right-aligned, so
// requests are rotated into their lane here and results rotated back out.
// RV32I requires naturally aligned accesses, so a request never straddles two
// words -- the test suite and the RTOS were both checked for this.
wire [1:0] boff = addr[1:0];
wire [11:0] widx = addr[13:2];
wire in_range = (addr < DMEM_BYTES);
wire [3:0] lane_we = wmask << boff;
wire [31:0] wdata_lane = wdata << {boff, 3'b000};
wire [31:0] word_rd = in_range ? mem[widx] : 32'h00000000;

`ifdef DMEM_MIRROR_IMEM
reg [11:0] wi;
reg [31:0] imem_word;
/* verilator lint_off UNUSEDSIGNAL */
reg [31:0] byte_addr;
/* verilator lint_on UNUSEDSIGNAL */
reg [1:0] byte_sel;
reg [7:0] byte_data;
`endif

initial begin
  for (w = 0; w < DMEM_WORDS; w = w + 1) begin
    mem[w] = 32'h00000000;
  end
  $readmemh("rom.hex", mem);
end

`ifdef SYNTHESIS
reg [31:0] word_rd_r;
reg [1:0] boff_r;
always @(posedge clk) begin
  word_rd_r <= word_rd;
  boff_r <= boff;
end
assign rdata = word_rd_r >> {boff_r, 3'b000};
`else
assign rdata = word_rd >> {boff, 3'b000};
`endif

always @(posedge clk) begin
  if (we) begin
    if (in_range) begin
      if (lane_we[0]) mem[widx][7:0] <= wdata_lane[7:0];
      if (lane_we[1]) mem[widx][15:8] <= wdata_lane[15:8];
      if (lane_we[2]) mem[widx][23:16] <= wdata_lane[23:16];
      if (lane_we[3]) mem[widx][31:24] <= wdata_lane[31:24];
    end
`ifdef DMEM_MIRROR_IMEM
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

endmodule
