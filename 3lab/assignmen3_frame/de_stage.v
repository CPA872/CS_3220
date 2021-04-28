 `include "VX_define.vh" 


module DE_STAGE(
    input clk,
    input reset,
    input  [`FE_latch_WIDTH-1:0]        from_FE_latch,
    input  [`from_AGEX_to_DE_WIDTH-1:0] from_AGEX_to_DE,  
    input  [`from_MEM_to_DE_WIDTH-1:0]  from_MEM_to_DE,     
    input  [`from_WB_to_DE_WIDTH-1:0]   from_WB_to_DE,  
    output [`from_DE_to_FE_WIDTH-1:0]   from_DE_to_FE,   
    output [`DE_latch_WIDTH-1:0]        DE_latch_out
);

    /* pipeline latch*/ 
    reg [`DE_latch_WIDTH-1:0] DE_latch; 

    /* register file */ 
    reg [`DBITS-1:0] regs [`REGWORDS-1:0];

    /* decode signals */
    wire [`INSTBITS-1:0]  inst_DE; 
    wire [`DBITS-1:0]     PC_DE;
    wire [`DBITS-1:0]     pcplus_DE; 
    wire [`OP1BITS-1:0]   op1_DE;
    wire [`OP2BITS-1:0]   op2_DE;
    wire [`IMMBITS-1:0]   imm_DE;
    wire [`REGNOBITS-1:0] rd_DE;
    wire [`REGNOBITS-1:0] rs_DE;
    wire [`REGNOBITS-1:0] rt_DE;  // REGNOBITS = 4

    wire signed [`DBITS-1:0] regval1_DE;
    wire signed [`DBITS-1:0] regval2_DE;
    wire signed [`DBITS-1:0] sxt_imm_DE;

    wire is_br_DE;
    wire is_jmp_DE;
    wire rd_mem_DE;     // reads from memory
    wire wr_mem_DE;     // writes to memory
    wire wr_reg_DE;     // writes to register

    wire [`REGNOBITS-1:0]        wregno_DE; // NO. of register to write to 
    wire [`DE_latch_WIDTH-1:0]   DE_latch_contents; 
    wire [`BUS_CANARY_WIDTH-1:0] bus_canary_DE; 

// =========================================================
// values from MEM stage
    wire                         wr_reg_from_wb_DE;
    wire [`DBITS-1:0]            wr_reg_val_from_wb_DE;
    wire [`REGNOBITS-1:0]        wregno_from_wb_DE;
    wire [`BUS_CANARY_WIDTH-1:0] bus_canary_from_wb_DE;
// =========================================================


// ============= Stall Control Signals =====================
    wire                  AGEX_rs_hazard_DE;
    wire                  AGEX_rt_hazard_DE;
    wire                  MEM_rs_hazard_DE;
    wire                  MEM_rt_hazard_DE;
    wire                  WB_rs_hazard_DE;
    wire                  WB_rt_hazard_DE;

    wire                  AGEX_rd_mem_DE;

    wire                  AGEX_hazard_DE;
    wire                  MEM_hazard_DE;
    wire                  WB_hazard_DE;

    wire                  dependency_stall_DE;
    wire                  jmp_br_stall_DE;
    wire                  stall_DE;
    reg [1:0]             stall_cycles;

    wire                  read_rs_DE;
    wire                  read_rt_DE;
    wire                  is_alu_DE;
    wire                  is_alui_DE;

    wire                  wr_1rd_0rt_DE;

    wire                  wr_reg_from_agex_DE;
    wire                  wr_1rd_0rs_from_agex_DE;  
    wire [`REGNOBITS-1:0] wregno_from_agex_DE; 

    wire                  wr_reg_from_mem_DE;
    wire                  wr_1rd_0rs_from_mem_DE;  
    wire [`REGNOBITS-1:0] wregno_from_mem_DE;
// =========================================================


// ============== Forwarding control signals ===============
    wire [`DBITS - 1:0]   aluout_from_agex_DE;
    wire [`DBITS - 1:0]   fwdval_from_mem_DE;  // if lw : rdval_mem  else aluout_mem

    wire                  reg1_agex_fwd_DE;
    wire                  reg2_agex_fwd_DE;
    wire                  reg1_mem_fwd_DE;
    wire                  reg2_mem_fwd_DE;
