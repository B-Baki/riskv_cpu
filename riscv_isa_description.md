### Reason for use

- A simple subset of the RISC-V **RV32I base integer ISA**: 32-bit integer registers and 32-bit integer operations.
- This does **not** include multiplication/division (`M` extension), compressed 16-bit instructions (`C` extension), atomics (`A` extension), floating-point (`F`/`D`), or privileged/OS behavior.

### Registers and memory

- 32 32-bit integer registers: `x0` to `x31`.
- `x0` is hardwired to zero. Reads always return `0`; writes are ignored.
- The program counter `PC` stores the **byte address** of the current instruction, not a source-code line number.
- In base RV32I without the compressed extension, normal instructions are 32 bits = 4 bytes, so instruction addresses are normally 4-byte aligned.
- Data memory is **byte-addressed**. Byte, halfword, and word accesses are possible:
  - byte = 8 bits
  - halfword = 16 bits
  - word = 32 bits
- Natural alignment means:
  - byte accesses can use any address
  - halfword accesses should normally use addresses where `Address % 2 == 0`
  - word accesses should normally use addresses where `Address % 4 == 0`
- If assuming a little-endian system: the **least-significant byte** of a multi-byte value is stored at the lowest memory address.
- Bits are numbered from least significant to most significant: bit `0` is the least-significant bit, bit `31` is the most-significant bit in a 32-bit value.

| Register      | ABI Name | Description               | Preserved across calls? |
| ------------- | -------- | ------------------------- | ----------------------- |
| **x0**        | zero     | Zero constant             | -                       |
| **x1**        | ra       | Return address            | No, caller-saved        |
| **x2**        | sp       | Stack pointer             | Yes                     |
| **x3**        | gp       | Global pointer            | Fixed / unallocatable   |
| **x4**        | tp       | Thread pointer            | Fixed / unallocatable   |
| **x5 - x7**   | t0 - t2  | Temporaries               | No, caller-saved        |
| **x8**        | s0 / fp  | Saved register / frame pointer | Yes, callee-saved  |
| **x9**        | s1       | Saved register            | Yes, callee-saved       |
| **x10 - x11** | a0 - a1  | Function arguments / return values | No, caller-saved |
| **x12 - x17** | a2 - a7  | Function arguments        | No, caller-saved        |
| **x18 - x27** | s2 - s11 | Saved registers           | Yes, callee-saved       |
| **x28 - x31** | t3 - t6  | Temporaries               | No, caller-saved        |

---

### R-type: register-register instructions

- **Format**: `INSTR rd, rs1, rs2`
- `rd` is the destination register.
- `rs1` and `rs2` are source registers.
- Integer arithmetic wraps modulo `2^32`; arithmetic overflow does not trap in RV32I.
- For register shift instructions, only `rs2[4:0]` is used as the shift amount.

| Bit Range          | 31 - 25    | 24 - 20 | 19 - 15 | 14 - 12    | 11 - 7 | 6 - 0      |
| ------------------ | ---------- | ------- | ------- | ---------- | ------ | ---------- |
| **Name**           | **funct7** | **rs2** | **rs1** | **funct3** | **rd** | **opcode** |
| **Number of bits** | 7          | 5       | 5       | 3          | 5      | 7          |

| Instruction | Name                            | FMT | Opcode   | funct3 | funct7   | Description                |
| ----------- | ------------------------------- | --- | -------- | ------ | -------- | -------------------------- |
| **add**     | ADD                             | R   | 011_0011 | 000    | 000_0000 | `rd = rs1 + rs2`           |
| **sub**     | SUB                             | R   | 011_0011 | 000    | 010_0000 | `rd = rs1 - rs2`           |
| **xor**     | XOR                             | R   | 011_0011 | 100    | 000_0000 | `rd = rs1 ^ rs2`           |
| **or**      | OR                              | R   | 011_0011 | 110    | 000_0000 | `rd = rs1 \| rs2`          |
| **and**     | AND                             | R   | 011_0011 | 111    | 000_0000 | `rd = rs1 & rs2`           |
| **sll**     | Shift Left Logical              | R   | 011_0011 | 001    | 000_0000 | `rd = rs1 << rs2[4:0]`     |
| **srl**     | Shift Right Logical             | R   | 011_0011 | 101    | 000_0000 | `rd = rs1 >>u rs2[4:0]`    |
| **sra**     | Shift Right Arithmetic          | R   | 011_0011 | 101    | 010_0000 | `rd = rs1 >>s rs2[4:0]`    |
| **slt**     | Set Less Than, signed           | R   | 011_0011 | 010    | 000_0000 | `rd = (rs1 s< rs2) ? 1 : 0` |
| **sltu**    | Set Less Than, unsigned         | R   | 011_0011 | 011    | 000_0000 | `rd = (rs1 u< rs2) ? 1 : 0` |

