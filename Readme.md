# RISC-V 32-bit Pipelined Processor (RV32IM)

Welcome to our custom RISC-V soft-core processor repository! This project implements a fully functional 32-bit RISC-V CPU from scratch, designed to be synthesized onto an Artix-7 FPGA. It's written entirely in Verilog and includes a custom C toolchain, memory-mapped I/O, and hardware mathematical units.

## 🚀 What We Are Doing
We are building a custom central processing unit (CPU) that understands the standard RISC-V instruction set architecture (specifically the **RV32IM** base integer instruction set with multiplication/division extensions). 

Instead of buying a processor from companies like Intel, AMD, or ARM, we have written the underlying hardware logic ourselves. We also created our own software toolchain to take standard C code, compile it into machine code, and execute it on our physical hardware chip.

### Explaining The Project (For Non-Engineers)
Think of a processor as a high-speed factory assembly line. Our project is the blueprint for a factory that processes *Math and Logic* instead of building cars.
- **The 5-Stage Pipeline (The Assembly Line):** We built an assembly line with 5 distinct stations (Fetch, Decode, Execute, Memory, Write-Back). While one instruction is being decoded, another is being fetched, keeping the factory running at maximum efficiency.
- **The 'M' Extension (The specialized robot):** We built a specialized circuit designed *only* to do fast multiplication and division.
- **UART (The Walkie-Talkie):** We added a way for our processor chip to talk directly to a modern laptop screen over a standard USB/Serial cable, so we can see the results of its work in real-time.

---

## 🏗️ Architecture Overview
The processor is built around a classic 5-stage RISC pipeline and employs a Harvard Architecture (separate instruction and data memories).

1. **Pipeline Stages:**
   - `if_stage.v` (Instruction Fetch): Grabs the next instruction from Instruction Memory (`imem`).
   - `id_stage.v` (Instruction Decode): Figures out what the instruction means and reads the registers.
   - `ex_stage.v` (Execute): The ALU (Arithmetic Logic Unit). Performs the math or logic operation.
   - `mem_stage.v` (Memory): Reads/Writes data to the Data Memory (`dmem`).
   - `wb_stage.v` (Write-Back): Saves the result back into the processor's register file.

2. **Advanced Hardware:**
   - **Hazard Unit:** (`hazard_unit.v`) Resolves data dependencies and pipeline stalls automatically to prevent incorrect math resulting from the fast assembly-line nature of the pipeline.
   - **Multiplier/Divider:** (`mult_div.v`) A hardware unit handling the RV32M extensions.
   - **Memory Mapped I/O (UART):** (`uart.v`, `top_fpga.v`) Communication modules mapped to address `0x8000_0000`. Writing to this exact memory address automatically sends data over a physical wire to a computer terminal.

3. **Software Toolchain:**
   - Located in the `c_toolchain/` directory. We write C code (like `main.c` or `workload_alu.c`), compile it, and generate hexadecimal (`imem.hex`, `dmem.hex`) files that preload into the FPGA RAM on startup.

---

## 🖥️ How to Run & See Outputs

### 1. Observing Through Simulation (Software Only)
If you don't have the FPGA board physically plugged into your computer, you can still test the logic using **Icarus Verilog**:
1. Open a terminal in the root directory.
2. Compile the CPU testbench:
   ```bash
   iverilog -o sim_soc.vvp tb_uart_soc.v top_fpga.v ...
   ```
   *(Scripts are provided in the repo to handle compilation automatically).*
3. Run the simulation:
   ```bash
   vvp sim_soc.vvp
   ```
4. Output text from the simulated CPU will print directly to your terminal. Waveform data will be saved to a `.vcd` file which you can open visually in **GTKWave**.

### 2. Observing on the Physical FPGA (Hardware)
To see the processor running in real life on the Artix-7 board:
1. Synthesize the project using Xilinx Vivado, utilizing the constraints mapped out in `constraint.xdc`.
2. Flash the generated bitstream onto the FPGA board.
3. Once the board is flashing (you'll see diagnostic LEDs light up!), plug a serial cable from the board to your PC.
4. Open a serial monitor like **PuTTY** or **TeraTerm**.
   - **Port:** (Check Device Manager, e.g., `COM3`)
   - **Baud Rate:** `115200`
   - **Data bits:** `8`, **Stop bits:** `1`, **Parity:** `None`
5. Press the reset button on the FPGA to restart the program. You will see the C program's output print live into your PuTTY window!

---
*Created for our Hardware Lab Project.*
