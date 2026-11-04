#ifndef __PMU_HW_DESC_H__
#define __PMU_HW_DESC_H__

// Macros for custom PMU core instructions.
// Counter read: rd = cnt[rs1]
// #define counter_read(rd, rs1)       asm volatile ("cnt.rd\t%0,%1" : "=r" (rd) : "r" (rs1));
// // Counter write: cnt[rs1] = rs2
// #define counter_write(rs1, rs2)     asm volatile ("cnt.wr\t%0,%1" :: "r" (rs1), "r" (rs2));


// Macros for custom PMU core instructions.
// Counter read: rd = cnt[rs1]
// cnt.rd rd, counter_idx -> rd = counter[counter_idx]
#define counter_read(rd, rs1) \
    asm volatile (".insn r 0x07, 0x0, 0, %0, %1, x0" : "=r" (rd) : "r" (rs1))

// Counter write: cnt[counter_idx] = value
// cnt.wr counter_idx, value -> counter[counter_idx] = value
// Note: In .insn format, rs1=value, rs2=counter_idx (reversed from macro params)
#define counter_write(counter_idx, value) \
    asm volatile (".insn r 0x07, 0x1, 0, x0, %1, %0" : : "r" (counter_idx), "r" (value))

// #############################################################################
// Defines for PMU: the register map, the scratchpads, the event selects and the EVU registers are those of the
// CVA6 side (software/quad_boot/pmu_defines.h)
// #############################################################################
#include "../../../quad_boot/pmu_defines.h"

// #############################################################################

#endif