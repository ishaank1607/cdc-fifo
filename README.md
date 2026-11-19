# cdc-fifo

An asynchronous FIFO and the clock-domain-crossing blocks it is built from, written in SystemVerilog
and run on a Digilent Basys 3 (Artix-7 XC7A35T-1). I wrote the synchronizers, gray-code counter, FIFO,
and testbench from scratch, with no Xilinx FIFO or CDC IP. The only Xilinx IP I used is the Clocking
Wizard (MMCM), to make two independent clocks for the board demo.

## Status

| Item | State |
|---|---|
| CDC primitives (2-flop synchronizer, reset synchronizer, gray counter, gray-to-binary) | Written |
| Asynchronous FIFO (`async_fifo`) | Written, synthesizes and implements cleanly |
| Self-checking testbench: reset checks, directed fill and drain, random traffic | Passing |
| Testbench checked against injected bugs | Done (5 bugs, see Verification) |
| Clock-ratio sweep and reset in the middle of operation | Not done |
| Board demo (100 MHz writer, 37 MHz reader, LFSR check) | Built and run; error LED stayed off, full and empty both seen |
| Timing (both clocks declared asynchronous) | Met |
| `report_cdc` | 0 unsafe, 0 missing `ASYNC_REG`, 1 endpoint reported Unknown (waiver added, see below) |
| Frequency counter (`freq_count`) | Written, not verified (no testbench yet) |

## FIFO design

`async_fifo` is a dual-clock FIFO with `DATA_W` data bits and depth `2**ADDR_W` (defaults 8 x 16).

```
 write domain (wclk)                        read domain (rclk)
 winc, wdata -> gray_counter (wptr) -wgray-> [2FF sync x (ADDR_W+1)] -> write pointer in read domain
                   | wbin[ADDR_W-1:0]                                        |
                   v                                                    rempty logic
               memory ------------------------------------------------>  rdata <- rbin
 wfull logic <- [2FF sync x (ADDR_W+1)] <-rgray- gray_counter (rptr) <- rinc
```

How it works and why I built it this way:

- Pointers are `ADDR_W + 1` bits wide. The extra bit is how the FIFO tells full from empty when the
  address bits match.
- Each pointer is counted in binary and registered in gray code, so only one bit changes per step. A
  pointer sampled mid-change in the other clock domain is either the old or the new value, never garbage.
- Each gray pointer bit crosses through a two-flop synchronizer marked `ASYNC_REG`, clocked and reset in
  the destination domain.
- `wfull` and `rempty` are registered and computed from the next pointer values. `wfull` resets to 0 and
  `rempty` resets to 1. The synchronized pointers lag, so the flags are conservative: the FIFO never
  overflows or underflows, at a small cost in throughput.
- Each domain has its own reset synchronizer (asynchronous assert, synchronous release). Both resets
  should be asserted together.
- Memory is a plain array with a clocked write and a combinational read, which Vivado maps to
  distributed RAM. `rdata` shows the head entry as soon as `rempty` is low.
- Depth has to be a power of two so the gray-code sequence wraps cleanly.

## Repository layout

```
src/           reusable RTL
  sync_2ff.sv        single-bit two-flop synchronizer
  reset_sync.sv      reset synchronizer (async assert, sync deassert)
  gray_counter.sv    binary counter with registered gray output (also exports binary and next-gray)
  gray2bin.sv        gray-to-binary decoder
  asynch_fifo.sv     asynchronous FIFO (module async_fifo)
  freq_count.sv      frequency counter: gray-coded counter crossing into a reference clock
tb/
  tb_async_fifo.sv   self-checking testbench
demo/
  fifo_demo_top.sv   Basys 3 demo top level
  lfsr.sv            8-bit LFSR (module lfsr8)
constraints/
  basys3_constr.xdc  pins, clock, asynchronous clock groups, CDC waiver
```

## Verification

`tb/tb_async_fifo.sv` is a self-checking testbench. The write and read sides are driven by random
request probabilities (`write_prob`, `read_prob`). A scoreboard queue records every accepted write and
checks every accepted read, in order, and also flags underflow (data read that was never written) and
overflow (more entries outstanding than the FIFO holds). The test runs in phases:

1. **Reset:** the flags must read empty and not full while reset is still asserted, and again after it
   is released.
2. **Fill:** with the reader off, 40 write-clock cycles must accept exactly 16 writes, leave `wfull`
   high, and leave 16 entries outstanding. Writes attempted while full are counted and must be ignored.
3. **Drain:** the reader runs until the scoreboard is empty. All 16 must come back in order and
   `rempty` must go high.
4. **Random:** 1000 write-clock cycles at 50% write and 50% read probability, then a final drain and
   end-state checks.

Result with a 10 ns write clock and a 7 ns read clock: 507 writes accepted, 507 reads accepted,
24 blocked writes while full, `rempty` seen on 538 read-clock cycles, 0 errors. The random phase never
reaches full because the read clock is faster, so the fill phase and the board demo are what exercise
the full flag.

### Checking the testbench against broken designs

To make sure the testbench can actually fail, it was run against five hand-made broken copies of the
FIFO (kept out of this repo):

