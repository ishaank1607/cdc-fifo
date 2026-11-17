// Basys 3 demo, the LFSR is written into the FIFO on one clock, checked on another
// led[0] error (should stay off)   led[1] FIFO was full   led[2] FIFO was empty
// led[3] read-clock heartbeat      led[4] clocks locked
// sw[0] slows the reader (FIFO fills)   sw[1] slows the writer (FIFO empties)
module fifo_demo_top (
    input  logic       clk,      // 100 MHz board clock
    input  logic       btnC,     // reset (active high)
    input  logic [1:0] sw,
    output logic [4:0] led
);
    // clocks, reset held until the clocks lock
    logic wclk, rclk, locked;
    clk_wiz_0 u_clk (
        .clk_in1 (clk),
        .reset   (1'b0),
        .clk_out1(wclk),
        .clk_out2(rclk),
        .locked  (locked)
    );

    logic rst_n;
    assign rst_n = ~btnC & locked;

    logic wrst_sync_n, rrst_sync_n;
    reset_sync u_wrst (.clk(wclk), .rst_n(rst_n), .rst_sync_n(wrst_sync_n));
    reset_sync u_rrst (.clk(rclk), .rst_n(rst_n), .rst_sync_n(rrst_sync_n));

    logic        winc, rinc, wfull, rempty;
    logic [7:0]  wdata, rdata;

    // ---------------- write side (wclk) ----------------
    logic slow_w;
    sync_2ff u_sw_w (.clk(wclk), .rst_n(wrst_sync_n), .d(sw[1]), .q(slow_w));

    logic [3:0] w_div;
    always_ff @(posedge wclk or negedge wrst_sync_n) begin
        if (!wrst_sync_n) w_div <= 4'd0;
        else              w_div <= w_div + 4'd1;
    end

    assign winc = ~wfull & (~slow_w | (w_div == 4'd0));

    lfsr8 u_wlfsr (.clk(wclk), .rst_n(wrst_sync_n), .en(winc), .q(wdata));

    logic full_seen;
    always_ff @(posedge wclk or negedge wrst_sync_n) begin
        if (!wrst_sync_n)  full_seen <= 1'b0;
        else if (wfull)    full_seen <= 1'b1;
    end

    // ---------------- FIFO ----------------
    async_fifo #(.DATA_W(8), .ADDR_W(4)) u_fifo (
        .wclk  (wclk), .wrst_n(rst_n), .winc(winc), .wdata(wdata),
        .rclk  (rclk), .rrst_n(rst_n), .rinc(rinc), .rdata(rdata),
        .rempty(rempty), .wfull(wfull)
    );

    // ---------------- read side (rclk) ----------------
    logic slow_r;
    sync_2ff u_sw_r (.clk(rclk), .rst_n(rrst_sync_n), .d(sw[0]), .q(slow_r));

    logic [3:0] r_div;
    always_ff @(posedge rclk or negedge rrst_sync_n) begin
        if (!rrst_sync_n) r_div <= 4'd0;
        else              r_div <= r_div + 4'd1;
    end

    assign rinc = ~rempty & (~slow_r | (r_div == 4'd0));

    logic [7:0] expected;
    lfsr8 u_rlfsr (.clk(rclk), .rst_n(rrst_sync_n), .en(rinc), .q(expected));

    logic err, got_data, empty_seen;
    always_ff @(posedge rclk or negedge rrst_sync_n) begin
        if (!rrst_sync_n) begin
            err <= 1'b0; got_data <= 1'b0; empty_seen <= 1'b0;
        end else begin
            if (rinc) begin
                got_data <= 1'b1;
                if (rdata !== expected) err <= 1'b1;
            end
            if (got_data && rempty) empty_seen <= 1'b1;
        end
    end

    logic [24:0] hb;
    always_ff @(posedge rclk or negedge rrst_sync_n) begin
        if (!rrst_sync_n) hb <= 25'd0;
        else              hb <= hb + 25'd1;
    end

    assign led = {locked, hb[24], empty_seen, full_seen, err};
endmodule
