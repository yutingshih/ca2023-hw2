# This program implements 32-bit unsigned integer multiplication.
#
# The average runtime of `mul_shift_u32` is O(n lg n).
#
# For including as a library, include only codes in
# the "Library" section.
#
# Library dependency graph:
#   **mul_shift_u32** -> mul_bf16
#
# Version: 0.0.0
# Tested: 2023-10-03T10:31:00+08:00

.data
arg1: .word   1000
arg2: .word   1000

.text
.globl main
main:
    # multiply two numbers
    lw   a0, arg1
    lw   a1, arg2
    jal  ra, mul_shift_u32

    # print result
    li   a7, 1 # to print integer
    ecall      # a0 = result of mul_shift_u32

    # exit program
    li   a7, 10
    ecall


# ┌-------------------------------------------------------┐
# |                        Library                        |
# └-------------------------------------------------------┘

# --- mul_shift_u32 ---
    # binary multiplication of two u32 numbers
    # input:
    #   a0: a (u32): multiplier
    #   a1: b (u32): multiplicand
    # output:
    #   a0: r (u32): product of a and b (a * b)
mul_shift_u32:
    mhu_prologue:
        addi sp, sp, -4
        sw   ra, 0(sp)
        bge  a0, a1, mhu_no_swap
        # make a1 <= a0
        addi t0, a1, 0
        mv   a1, a0
        mv   a0, t0
    mhu_no_swap:
        # binary multiplication of t0 = a0 * a1
        addi t0, zero, 0 # t0 = result
    mhu_loop:
        beq  a1, zero, mhu_epilogue
        andi t2, a1, 1 # the least significant bit of a1
        beq  t2, zero, mhu_next
        add  t0, t0, a0
    mhu_next:
        slli a0, a0, 1
        srli a1, a1, 1
        j mhu_loop
    mhu_epilogue:
        mv   a0, t0
        lw   ra, 0(sp)
        addi sp, sp, 4
        ret
