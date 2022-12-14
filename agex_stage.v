 `include "define.vh" 

module AGEX_STAGE(
  input  wire                               clk,
  input  wire                               reset,
  input  wire [`from_MEM_to_AGEX_WIDTH-1:0] from_MEM_to_AGEX,    
  input  wire [`from_WB_to_AGEX_WIDTH-1:0]  from_WB_to_AGEX,   
  input  wire [`DE_latch_WIDTH-1:0]         from_DE_latch,
  output wire [`AGEX_latch_WIDTH-1:0]       AGEX_latch_out,
  output wire [`from_AGEX_to_FE_WIDTH-1:0]  from_AGEX_to_FE,
  output wire [`from_AGEX_to_DE_WIDTH-1:0]  from_AGEX_to_DE
);

  reg [`AGEX_latch_WIDTH-1:0] AGEX_latch; 
  // wire to send the AGEX latch contents to other pipeline stages 
  assign AGEX_latch_out = AGEX_latch;
  
  wire[`AGEX_latch_WIDTH-1:0] AGEX_latch_contents; 
  
   
  wire [`INSTBITS-1:0]inst_AGEX; 
  wire [`DBITS-1:0]PC_AGEX;
  wire [`DBITS-1:0] inst_count_AGEX; 
  wire [`DBITS-1:0] pcplus_AGEX; 
  wire [`IOPBITS-1:0] op_I_AGEX;
  wire [`DBITS-1:0] reg_1_val;
  wire [`DBITS-1:0] reg_2_val;
  wire [`DBITS-1:0] imm_val;
  wire [4:0] reg_dest;
  reg br_cond_AGEX; // 1 means a branch condition is satisified. 0 means a branch condition is not satisifed 


  wire[`BUS_CANARY_WIDTH-1:0] bus_canary_AGEX; 
 
  // **TODO: Complete the rest of the pipeline 
 
 //Signed versions of registers for pipeline math 
 reg signed [`DBITS-1:0] signed_reg_1_val;
 reg signed [`DBITS-1:0] signed_reg_2_val;
 reg signed [`DBITS-1:0] signed_imm;
 assign signed_reg_1_val = reg_1_val;
 assign signed_reg_2_val = reg_2_val;
 assign signed_imm = imm_val;

  always @ (*) begin
    case (op_I_AGEX)
      `BEQ_I : begin
        br_cond_AGEX = reg_1_val == reg_2_val; // write correct code to check the branch condition. 
        is_branch = 1;
      end
      `BNE_I : begin 
        br_cond_AGEX = reg_1_val != reg_2_val;
        is_branch = 1; 
        //$display("pc %x, reg1 %d, reg2%d", PC_AGEX, reg_1_val, reg_1_val);
      end
      `BLT_I : begin
        br_cond_AGEX = signed_reg_1_val < signed_reg_2_val; 
        is_branch = 1;
      end
      `BGE_I : begin
        br_cond_AGEX = signed_reg_1_val >= signed_reg_2_val; 
        is_branch = 1; 
      end
      `BLTU_I: begin
        br_cond_AGEX = reg_1_val < reg_2_val;
        is_branch = 1;
      end
      `BGEU_I : begin
        br_cond_AGEX = reg_1_val >= reg_2_val;
        is_branch = 1;
      end
      `JAL_I : begin
        br_cond_AGEX = 1;
        is_branch = 1;
      end
      `JALR_I : begin
        br_cond_AGEX = 1;
        is_branch = 1;
        //$display("pc %x, br_cond_AGEX %d, is_branch %d br_target %x", PC_AGEX, br_cond_AGEX, is_branch, br_target);
      end
      default : begin 
        br_cond_AGEX = 1'b0;
        is_branch = 0;
      end
    endcase
  end
  reg is_branch;
  wire stall_de;
  wire move_on_fetch;

  assign move_on_fetch = !br_cond_AGEX && is_branch;

  assign stall_de = is_branch;
  assign from_AGEX_to_DE = {stall_de, reg_dest, wr_reg};

  assign from_AGEX_to_FE = {br_cond_AGEX, br_target, move_on_fetch};
  // compute ALU operations  (alu out or memory addresses)
  reg [`DBITS-1:0] result;
  always @ (*) begin
  
    case (op_I_AGEX)
      `ADD_I: result = reg_1_val + reg_2_val;
      `ADDI_I: result = reg_1_val + imm_val;
      `AUIPC_I: result = imm_val + PC_AGEX;
      `SUB_I: result = reg_1_val - reg_2_val;
      `JAL_I: result = PC_AGEX + 4;
      `JALR_I: result = PC_AGEX + 4;
      `LUI_I: result = imm_val;
      `ANDI_I: result = reg_1_val & imm_val;
      `AND_I: result = reg_1_val & reg_2_val;
      `ORI_I: result = reg_1_val | imm_val;
      `OR_I: result = reg_1_val | reg_2_val;
      `XORI_I: result = reg_1_val ^ imm_val;
      `XOR_I: result = reg_1_val ^ reg_2_val;
      `SLL_I: result = reg_1_val <&lt reg_2_val[5:0];
      `SRL_I: result = reg_1_val >> reg_2_val[5:0];
      `SRA_I: result = reg_1_val >>> reg_2_val[5:0];
      `SRLI_I: result = reg_1_val <&lt imm_val;
      `SLTI_I: begin
          if (signed_imm > signed_reg_1_val) begin
              result <= 1
          else 
              result <= 0
        end
      end
      `SLTIU_I: begin
          if (imm_val > reg_1_val) begin
              result <= 1
          else 
              result <= 0
        end
      end

      `SLT_I: begin
          if (signed_reg_2_val > signed_reg_1_val) begin
              result <= 1
          else 
              result <= 0
        end
      end
      
      `SLTU_I: begin
          if (reg_2_val > reg_1_val) begin
              result <= 1
          else 
              result <= 0
        end
      end
      
      
	  endcase 
   
  end 

  // branch target needs to be computed here 
  // computed branch target needs to send to other pipeline stages (pctarget_AGEX)

  reg [`DBITS-1:0] br_target;
  always @(*)begin  
  
    case (op_I_AGEX)
      `BEQ_I: br_target = PC_AGEX + imm_val;
      `BNE_I: br_target = PC_AGEX + imm_val;
      `BLT_I: br_target = PC_AGEX + imm_val;
      `BGE_I: br_target = PC_AGEX + imm_val;
      `BLTU_I: br_target = PC_AGEX + imm_val;
      `BGEU_I: br_target = PC_AGEX + imm_val;
      `JAL_I: br_target = PC_AGEX + imm_val;
      `JALR_I: br_target = reg_1_val + imm_val; 

	  endcase 

  end 

  wire wr_reg;
  assign  {
    inst_AGEX,
    PC_AGEX,
    pcplus_AGEX,
    op_I_AGEX,
    inst_count_AGEX, 
    reg_1_val,
    reg_2_val,
    reg_dest,
    imm_val,
    wr_reg,
            // more signals might need
    bus_canary_AGEX
  } = from_DE_latch;    
 
  assign AGEX_latch_contents = {
    inst_AGEX,
    PC_AGEX,
    op_I_AGEX,
    inst_count_AGEX, 
    reg_dest,
    result,
    wr_reg,
            // more signals might need
    bus_canary_AGEX     
  }; 
 
  always @ (posedge clk) begin
    if (reset) begin
      AGEX_latch <= {`AGEX_latch_WIDTH{1'b0}};
      // might need more code here  
        end 
    else 
        begin
      // need to complete 
            AGEX_latch <= AGEX_latch_contents ;
        end 
  end

endmodule
