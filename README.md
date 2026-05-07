# RV32I CPU Project

This repository contains a from-scratch RISC-V RV32I CPU implementation written in **SystemVerilog**. The project is developed simulation-first using **Vivado/XSim**, with the long-term goal of running on a Xilinx/AMD FPGA.

Current verified blocks:

- `src/alu.sv` — arithmetic/logic unit
- `src/regfile.sv` — RV32I integer register file

Current testbenches:

- `sim/tb_alu.sv`
- `sim/tb_regfile.sv`

---

## 1. Requirements

Install:

- AMD/Xilinx **Vivado ML Standard**
- Device support for your target FPGA family
- A text editor, such as VS Code
- Git, if cloning from a repository

Set the FPGA part according to your board.

Example for a Digilent Cmod A7-35T:

```text
xc7a35tcpg236-1
```

If you are using a different FPGA board, replace that part number with your board's FPGA part.

The physical FPGA board is not required for the current stage. The project can be developed and tested in simulation.

---

## 2. Clone and enter the repository

Clone the repository and move into it:

```bash
git clone <REPOSITORY_URL>
cd <REPO_ROOT>
```

In the rest of this README:

```text
<REPO_ROOT>
```

means the root directory of the cloned repository.

---

## 3. Repository layout

The repository is organized like this:

```text
<REPO_ROOT>/
  README.md
  refresh_sources.tcl
  run_tests.tcl

  src/
    alu.sv
    regfile.sv

  sim/
    tb_alu.sv
    tb_regfile.sv

  vivado_proj/
    <VIVADO_PROJECT_NAME>/
      <VIVADO_PROJECT_NAME>.xpr
```

Conventions:

```text
src/  = synthesizable hardware modules
sim/  = simulation-only testbenches
```

Do not place testbenches in `src/`. Do not place design modules only in `sim/`.

---

## 4. Create or open the Vivado project

### Option A: Open an existing Vivado project

If the repository already includes a Vivado project file, open:

```text
<REPO_ROOT>/vivado_proj/<VIVADO_PROJECT_NAME>/<VIVADO_PROJECT_NAME>.xpr
```

Then, in the Vivado Tcl Console, move to the repository root:

```tcl
cd <REPO_ROOT>
```

For example:

```tcl
cd /path/to/cloned/repo
```

Then refresh the source files:

```tcl
source refresh_sources.tcl
```

### Option B: Create a new Vivado project

If the Vivado project is not included, create it from scratch:

1. Open Vivado.
2. Click **Create Project**.
3. Choose a project name, for example `<VIVADO_PROJECT_NAME>`.
4. Choose project location:

```text
<REPO_ROOT>/vivado_proj/
```

5. Select **RTL Project**.
6. Select **Do not specify sources at this time**.
7. Choose your FPGA part.

Example for Cmod A7-35T:

```text
xc7a35tcpg236-1
```

After the project opens, run:

```tcl
cd <REPO_ROOT>
source refresh_sources.tcl
```

---

## 5. Refreshing source files

Vivado does not automatically watch `src/` and `sim/` like a normal programming IDE. When new SystemVerilog files are added, refresh the Vivado file sets using:

```tcl
source refresh_sources.tcl
```

The script should contain:

```tcl
add_files -fileset sources_1 [glob -nocomplain ./src/*.sv ./src/*.v]
add_files -fileset sim_1    [glob -nocomplain ./sim/*.sv ./sim/*.v]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
```

Run it from `<REPO_ROOT>`.

If Vivado prints warnings like this:

```text
File '...' cannot be added to the project because it already exists in the project, skipping this file
```

that is harmless. It means the file is already known to Vivado.

---

## 6. Running the tests

From the Vivado Tcl Console:

```tcl
cd <REPO_ROOT>
source run_tests.tcl
```

Expected success output includes:

```text
All ALU tests passed.
All register file tests passed.
All requested testbenches completed.
```

If the output contains any of the following, a test failed or hung:

```text
FAIL
Fatal
TIMEOUT
```

Fix the first failing test before continuing.

---

## 7. Test runner script

The test runner should use a bounded runtime. Avoid unbounded `run all`, because many testbenches include clocks that run forever.

Recommended `run_tests.tcl`:

```tcl
source refresh_sources.tcl

proc run_tb {tb_name} {
    puts "========================================"
    puts "Running testbench: $tb_name"
    puts "========================================"

    if {[current_sim] ne ""} {
        close_sim
    }

    set_property top $tb_name [get_filesets sim_1]
    update_compile_order -fileset sim_1

    launch_simulation -simset sim_1 -mode behavioral

    # Bounded runtime. Each testbench should finish well before this.
    run 1us

    close_sim
}

run_tb tb_alu
run_tb tb_regfile

puts "========================================"
puts "All requested testbenches completed."
puts "========================================"
```

When adding a new testbench, add one line near the bottom:

```tcl
run_tb tb_<MODULE_NAME>
```

