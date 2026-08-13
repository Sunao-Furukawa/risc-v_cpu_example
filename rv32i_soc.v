`timescale 1ns/1ps
// Synthesizable top level: the core wired to its instruction and data memories.
// This is the unit to hand to a synthesis tool -- tb_rv32i.v is a simulation
// testbench and is not synthesizable. Build with -DSYNTHESIS so the core and
// both memories select their registered (block RAM) variants; see run_synth.sh.
//
// Both memories initialise from rom.hex, so that file has to sit next to the
// sources when synthesising.
module rv32i_soc(
  input clk,
  input reset,
  output [31:0] pc_debug
);

wire [31:0] imem_addr;
wire [31:0] imem_rdata;
wire mem_we;
wire [31:0] mem_addr;
wire [31:0] mem_wdata;
wire [3:0] mem_wmask;
wire [31:0] mem_rdata;

imem u_imem(
  .clk(clk),
  .addr(imem_addr),
  .rdata(imem_rdata)
);

dmem u_dmem(
  .clk(clk),
  .we(mem_we),
  .wmask(mem_wmask),
  .addr(mem_addr),
  .wdata(mem_wdata),
  .rdata(mem_rdata)
);

rv32i_cpu u_cpu(
  .clk(clk),
  .reset(reset),
  .imem_addr(imem_addr),
  .imem_rdata(imem_rdata),
  .mem_we(mem_we),
  .mem_addr(mem_addr),
  .mem_wdata(mem_wdata),
  .mem_wmask(mem_wmask),
  .mem_rdata(mem_rdata),
  .pc_debug(pc_debug)
);

endmodule
