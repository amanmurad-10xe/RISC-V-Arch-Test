/* --------------------------------------------------------------------------------------------
 * Author:     Aman Murad
 * Date:       2026-02-12
 * Module:     RISC-V Arch Test
 * Task:       SV32 Virtual Memory Test (Spike/Sail)
 *
 * Description:
 *  - Start in M-mode
 *  - Setup SV32 page tables
 *  - Enable translation via satp
 *  - Drop to S-mode using mret
 *  - Test RWX / RW / R permissions
 *  - Verify page faults using mcause
 *  - Report result via tohost
 * -------------------------------------------------------------------------------------------- */

#define RVTEST_DATA_BEGIN                                           \
    .pushsection .tohost,"aw",@progbits;                            \
    .align 6; .global tohost; tohost: .dword 0;                     \
    .align 6; .global fromhost; fromhost: .dword 0;                 \
    .popsection

#define RVTEST_CODE_BEGIN                                           \
    .section .text.init;                                            \
    .align  6;                                                      \
    .global _start;                                                 \

RVTEST_CODE_BEGIN
_start:
    /* 
     * Initialize trap handler for M-mode to handle page faults
     */
    li t0, 0x800
    li t1, 0x1000
    or t0, t0, t1
    csrs mstatus, t0

    la t0, trap_vector

    /* 
     * mtvec MODE=0 (direct) and BASE=trap_vector
     */
    li t1, 0x3
    not t1, t1
    and t0, t0, t1
    csrw mtvec, t0

    j main

.align 2
.type trap_vector, @function
trap_vector:
    csrr t0, mcause

    li t1, 12          # instruction page fault
    beq t0, t1, handle_instruction_fault
    
    li t1, 13          # load page fault
    beq t0, t1, handle_load_fault

    li t1, 15          # store page fault 
    beq t0, t1, handle_store_fault

    /* Unexpected trap cause, report failure */
    j test_fail

handle_instruction_fault:
    csrw mepc, ra      
    mret

handle_load_fault:
    j trap_finish   

handle_store_fault:
    j trap_finish

trap_finish:
    /* Return to the instruction that caused the fault */
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0

    /* Return to S-mode */
    mret

.section .text
.align 2
.global main
.type main, @function
main:

    /* 
     * VA for SMODE test code = 0xBEEF3000
     */

    la a0, 0x2fb
    la a1, l0_pt       # PA of L0 page table
    srli a1, a1, 2
    li a2, 0x0
    li a3, 1
    call set_PTE      
 
    la a0, 0x2f1
    la a1, tohost
    srli a1, a1, 2
    li a2, 0x7        # RWX permissions
    li a3, 0
    call set_PTE

    la a0, 0x2f2
    la a1, set_PTE
    srli a1, a1, 2
    li a2, 0x7        # RWX permissions for main function
    li a3, 0
    call set_PTE

    la a0, 0x2f4
    la a1, l1_pt
    srli a1, a1, 2
    li a2, 0x7        # RWX permissions for page containing L1 page table
    li a3, 0
    call set_PTE

    la a0, 0x2f5
    la a1, l0_pt
    srli a1, a1, 2
    li a2, 0x7        # RWX permissions for page containing L0 page table
    li a3, 0
    call set_PTE

    /* 
     * Supervisor instructions entry point
     */
    la a0, 0x2f3
    la a1, sm_test
    srli a1, a1, 2
    li a2, 0x7        # RWX permissions for supervisor test code
    li a3, 0
    call set_PTE

    /*
     * test_data page entry point, initial permission is RWX, will be changed to RW and R later in the test
     * test_data VA = 0xABCD4000
     * VPN[1] = 0x2af
     * VPN[0] = 0x0d4
     */
    la a0, 0x2af
    la a1, l0_pt
    srli a1, a1, 2
    li a2, 0x0
    li a3, 1
    call set_PTE

    la a0, 0x0d4
    la a1, test_data
    srli a1, a1, 2
    li a2, 0x7        # RWX permissions for test_data page
    li a3, 0
    call set_PTE

    sfence.vma

    /*
     * setting up satp register for virtual memory :
     * satp format for SV32:
     * [31]    MODE (1 for SV32)
     * [30:22] ASID (address space identifier, not used in this test, set to 0)
     * [21:0]  PPN (physical page number of L1 page table, right shifted by 12)
     */
    li t0, (1 << 31)
    la t1, l1_pt
    srli t1, t1, 12
    or t0, t0, t1

    csrw satp, t0
    sfence.vma

    li t0, (3 << 11)          /* clear MPP */
    csrc mstatus, t0

    li t0, (1 << 11)          /* set MPP = S */
    csrs mstatus, t0

    li t0, 0
    lui t0, 0xBEEF3           /* VA of supervisor test code */
    csrw mepc, t0
    mret

