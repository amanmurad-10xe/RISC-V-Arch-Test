# RISC-V Privilege Mode Switching and Trap Handling Test

## Author
**Aman Murad**

## Module
RISC-V Architecture Test

---

## Overview

This test verifies **correct privilege mode switching and trap handling** in a RISC-V system using **Machine (M), Supervisor (S), and User (U)** modes.

The program starts execution in **Machine mode**, installs a **machine-mode trap handler**, and demonstrates controlled transitions between privilege modes using **standard RISC-V mechanisms**.  
Correct behavior is verified using **ECALLs** and **mcause-based trap handling**.  
The test **always exits in Machine mode**, as required by RISC-V compliance-style tests.

---

## Objectives

- Start execution in **Machine mode**
- Implement a **privilege switching function** callable from Machine mode
- Implement a **Machine-mode trap handler** for ECALLs
- Switch execution:
  - Machine → Supervisor
  - Supervisor → User (standard method)
  - User → Supervisor (via trap)
  - Supervisor → Machine (via trap)
- Exit the test in **Machine mode** with a PASS signature

---

## Privilege Switching Mechanisms Used

The test uses the following **RISC-V CSRs and instructions**:

- `mstatus.MPP` — selects next privilege mode after `mret`
- `mepc` — return address for `mret`
- `sstatus.SPP` — selects next privilege mode after `sret`
- `sepc` — return address for `sret`
- `mtvec` — machine trap vector
- `mcause` — identifies trap reason
- `ecall` — generates environment call exception
- `mret` / `sret` — return from trap or privilege switch

---

## Implemented Components

### 1. `switch_mode(a0)` — Machine-mode privilege switch function

- **Callable only from Machine mode**
- Uses `mstatus.MPP`, `mepc`, and `mret`

| Argument (`a0`) | Effect |
|---------------|-------|
| `0` | Switch Machine → Supervisor |
| `1` | Switch Machine → User |

---

### 2. Machine-mode Trap Handler (`trap_vector`)

The trap handler executes in **Machine mode** and handles ECALLs originating from lower privilege levels.

| ECALL Source | `mcause` | Return Mode |
|-------------|----------|-------------|
| User mode | `8` | Supervisor |
| Supervisor mode | `9` | Machine |

The handler:
- Reads `mcause` and `mepc`
- Programs `mstatus.MPP`
- Advances `mepc` to skip the ECALL
- Executes `mret` to return to the correct mode

---

### 3. Supervisor → User Mode Switch (Standard Method)

While in **Supervisor mode**, switching to User mode is performed using:

- `sstatus.SPP` (cleared to 0)
- `sepc` (set to user entry)
- `sret`

This follows the **standard RISC-V privilege return mechanism**.

---

## Program Execution Flow

1. Program starts in **Machine mode** at `_start`
2. Control jumps to `main`
3. Machine trap handler address is written to `mtvec`
4. `switch_mode(0)` switches **Machine → Supervisor**
5. From Supervisor mode:
   - `switch_to_user` switches **Supervisor → User** using `sret`
6. In User mode:
   - `ecall` triggers a trap to Machine mode
   - Trap handler returns execution to **Supervisor mode**
7. In Supervisor mode:
   - `ecall` triggers another trap
   - Trap handler returns execution to **Machine mode**
8. Test exits in Machine mode by writing **PASS signature** to `tohost`

---

## Test Completion Signaling

The test communicates its result using a **memory-mapped `tohost` register**, which is monitored by the simulator.

### PASS
```asm
li gp, 0x55555555
sw gp, tohost, t0
```

### FAIL
```asm
li gp, 0xdeadbeef
sw gp, tohost, t0
```

---

## File Structure
```
project/
│
├─ test.S      # RISC-V bare-metal test program (entry + logic)
├─ link.ld     # Linker script (memory layout, sections, symbols)
├─ Makefile    # Build, disassembly, and Spike run automation
└─ README.md   # Project documentation
```

---

### Build the program
```bash
make
```
- Assembles and links `test.S` using the RISC-V GCC toolchain
- Produces the ELF binary `test.elf`
- Generates disassembly `test.dis`
      
### Generate Disassembly only
```bash
make disasm
```
- Uses riscv64-unknown-elf-objdump
- Outputs full instruction-level disassembly to `test.dis`

### Run on spike (bare-metal)
```bash
make run
```
- Runs `test.elf` on Spike
- Enables: instruction logging and commit logging
- Output files:
    1. spike.out → program output
    2. spike.log → execution trace
- Searches for test status markers:
    1. 0x55555555 → test pass
    2. 0xdeadbeef → test fail

### Clean build artifacts
```bash
make clean
```
- Removes all compiled, output and disassembly files

### Help
```bash
make help
```
- Displays the target menu and usage instructions

---
