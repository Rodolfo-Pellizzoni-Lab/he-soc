/* MIT License

Copyright (c) 2024 Abdur Rahman

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

OUTPUT_ARCH(riscv)


/* Stack information variables */

STACK_SIZE      = 0x300;

ENTRY(_start)

/* Memory regions for Instruction and Data Memories */
MEMORY
{
    ISPM (rx) : ORIGIN = 0x10427000, LENGTH = 0x1000
    DSPM (rw) : ORIGIN = 0x10428200, LENGTH = 0x600
}

SECTIONS
{
    .text : {
        . = ALIGN(4);

        *(.text)
        *(.text.*)
        . = ALIGN(4);
    } > ISPM

    .rodata : {
        . = ALIGN(4);
        /* Small RO data before large RO data */
        *(.srodata)
        *(.srodata.*)
        *(.rodata);
        *(.rodata.*)
        . = ALIGN(4);
    } > DSPM

    .data : {
        . = ALIGN(4);
        _sidata = LOADADDR(.data);
        _sdata = .;

        /* Small data before large data */
        *(.sdata)
        *(.sdata.*)
        *(.data);
        *(.data.*)
        . = ALIGN(4);
        _edata = .;
    } > DSPM

    .bss :
    {
        . = ALIGN(4);
        _bss_start = .;
        /* Small BSS before large BSS */
        *(.sbss)
        *(.sbss.*)
        *(.bss)
        *(.bss.*)
        *(COMMON)
        _bss_end = .;
        . = ALIGN(4);
    } > DSPM


    .stack (NOLOAD) : {
        . = ALIGN(4);              
        _stack_start = .;           
        . += STACK_SIZE;            
        _stack_end = .;            
    } > DSPM
}