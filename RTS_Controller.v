 `timescale 1 ns / 1ns

module RTS_Controller #(parameter ShiftSize = 1, numOfTstCycl = 50) (clk, rstIn, NbarT, rstOut, PRPG_En, SRSG_En, SISA_En, MISR_En, done);

	input clk, rstIn;
	output reg NbarT, rstOut;
	output reg PRPG_En, SRSG_En, SISA_En, MISR_En;
	output reg done;
	reg [2:0] present_state, next_state;
	reg [5:0]shtCount; //vector size should be log2 of ShiftSize
	reg shtCount_Rst, shtCount_En;
	reg [15:0]testVectorCount; //Its size should be log2 of numOfTstCycl
	reg testCount_Rst, testCount_En;
	
	`define Reset 0
	`define GenData 1
	`define ShiftData 2
	`define NormalMode 3
	`define GenSignature 4
	`define Exit 5
	
	//Sequencer
	always @(posedge clk, posedge rstIn)
		if(rstIn) present_state <= `Reset;
		else present_state <= next_state;
	always @(present_state or shtCount) begin :Combinatorial
	
		NbarT = 1'b0; rstOut = 1'b0; MISR_En = 1'b0;
		PRPG_En = 1'b0; SRSG_En = 1'b0; done = 1'b0;
		SISA_En = 1'b0; shtCount_Rst = 1'b0; shtCount_En = 1'b0;
		testCount_Rst = 1'b0; testCount_En = 1'b0;
		case (present_state)
			`Reset : begin
				next_state = `GenData;
				rstOut = 1'b1;
				NbarT = 1'b1;
				testCount_Rst = 1'b1;
			end
			`GenData : begin
				next_state = `ShiftData;
				PRPG_En = 1'b1;
				shtCount_Rst = 1'b1;
			end
			`ShiftData : begin
				next_state = (shtCount < ShiftSize - 1) ?
				`ShiftData : `NormalMode;
				shtCount_En = 1'b1;
				SRSG_En = 1'b1;
				SISA_En = 1'b1;
				NbarT = 1'b1;
			end
			`NormalMode : begin
				next_state = `GenSignature;
				NbarT = 1'b0;
			end
			`GenSignature : begin
				next_state = (testVectorCount < numOfTstCycl - 1) ?
				`GenData : `Exit;
				testCount_En = 1'b1;
				MISR_En = 1'b1;
			end
			`Exit : begin
				next_state = `Exit;
				done = 1'b1;
			end
			default : next_state = `Reset;
		endcase
	
	end
	
	//Counting number of bits shifted into scan chain
	always @(posedge clk) begin
		if(shtCount_Rst) shtCount <= 0;
		else if(shtCount_En)
			shtCount <= shtCount + 1;
	end
	
	//Counting number of applied test vectors
	always @(posedge clk) begin
		if(testCount_Rst) testVectorCount <= 0;
		else if(testCount_En)
			testVectorCount <= testVectorCount + 1;
	end
endmodule