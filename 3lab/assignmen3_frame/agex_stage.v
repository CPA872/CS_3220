 `include "VX_define.vh" 


module AGEX_STAGE(
    input  clk,
    input  reset,
    input  [`from_MEM_to_AGEX_WIDTH-1:0] from_MEM_to_AGEX,    
    input  [`from_WB_to_AGEX_WIDTH-1:0]  from_WB_to_AGEX,   
    input  [`DE_latch_WIDTH-1:0]         from_DE_latch,
    output [`AGEX_latch_WIDTH-1:0]       AGEX_latch_out,

    output [`from_AGEX_to_FE_WIDTH-1:0]  from_AGEX_to_FE,
    output [`from_AGEX_to_DE_WIDTH-1:0]  from_AGEX_to_DE
);

    // wire to send the AGEX latch contents to other pipeline stages 
    reg [`AGEX_latch_WIDTH-1:0] AGEX_latch; 
    assign AGEX_latch_out = AGEX_latch;
  
    wire [`AGEX_latch_WIDTH-1:0] AGEX_latch_contents; 
   
    wire [`INSTBITS-1:0] inst_AGEX; 
    wire [`DBITS-1:0]    PC_AGEX;
    wire [`DBITS-1:0]    pcplus_AGEX; 
    wire [`OP1BITS-1:0]  op1_AGEX;
    wire [`OP2BITS-1:0]  op2_AGEX;
    wire [`IMMBITS-1:0]  imm_AGEX;

  
    wire signed [`DBITS-1:0] regval1_AGEX;
    wire signed [`DBITS-1:0] regval2_AGEX;
    wire signed [`DBITS-1:0] sxt_imm_AGEX;

    wire is_br_AGEX;
    wire is_jmp_AGEX;
    wire rd_mem_AGEX;
    wire wr_mem_AGEX;
    wire wr_reg_AGEX;
    reg  br_cond_AGEX;

    reg  [`DBITS-1:0]             aluout_AGEX; 
    wire [`REGNOBITS-1:0]         wregno_AGEX;
    wire [`DBITS-1:0]             pctarget_AGEX; 
    wire [`BUS_CANARY_WIDTH-1:0]  bus_canary_AGEX; 

    wire                          wr_1rd_0rs_AGEX;    // writes to 1(rd), 0(rt), NOT USED

