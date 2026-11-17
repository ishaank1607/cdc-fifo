// asynchronous FIFO

module async_fifo #(
    parameter int DATA_W = 8, 
    parameter int ADDR_W = 4)(
    input wclk,
    input wrst_n,
    input winc,
    input [DATA_W-1:0] wdata,
    input rclk,
    input rrst_n,
    input rinc,
    output logic [DATA_W-1:0] rdata,
    output logic rempty,
    output logic wfull
);

//SIGNAL DECLARATIONS
logic [ADDR_W:0] wgray;
logic [ADDR_W:0] rgray;
logic [ADDR_W:0] wbin;
logic [ADDR_W:0] rbin;
logic [ADDR_W:0] wgray_next;
logic [ADDR_W:0] rgray_next;
logic wrst_sync_n;
logic rrst_sync_n;
logic [ADDR_W:0] rq2w_gray;
logic [ADDR_W:0] wq2r_gray;
logic [DATA_W-1:0] mem [2**ADDR_W-1:0];

gray_counter #(.WIDTH(ADDR_W + 1)) wptr (
    .clk(wclk),
    .rst_n(wrst_sync_n),
    .en(winc && !wfull),
    .gray(wgray),
    .bin(wbin),
    .next_gray(wgray_next)
);

gray_counter #(.WIDTH(ADDR_W + 1)) rptr (
    .clk(rclk),
    .rst_n(rrst_sync_n),
    .en(rinc && !rempty),
    .gray(rgray),
    .bin(rbin),
    .next_gray(rgray_next)
);


genvar i;
for (i = 0; i < ADDR_W + 1; i++) begin : gen_sync
    sync_2ff u_sync_w2r (
        .clk(rclk),
        .rst_n(rrst_sync_n),
        .d(wgray[i]),
        .q(wq2r_gray[i])
    );
    sync_2ff u_sync_r2w (
        .clk(wclk),
        .rst_n(wrst_sync_n),
        .d(rgray[i]),
        .q(rq2w_gray[i])
    );
end

reset_sync rst1 (
    .clk(rclk),
    .rst_n(rrst_n),
    .rst_sync_n(rrst_sync_n)
);

reset_sync rst2 (
    .clk(wclk),
    .rst_n(wrst_n),
    .rst_sync_n(wrst_sync_n)
);

always_ff @ (posedge wclk or negedge wrst_sync_n) begin
    if(!wrst_sync_n) wfull <= 0;
    else wfull <= (wgray_next == {~rq2w_gray[ADDR_W], ~rq2w_gray[ADDR_W-1], rq2w_gray[ADDR_W-2:0]});
end

always_ff @ (posedge rclk or negedge rrst_sync_n) begin
    if(!rrst_sync_n) rempty <= 1;
    else rempty <= (rgray_next == wq2r_gray);
end

always_ff @(posedge wclk) begin
    if (winc && !wfull) begin
        mem[wbin[ADDR_W-1:0]] <= wdata;
    end
end

assign rdata = mem[rbin[ADDR_W-1:0]];

endmodule