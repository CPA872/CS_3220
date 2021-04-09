module Project(
	input        CLOCK_50,
	input        RESET_N,
	input  [3:0] KEY,
	input  [9:0] SW,
	output [6:0] HEX0,
	output [6:0] HEX1,
	output [6:0] HEX2,
	output [6:0] HEX3,
	output [6:0] HEX4,
	output [6:0] HEX5,
	output [9:0] LEDR
);

	parameter DBITS       =32;
	parameter INSTSIZE    =32'd4;
	parameter INSTBITS    =32;
	parameter REGNOBITS   =6;
	parameter REGWORDS    =(1<<REGNOBITS);
	parameter IMMBITS     =14;
	parameter STARTPC     =32'h100;
	parameter ADDRHEX     =32'hFFFFF000;
	parameter ADDRLEDR    =32'hFFFFF020;
	parameter ADDRKEY     =32'hFFFFF080;
	parameter ADDRSW      =32'hFFFFF090;
	parameter ADDRKEYCTRL =32'hFFFFF084;
	parameter ADDRSWCTRL  =32'hFFFFF094;
	parameter ADDRTCNT    =32'hFFFFF100;
	parameter ADDRTLIM    =32'hFFFFF104;
	parameter ADDRTCTRL   =32'hFFFFF108;
	parameter IMEMINITFILE="Sorter3.mif";
	parameter IMEMADDRBITS=16;
	parameter IMEMWORDBITS=2;
	parameter IMEMWORDS   =(1<<(IMEMADDRBITS-IMEMWORDBITS));
	parameter DMEMADDRBITS=16;
	parameter DMEMWORDBITS=2;
	parameter DMEMWORDS   =(1<<(DMEMADDRBITS-DMEMWORDBITS));
  
	parameter OP1BITS  =6;
	parameter OP1_ALUR =6'b000000;
	parameter OP1_BEQ  =6'b001000;
	parameter OP1_BLT  =6'b001001;
	parameter OP1_BLE  =6'b001010;
	parameter OP1_BNE  =6'b001011;
	parameter OP1_JAL  =6'b001100;
	parameter OP1_LW   =6'b010010;
	parameter OP1_SW   =OP1_LW+6'b001000;
	parameter OP1_ADDI =6'b100000;
	parameter OP1_ANDI =6'b100100;
	parameter OP1_ORI  =6'b100101;
	parameter OP1_XORI =6'b100110;
  
	parameter OP2BITS  =6;
	parameter OP2_EQ   =OP1_BEQ;
	parameter OP2_LT   =OP1_BLT;
	parameter OP2_LE   =OP1_BLE;
	parameter OP2_NE   =OP1_BNE;
	parameter OP2_ADD  =OP1_ADDI;
	parameter OP2_AND  =OP1_ANDI;
	parameter OP2_OR   =OP1_ORI;
	parameter OP2_XOR  =OP1_XORI;
	parameter OP2_SUB  =OP2_ADD|6'b001000;
	parameter OP2_NAND =OP2_AND|6'b001000;
	parameter OP2_NOR  =OP2_OR |6'b001000;
	parameter OP2_NXOR =OP2_XOR|6'b001000;
	
  
	// The reset signal comes from the reset button on the DE0-CV board
	// RESET_N is active-low, so we flip its value ("reset" is active-high)
	wire clk,locked;
	// The PLL is wired to produce clk and locked signals for our logic
	Pll myPll(
		.refclk(CLOCK_50),
		.rst      (!RESET_N),
		.outclk_0 (clk),
		.locked   (locked)
	);
	wire reset=!locked;

  
  
  
