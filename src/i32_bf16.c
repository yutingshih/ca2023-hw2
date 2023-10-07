/*
 * This program implements and tests the following functionality:
 *   Conversion from 32-bit integer (i32) to bfloat16 (bf16),
 *   and vice versa.
 *
 * Version: 0.0
 * Tested: 2023-10-07T17:46:00+08:00
 */

#ifndef I32_BF16_C
#define I32_BF16_C

#include "type_def.h"

// uncomment the following line to test this program
// #define I32_BF16_TEST
#ifdef I32_BF16_TEST
#include <stdio.h>  // puts, printf
#endif              // I32_BF16_TEST

i32 bf16_to_i32(bf16 x) {
  u32 ux = *(u32 *)&x;
  if ((ux & 0x7FFF0000) == 0) return 0;

  u32 s = ux & 0x80000000;
  i32 e = ((ux & 0x7F800000) >> 23) - 127 - 7;
  i32 m = ((ux & 0x007F0000) >> 16) | 0x0080;

  i32 r = m;
  if (e < 0) {
    r >>= -e;
  } else if (e >= 24) {
    r = 0x7FFFFFFF;  // most positive/negative number as NaN
  } else if (e > 0) {
    r <<= e;
  }
  r = s ? -r : r;
  return r;
}

bf16 i32_to_bf16(i32 x) {
  if (x == 0) return (bf16)0;  // 0 00000000 0000000

  i32 s = (x < 0) ? 1 : 0; // sign bit of x
  i32 e = 7;
  i32 m = s ? -x : x;

  // increment exponent until (1.0 <= mantissa < 2.0)
  // fraction smaller than the precision of bf16 is dropped (floored)
  while (m < 0x80) {
    e -= 1;
    m <<= 1;
  }

  // decrement exponent until (1.0 <= mantissa < 2.0)
  while (m >= 0x100) {
    e += 1;
    m >>= 1;
  }

  s = s << 31;
  e = (e + 127) << 23;
  m = (m & 0x7F) << 16;
  u32 r = s | e | m;
  return *(bf16 *)&r;
}

/* Test the functionalities in this unit.
 * Return 0 if successes. Otherwise, return a non-zero number,
 * which indicates the first failed test.
 */
int test_i32_bf16() {
  i32 s, ri;
  bf16 b, rb;
  i32 *pb = (i32 *)&b;
  i32 *prb = (i32 *)&rb;

  // 1: i32 0 -> bf16 0.0
  rb = i32_to_bf16(0);
  s = 0;  // 0 00000000 0000000
  if (*prb != s) return 1;

  // 2: i32 1 -> bf16 1.0
  rb = i32_to_bf16(1);
  s = 0x3F800000;  // 0 01111111 0000000
  if (*prb != s) return 2;

  // 3: i32 255 -> bf16 255.0
  rb = i32_to_bf16(255);
  s = 0x437F0000;  // 0 10000110 1111111
  if (*prb != s) return 3;

  // 4: i32 -256 -> bf16 -256.0
  rb = i32_to_bf16(-256);
  s = 0xC3800000;  // 1 10000111 0000000
  if (*prb != s) return 4;

  // 5: i32 -257 -> bf16 -256.0
  rb = i32_to_bf16(-257);
  s = 0xC3800000;  // 1 10000111 0000001
  if (*prb != s) return 5;

  // 6: bf16 0.0 -> i32 0.0
  *pb = 0;  // 0
  ri = bf16_to_i32(b);
  s = 0;
  if (ri != s) return 6;

  // 7: bf16 1.0 -> i32 1
  *pb = 0x3F800000;  // 0 01111111 0000000
  ri = bf16_to_i32(b);
  s = 1;
  if (ri != s) return 7;

  // 8: bf16 2.25 -> i32 2
  *pb = 0x40100000;  // 0 10000000 0010000
  ri = bf16_to_i32(b);
  s = 2;
  if (ri != s) return 8;

  // 9: bf16 258.0 -> i32 258
  *pb = 0x43810000;  // 0 10000111 0000001
  ri = bf16_to_i32(b);
  s = 258;
  if (ri != s) return 9;

  return 0;
}

#ifdef I32_BF16_TEST
int main() {
  int error_code = test_i32_bf16();
  if (error_code == 0) {
    puts("Test for i32_bf16.c passed.");
    return 0;
  } else {
    printf("Test %d for i32_bf16.c failed.\n", error_code);
    return 1;
  }
}
#endif  // I32_BF16_TEST

#endif  // I32_BF16_C