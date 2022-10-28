module BRANCH_PREDICTOR(
  input wire                              clk,
  input wire                              reset,  
  input wire [`from_FE_to_BP_WIDTH-1:0]       from_FE_to_BP,
  input wire [`from_AGEX_to_BP_WIDTH-1:0]	from_AGEX_to_BP,
  input wire [`from_DE_to_BP_WIDTH-1:0]		from_DE_to_BP,
  output wire [`from_BP_to_FE_WIDTH-1:0]	from_BP_to_FE,
  output wire [`from_BP_to_DE_WIDTH-1:0]	from_BP_to_DE
);
	wire [`DBITS-1:0] FE_PC;
	wire [`DBITS-1:0] new_PC;
	wire is_agex_branch;
	wire [`DBITS-1:0] agex_branch_pc;
	wire flush;
	wire [`DBITS-1:0] DE_PC;
	wire [`DBITS-1:0] predicted_PC;

	assign {is_agex_branch, agex_branch_pc} = from_AGEX_to_BP;
	assign DE_PC = from_DE_to_BP;
	assign FE_PC = from_FE_to_BP;
	assign predicted_PC = FE_PC + `INSTSIZE;

	assign flush = is_agex_branch && (DE_PC != agex_branch_pc);

	assign new_PC = flush ? agex_branch_pc : predicted_PC;
	
	
	assign from_BP_to_FE = {flush, new_PC};
	assign from_BP_to_DE = flush;

	/*always @ (posedge clk) begin
		$display("PC %x predict %x", FE_PC, new_PC);
	end*/
endmodule