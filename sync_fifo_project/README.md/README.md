# High-Performance Parametric Synchronous FIFO

## Overview
This repository contains a synthesis-ready, parameterizable Synchronous FIFO written in SystemVerilog. It is designed for high-performance ASIC/FPGA digital systems, ensuring glitch-free operation by strictly registering all output ports (including status flags). 

The design utilizes **Look-Ahead Pointer Logic** to update flags and data seamlessly without adding combinatorial delay paths to downstream modules.

## Block Diagram
*(Note to self: Create a simple block diagram in Draw.io showing the `clk/rst_n` driving the Write Control, Read Control, and the SRAM block, with pointers feeding into a Comparator block that drives the FFs for `full` and `empty`.)*

## Interface Signals

| Signal Name     | Width          | Direction | Description                                                               |
|-----------------|----------------|-----------|---------------------------------------------------------------------------|
| `clk`           | 1              | Input     | System Clock.                                                             |
| `rst_n`         | 1              | Input     | Active-low asynchronous reset.                                            |
| `w_en`          | 1              | Input     | Write Enable. Writes `data_in` to memory if FIFO is not full.             |
| `r_en`          | 1              | Input     | Read Enable. Reads data to `data_out` if FIFO is not empty.               |
| `data_in`       | `DATA_WIDTH`   | Input     | Data input bus.                                                           |
| `data_out`      | `DATA_WIDTH`   | Output    | Registered data output bus (1-cycle read latency).                        |
| `full`          | 1              | Output    | High when FIFO is completely full.                                        |
| `empty`         | 1              | Output    | High when FIFO has zero entries.                                          |
| `almost_full`   | 1              | Output    | High when FIFO entries >= `FIFO_DEPTH - ALMOST_FULL_THRESH`.              |
| `almost_empty`  | 1              | Output    | High when FIFO entries <= `ALMOST_EMPTY_THRESH`.                          |

---

## Architectural Deep Dive: N+1 Pointer Logic
One of the most critical design challenges in a FIFO is distinguishing between the **Full** and **Empty** states, as the Read and Write pointers point to the exact same physical memory address in both scenarios.

To handle this elegantly without utilizing a bulky hardware counter, this design utilizes the **N+1 Bit Pointer Technique**:

If the FIFO depth is $2^N$ (e.g., 16 elements), the memory address requires $N$ bits (4 bits). The internal pointers, however, are allocated $N+1$ bits (5 bits). 
* **The lower $N$ bits** act as the actual memory address.
* **The MSB (Most Significant Bit)** acts as a "wrap-around" toggle flag.

### Empty Condition
The FIFO is empty when the Write Pointer has exactly caught up to the Read Pointer. 
* **Logic:** `assign empty = (wr_ptr == rd_ptr);` (Both address bits and the wrap-around MSB are identical).

### Full Condition
The FIFO is full when the Write Pointer loops entirely around the memory and catches the Read Pointer from behind.
* **Logic:** The address bits ($N-1:0$) are identical, but the **Wrap-Around MSBs are inverted**. 
* `assign full = (wr_ptr[N] != rd_ptr[N]) && (wr_ptr[N-1:0] == rd_ptr[N-1:0]);`

### Handling Corner Cases (Over-Read / Over-Write)
The logic strictly masks enabling signals against the current full/empty state (`w_en && !full`). If a master device attempts to push data to a `full` FIFO, the logic simply drops the transaction, preventing corruption of previously written data.

---
## Simulation & Verification
The `/dv` directory contains a self-checking testbench (`tb_fifo.sv`). It instantiates a SystemVerilog Queue as a Golden Reference model. 
1. **Drive:** Stimulates the FIFO up to its limits (triggering `almost_full` and `full`).
2. **Corner Case Injection:** Intentionally pushes `w_en` while full, and `r_en` while empty to ensure pointer integrity.
3. **Check:** Compares the 1-cycle latency `data_out` against the Golden Queue.
