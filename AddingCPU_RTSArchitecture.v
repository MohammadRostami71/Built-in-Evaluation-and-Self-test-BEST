`timescale 1 ns / 1ns
module AddingCPU_RTSArchitecture();

	parameter PRPG_Size = 16;
	parameter SRSG_Size = 16;
	parameter MISR_Size = 56;
	parameter SISA_Size = 16;
	parameter Shift_Cnt = 1; //Scan_Size = 24
	parameter numOfTstCycl = 100;
	parameter numOfConfig = 1;
	integer sigFile,cfgFile,status,faultFile,resultFile;
	integer i,numOfFaults,numOfDetected,numOf,n; 
	
	///////
	reg[PRPG_Size-1:0] PRPG_Seed;
	reg[PRPG_Size-1:0] PRPG_Poly;
	wire[PRPG_Size-1:0] PRPG_Out;
	
	reg[MISR_Size-1:0] MISR_Seed;
	reg[MISR_Size-1:0] MISR_Poly;
	//reg[MISR_Size-1:0] MISR_P;
	wire[MISR_Size-1:0] MISR_Out;
	
	reg[SRSG_Size-1:0] SRSG_Seed;
	reg[SRSG_Size-1:0] SRSG_Poly;
	wire[SRSG_Size-1:0] SRSG_Out;
	
	reg[SISA_Size-1:0] SISA_Seed;
	reg[SISA_Size-1:0] SISA_Poly;
	//reg SISA_Si;
	wire[SISA_Size-1:0] SISA_Out;
	//////
	real coverage;
	reg [MISR_Size - 1:0] Golden_MISR_Out;
	reg [SISA_Size - 1:0] Golden_SISA_Out;
	reg clk,masterRst,reset,Si,stuckAtVal;
	//reg [7:0]inst;
	wire [7:0] address,out_data;
	wire store,So,internalRst,NbarT;
	reg [8*50:1] wireName;
	
	CPU_net FUT(clk,PRPG_Out[7:0],internalRst,address,out_data,store,NbarT,SRSG_Out[0],So);
	
	LFSR #(PRPG_Size) PRPG (clk, internalRst, PRPG_En, PRPG_Poly,PRPG_Seed, PRPG_Out);
	
	MISR #(MISR_Size) MISR_1 (clk, internalRst, MISR_En,MISR_Poly, MISR_Seed,{39'b0, address,out_data,store}, MISR_Out);
	
	SRSG #(SRSG_Size) SRSG_1 (clk, internalRst, SRSG_En,SRSG_Poly, SRSG_Seed, SRSG_Out);
	
	SISA #(SISA_Size) SISA_1 (clk, internalRst, SISA_En, So,SISA_Poly, SISA_Seed,SISA_Out);
	
	RTS_Controller #(Shift_Cnt, numOfTstCycl) RTS_Controller_1(clk, masterRst, NbarT, internalRst, PRPG_En,SRSG_En, SISA_En, MISR_En, done);
	
	always #5 clk = !clk;
		initial begin
		
		PRPG_Seed = 12;
		SRSG_Seed = 5;
		MISR_Seed = 13;
		SISA_Seed = 24;
		
		sigFile = $fopen ("Signature.txt", "w");
		resultFile = $fopen ("Results.txt", "w");
		
		clk = 0;
		
		//Generate Dictionary of Good Signatures
		//for Various Configurations
		cfgFile = $fopen ("Configuration.txt", "r");
		i = 0;
		while (!$feof(cfgFile)) begin
			i = i + 1;
			//Apply Configurations
			status = $fscanf(cfgFile, "%b %b %b %b\n", PRPG_Poly, SRSG_Poly, MISR_Poly, SISA_Poly);
			masterRst = 1'b1; #1 masterRst = 1'b0;
			//Wait for good signature
			@(posedge done);
			$fwrite( sigFile, "%b %b\n", MISR_Out, SISA_Out);
		end
		$fclose(sigFile);
		$fclose(cfgFile);
		#1;
		// End Dictionary of Good Signatures
		
		// Fault Simulation for every configuration
		cfgFile = $fopen ("Configuration.txt", "r");
		sigFile = $fopen ("Signature.txt", "r");
		i = 0;
		while (!$feof(cfgFile)) begin
			i = i + 1;
			//extract golden signature
			status = $fscanf( sigFile, "%b %b\n", Golden_MISR_Out, Golden_SISA_Out);
			//Apply Configurations
			status = $fscanf(cfgFile, "%b %b %b %b \n", PRPG_Poly, SRSG_Poly, MISR_Poly, SISA_Poly);
			#1;
			faultFile = $fopen ("fault.flt", "r");
			numOfFaults = 0; numOfDetected = 0;
			
			while(!$feof(faultFile)) begin
				status = $fscanf(faultFile,"%s s@%b\n",wireName, stuckAtVal);
				numOfFaults = numOfFaults + 1;
				$InjectFault(wireName, stuckAtVal);
				masterRst = 1'b1; #1 masterRst = 1'b0;
				@( posedge done ); //Wait for signature
				//compare
				if({MISR_Out, SISA_Out} != {Golden_MISR_Out, Golden_SISA_Out})
					numOfDetected = numOfDetected + 1;
				$RemoveFault(wireName);
			end // "while(!$feof(faultFile))"
			$fclose(faultFile);
			
			coverage = numOfDetected * 100.0 / numOfFaults;
			$fwrite(resultFile, "%b %b %b %b %d %d %f\n", PRPG_Poly, SRSG_Poly, MISR_Poly, SISA_Poly, numOfTstCycl, numOfTstCycl * Shift_Cnt, coverage );
			
		end // "while (!$feof(cfgFile)) "
		$fclose(cfgFile);
		$fclose(sigFile);
		$fclose(resultFile);
		$stop;
	end
endmodule
/////////////////////////
module LFSR #(parameter n = 8) (input clk, init, en,input [n-1:0] seed,input [n-1:0] poly,output reg [n-1:0] Q);
	integer i;
	always @(posedge clk, posedge init) begin
		if (init == 1'b1) Q <= seed;
		else if (en == 1'b1) begin
			Q[n-1] <= Q[0];
			for (i=0; i<n-1 ; i=i+1 ) begin
				Q[i] <= (Q[0] & poly[i] ) ^ Q[i+1];
			end //for
		end
	end
endmodule
//////////////////////////////////
module SRSG #(parameter n = 8) (input clk, init, en,input [n-1:0] seed,input [n-1:0] poly,output reg [n-1:0] Q);
	integer i;
	always @(posedge clk, posedge init) begin
		if (init == 1'b1) Q <= seed;
		else if (en == 1'b1) begin
			Q[n-1] <= Q[0];
			for (i=0; i<n-1 ; i=i+1 ) begin
				Q[i] <= (Q[0] & poly[i] ) ^ Q[i+1];
			end //for
		end
	end
endmodule
//////////////////////////////////////
module SISA #(parameter n = 8) (input clk, init, en, sin, input [n - 1:0]poly, seed, output reg [n - 1:0] Q);
	integer i;
	always @(posedge clk, posedge init) begin
		if (init == 1'b1) Q <= seed;
		else if (en == 1'b1) begin
			Q[n - 1] <= Q[0] ^ sin;
			for (i = 0; i < n - 1; i = i + 1) begin
				Q[i] <= (Q[0] & poly[i]) ^ Q[i + 1];
			end //for
		end
	end
endmodule
//////////////////////
module MISR #(parameter n = 8 )
	(input clk, rst, en, input [n - 1:0] poly, seed, P,output reg [n - 1:0] Q);
	integer i;
	always @(posedge clk, posedge rst) begin
		if (rst == 1'b1)
		Q <= seed;
		else if (en == 1'b1) begin
			Q[n - 1] <= (Q [ 0 ] & poly [n - 1]) ^ P[n - 1];
			for (i = 0; i < n - 1; i = i + 1) begin
				Q[i] <= (Q[0] & poly[i]) ^ P[i] ^ Q [i + 1];
			end//for
		end
	end
endmodule