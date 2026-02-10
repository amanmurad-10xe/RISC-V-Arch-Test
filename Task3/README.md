# RISC-V S-Mode Illegal Instruction Exception Handling Test

## Author
**Aman Murad**

## Module
RISC-V Architecture Test

---

## Overview

This test verifies **Supervisor-mode (S-mode) exception handling** in a RISC-V system.

The program starts execution in **Machine mode (M-mode)**, configures **exception delegation**, installs a **Supervisor-mode trap handler**, and then transitions execution to **User mode (U-mode)**.

An **illegal instruction** is intentionally executed in User mode.  
The test confirms that:
- The exception is **delegated from M-mode to S-mode**
- The **S-mode trap handler** correctly detects and handles the exception
- Execution safely returns back to **User mode**
- The test reports **PASS** using the `tohost` mechanism

---

## Objectives

- Start execution in **Machine mode**
- Delegate **illegal instruction exceptions** to Supervisor mode
- Install a **Supervisor-mode trap handler**
- Switch execution:
  - Machine → Supervisor
  - Supervisor → User
- Generate an **illegal instruction exception** in User mode
- Handle the exception **entirely in Supervisor mode**
- Resume execution in User mode after exception handling
- Signal **PASS / FAIL** using `tohost`

---

## Exception Handling Mechanism Used

The test relies on the following **RISC-V CSRs and instructions**:

- `medeleg` — delegates exceptions from M-mode to S-mode
- `stvec` — Supervisor-mode trap vector
- `scause` — identifies exception cause
- `sepc` — stores faulting instruction address
- `mstatus.MPP` — controls privilege level after `mret`
- `sstatus.SPP` — controls privilege level after `sret`
- `mret` / `sret` — return from privilege mode
- `csrr` — used to intentionally trigger illegal instruction in U-mode

---

## File Structure
```
project/
│
├─ test.S      # RISC-V bare-metal test program
├─ link.ld     # Linker script
├─ Makefile    # Build and simulation automation
└─ README.md   # Project documentation
```

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