.section .test_text, "ax"
.global sm_test
.align 12
.type sm_test, @function
sm_test:
    la s0, 0xABCD4000    # test_data page VA 

/*
 * This function is called from S-mode to test if the page permissions are correctly enforced.
 * It will be mapped to a virtual address with RWX permissions, so all operations should succeed.
 */
sm_xwr_page:

    jalr ra, s0, 16          # Exectute test instruction (should pass)

    li t0, 0xABCDCAFE        # write test (should pass)
    sw t0, 4(s0)

    lw t0, 4(s0)             # read test (should pass)
    li t1, 0xABCDCAFE
    bne t0, t1, test_fail
   
/* 
 * Now we will change the permissions of this page to RW only and test again.
 */
sm_wr_page:

    la a0, 0x0d4
    lui a1, 0x80006   # PA of test_data page
    srli a1, a1, 2
    li a2, 0x3        # RW permissions 
    li a3, 0          # Leaf PTE
    call set_PTE

    sfence.vma

    jalr ra, s0, 16        # Execute test instruction (should trap)

    li t0, 0xABCDCAFE      # write test (should pass)
    sw t0, 8(s0)

    lw t0, 8(s0)           # read test (should pass)
    li t1, 0xABCDCAFE
    bne t0, t1, test_fail

/* 
 * Now we will change the permissions to R only and test again.
 */
sm_r_page:

    la a0, 0x0d4
    lui a1, 0x80006   # PA of test_data page
    srli a1, a1, 2
    li a2, 0x1        # R permissions 
    li a3, 0          # Leaf PTE
    call set_PTE

    sfence.vma

    jalr ra, s0, 16        # Execute test instruction (should trap)

    li t0, 0xABCDCAFE      # write test (should trap)
    sw t0, 12(s0)

    lw t0, 12(s0)          # read test (should pass)
    li t1, 0x87654321
    bne t0, t1, test_fail

    j test_pass

/*
 * Test pass/fail handlers
 */
test_pass:
    li gp, 0x1
    sw gp, tohost, t0
    j write_tohost

test_fail:
    li gp, 0x3
    sw gp, tohost, t0
    j write_tohost

RVTEST_DATA_BEGIN
write_tohost:
    sw gp, tohost, t0
    j write_tohost

/*
 * Helper function to set PTEs in page tables
 * a0 = VPN index
 * a1 = PA of the page or next level page table
 * a2 = permissions (R/W/X)
 * a3 = 1 if this is a leaf PTE, 0 if it's an intermediate PTE
 */
.section .text
.align 2
.global set_PTE
.type set_PTE, @function
set_PTE:

    /* Extraction PFN from PA and aligning it to 4KB */
    mv t0, a1
    li t1, 0xfffffc00
    and t0, t0, t1

    bnez a3, l1_pte

l0_pte:
    ori t0, t0, 0xC1   # dirty and accessed bits + valid bit for leaf PTE
    slli t1, a2, 1     # Shift permissions to align with PTE format 
    or t0, t0, t1
    la t1, l0_pt       # Address of L0 page table
    j save_pte

l1_pte:
    ori t0, t0,0x1     # Valid bit for intermediate PTE
    la t1, l1_pt       # Address of L1 page table

save_pte:
    slli t2, a0, 2
    add t1, t1, t2
    sw t0, 0(t1)
    ret
.size set_PTE, .-set_PTE

/* 
 * Defining Root Page Table (L1) 
 */
.section .page_table
.align 12
.global l1_pt
.type l1_pt, @object
l1_pt:
    .zero 4096
    .size l1_pt, .-l1_pt

/* 
 * Defining L0 Page Table (Leaf)
 */
.section .page_table
.align 12
.global l0_pt
.type l0_pt, @object
l0_pt:
    .zero 4096
    .size l0_pt, .-l0_pt

/*
 * Random Data for testing read and write permissions
 */

.section .test_data
.align 12
.global test_data
.type test_data, @object
test_data:
    # data pattern to verify correct read/write permissions
    .word 0xCAFEBABE, 0xDEADBEEF, 0x12345678, 0x87654321
    # instruction to execute in test modes
    add s0, s0, zero
    nop 
    ret
    .size test_data, .-test_data
