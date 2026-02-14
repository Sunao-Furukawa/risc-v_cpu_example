.section .text.start
.globl _start
_start:
  la sp, _stack_top

  la t0, _sbss
  la t1, _ebss
  beq t0, t1, 2f
1:
  sw zero, 0(t0)
  addi t0, t0, 4
  blt t0, t1, 1b
2:
  call main
3:
  j 3b
