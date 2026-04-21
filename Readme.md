# RV32IMF RISC-V Hardware Calculator

This repository contains a 5-stage pipelined RISC-V processor with support for the RV32I (Base Integer), RV32M (Multiply/Divide), and RV32F (Single-Precision Floating Point) extensions. It includes a UART interface for communication and a C-based firmware calculator.

## Table of Contents
- [Features](#features)
- [Project Structure](#project-structure)
- [Recent Bug Fixes & Improvements](#recent-bug-fixes--improvements)
- [Getting Started](#getting-started)
- [Hardware Review](#hardware-review)

## Features
- **5-Stage Pipeline**: IF, ID, EX, MEM, WB with full hazard detection and forwarding.
- **RV32F Support**: Dedicated FPU handling FADD.S, FSUB.S, FMUL.S, FLW, FSW, etc.
- **UART Communication**: Integrated UART RX/TX for interactive debugging and data transfer.
- **Floating Point Calculator**: C firmware that parses expressions and computes results on hardware.

## Project Structure (Firmware Toolchain)

To run custom C code on this hardware, there are dedicated scripts and environment components designed to guide execution without requiring deep Verilog knowledge:

- **`Makefile`**: The master build script in the root directory. It automatically compiles your bare-metal C programs and coordinates sending the binaries to the FPGA. 
- **`c_toolchain/main.c`**: Your primary execution entry-point where you write your custom C application.
- **`c_toolchain/start.S`**: The critical Assembly bootloader. Bare-metal environments lack an operating system. This script zeros out the Stack Pointer (`sp`), maps the CPU memory footprint so you can safely use local variables, and configures the exception Trap vectors before jumping directly to your C `main()` function.
- **`c_toolchain/link.ld`**: The memory linker script. It structures the memory blocks, ensuring that the machine code begins exactly at address `0x00000000` (the processor's reset/boot address).
- **`c_toolchain/terminal.py`**: The interactive Python UART dispatcher. It connects over the Serial COM port, pushes the compiled `program.bin` instruction payload into the FPGA's boot memory, and drops you into a two-way UART terminal to parse `print_string()` outputs or read your keyboard expressions!

## Getting Started: Compiling & Running Code

### 1. Install Dependencies
You need the official RISC-V Bare-Metal GUI/Compiler installed to translate C files into hardware execution binaries.
1. Download **xPack GNU RISC-V Embedded GCC** for Windows.
2. Extract the archive and add its `\bin\` folder to your PC's System Environment `PATH` variables.
3. Ensure Python 3+ is installed (needed for the UART terminal).

### 2. Prepare the FPGA Hardware 
1. Open Xilinx Vivado.
2. "Generate Bitstream" targeting `top_fpga.v` and program your connected Artix-7 FPGA target.
3. Once flashed, the FPGA boots into an idle state, looping its hardware Bootloader waiting on the UART channel to receive the C instruction payload.

### 3. Writing and Disptaching Software
Anytime you modify `c_toolchain/main.c` or write a custom `.c` firmware file, you can compile and dispatch it to the FPGA automatically using the root `Makefile`! 

Open your Command Prompt or PowerShell in the root directory and use:
```bash
# Compiles the default 'main.c' and deploys it over the default COM3 port
make

# You can also pass custom C scripts and custom COM Ports!
make run FILE=c_toolchain/workload_alu.c COM=COM4
```

Behind the scenes, the Makefile will:
1. Compile your C Code (`riscv-none-elf-gcc`) against the `start.S` Stack Bootloader.
2. Extract the layout into raw machine code (`program.bin`).
3. Launch `terminal.py`, which flashes the `program.bin` chunks natively to the FPGA via serial.
4. Seamlessly switch into an interactive console so you can interface directly with your running firmware!

## Recent Bug Fixes & Improvements

### 1. Pipeline Load-Use Hazard Fix (`pipeline.v`)
- **Issue**: The `ex_mem_reg` was being stalled during Load-Use hazards. This caused the Load instruction to be "stuck" in the EX/MEM pipeline register, effectively deleting it and replacing it with the previous instruction.
- **Fix**: Re-routed the stall signal for the EX/MEM stage to `stage_stall_ex` (which ignores Load-Use stalls) while maintaining proper stalls for the IF/ID/EX boundaries. This ensures Load instructions advance to memory to fetch data.

### 2. Compiler Optimization Tuning (`build.bat`)
- **Issue**: GCC was generating `FMADD.S` (Fused Multiply-Add) instructions, which the hardware FPU does not support, causing illegal instruction exceptions.
- **Fix**: Added `-ffp-contract=off` to the compiler flags to disable FMA fusion, ensuring only base `FADD.S` and `FMUL.S` instructions are generated.

### 3. UART Terminal Stability (`terminal.py`)
- **Issue**: The Python terminal would crash with a `ctypes` error on exit due to improper serial port handling during `KeyboardInterrupt`.
- **Fix**: Implemented `os._exit(0)` in the interrupt handler to cleanly terminate the process and all threads.

### 4. UART TX FIFO Optimization (`uart_tx_fifo.v`)
- **Recommendation**: Removed asynchronous reset loops inside the memory array to allow Vivado to correctly map the FIFO to dedicated Block RAM (BRAM) instead of consuming thousands of LUTs.

## Hardware Review & Progress Report

> [!IMPORTANT]
> **Status**: The pipeline is now functionally correct at the architectural level. The critical "vanishing Load" bug has been resolved.

### Critical Findings:
1. **The "Silent" Pipeline Freeze**: The most significant blocker was the `ex_mem_reg` stalling during memory reads. Because the pipeline was technically still "running" but skipping memory loads, the firmware would loop infinitely or jump to zero-value addresses.
2. **Instruction Set Mismatch**: The RV32F implementation is specialized. Users must ensure the compiler is restricted from using Fused Multiply-Add (FMA) unless the FPU is upgraded to support the 3-op instruction format.
3. **UART Synchronization**: The 1-cycle latency match for UART reads in `top_fpga.v` is correctly implemented using `is_uart_read_r`, matching the BRAM timing.

### Recommendations for Future Development:
- **FPGA Utilization**: Monitor BRAM usage if the UART FIFO depth is increased.
- **FPU Exceptions**: Consider implementing IEEE-754 exception flags (Invalid, Overflow, etc.) in the CSR file for better debugging of edge-case math.
- **Timing Analysis**: As more features are added, check the "Set Up" and "Hold" times in Vivado, especially regarding the long paths through the FPU.

---
**Maintained by**: Antigravity AI & Purushottam Jha
**Date**: April 2026
