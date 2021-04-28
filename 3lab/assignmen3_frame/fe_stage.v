 `include "VX_define.vh" 

module FE_STAGE(
    input  clk,
    input  reset,
    input  [`from_DE_to_FE_WIDTH - 1  :0] from_DE_to_FE,
    input  [`from_AGEX_to_FE_WIDTH - 1:0] from_AGEX_to_FE,   
    input  [`from_MEM_to_FE_WIDTH - 1 :0] from_MEM_to_FE,   
    input  [`from_WB_to_FE_WIDTH - 1  :0] from_WB_to_FE, 
    output [`FE_latch_WIDTH - 1       :0] FE_latch_out
);


    // I-MEM
    (* ram_init_file = `IDMEMINITFILE *)
    reg [`DBITS - 1:0] imem [`IMEMWORDS - 1:0];

    // A 8-entry Branch Target Buffer, each entry has 33 bits: {taken 1b, PCtarget 32b}
    reg [`DBITS:0] BTB  [7:0];

    initial begin
        $readmemh(`IDMEMINITFILE , imem);
    end

    /* pipeline latch */ 
    reg [`FE_latch_WIDTH-1:0]   FE_latch; // FE latch 
    reg [`DBITS-1:0]            PC_FE_latch;       // PC latch in the FE stage   // you could use a part of FE_latch as a PC latch as well 

    wire                        dependency_stall_FE;
    wire                        jmp_br_stall_FE;             // signal to indicate when a front-end needs to be stall
    wire                        stall_pipe;

    wire                        jmp_br_from_de_FE;      // if the instruction is decoded as a jump or branch
    wire                        br_cond_from_agex_FE;   // is branch taken?
    wire [`DBITS-1:0]           pctarget_from_agex_FE;            //
    wire [`INSTBITS-1:0]        inst_FE;                // instruction value in the FE stage 
    wire [`DBITS-1:0]           pcplus_FE;              // pc plus value in the FE stage 
    wire [`FE_latch_WIDTH-1:0]  FE_latch_contents; 
    wire [3:0]                  bus_canary_from_agex_FE;


//  ===================== Branch Target Buffer ==========================================
    wire [`IMEMADDRBITS-1:2]    pc_index_FE;            // index of PC address in memory
    wire                        use_pred_FE;            // pcplus gets BTB prediction

    wire                        is_branch_FE;
    wire [`OP1BITS-1:0]         op1_FE;

    wire                        pc_pred_taken_FE;       // taken prediction from BTB
    wire [`DBITS-1:0]           pc_pred_FE;             // predicted PC from BTB
    wire [2:0]                  BTB_index_FE;

    wire                        update_BTB_from_wb_FE;
    wire [2:0]                  update_index_from_wb_FE;
    wire [`DBITS:0]             new_BTB_entry_from_wb_FE;

    wire                        flush_FE;
//  ======================================================================================

    assign {
        pc_pred_taken_FE,
        pc_pred_FE
    } = BTB[BTB_index_FE];

    assign {
        dependency_stall_FE,
        jmp_br_stall_FE
    } = from_DE_to_FE; // you need to complete the logic to compute stall FE stage 

    assign {
        br_cond_from_agex_FE,
        pctarget_from_agex_FE,
        flush_FE,
        bus_canary_from_agex_FE
    } = from_AGEX_to_FE;

    assign {
        update_BTB_from_wb_FE,
        update_index_from_wb_FE,
        new_BTB_entry_from_wb_FE
    } = from_WB_to_FE;


    assign op1_FE       = inst_FE[31:26];
    assign is_branch_FE = op1_FE == 6'b001000 || op1_FE == 6'b001001 || op1_FE == 6'b001010 || op1_FE == 6'b001011;
    assign BTB_index_FE = PC_FE_latch[4:2];

    assign pc_index_FE  = PC_FE_latch[`IMEMADDRBITS-1:`IMEMWORDBITS];
    assign inst_FE      = imem[pc_index_FE];        // IMEMADDRBITS=16 IMEMWORDBITS = 2
    assign stall_pipe   = dependency_stall_FE || jmp_br_stall_FE;

    // if is branch inst AND BTB is valid AND BTB suggests taken, use predicted PC, else PC + 4
    assign use_pred_FE  = is_branch_FE && pc_pred_taken_FE && (pc_pred_FE != 32'b0);
    assign pcplus_FE    = use_pred_FE ? pc_pred_FE : PC_FE_latch + `INSTSIZE;


    assign FE_latch_out = FE_latch; 

    assign FE_latch_contents = { 
            inst_FE, 
            PC_FE_latch, 
            pcplus_FE,          // please feel free to add more signals such as valid bits etc. 
            pc_pred_taken_FE,
            pc_pred_FE,
            `BUS_CANARY_VALUE // for an error checking of bus encoding/decoding  
    };

//  BTB update block
    always @ (negedge clk or posedge reset) begin
        if (reset) begin
            BTB[0] <= 33'h0;
            BTB[1] <= 33'h0;
            BTB[2] <= 33'h0;
            BTB[3] <= 33'h0;
            BTB[4] <= 33'h0;
            BTB[5] <= 33'h0;
            BTB[6] <= 33'h0;
            BTB[7] <= 33'h0;
        end
        else if (update_BTB_from_wb_FE) begin  // updates BTB with br_cond and pctarget from WB
            BTB[update_index_from_wb_FE] <= new_BTB_entry_from_wb_FE;
        end
    end

   
    always @ (posedge clk or posedge reset) begin
        if(reset)
            PC_FE_latch <= `STARTPC;  // STARTPC = 32'h100
        else if (!stall_pipe && !br_cond_from_agex_FE)  // continue to next instruction (pc + 4)
            PC_FE_latch <= pcplus_FE;
        else if (!stall_pipe && br_cond_from_agex_FE)   // jump or branch
            PC_FE_latch <= pctarget_from_agex_FE;
        else if (stall_pipe == 1'b1)  // dependency stall, hold current PC
            PC_FE_latch <= PC_FE_latch;
        else
            PC_FE_latch <= PC_FE_latch;
    end
  
// NOTE: resolve data dependency first, jmp/br stall later!
    always @ (posedge clk or posedge reset) begin
        if (reset || flush_FE) begin 
            FE_latch <= {`FE_latch_WIDTH{1'b0}}; 
        end 
        else if (dependency_stall_FE == 1'b1) begin // dependency stall, hold current PC
            FE_latch <= FE_latch;
        end 
        else if (jmp_br_stall_FE) begin  // jump/branch stall, send bubbles
            FE_latch <= 0; 
        end 
        else begin  // this is just an example. you need to expand the contents of if/else
            FE_latch <= FE_latch_contents; 
        end  
    end
endmodule