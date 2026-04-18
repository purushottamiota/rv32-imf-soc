.section .init
.globl _start

_start:
    # 1. Initialize Stack Pointer to the top of 8KB DMEM (0x2000)
    li sp, 0x2000
    
    # 2. Initialize Trap Vector
    la t0, _trap_handler
    csrw mtvec, t0
    
    # 3. Jump straight to C main function! (SKIPPING FPU TEST)
    jal ra, main

halt:
    j halt

_trap_handler:
    jal ra, c_trap_handler
    mret