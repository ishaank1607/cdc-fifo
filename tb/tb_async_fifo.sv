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

task automatic check(input bit cond, input string msg);
   if (!cond) begin
       $error(msg);
       error_count = error_count + 1;
   end
endtask

task automatic run_traffic(input int wp, input int rp, input int cycles);
    write_prob <= wp;
    read_prob <= rp;
    repeat (cycles) @(posedge wclk);
endtask

task automatic drain();
    write_prob <= 0;
    read_prob <= 100;
    repeat (300) begin
        @(posedge rclk);
        if (expected_q.size() == 0) break;
    end
    repeat (10) @(posedge rclk);
endtask

initial begin
    int snap;
    wrst_n = 0;
    rrst_n = 0;
    winc = 0;
    rinc = 0;
    wdata = 0;
    #40;
    check(rempty === 1'b1 && wfull === 1'b0, "flags must be empty/not-full while reset is asserted");
    #10;
    wrst_n = 1;
    rrst_n = 1;
    #100;
    if (rempty !== 1'b1 || wfull !== 1'b0) begin
        check(rempty === 1'b1 && wfull === 1'b0, "FIFO should be empty after reset");
    end
    else begin
        $display("PASS: FIFO is empty after reset, all OK");
    end
    $display("--- Phase 1: fill ---");
    snap = writes_accepted;
    run_traffic(100, 0, 40);
    @(negedge wclk);
        check(writes_accepted - snap == 2**ADDR_W, "fill should accept exactly 16 writes");
        check(wfull === 1'b1, "wfull should be high when full");
        check(expected_q.size() == 2**ADDR_W, "queue should hold 16 entries");
        check(full_hits > 0, "should have seen blocked writes while full");
    $display("--- Phase 2: drain ---");
    drain();
    check(rempty === 1'b1, "rempty should be high after draining");
    check(expected_q.size() == 0, "queue should be empty after draining");
    run_traffic(50, 50, 1000);
    drain();
    check(rempty === 1'b1, "rempty should be high after draining");
    check(expected_q.size() == 0, "queue should be empty after draining");
    $display("writes accepted: %0d, reads accepted: %0d, full hits: %0d, empty hits: %0d, errors: %0d",
         writes_accepted, reads_accepted, full_hits, empty_hits, error_count);
    if (error_count == 0) begin
        $display("PASS");
    end else begin
        $display("FAIL: FIFO test completed with %0d errors", error_count);
    end
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