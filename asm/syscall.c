#define STDOUT_FILENO 1

/* write system call implementation using RISC-V ecall */
int write(int fd, const void* buf, unsigned nbyte) {
    asm(
        ".equ SYS_WRITE, 64" "\n\t"
        "li a7, SYS_WRITE" "\n\t"
        "ecall" "\n"
    );
    return 0;
}

/* exit system call implementation using RISC-V ecall */
int exit(int status) {
    asm(
        ".equ SYS_EXIT, 93" "\n\t"
        "li a7, SYS_EXIT" "\n\t"
        "ecall" "\n"
    );
    return 0;
}

/* print a character */
void print_char(char ch) {
    write(STDOUT_FILENO, &ch, 1);
}

/* print a null-terminated string */
void print_string(const char* str) {
    unsigned len = 0;
    while (str[len]) len++;
    write(STDOUT_FILENO, str, len);
}

/* calculate the quotient of (a0 / a1) */
unsigned _divu(unsigned a0, unsigned a1) {
    unsigned q = 0;
    while (a0 >= a1) {
        a0 -= a1;
        q++;
    }
    return q;
}

/* calculate the remainder of (a0 % a1) */
unsigned _remu(unsigned a0, unsigned a1) {
    while (a0 >= a1) a0 -= a1;
    return a0;
}

// The max length of a 32-bit signed integer is 11.
// (10 characters for digits, and 1 for the sign character)
#define STACK_SIZE 12

/* print a signed integer */
void print_int(int num) {
    int neg = num < 0;
    if (neg) num = -num;

    char stack[STACK_SIZE], *ptr = stack + STACK_SIZE;

    do {
        *--ptr = (char) ('0' + _remu(num, 10));
        num = _divu(num, 10);
    } while (num);

    if (neg) *--ptr = '-';

    int len = STACK_SIZE - (ptr - stack);
    write(STDOUT_FILENO, ptr, len);
}
