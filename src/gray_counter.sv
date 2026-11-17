// gray counter

module gray_counter #(parameter int WIDTH = 32)(
    input clk,
    input rst_n,
    input en,
    output logic [WIDTH-1:0] gray,
    output logic [WIDTH-1:0] bin,
    output logic [WIDTH-1:0] next_gray
);


logic [WIDTH-1:0] IncBin;

assign IncBin = bin + en;
assign next_gray = IncBin ^ (IncBin >> 1);

always_ff @ (posedge clk or negedge rst_n) begin  
    
    if(!rst_n) begin
         bin <= 0;
         gray <= 0;
    end
    else begin
        gray <= next_gray;
        bin <= IncBin;
    end
end

endmodule