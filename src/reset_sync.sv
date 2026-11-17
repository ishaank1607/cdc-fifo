//reset synchronizer

module reset_sync(
    input clk, 
    input rst_n, 
    (* ASYNC_REG = "TRUE" *) output logic rst_sync_n
);
    
    (* ASYNC_REG = "TRUE" *) logic rst_ff;

    always_ff @ (posedge clk or negedge rst_n) begin  
        if(!rst_n) rst_ff <= 0;
        else rst_ff <= 1;
    end
    
    always_ff @ (posedge clk or negedge rst_n) begin  
        if(!rst_n) rst_sync_n<= 0;
        else rst_sync_n <= rst_ff;
    end
endmodule