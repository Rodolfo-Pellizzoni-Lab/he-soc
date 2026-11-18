// Accelerator socket: register access from software (see hardware/accel/README.md).
//   slot s registers: ACCEL_BASE(s) + offset (32-bit registers, 64 KB window per slot)
//   interrupt: PLIC ID 9 (all slots share it)
//   buffers the accelerator reads/writes: anywhere (DRAM included): the socket's memory port is a port of the
//   coherence unit, so the device sees the cores' dirty L1 lines and its writes invalidate the cores' copies.
//   ACCEL_BUF places a buffer in the on-chip SRAM (32 KB, uncached, shared with tohost) when a test wants it there.
//   Write the buffer, then `fence`, then START; read the result after DONE (software/soc_tests/t_dma measures this).
#ifndef ACCEL_H
#define ACCEL_H
#include "soc_test.h"

#define ACCEL_WINDOW     0x10000000UL
#define ACCEL_BASE(s)    (ACCEL_WINDOW + (unsigned long)(s) * 0x10000UL)
#define ACCEL_IRQ_ID     9
#define ACCEL_BUF        SOC_SRAM
// QoS tags ("I/O on behalf of an RCID", hardware/accel/README.md): an accelerator learns the requester's user
// field with every register access and tags its DMA (the template: with the hart that wrote START); the socket
// can force a tag per slot instead. SoC user layout (ariane_axi_soc, QosUserLsb = 3): port [2:0], RCID [6:3],
// MCID [10:7], AT [11]; the CCU writes the port bits.
// width of the source-port field at the bottom of the user word: clog2(NumCVA6 + 2), the cores plus the socket's and
// the Ethernet's DMA ports (3 bits up to 6 cores, 4 bits for 7 to 14); SOC_NUM_CORES (soc_test.h) or ACCEL_NUM_CORES
// selects it, default 4 cores
#ifndef ACCEL_NUM_CORES
#ifdef SOC_NUM_CORES
#define ACCEL_NUM_CORES SOC_NUM_CORES
#else
#define ACCEL_NUM_CORES 4
#endif
#endif
#define ACCEL_SRC_BITS ((ACCEL_NUM_CORES + 2) <= 2 ? 1 : (ACCEL_NUM_CORES + 2) <= 4 ? 2 : (ACCEL_NUM_CORES + 2) <= 8 ? 3 : \
                        (ACCEL_NUM_CORES + 2) <= 16 ? 4 : 5)
