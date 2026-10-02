# Development guide (Vivado / XSim)

Portfolio overview lives in the root [README](../README.md). This document keeps the detailed simulation and FPGA workflow.

---

## Requirements

- AMD/Xilinx Vivado with XSim
- Linux shell, Python 3
- RISC-V bare-metal toolchain (`riscv64-unknown-elf-gcc`, `objcopy`, `objdump`)

```bash
sudo apt update
sudo apt install gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf python3
```

---

## Layout

```text
src/           design modules (alu, regfile, imm_gen, decoder, branch_comp,
               pc_unit, fiu, lsu, rv32_core, cmod_a7_top)
sim/           testbenches (tb_*)
asm/           assembly programs
programs/      generated .hex for $readmemh
scripts/       asm_to_hex.sh, bin_to_hex.py, linker.ld
constraints/   Cmod A7 XDC
build/         assembler/linker outputs
refresh_sources.tcl
```

Generated Vivado folders (`.sim/`, `.cache/`, `.Xil/`, waveforms) are not source.

---

## Hardware modules (summary)

| Module | Role |
| --- | --- |
| `alu.sv` | Combinational ADD/SUB/AND/OR/XOR/SLL/SRL/SRA/SLT/SLTU (`op` is internal, not the RISC-V opcode) |
| `regfile.sv` | `x0`–`x31`, `x0` hardwired 0; 2 read / 1 sync write |
| `imm_gen.sv` | I/S/B/U/J/SHAMT immediates |
| `decoder.sv` | Control signals only (no execute) |
| `branch_comp.sv` | BEQ/BNE/BLT/BGE/BLTU/BGEU |
| `pc_unit.sv` | pc+4, branch/JAL, JALR (`& ~1`), stall hold |
| `fiu.sv` | Word-addressed IMEM; optional `$readmemh` via `INIT_FILE` |
| `lsu.sv` | LB/LH/LW/LBU/LHU/SB/SH/SW + misalignment detect; optional DMEM init |
| `rv32_core.sv` | Single-cycle integrate; exposes `pc`, `instr`, `halted`, `trap`, `debug_x3` |
| `cmod_a7_top.sv` | Digilent Cmod A7 top: reset/stall buttons, LED status |

`ebreak`, `ecall`, illegal instructions, and misaligned instruction/data accesses halt/trap the core.

---

## Assembly → hex flow

```text
asm/<name>.S
  → riscv64-unknown-elf-gcc (rv32i / ilp32, freestanding, scripts/linker.ld)
build/<name>.elf
  → objcopy -O binary
build/<name>.bin
  → scripts/bin_to_hex.py
programs/<name>.hex
  → $readmemh into fiu.mem
```

```bash
./scripts/asm_to_hex.sh core_basic
cat programs/core_basic.hex
cat build/core_basic.dump
```

**Editing assembly is not enough** — rebuild the hex, then **close and relaunch** simulation so `$readmemh` runs again. Vivado does not assemble `.S` files.

---

## `IMEM_INIT_FILE` / path notes

`fiu` and `lsu` only load when their `INIT_FILE` is nonempty:

```systemverilog
parameter string INIT_FILE = "";
```

`rv32_core` defaults to empty strings:

```systemverilog
parameter string IMEM_INIT_FILE = "";
parameter string DMEM_INIT_FILE = "";
```

Testbenches and `cmod_a7_top` override `IMEM_INIT_FILE` with a **repo-relative** path such as `programs/core_basic.hex`. `$readmemh` resolves paths relative to the **simulator / Vivado working directory**. If load fails:

1. Pass an absolute path to your checkout, or
2. Set the sim working directory to the repo root.

Do not leave machine-specific absolute paths (e.g. `/home/...`) in committed defaults.

For FPGA synthesis, set `IMEM_INIT_FILE` on the `rv32_core` instance in `cmod_a7_top.sv` to a path Vivado can see when elaborating `$readmemh`.

---

## Refresh Vivado sources

```tcl
cd <REPO_ROOT>
source refresh_sources.tcl
```

Prefer files under `<REPO_ROOT>/src` and `sim`, not copies inside a generated project tree.

