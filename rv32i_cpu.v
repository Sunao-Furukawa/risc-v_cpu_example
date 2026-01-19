`timescale 1ns/1ps
module rv32i_cpu(
  input clk,
  input reset,
  output [31:0] imem_addr,
  input [31:0] imem_rdata,
  output mem_we,
  output [31:0] mem_addr,
  output [31:0] mem_wdata,
  output [3:0] mem_wmask,
  input [31:0] mem_rdata,
  output [31:0] pc_debug
);

reg [31:0] pc_fetch;
reg [31:0] pc_exec;
reg [31:0] instr_reg;
reg instr_valid;
assign pc_debug = pc_exec;
assign imem_addr = pc_fetch;

reg [31:0] regs[0:31];

reg [31:0] csr_mtvec;
reg [31:0] csr_mcause;
wire [11:0] csr_addr = instr_reg[31:20];
reg [31:0] csr_rdata;
reg csr_we;
reg [31:0] csr_wdata;
reg ecall;

wire [6:0] opcode = instr_reg[6:0];
wire [4:0] rd = instr_reg[11:7];
wire [2:0] funct3 = instr_reg[14:12];
wire [4:0] rs1 = instr_reg[19:15];
wire [4:0] rs2 = instr_reg[24:20];
wire [6:0] funct7 = instr_reg[31:25];

wire [31:0] rs1_val = (rs1 == 0) ? 32'b0 : regs[rs1];
wire [31:0] rs2_val = (rs2 == 0) ? 32'b0 : regs[rs2];

wire [31:0] imm_i = {{20{instr_reg[31]}}, instr_reg[31:20]};
wire [31:0] imm_s = {{20{instr_reg[31]}}, instr_reg[31:25], instr_reg[11:7]};
wire [31:0] imm_b = {{19{instr_reg[31]}}, instr_reg[31], instr_reg[7], instr_reg[30:25], instr_reg[11:8], 1'b0};
wire [31:0] imm_u = {instr_reg[31:12], 12'b0};
wire [31:0] imm_j = {{11{instr_reg[31]}}, instr_reg[31], instr_reg[19:12], instr_reg[20], instr_reg[30:21], 1'b0};

reg [31:0] next_pc;
reg reg_we;
reg [31:0] reg_wdata;
reg mem_we_r;
reg [3:0] mem_wmask_r;
reg [31:0] mem_addr_r;
reg [31:0] mem_wdata_r;

assign mem_we = mem_we_r;
assign mem_wmask = mem_wmask_r;
assign mem_addr = mem_addr_r;
assign mem_wdata = mem_wdata_r;

reg [31:0] alu_a;
reg [31:0] alu_b;
reg [31:0] alu_out;

reg load_pending;
reg [4:0] load_rd;
reg [2:0] load_funct3;
reg load_start;
reg [31:0] load_wdata;

function [31:0] csr_read;
  input [11:0] addr;
  begin
    case (addr)
      12'h305: csr_read = csr_mtvec;
      12'h342: csr_read = csr_mcause;
      12'hF14: csr_read = 32'b0;
      default: csr_read = 32'b0;
    endcase
  end
endfunction

function [31:0] load_data;
  input [2:0] f3;
  input [31:0] data;
  reg [7:0] b0;
  reg [15:0] h;
  begin
    b0 = data[7:0];
    h = data[15:0];
    case (f3)
      3'b000: load_data = {{24{b0[7]}}, b0}; // LB
      3'b100: load_data = {24'b0, b0}; // LBU
      3'b001: load_data = {{16{h[15]}}, h}; // LH
      3'b101: load_data = {16'b0, h}; // LHU
      3'b010: load_data = data; // LW
      default: load_data = data;
    endcase
  end
endfunction

always @* begin
  next_pc = pc_exec + 32'd4;
  reg_we = 1'b0;
  reg_wdata = 32'b0;
  mem_we_r = 1'b0;
  mem_wmask_r = 4'b0000;
  mem_addr_r = 32'b0;
  mem_wdata_r = rs2_val;
  csr_we = 1'b0;
  csr_wdata = 32'b0;
  ecall = 1'b0;
  csr_rdata = 32'b0;
  alu_a = rs1_val;
  alu_b = rs2_val;
  alu_out = 32'b0;
  load_start = 1'b0;
  load_wdata = load_data(load_funct3, mem_rdata);

  if (instr_valid && !load_pending) begin
    case (opcode)
      7'b0110111: begin
        reg_we = 1'b1;
        reg_wdata = imm_u;
      end
      7'b0010111: begin
        reg_we = 1'b1;
        reg_wdata = pc_exec + imm_u;
      end
      7'b1101111: begin
        reg_we = 1'b1;
        reg_wdata = pc_exec + 32'd4;
        next_pc = pc_exec + imm_j;
      end
      7'b1100111: begin
        reg_we = 1'b1;
        reg_wdata = pc_exec + 32'd4;
        next_pc = (rs1_val + imm_i) & ~32'd1;
      end
      7'b1100011: begin
        case (funct3)
          3'b000: if (rs1_val == rs2_val) next_pc = pc_exec + imm_b; // BEQ
          3'b001: if (rs1_val != rs2_val) next_pc = pc_exec + imm_b; // BNE
          3'b100: if ($signed(rs1_val) < $signed(rs2_val)) next_pc = pc_exec + imm_b; // BLT
          3'b101: if ($signed(rs1_val) >= $signed(rs2_val)) next_pc = pc_exec + imm_b; // BGE
          3'b110: if (rs1_val < rs2_val) next_pc = pc_exec + imm_b; // BLTU
          3'b111: if (rs1_val >= rs2_val) next_pc = pc_exec + imm_b; // BGEU
          default: ;
        endcase
      end
      7'b0000011: begin
        mem_addr_r = rs1_val + imm_i;
        load_start = 1'b1;
      end
      7'b0100011: begin
        mem_addr_r = rs1_val + imm_s;
        mem_we_r = 1'b1;
        case (funct3)
          3'b000: mem_wmask_r = 4'b0001; // SB
          3'b001: mem_wmask_r = 4'b0011; // SH
          3'b010: mem_wmask_r = 4'b1111; // SW
          default: mem_wmask_r = 4'b0000;
        endcase
      end
      7'b0010011: begin
        reg_we = 1'b1;
        alu_a = rs1_val;
        alu_b = imm_i;
        case (funct3)
          3'b000: alu_out = alu_a + alu_b; // ADDI
          3'b010: alu_out = ($signed(alu_a) < $signed(alu_b)) ? 32'd1 : 32'd0; // SLTI
          3'b011: alu_out = (alu_a < alu_b) ? 32'd1 : 32'd0; // SLTIU
          3'b100: alu_out = alu_a ^ alu_b; // XORI
          3'b110: alu_out = alu_a | alu_b; // ORI
          3'b111: alu_out = alu_a & alu_b; // ANDI
          3'b001: alu_out = alu_a << instr_reg[24:20]; // SLLI
          3'b101: begin
            if (funct7 == 7'b0100000)
              alu_out = $signed(alu_a) >>> instr_reg[24:20]; // SRAI
            else
              alu_out = alu_a >> instr_reg[24:20]; // SRLI
          end
          default: alu_out = 32'b0;
        endcase
        reg_wdata = alu_out;
      end
      7'b0110011: begin
        reg_we = 1'b1;
        alu_a = rs1_val;
        alu_b = rs2_val;
        case (funct3)
          3'b000: begin
            if (funct7 == 7'b0100000)
              alu_out = alu_a - alu_b; // SUB
            else
              alu_out = alu_a + alu_b; // ADD
          end
          3'b001: alu_out = alu_a << alu_b[4:0]; // SLL
          3'b010: alu_out = ($signed(alu_a) < $signed(alu_b)) ? 32'd1 : 32'd0; // SLT
          3'b011: alu_out = (alu_a < alu_b) ? 32'd1 : 32'd0; // SLTU
          3'b100: alu_out = alu_a ^ alu_b; // XOR
          3'b101: begin
            if (funct7 == 7'b0100000)
              alu_out = $signed(alu_a) >>> alu_b[4:0]; // SRA
            else
              alu_out = alu_a >> alu_b[4:0]; // SRL
          end
          3'b110: alu_out = alu_a | alu_b; // OR
          3'b111: alu_out = alu_a & alu_b; // AND
          default: alu_out = 32'b0;
        endcase
        reg_wdata = alu_out;
      end
      7'b1110011: begin
        csr_rdata = csr_read(csr_addr);
        case (funct3)
          3'b000: begin
            if (instr_reg[31:20] == 12'b0) begin
              ecall = 1'b1;
              next_pc = csr_mtvec;
            end
          end
          3'b001: begin // CSRRW
            reg_we = (rd != 0);
            reg_wdata = csr_rdata;
            csr_we = 1'b1;
            csr_wdata = rs1_val;
          end
          3'b010: begin // CSRRS
            reg_we = (rd != 0);
            reg_wdata = csr_rdata;
            if (rs1 != 0) begin
              csr_we = 1'b1;
              csr_wdata = csr_rdata | rs1_val;
            end
          end
          default: ;
        endcase
      end
      default: begin
        // NOP/unsupported
      end
    endcase
  end
end

integer i;
always @(posedge clk or posedge reset) begin
  if (reset) begin
    pc_fetch <= 32'b0;
    pc_exec <= 32'b0;
    instr_reg <= 32'h00000013;
    instr_valid <= 1'b0;
    load_pending <= 1'b0;
    load_rd <= 5'b0;
    load_funct3 <= 3'b0;
    for (i = 0; i < 32; i = i + 1) begin
      regs[i] <= 32'b0;
    end
    csr_mtvec <= 32'b0;
    csr_mcause <= 32'b0;
  end else begin
    if (load_pending) begin
      if (load_rd != 0) begin
        regs[load_rd] <= load_wdata;
      end
      load_pending <= 1'b0;
      instr_valid <= 1'b0;
    end else begin
      pc_exec <= pc_fetch;
      instr_reg <= imem_rdata;
      instr_valid <= 1'b1;
      pc_fetch <= next_pc;
      if (reg_we && (rd != 0)) begin
        regs[rd] <= reg_wdata;
      end
      if (csr_we) begin
        case (csr_addr)
          12'h305: csr_mtvec <= csr_wdata;
          12'h342: csr_mcause <= csr_wdata;
          default: ;
        endcase
      end
      if (ecall) begin
        csr_mcause <= 32'd11;
      end
      if (load_start) begin
        load_pending <= 1'b1;
        load_rd <= rd;
        load_funct3 <= funct3;
        instr_valid <= 1'b0;
      end
    end
  end
end

endmodule