// ------------------------------ FETCH/DECODE STAGE ------------------------------
  
	// The PC register and update logic
	reg  [(DBITS-1):0] PC;
	always @(posedge clk) begin
	if(reset)
		PC<=STARTPC;
	else if(mispred_M)
		PC<=pcgood_M;
	else if(!stall_F)
		PC<=pcpred_F;
	end
	// This is the value of "incremented PC", computed in stage 1
	wire [(DBITS-1):0] pcplus_F=PC+INSTSIZE;
	
	
	// Smarter branch prediction
	reg [(DBITS-1):0] bpred[7:0];
	wire [7:0] predbits_F;
	wire [(DBITS-1):0] bpred_F,pcpred_F;
	
	// Use some bits of the PC
	assign predbits_F=pcplus_F[9:2];
	
	// Lookup prediction
	assign bpred_F=bpred[predbits_F];
	
	// If branch or jump detected, use pred value otherwise just incremented value
	assign pcpred_F=(isbranch_D|isjump_D)?bpred_F:pcplus_F;
	
	
	// Instruction-fetch
	(* ram_init_file = IMEMINITFILE *)
	reg [(DBITS-1):0] imem[(IMEMWORDS-1):0];
	wire [(DBITS-1):0] inst_F=imem[PC[(IMEMADDRBITS-1):IMEMWORDBITS]];
	
	
  	// Buffer (fetch and decode same so directly connect signals first few signals)
	wire [(DBITS-1):0] inst_D=inst_F;
	wire [(DBITS-1):0] pcplus_D=pcplus_F;
	wire [(DBITS-1):0] pcpred_D=pcpred_F;
	reg aluimm_D;
	reg [(OP2BITS-1):0] alufunc_D;
	reg isbranch_D,isjump_D,isnop_D;
	reg wmem_D,wreg_D;
	reg [(REGNOBITS-1):0] wregno_D;
	reg selaluout_D,selmemout_D,selpcplus_D;
	wire [(DBITS-1):0] regout1_D;
	wire [(DBITS-1):0] regout2_D;
	wire [(DBITS-1):0] sxtimm_D;
	
	
	// Instruction decoding, just new names for signals
	wire [(OP1BITS-1):0]  op1_D=inst_D[(DBITS-1):(DBITS-OP1BITS)];
	wire [(REGNOBITS-1):0] rs_D,rt_D,rd_D;
	wire [(OP2BITS-1):0] op2_D=inst_D[(OP2BITS-1): 0];
	wire [(IMMBITS-1):0] rawimm_D=inst_D[(IMMBITS-1):0];
	assign {rs_D,rt_D,rd_D}=inst_D[(DBITS-OP1BITS-1):(DBITS-OP1BITS-3*REGNOBITS)];
	SXT #(.IBITS(IMMBITS), .OBITS(DBITS)) sxt(.IN(rawimm_D), .OUT(sxtimm_D));
	
	
	// Read registers
	reg [(DBITS-1):0] regs[(REGWORDS-1):0];
	wire [(DBITS-1):0] rsval_D=regs[rs_D];
	wire [(DBITS-1):0] rtval_D=regs[rt_D];
	
	
	// Actual decoding
	always @* begin
		// Reset controls
		{aluimm_D,alufunc_D}={1'b0,{OP2BITS{1'b0}}};
		{isbranch_D,isjump_D,isnop_D}={1'b0,1'b0,1'b0};
		{selaluout_D,selmemout_D,selpcplus_D}={1'b0,1'b0,1'b0};
		{wmem_D,wreg_D,wregno_D}={1'b0,1'b0,{REGNOBITS{1'b0}}};
		// Not sure about using this
		//if(reset|flush_D)
			//isnop_D=1'b1;
		case(op1_D)
			// Use ALU result and write to dest reg rd
			OP1_ALUR:
				{alufunc_D,selaluout_D,wregno_D,wreg_D}={op2_D,1'b1,rd_D,1'b1};
			default:
				case (op1_D)
					// Use imm value in ALU, use ALU result and write to dest reg rt
					OP1_ADDI,OP1_ANDI,OP1_ORI,OP1_XORI:
						{aluimm_D,alufunc_D,selaluout_D,wreg_D,wregno_D}=
						{1'b1,op1_D,1'b1,1'b1,rt_D};
					// Use imm value in ALU, use memout to write to dest reg rt
					OP1_LW:
						{aluimm_D,alufunc_D,selmemout_D,wreg_D,wregno_D}=
						{1'b1,OP1_ADDI,1'b1,1'b1,rt_D};
					// Use imm value in ALU and write to mem
					OP1_SW:
						{aluimm_D,alufunc_D,wmem_D}={1'b1,OP1_ADDI,1'b1};
					// Set isbranch, comparison done in ALU and outcome handled in mem stage
					OP1_BEQ,OP1_BNE,OP1_BLT,OP1_BLE:
						{alufunc_D,isbranch_D}={op1_D,1'b1};
					// Set isjump, use imm value in ALU, use pcplus and write to dest reg rt
					OP1_JAL:
						{aluimm_D,alufunc_D,isjump_D,selpcplus_D,wreg_D,wregno_D}=
						{1'b1,OP1_ADDI,1'b1,1'b1,1'b1,rt_D};
					// Otherwise operation is a nop
					default: isnop_D=1'b1;
				endcase
		endcase
	end

	
	// Forwarding to handle hazards
	wire rsdep_A2D,rtdep_A2D,rsdep_M2D,rtdep_M2D,usert_D,stall_D,stall_F;
	
	// Identify dependencies and assign which value to pass on based on them
	assign rsdep_A2D=wreg_A&(wregno_A==rs_D);
	assign rtdep_A2D=wreg_A&(wregno_A==rt_D);
	assign rsdep_M2D=wreg_M&(wregno_M==rs_D);
	assign rtdep_M2D=wreg_M&(wregno_M==rt_D);
	assign regout1_D=rsdep_A2D?forwval_A:rsdep_M2D?forwval_M:rsval_D;
	assign regout2_D=rtdep_A2D?forwval_A:rtdep_M2D?forwval_M:rtval_D;
	
	// Still need to stall on load-use hazard
	assign usert_D=~aluimm_D|wmem_D;
	assign stall_F=(rsdep_A2D|(rtdep_A2D&usert_D))&selmemout_A;
	assign stall_D=stall_F;
	
	
	
// ----------------------------------- ALU STAGE ----------------------------------	
	
	// Buffer
	reg [(DBITS-1):0] pcplus_A,pcpred_A;
	reg aluimm_A;
	reg [(OP2BITS-1):0] alufunc_A;
	reg isbranch_A,isjump_A,isnop_A;
	reg wmem_A,wreg_A;
	reg [(REGNOBITS-1):0] wregno_A;
	reg selaluout_A,selmemout_A,selpcplus_A;
	reg [(DBITS-1):0] regout1_A,regout2_A,sxtimm_A;
	
	// Transfer values
	always @(posedge clk) begin
		////////////////////////////////////////
		// Lines below are for checking stalling and flushing
		//if(stall_D)
		//	stallCounter<=stallCounter+32'b1;
		//if(flush_D)
		//	flushDCounter<=flushDCounter+32'b1;
		////////////////////////////////////////
		// Zero out on flush/stall
		if (flush_D|stall_D) begin
			{pcplus_A,pcpred_A}<={{DBITS{1'b0}},{DBITS{1'b0}}};
			{aluimm_A,alufunc_A}<={1'b0,{OP2BITS{1'b0}}};
			{isbranch_A,isjump_A,isnop_A}<={1'b0,1'b0,1'b0};
			{selaluout_A,selmemout_A,selpcplus_A}<={1'b0,1'b0,1'b0};
			{wmem_A,wreg_A,wregno_A}<={1'b0,1'b0,{REGNOBITS{1'b0}}};
			{regout1_A,regout2_A,sxtimm_A}<={{DBITS{1'b0}},{DBITS{1'b0}},{DBITS{1'b0}}};
		// Otherwise transfer D2A
		end else begin
			{pcplus_A,pcpred_A}<={pcplus_D,pcpred_D};
			{aluimm_A,alufunc_A}<={aluimm_D,alufunc_D};
			{isbranch_A,isjump_A,isnop_A}<={isbranch_D,isjump_D,isnop_D}; 
			{selaluout_A,selmemout_A,selpcplus_A}<={selaluout_D,selmemout_D,selpcplus_D};
			{wmem_A,wreg_A,wregno_A}<={wmem_D,wreg_D,wregno_D};
			{regout1_A,regout2_A,sxtimm_A}<={regout1_D,regout2_D,sxtimm_D};
		end
	end
	
	
	// Actual ALU
	wire signed [(DBITS-1):0] aluin1_A,aluin2_A,forwval_A;
	reg signed [(DBITS-1):0] aluout_A;
	// First ALU input always a reg value
	assign aluin1_A=regout1_A;
	// For ALU input 2 select immediate value or second reg value
	assign aluin2_A=aluimm_A?sxtimm_A:regout2_A;
	
	always @(alufunc_A or aluin1_A or aluin2_A)
		case(alufunc_A)
			OP2_EQ:  aluout_A={31'b0,aluin1_A==aluin2_A};
			OP2_LT:  aluout_A={31'b0,aluin1_A<aluin2_A};
			OP2_LE:  aluout_A={31'b0,aluin1_A<=aluin2_A};
			OP2_NE:  aluout_A={31'b0,aluin1_A!=aluin2_A};
			OP2_ADD: aluout_A=aluin1_A+aluin2_A;
			OP2_AND: aluout_A=aluin1_A&aluin2_A;
			OP2_OR:  aluout_A=aluin1_A|aluin2_A;
			OP2_XOR: aluout_A=aluin1_A^aluin2_A;
			OP2_SUB: aluout_A=aluin1_A-aluin2_A;
			OP2_NAND:aluout_A=~(aluin1_A&aluin2_A);
			OP2_NOR: aluout_A=~(aluin1_A|aluin2_A);
			OP2_NXOR:aluout_A=~(aluin1_A^aluin2_A);
			default: aluout_A={DBITS{1'bX}};
		endcase
		
	// Set the value to forward from this stage
	assign forwval_A=selaluout_A?aluout_A:selpcplus_A?pcplus_A:{DBITS{1'bX}};



		
// ------------------------------- MEM/WB STAGE ---------------------------------		
		
	// Buffer
	reg [(DBITS-1):0] pcplus_M,pcpred_M;
	reg isbranch_M,isjump_M,isnop_M;
	reg wmem_M,wreg_M;
	reg [(REGNOBITS-1):0] wregno_M;
	reg selaluout_M,selmemout_M,selpcplus_M;
	reg [(DBITS-1):0] regout1_M,regout2_M,sxtimm_M;
	reg [(DBITS-1):0] aluout_M;

	
	// Transfer values
	always @(posedge clk) begin
		////////////////////////////////////////
		// Lines below are for checking flushing
		//if(flush_A)
		//	flushACounter<=flushACounter+32'b1;
		////////////////////////////////////////
		// Zero out on flush
		if (flush_A) begin
			{pcplus_M,pcpred_M}<={{DBITS{1'b0}},{DBITS{1'b0}}};
			{isbranch_M,isjump_M,isnop_M}<={1'b0,1'b0,1'b0};
			{selaluout_M,selmemout_M,selpcplus_M}<={1'b0,1'b0,1'b0};
			{wmem_M,wreg_M,wregno_M}<={1'b0,1'b0,{REGNOBITS{1'b0}}};
			{regout1_M,regout2_M,sxtimm_M}<={{DBITS{1'b0}},{DBITS{1'b0}},{DBITS{1'b0}}};
			aluout_M<={DBITS{1'b0}};
		// Otherwise transfer A2M
		end else begin
			{pcplus_M,pcpred_M}<={pcplus_A,pcpred_A};
			{isbranch_M,isjump_M,isnop_M}<={isbranch_A,isjump_A,isnop_A}; 
			{selaluout_M,selmemout_M,selpcplus_M}<={selaluout_A,selmemout_A,selpcplus_A};
			{wmem_M,wreg_M,wregno_M}<={wmem_A,wreg_A,wregno_A};
			{regout1_M,regout2_M,sxtimm_M}<={regout1_A,regout2_A,sxtimm_A};
			aluout_M<=aluout_A;
		end
	end
	
	// Generate dobranch, target address, and flush signals
	wire dobranch_M,mispred_M,flush_D,flush_A;
	wire [(DBITS-1):0] brtarg_M,jmptarg_M,pcgood_M;
	
	// Calculate target addresses
	assign brtarg_M=(sxtimm_M << 2)+pcplus_M;
	assign jmptarg_M=(sxtimm_M << 2)+regout1_M;
	
	// Output from alu comparison on a branch instruction determines whether to branch
	assign dobranch_M=isbranch_M&aluout_M[0];
	
	// Decide new PC
	assign pcgood_M=dobranch_M?brtarg_M:isjump_M?jmptarg_M:pcplus_M;
	
	// Compare new PC and prediction to figure out if there is a misprediction
	assign mispred_M=(pcgood_M!=pcpred_M)&&!isnop_M;
	
	// Flush on misprediction
	assign flush_D=mispred_M&~isnop_M;
	assign flush_A=flush_D;
	
	// Update prediction
	wire [7:0] predbits_M;
	assign predbits_M=pcplus_M[9:2];
	always @(posedge clk)
		if (!reset&&(isbranch_M||isjump_M))
			bpred[predbits_M]<=pcgood_M;


	// Actual dmem
	wire [(DBITS-1):0] memaddr_M,wmemval_M;
	assign {memaddr_M,wmemval_M}={aluout_M,regout2_M};
	wire MemEnable=!(memaddr_M[(DBITS-1):DMEMADDRBITS]);
	wire MemWE=(!reset)&wmem_M&MemEnable;
	(* ram_init_file = IMEMINITFILE, ramstyle="no_rw_check" *)
	reg [(DBITS-1):0] dmem[(DMEMWORDS-1):0];
	always @(posedge clk)
		if(MemWE)
			dmem[memaddr_M[(DMEMADDRBITS-1):DMEMWORDBITS]]<=wmemval_M;
	wire [(DBITS-1):0] MemVal=MemWE?{DBITS{1'bX}}:dmem[memaddr_M[(DMEMADDRBITS-1):DMEMWORDBITS]];
	
	// Connect memory and input devices to the bus
	wire [(DBITS-1):0] memout_M=MemEnable?MemVal:dbus;
		

	// Decide what gets written into the destination register (wregval_M),
	// when it gets written (wrreg_M) and to which register it gets written (wregno_M)
	wire [(DBITS-1):0] wregval_M,forwval_M;
	
	assign wregval_M=
	selpcplus_M?pcplus_M:selaluout_M?aluout_M:selmemout_M?memout_M:{(DBITS){1'bX}};
	
	// Set the value to forwar from this stage
	assign forwval_M=wregval_M;
		
	// Writeback
	always @(posedge clk)
		if(wreg_M&&!reset)
			regs[wregno_M]<=wregval_M;

	

	
// -------------------------------------- I/O -------------------------------------	

	wire [(DBITS-1):0] abus;
	wire [(DBITS-1):0] dbus;
	wire we;
	
	assign we=wmem_M;
	assign abus=memaddr_M;
	
	wire [(DBITS-1):0] dbus_p;
	wire [(DBITS-1):0] dbus_m;
	wire [(DBITS-1):0] dbus_h;
	wire [(DBITS-1):0] dbus_l;
	wire [(DBITS-1):0] dbus_k;
	wire [(DBITS-1):0] dbus_s;
	wire [(DBITS-1):0] dbus_t;
	
	// Bus drivers
	assign dbus_p=wmem_M?wmemval_M:{DBITS{1'b0}};
	assign dbus_h=HEXread?{{8'b0},HEXOut}:{DBITS{1'b0}};
	assign dbus_l=LEDRread?{{22'b0},LEDR}:{DBITS{1'b0}};
	assign dbus_k=KDATAread?{{28'b0},KDATA}:(KCTRLread?{{27'b0},KCTRL}:{DBITS{1'b0}});
	assign dbus_s=SDATAread?SDATA:(SCTRLread?SCTRL:{DBITS{1'b0}});
	assign dbus_t=TCNTread?TCNT:(TLIMread?TLIM:(TCTRLread?TCTRL:{DBITS{1'b0}}));
	
	// OR the buses
	assign dbus=dbus_p|dbus_h|dbus_l|dbus_k|dbus_s|dbus_t;
	
	
	/*
		Implementing a stall counter to check forwarding
		We should only be stalling on load-use hazards
		So it should be that stalls == # of such hazards in Sorter3
		There are such hazards in Sorter 3 at lines:
			Executes once initially:
				25-26													+ 1
				ChkAsc: 64-65										+ 1
				Executes for 8192 array elements:
					LoopChkAsc: 68-69								+ 8192
					
			Executes 15 times:
				Main Loop: 44-45									+ 15
				Executes 2*8192 times:
					SortDescLoopJ: 140-141						+ 245,760
				ChkDsc: 84-85										+ 15
				Executes for 8192 array elements:
					LoopChkDsc: 89-90								+ 122,880
				Main Loop: 49-50									+ 15
				Executes 2*8192 times:
					SortAscLoopJ: 113-114						+ 245,760
				ChkAsc: 64-65										+ 15
				Executes for 8192 array elements:
					LoopChkAsc: 68-69								+ 122,880
					
		This totals to 745,534 (0xB603E)
		0xB603E displayed on HEX when SW[0] set
		...
		Realized that a lot of these hazards involve the second instruction as a branch
		So we could actually need to flush instead if there was a misprediction
	*/
	////////////////////////////////////////
	// Lines below for stalling and flushing counting
	//reg [31:0] stallCounter=32'b0;
	//reg [31:0] flushDCounter=32'b0;
	//reg [31:0] flushACounter=32'b0;
	/////////////////////////////////////
	
	
	// HEX
	reg [23:0] HEXOut;
	SevenSeg ss5(.OUT(HEX5),.IN(HEXOut[23:20]));
	SevenSeg ss4(.OUT(HEX4),.IN(HEXOut[19:16]));
	SevenSeg ss3(.OUT(HEX3),.IN(HEXOut[15:12]));
	SevenSeg ss2(.OUT(HEX2),.IN(HEXOut[11:8]));
	SevenSeg ss1(.OUT(HEX1),.IN(HEXOut[7:4]));
	SevenSeg ss0(.OUT(HEX0),.IN(HEXOut[3:0]));
	
	wire HEXio=(abus==ADDRHEX);
	wire HEXwrite=(HEXio&&we);
	wire HEXread=(HEXio&&!we);
	
	always @(posedge clk or posedge reset)
	if(reset)
		HEXOut<=24'hFEDEAD;
	else if(HEXwrite)
		HEXOut<=dbus[23:0];
	/////////////////////////////////////////////////////////
	// Lines below are for displaying stall and flush counts
	//else if(SW[0])
	//	HEXOut<=stallCounter[23:0];
	//else if(SW[1])
	//	HEXOut<=flushDCounter[23:0];
	//else if(SW[2])
	//	HEXOut<=flushACounter[23:0];
	/////////////////////////////////////////////////////////
	
			
	// LEDR
	reg [9:0] LEDRout;
	wire LEDRio=(abus==ADDRLEDR);
	wire LEDRwrite=(LEDRio&&we);
	wire LEDRread=(LEDRio&&!we);
	
	always @(posedge clk or posedge reset)
		if(reset)
			LEDRout<=10'b0;
		else if (LEDRwrite)
			LEDRout<=dbus[9:0];
			
	assign LEDR=LEDRout;
	
	
	// KEY
	reg [3:0] KDATA;
	wire [3:0] KDATAnew;
	assign KDATAnew=~KEY;
	reg kReady,kOverrun,kie;
	wire [4:0] KCTRL={kie,2'b0,kOverrun,kReady};
	
	wire KDATAio=(abus==ADDRKEY);
	wire KCTRLio=(abus==ADDRKEYCTRL);
	wire KDATAread=(KDATAio&&!we);
	wire KCTRLread=(KCTRLio&&!we);
	wire KCTRLwrite=(KCTRLio&&we);
	
	always @(posedge clk or posedge reset) begin
		if (reset)
			{kReady,kOverrun,kie,KDATA}<={1'b0,1'b0,1'b0,4'b0};
		else begin
			KDATA<=~KEY;
			if (KDATAread)
				{kReady,kOverrun,kie}<={1'b0,1'b0,1'b0};
			else if (KCTRLwrite)
				if (dbus[1]==1'b0) begin
					kOverrun<=1'b0;
					kie<=1'b0;
				end
				if (KDATA!=KDATAnew) begin
					if (!kReady)
						kReady<=1'b1;
					else
						{kOverrun,KDATA}<={1'b1,KDATAnew};
				end
		end
	end
	
	
	// SW
	reg [9:0] SDATA;
	wire [9:0] SDATAnew; // To detect change in SDATA
	assign SDATAnew=updated; // Get SW debounced data
	reg Sready,Soverrun,Sie; // SW control register bits
	wire [4:0] SCTRL={Sie,2'b0,Soverrun,Sready};
	reg [9:0] updated,curr;
	reg [31:0] counter=32'b0;
	parameter stable=860000;
	
	wire SDATAio=(abus==ADDRSW);
	wire SCTRLio=(abus==ADDRSWCTRL);
	wire SDATAread=(SDATAio&&!we);
	wire SCTRLread=(SCTRLio&&!we);
	wire SCTRLwrite=(SCTRLio&&we);

	always @(posedge clk or posedge reset) // On reset, set to 0s
		if(reset) begin
			Sready<=1'b0;
			Soverrun<=1'b0;
			Sie<=1'b0;
			SDATA<=10'b0;
			counter<=32'b0;
		end
		else begin
		// If reading SDATA, clear ready and overrun
		if (SDATAread) begin
			Sready <= 1'b0;
			Soverrun <= 1'b0;
			Sie <= 1'b0;
		end
		// Writes to SDATA ignored, but if writing 0 to SCTRL, reset overrun
		else if (SCTRLwrite) begin
			if (dbus[1]==1'b0) begin
				Soverrun<=1'b0;
				Sie<=1'b0;
			end
		end
		// Debouncing
		// 86MHz, 86,000,000 cycles/sec --> 860,000 per 10 milliseconds
		// If current data remains the same, increment counter, else reset it
		curr<=SW;
		if (counter<stable) begin
			if (curr==SW)
				counter<=counter+32'b1;
			else
				counter<=32'b0;
			end
		else begin
			updated<=curr;
			counter<=32'b0;
		end
		// Detect an updated SDATA
		if (SDATA!=SDATAnew) begin
			if(!Sready)
				Sready<=1'b1;  // If not ready, set ready
			else begin  // But if it was already ready, set overrun
				Soverrun<=1'b1;
				SDATA<=SDATAnew; // Update SDATA
			end
		end
	end
	
	
	// TIMER
	reg Tready,Toverrun,Tie;
	wire [4:0] TCTRL={Tie,2'b0,Toverrun,Tready};
	reg [31:0] TCNT;
	reg [31:0] TLIM;
	reg [31:0] Tcounter=32'b0;
	parameter ms=86000; // 1 ms
	
	wire TCNTio=(abus==ADDRTCNT);
	wire TLIMio=(abus==ADDRTLIM);
	wire TCTRLio=(abus==ADDRTCTRL);
	wire TCNTread=(TCNTio&&!we);
	wire TCNTwrite=(TCNTio&&we);
	wire TLIMread=(TLIMio&&!we);
	wire TLIMwrite=(TLIMio&&we);
	wire TCTRLread=(TCTRLio&&!we);
	wire TCTRLwrite=(TCTRLio&&we);
	
	always @(posedge clk or posedge reset) begin
		if(reset) begin
			Tready<=1'b0;
			Toverrun<=1'b0;
			Tie<=1'b0;
			TCNT<=31'b0;
			TLIM<=31'b0;
			Tcounter<=32'b0;
		end
		else begin
			// Writing to TCNT sets value of counter
			if (TCNTwrite)
				TCNT<=dbus;
			// Writing to TLIM sets value of TLIM and also resets TCNT
			else if (TLIMwrite) begin
				TLIM<=dbus;
				TCNT<=32'b0;
			end
			// Writing 0 to overrun or ready resets them
			else if (TCTRLwrite) begin
				Tie<=1'b0;
				if (dbus[1]==1'b0)
					Toverrun<=1'b0;
				if (dbus[0]==1'b0)
					Tready<=1'b0;
			end
			// Reset ready and overflow
			if (TCNTread||TCNTwrite||TLIMwrite) begin
				Tready<=1'b0;
				Toverrun<=1'b0;
			end
			// Increment counter
			if (Tcounter>=ms) begin
				// Can't increment counter if we reach limit
				if ((TLIM>0)&&(TCNT==(TLIM-1))) begin
					TCNT<=32'b0;
					Tcounter<=32'b0;
					if(!Tready)
						Tready<=1'b1; // If not ready, set ready
					else // But if it was already ready, set overrun
						Toverrun<=1'b1;
				end
				// Increment TCNT
				else begin
					TCNT<=TCNT+32'b1;
					Tcounter<=32'b0;
				end
			end
			else begin
				Tcounter<=Tcounter+32'b1; // Keep counting cycles to reach 1 ms
			end
		end
	end
	
	
endmodule


module SXT(IN,OUT);
  parameter IBITS;
  parameter OBITS;
  input  [(IBITS-1):0] IN;
  output [(OBITS-1):0] OUT;
  assign OUT={{(OBITS-IBITS){IN[IBITS-1]}},IN};  
endmodule

