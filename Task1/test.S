/* --------------------------------------------------------------------------------------------
 * Author:     Aman Murad
 * Date:       2026-02-02
 * Module:     RISC-V Arch Test
 * Task 1:     Privilege Mode Switching and Trap Handling
 *
 * Description:
 * This program demonstrates controlled switching between Machine (M),
 * Supervisor (S), and User (U) modes using RISC-V CSRs.
 *
 * - A function switch_mode() switches from M-mode to S or U.
 * - A machine-mode trap handler handles ECALLs from U and S modes.
 * - ECALL from U returns execution in S-mode.
 * - ECALL from S returns execution in M-mode.
 *
 * The test always exits in Machine mode.
 * -------------------------------------------------------------------------------------------- */

#define RVTEST_DATA_BEGIN                                           \
    .pushsection .tohost,"aw",@progbits;                            \
    .align 6; .global tohost; tohost: .dword 0;                     \
    .align 6; .global fromhost; fromhost: .dword 0;                 \
    .popsection;                                                    \
    .align 4; .global begin_signature; begin_signature:

#define RVTEST_CODE_BEGIN                                           \
    .section .text.init;                                            \
    .align  6;                                                      \
    .global _start;                                                 \
_start:                                                             \
    j main;                             
 
/*
 * 
 * Machine-mode Trap Vector
 * Handles ECALLs from Supervisor and User modes
 *
 */
trap_vector:

    csrr t0, mcause                      /* Read trap cause */
    csrr t1, mepc                        /* Read exception PC */

    /* Check USER ECALL (mcause = 8) */
    li t2, 8
    beq t0, t2, handle_user_ecall

    /* Check for SUPERVISOR ECALL (mcause = 9) */
    li t2, 9
    beq t0, t2, handle_supervisor_ecall

    /* Unexpected trap failure */
    j test_fail

/*
 * ECALL from User Mode
 * Return execution in Supervisor Mode
 *
 */
handle_user_ecall:
    /* Return to Supervisor Mode */
    csrr t3, mstatus
    li   t4, ~(3 << 11)
    and  t3, t3,  t4                      /* Clear MPP */
    li   t4, (1 << 11)                   /* MPP = S(01) */
    or   t3, t3, t4
    csrw mstatus, t3

    addi t1, t1, 4                       /* Skip ecall */
    csrw mepc, t1
    mret

/* 
 *
 * ECALL from Supervisor Mode
 * Return execution in Machine Mode
 *
 */
handle_supervisor_ecall:
    /* Return to Machine mode */
    csrr t3, mstatus
    li   t4, ~(3 << 11)
    and  t3, t3, t4                  /* Clear MPP */
    li   t4, (3 << 11)               /* MPP = M(11) */
    or   t3, t3, t4
    csrw mstatus, t3

    addi t1, t1, 4
    csrw mepc, t1
    mret

RVTEST_CODE_BEGIN
main:
    /* Trap Handler */
    la   t0, trap_vector
    csrw mtvec, t0

    /* Switch from M to S (a0 = 0) */
    li   a0, 0
    jal  switch_mode

supervisor_entry:
    /* Switch from S to U */
    jal  switch_to_user

user_entry:
    /* ECALL from U should return to S */
    ecall

s_after_user:
    /* ECALL from S should return to M */
    ecall

    j test_pass

/* 
 *
 * switch_mode
 * a0 = 0 - switch to Supervisor mode
 * a0 = 1 - switch to User mode
 * Must be called only from Machine Mode
 * 
 */
switch_mode:
    csrr t0, mstatus
    li   t1, ~(3 << 11)
    and  t0, t0, t1                      /* Clear MPP */

    beqz a0, set_supervisor

set_user:
    li   t1, (0 << 11)                   /* MPP = User (00) */
    or   t0, t0, t1
    csrw mstatus, t0
    la   t2, user_entry
    csrw mepc, t2
    mret

set_supervisor:
    li   t1, (1 << 11)                   /* MPP = Supervisor (01) */
    or   t0, t0, t1
    csrw mstatus, t0
    la   t2, supervisor_entry
    csrw mepc, t2
    mret

switch_to_user:
    csrr t0, sstatus
    li   t1, ~(1 << 8)
    and  t0, t0, t1                      /* Clear SPP */
    csrw sstatus, t0

    la   t2, user_entry
    csrw sepc, t2

    sret                                 /* Return to User Mode */

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

.data 
base:
    .word 0xcafebeef

RVTEST_DATA_BEGIN