.PHONY: all clean run disasm help

# Toolchain
TOOLCHAIN := riscv64-unknown-elf
CC := $(TOOLCHAIN)-gcc
OBJDUMP := $(TOOLCHAIN)-objdump

# Architecture
ARCH := rv32im_zicsr
ABI  := ilp32

# Files
SRC := test.S
ELF := test.elf
DIS := test.dis
LDS := link.ld

# Compiler & Linker Flags
CFLAGS := -march=$(ARCH) -mabi=$(ABI) -nostdlib -nostartfiles -ffreestanding
LDFLAGS := -T $(LDS)

# Default target
all: $(ELF) disasm

# Compile & link assembly
$(ELF): $(SRC) $(LDS)
	@$(CC) $(CFLAGS) $(LDFLAGS) $< -o $@

# Generate disassembly
disasm: $(ELF)
	@$(OBJDUMP) -D -M no-aliases $(ELF) > $(DIS)

# Run test on Spike with logging
run: $(ELF)
	@spike --isa=rv32im_zicsr -l --log-commits $(ELF) 1>spike.out 2>spike.log	
	@echo "Spike execution completed."

# Clean build artifacts
clean:
	@rm -f $(ELF) $(DIS) spike.out spike.log
	@clear

# Help info
help:
	@echo "Makefile targets:"
	@echo "  all       : Compile, link and generate disassembly"
	@echo "  disasm    : Generate disassembly only"
	@echo "  run       : Run test on Spike and log commits"
	@echo "  clean     : Remove all build artifacts"
	@echo "  help      : Show this message"
