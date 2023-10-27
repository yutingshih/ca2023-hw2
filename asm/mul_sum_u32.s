# This program implements and tests unsigned integer multiplication.
# The average runtime of `mul_sum_u32` is O(n).
#
# Version: 0.0
# Tested: 2023-10-03T10:19:00+08:00

.text
.globl main
main:
        # multiply two numbers
        li  a0, 6
        li  a0, 6
        jal ra, mul_sum_u32

        # print result
        li a7, 1 # to print integer
        ecall    # a0 = result of mul_sum_u32

        # exit program
        li a7, 10
        ecall

# --- mul_sum_u32 ---
# a0 = a0 * a1 with summing a1 times of a0
# both a0 and a1 are unsigned or positive
mul_sum_u32:
        addi sp, sp, -4
        sw   ra, 0(sp)
        bge  a0, a1, muu_no_swap
        # ensure a1 <= a0
        mv   t1, a1
        mv   a1, a0
        mv   a0, t1
muu_no_swap:
        li   t0, 0 # t0 = result
        addi a1, a1, -1
muu_loop:
        add  t0, t0, a0
        addi a1, a1, -1
        bge  a1, zero, muu_loop
muu_exit:
        mv   a0, t0
        lw   ra, 0(sp)
        addi sp, sp, 4
        ret
