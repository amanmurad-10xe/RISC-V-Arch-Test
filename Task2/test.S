/* -----------------------------------------------------------------------------
 * Author:     Aman Murad
 * Date:       2026-02-09
 * Module:     RISC-V Arch Test
 * Task 2:     Physical Memory Protection
 *
 * Description:
 * Configure 2 PMP regions (4KB TOR execute-only, 4KB NAPOT read-only)
 * Test R/W/X in S-mode
 * Lock PMP entries
 * Test again in M-mode
 * Handle instruction/load/store access faults
 *
 * --------------------------------------------------------------------------- */

#define RVTEST_DATA_BEGIN                                           \
    .pushsection .tohost,"aw",@progbits;                            \
    .align 6; .global tohost; tohost: .dword 0;                     \
    .align 6; .global fromhost; fromhost: .dword 0;                 \
    .popsection                                                     \
    .align 4; .global begin_signature; begin_signature:

#define RVTEST_CODE_BEGIN                                           \
    .section .text.init;                                            \
    .align  6;                                                      \
    .global _start;                                                 \
_start:
    j main

/*
 * Machine-mode Trap Vector
 * Handles access faults from S Mode (M Mode with MPRV set and locked PMP)
 *
 */
trap_vector:
    csrr t6, mcause                      /* Read trap cause into t6 (was t0) */
    csrr t5, mepc                        /* Read exception PC into t5 (was t1) */

    /* ECALL from S mode to switch back to M-mode */
    li t4, 9                             /* Use t4 for comparison (was t2) */
    beq t6, t4, handle_ecall

    /* Instruction access fault (mcause = 1) */
    li t4, 1
    beq t6, t4, handle_instr_fault

    /* Load access fault (mcause = 5) */
    li t4, 5
    beq t6, t4, handle_data_fault

    /* Store access fault (mcause = 7) */
    li t4, 7
    beq t6, t4, handle_data_fault

    /* Unexpected trap failure */
    j test_fail

/*
 * Instruction Fault handler
 * Skip the faulting instruction
 */
handle_instr_fault:
    csrw mepc, ra
    mret

/*
 * Data Fault handler
 * Skip the faulting instruction
 */
handle_data_fault:
    addi t5, t5, 4       /* Increment PC (held in t5) */
    csrw mepc, t5
    mret

handle_ecall:
    /* Set next PC to machine_tests */
    la t4, machine_tests
    csrw mepc, t4
    
    /* Force MPP back to Machine Mode (11) in mstatus */
    csrr t4, mstatus
    li t5, ~(3 << 11)    /* Clear MPP bits */
    and t4, t4, t5
    li t5, (3 << 11)     /* Set MPP = Machine (11) */
    or t4, t4, t5
    csrw mstatus, t4
    
    mret

RVTEST_CODE_BEGIN
main:

    /* Trap Handler */
    la   t0, trap_vector
    csrw mtvec, t0

    /* entry0 for lower bound */
    li t0, 0x80000000
    srli t0, t0, 2
    csrw pmpaddr0, t0

    li t0, 0x08
    csrw pmpcfg0, t0

    /* Protect for entry1 region start */
    li t0, 0x80002000
    srli t0, t0, 2
    csrw pmpaddr1, t0

    li t0, (0x0F << 8)
    csrr t1, pmpcfg0
    or t1, t1, t0
    csrw pmpcfg0, t1

    /*  TOR REGION */
    /* 4KB at execute only */
    li t0, 0x80003000
    srli t0, t0, 2
    csrw pmpaddr2, t0

    /* entry1 = TOR + X (0x0C) */
    li t0, (0x0C << 16)
    csrr t1, pmpcfg0
    or t1, t1, t0
    csrw pmpcfg0, t1
    
    /* NAPOT REGION */
    /* 4KB at 0x80003000 read only */
    li t0, 0x80003000
    srli t0, t0, 2
    li t1, 0x1FF                         /* NAPOT encoding for 4KB region */
    or t0, t0, t1
    csrw pmpaddr3, t0

    /* entry2 = NAPOT + R (0x19) */
    li t0, (0x19 << 24)
    csrr t1, pmpcfg0
    or t1, t1, t0
    csrw pmpcfg0, t1

    /* Switch to S-mode */
    csrr t0, mstatus
    li   t1, ~(3 << 11)
    and  t0, t0, t1                      /* Clear MPP */ 
    li   t1, (1 << 11)                   /* MPP = Supervisor */
    or   t0, t0, t1
    csrw mstatus, t0

    la   t0, supervisor_tests
    csrw mepc, t0
    mret

supervisor_tests:

    /* execute TOR (allowed) */
    la t0, tor_execution
    jalr t0
 
    /* Read NAPOT (allowed) */
    li t0, 0x80003000
    lw t1, 0(t0)

    /* Write NAPOT (Store access fault) */
    sw t1, 0(t0)

    /* Execute NAPOT (Instruction access fault) */
    la t0, napot_execution
    jalr t0

    /* Read TOR (Load access fault) */
    li t0, 0x80002000
    lw t1, 0(t0)

    /* Write TOR (Store access fault) */
    sw t1, 0(t0)
    
    /* Switch to M-mode using handler */
    ecall
    
machine_tests:

    /* Lock PMP entries
     * entry0 for TOR RX + L 
     * entry1 for TOR X + L
     * entry2 for NAPOT R + L
     */
    li t0, 0x88
    li t1, (0x8F << 8)
    li t2, (0x8C << 16)
    li t3, (0x99 << 24)
    or t0, t0, t1
    or t0, t0, t2
    or t0, t0, t3
    csrw pmpcfg0, t0

    /* Enable MPRV to test S-mode permissions from M-mode */
    csrr t0, mstatus
    li   t1, (1 << 17)        /* MPRV */
    or   t0, t0, t1
    csrw mstatus, t0

    /* Execute TOR (allowed) */
    la t0, tor_execution
    jalr t0

    /* Read NAPOT (allowed) */
    li t0, 0x80003000
    lw t1, 0(t0)

    /* Write NAPOT (Store access fault) */
    sw t1, 0(t0)

    /* Execute NAPOT (Instruction access fault) */
    la t0, napot_execution
    jalr t0

    /* Read TOR (Load access fault) */
    li t0, 0x80002000
    lw t1, 0(t0)

    /* Write TOR (Store access fault) */
    sw t1, 0(t0)

    /* All tests passed */
    j test_pass

/* Test functions */
.section .tor_region, "ax" 
.align 2
tor_execution:
    ret

.section .napot_region, "ax"
.align 2
napot_execution:
    ret
 
.section .text
/*
 *
 * Test Pass/Fail Handlers
 *
 */
test_pass:
    li gp, 0x55555555                    /* signature for test pass */
    sw gp, tohost, t0
    j write_tohost

test_fail:
    li gp, 0xdeadbeef                    /* signature for test fail */
    sw gp, tohost, t0
    j write_tohost

.align 2
write_tohost:
    li gp, 1
    sw gp, tohost, t0
    j write_tohost

RVTEST_DATA_BEGIN