// ======================= Branch Prediction Control =================
    wire                          flush_AGEX;
    wire                          pc_pred_taken_AGEX;       // taken prediction from BTB
    wire [`DBITS-1:0]             pc_pred_AGEX;             // predicted PC from BTB


    // Misprediction 
    assign flush_AGEX = is_br_AGEX && ((pc_pred_taken_AGEX != br_cond_AGEX) || (pc_pred_AGEX != pctarget_AGEX));

    assign {
            inst_AGEX,
            PC_AGEX,
            pcplus_AGEX,
            op1_AGEX,
            op2_AGEX,

            regval1_AGEX,
            regval2_AGEX,
            sxt_imm_AGEX,                                
            is_br_AGEX,
            is_jmp_AGEX,
            rd_mem_AGEX,
            wr_mem_AGEX,
            wr_reg_AGEX,
            wregno_AGEX, 

            pc_pred_taken_AGEX,
            pc_pred_AGEX,

                  // more signals might need
            bus_canary_AGEX
    } = from_DE_latch; 
    
    // **TODO: Complete the rest of the pipeline 
 
  
    always @ (op1_AGEX or regval1_AGEX or regval2_AGEX) begin
        case (op1_AGEX)
            `OP1_BEQ : br_cond_AGEX = (regval1_AGEX == regval2_AGEX);
            `OP1_BLT : br_cond_AGEX = (regval1_AGEX < regval2_AGEX);
            `OP1_BLE : br_cond_AGEX = (regval1_AGEX <= regval2_AGEX);
            `OP1_BNE : br_cond_AGEX = (regval1_AGEX != regval2_AGEX);
            default  : br_cond_AGEX = 1'b0;
        endcase
    end


    assign wr_1rd_0rs_AGEX = (op1_AGEX == `OP1_ALUR);


    always @ (op1_AGEX or op2_AGEX or regval1_AGEX or regval2_AGEX or sxt_imm_AGEX) begin
        if (op1_AGEX == `OP1_ALUR)
            // ALU instructions, RD = RS (regval1) <OP2> RT (regval2)
            case (op2_AGEX)
                // Conditional executions
        		`OP2_EQ	  : aluout_AGEX = {31'b0, regval1_AGEX == regval2_AGEX};
        		`OP2_LT	  : aluout_AGEX = {31'b0, regval1_AGEX <  regval2_AGEX};
                `OP2_LE   : aluout_AGEX = {31'b0, regval1_AGEX <= regval2_AGEX};
                `OP2_NE   : aluout_AGEX = {31'b0, regval1_AGEX != regval2_AGEX};

                `OP2_ADD  : aluout_AGEX = regval1_AGEX + regval2_AGEX;
                `OP2_AND  : aluout_AGEX = regval1_AGEX & regval2_AGEX;
                `OP2_OR   : aluout_AGEX = regval1_AGEX | regval2_AGEX;
                `OP2_XOR  : aluout_AGEX = regval1_AGEX ^ regval2_AGEX;
                `OP2_SUB  : aluout_AGEX = regval1_AGEX - regval2_AGEX;
                `OP2_NAND : aluout_AGEX = ~(regval1_AGEX & regval2_AGEX);
                `OP2_NOR  : aluout_AGEX = ~(regval1_AGEX | regval2_AGEX);
                `OP2_NXOR : aluout_AGEX = ~(regval1_AGEX ^ regval2_AGEX);
                `OP2_LSHF : aluout_AGEX = regval1_AGEX << regval2_AGEX;
                `OP2_RSHF : aluout_AGEX = regval1_AGEX >> regval2_AGEX;

        		default	  : aluout_AGEX = {`DBITS{1'b0}};
        	endcase

        
        // With immediate instructions, RT = IMM + RS(regval1)
        
        else if(op1_AGEX == `OP1_LW || op1_AGEX == `OP1_SW || op1_AGEX == `OP1_ADDI) // calculates Memory Address
        	aluout_AGEX = regval1_AGEX + sxt_imm_AGEX;
        else if(op1_AGEX == `OP1_ANDI)
        	aluout_AGEX = regval1_AGEX & sxt_imm_AGEX;
        else if(op1_AGEX == `OP1_ORI)
        	aluout_AGEX = regval1_AGEX | sxt_imm_AGEX;
        else if(op1_AGEX == `OP1_XORI)
        	aluout_AGEX = regval1_AGEX ^ sxt_imm_AGEX;
        else if(op1_AGEX == `OP1_JAL)  // JAL: [ Rt = PC+4, PC = Rs + 4sxt(Imm) ]
            aluout_AGEX = PC_AGEX + 4; 
        else
        	aluout_AGEX = {`DBITS{1'b0}};
    end

    
    assign pctarget_AGEX = (br_cond_AGEX || is_jmp_AGEX) ? PC_AGEX + 4 + ($signed(sxt_imm_AGEX) << 2) : 32'h00000000;
 
    assign AGEX_latch_contents = {
            inst_AGEX,
            PC_AGEX,
            aluout_AGEX,
            regval2_AGEX,
            rd_mem_AGEX,
            wr_mem_AGEX,
            wr_reg_AGEX,
            wregno_AGEX,
            br_cond_AGEX,
            pctarget_AGEX,
                   // more signals might need
    // ===== stall detection =========
            wr_1rd_0rs_AGEX,
    // ==========================
            bus_canary_AGEX     
    }; 



    assign from_AGEX_to_FE = {
        br_cond_AGEX,
        pctarget_AGEX,
        flush_AGEX,
        bus_canary_AGEX
    };

    assign from_AGEX_to_DE = {
        wr_reg_AGEX,
        wr_1rd_0rs_AGEX,  
        wregno_AGEX,
        aluout_AGEX,
        rd_mem_AGEX,
        flush_AGEX
    };

 
    always @ (posedge clk or posedge reset) begin
        if (reset) begin
            AGEX_latch <= {`AGEX_latch_WIDTH{1'b0}};

        end else begin
            // need to complete 
            AGEX_latch <= AGEX_latch_contents ;
        end 
    end

endmodule