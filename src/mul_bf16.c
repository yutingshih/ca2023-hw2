/*
 * This program implements and tests the following functionality:
 *   Multiplication of bf16 numbers
 *
 * Definition of a bfloat16 (bf16) number:
 * (1) 1 sign, 8 exp, 7 mantissa (significand) bits, in order.
 * (2) Bf16 stored in a 32-bit memory chunk is at the
 *     highest (most significant) 16 bits.
 *
 * Reference: https://en.wikipedia.org/wiki/Bfloat16_floating-point_format
 *
 * Version: 0.0
 * Tested: 2023-10-07T14:09:00+08:00
 */

#ifndef MUL_BF16_C
#define MUL_BF16_C

#include "type_def.h"

// uncomment the following line to test this program
// #define MUL_BF16_TEST
#ifdef MUL_BF16_TEST
#include <stdio.h>  // puts, printf
#endif              // MUL_BF16_TEST

// uncomment the following line to see debugging info
// #define DEBUG
#ifdef DEBUG
#include "print_bf16.c"
#endif  // DEBUG

/* Multiply of two bf16 numbers.
 * Returns (a * b).
 *
 * Input format:
 *   a: bf16
 *   b: bf16
 * Output format: bf16
 */
bf16 mul_bf16(bf16 a, bf16 b) {
  u32 ba = *(u32 *)&a;
  u32 bb = *(u32 *)&b;
  u32 sa = ba & 0x80000000;
  u32 sb = bb & 0x80000000;
  i32 ea = ((ba & 0x7F800000) >> 23) - 127;
  i32 eb = ((bb & 0x7F800000) >> 23) - 127;
  i32 ma = ((ba & 0x007F0000) >> 16) | 0x0080;
  i32 mb = ((bb & 0x007F0000) >> 16) | 0x0080;

#ifdef DEBUG
  printf("(a and b in multiplication)\n");
  printf("%1s %8s %7s\n", "s", "exp", "mantissa");
  print_bf16_binary(a);
  print_bf16_binary(b);
  puts("");
#endif  // DEBUG

  u32 s = sa ^ sb;         // result sign (1 = negative, 0 = positive)
  u32 e = ea + eb;         // result exponent
  i32 m = (ma * mb) >> 7;  // result mantissa
  // notes:
  // * 0x4000 <= (ma * mb) <= 0xFE01
  // * 0x80 m <= 0x1FC

  // handle carry bit; make m <= 0xFF
  if (m & 0x100) {
    m >>= 1;
    e += 1;
  }

  // handle result of 0
  if (m == 0) {
    e = -127;
  }

  s = s << 31;
  e = (e + 127) << 23;
  m = (m & 0x7F) << 16;
  u32 r = s | e | m;

#ifdef DEBUG
  printf("(multiplication result)\n");
  printf("%1s %8s %7s\n", "s", "exp", "mantissa");
  print_bf16_binary(*(bf16 *)&r);
  puts("");
#endif  // DEBUG

  return *(bf16 *)&r;
}

/* Test the functionalities in this unit.
 * Return 0 if successes. Otherwise, return a non-zero number,
 * which indicates the first failed test.
 */
int test_mul_bf16() {
  bf16 a, b, r;
  u32 s;
  u32 *pa = (u32 *)&a;
  u32 *pb = (u32 *)&b;
  u32 *pr = (u32 *)&r;

  // 1: a = b = 1
  *pa = 0x3F800000;  // 0 01111111 0000000
  *pb = 0x3F800000;  // 0 01111111 0000000
  s = 0x3F800000;    // 0 10000000 0100110
  r = mul_bf16(a, b);
  if (*pr != s) return 1;

  // 2: a = 0.5, b = 4
  *pa = 0x3F000000;  // 0 01111110 0000000
  *pb = 0x40800000;  // 0 10000001 0000000
  s = 0x40000000;    // 0 10000000 0000000
  r = mul_bf16(a, b);
  if (*pr != s) return 2;

  // 3: a < 0, b > 0, mantissa carries
  *pa = 0xBF400000;  // 1 01111110 1000000
  *pb = 0x40B00000;  // 0 10000001 0110000
  s = 0x40840000;    // 0 10000001 0000100
  r = mul_bf16(a, b);
  if (*pr != s) return 3;

  return 0;
}

#ifdef MUL_BF16_TEST
int main() {
  int error_code = test_mul_bf16();
  if (error_code == 0) {
    puts("Test for mul_bf16.c passed.");
    return 0;
  } else {
    printf("Test %d for mul_bf16.c failed.\n", error_code);
    return 1;
  }
}
#endif  // MUL_BF16_TEST

#endif  // MUL_BF16_C