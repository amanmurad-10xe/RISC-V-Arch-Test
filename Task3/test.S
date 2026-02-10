/* --------------------------------------------------------------------------------------------
 * Author:     Aman Murad
 * Date:       2026-02-05
 * Module:     RISC-V Arch Test
 * Task 3:     S-Mode Exception Handling
 *
 * Description:
 * This test verifies that an illegal instruction exception generated in
 * User mode is correctly handled in Supervisor mode.
 *
 * -------------------------------------------------------------------------------------------- */
 
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
 * 
 * Supervisor-mode Trap Vector
 * Handles exception from User mode
 *
 */
s_trap_vector:

    csrr t0, scause                      /* Read Trap cause */
    csrr t1, sepc                        /* Read Exception PC */

    /* Illegal instruction (scause = 2) */
    li   t2, 2
    beq  t0, t2, handle_illegal

    /* Unexpected exception failure */
    j test_fail

/*
 * Illegal Instruction Exception from User Mode
 * Return execution in User Mode
 */
handle_illegal:
    /* Skip the illegal instruction */
    addi t1, t1, 4
    csrw sepc, t1

    /* Return back to U-mode */
    sret

RVTEST_CODE_BEGIN
main:

    li   t0, (1 << 2)                    /* bit 2 = illegal instruction */
    csrw medeleg, t0

    /* S-mode trap handler */
    la   t0, s_trap_vector
    csrw stvec, t0

    /* Switch from M-mode to S-mode */
    jal  switch_to_supervisor

s_entry:
    /* Switch from S-mode to U-mode */
    jal  switch_to_user

u_entry:
    /* Generate illegal instruction */
    csrr t0, sstatus

    /* Should reach here if S-mode trap works */
    j test_pass

switch_to_supervisor:
    csrr t0, mstatus
    li   t1, ~(3 << 11)
    and  t0, t0, t1                      /* Clear MPP */
    li   t1, (1 << 11)                   /* MPP = Supervisor */
    or   t0, t0, t1
    csrw mstatus, t0

    la   t2, s_entry
    csrw mepc, t2
    mret

switch_to_user:
    csrr t0, sstatus
    li   t1, ~(1 << 8)
    and  t0, t0, t1                      /* Clear SPP */
    csrw sstatus, t0

    la   t2, u_entry
    csrw sepc, t2
    sret

/*
 *
 * Test Pass/Fail Handlers
 *
 */
test_pass:
    li gp, 0x55555555
    sw gp, tohost, t0
    j write_tohost

test_fail:
    li gp, 0xdeadbeef
    sw gp, tohost, t0
    j write_tohost

.align 2
write_tohost:
    li gp, 1
    sw gp, tohost, t0
    j write_tohost

RVTEST_DATA_BEGIN