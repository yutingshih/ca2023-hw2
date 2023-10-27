# This program implements and tests natural logarithm of bf16 numbers.
#
# For including as a library, include only codes in…
# (1) all of the "Required Library" sections, and
# (2) the "Library" section.
#
# Library dependency graph:
#                    add_sub_bf16 ↘
#   mul_shift_u32 -> mul_bf16 ----> **ln_bf16**
#                    i32_bf16     ↗
#
# Version: 0.2.0
# Tested: 2023-10-00T12:37:00+08:00

.text

# ┌-------------------------------------------------------┐
# |                     Testing Suite                     |
# └-------------------------------------------------------┘

.globl main
main:
    # test all functionalities
    jal  ra, ln_bf16_test

    # print result
    li   a7, 1 # to print integer
    ecall    # a0 = 0 for success, or non-zero for index of failed test

    # exit program
    li   a7, 10
    ecall


# --- ln_bf16_test ---
    # test the functionalities of mul_bf16
    # input: nothing
    # output:
    #   a0: error_code: 0 for success
    #                   otherwise, index of the first failed test
    # notes:
    #   the solution for the result of ln_bf16(x) is the result
    #   from the C program, for the values from both should be
    #   identical under the same implementation
ln_bf16_test:
    lbt_prologue:
        addi sp, sp, -4
        sw   ra, 0(sp)
    lbt_t1:
        li   a0, 0x00000000 # 0.00
        jal  ra, ln_bf16
        li   t0, 0xFF800000 # -inf
        li   t1, 1 # error code
        bne  t0, a0, lbt_epilogue
    lbt_t2:
        li   a0, 0x3D4D0000 # 0.05
        jal  ra, ln_bf16
        li   t0, 0xC03E0000 # -2.969
        li   t1, 2 # error code
        bne  t0, a0, lbt_epilogue
    lbt_t3:
        li   a0, 0x3E1A0000 # 0.15
        jal  ra, ln_bf16
        li   t0, 0xBFF20000 # -1.891
        li   t1, 3 # error code
        bne  t0, a0, lbt_epilogue
    lbt_t4:
        li   a0, 0x3E4D0000 # 0.20
        jal  ra, ln_bf16
        li   t0, 0xBFCA0000 # -1.578
        li   t1, 4 # error code
        bne  t0, a0, lbt_epilogue
    lbt_t5:
        li   a0, 0x3F260000 # 0.65
        jal  ra, ln_bf16
        li   t0, 0xBEDA0000 # -0.426
        li   t1, 5 # error code
        bne  t0, a0, lbt_epilogue
    lbt_t6:
        li   a0, 0x3F800000 # 1.00
        jal  ra, ln_bf16
        li   t0, 0x3C000000 # 0.008
        li   t1, 6 # error code
        bne  t0, a0, lbt_epilogue
    lbt_t7:
        li   a0, 0x40000000 # 2.00
        jal  ra, ln_bf16
        li   t0, 0x3F330000 # -0.006
        li   t1, 7 # error code
        bne  t0, a0, lbt_epilogue
    lbt_all_passed:
        li   t1, 0
    lbt_epilogue:
        mv   a0, t1 # error code
        lw   ra, 0(sp)
        addi sp, sp, 4
        ret



# ┌-------------------------------------------------------┐
# |         Required Library - add_sub_bf16 v0.1.0        |
# └-------------------------------------------------------┘

# --- add_sub_bf16 ---
    # addition or subtraction of two bf16 numbers
    # input:
    #   a0: a (bf16): add/sub candidate
    #   a1: b (bf16): add/sub candidate
    #   a2: to_add (int): 1 for addition; 0 for subtraction
    # output:
    #   a0: r (bf16): result of (a + b) or (a - b)
    # notes:
    #   t0: sa, s
    #   t1: sb
    #   t2: ea, e
    #   t3: eb
    #   t4: ma, m
    #   t5: mb
    #   t6: (always temp)
