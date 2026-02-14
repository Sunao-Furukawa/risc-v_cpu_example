OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
  RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 16K
}

SECTIONS
{
  .text : {
    KEEP(*(.text.start))
    *(.text .text.*)
  } > RAM

  .rodata : {
    *(.rodata .rodata.*)
  } > RAM

  .data : {
    *(.data .data.*)
  } > RAM

  .bss : {
    _sbss = .;
    *(.bss .bss.* COMMON)
    _ebss = .;
  } > RAM

  . = ALIGN(16);
  _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
