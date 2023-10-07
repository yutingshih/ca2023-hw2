# This makefile is a utility for C source code.
#
# Usage: make SRC=<C_source_filename_without_dot_c>
#
# Example: make SRC="src/ln_bf16"

CFLAGS = -Wall -Wextra

all: $(SRC).c compile run clean

compile: $(SRC).c
	@gcc $? $(CFLAGS) -o $(SRC)

run: $(SRC).exe
	@./$?

clean:
	@rm $(SRC).exe