/*======================================================================*/
/* Proxy kernel linker script                                           */
/*======================================================================*/
/* This is the linker script used when building the proxy kernel. */

/*----------------------------------------------------------------------*/
/* Setup                                                                */
/*----------------------------------------------------------------------*/

/* The OUTPUT_ARCH command specifies the machine architecture where the
   argument is one of the names used in the BFD library. More
   specifically one of the entires in bfd/cpu-mips.c
   See LICENSE for license details.
*/

OUTPUT_ARCH( "riscv" )
ENTRY(_start)

MEMORY
{
  L2      (rwx) : ORIGIN = 0x1C000000, LENGTH = 0x00008000
}

/*----------------------------------------------------------------------*/
/* Sections                                                             */
/*----------------------------------------------------------------------*/


SECTIONS
{

  /* text: for code & constants */
  . = 0x1C000000;
  .text.init : { *(.text.init) } > L2
  . = 0x1C000100;
  .nocache_share_region : { *(.nocache_share_region) } > L2
  . = ALIGN(0x1000);
  .tohost : { *(.tohost) } > L2

  .text : { *(.text) } > L2

  /* SPM DATA */
  .spm_data : { *(.heapl2ram) } > L2

  /* data: for initialized data */
  /*.data : { *(.data) } > L2*/

  .sdata : {
    __global_pointer$ = . + 0x800;
    *(.srodata.cst16) *(.srodata.cst8) *(.srodata.cst4) *(.srodata.cst2) *(.srodata*)
    *(.sdata .sdata.* .gnu.linkonce.s.*)
  } > L2

  /* Read Only Cluster Code */
  .rodata :  {
    *(.rodata);
    . = ALIGN(0x10);
    __cluster_code_start = . ;
    KEEP(*(.clusterraw*))
    __cluster_code_end = . ;
    } > L2

  /* bss: for uninitialized data, cleared by crt.S on hart 0 in board builds (_bss_start.._bss_end) */
  .sbss : {
    . = ALIGN(8);
    _bss_start = .;
    *(.sbss .sbss.* .gnu.linkonce.sb.*)
    *(.scommon)
  } > L2
  .bss : {
    *(.bss)
    . = ALIGN(8);
    _bss_end = .;
  } > L2

  /* thread-local data segment */
  .tdata :
  {
    _tls_data = .;
    *(.tdata.begin)
    *(.tdata)
    *(.tdata.end)
  } > L2
  .tbss :
  {
    *(.tbss)
    *(.tbss.end)
  } > L2

  /* stack: one 0x500-byte slice (stack + TLS) per hart, hart 0's at the top (crt.S) */
  __stack_size = 0x500;
  __stack_harts = 8;            /* enough for the eight-core SoC too; crt.S parks a hart without a slice */
  .stack :
  {
    . = ALIGN(16);
    . = . + __stack_harts * __stack_size;
    _stack = .;
  } > L2

  /* End of uninitalized data segement */
  _end = .;
    /* init table vector */
  .vectors :
    {
        . = ALIGN(4);
		_vectors_start = .;
        KEEP(*(.vectors))
		_vectors_end = .;
    } > L2
}