add_sub_bf16:
    asb_prologue:
        addi sp, sp, -4
        sw   ra, 0(sp)
    asb_body:
        # extract expoent and mantissa from a and b
        li   t6, 0x7F800000
        and  t2, a0, t6 # ea
        srli t2, t2, 23
        addi t2, t2, -127
        li   t6, 0x7F800000
        and  t3, a1, t6 # eb
        srli t3, t3, 23
        addi t3, t3, -127
        li   t6, 0x007F0000
        and  t4, a0, t6 # ma
        srli t4, t4, 16
        ori  t4, t4, 0x80
        li   t6, 0x007F0000
        and  t5, a1, t6 # mb
        srli t5, t5, 16
        ori  t5, t5, 0x80

        # normalization: make 2 numbers have the same exponent
        blt  t2, t3, asb_normalization_1
        mv   t6, t2      # t6 = ea
        sub  t2, t2, t3 # t2 = ea - eb
        srl  t5, t5, t2 # mb >>= t2
        mv   t2, t6      # e = t6
        j    asb_normalization_end
    asb_normalization_1:
        mv   t6, t3      # t6 = eb
        sub  t2, t3, t2 # t2 = ea - eb
        srl  t4, t4, t2 # ma >>= t2
        mv   t2, t6      # e = t6
    asb_normalization_end:
        # addition or subtraction
        li   t6, 0x80000000
        and  t0, a0, t6 # sa
        beqz t0, asb_not_invert_ma
        sub  t4, zero, t4
    asb_not_invert_ma:
        li   t6, 0x80000000
        and  t1, a1, t6 # sb
        beqz t1, asb_not_invert_mb_1
        sub  t5, zero, t5
    asb_not_invert_mb_1:
        bnez a2, asb_not_invert_mb_2
        sub  t5, zero, t5
    asb_not_invert_mb_2:
        add  t4, t4, t5 # m = ma + mb
        # handle negative result
        li   t0, 0
        bgez t4, asb_positive_m
        sub  t4, zero, t4
        li   t0, 1
    asb_positive_m:
        # handle carry bit
        andi t5, t4, 0x100
        beqz t5, asb_no_carry
        srli t4, t4, 1
        addi t2, t2, 1
    asb_no_carry:
        # handle result of 0
        li   t5, 0x80
        bnez t4, asb_small
        li   t2, -127     # e = -127
        j    asb_small_end
    asb_small:
        bge  t4, t5, asb_small_end # while (m < 0x80)
        addi t2, t2, -1 # e -= 1
        slli t4, t4, 1  # m <<= 1
        j    asb_small
    asb_small_end:
        # construct the result
        slli t0, t0, 31   # s = s << 31
        addi t2, t2, 127  # e = (e + 127) << 23
        slli t2, t2, 23
        andi t4, t4, 0x7F # m = (m & 0x7F) << 16
        slli t4, t4, 16
        or   a0, t0, t2   # r = s | e | m
        or   a0, a0, t4
    asb_epilogue:
        lw   ra, 0(sp)
        addi sp, sp, 4
        ret


# --- add_bf16 ---
    # addition of two bf16 numbers.
    # input:
    #   a0: a (bf16): addition candidate
    #   a1: b (bf16): addition candidate
    # output:
    #   a0: r (bf16): reslut of (a + b)
add_bf16:
        addi sp, sp, -4
        sw   ra, 0(sp)
        li   a2, 1
        jal  ra, add_sub_bf16
        lw   ra, 0(sp)
        addi sp, sp, 4
        ret


# --- sub_bf16 ---
    # subtraction of two bf16 numbers.
    # input:
    #   a0: a (bf16): subtraction candidate
    #   a1: b (bf16): subtraction candidate
    # output:
    #   a0: r (bf16): reslut of (a - b)
sub_bf16:
        addi sp, sp, -4
        sw   ra, 0(sp)
        li   a2, 0
        jal  ra, add_sub_bf16
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
# |          Required Library - mul_bf16 v0.1.0           |
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


# ┌-------------------------------------------------------┐
# |          Required Library - u32_bf16 v0.0.0           |
# └-------------------------------------------------------┘

# --- bf16_to_i32 ---
    # (NOT IMPLEMENTED YET!)
    # convert bf16 to i32
    # input:
    #   a0: x (bf16): bf16 number to be processed
    # output:
    #   a0: m, r (i32): 32-bit integer (without fraction)
bf16_to_i32:
    ret