---

### I-type: register-immediate instructions

- **Format**: `INSTR rd, rs1, imm`
- For non-shift immediate instructions:
  - `IMMI = SXT(imm[11:0])`
  - `SXT` means sign extension from 12 bits to 32 bits.
- Signed comparisons treat register values as two's-complement signed integers.
- Unsigned comparisons treat register values as unsigned 32-bit integers.
- For `sltiu`, the immediate is still sign-extended, then treated as an unsigned 32-bit value for comparison.

| Bit Range          | 31 - 20       | 19 - 15 | 14 - 12    | 11 - 7 | 6 - 0      |
| ------------------ | ------------- | ------- | ---------- | ------ | ---------- |
| **Name**           | **imm[11:0]** | **rs1** | **funct3** | **rd** | **opcode** |
| **Number of bits** | 12            | 5       | 3          | 5      | 7          |

| Instruction | Name                             | FMT | Opcode   | funct3 | Description                  |
| ----------- | -------------------------------- | --- | -------- | ------ | ---------------------------- |
| **addi**    | ADD Immediate                    | I   | 001_0011 | 000    | `rd = rs1 + IMMI`            |
| **xori**    | XOR Immediate                    | I   | 001_0011 | 100    | `rd = rs1 ^ IMMI`            |
| **ori**     | OR Immediate                     | I   | 001_0011 | 110    | `rd = rs1 \| IMMI`           |
| **andi**    | AND Immediate                    | I   | 001_0011 | 111    | `rd = rs1 & IMMI`            |
| **slti**    | Set Less Than Immediate, signed  | I   | 001_0011 | 010    | `rd = (rs1 s< IMMI) ? 1 : 0` |
| **sltiu**   | Set Less Than Immediate, unsigned | I  | 001_0011 | 011    | `rd = (rs1 u< IMMI) ? 1 : 0` |

#### I-type shift-immediate instructions

- Shift-immediate instructions use a 5-bit shift amount: `shamt = imm[4:0]`.
- `imm[11:5]` is not a normal signed immediate here; it helps distinguish `slli`, `srli`, and `srai`.

| Bit Range          | 31 - 25       | 24 - 20      | 19 - 15 | 14 - 12    | 11 - 7 | 6 - 0      |
| ------------------ | ------------- | ------------ | ------- | ---------- | ------ | ---------- |
| **Name**           | **imm[11:5]** | **shamt[4:0]** | **rs1** | **funct3** | **rd** | **opcode** |
| **Number of bits** | 7             | 5            | 5       | 3          | 5      | 7          |

| Instruction | Name                             | FMT | Opcode   | funct3 | imm[11:5] | Description            |
| ----------- | -------------------------------- | --- | -------- | ------ | --------- | ---------------------- |
| **slli**    | Shift Left Logical Immediate     | I   | 001_0011 | 001    | 000_0000  | `rd = rs1 << shamt`    |
| **srli**    | Shift Right Logical Immediate    | I   | 001_0011 | 101    | 000_0000  | `rd = rs1 >>u shamt`   |
| **srai**    | Shift Right Arithmetic Immediate | I   | 001_0011 | 101    | 010_0000  | `rd = rs1 >>s shamt`   |

---

### I-type / S-type: load/store instructions

- Load format: `lw rd, offset(rs1)`
- Store format: `sw rs2, offset(rs1)`
- `IMMI = SXT(imm[11:0])`
- `Address = rs1 + IMMI`
- Multi-byte loads/stores use the system's endianness. If assuming little-endian, the least-significant byte is at the lowest address.

#### Load encoding: I-type

