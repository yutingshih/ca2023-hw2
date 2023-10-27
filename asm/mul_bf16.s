# This program implements and tests multiplication
# of bf16 numbers.
#
# For including as a library, include only codes in…
# (1) the "Required Library" sections, and
# (2) the "Library" section.
#
# Library dependency graph:
#   mul_shift_u32 -> **mul_bf16**
#
# Version: 0.1.0
# Tested: 2023-10-09T12:37:00+08:00

.text

# ┌-------------------------------------------------------┐
# |                     Testing Suite                     |
# └-------------------------------------------------------┘

.globl main
main:
    # test all functionalities
    jal  ra, mul_bf16_test

    # print result
    li   a7, 1 # to print integer
    ecall    # a0 = 0 for success, or non-zero for index of failed test

    # exit program
    li   a7, 10
    ecall


# --- mul_bf16_test ---
    # test the functionalities of mul_bf16
    # input: nothing
    # output:
    #   a0: error_code: 0 for success
    #                   otherwise, index of the first failed test
mul_bf16_test:
    mbt_prologue:
        addi sp, sp, -4
        sw   ra, 0(sp)
    mbt_t1:
        li   a0, 0x3F800000
        li   a1, 0x3F800000
        jal  ra, mul_bf16
        li   t0, 0x3F800000
        li   t1, 1 # error code
        bne  t0, a0, mbt_epilogue
    mbt_t2:
        li   a0, 0x3F000000
        li   a1, 0x40800000
        jal  ra, mul_bf16
        li   t0, 0x40000000
        li   t1, 2 # error code
        bne  t0, a0, mbt_epilogue
    mbt_t3:
        li   a0, 0xBF400000
        li   a1, 0x40B00000
        jal  ra, mul_bf16
        li   t0, 0xC0840000
        li   t1, 3 # error code
        bne  t0, a0, mbt_epilogue
    mbt_t4:
        li   a0, 0x40800000
        li   a1, 0
        jal  ra, mul_bf16
        li   t0, 0
        li   t1, 4 # error code
        bne  t0, a0, mbt_epilogue
    mbt_all_passed:
        li   t1, 0
    mbt_epilogue:
        mv   a0, t1 # error code
        lw   ra, 0(sp)
        addi sp, sp, 4
        ret


# ┌-------------------------------------------------------┐
# |        Required Library - mul_shift_u32 v0.0.0        |
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


# ┌-------------------------------------------------------┐
# |                        Library                        |
# └-------------------------------------------------------┘

# --- mul_bf16 ---
    # multiplication of two bf16 numbers
    # input:
    #   a0: a (bf16): multiplier
    #   a1: b (bf16): multiplicand
    # output:
    #   a0: m, r (bf16): product of a and b (a * b)
    # notes:
    #   s0: s
    #   s1: e
    #   t0: sa
    #   t1: sb
    #   t2: ea
    #   t3: eb
    #   t4: ma
    #   t5: mb
mul_bf16:
    mb_prologue:
        addi sp, sp, -12
        sw   ra, 0(sp)
        sw   s0, 4(sp)
        sw   s1, 8(sp)
    mb_body:
        beqz a0, mb_epilogue
        bnez a1, mb_nonzero_input
        mv   a0, zero
        j    mb_epilogue
    mb_nonzero_input:
        # extract sign, exponent and mantissa of a and b
        sltz t0, a0 # sa
        sltz t1, a1 # sb
        li   t3, 0x7F800000
        and  t2, a0, t3
        srli t2, t2, 23
        addi t2, t2, -127 # ea
        and  t3, a1, t3
        srli t3, t3, 23
        addi t3, t3, -127 # eb
        li   t5, 0x007F0000
        and  t4, a0, t5
        srli t4, t4, 16
        ori  t4, t4, 0x80 # ma
        and  t5, a1, t5
        srli t5, t5, 16
        ori  t5, t5, 0x80 # mb
        # calculate the initial result
        xor  s0, t0, t1 # s = sa ^ sb
        add  s1, t2, t3 # e = ea + eb
        mv   a0, t4
        mv   a1, t5
        jal  ra, mul_shift_u32
        srli a0, a0, 7  # m = (ma * mb) >> 7
        # handle carry bit
        andi t1, a0, 0x100
        beqz t1, mb_no_carry
        srli a0, a0, 1
        addi s1, s1, 1
    mb_no_carry:
        # handle result of +-0
        bnez a0, mb_nonzero_result
        slli a0, s0, 31   # r = s << 31
        j    mb_epilogue
    mb_nonzero_result:
        # construct the result
        slli s0, s0, 31   # s = s << 31
        addi s1, s1, 127
        slli s1, s1, 23   # e = (e + 127) << 23
        andi a0, a0, 0x7F
        slli a0, a0, 16   # m = (m & 0x7F) << 16
        or   a0, a0, s0
        or   a0, a0, s1   # r = s | e | m
    mb_epilogue:
        lw   ra, 0(sp)
        lw   s0, 4(sp)
        lw   s1, 8(sp)
        addi sp, sp, 12
        ret
