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
    reg [`DBITS-1:0] imem [`IMEMWORDS-1:0];

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


    wire [`BUS_CANARY_WIDTH-1:0] bus_canary_from_agex_FE;

    assign FE_latch_out = FE_latch; 

    // ======= NEW CODE: extract AGEX to FE signal
    assign {
        br_cond_from_agex_FE,
        pctarget_from_agex_FE,
        bus_canary_from_agex_FE
    } = from_AGEX_to_FE;



    assign {
        dependency_stall_FE,
        jmp_br_stall_FE
    } = from_DE_to_FE; // you need to complete the logic to compute stall FE stage 

    assign stall_pipe = dependency_stall_FE || jmp_br_stall_FE;

    // reading instruction from imem 
    assign inst_FE = imem[PC_FE_latch[`IMEMADDRBITS-1:`IMEMWORDBITS]]; // IMEMADDRBITS=16 IMEMWORDBITS = 2
    
    // wire to send the FE latch contents to the DE stage 


    // This is the value of "incremented PC", computed in the FE stage
    assign pcplus_FE = PC_FE_latch + `INSTSIZE;

    // the order of latch contents should be matched in the decode stage when we extract the contents. 
    assign FE_latch_contents = { 
            inst_FE, 
            PC_FE_latch, 
            pcplus_FE,          // please feel free to add more signals such as valid bits etc. 
            `BUS_CANARY_VALUE // for an error checking of bus encoding/decoding  
    };
   
    always @ (posedge clk or posedge reset) begin
        if(reset)
            PC_FE_latch <= `STARTPC;  // STARTPC = 32'h100
        else if (!stall_pipe && !br_cond_from_agex_FE)  // continue to next instruction (pc + 4)
            PC_FE_latch <= pcplus_FE;
        else if (!stall_pipe && br_cond_from_agex_FE)   // jump or branch
            PC_FE_latch <= pctarget_from_agex_FE;
        else if (stall_pipe == 1'b1)  // dependency stall, hold current PC
            PC_FE_latch <= PC_FE_latch;
        // else if (jmp_br_stall_FE == 1'b1) // jump / branch stall, send zeros to 
        //     PC_FE_latch <= 32'h00000000;
        else
            PC_FE_latch <= PC_FE_latch;
    end
  
// NOTE: resolve data dependency first, jmp/br stall later!
    always @ (posedge clk or posedge reset) begin
        if(reset) begin 
            FE_latch <= {`FE_latch_WIDTH{1'b0}}; 
        end else if (dependency_stall_FE == 1'b1) begin // dependency stall, hold current PC
            FE_latch <= FE_latch;
        end else if (jmp_br_stall_FE) begin  // jump/branch stall, send bubbles
            FE_latch <= 0; 
        end else begin  // this is just an example. you need to expand the contents of if/else
            FE_latch <= FE_latch_contents; 
        end  
    end
endmodule