| Bit Range          | 31 - 20       | 19 - 15 | 14 - 12    | 11 - 7 | 6 - 0      |
| ------------------ | ------------- | ------- | ---------- | ------ | ---------- |
| **Name**           | **imm[11:0]** | **rs1** | **funct3** | **rd** | **opcode** |
| **Number of bits** | 12            | 5       | 3          | 5      | 7          |
| **Meaning**        | offset        | base    | width      | dest   | LOAD       |

#### Store encoding: S-type

| Bit Range          | 31 - 25       | 24 - 20 | 19 - 15 | 14 - 12    | 11 - 7      | 6 - 0      |
| ------------------ | ------------- | ------- | ------- | ---------- | ----------- | ---------- |
| **Name**           | **imm[11:5]** | **rs2** | **rs1** | **funct3** | **imm[4:0]** | **opcode** |
| **Number of bits** | 7             | 5       | 5       | 3          | 5           | 7          |
| **Meaning**        | offset[11:5]  | src     | base    | width      | offset[4:0] | STORE      |

| Instruction | Name                 | FMT | Opcode   | funct3 | Description                                  |
| ----------- | -------------------- | --- | -------- | ------ | -------------------------------------------- |
| **lb**      | Load Byte            | I   | 000_0011 | 000    | `rd = SXT(M8[Address])`                      |
| **lh**      | Load Halfword        | I   | 000_0011 | 001    | `rd = SXT(M16[Address])`                     |
| **lw**      | Load Word            | I   | 000_0011 | 010    | `rd = M32[Address]`                          |
| **lbu**     | Load Byte Unsigned   | I   | 000_0011 | 100    | `rd = ZXT(M8[Address])`                      |
| **lhu**     | Load Halfword Unsigned | I | 000_0011 | 101    | `rd = ZXT(M16[Address])`                     |
| **sb**      | Store Byte           | S   | 010_0011 | 000    | `M8[Address] = rs2[7:0]`                     |
| **sh**      | Store Halfword       | S   | 010_0011 | 001    | `M16[Address] = rs2[15:0]`                   |
| **sw**      | Store Word           | S   | 010_0011 | 010    | `M32[Address] = rs2[31:0]`                   |

---

### B-type: branch instructions

- **Format**: `INSTR rs1, rs2, label`
- Branches are PC-relative.
- The branch immediate is encoded in multiples of 2 bytes.
- `IMMB = SXT({imm[12], imm[10:5], imm[4:1], 1'b0})`
- If the branch condition is true: `PC = PC + IMMB`
- If the branch condition is false: `PC = PC + 4`
- In RV32I without compressed instructions, target instruction addresses are normally 4-byte aligned, but the branch encoding still has bit 0 fixed to zero.

| Bit Range          | 31          | 30 - 25       | 24 - 20 | 19 - 15 | 14 - 12    | 11 - 8       | 7           | 6 - 0      |
| ------------------ | ----------- | ------------- | ------- | ------- | ---------- | ------------- | ----------- | ---------- |
| **Name**           | **imm[12]** | **imm[10:5]** | **rs2** | **rs1** | **funct3** | **imm[4:1]** | **imm[11]** | **opcode** |
| **Number of bits** | 1           | 6             | 5       | 5       | 3          | 4             | 1           | 7          |

| Instruction | Name                         | FMT | Opcode   | funct3 | Description                         |
| ----------- | ---------------------------- | --- | -------- | ------ | ----------------------------------- |
| **beq**     | Branch if Equal              | B   | 110_0011 | 000    | `if (rs1 == rs2) PC += IMMB`        |
| **bne**     | Branch if Not Equal          | B   | 110_0011 | 001    | `if (rs1 != rs2) PC += IMMB`        |
| **blt**     | Branch if Less Than, signed  | B   | 110_0011 | 100    | `if (rs1 s< rs2) PC += IMMB`        |
| **bge**     | Branch if Greater/Equal, signed | B | 110_0011 | 101    | `if (rs1 s>= rs2) PC += IMMB`       |
| **bltu**    | Branch if Less Than, unsigned | B  | 110_0011 | 110    | `if (rs1 u< rs2) PC += IMMB`        |
| **bgeu**    | Branch if Greater/Equal, unsigned | B | 110_0011 | 111 | `if (rs1 u>= rs2) PC += IMMB`       |

---

### J-type / I-type: jump-and-link instructions

#### `jal`