#define ACCEL_USER(port, rcid, mcid) ((uint32_t)(port) | ((uint32_t)(rcid) << ACCEL_SRC_BITS) | ((uint32_t)(mcid) << (ACCEL_SRC_BITS + 4)))
#define ACCEL_TAG_REG        0x28                                          // template: user field latched at START (R)
#define ACCEL_QOS_PROBE      (ACCEL_WINDOW + 0x3F0000UL)                   // returns the user field of the read itself
#define ACCEL_TAG_POLICY(s)  (ACCEL_WINDOW + 0x3F0100UL + (unsigned long)(s) * 8)   // RW: bit 31 FORCE, [11:0] tag ([12:0] at 8 cores)
#define ACCEL_LAST_USER(s)   (ACCEL_TAG_POLICY(s) + 4)                     // R: user field of the slot's last DMA request
#define ACCEL_POLICY_FORCE   0x80000000u
// Per-job and address-range tags (hardware/docs/qos.md "Device DMA"). The socket picks each DMA request's tag:
// FORCE -> the default (TAG_POLICY's tag); RANGE_EN and a range entry matches -> that entry's tag; the device tags
// per job (QOS_CAP.JOB) and DEV_OFF is clear -> the device's tag; otherwise the default.
#define ACCEL_POLICY_RANGE_EN 0x40000000u
#define ACCEL_POLICY_DEV_OFF  0x20000000u                                  // reads 1 when the device has no per-job tags
#define ACCEL_QOS_CAP(s)     (ACCEL_WINDOW + 0x3F0200UL + (unsigned long)(s) * 8)   // R: [0] JOB, [15:8] range entries
#define ACCEL_LAST_SRC(s)    (ACCEL_QOS_CAP(s) + 4)                        // R: rule of the last DMA request
#define ACCEL_SRC_DEV        0u                                            //   LAST_SRC [1:0]: the device's tag
#define ACCEL_SRC_RANGE      1u                                            //   a range entry's ([15:8] the entry)
#define ACCEL_SRC_FORCE      2u                                            //   FORCE
#define ACCEL_SRC_DEFAULT    3u                                            //   the default, no rule applied
#define ACCEL_RANGE(k)       (ACCEL_WINDOW + 0x3F1000UL + (unsigned long)(k) * 16)  // +0 BASE, +4 LIMIT (pages), +8 CFG
#define ACCEL_RANGE_V        0x80000000u
#define ACCEL_RANGE_SLOT(s)  (1u << (16 + (s)))
// range entry k: physical pages first..last (byte addresses, inclusive), for the slots in `slots`, tag `tag`
static inline void accel_range_set(int k, uint64_t first, uint64_t last, uint32_t slots, uint32_t tag) {
  REG32(ACCEL_RANGE(k) + 8) = 0;                       // invalid while it changes
  REG32(ACCEL_RANGE(k))     = (uint32_t)(first >> 12);
  REG32(ACCEL_RANGE(k) + 4) = (uint32_t)(last >> 12);
  REG32(ACCEL_RANGE(k) + 8) = ACCEL_RANGE_V | slots | tag;
}
// template accelerators: job queue. A job is a descriptor in memory; SUBMIT queues it with the tag of the SUBMIT
// write, and every DMA request of the job (descriptor read, data, completion write) carries that tag.
#define ACCEL_SUBMIT         0x40                                          // W: descriptor address >> 3
#define ACCEL_QSTAT          0x44                                          // R: [7:0] waiting, [15:8] depth, [16] OVF
#define ACCEL_QSTAT_OVF      0x10000u                                      // W1C
#define ACCEL_DROPPED        0x48                                          // R: SUBMITs dropped (queue full)
typedef struct {
  uint64_t src, dst;
  uint32_t len, arg;
  uint64_t cpl;                                                            // written by the accelerator
} accel_desc_t;
#define ACCEL_CPL_DONE       1u
#define ACCEL_CPL_ERR        2u
#define ACCEL_CPL_TAG(c)     ((uint32_t)((c) >> 16) & 0xFFFFu)
#define ACCEL_CPL_CYCLES(c)  ((uint32_t)((c) >> 32))

static inline void     accel_wr(int s, unsigned off, uint32_t v) { REG32(ACCEL_BASE(s) + off) = v; }
static inline uint32_t accel_rd(int s, unsigned off)             { return REG32(ACCEL_BASE(s) + off); }
// 64-bit value split over two consecutive registers (low word at off)
static inline void accel_wr64(int s, unsigned off, uint64_t v) {
  accel_wr(s, off, (uint32_t)v); accel_wr(s, off + 4, (uint32_t)(v >> 32));
}
// queue descriptor d on slot s. The fence makes the descriptor visible first. The tag is taken when the SUBMIT write
// leaves the core, so the read-back holds the caller until it has: srmcfg (or the privilege) can change after.
static inline uint32_t accel_submit(int s, volatile accel_desc_t *d) {
  __asm__ volatile("fence" ::: "memory");
  accel_wr(s, ACCEL_SUBMIT, (uint32_t)((uintptr_t)d >> 3));
  return accel_rd(s, ACCEL_QSTAT);
}
// poll until (reg & mask) == val; returns 0, or -1 after max_polls reads
static inline int accel_wait(int s, unsigned off, uint32_t mask, uint32_t val, unsigned long max_polls) {
  for (unsigned long i = 0; i < max_polls; i++) if ((accel_rd(s, off) & mask) == val) return 0;
  return -1;
}
// PLIC: route ACCEL_IRQ_ID to hart 0 machine mode (context 0) and read the pending bit
static inline void accel_plic_enable(void) {
  REG32(SOC_PLIC_BASE + ACCEL_IRQ_ID * 4) = 1;
  REG32(SOC_PLIC_BASE + 0x2000) |= 1u << ACCEL_IRQ_ID;
}
static inline int accel_plic_pending(void) { return (REG32(SOC_PLIC_BASE + 0x1000) >> ACCEL_IRQ_ID) & 1; }
static inline uint32_t accel_plic_claim(void) { return REG32(SOC_PLIC_BASE + 0x200004); }
static inline void accel_plic_complete(uint32_t id) { REG32(SOC_PLIC_BASE + 0x200004) = id; }
#endif
