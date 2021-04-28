 `include "VX_define.vh" 


module WB_STAGE(
    input  clk,
    input  reset,  
    input  [`MEM_latch_WIDTH-1:0]        from_MEM_latch,
    output [`from_WB_to_FE_WIDTH-1:0]    from_WB_to_FE,
    output [`from_WB_to_DE_WIDTH-1:0]    from_WB_to_DE,  
    output [`from_WB_to_AGEX_WIDTH-1:0]  from_WB_to_AGEX,
    output [`from_WB_to_MEM_WIDTH-1:0]   from_WB_to_MEM,
    output [6:0] HEX0,
    output [6:0] HEX1, 
    output [9:0] LEDR 
);

    wire [`INSTBITS-1:0] inst_WB; 
    wire [`DBITS-1:0]    PC_WB;
    wire [`DBITS-1:0]    memaddr_WB; 
    wire [`DBITS-1:0]    regval_WB; 
    wire [`DBITS-1:0]    regval2_WB;
    wire [`DBITS-1:0]    wr_reg_val_WB;   
    wire [`DBITS-1:0]    aluout_WB;   

    wire wr_mem_WB;
    wire wr_reg_WB;
    wire [`REGNOBITS-1:0] wregno_WB;
    wire [`BUS_CANARY_WIDTH-1:0] bus_canary_WB;
    wire [`from_WB_to_DE_WIDTH-1:0] WB_latch_contents;

    reg [23:0] HEX_out; 
    reg [ 9:0] LEDR_out; 

/* HEX0, HEX1 are completed for you.  */ 
    always @ (posedge clk or posedge reset) begin
        if(reset)
            HEX_out <= 24'hFEDEAD;
        else if(wr_mem_WB && (memaddr_WB == `ADDRHEX))
            HEX_out <= regval2_WB[`HEXBITS-1:0];
    end

    assign HEX0 = HEX_out[3:0]; // if we are using a board, we should converte hex values with seven segments. 
    assign HEX1 = HEX_out[7:4];    

    always @ (posedge clk or posedge reset) begin
        if(reset)
            LEDR_out <= 10'b0011111111;
        else if(wr_mem_WB && (memaddr_WB == `ADDRLEDR))
            LEDR_out <= regval2_WB[`LEDRBITS-1:0];
    end

    assign LEDR = LEDR_out;

    // if load word, write back the memory value, otherwise the ALU value
    assign wr_reg_val_WB = (inst_WB[31:26] == 6'b010010) ? regval_WB : aluout_WB;


 // **TODO: Complete the rest of the pipeline 
 
    assign {
        inst_WB,
        PC_WB,
        memaddr_WB,
        regval_WB,  // value read from memory
        regval2_WB, // value from ALU
        wr_mem_WB,
        wr_reg_WB,
        wregno_WB,    
        // more signals might need     
        aluout_WB,

        bus_canary_WB 
    } = from_MEM_latch; 
        
    // write register by sending data to the DE stage 

    assign from_WB_to_DE = {
        wr_reg_WB,
        wregno_WB,
        wr_reg_val_WB,
        bus_canary_WB
    };

    // **TODO: Write the code for LEDR here

    always @ (posedge clk or posedge reset) begin
        // this code need to be completed 

    end  // end always




endmodule 