| Injected bug | Result |
|---|---|
| `wfull` compare with one inversion dropped | Caught (overflow errors) |
| Memory read address one bit too narrow | Caught (data mismatches) |
| Memory write not gated by `!wfull` | Caught (data mismatch) |
| `rempty` computed from the current pointer instead of the next | Caught (read of data nobody wrote) |
| `rempty` resetting to 0 instead of 1 | Missed by my first version |

The last one is why the testbench now checks the flags while reset is still asserted: the wrong value
only lasts a few cycles after reset releases, so a check made later never sees it. With that check added
it fails as it should.

Not covered yet: sweeping the clock ratio (faster writer, near-equal periods) and reset in the middle of
operation.

## Board demo (Basys 3)

`demo/fifo_demo_top.sv` generates two clocks from the 100 MHz board clock with an MMCM (100 MHz write
clock, 37 MHz read clock, VCO 925 MHz), holds reset until the MMCM locks, and runs an LFSR writer and
checker around the FIFO. The writer pushes an LFSR sequence whenever the FIFO is not full. The reader
pops whenever it is not empty and compares each word against its own copy of the LFSR. Any mismatch sets
a sticky error flag.

| LED | Meaning |
|---|---|
| `led[0]` | Data mismatch (must stay off) |
| `led[1]` | FIFO was full at some point since reset |
| `led[2]` | FIFO was empty at some point after the first read |
| `led[3]` | Read-clock heartbeat (about 1 Hz) |
| `led[4]` | MMCM locked |

`sw[0]` throttles the reader to one request in 16 cycles, so the FIFO fills. `sw[1]` throttles the
writer the same way, so the FIFO drains. `btnC` resets and clears the latched LEDs.

On the board, `led[1]` lights immediately in the default mode (the 100 MHz writer outruns the 37 MHz
reader), `led[2]` lights with `sw[1]` high, and `led[0]` stayed off. I have not recorded a timed
long-duration run yet.

The Clocking Wizard instance is `clk_wiz_0` and is not stored in this repo. To recreate it: primary
input 100 MHz, `clk_out1` 100 MHz, `clk_out2` 37 MHz, with the active-high `reset` and `locked` ports.

## Implementation results (fifo_demo_top, Vivado 2026.1, xc7a35tcpg236-1)

- **Timing:** met with both clocks declared asynchronous. Worst setup slack +6.902 ns and worst hold
  slack +0.083 ns. The 100 MHz domain has +6.902 ns setup and +0.083 ns hold, and the 37 MHz domain has
  +22.267 ns setup and +0.122 ns hold. Asynchronous reset recovery and removal checks pass too.
- **Utilization:** 52 LUTs (6 as distributed RAM), 105 flip-flops, 0 block RAM, 0 DSP, 1 MMCM, 3 BUFG,
  9 I/O pins, no latches.
- `async_fifo` on its own synthesizes to 30 LUTs and 44 flip-flops.

One thing I got wrong at first: my clock-group constraint used the wrong clock names. The implemented
clocks are called `clk_out1_clk_wiz_0_1` and `clk_out2_clk_wiz_0_1`, so Vivado treated the two clocks
as related and reported false failures of up to -3.4 ns on the crossings. Matching the names with a
wildcard fixed it.

### CDC report

`report_cdc` finds 12 endpoints between the two clocks: 11 safe, 0 unsafe, 0 without `ASYNC_REG`, and one
reported Unknown (CDC-1). The Unknown one is the FIFO memory read path, from the RAM written in the write
clock domain into the read-domain error check (`u_fifo/mem_reg_0_15_0_5/RAMC_D1/CLK` to `err_reg/CE`).
It is safe by protocol: `rempty` only deasserts after the write pointer has crossed two synchronizer
stages, so the entry has been stable for at least two read-clock cycles before it is read, and an entry is
not overwritten until the read pointer has crossed back. Vivado can't prove that, so it reports the path
as Unknown. I added a waiver for it in the constraints file, and I have not re-run the reports since to
confirm it clears.

Other methodology warnings still open: no output delay on the LED outputs, a LUT driving an asynchronous
reset (`~btnC & locked`), and auto-derived clocks referenced by the clock-group constraint.

## Running the simulation

1. Create a Vivado project for part xc7a35tcpg236-1.
2. Add `src/` as design sources (uncheck "Copy sources into project").
3. Add `tb/tb_async_fifo.sv` as a simulation source and set it as the simulation top.
4. Run Behavioral Simulation, then type `run all` in the Tcl console. The summary and a PASS or FAIL line
   print at the end.

## Building the board demo

1. Create `clk_wiz_0` as described above.
2. Add `src/` and `demo/` as design sources and `constraints/basys3_constr.xdc` as constraints. Set
   `fifo_demo_top` as the design top (not the simulation top).
3. Run synthesis, implementation, and bitstream generation, then program the board.

## Notes on how this was built

I used Claude throughout as a tutor and reviewer: explaining the concepts, reviewing my code, and helping
me debug. I wrote the CDC modules, the FIFO, and the testbench myself. The board-demo files
(`demo/lfsr.sv`, `demo/fifo_demo_top.sv`) and the first draft of the constraints file were drafted by
Claude; I built them, ran them on the board, and debugged the constraint and top-module problems that
came up.

## Still to do

- Clock-ratio sweep and reset-in-the-middle tests
- A testbench for `freq_count`
- Re-run the CDC and timing reports with the waiver, and add an output-delay or false-path constraint
  for the LEDs
- A recorded long-duration run on the board
