# cdc-fifo

Clock-domain-crossing building blocks and an asynchronous FIFO in SystemVerilog, targeting the
Digilent Basys 3 (Artix-7 XC7A35T-1). The CDC primitives, the FIFO, and the testbench are written
from scratch; no Xilinx FIFO or CDC IP is used. The only Xilinx IP is the Clocking Wizard (MMCM),
used to generate two independent clocks for the board demo.

## Status

| Item | State |
|---|---|
| CDC primitives (2-flop synchronizer, reset synchronizer, gray counter, gray-to-binary) | Written |
| Asynchronous FIFO (`async_fifo`) | Written, synthesizes and implements cleanly |
| Self-checking testbench (random traffic + scoreboard) | Passing |
| Directed corner-case tests (fill, drain, clock-ratio sweep, reset mid-run) | Not done |
| Board demo on Basys 3 (100 MHz writer, 37 MHz reader, LFSR check) | Built and run; error LED stayed off, full and empty both observed |
| Timing (implementation, both clocks declared asynchronous) | Met |
| `report_cdc` | 0 unsafe, 0 missing `ASYNC_REG`, 1 endpoint reported Unknown (see below) |
| Frequency counter (`freq_count`) | Written, not verified (no testbench yet) |

## FIFO design

`async_fifo` is a parameterized dual-clock FIFO: `DATA_W` data bits, depth `2**ADDR_W` (defaults 8 x 16).

```
 write domain (wclk)                        read domain (rclk)
 winc, wdata -> gray_counter (wptr) -wgray-> [2FF sync x (ADDR_W+1)] -> write pointer in read domain
                   | wbin[ADDR_W-1:0]                                        |
                   v                                                    rempty logic
               memory ------------------------------------------------>  rdata <- rbin
 wfull logic <- [2FF sync x (ADDR_W+1)] <-rgray- gray_counter (rptr) <- rinc
```

Design choices:

- Pointers are `ADDR_W + 1` bits wide; the extra bit distinguishes full from empty.
- Each pointer is counted in binary and registered in gray code, so only one bit changes per step. A
  pointer sampled mid-change in the other clock domain is either the old or the new value.
- Each gray pointer bit crosses through a two-flop synchronizer marked `ASYNC_REG`, clocked and reset in
  the destination domain.
- `wfull` and `rempty` are registered and computed from the next pointer values. `wfull` resets to 0 and
  `rempty` resets to 1. Because the synchronized pointers lag, the flags are conservative: the FIFO never
  overflows or underflows, at a small cost in throughput.
- Each domain has its own reset synchronizer (asynchronous assert, synchronous release). Assert both
  resets together.
- Memory is a plain array with a clocked write and a combinational read, which synthesizes to
  distributed RAM. `rdata` shows the head entry as soon as `rempty` is low.
- Depth must be a power of two, so the gray-code sequence wraps cleanly.

## Repository layout

```
src/           reusable RTL
  sync_2ff.sv        single-bit two-flop synchronizer
  reset_sync.sv      reset synchronizer (async assert, sync deassert)
  gray_counter.sv    binary counter with registered gray output (also exports binary and next-gray)
  gray2bin.sv        gray-to-binary decoder
  asynch_fifo.sv     asynchronous FIFO (module async_fifo)
  freq_count.sv      frequency counter using a gray-coded counter crossing into a reference clock
tb/
  tb_async_fifo.sv   self-checking testbench
demo/
  fifo_demo_top.sv   Basys 3 demo top level
  lfsr.sv            8-bit LFSR (module lfsr8)
constraints/
  basys3_constr.xdc  pins, clock, asynchronous clock groups
```

## Verification

`tb/tb_async_fifo.sv` is a self-checking SystemVerilog testbench:

