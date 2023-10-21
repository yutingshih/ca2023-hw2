/*
 * This program implements the following functionality:
 *   Print BF16 numbers in…
 *   (1) hexidecimal and decimal, and
 *   (2) binary
 */

#ifndef PRINT_BF16_C
#define PRINT_BF16_C

#include <stdio.h>   // printf
#include <string.h>  // sprintf, strncpy

#include "type_def.h"

void print_bf16_hex_dec(bf16 x) {
  char buffer[11] = {0};
  sprintf(buffer, "%08x", *(int *)&x);
  memset(buffer + 4, 0, 4 * sizeof(char));
  printf("%s %.6f\n", buffer, x);
}

/* Print the last (least significant) n_bits bits of x to buffer.
 */
void sprint_binary(char *buffer, u32 x, u32 n_bits) {
  for (int i = n_bits - 1; i >= 0; i--) {
    u32 is_bit_set = (x >> i) & 1;
    sprintf(buffer, "%c", (is_bit_set ? '1' : '0'));
    buffer += 1;
  }
  buffer[0] = '\0';
}

/* Print the bf16 number in binary. */
void print_bf16_binary(bf16 x) {
  u32 bx = (*(u32 *)&x) >> 16;
  char buffer[17];
  sprint_binary(buffer, bx, 16);

  char s[2] = {0};
  char e[9] = {0};
  char m[8] = {0};
  strncpy(s, buffer, 1);
  strncpy(e, buffer + 1, 8);
  strncpy(m, buffer + 9, 7);

  printf("%s %s %s\n", s, e, m);
}

#endif  // PRINT_BF16_C