- **Format**: `jal rd, label`
- JAL is PC-relative.
- `rd = PC + 4`
- `PC = PC + IMMJ`
- `IMMJ = SXT({imm[20], imm[10:1], imm[11], imm[19:12], 1'b0})`
- JAL has an approximate range of **±1 MiB** from the current PC.
- `jal x0, label` can be used as an unconditional jump without saving a return address.

| Bit Range          | 31          | 30 - 21       | 20          | 19 - 12        | 11 - 7 | 6 - 0      |
| ------------------ | ----------- | ------------- | ----------- | -------------- | ------ | ---------- |
| **Name**           | **imm[20]** | **imm[10:1]** | **imm[11]** | **imm[19:12]** | **rd** | **opcode** |
| **Number of bits** | 1           | 10            | 1           | 8              | 5      | 7          |
| **Meaning**        | offset      | offset        | offset      | offset         | dest   | JAL        |

| Instruction | Name          | FMT | Opcode   | Description                  |
| ----------- | ------------- | --- | -------- | ---------------------------- |
| **jal**     | Jump and Link | J   | 110_1111 | `rd = PC + 4; PC += IMMJ`    |

#### `jalr`

- **Format**: `jalr rd, imm(rs1)`
- JALR is an indirect jump.
- `IMMI = SXT(imm[11:0])`
- `rd = PC + 4`
- `PC = (rs1 + IMMI) & ~1`
- The low bit of the target address is cleared; this is **not** the same as shifting left by 1.
- JALR itself has only a signed 12-bit immediate. Longer jumps are built by first putting a larger address or PC-relative base into `rs1`, often using `lui` or `auipc`.
- `jalr x0, 0(ra)` is commonly used to return from a function; the pseudoinstruction is `ret`.

| Bit Range          | 31 - 20       | 19 - 15 | 14 - 12    | 11 - 7 | 6 - 0      |
| ------------------ | ------------- | ------- | ---------- | ------ | ---------- |
| **Name**           | **imm[11:0]** | **rs1** | **funct3** | **rd** | **opcode** |
| **Number of bits** | 12            | 5       | 3          | 5      | 7          |
| **Meaning**        | offset        | base    | 000        | dest   | JALR       |

| Instruction | Name                   | FMT | Opcode   | funct3 | Description                            |
| ----------- | ---------------------- | --- | -------- | ------ | -------------------------------------- |
| **jalr**    | Jump and Link Register | I   | 110_0111 | 000    | `rd = PC + 4; PC = (rs1 + IMMI) & ~1`  |

---

### U-type: upper immediate instructions

- **Format**: `INSTR rd, imm`
- `IMMU = {imm[31:12], 12'b0}`
- Equivalently: `IMMU = imm[31:12] << 12`
- `lui` loads a 20-bit immediate into the upper 20 bits of a register and clears the lower 12 bits.
- `auipc` adds the upper immediate to the current PC.
- `lui`/`addi` or `auipc`/`jalr` are often used together to build larger constants or addresses.

| Bit Range          | 31 - 12        | 11 - 7 | 6 - 0      |
| ------------------ | -------------- | ------ | ---------- |
| **Name**           | **imm[31:12]** | **rd** | **opcode** |
| **Number of bits** | 20             | 5      | 7          |

| Instruction | Name                         | FMT | Opcode   | Description        |
| ----------- | ---------------------------- | --- | -------- | ------------------ |
| **lui**     | Load Upper Immediate         | U   | 011_0111 | `rd = IMMU`        |
| **auipc**   | Add Upper Immediate to PC    | U   | 001_0111 | `rd = PC + IMMU`   |

---

### System instructions commonly ignored in a toy RV32I CPU

These are part of the base ISA encoding space, but a simple educational CPU may choose not to implement useful OS/debugger behavior for them.

| Instruction | Name                       | FMT | Opcode   | funct3 | imm[11:0]     | Description                       |
| ----------- | -------------------------- | --- | -------- | ------ | ------------- | --------------------------------- |
| **ecall**   | Environment Call           | I   | 111_0011 | 000    | 0000_0000_0000 | Transfer control to environment   |
| **ebreak**  | Environment Breakpoint     | I   | 111_0011 | 000    | 0000_0000_0001 | Transfer control to debugger      |
