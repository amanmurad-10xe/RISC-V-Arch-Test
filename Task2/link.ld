OUTPUT_ARCH( "riscv" )

ENTRY(_start)

SECTIONS
{
  . = 0x80000000;

  .text.init : ALIGN(0x100)
  { 
      *(.text.init) 
  }
  
  .tohost : ALIGN(0x100)
  { 
      *(.tohost) 
  }

  .text : ALIGN(0x100)
  {
       *(.text) 
  }

  .data : ALIGN(0x100)
  { 
      *(.data) 
  }

  . = 0x80002000;
  .tor_region : ALIGN(0x1000)
  {
      *(.tor_region)
  }

  . = 0x80003000;
  .napot_region : ALIGN(0x1000)
  {
      *(.napot_region)
  }

  .bss : { *(.bss) }
  _end = .;
}