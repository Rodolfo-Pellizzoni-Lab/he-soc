// APMU Ibex counter instructions (custom opcode 0x07) for the Ibex firmware.
// Include with -I$(SW_HOME)/inc/pmu. Addresses are in pmu_defines.h.
//
//   function           instruction  funct7 funct3  operation
//   cnt_rd(idx)        cnt.rd       0x00   000     return counter[idx]
//   cnt_rds(idx)       cnt.rds      0x01   000     return snapshot[idx]
//   cnt_wr(idx, val)   cnt.wr       -      001     counter[idx] = val
//   cnt_wfp(mask)      wfp          0x00   010     stall until a counter in mask is pending, return those counters
//   cnt_wfo(mask)      wfo          0x01   010     stall until a counter in mask overflows, return those counters
//   cnt_snap(mask)     cnt.snap     0x00   011     snapshot[j] = counter[j] for every bit j in mask, in one cycle
//
// cnt_rd and cnt_rds return bits 30:0. An index >= NUM_COUNTER reads 0 and writes nothing.
// The snapshot registers are only reachable by the Ibex and are cleared on reset.
#ifndef PMU_HW_DESC_H
#define PMU_HW_DESC_H
#include <stdint.h>

static inline uint32_t cnt_rd(uint32_t idx) {
  uint32_t v;
  __asm__ volatile(".insn r 0x07, 0, 0, %0, %1, x0" : "=r"(v) : "r"(idx));
  return v;
}

static inline void cnt_wr(uint32_t idx, uint32_t value) {
  __asm__ volatile(".insn s 0x07, 1, %1, 0(%0)" : : "r"(idx), "r"(value) : "memory");
}

static inline uint32_t cnt_rds(uint32_t idx) {
  uint32_t v;
  __asm__ volatile(".insn r 0x07, 0, 1, %0, %1, x0" : "=r"(v) : "r"(idx));
  return v;
}

static inline void cnt_snap(uint32_t mask) {
  __asm__ volatile(".insn r 0x07, 3, 0, x0, %0, x0" : : "r"(mask) : "memory");
}

static inline uint32_t cnt_wfp(uint32_t mask) {
  uint32_t woke;
  __asm__ volatile(".insn r 0x07, 2, 0, %0, %1, x0" : "=r"(woke) : "r"(mask));
  return woke;
}

static inline uint32_t cnt_wfo(uint32_t mask) {
  uint32_t woke;
  __asm__ volatile(".insn r 0x07, 2, 1, %0, %1, x0" : "=r"(woke) : "r"(mask));
  return woke;
}

#endif
