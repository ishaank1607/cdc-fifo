// testbench for asynch FIFO

`timescale 1ns/1ps

module tb_async_fifo;

//SIGNAL DECLARATIONS/INITIALIZATION

localparam int DATA_W = 8;
localparam int ADDR_W = 4;

logic wclk;
logic wrst_n;
logic winc;
logic [DATA_W-1:0] wdata;
logic rclk;
logic rrst_n;
logic rinc;
logic [DATA_W-1:0] rdata;
logic rempty;
logic wfull;
real wperiod = 10.0;
real rperiod = 7.0;

async_fifo #(
    .DATA_W(DATA_W),
    .ADDR_W(ADDR_W)
) dut (
    .wclk(wclk),
    .wrst_n(wrst_n),
    .winc(winc),
    .wdata(wdata),
    .rclk(rclk),
    .rrst_n(rrst_n),
    .rinc(rinc),
    .rdata(rdata),
    .rempty(rempty),
    .wfull(wfull)
);

initial begin
    wclk = 0;
    forever begin
    #(wperiod/2.0) wclk = ~wclk;
    end
end

initial begin
    rclk = 0;
    forever begin
    #(rperiod/2.0) rclk = ~rclk;
    end
end

initial begin
    wrst_n = 0;
    rrst_n = 0;
    winc = 0;
    rinc = 0;
    wdata = 0;
    #50;
    wrst_n = 1;
    rrst_n = 1;
    #300;
    if (rempty !== 1'b1 || wfull !== 1'b0) begin
        $error("ERROR: FIFO should be empty after reset");
    end
    else begin
        $display("PASS: FIFO is empty after reset, all OK");
    end
    $finish;
end

endmodule