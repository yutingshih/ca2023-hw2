# This program implements and tests conversion between
# 32-bit integer (i32) and bfloat16 (bf16).
#
# For including as a library, include only codes in
# the "Library" section.
#
# Library dependency graph:
#   **i32_bf16** -> ln_bf16
#
# Version: 0.0.0
# Tested: 2023-10-09T10:33:00+08:00


.text

# ┌-------------------------------------------------------┐
# |                     Testing Suite                     |
# └-------------------------------------------------------┘

.globl main
main:
    # test all functionalities
    jal  ra, i32_bf16_test
    # returns a0 = 0 for success, or non-zero for index of failed test

    # print result
    jal ra, print_int
    li a0, '\n'
    jal ra, print_char

    # exit program
    j exit


# --- i32_bf16_test ---
    # test the functionalities of i32_to_bf16 and
    # bf16_to_i32
    # input: nothing
    # output:
    #   a0: error_code: 0 for success
    #                   otherwise, index of the first failed test
i32_bf16_test:
    ibt_prologue:
        addi sp, sp, -4
        sw   ra, 0(sp)
    ibt_t1:
        li   a0, 0
        jal  ra, i32_to_bf16
        li   t0, 0
        li   t1, 1 # error code
        bne  t0, a0, ibt_epilogue
    ibt_t2:
        li   a0, 1
        jal  ra, i32_to_bf16
        li   t0, 0x3F800000
        li   t1, 2 # error code
        bne  t0, a0, ibt_epilogue
    ibt_t3:
        li   a0, 255
        jal  ra, i32_to_bf16
        li   t0, 0x437F0000
        li   t1, 3 # error code
        bne  t0, a0, ibt_epilogue
    ibt_t4:
        li   a0, -256
        jal  ra, i32_to_bf16
        li   t0, 0xC3800000
        li   t1, 4 # error code
        bne  t0, a0, ibt_epilogue
    ibt_t5:
        li   a0, -257
        jal  ra, i32_to_bf16
        li   t0, 0xC3800000
        li   t1, 5 # error code
        bne  t0, a0, ibt_epilogue
    ibt_all_passed:
        li   t1, 0
    ibt_epilogue:
        mv   a0, t1 # error code
        lw   ra, 0(sp)
        addi sp, sp, 4
        ret


# ┌-------------------------------------------------------┐
# |                        Library                        |
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
