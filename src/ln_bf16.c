/*
 * This program implements and tests the following functionality:
 *   Natural logarithm of fp32 and bf16 numbers.
 *
 * Version: 0.1
 * Tested: 2023-10-07T22:33:00+08:00
 */

#ifndef LN_BF16_C
#define LN_BF16_C

#include "add_sub_bf16.c"
#include "i32_bf16.c"
#include "mul_bf16.c"
#include "type_def.h"

// uncomment the following line to test this program
// #define LN_BF16_TEST
#ifdef LN_BF16_TEST
#include <stdio.h>
#include <string.h>

#include "fp32_bf16.c"
#include "print_bf16.c"
#endif  // LN_BF16_TEST

/* ln(abs(x))
 * Returns ln(abs(x)),
 *   which is calculated by the 3rd-order polynomial approximation
 *   obtained by the Remez algorithm.
 *
 * Notice: This function only works with 32-bit integers and fp32 with
 *   normal numbers. (i.e., x > 2^-126.)
 *
 * Reference: https://quadst.rip/ln-approx.html
 */
float ln_fp32(float x) {
  unsigned int *px = (unsigned int *)&x;

  // catch zero
  if (*px == 0) {
    *px = 0xFF800000;
    return *(bf16 *)px;
  }

  // discard x's sign
  *px &= 0x7FFFFFFF;

  // get exponent
  int exp = (*px >> 23) - 127;

  // set x's exponent to 0, which is 127 after normalization.
  *px = 0x3F800000 | (*px & 0x7FFFFF);

  return -1.49278 + (2.11263 + (-0.729104 + 0.10969 * x) * x) * x +
         0.6931471806 * exp;
}

/* ln(abs(x))
 * Returns ln(abs(x)),
 * which is calculated by the 3rd-order polynomial approximation
 * obtained by the Remez algorithm.
 *
 * Input format: bf16
 * Output format: bf16
 *
 * This function only works in a 32-bit runtime.
 */
bf16 ln_bf16(bf16 x) {
  // Constants for bf16 in the precision of bf16
  const u32 u_lnc0 = 0xBFBF0000;  // -1.49
  const u32 u_lnc1 = 0x40070000;  // 2.11
  const u32 u_lnc2 = 0xBF3B0000;  // -0.73
  const u32 u_lnc3 = 0x3DE10000;  // 0.109
  const u32 u_ln2 = 0x3F310000;   // 0.69

  // Constants for this function in the precision of bf16
  const bf16 lnc0 = *(bf16 *)&u_lnc0;  // -1.49
  const bf16 lnc1 = *(bf16 *)&u_lnc1;  // 2.11
  const bf16 lnc2 = *(bf16 *)&u_lnc2;  // -0.73
  const bf16 lnc3 = *(bf16 *)&u_lnc3;  // 0.109
  const bf16 ln2 = *(bf16 *)&u_ln2;    // 0.69

  u32 *px = (u32 *)&x;
  bf16 exp = i32_to_bf16(((*px & 0x7F800000) >> 23) - 127);

  // catch zero
  if (*px == 0) {
    *px = 0xFF800000;
    return *(bf16 *)px;
  }

  // set x's exponent to 0, which is 127 after normalization.
  *px = 0x3F800000 | (*px & 0x7F0000);

  // return lnc0 + (lnc1 + (lnc2 + lnc3 * x) * x) * x + ln2 * exp;
  bf16 t;
  t = add_bf16(lnc2, mul_bf16(lnc3, x));  // t = lnc2 + lnc3 * x
  t = add_bf16(lnc1, mul_bf16(t, x));     // t = lnc1 + t * x
  t = add_bf16(lnc0, mul_bf16(t, x));     // t = lnc0 + t * x
  t = add_bf16(t, mul_bf16(ln2, exp));    // t = t + ln2 * exp
  return t;
}

#ifdef LN_BF16_TEST
void print_comparison_fp32_bf16(float f, bf16 b) {
  printf("%5.2f", fp32_to_bf16(f));
  print_bf16_binary(fp32_to_bf16(f));
  printf("%5.2f", b);
  print_bf16_binary(b);
  puts("");
}

/* Test the functionalities in this unit.
 * Return 0 if successes. Otherwise, return a non-zero number,
 * which indicates the first failed test.
 */
int test_ln_bf16() {
  float f, rf;
  bf16 b, rb;

  // 1: ln(1) = 0
  f = b = i32_to_bf16(1);
  rf = ln_fp32(f);
  rb = ln_bf16(b);
  printf("Ln test 1: ln(1) = 0\n");
  print_comparison_fp32_bf16(rf, rb);

  // 2: ln(2) = 0.693
  f = b = fp32_to_bf16(2.0f);
  rf = ln_fp32(f);
  rb = ln_bf16(b);
  printf("Ln test 2: ln(2) = 0.693\n");
  print_comparison_fp32_bf16(rf, rb);

  // 3: ln(0.5) = -0.693
  f = b = fp32_to_bf16(0.5f);
  rf = ln_fp32(f);
  rb = ln_bf16(b);
  printf("Ln test 3: ln(0.5) = -0.693\n");
  print_comparison_fp32_bf16(rf, rb);

  // 4: ln(0.1) = -2.302
  f = b = fp32_to_bf16(0.1f);
  rf = ln_fp32(f);
  rb = ln_bf16(b);
  printf("Ln test 4: ln(0.1) = -2.302\n");
  print_comparison_fp32_bf16(rf, rb);

  return 0;
}

int main() {
  test_ln_bf16();
  return 0;
}
#endif  // LN_BF16_TEST

#endif  // LN_BF16_C