# --- i32_to_bf16 ---
    # convert i32 to bf16
    # input:
    #   a0: x (i32): integer to convert
    # output:
    #   a0: m, r (bf16): float with roughly the same
    #                    value as input
    # notes:
    #   t0: s
    #   t1: e
i32_to_bf16:
    itb_prologue:
        addi sp, sp, -4
        sw   ra, 0(sp)
    itb_body:
        bnez a0, itb_nonzero_x
        # x == 0
        j    itb_epilogue
    itb_nonzero_x:
        sltz t0, a0 # s = sign bit of x
        li   t1, 7 # e = 7
        # `m = x` is `mv a0, a0`, which is nop
        beqz t0, itb_positive_x
        sub  a0, zero, a0 # m = -x
    itb_positive_x:
        li   t2, 0x80
    itb_small_x:
        bge  a0, t2, itb_large_x_outer
        addi t1, t1, -1
        slli a0, a0, 1
        j    itb_small_x
    itb_large_x_outer:
        li   t2, 0x100
    itb_large_x_inner:
        blt  a0, t2, itb_result
        addi t1, t1, 1
        srli a0, a0, 1
        j    itb_large_x_inner
    itb_result:
        andi a0, a0, 0x7F
        slli a0, a0, 16
        addi t1, t1, 127
        slli t1, t1, 23
        slli t0, t0, 31
        or   a0, a0, t1
        or   a0, a0, t0
    itb_epilogue:
        lw   ra, 0(sp)
        addi sp, sp, 4
        ret


# ┌-------------------------------------------------------┐
# |                        Library                        |
# └-------------------------------------------------------┘

# --- ln_bf16 ---
    # return ln(abs(x))
    # input:
    #   a0: x (bf16): number to transform
    # output:
    #   a0: t (bf16): result of ln(abs(x))
    # notes:
    #   s0: x, t (around last mul_bf16)
    #   s1: exp
    # reference: ln_bf16.c
ln_bf16:
    lb_prologue:
        addi sp, sp, -12
        sw   ra, 0(sp)
        sw   s0, 4(sp)
        sw   s1, 8(sp)
    lb_body:
        # remove extra bits (otherwise, offset-by-one bug occurs)
        li   t0, 0xFFFF0000
        and  a0, a0, t0
        # catch zero
        bnez a0, lb_nonzero_input
        li   a0, 0xFF800000
        j    lb_epilogue
    lb_nonzero_input:
        mv   s0, a0 # s0 = x, for x will be used later
        li   t0, 0x7F800000
        and  a0, s0, t0     # a0 = *px & 0x7F800000
        srli a0, a0, 23
        addi a0, a0, -127   # a0 = (a0 >> 23) - 127
        jal  i32_to_bf16    # a0 = (bf16) a0
        mv   s1, a0         # exp = a0
        # set x's exponent to 0
        li   t1, 0x7F0000
        li   t2, 0x3F800000
        and  s0, s0, t1
        or   s0, s0, t2     # x = 0x3F800000 | (*px & 0x7F0000)
        # calculate result (t)
        mv   a0, s0         # a0 = x
        li   a1, 0x3DE10000 # lnc3 = 0.109
        jal  mul_bf16       # a0 = lnc3 * x
        li   a1, 0xBF3B0000 # lnc2 = -0.73
        jal  add_bf16       # a0 = a0 + lnc2
        mv   a1, s0         # a1 = x
        jal  mul_bf16       # a0 = a0 * x
        li   a1, 0x40070000 # lnc1 = 2.11
        jal  add_bf16       # a0 = a0 + lnc1
        mv   a1, s0         # a1 = x
        jal  mul_bf16       # a0 = a0 * x
        li   a1, 0xBFBF0000 # lnc0 = -1.49
        jal  add_bf16       # a0 = a0 + lnc0
        mv   s0, a0         # s0 = t
        li   a0, 0x3F310000 # ln2  = 0.69
        mv   a1, s1         # a1 = exp
        jal  mul_bf16       # a0 = ln2 * exp
        mv   a1, s0         # a1 = t
        jal  add_bf16       # a0 = a0 + t (result)
    lb_epilogue:
        lw   ra, 0(sp)
        lw   s0, 4(sp)
        lw   s1, 8(sp)
        addi sp, sp, 12
        ret
