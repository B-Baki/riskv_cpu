.section .text
.global _start

_start:
    addi x1, x0, 5
    addi x2, x0, 7
    add  x3, x1, x2

    sw   x3, 0(x0)
    lw   x4, 0(x0)

    beq  x4, x3, branch_taken
    addi x5, x0, 111

branch_taken:
    addi x5, x0, 222

    jal  x6, jump_target
    addi x7, x0, 123

jump_target:
    addi x8, x0, -1

    ebreak