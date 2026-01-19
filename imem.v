module imem(
  input clk,
  input [31:0] addr,
  output [31:0] rdata
);
wire [1:0] unused_addr = addr[1:0];
parameter IMEM_WORDS = 4096;
(* rom_style = "block" *) reg [31:0] mem[0:IMEM_WORDS-1];
reg [31:0] rdata_r;
integer i;

initial begin
  for (i = 0; i < IMEM_WORDS; i = i + 1) begin
    mem[i] = 32'h00000013;
  end
  $readmemh("rom.hex", mem);
end

always @(posedge clk) begin
  if (addr[31:2] < IMEM_WORDS)
    rdata_r <= mem[addr[13:2]];
  else
    rdata_r <= 32'h00000013;
end

assign rdata = rdata_r;
endmodule
