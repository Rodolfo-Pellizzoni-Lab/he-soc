// Two board experiments on the DRAM timing model behind the slowdown, with t_sweep's chain and chase (t_sweep.c,
// included as it is; its main is renamed and not called). On the 10-30 bitstreams t_sweep's 1 GHz curve lies only
// about 1 cycle per read above the model-off one although the model holds the average read back 17 cycles, and at
// 1152 and 1280 KB it lies below it (hardware/docs/dram_model.md):
//   A. Does the model's hold reach the core? The hold is the first beat's, but the LLC answers a refill only when
//      all 8 beats are in. At 2048 KB: the model-off chase twice, the 1 GHz settings, then those settings with
//      LAT_RD 1, 60, 100, 120 and 160. If a refill ends at max(the modelled last beat, the real last beat + 1),
//      LAT_RD 1 to 80 cost about the same and the time rises from the LAT_RD whose last beat comes after the real one.
//   B. Is the 1 GHz chase faster at 1152 and 1280 KB because it runs second, after the chain's first chase? At 1152,
//      1280 and 1536 KB: off, off again, 1 GHz, a pass that dirties every element again, off. The off chases run with
//      the model enabled at 0/0/0 (no hold, one cycle in its buffer), so that its counters count their DRAM traffic.
// One line per chase:
//   PROBE A <LAT_RD, or off> <cycles per read x100> <model reads> <late> <hold cycles> <read beats>
//   PROBE B <array KB> <step> <cycles per read x100> <model reads> <model writes>
// Print-only apart from one check (the model is present). Built without fpga=1 the arrays are small, for a quick
// run of the code in simulation.
#define main t_sweep_main
#include "../t_sweep/t_sweep.c"
#undef main

#define DM_WR_CNT  0x14
#define DM_RD_BEAT 0x28

#ifdef FPGA_EMULATION
#define KB_A 2048
static const uint32_t kb_b[] = {1152, 1280, 1536};
#else                           // a few ms of simulation: the code's run, not the measurement
#define KB_A 4
static const uint32_t kb_b[] = {2, 4};
#endif
static const uint32_t lat_rd_a[] = {1, 60, 100, 120, 160};

static void probe_a(uint32_t lat_rd, uint32_t n) {
  uint32_t c = chase_x100(BASE, n);
  uint32_t rd = REG32(DM + DM_RD_CNT), late = REG32(DM + DM_RD_LATE), hold = REG32(DM + DM_HOLD_CY);
  uint32_t beats = REG32(DM + DM_RD_BEAT);
  REG32(DM + DM_CTRL) = 0;
  printf("PROBE A %u %u %u %u %u %u\r\n", lat_rd, c, rd, late, hold, beats);
}

static void probe_b(uint32_t kb, const char *step, uint32_t n) {
  uint32_t c = chase_x100(BASE, n);
  uint32_t rd = REG32(DM + DM_RD_CNT), wr = REG32(DM + DM_WR_CNT);
  REG32(DM + DM_CTRL) = 0;
  printf("PROBE B %u %s %u %u %u\r\n", kb, step, c, rd, wr);
}

int main(void) {
  soc_test_begin("t_sweep_probe");
  int present = REG32(DM + DM_ID) == DM_ID_VAL;
  if (present) {
    REG32(DM + DM_CTRL) = 0;
    uint32_t n = KB_A * 1024 / ELEM;
    build(BASE, n);
    for (int k = 0; k < 2; k++) {
      REG32(DM + DM_CTRL) = 0;
      printf("PROBE A off %u\r\n", chase_x100(BASE, n));
    }
    dm_set(LAT_1G, LAT_1G, OCC16_1G);
    probe_a(LAT_1G, n);
    for (uint32_t i = 0; i < sizeof lat_rd_a / sizeof lat_rd_a[0]; i++) {
      dm_set(lat_rd_a[i], LAT_1G, OCC16_1G);
      probe_a(lat_rd_a[i], n);
    }
    REG32(DM + DM_CTRL) = 0;
    printf("PROBE A off %u\r\n", chase_x100(BASE, n));
    for (uint32_t s = 0; s < sizeof kb_b / sizeof kb_b[0]; s++) {
      uint32_t kb = kb_b[s], m = kb * 1024 / ELEM;
      build(BASE, m);
      dm_set(0, 0, 0);
      probe_b(kb, "off1", m);
      dm_set(0, 0, 0);
      probe_b(kb, "off2", m);
      dm_set(LAT_1G, LAT_1G, OCC16_1G);
      probe_b(kb, "1ghz", m);
      volatile uint64_t *a = (volatile uint64_t *)BASE;
      for (uint32_t i = 0; i < m; i++) a[i * 2] = a[i * 2];
      dm_set(0, 0, 0);
      probe_b(kb, "off3", m);
    }
    REG32(DM + DM_CTRL) = 0;
    REG32(DM + DM_LAT_RD) = 0; REG32(DM + DM_LAT_WR) = 0; REG32(DM + DM_OCC16) = 0;
  }
  CHECK(present, "DRAM timing model not present (ID 0x%x)", REG32(DM + DM_ID));
  return soc_test_end();
}
