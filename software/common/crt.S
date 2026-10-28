# See LICENSE for license details.

#include "encoding.h"

#if __riscv_xlen == 64
# define LREG ld
# define SREG sd
# define REGBYTES 8
#else
# define LREG lw
# define SREG sw
# define REGBYTES 4
#endif

# define NB_CORES 2

default_exc_handler:
  jal x0, sleep_loop //exc handler

sleep_loop:
  wfi
  j sleep_loop

  .section ".text.init"
  .globl _start
_start:
  li  x1, 0
  li  x2, 0
  li  x3, 0
  li  x4, 0
  li  x5, 0
  li  x6, 0
  li  x7, 0
  li  x8, 0
  li  x9, 0
  li  x10,0
  li  x11,0
  li  x12,0
  li  x13,0
  li  x14,0
  li  x15,0
  li  x16,0
  li  x17,0
  li  x18,0
  li  x19,0
  li  x20,0
  li  x21,0
  li  x22,0
  li  x23,0
  li  x24,0
  li  x25,0
  li  x26,0
  li  x27,0
  li  x28,0
  li  x29,0
  li  x30,0
  li  x31,0

  // enable FPU and accelerator if present
  li t0, MSTATUS_FS | MSTATUS_XS
  csrs mstatus, t0

  // make sure XLEN agrees with compilation choice
  li t0, 1
  slli t0, t0, 31
#if __riscv_xlen == 64
  bgez t0, 1f
#else
  bltz t0, 1f
#endif
2:
  li a0, 1
  sw a0, tohost, t0
  j 2b
1:

#ifdef __riscv_flen
  // initialize FPU if we have one
  fssr    x0
  fmv.s.x f0, x0
  fmv.s.x f1, x0
  fmv.s.x f2, x0
  fmv.s.x f3, x0
  fmv.s.x f4, x0
  fmv.s.x f5, x0
  fmv.s.x f6, x0
  fmv.s.x f7, x0
  fmv.s.x f8, x0
  fmv.s.x f9, x0
  fmv.s.x f10,x0
  fmv.s.x f11,x0
  fmv.s.x f12,x0
  fmv.s.x f13,x0
  fmv.s.x f14,x0
  fmv.s.x f15,x0
  fmv.s.x f16,x0
  fmv.s.x f17,x0
  fmv.s.x f18,x0
  fmv.s.x f19,x0
  fmv.s.x f20,x0
  fmv.s.x f21,x0
  fmv.s.x f22,x0
  fmv.s.x f23,x0
  fmv.s.x f24,x0
  fmv.s.x f25,x0
  fmv.s.x f26,x0
  fmv.s.x f27,x0
  fmv.s.x f28,x0
  fmv.s.x f29,x0
  fmv.s.x f30,x0
  fmv.s.x f31,x0
1:
#endif

  // initialize global pointer
.option push
.option norelax
  la gp, __global_pointer$
.option pop

  // get core id
  csrr a0, mhartid
  li a1, NB_CORES

#ifdef FPGA_EMULATION
  // hart 0 clears .sbss/.bss before any C code runs: a debugger or loader writes only the sections with
  // contents, and DRAM holds garbage after programming. The other harts get here only once hart 0 has woken them.
  // Board builds only: the simulation's DRAM model reads zero where nothing was loaded, and clearing a big
  // .bss through the caches costs as much simulated time as a pass over it.
  bnez a0, 2f
  la t0, _bss_start
  la t1, _bss_end
1:
  bgeu t0, t1, 2f
  SREG x0, 0(t0)
  addi t0, t0, REGBYTES
  j 1b
2:
#endif

  // each hart has its own __stack_size bytes of .stack, hart 0's slice at the top: the stack grows down from
  // the top of the slice, the hart's TLS sits at its bottom. The linker script reserves __stack_harts slices
  // (where it does not set them: 4 slices, 8 KB each); a hart beyond them would get a stack below .stack, on
  // the program's data, so it parks here instead.
  .weak __stack_size, __stack_harts
  lui t0, %hi(__stack_harts)
  addi t0, t0, %lo(__stack_harts)
  bnez t0, 1f
  li t0, 4
1:
  bgeu a0, t0, 3f
  lui t0, %hi(__stack_size)
  addi t0, t0, %lo(__stack_size)
  bnez t0, 1f
  li t0, 0x2000
1:
  mul a2, a0, t0
  la  sp, _stack
  sub sp, sp, a2
  sub tp, sp, t0

  j _init

3:
  wfi
  j 3b

#ifdef FPGA_EMULATION
  // a linker script without _bss_start/_bss_end gets an empty range here: nothing is cleared
  .weak _bss_start, _bss_end
_bss_start:
_bss_end:
#endif

  .align 2

#ifdef CLUSTER_BIN
.section .clusterraw
.incbin CLUSTER_BIN_PATH
#endif

.section ".tdata.begin"
.globl _tdata_begin
_tdata_begin:

.section ".tdata.end"
.globl _tdata_end
_tdata_end:

.section ".tbss.end"
.globl _tbss_end
_tbss_end:

.section ".tohost","aw",@progbits
.align 6
.globl tohost
tohost: .dword 0
.align 6
.globl fromhost
fromhost: .dword 0

/* =================================================== [ exceptions ] === */
/* This section has to be down here, since we have to disable rvc for it  */

.section ".vectors", "ax"
.option norvc;

.org 0x00
.rept 10
jal x0, default_exc_handler
.endr

jal x0, default_exc_handler

jal x0, handle_trap

.org 0x30
.rept 18
jal x0, default_exc_handler
.endr
jal x0, default_exc_handler
jal x0, default_exc_handler
