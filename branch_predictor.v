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
	wire is_branch_taken_agex;
	wire flush;
	wire [`DBITS-1:0] DE_PC;
	reg [`DBITS-1:0] predicted_PC;

	reg [7:0] BHR;
	reg [58:0] BTB [15:0];
	reg [1:0] PHT [255:0];
	wire [`DBITS-1:0] PC_AGEX;
	assign {is_agex_branch, is_branch_taken_agex, agex_branch_pc, agex_BHR, PC_AGEX} = from_AGEX_to_BP;
	assign DE_PC = from_DE_to_BP;
	assign FE_PC = from_FE_to_BP;

	wire [7:0] pht_index;
	wire [3:0] btb_index;
	assign pht_index = FE_PC[9:2] ^ BHR;
	assign btb_index = FE_PC[5:2];
	
	reg [25:0] tag;
	reg valid;
	reg [`DBITS-1:0] target;
	//Prediction logic
	always @ (*) begin
		tag = BTB[btb_index][58:33];
		valid = BTB[btb_index][32];
		target = BTB[btb_index][`DBITS-1:0];
		if (PHT[pht_index] >= 2) begin
			if (valid && {tag, btb_index} == FE_PC[31:2]) begin//Predict branch
				predicted_PC = target;
			end
			else
			begin//Address not in cache
				predicted_PC = FE_PC + `INSTSIZE;
			end
		end 
		else begin//Predict no branch
			predicted_PC = FE_PC + `INSTSIZE;
		end
	end
	

	wire [7:0] pht_index_agex;
	wire [3:0] btb_index_agex;
	assign pht_index_agex = PC_AGEX[9:2] ^ agex_BHR;
	assign btb_index_agex = PC_AGEX[5:2];

	wire[7:0] agex_BHR;
	wire [25:0] tag_agex;
	wire valid_agex;
	wire [`DBITS-1:0] target_agex;
	assign tag_agex = PC_AGEX[31:6];
	assign valid_agex = is_agex_branch;
	assign target_agex = agex_branch_pc;
	//Update logic
	always @(posedge clk) begin
		if (valid_agex) begin
			BTB[btb_index_agex] <= {tag_agex, valid_agex, target_agex};
			if (is_branch_taken_agex && PHT[pht_index_agex] < 3) begin
				 PHT[pht_index_agex] <= PHT[pht_index_agex] + 1;
			end 
			if (!is_branch_taken_agex && PHT[pht_index_agex] > 0) begin
				 PHT[pht_index_agex] <= PHT[pht_index_agex] - 1;
			end
			BHR <= agex_BHR << 1 + {is_branch_taken_agex};
		end
	end
	//flush if it is branch and predicted wrong
	assign flush = is_agex_branch && (DE_PC != agex_branch_pc);
	//If flushed, get the send the correct pc
	assign new_PC = flush ? agex_branch_pc : predicted_PC;
	
	
	assign from_BP_to_FE = {flush, new_PC, BHR};
	assign from_BP_to_DE = flush;

	/*always @ (posedge clk) begin
		$display("PC %x predict %x", FE_PC, new_PC);
	end*/
endmodule