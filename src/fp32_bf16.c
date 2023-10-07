/*
 * This program implements and tests the following functionality:
 *   Conversion from IEEE 754 single-precision
 *   32-bit float (fp32) to bfloat16 (bf16), and vice versa.
 *
 * Version: 0.0
 * Tested: 2023-10-07T14:47:00+08:00
 */

#ifndef FP32_BF16_C
#define FP32_BF16_C

#include "type_def.h"

// uncomment the following line to test this program
// #define FP32_BF16_TEST
#ifdef FP32_BF16_TEST
#include <stdio.h>  // puts, printf
#endif              // FP32_BF16_TEST

/* Convert fp32 to bf16.
 * Input format: fp32
 * Output format: bf16
 *
 * Reference: https://onestepcode.com/float-to-int-c/
 * Reference: https://hackmd.io/@sysprog/arch2023-quiz1-sol#Problem-B
 */
bf16 fp32_to_bf16(float x) {
  bf16 y = x;
  int *p = (int *)&y;
  unsigned int exp = *p & 0x7F800000;
  unsigned int man = *p & 0x007FFFFF;
  if (exp == 0 && man == 0)  // zero
    return x;
  if (exp == 0x7F800000)  // infinity or NaN
    return x;

  // normalized number: round to nearest
  float r = x;
  int *pr = (int *)&r;
  *pr &= 0xFF800000;  // r has the same exp as x
  r /= 0x100;
  y = x + r;

  *p &= 0xFFFF0000;

  return y;
}

/* Convert bf16 to fp32.
 * Input format: bfloat16 stored in the higher 16 bits
 * Output format: IEEE 754 single-precision 32-bit float
 */
float bf16_to_fp32(bf16 x) {
  int *p = (int *)&x;
  // just in case some random bits are in the lower 16 bits.
  *p &= 0xFFFF0000;
  return x;
}

/* Test the functionalities in this unit.
 * Return 0 if successes. Otherwise, return a non-zero number,
 * which indicates the first failed test.
 */
int test_fp32_bf16() {
  float x, r;
  u32 s;
  u32 *px = (u32 *)&x;
  u32 *pr = (u32 *)&r;

  // 1: fp32 -> bf16, round down
  *px = 0x40807FFF;
  r = fp32_to_bf16(x);
  s = 0x40800000;  // 0 10000001 0000000
  if (*pr != s) return 1;

  // 2: fp32 -> bf16, round up
  *px = 0xC0808000;
  r = fp32_to_bf16(x);
  s = 0xC0810000;  // 1 10000001 0000001
  if (*pr != s) return 2;

  // 3: bf16 -> fp32
  *px = 0xC0FF0000;  // 1 10000001 1111111
  r = bf16_to_fp32(x);
  s = 0xC0FF0000;  // 1 10000001 1111111
  if (*pr != s) return 3;

  return 0;
}

#ifdef FP32_BF16_TEST
int main() {
  int error_code = test_fp32_bf16();
  if (error_code == 0) {
    puts("Test for fp32_bf16.c passed.");
    return 0;
  } else {
    printf("Test %d for fp32_bf16.c failed.\n", error_code);
    return 1;
  }
}
#endif  // FP32_BF16_TEST

#endif  // FP32_BF16_C