.section .init
.globl _start

_start:
    # Initialize Stack Pointer to the absolute top of 8KB DMEM (0x2000)
    li sp, 0x2000
    
    # Jump to C main function
    jal ra, main

halt:
    j halt
