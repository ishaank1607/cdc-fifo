//two flop synchronizer


module sync_2ff(
    input clk, 
    input rst_n, 
    input d, 
    (* ASYNC_REG = "TRUE" *) output logic q
);
    
    (* ASYNC_REG = "TRUE" *) logic data_ff;

    always_ff @ (posedge clk or negedge rst_n) begin  
        if(!rst_n) data_ff <= 0;
        else data_ff <= d;
    end
    
    always_ff @ (posedge clk or negedge rst_n) begin  
        if(!rst_n) q<= 0;
        else q <= data_ff;
    end
endmodule