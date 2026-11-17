// frequency counter module

module freq_count #(
    parameter int WIDTH = 32,
    parameter int WINDOW_CYCLES = 100_000_000
)(
    input ref_clk,
    input meas_clk,
    input rst_n,
    output logic [WIDTH-1:0] count,
    output logic valid
);

//meas_clk is the clock frequency that the module measures
//count and valid in ref_clk domain, rst_n is asynch

//SIGNAL DECLARATIONS
logic rst_ref_n;
logic rst_meas_n;
logic [WIDTH-1:0] gray_cnt;
logic [WIDTH-1:0] gray_sync;
logic [WIDTH-1:0] bin_sync;
logic have_prev;
localparam int CW = $clog2(WINDOW_CYCLES);
logic [CW-1:0] win_cnt;
logic [WIDTH-1:0] cur_count, prev_count;



reset_sync u_rst_ref(
    .clk(ref_clk),
    .rst_n(rst_n),
    .rst_sync_n(rst_ref_n)
);

reset_sync u_rst_meas(
    .clk(meas_clk),
    .rst_n(rst_n),
    .rst_sync_n(rst_meas_n)
);

gray_counter #(.WIDTH(WIDTH)) u_gray_counter(
    .clk(meas_clk),
    .rst_n(rst_meas_n),
    .en(1'b1),
    .gray(gray_cnt),
    .bin(),
    .next_gray()
);

gray2bin #(.WIDTH(WIDTH)) u_gray2bin(
    .gray(gray_sync),
    .bin(bin_sync)
);

genvar i;
for (i = 0; i < WIDTH; i++) begin : gen_sync
    sync_2ff u_sync_2ff (
        .clk(ref_clk),
        .rst_n(rst_ref_n),
        .d(gray_cnt[i]),
        .q(gray_sync[i])
    );
end

always_ff @(posedge ref_clk or negedge rst_ref_n) begin
    if (!rst_ref_n) begin
        count <= 0;
        valid <= 0;
        have_prev <= 0;
        win_cnt <= 0;
        cur_count <= 0;
        prev_count <= 0;
    end else begin
        valid <= 0;
        cur_count <= bin_sync;
        if (win_cnt == WINDOW_CYCLES - 1) begin
            win_cnt <= 0;
            prev_count <= cur_count;
            if (have_prev) begin
                count <= cur_count - prev_count;
                valid <= 1;
            end else begin
                have_prev  <= 1;
            end
        end else begin
            win_cnt <= win_cnt + 1;
        end
    end
end

endmodule