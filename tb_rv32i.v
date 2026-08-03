`timescale 1ns/1ps
module tb_rv32i;
  reg clk;
  reg reset;
  wire [31:0] imem_addr;
  wire [31:0] imem_rdata;
  wire mem_we;
  wire [31:0] mem_addr;
  wire [31:0] mem_wdata;
  wire [3:0] mem_wmask;
  wire [31:0] mem_rdata;
  wire [31:0] pc_debug;
  wire unused_pc_debug = &pc_debug;

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

  function [31:0] mem_word;
    input [31:0] addr;
    begin
      mem_word = {u_dmem.mem[addr + 32'd3], u_dmem.mem[addr + 32'd2], u_dmem.mem[addr + 32'd1], u_dmem.mem[addr]};
    end
  endfunction

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  integer cycle;
  integer max_cycles;
  reg [31:0] tohost;

  initial begin
    reset = 1'b1;
    #20;
    reset = 1'b0;

    // The rv32ui ISA tests finish in <1000 cycles, but a full RTOS run
    // (rtos/test_rtos.c) needs ~330k cycles, so the budget has to cover it.
    // Override with +max_cycles=<n> for longer or shorter runs.
    if (!$value$plusargs("max_cycles=%d", max_cycles)) begin
      max_cycles = 2000000;
    end

    for (cycle = 0; cycle < max_cycles; cycle = cycle + 1) begin
      @(posedge clk);
      tohost = mem_word(32'h00001000);
      if (tohost != 0) begin
        if (tohost == 32'd1) begin
          $display("PASS (%0d cycles)", cycle + 1);
        end else begin
          $display("FAIL: tohost=%0d (%0d cycles)", tohost, cycle + 1);
        end
        $finish;
      end
    end

    $display("TIMEOUT after %0d cycles (pc=0x%08x)", max_cycles, pc_debug);
    $finish;
  end
endmodule
