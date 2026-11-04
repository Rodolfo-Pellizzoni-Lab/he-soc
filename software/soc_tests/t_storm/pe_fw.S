// t_storm's program for the APMU's processing element (Ibex, rv32im), run from the ISPM (0x1042_7000). make pe_fw.h
// turns it into the words t_storm.c copies there. The host holds the PE, writes the parameters into the DSPM and
// releases it, which (re)starts this program at its first word; the parameters and results (DSPM_BASE_ADDR + ...):
//   0x000 ACK    the PE writes 1 once every EVU register of the list is written and read back
//   0x004 STOP   the host writes 1 once the traffic has drained
//   0x008 DONE   the PE writes 1 once it has disarmed the EVUs and taken the final sample
//   0x00C COUNT  samples taken so far
//   0x010 K      counters to sample, 0 .. K-1
//   0x014 T      cycles between samples (mcycle)
//   0x018 RING   samples the ring holds; sample n goes to slot n % RING
//   0x01C NEVU   number of (address, value) pairs at 0x040
//   0x020 MAGIC  the PE writes 0x5A5 when it starts
//   0x024 ERRS   EVU registers that did not read back what the PE wrote (set before ACK, and again before DONE)
//   0x040 the EVU list: (EVU register address, event ID) pairs; the PE writes the IDs, and 0 to the same registers
//         when STOP comes
//   0x200 the final sample, 0x400 the ring: one sample is mcycle, then counters 0 .. K-1 (cnt.rd: bits 30:0)
// Every access outside the DSPM goes to the EVU registers (the PE's window into the SoC): anything else would stall
// the PE for good.
  .equ DSPM, 0x10429000
  .text
  .globl _start
_start:
  lui   s0, %hi(DSPM)
  li    t0, 0x5A5
  sw    t0, 0x20(s0)          // MAGIC
  lw    s1, 0x10(s0)          // K
  lw    s2, 0x14(s0)          // T
  lw    s3, 0x18(s0)          // RING
  lw    s4, 0x1C(s0)          // NEVU
  li    s10, 0                // read-back mismatches
  addi  t1, s0, 0x40          // arm: every pair's ID into its register, then read it back (the write has landed)
  mv    t2, s4
1:
  beqz  t2, 2f
  lw    t3, 0(t1)
  lw    t4, 4(t1)
  sw    t4, 0(t3)
  lw    t5, 0(t3)
  beq   t5, t4, 10f
  addi  s10, s10, 1
10:
  addi  t1, t1, 8
  addi  t2, t2, -1
  j     1b
2:
  sw    s10, 0x24(s0)         // ERRS
  li    t0, 1
  sw    t0, 0(s0)             // ACK
  li    s5, 0                 // samples taken
  csrr  s6, mcycle            // when the last one was taken
  addi  s7, s0, 0x400         // the ring
  li    s8, 0                 // its next slot
  addi  s9, s1, 1
  slli  s9, s9, 2             // bytes per sample
3:
  lw    t0, 4(s0)             // STOP?
  bnez  t0, 5f
  csrr  t1, mcycle
  sub   t2, t1, s6
  bltu  t2, s2, 3b
  mv    s6, t1
  mul   t3, s8, s9
  add   t3, t3, s7            // the slot
  sw    t1, 0(t3)
  li    t4, 0
4:
  .insn r 0x07, 0, 0, t5, t4, x0   // cnt.rd t5, t4: t5 = counter t4
  slli  t6, t4, 2
  add   t6, t6, t3
  sw    t5, 4(t6)
  addi  t4, t4, 1
  bne   t4, s1, 4b
  addi  s5, s5, 1
  sw    s5, 0xC(s0)           // COUNT
  addi  s8, s8, 1
  bne   s8, s3, 3b
  li    s8, 0
  j     3b
5:
  addi  t1, s0, 0x40          // disarm: 0 into every register of the list, read back
  mv    t2, s4
6:
  beqz  t2, 7f
  lw    t3, 0(t1)
  sw    zero, 0(t3)
  lw    t5, 0(t3)
  beqz  t5, 11f
  addi  s10, s10, 1
11:
  addi  t1, t1, 8
  addi  t2, t2, -1
  j     6b
7:
  addi  t3, s0, 0x200         // the final sample
  csrr  t1, mcycle
  sw    t1, 0(t3)
  li    t4, 0
8:
  .insn r 0x07, 0, 0, t5, t4, x0
  slli  t6, t4, 2
  add   t6, t6, t3
  sw    t5, 4(t6)
  addi  t4, t4, 1
  bne   t4, s1, 8b
  sw    s10, 0x24(s0)         // ERRS
  li    t0, 1
  sw    t0, 8(s0)             // DONE
9:
  j     9b