Example:

```tcl
run_tb tb_imm_gen
```

---

## 8. Testbench timeout pattern

Every testbench should either finish successfully with `$finish` or fail with `$fatal`.

Use this pattern to prevent silent hangs:

```systemverilog
logic done;

initial begin
  done = 1'b0;

  // Test sequence goes here.
  // If all checks pass:

  done = 1'b1;
  $finish;
end

initial begin
  #1000;
  if (!done) begin
    $display("TIMEOUT: testbench did not finish.");
    $fatal;
  end
end
```

The `done` flag is important. Without it, the timeout block can falsely fire after the test has already passed.

---

## 9. Current modules

### 9.1 ALU

File:

```text
src/alu.sv
```

The ALU is combinational. It has no clock and stores no state.

It supports the RV32I arithmetic and logic operations needed for:

```text
add, addi
sub
and, andi
or, ori
xor, xori
sll, slli
srl, srli
sra, srai
slt, slti
sltu, sltiu
```

It also supports address calculation for loads and stores through addition.

Testbench:

```text
sim/tb_alu.sv
```

Expected success message:

```text
All ALU tests passed.
```

---

### 9.2 Register file

File:

```text
src/regfile.sv
```

The register file implements the RV32I integer registers:

```text
x0 through x31
```

Required behavior:

- 32 registers
- 32 bits per register
- two combinational read ports
- one clocked write port
- active-low reset: `rst_n = 0` means reset is active
- `x0` always reads as zero
- writes to `x0` are ignored

The reads are combinational because reading only selects existing stored values. Writes are clocked because writing changes architectural CPU state and must only commit on a controlled clock edge.

Testbench:

```text
sim/tb_regfile.sv
```

Expected success message:

```text
All register file tests passed.
```

---

## 10. Adding a new module

For each new CPU block:

1. Add the synthesizable design file to `src/`.
2. Add the matching testbench to `sim/`.
3. Add the new testbench to `run_tests.tcl`.
4. Run the full test suite.
5. Do not move on until all existing tests still pass.

Example for an immediate generator:

```text
src/imm_gen.sv
sim/tb_imm_gen.sv
```

Then add this to `run_tests.tcl`:

```tcl
run_tb tb_imm_gen
```

Run:

```tcl
source run_tests.tcl
```

---

## 11. Development order

Build and verify the CPU incrementally:

1. `alu.sv` — arithmetic/logic unit
2. `regfile.sv` — integer register file
3. `imm_gen.sv` — immediate generator
4. `decoder.sv` — instruction decoder and control generation
5. simple instruction/data memory for simulation
6. `rv32_core.sv` — first integrated CPU core
7. small assembly programs in simulated memory
8. memory-mapped UART model
9. FPGA top-level wrapper
10. external SRAM controller
11. M extension: multiply/divide
12. C extension: compressed instructions

Avoid starting with pipelining, caches, Linux, privileged mode, or compressed instructions. Get a simple RV32I core working first.

---

## 12. Normal workflow

After editing files:

```text
1. Save all files in your editor.
2. In Vivado Tcl Console, run: cd <REPO_ROOT>
3. Run: source run_tests.tcl
4. Fix the first failing test, if any.
5. Repeat until all tests pass.
```

To debug only one testbench, temporarily comment out the others in `run_tests.tcl`:

```tcl
run_tb tb_alu
# run_tb tb_regfile
# run_tb tb_imm_gen
```

---

## 13. Common Vivado messages

### File already exists warning

```text
File '...' cannot be added to the project because it already exists in the project, skipping this file
```

This is usually harmless. It means `refresh_sources.tcl` tried to add a file that Vivado already knows about.

### On-the-fly syntax checking warning

```text
Attempt to get parsing info during refresh. "On-the-fly" syntax checking information may be incorrect.
```

Usually harmless while Vivado is refreshing sources or launching simulations.

### Environment variable warning

```text
One or more environment variables have been detected which affect the operation of the C compiler
```

Usually harmless unless elaboration or simulation fails. If simulation works, ignore it for now.

### Board part warnings at startup

Warnings about unrelated board parts are usually harmless if your project FPGA part is set correctly.

Check the project part in Vivado if synthesis or implementation fails.

---

## 14. Current success criteria

The project is healthy if:

```tcl
source run_tests.tcl
```

prints:

```text
All ALU tests passed.
All register file tests passed.
All requested testbenches completed.
```

and does not print:

```text
FAIL
Fatal
TIMEOUT
```

---

## 15. Next module

The next logical module is:

```text
src/imm_gen.sv
sim/tb_imm_gen.sv
```

The immediate generator extracts and sign-extends constants from RISC-V instructions. It is needed for instructions such as:

```text
addi
slti
sltiu
andi
ori
xori
lw
sw
beq
jal
jalr
lui
auipc
```

After `imm_gen.sv` passes its tests, move to the decoder.
