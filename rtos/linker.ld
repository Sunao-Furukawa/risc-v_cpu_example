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
    *(.sdata .sdata.*)
  } > RAM

  /* start.S zeroes [_sbss, _ebss) a word at a time, so both bounds must be
     word aligned and the range must cover .sbss as well as .bss -- gcc puts
     small objects (g_ticks, the task counters) in .sbss. */
  .bss : {
    . = ALIGN(4);
    _sbss = .;
    *(.sbss .sbss.*)
    *(.bss .bss.* COMMON)
    . = ALIGN(4);
    _ebss = .;
  } > RAM

  . = ALIGN(16);
  _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
