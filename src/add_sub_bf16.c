/*
 * This program implements and tests the following functionality:
 *   Addition and subtraction of bfloat16 (bf16) numbers.
 *
 * Definition of a bfloat16 (bf16) number:
 * (1) 1 sign, 8 exp, 7 mantissa (significand) bits, in order.
 * (2) Bf16 stored in a 32-bit memory chunk is at the
 *     highest (most significant) 16 bits.
 *
 * Reference: https://en.wikipedia.org/wiki/Bfloat16_floating-point_format
 *
 * Version: 0.1
 * Tested: 2023-10-07T15:05:00+08:00
 */

#ifndef ADD_SUB_BF16_C
#define ADD_SUB_BF16_C

// uncomment the following line to test this program
// #define ADD_SUB_BF16_TEST
#ifdef ADD_SUB_BF16_TEST
#include <stdio.h>  // puts, printf
#endif              // ADD_SUB_BF16_TEST

#include "type_def.h"

// uncomment the following line to see debugging info
// #define ADD_SUB_BF16_DEBUG
#ifdef ADD_SUB_BF16_DEBUG
#include "print_bf16.c"  // print_bf16_binary
#endif                   // ADD_SUB_BF16_DEBUG

/* Addition or subtraction of two bf16 numbers.
 * Returns (a + b) or (a - b), depends on whether to_add.
 *
 * Input format:
 *   a: bf16
 *   b: bf16
 *   to_add: 1 for addition, 0 for subtraction
 * Output format: bf16
 */
bf16 add_sub_bf16(bf16 a, bf16 b, int to_add) {
  u32 ba = *(u32 *)&a; // must be unsigned
  u32 bb = *(u32 *)&b; // must be unsigned
  u32 sa = ba & 0x80000000;
  u32 sb = bb & 0x80000000;
  i32 ea = ((ba & 0x7F800000) >> 23) - 127;
  i32 eb = ((bb & 0x7F800000) >> 23) - 127;
  i32 ma = ((ba & 0x007F0000) >> 16) | 0x80;
  i32 mb = ((bb & 0x007F0000) >> 16) | 0x80;

#ifdef ADD_SUB_BF16_DEBUG
  printf("(a and b in addition)\n");
  printf("%1s %8s %7s\n", "s", "exp", "mantissa");
  print_bf16_binary(a);
  print_bf16_binary(b);
  puts("");
#endif  // ADD_SUB_BF16_DEBUG

  u32 s = 0;  // result sign (1 = negative, 0 = positive)
  u32 e = 0;  // result exponent
  i32 m = 0;  // result mantissa

  // normalization: make 2 numbers have the same exponent
  if (ea >= eb) {
    e = ea;
    mb >>= (ea - eb);  // arithmetic right shift
  } else {
    e = eb;
    ma >>= (eb - ea);  // arithmetic right shift
  }

  // addition or subtraction;
  // make abs(m) <= 0x1FE by implementation.
  // note: negating numbers has to be postponed to after normalization.
  //       otherwise, it will lead to an error of -1 in mantissa.
  ma = (sa != 0) ? -ma : ma;
  mb = (sb != 0) ? -mb : mb;
  mb = (to_add == 0) ? -mb : mb;
  m = ma + mb;

  // handle negative result
  if (m < 0) {
    m = -m;
    s = 1;
  } else
    s = 0;

  // handle carry bit; make m <= 0xFF
  if (m & 0x100) {
    m >>= 1;
    e += 1;
  }

  // handle result of 0
  if (m == 0) {
    e = -127;
  } else {
    // handle result < 1
    while (m < 0x80) {
      e -= 1;
      m <<= 1;
    }
  }

  // construct the result
  s = s << 31;
  e = (e + 127) << 23;
  m = (m & 0x7F) << 16;
  u32 r = s | e | m;

#ifdef ADD_SUB_BF16_DEBUG
  printf("(addition result)\n");
  printf("%1s %8s %7s\n", "s", "exp", "mantissa");
  print_bf16_binary(*(bf16 *)&r);
  puts("");
#endif  // ADD_SUB_BF16_DEBUG

  return *(bf16 *)&r;
}

