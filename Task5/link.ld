OUTPUT_ARCH( "riscv" )

ENTRY(_start)

SECTIONS
{
  . = 0x80000000;
  
  .text.init : 
  { 
    *(.text.init) 
  }
  
  .tohost ALIGN (0x1000) : 
  { 
	  *(.tohost)
  }
  
  .text ALIGN (0x1000) : 
  {
	  *(.text)
    *(.test_text)
  }
  
  .data ALIGN (0x1000) : 
  {
	  *(.data)
    *(.page_table)
    *(.test_data)
  }

  .bss : 
  {
	  *(.bss)
  }

  _end = .;
}