// =========================================================

    wire                        pc_pred_taken_DE;       // taken prediction from BTB
    wire [`DBITS-1:0]           pc_pred_DE;             // predicted PC from BTB
    wire                        flush_DE;


    // **TODO: Complete the rest of the pipeline 

    // assign decode signals
    assign op1_DE = inst_DE[31:26];
    assign op2_DE = inst_DE[25:18];
    assign imm_DE = inst_DE[23: 8];
    assign rd_DE  = inst_DE[11: 8];
    assign rs_DE  = inst_DE[ 7: 4];
    assign rt_DE  = inst_DE[ 3: 0];

    // complete the rest of instruction decoding 
    //                                              BEQ                   BLT                     BLE                     BNE
    assign is_br_DE   = (PC_DE == 0) ? 0 : (op1_DE == 6'b001000 || op1_DE == 6'b001001 || op1_DE == 6'b001010 || op1_DE == 6'b001011);
    assign is_jmp_DE  = (op1_DE == 6'b001100); // JAL
    assign rd_mem_DE  = (op1_DE == 6'b010010); // LW
    
    assign wr_mem_DE  = (op1_DE == 6'b011010); // SW
    assign wr_reg_DE  = !is_br_DE && !wr_mem_DE && (PC_DE != 32'h00000000);  // is NOT branch, SW, 

    // ALU writes to RD, all other wreg instructions writes to RT
    assign wregno_DE  = (op1_DE == 6'b000000) ? rd_DE : rt_DE;

    assign is_alu_DE  = (op1_DE == 6'b000000);
    assign is_alui_DE = (op1_DE == 6'b100000 || op1_DE == 6'b100100 || op1_DE == 6'b100101 || op1_DE == 6'b100110);
    //                            ADDi                ANDi                  ORi                  XORi
    

//  ================== hazard logic ==============================================================
    assign read_rt_DE = is_alu_DE || is_br_DE || is_jmp_DE || wr_mem_DE;
    assign read_rs_DE = is_alu_DE || is_alui_DE || is_br_DE || wr_mem_DE || rd_mem_DE;

    // hazard: data desired is in AGEX stage
    assign AGEX_rs_hazard_DE   = read_rs_DE && wr_reg_from_agex_DE && (rs_DE == wregno_from_agex_DE);
    assign AGEX_rt_hazard_DE   = read_rt_DE && wr_reg_from_agex_DE && (rt_DE == wregno_from_agex_DE);
    assign AGEX_hazard_DE      = AGEX_rs_hazard_DE || AGEX_rt_hazard_DE;

    // hazard: data desired is in MEM stage
    assign MEM_rs_hazard_DE    = read_rs_DE && wr_reg_from_mem_DE && (rs_DE == wregno_from_mem_DE);
    assign MEM_rt_hazard_DE    = read_rt_DE && wr_reg_from_mem_DE && (rt_DE == wregno_from_mem_DE);
    assign MEM_hazard_DE       = MEM_rs_hazard_DE || MEM_rt_hazard_DE;
//  ============================================================================================


//  ================ forwarding logic ==========================================================
    assign reg1_agex_fwd_DE = AGEX_rs_hazard_DE;
    assign reg2_agex_fwd_DE = AGEX_rt_hazard_DE;
    assign reg1_mem_fwd_DE  = MEM_rs_hazard_DE;
    assign reg2_mem_fwd_DE  = MEM_rt_hazard_DE; 

    assign regval1_DE = reg1_agex_fwd_DE ? aluout_from_agex_DE
                                : reg1_mem_fwd_DE ? fwdval_from_mem_DE
                                : regs[rs_DE];  

    assign regval2_DE = reg2_agex_fwd_DE ? aluout_from_agex_DE 
                                : reg2_mem_fwd_DE ? fwdval_from_mem_DE
                                : regs[rt_DE];
//  ==============================================================================================


    // Now the only dependency stall is having a LW instruction immediately preceding
    assign dependency_stall_DE = AGEX_hazard_DE && AGEX_rd_mem_DE;
    assign jmp_br_stall_DE     = 0; //is_br_DE || is_jmp_DE;
    assign stall_DE            = jmp_br_stall_DE;


// ========  Register value assignment: to be fed into ALU as A_input and B_input

    assign sxt_imm_DE = { {16{imm_DE[15]}}, imm_DE };
    assign wr_1rd_0rt_DE  = (op1_DE == `OP1_ALUR);  // not used

    // assign wire to send the contents of DE latch to other pipeline stages  
    assign DE_latch_out = DE_latch; 
  
    assign {
        wr_reg_from_agex_DE,
        wr_1rd_0rs_from_agex_DE,  
        wregno_from_agex_DE,
        aluout_from_agex_DE,
        AGEX_rd_mem_DE,
        flush_DE
    } = from_AGEX_to_DE;


    assign {
        wr_reg_from_mem_DE,
        wr_1rd_0rs_from_mem_DE,  
        wregno_from_mem_DE,
        fwdval_from_mem_DE
    } = from_MEM_to_DE;


    assign {
        wr_reg_from_wb_DE,
        wregno_from_wb_DE,
        wr_reg_val_from_wb_DE,
        bus_canary_from_wb_DE
    } = from_WB_to_DE;

    // send stall signals to FE
    assign from_DE_to_FE = {
        dependency_stall_DE,
        jmp_br_stall_DE
    };
        
    // Sign extension example 
    SXT mysxt (.IN(imm_DE), .OUT(sxt_imm_DE));
  
    // decoding the contents of FE latch out. the order should be matched with the fe_stage.v 
    assign {
            inst_DE,
            PC_DE, 
            pcplus_DE,
            pc_pred_taken_DE,
            pc_pred_DE,
            bus_canary_DE 
    } = from_FE_latch;  // based on the contents of the latch, you can decode the content 

    assign DE_latch_contents = {
            inst_DE,
            PC_DE,
            pcplus_DE,
            op1_DE,
            op2_DE,
            regval1_DE,
            regval2_DE,
            sxt_imm_DE,
            is_br_DE,
            is_jmp_DE,
            rd_mem_DE,
            wr_mem_DE,
            wr_reg_DE,
            wregno_DE,
            pc_pred_taken_DE,
            pc_pred_DE,

            // more signals might need
            bus_canary_DE 
    }; 
    
    always @ (negedge clk or posedge reset) begin
        if (reset) begin
            regs[0]  <= {`DBITS{1'b0}};
            regs[1]  <= {`DBITS{1'b0}};
            regs[2]  <= {`DBITS{1'b0}};
            regs[3]  <= {`DBITS{1'b0}};
            regs[4]  <= {`DBITS{1'b0}};
            regs[5]  <= {`DBITS{1'b0}};
            regs[6]  <= {`DBITS{1'b0}};
            regs[7]  <= {`DBITS{1'b0}};
            regs[8]  <= {`DBITS{1'b0}};
            regs[9]  <= {`DBITS{1'b0}};
            regs[10] <= {`DBITS{1'b0}};
            regs[11] <= {`DBITS{1'b0}};
            regs[12] <= {`DBITS{1'b0}};
            regs[13] <= {`DBITS{1'b0}};
            regs[14] <= {`DBITS{1'b0}};
            regs[15] <= {`DBITS{1'b0}};
        end
        else if (wr_reg_from_wb_DE) begin  // write value back to register
            regs[wregno_from_wb_DE] <= wr_reg_val_from_wb_DE;
        end
    end


    always @ (posedge clk or posedge reset) begin
        if (reset || flush_DE) begin
            DE_latch <= {`DE_latch_WIDTH{1'b0}};
            // might need more code 
        end 
        else if (dependency_stall_DE) begin
            DE_latch <= {`DE_latch_WIDTH{1'b0}};
        end 
        else if (jmp_br_stall_DE) begin  // need to pass instructions if this is a jump or branch
            DE_latch <= DE_latch_contents;
        end 
        else begin
            // need to complete. e.g.) stall? 
            DE_latch <= DE_latch_contents;
        end
    end

endmodule


module SXT(IN, OUT);
    parameter IBITS = 16;
    parameter OBITS = 32;

    input  [IBITS-1:0] IN;
    output [OBITS-1:0] OUT;

    assign OUT = {{(OBITS-IBITS){IN[IBITS-1]}}, IN};
endmodule