# Usage:
# 	make [all]                              compile all the targets
# 	make TARGET                             compile a specific target
#	make TARGET [TARGET [...]]              compile specific targets
# 	make test                               run tests for all the targets
# 	make test_TARGET                        run test for a specific target
# 	make test_TARGET [test_TARGET [...]]    run tests for specific targets
# 	make clean                              delete all the executables
#
# Example:
#	make                    (compile all the targets)
# 	make clean test         (delete all the executables, compile and run all the tests)
# 	make all test_mul_bf16  (compile all the targets but only run test for mul_bf16)

BIN ?= i32_bf16 fp32_bf16 add_sub_bf16 mul_bf16 ln_bf16

CROSS ?= riscv-none-elf-
CC := $(CROSS)gcc
CFLAGS := -Wall -Wextra
LDLIBS := -lm

ifdef CROSS
	CFLAGS += -march=rv32i -mabi=ilp32
	RUNTIME ?= rv32emu
endif

all: $(BIN)

%: %.c
	-$(CC) -D$(shell echo $@ | tr a-z A-Z)_TEST $(CFLAGS) -o $@ $< $(LDLIBS)

test: $(addprefix test_, $(BIN))
test_%: %
	-@$(RUNTIME) $<

clean:
	-@$(RM) -v $(BIN)
