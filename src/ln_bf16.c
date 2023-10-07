/*
 * This program implements and tests the following functionality:
 *   Natural logarithm of fp32 and bf16 numbers.
 *
 * Version: 0.2
 * Tested: 2023-10-07T22:39:00+08:00
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
#include <math.h>
#include <stdio.h>
#include <string.h>

#include "fp32_bf16.c"
#include "print_bf16.c"

// uncomment the following line to generate the dataset
// #define LN_BF16_GENERATE_DATASET

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
  i32 *px = (i32 *)&x;

  // catch zero
  if (*px == 0) {
    *px = 0xFF800000;  // -inf
    return *(bf16 *)px;
  }

  // discard x's sign
  *px &= 0x7FFFFFFF;

  // get exponent
  i32 exp = (*px >> 23) - 127;

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
  // constants for bf16 in the precision of bf16
  const u32 u_lnc0 = 0xBFBF0000;  // -1.49
  const u32 u_lnc1 = 0x40070000;  // 2.11
  const u32 u_lnc2 = 0xBF3B0000;  // -0.73
  const u32 u_lnc3 = 0x3DE10000;  // 0.109
  const u32 u_ln2 = 0x3F310000;   // 0.69

  // constants for this function in the precision of bf16
  const bf16 lnc0 = *(bf16 *)&u_lnc0;  // -1.49
  const bf16 lnc1 = *(bf16 *)&u_lnc1;  // 2.11
  const bf16 lnc2 = *(bf16 *)&u_lnc2;  // -0.73
  const bf16 lnc3 = *(bf16 *)&u_lnc3;  // 0.109
  const bf16 ln2 = *(bf16 *)&u_ln2;    // 0.69

  u32 *px = (u32 *)&x;
  // remove extra bits (otherwise, offset-by-one bug occurs)
  *px = *px & 0x7FFF0000;

  // catch zero
  if (*px == 0) {
    *px = 0xFF800000;
    return *(bf16 *)px;
  }

  bf16 exp = i32_to_bf16(((*px & 0x7F800000) >> 23) - 127);

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

#ifdef LN_BF16_GENERATE_DATASET
void print_fp32_bf16_comparison_header() {
  puts(
      "   x, x (bf16, hex),  ln(x), ln_fp32(x), ln_bf16(x), ln_bf16(x) (hex), "
      "  error");
}

void print_fp32_bf16_comparison_row(float x, float t, float f, bf16 b) {
  bf16 bf_in = fp32_to_bf16(x);
  printf("%4.2f, %5s%08X, %6.3f, ", x, "0x", *(u32 *)&bf_in, t);
  printf("%10.3f, %10.3f, %8s%08X, ", f, b, "0x", *(u32 *)&b);
  printf("%7.3f\n", t - b);
}
#endif  // LN_BF16_GENERATE_DATASET

/*
 * if x = 0, return 0
 * if 0 < x <= 9, return 10
 * if 10 < x <= 99, return 100
 * ...
 *
 * Note: a u32 number is less than or equal to 4,294,967,295.
 */
u32 get_smallest_decimal_number(u32 x) {
  const u32 one_billion = 1000000000;
  if (x > one_billion) return one_billion;
  if (x == 0) return 0;
  u32 divisor = 10;
  while (x / divisor != 0) divisor *= 10;
  return divisor;
}

/* Test the functionalities in this unit.
 * Return 0 if successes. Otherwise, return a non-zero number,
 * which indicates the first failed test.
 */
int test_ln_bf16(float n_rows, float *average_error, float *maximal_error) {
#ifdef LN_BF16_GENERATE_DATASET
  print_fp32_bf16_comparison_header();
#endif  // LN_BF16_GENERATE_DATASET

  n_rows = roundf(n_rows);
  *average_error = 0;
  *maximal_error = 0;
  float error_code_multiplier = (float)get_smallest_decimal_number((u32)n_rows);
  float step = 2.0 / n_rows;
  for (float f = 0; f <= 2.0001; f += step) {
    float t = logf(f);
    bf16 rb = ln_bf16(fp32_to_bf16(f));
    bf16 error = fabsf(t - rb);
    if (isfinite(error)) {
      *average_error += error / n_rows;
      if (error > 0.05)  // something is wrong.
        return (int)(f * error_code_multiplier);
      if (error > *maximal_error) *maximal_error = error;
    }

#ifdef LN_BF16_GENERATE_DATASET
    float rf = ln_fp32(f);
    print_fp32_bf16_comparison_row(f, t, rf, rb);
#endif  // LN_BF16_GENERATE_DATASET
  }

  return 0;
}

int main() {
  float average_error = 0, maximal_error = 0;
  int error_code = test_ln_bf16(40, &average_error, &maximal_error);
  if (error_code == 0) {
    puts("Test for ln_bf16.c passed.");
    printf("Average error: %.3f\n", average_error);
    printf("Maximal error: %.3f\n", maximal_error);
    return 0;
  } else {
    printf("Test %.2f for ln_bf16.c failed.\n", error_code / 100.0);
    return 1;
  }
}
#endif  // LN_BF16_TEST

#endif  // LN_BF16_C