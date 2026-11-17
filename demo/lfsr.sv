// 8-bit LFSR this advances only when en is high
module lfsr8 (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       en,
    output logic [7:0] q
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)  q <= 8'h01;                                 
        else if (en) q <= {q[6:0], q[7] ^ q[5] ^ q[4] ^ q[3]};
    end
endmodule