---

## Running one testbench

```tcl
cd <REPO_ROOT>
source refresh_sources.tcl
set_property source_mgmt_mode None [current_project]
set_property top <TESTBENCH_NAME> [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
launch_simulation -simset sim_1 -mode behavioral
run all
```

Use `run all` when the TB calls `$finish`; use a bounded `run 1us` / `run 20ms` if unsure.

### Unit tests

`tb_alu`, `tb_regfile`, `tb_imm_gen`, `tb_decoder`, `tb_branch_comp`, `tb_pc_unit`, `tb_fiu`, `tb_lsu`

Expect messages like `All ALU tests passed.`

### Core smoke — `tb_rv32_core`

End-to-end program checks on registers / DMEM. Expect `All RV32 core tests passed.`

> This TB historically expected a richer program than the minimal `core_basic.S` smoke used by the FPGA top. If checks fail, confirm `programs/core_basic.hex` matches the expectations in the testbench (or point `IMEM_INIT_FILE` at the intended image).

### Debug trace — `tb_rv32_core_debug`

```bash
./scripts/asm_to_hex.sh core_basic
```

```tcl
set_property top tb_rv32_core_debug [get_filesets sim_1]
launch_simulation -simset sim_1 -mode behavioral
run all
```

Per-instruction trace + register/DMEM dumps — visibility tool, not a strict pass/fail suite.

### Regression — `tb_rv32_core_regression`

Covers ALU R/I, LUI/AUIPC, loads/stores (signed/unsigned), branches, JAL/JALR, `x0`, FENCE, ECALL/EBREAK, illegal and misaligned traps, negative immediates, backward-branch stress.

```tcl
set_property top tb_rv32_core_regression [get_filesets sim_1]
launch_simulation -simset sim_1 -mode behavioral
run 20ms
```

Expect `ALL RV32 CORE REGRESSION TESTS PASSED`.

---

## If XSim gets stuck compiling

If the log sits on `xvlog --incr --relax ...`, compilation is still running (often because many large TBs are in `sim_1`).

```bash
ps aux | egrep "xvlog|xelab|xsim" | grep -v grep
pkill -TERM -f xvlog; pkill -TERM -f xelab; pkill -TERM -f xsim
# if needed: pkill -KILL -f xvlog|xelab|xsim
rm -rf <VIVADO_PROJECT_DIR>/<PROJECT_NAME>.sim/sim_1/behav/xsim
```

### Faster debug: one TB in `sim_1`

```tcl
cd <REPO_ROOT>
remove_files [get_files -quiet ./sim/tb_*.sv]
add_files -fileset sim_1 ./sim/tb_rv32_core_debug.sv
source refresh_sources.tcl
set_property source_mgmt_mode None [current_project]
set_property top tb_rv32_core_debug [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
launch_simulation -simset sim_1 -mode behavioral
run all
```

---

## Stale assembly / stale SV in Vivado

After editing `asm/*.S`:

```bash
./scripts/asm_to_hex.sh core_basic
```

```tcl
close_sim
launch_simulation -simset sim_1 -mode behavioral
run all
```

If Vivado shows old SystemVerilog, check the file path — remove stale project copies and re-add from the repo:

```tcl
remove_files [get_files -quiet -all *rv32_core.sv]
add_files -fileset sources_1 ./src/rv32_core.sv
update_compile_order -fileset sources_1
```

---

## Suggested workflow

**RTL change:** edit one `src/` module → its unit TB → `tb_rv32_core` → optional debug → regression before calling it done.

**Asm change:** edit `asm/<prog>.S` → `scripts/asm_to_hex.sh <prog>` → relaunch sim → `tb_rv32_core_debug`.

**FPGA:** set `IMEM_INIT_FILE`, apply `constraints/cmod_a7_cpu_smoke.xdc`, synthesize/implement `cmod_a7_top`.

---

## Limitations / next steps

Not yet: external SRAM, UART/MMIO, full CSR/interrupt story, M/C extensions, pipelining, compliance-suite CI.

Likely next: more asm programs, sim MMIO debug output, richer FPGA memory map, then broader on-hardware bring-up.
