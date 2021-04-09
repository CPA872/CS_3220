`timescale 1ns / 1ps

module bubblesort(
    clk,
    reset, 
    done, 
    rd_en, 
    dat_out0,
    dat_out1,
    dat_out2,
    dat_out3,
    dat_out4,
    dat_out5,
    dat_out6,
    dat_out7,
    dat_out8,
    dat_out9,
    i_out,
    j_out
);
    
    input clk;
    input reset;
    input rd_en;
    output [15:0] dat_out0;
    output [15:0] dat_out1;
    output [15:0] dat_out2;
    output [15:0] dat_out3;
    output [15:0] dat_out4;
    output [15:0] dat_out5;
    output [15:0] dat_out6;
    output [15:0] dat_out7;
    output [15:0] dat_out8;
    output [15:0] dat_out9;
    output [3:0] i_out, j_out;
    output done; 
 
    parameter NumItm = 10 ;

    reg[15:0] dmem [9:0];
    reg done_reg = 0;

    assign dat_out0 = dmem[0];
    assign dat_out1 = dmem[1];
    assign dat_out2 = dmem[2];
    assign dat_out3 = dmem[3];
    assign dat_out4 = dmem[4];
    assign dat_out5 = dmem[5];
    assign dat_out6 = dmem[6];
    assign dat_out7 = dmem[7];
    assign dat_out8 = dmem[8];
    assign dat_out9 = dmem[9];   
    assign done = done_reg;
    /*
        please consider dmem as memory from wich you will read values.
    */
    
    initial begin
        $readmemh("ex1.mem", dmem);
    end
    
    integer i = 0;
    integer j = 0;
    integer end_condition = NumItm - 1;
    
    reg [15:0] a, b, temp_data;
    reg [2:0] state = 0;  // state 0-5
    reg swap = 0;
    reg [3:0] iterations = 1;  // track how many iterations have passed
    
    assign i_out = i;
    assign j_out = state;    
    
    parameter state_num = 5;
    
    always @(posedge clk or posedge reset) begin
        case (state)
            0: begin // read in a  
                a <= dmem[i];
                state <= state + 1;
               end   
                   
            1: begin 
                b <= dmem[i + 1];  // read in b
                state <= state + 1;
               end
            
            2: begin        // determine if swap
                if (a > b) begin
                    swap <= 1;
                    state <= state + 1;
                end else begin
                    swap <= 0;
                    state <= 5;
                end
            end
            
            3: begin        // swap if needed
                if (swap) begin
                    temp_data <= dmem[i];
                    dmem[i] <= dmem[i + 1];
                    state <= state + 1;
                end
            end
            
            4: begin        // swap if needed
                if (swap) begin
                    dmem[i + 1] <= temp_data;
                    state <= state + 1;
                end
            end
            
            5: begin        // increment i
                state <= 0;
                if (i == NumItm - iterations) begin
                    i <= 0;
                    iterations <= iterations + 1;
                end else
                    i <= i + 1;
            end
        endcase
        
//        // increase state counter
//        if (state == state_num)
//            state <= 0;
//        else
//            state <= state + 1;
    
    end // always 
    
    endmodule