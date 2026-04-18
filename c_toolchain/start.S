.section .init
.globl _start

_start:
    # 1. Initialize Stack Pointer to the top of 8KB DMEM (0x2000)
    li sp, 0x2000
    
    # 2. Initialize Trap Vector (Exceptions jump to _trap_handler)
    la t0, _trap_handler
    csrw mtvec, t0
    
    # 3. Jump straight to C main function!
    jal ra, main

halt:
    j halt

_trap_handler:
    # Read the exact exception cause from the CSR into a0 
    # (a0 is automatically passed as Argument 1 to the C function)
    csrr a0, mcause
    
    # Call the C trap handler
    jal ra, c_trap_handler
    
    # CRITICAL FIX: Advance MEPC by 4 bytes to skip the faulting instruction!
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0
    
    # Return to the NEXT instruction in the pipeline
    mret