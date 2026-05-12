OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
  IMEM (rx) : ORIGIN = 0x00000000, LENGTH = 16K
}

SECTIONS
{
  . = ORIGIN(IMEM);

  .text : {
    *(.text.start)
    *(.text)
    *(.text.*)
  } > IMEM

  .rodata : {
    *(.rodata)
    *(.rodata.*)
  } > IMEM
}