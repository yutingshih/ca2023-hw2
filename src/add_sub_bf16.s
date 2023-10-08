# This program implements and tests bf16 additions
# and subtraction.
# 
# For including as a library, include only codes in
# the "Library" section.
#
# Version: 0.1.0
# Tested: 2023-10-09T11:32:00+08:00

.text

# ┌-------------------------------------------------------┐
# |                     Testing Suite                     |
# └-------------------------------------------------------┘

main:
    # test all functionalities
    jal  ra, add_sub_bf16_test
    
    # print result
    li   a7, 1 # to print integer
    ecall    # a0 = 0 for success, or non-zero for index of failed test

    # exit program
    li   a7, 10
    ecall


# --- add_sub_bf16_test ---
    # test the functionalities of add_sub_bf16
    # input: nothing
    # output:
    #   a0: error_code: 0 for success
    #                   otherwise, index of the first failed test
add_sub_bf16_test:
    asbt_prologue:
        addi sp, sp -4
        sw   ra, 0(sp)
    asbt_t1:
        li   a0, 0x3F9A0000
        li   a1, 0x3FB30000
        li   a2, 1
        jal  ra, add_sub_bf16
        li   t0, 0x40260000
        li   t1, 1 # error code
        bne  t0, a0, asbt_epilogue
    asbt_t2:
        li   a0, 0x3F9A0000
        li   a1, 0x40140000
        jal  ra, add_bf16
        li   t0, 0x40610000
        li   t1, 2 # error code
        bne  t0, a0, asbt_epilogue
    asbt_t3:
        li   a0, 0x40410000
        li   a1, 0x3FFF0000
        jal  ra, add_bf16
        li   t0, 0x40A00000
        li   t1, 3 # error code
        bne  t0, a0, asbt_epilogue
    asbt_t4:
        li   a0, 0xC0410000
        li   a1, 0x3FFF0000
        jal  ra, add_bf16
        li   t0, 0xBF840000
        li   t1, 4 # error code
        bne  t0, a0, asbt_epilogue
    asbt_t5:
        li   a0, 0x40000000
        li   a1, 0x40000000
        jal  ra, sub_bf16
        li   t0, 0
        li   t1, 5 # error code
        bne  t0, a0, asbt_epilogue
    asbt_t6:
        li   a0, 0x40450000
        li   a1, 0x3F7F0000
        jal  ra, sub_bf16
        li   t0, 0x40060000
        li   t1, 6 # error code
        bne  t0, a0, asbt_epilogue
    asbt_t7:
        li   a0, 0xBFC00000
        li   a1, 0x40400000
        jal  ra, sub_bf16
        li   t0, 0xC0900000
        li   t1, 7 # error code
        bne  t0, a0, asbt_epilogue
    asbt_all_passed:
        li   t1, 0
    asbt_epilogue:
        mv   a0, t1 # error code
        lw   ra, 0(sp)
        addi sp, sp, 4
        ret


# ┌-------------------------------------------------------┐
# |                        Library                        |
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