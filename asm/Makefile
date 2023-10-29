TARGET ?= add_sub_bf16 i32_bf16 ln_bf16 mul_bf16 mul_shift_u32 mul_sum_u32
BIN := $(addsuffix .elf, $(TARGET))

CROSS := riscv-none-elf-
CC := $(CROSS)gcc
AS := $(CROSS)as
LD := $(CROSS)ld
CFLAGS := -march=rv32i -mabi=ilp32 -ffreestanding
ASFLAGS := -march=rv32i -mabi=ilp32 -R
LDFLAGS := --oformat=elf32-littleriscv -T link.ld

all: $(BIN)

%.elf: %.o syscall.o
	$(LD) $(LDFLAGS) -o $@ $^

test: $(BIN)
	@for i in $^; do rv32emu $$i; done

test_%: %.elf
	@rv32emu $<

clean:
	-@$(RM) -v $(BIN)
