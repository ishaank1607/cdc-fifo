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
int write_prob = 0;                 
int read_prob  = 0;
logic [DATA_W-1:0] expected_q [$];  
logic [DATA_W-1:0] exp;             
logic [DATA_W-1:0] next_wdata = 0;  
int writes_accepted = 0, reads_accepted = 0;
int full_hits = 0, empty_hits = 0, error_count = 0;

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
    #100;
    if (rempty !== 1'b1 || wfull !== 1'b0) begin
        $error("ERROR: FIFO should be empty after reset");
    end
    else begin
        $display("PASS: FIFO is empty after reset, all OK");
    end
    write_prob = 50;
    read_prob  = 50;
    #10000;
    $display("Simulation finished, writes accepted: %0d, reads accepted: %0d, full hits: %0d, empty hits: %0d, errors: %0d", writes_accepted, reads_accepted, full_hits, empty_hits, error_count);
    $finish;
end

always @(negedge wclk) begin  //write stimulus
    if (wrst_n) begin
        winc <= ($urandom_range(0,99) < write_prob);
        wdata <= next_wdata;
        next_wdata <= next_wdata + 1;
    end else begin
        winc <= 0;
    end
end

always @(posedge wclk) begin   //write monitor
    if (wrst_n) begin
        if (winc && !wfull) begin
            expected_q.push_back(wdata);
            writes_accepted <= writes_accepted + 1;
        end
        else if (winc && wfull) begin
            full_hits <= full_hits + 1;
        end
        if (expected_q.size() > (1 << ADDR_W)) begin
            $error("ERROR: FIFO overflow, expected_q size exceeded FIFO capacity");
            error_count = error_count + 1;
        end
    end
end

always @(negedge rclk) begin   //read stimulus
    if (rrst_n) begin
        rinc <= ($urandom_range(0,99) < read_prob);
    end else begin
        rinc <= 0;
    end
end

always @(posedge rclk) begin  //read monitor and scoreboard
    if (rrst_n) begin
        if (rinc && !rempty) begin
            if (expected_q.size() == 0) begin
                $error("ERROR: FIFO gave data nobody wrote");
                error_count = error_count + 1;
            end else begin
                exp = expected_q.pop_front();
                if (exp !== rdata) begin
                    $error("ERROR: Data mismatch between expected and actual");
                    error_count = error_count + 1;
                end
                reads_accepted <= reads_accepted + 1;
            end
        end
        if (rempty) begin
            empty_hits <= empty_hits + 1;
        end
    end
end




endmodule