- Random write and read requests with configurable probabilities (`write_prob`, `read_prob`).
- A scoreboard queue records every accepted write and checks every accepted read, in order.
- Checks for underflow (data read that was never written) and overflow (more entries than the FIFO holds).
- Reset-state check: after reset the FIFO must be empty and not full.

Current result: write clock 10 ns, read clock 7 ns, 50% write / 50% read request probability for 10 us:
489 writes accepted, 488 reads accepted (the last entry was still in flight), 0 errors. The faster read
clock keeps the FIFO near empty, so this run does not reach full. Full is exercised on the board (below).

Not yet covered in simulation: directed fill and drain, a faster write clock, near-equal clock periods,
and reset in the middle of operation.

## Board demo (Basys 3)

`demo/fifo_demo_top.sv` generates two clocks with an MMCM from the 100 MHz board clock (100 MHz write
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

`sw[0]` throttles the reader to one request in 16 cycles (the FIFO fills). `sw[1]` throttles the writer
the same way (the FIFO drains). `btnC` resets and clears the latched LEDs.

Observed on the board: in the default mode `led[1]` lights immediately (the 100 MHz writer outruns the
37 MHz reader); with `sw[1]` high `led[2]` lights; `led[0]` stayed off.

The Clocking Wizard instance is named `clk_wiz_0` and is not stored in this repository. To recreate it:
primary input 100 MHz, `clk_out1` 100 MHz, `clk_out2` 37 MHz, active-high `reset` and `locked` enabled.

## Implementation results (fifo_demo_top, Vivado 2026.1, xc7a35tcpg236-1)

- Timing: met with both clocks declared asynchronous. Worst setup slack +6.902 ns, worst hold slack
  +0.083 ns. The 100 MHz domain has +6.902 ns setup and +0.083 ns hold; the 37 MHz domain has
  +22.267 ns setup and +0.122 ns hold. Asynchronous reset recovery and removal checks also pass.
- Utilization: 52 LUTs (6 as distributed RAM), 105 flip-flops, 0 block RAM, 0 DSP, 1 MMCM, 3 BUFG,
  9 I/O pins, no latches.
- `async_fifo` alone synthesizes to 30 LUTs and 44 flip-flops.

### CDC report

`report_cdc` finds 12 endpoints between the two clocks: 11 safe, 0 unsafe, 0 without `ASYNC_REG`, and one
reported Unknown (CDC-1). The Unknown endpoint is the FIFO memory read path, from the RAM written in the
write clock domain into the read-domain error check (`u_fifo/mem_reg_0_15_0_5/RAMC_D1/CLK` to
`err_reg/CE`). It is safe by protocol: `rempty` only deasserts after the write pointer has crossed two
synchronizer stages, so the entry has been stable for at least two read-clock cycles before it is read,
and an entry is not overwritten until the read pointer has crossed back. Vivado cannot prove this, so it
reports the path as Unknown. A waiver for it has not been added to the constraints yet.

Other methodology warnings currently open: no output delay on the LED outputs, a LUT driving an
asynchronous reset (`~btnC & locked`), and auto-derived clocks referenced by the clock-group constraint.

## Running the simulation

1. Create a Vivado project for part xc7a35tcpg236-1.
2. Add `src/` as design sources (uncheck "Copy sources into project").
3. Add `tb/tb_async_fifo.sv` as a simulation source and set it as the simulation top.
4. Run Behavioral Simulation, then `run all` in the Tcl console. The summary line prints at the end.

## Building the board demo

1. Create `clk_wiz_0` as described above.
2. Add `src/` and `demo/` as design sources, `constraints/basys3_constr.xdc` as constraints, and set
   `fifo_demo_top` as the design top (not the simulation top).
3. Run synthesis, implementation, and generate the bitstream, then program the board.

## Planned

- Directed tests: fill to full, drain, faster write clock, near-equal clocks, reset mid-run
- Testbench for `freq_count`
- CDC waiver for CDC-1 and output-delay constraints on the LEDs
- Recorded long-duration board run