/* Addition of two bf16 numbers.
 * Returns (a + b).
 *
 * Input format:
 *   a: bf16
 *   b: bf16
 * Output format: bf16
 */
bf16 add_bf16(bf16 a, bf16 b) { return add_sub_bf16(a, b, 1); }

/* Subtraction of two bf16 numbers.
 * Returns (a - b).
 *
 * Input format:
 *   a: bf16
 *   b: bf16
 * Output format: bf16
 */
bf16 sub_bf16(bf16 a, bf16 b) { return add_sub_bf16(a, b, 0); }

/* Test the functionalities in this unit.
 * Return 0 if successes. Otherwise, return a non-zero number,
 * which indicates the first failed test.
 */
int test_add_sub_bf16() {
  bf16 a, b, r;
  u32 s;
  u32 *pa = (u32 *)&a;
  u32 *pb = (u32 *)&b;
  u32 *pr = (u32 *)&r;

  // 1: add, a > 0, b > 0, exp_a == exp_b, exp carry
  *pa = 0x3F9A0000;  // 0 01111111 0011010
  *pb = 0x3FB30000;  // 0 01111111 0110011
  s = 0x40260000;    // 0 10000000 0100110
  r = add_sub_bf16(a, b, 1);
  if (*pr != s) return 1;

  // 2: add, a > 0, b > 0, exp_a < exp_b , no exp carry
  *pa = 0x3F9A0000;  // 0 01111111 0011010
  *pb = 0x40140000;  // 0 10000000 0010100
  s = 0x40610000;    // 0 10000000 1100001
  r = add_bf16(a, b);
  if (*pr != s) return 2;

  // 3: add, a > 0, b > 0, exp_a > exp_n, exp carry
  *pa = 0x40410000;  // 0 10000000 1000001
  *pb = 0x3FFF0000;  // 0 01111111 1111111
  s = 0x40A00000;    // 0 10000001 0100000
  r = add_bf16(a, b);
  if (*pr != s) return 3;

  // 4: add, a < 0, b > 0, (a + b) < 0, exp decreases
  *pa = 0xC0410000;  // 1 10000000 1000001
  *pb = 0x3FFF0000;  // 0 01111111 1111111
  s = 0xBF840000;    // 1 01111111 0000100
  r = add_bf16(a, b);
  if (*pr != s) return 4;

  // 5: sub, a = b
  *pa = 0x40000000;  // 0 10000000 0000000
  *pb = 0x40000000;  // 0 10000000 0000000
  s = 0;             // 0 00000000 0000000
  r = add_sub_bf16(a, b, 0);
  if (*pr != s) return 5;

  // 6: sub, a > 0, b > 0, (a - b) > 0, no exp carry
  *pa = 0x40450000;  // 0 10000000 1000101
  *pb = 0x3F7F0000;  // 0 01111110 1111111
  s = 0x40060000;    // 0 10000000 0000110
  r = sub_bf16(a, b);
  if (*pr != s) return 6;

  // 7: sub, a < 0, b > 0, exp_a < exp_b, exp carry
  *pa = 0xBFC00000;  // 1 01111111 1000000
  *pb = 0x40400000;  // 0 10000000 1000000
  s = 0xC0900000;    // 1 10000001 0010000
  r = sub_bf16(a, b);
  if (*pr != s) return 7;

  return 0;
}

#ifdef ADD_SUB_BF16_TEST
int main() {
  int error_code = test_add_sub_bf16();
  if (error_code == 0) {
    puts("Test for add_sub_bf16.c passed.");
    return 0;
  } else {
    printf("Test %d for add_sub_bf16.c failed.\n", error_code);
    return 1;
  }
}
#endif  // ADD_SUB_BF16_TEST

#endif  // ADD_SUB_BF16_C