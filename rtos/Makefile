TOOLCHAIN ?= /opt/riscv/bin
CC = $(TOOLCHAIN)/riscv32-unknown-elf-gcc
OBJCOPY = $(TOOLCHAIN)/riscv32-unknown-elf-objcopy

CFLAGS = -march=rv32i -mabi=ilp32 -ffreestanding -nostdlib -nostartfiles -O2 -Wall -Wextra
LDFLAGS = -T linker.ld -nostdlib -Wl,--build-id=none

SRCS = start.S rtos.c test_rtos.c

all: rtos.elf rtos.bin rtos.hex

rtos.elf: $(SRCS) linker.ld
	$(CC) $(CFLAGS) -o $@ $(SRCS) $(LDFLAGS)

rtos.bin: rtos.elf
	$(OBJCOPY) -O binary $< $@

rtos.hex: rtos.bin elf2hex.py
	./elf2hex.py $< $@

rom.hex: rtos.hex
	cp $< ../rom.hex

clean:
	rm -f rtos.elf rtos.bin rtos.hex

.PHONY: all clean rom.hex
