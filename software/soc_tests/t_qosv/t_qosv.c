// QoS-ID privilege association and vRCID translation (hardware/docs/qos.md, "Privilege association and
// virtualized RCIDs"). Core 0 only. Every expected tag is read back through the QoS probe of the accelerator
// socket (0x103F_0000), which returns the AXI user field of the read that reaches it: {AT, MCID, RCID, source}.
//  - CSRs: reset values and WARL masks of mqosctl, mqosid, hqosid, sqosid, vsrmcfg, hqosctl, hrcidmap0/1
//  - privilege association: M mode -> mqosid (mqosctl[0]), HS -> hqosid ([1]), VS -> sqosid ([2]); a mode whose
//    bit is clear keeps srmcfg; loads under MPRV take the IDs of the effective privilege
//  - vRCID translation (hqosctl[0]): with it off, VS/VU accesses to srmcfg and sqosid raise a virtual-instruction
//    exception (Ssqosid); with it on, VS mode reads and writes its own copies (vsrmcfg, sqosid) without a trap,
//    and V=1 accesses carry the physical RCID hrcidmap gives the guest's RCID (the default RCID when the entry is
//    invalid); MCIDs pass through
//  - HLV from M mode (ld/st virtualization on) takes the VS IDs
#include "soc_test.h"

#define QOS_PROBE 0x103F0000UL
#define SRC_BITS  SOC_SRC_BITS

#define CSR_R(n)    ({ uint64_t _v; __asm__ volatile("csrr %0, " #n : "=r"(_v)); _v; })
#define CSR_W(n, x) __asm__ volatile("csrw " #n ", %0" :: "r"((uint64_t)(x)) : "memory")
// custom CSR numbers (riscv_pkg.sv)
#define SRMCFG    0x181
#define SQOSID    0x5C0
#define HQOSCTL   0x6C0
#define HRCIDMAP0 0x6C1
#define HRCIDMAP1 0x6C2
#define VSRMCFG   0x6C3
#define HQOSID    0x6C4
#define MQOSID    0x7C0
#define MQOSCTL   0x7C1
#define R_(n) CSR_R(n)
#define W_(n, x) CSR_W(n, x)

#define IDS(r, m) ((uint64_t)(r) | ((uint64_t)(m) << 16))

// ecall causes: 8 from U/VU, 9 from HS, 10 from VS, 11 from M; 22 virtual instruction; 2 illegal instruction
enum { C_U = 8, C_HS = 9, C_VS = 10, C_M = 11, C_ILL = 2, C_VIRT = 22 };

static int rbits = 4, mbits = 4;
static int popcount(uint64_t x) { int n = 0; while (x) { n += x & 1; x >>= 1; } return n; }

static void check_tag(const char *what, uint32_t u, uint64_t r, uint64_t m) {
  uint32_t src = u & ((1u << SRC_BITS) - 1);
  uint64_t ur  = (u >> SRC_BITS) & ((1u << rbits) - 1);
  uint64_t um  = (u >> (SRC_BITS + rbits)) & ((1u << mbits) - 1);
  uint32_t at  = (u >> (SRC_BITS + rbits + mbits)) & 1;
  CHECK(src == 0 && ur == r && um == m && at == 0, "%s: user 0x%x = src %d rcid %d mcid %d at %d, expected rcid %d mcid %d",
        what, u, src, (int)ur, (int)um, at, (int)r, (int)m);
}

// Runs, in privilege mode mpp (0 U, 1 S, 3 M) with virtualization mpv:
//   wsel 1: csrw srmcfg, wval    wsel 2: csrw sqosid, wval
//   lw from the QoS probe
//   rsel 1: csrr srmcfg          rsel 2: csrr sqosid
//   ecall
// Returns the mcause of the trap that ends it (an ecall cause when every step worked); *probe and *rd get the
// probe read and the CSR read (0xbad if not reached).
typedef struct { uint64_t cause, rd; uint32_t probe; } lower_t;
static lower_t lower(int mpp, int mpv, int wsel, uint64_t wval, int rsel) {
  uint64_t cause, rd, pr, old_mtvec;
  uint64_t clr = (3ULL << 11) | (1ULL << 39);
  uint64_t set = ((uint64_t)mpp << 11) | ((uint64_t)mpv << 39);
  __asm__ volatile(
      "csrr %[omt], mtvec\n"
      "la   t0, 1f\n"
      "csrw mtvec, t0\n"
      "csrc mstatus, %[clr]\n"
      "csrs mstatus, %[set]\n"
      "la   t0, 2f\n"
      "csrw mepc, t0\n"
      "li   t2, 0xbad\n"
      "li   t3, 0xbad\n"
      "mv   t4, %[ws]\n"
      "mv   t6, %[rs]\n"
      "mv   t1, %[wv]\n"
      "mv   t5, %[pa]\n"
      "mret\n"
      "2: li t0, 1\n"
      "bne  t4, t0, 3f\n"
      "csrw 0x181, t1\n"
      "3: li t0, 2\n"
      "bne  t4, t0, 4f\n"
      "csrw 0x5C0, t1\n"
      "4: lw t3, 0(t5)\n"
      "li   t0, 1\n"
      "bne  t6, t0, 5f\n"
      "csrr t2, 0x181\n"
      "5: li t0, 2\n"
      "bne  t6, t0, 6f\n"
      "csrr t2, 0x5C0\n"
      "6: ecall\n"
      ".align 2\n"
      "1: csrr %[c], mcause\n"
      "mv   %[v], t2\n"
      "mv   %[p], t3\n"
      "csrw mtvec, %[omt]\n"
      "csrc mstatus, %[clr]\n"
      : [c] "=&r"(cause), [v] "=&r"(rd), [p] "=&r"(pr), [omt] "=&r"(old_mtvec)
      : [clr] "r"(clr), [set] "r"(set), [ws] "r"((uint64_t)wsel), [wv] "r"(wval), [rs] "r"((uint64_t)rsel),
        [pa] "r"(QOS_PROBE)
      : "t0", "t1", "t2", "t3", "t4", "t5", "t6", "memory");
  lower_t r = {cause, rd, (uint32_t)pr};
  return r;
}

static uint32_t probe_m(void) { return REG32(QOS_PROBE); }

// csrr of CSR n in M mode; returns the mcause of the trap it raised, 0 if none (the CSR exists)
#define TRY_CSRR(n) ({ uint64_t _c, _o;                                                        \
  __asm__ volatile("csrr %[o], mtvec\n la t0, 1f\n csrw mtvec, t0\n li %[c], 0\n csrr t1, " #n "\n" \
                   "j 2f\n .align 2\n 1: csrr %[c], mcause\n la t0, 2f\n csrw mepc, t0\n mret\n"     \
                   "2: csrw mtvec, %[o]\n"                                                      \
                   : [c] "=&r"(_c), [o] "=&r"(_o) :: "t0", "t1", "memory");                      \
  _c; })

// load from the probe with MPRV=1 and MPP = mpp (V = mpv): the effective ld/st privilege
static uint32_t probe_mprv(int mpp, int mpv) {
  uint64_t clr = (3ULL << 11) | (1ULL << 39) | (1ULL << 17);
  uint64_t set = ((uint64_t)mpp << 11) | ((uint64_t)mpv << 39) | (1ULL << 17);
  uint64_t v;
  __asm__ volatile("csrc mstatus, %[clr]\n csrs mstatus, %[set]\n lw %[v], 0(%[pa])\n csrc mstatus, %[clr]\n"
                   : [v] "=&r"(v) : [clr] "r"(clr), [set] "r"(set), [pa] "r"(QOS_PROBE) : "memory");
  return (uint32_t)v;
}

// hlv.w t3, (t5) from M mode: a load with the VS ld/st privilege (hstatus.SPVP = 1: VS)
static uint32_t probe_hlv(void) {
#ifdef QOSV_NO_HLV
  return 0xFFFFFFFF;                      // the HLV steps are skipped (their check_tag calls fail visibly)
#endif
  uint64_t v;
  __asm__ volatile("csrs hstatus, %[spvp]\n mv t5, %[pa]\n .word 0x680F4E73\n mv %[v], t3\n csrc hstatus, %[spvp]\n"
                   : [v] "=&r"(v) : [pa] "r"(QOS_PROBE), [spvp] "r"(1ULL << 8) : "t3", "t5", "memory");
  return (uint32_t)v;
}

static void expect_lower(const char *what, lower_t l, uint64_t cause, uint64_t r, uint64_t m) {
  CHECK(l.cause == cause, "%s: mcause %d, expected %d", what, (int)l.cause, (int)cause);
  if (l.cause == cause && cause >= C_U && cause <= C_M) check_tag(what, l.probe, r, m);
}

int main(void) {
  soc_test_begin("t_qosv");
  uint64_t medeleg, hedeleg;
  __asm__ volatile("csrr %0, medeleg\n csrw medeleg, zero" : "=r"(medeleg));
  __asm__ volatile("csrr %0, hedeleg\n csrw hedeleg, zero" : "=r"(hedeleg));
  // the lower modes need a PMP entry (NAPOT, whole address space, RWX); hgatp / vsatp stay bare (reset)
  __asm__ volatile("csrw pmpaddr0, %0\n csrw pmpcfg0, %1" :: "r"(~0ULL), "r"(0x1FULL));

  // ---- 1. which features the build has (absent CSRs raise illegal instruction), reset values, WARL masks
  int pa = TRY_CSRR(0x7C1) == 0;          // privilege association (QOS_PRIV_ASSOC)
  int vr = TRY_CSRR(0x6C0) == 0;          // vRCID translation (QOS_NUM_VRCID > 0)
  printf("privilege association %s, vRCID translation %s\r\n", pa ? "present" : "absent", vr ? "present" : "absent");
  if (!pa) {
    uint64_t c0 = TRY_CSRR(0x7C1), c1 = TRY_CSRR(0x7C0), c2 = TRY_CSRR(0x6C4), c3 = TRY_CSRR(0x5C0);
    CHECK(c0 == C_ILL && c1 == C_ILL && c2 == C_ILL && c3 == C_ILL,
          "absent association CSRs: mcause mqosctl %d mqosid %d hqosid %d sqosid %d, expected 2", (int)c0, (int)c1,
          (int)c2, (int)c3);
  }
  if (!vr) {
    uint64_t c0 = TRY_CSRR(0x6C0), c1 = TRY_CSRR(0x6C1), c2 = TRY_CSRR(0x6C2), c3 = TRY_CSRR(0x6C3);
    CHECK(c0 == C_ILL && c1 == C_ILL && c2 == C_ILL && c3 == C_ILL,
          "absent translation CSRs: mcause hqosctl %d map0 %d map1 %d vsrmcfg %d, expected 2", (int)c0, (int)c1,
          (int)c2, (int)c3);
  }
  W_(0x181, ~0ULL);
  uint64_t warl = R_(0x181);
  rbits = popcount(warl & 0xFFF);
  mbits = popcount((warl >> 16) & 0xFFF);
  uint64_t rm = (1ULL << rbits) - 1, mm = (1ULL << mbits) - 1, idm = IDS(rm, mm);
  printf("RCID %d bits, MCID %d bits\r\n", rbits, mbits);
  int nv = 0;                             // vRCID table entries
  if (pa) {
    CHECK(R_(0x7C1) == 0 && R_(0x7C0) == 0 && R_(0x6C4) == 0 && R_(0x5C0) == 0,
          "reset: mqosctl %x mqosid %x hqosid %x sqosid %x", (unsigned)R_(0x7C1), (unsigned)R_(0x7C0),
          (unsigned)R_(0x6C4), (unsigned)R_(0x5C0));
    W_(0x7C0, ~0ULL); CHECK(R_(0x7C0) == idm, "mqosid WARL %08x%08x", H64(R_(0x7C0)));
    W_(0x6C4, ~0ULL); CHECK(R_(0x6C4) == idm, "hqosid WARL %08x%08x", H64(R_(0x6C4)));
    W_(0x5C0, ~0ULL); CHECK(R_(0x5C0) == idm, "sqosid WARL %08x%08x", H64(R_(0x5C0)));
    W_(0x7C1, ~0ULL); CHECK(R_(0x7C1) == 7, "mqosctl WARL %08x%08x", H64(R_(0x7C1)));
    W_(0x7C1, 0); W_(0x7C0, 0); W_(0x6C4, 0); W_(0x5C0, 0);
  }
  if (vr) {
    CHECK(R_(0x6C3) == 0 && R_(0x6C0) == 0 && R_(0x6C1) == 0 && R_(0x6C2) == 0,
          "reset: vsrmcfg %x hqosctl %x map0 %x map1 %x", (unsigned)R_(0x6C3), (unsigned)R_(0x6C0),
          (unsigned)R_(0x6C1), (unsigned)R_(0x6C2));
    W_(0x6C3, ~0ULL); CHECK(R_(0x6C3) == idm, "vsrmcfg WARL %08x%08x", H64(R_(0x6C3)));
    W_(0x6C0, ~0ULL); CHECK(R_(0x6C0) == (1 | (rm << 16)), "hqosctl WARL %08x%08x", H64(R_(0x6C0)));
    W_(0x6C1, ~0ULL); W_(0x6C2, ~0ULL);
    uint64_t m0 = R_(0x6C1), m1 = R_(0x6C2);
    // entries are filled from vRCID 0 up: each one reads back {V, all RCID bits}, the rest read zero
    for (int i = 0; i < 16; i++) {
      uint64_t b = ((i < 8 ? m0 : m1) >> (8 * (i % 8))) & 0xFF;
      if (b == (0x80 | rm) && nv == i) nv++;
      else CHECK(b == 0, "hrcidmap entry %d WARL 0x%x (entries so far %d)", i, (unsigned)b, nv);
    }
    CHECK(nv >= 1 && nv <= (1 << rbits), "vRCID table: %d entries", nv);
    printf("vRCID table: %d entries\r\n", nv);
    W_(0x6C0, 0); W_(0x6C1, 0); W_(0x6C2, 0); W_(0x6C3, 0);
  }

  // ---- 2. no association: every mode carries srmcfg
  W_(0x181, IDS(1, 2));
  check_tag("M, association off", probe_m(), 1, 2);
  expect_lower("HS, association off", lower(1, 0, 0, 0, 1), C_HS, 1, 2);
  expect_lower("U, association off", lower(0, 0, 0, 0, 0), C_U, 1, 2);
  expect_lower("VS, association off", lower(1, 1, 0, 0, 0), C_VS, 1, 2);
  expect_lower("VU, association off", lower(0, 1, 0, 0, 0), C_U, 1, 2);

  if (pa) {
  // ---- 3. M association
  W_(0x7C0, IDS(3, 4));
  check_tag("M, mqosctl=0 (mqosid set)", probe_m(), 1, 2);
  W_(0x7C1, 1);
  check_tag("M, mqosctl=M", probe_m(), 3, 4);
  expect_lower("HS, mqosctl=M", lower(1, 0, 0, 0, 0), C_HS, 1, 2);
  expect_lower("U, mqosctl=M", lower(0, 0, 0, 0, 0), C_U, 1, 2);

  // ---- 4. HS association (+ MPRV: loads take the effective privilege's IDs)
  W_(0x6C4, IDS(5, 6));
  W_(0x7C1, 3);
  check_tag("M, mqosctl=M|HS", probe_m(), 3, 4);
  expect_lower("HS, mqosctl=M|HS", lower(1, 0, 0, 0, 0), C_HS, 5, 6);
  expect_lower("U, mqosctl=M|HS", lower(0, 0, 0, 0, 0), C_U, 1, 2);
  expect_lower("VS, mqosctl=M|HS", lower(1, 1, 0, 0, 0), C_VS, 1, 2);
  check_tag("M with MPRV, MPP=S", probe_mprv(1, 0), 5, 6);
  check_tag("M with MPRV, MPP=U", probe_mprv(0, 0), 1, 2);
  check_tag("M after MPRV", probe_m(), 3, 4);
  W_(0x7C1, 2);
  check_tag("M, mqosctl=HS", probe_m(), 1, 2);
  W_(0x7C1, 3);

  // ---- 5. VS association without translation: sqosid is set by the hypervisor (physical IDs); the guest
  //         cannot reach srmcfg or sqosid
  W_(0x5C0, IDS(7, 8));
  W_(0x7C1, 7);
  expect_lower("VS, mqosctl=M|HS|VS", lower(1, 1, 0, 0, 0), C_VS, 7, 8);
  expect_lower("VU, mqosctl=M|HS|VS", lower(0, 1, 0, 0, 0), C_U, 1, 2);
  expect_lower("HS, mqosctl=M|HS|VS", lower(1, 0, 0, 0, 0), C_HS, 5, 6);
  check_tag("HLV, VS association, no translation", probe_hlv(), 7, 8);
  expect_lower("VS writes srmcfg, translation off", lower(1, 1, 1, IDS(1, 1), 0), C_VIRT, 0, 0);
  expect_lower("VS reads srmcfg, translation off", lower(1, 1, 0, 0, 1), C_VIRT, 0, 0);
  expect_lower("VS writes sqosid, translation off", lower(1, 1, 2, IDS(1, 1), 0), C_VIRT, 0, 0);
  expect_lower("VS reads sqosid, translation off", lower(1, 1, 0, 0, 2), C_VIRT, 0, 0);
  expect_lower("U reads sqosid", lower(0, 0, 0, 0, 2), C_ILL, 0, 0);
  CHECK(R_(0x5C0) == IDS(7, 8) && R_(0x181) == IDS(1, 2), "after trapped guest writes: sqosid %08x%08x srmcfg %08x%08x",
        H64(R_(0x5C0)), H64(R_(0x181)));

  }

  // ---- 6. vRCID translation. Map: va -> 9, vc -> 11, vb (the last entry: in the second map CSR with more than
  //         8 entries) -> 12; vinv unmapped (or beyond the table) -> default RCID 14. Defaults: 2, 5, 15, 3.
  if (vr) {
    int va = nv > 2 ? 2 : 0, vc = nv > 5 ? 5 : va, vb = nv - 1;
    int vinv = nv < (1 << rbits) ? nv : 3;            // beyond the table, or an unmapped entry
    uint64_t pa_ = 9 & rm, pc = 11 & rm, pb = 12 & rm, def = 14 & rm;
    uint64_t map[2] = {0, 0};
    int ent[3] = {va, vc, vb}; uint64_t phys[3] = {pa_, pc, pb};
    for (int i = 0; i < 3; i++) map[ent[i] / 8] |= (0x80ULL | phys[i]) << (8 * (ent[i] % 8));
    W_(0x6C1, map[0]);
    W_(0x6C2, map[1]);
    uint64_t em_r = pa ? 3 : 1, em_m = pa ? 4 : 2, eh_r = pa ? 5 : 1, eh_m = pa ? 6 : 2;
    W_(0x6C3, IDS(va, 5));                // the guest's srmcfg, as a hypervisor would restore it
    W_(0x6C0, 1 | (def << 16));
    if (pa) W_(0x7C1, 3);                 // VS association off: V=1 accesses carry vsrmcfg
    expect_lower("VS, vsrmcfg vRCID va", lower(1, 1, 0, 0, 1), C_VS, pa_, 5);
    lower_t l = lower(1, 1, 0, 0, 1);
    CHECK(l.rd == IDS(va, 5), "VS reads srmcfg (translation on): %08x%08x, expected the virtual %08x%08x", H64(l.rd),
          H64(IDS(va, 5)));
    expect_lower("VU, vsrmcfg vRCID va", lower(0, 1, 0, 0, 0), C_U, pa_, 5);
    l = lower(1, 1, 1, IDS(vc, 1), 1);    // the guest writes its srmcfg: no trap
    expect_lower("VS writes srmcfg vRCID vc", l, C_VS, vc == va ? pa_ : pc, 1);
    CHECK(l.rd == IDS(vc, 1), "VS reads back srmcfg: %08x%08x", H64(l.rd));
    CHECK(R_(0x6C3) == IDS(vc, 1) && R_(0x181) == IDS(1, 2), "guest srmcfg write: vsrmcfg %08x%08x (expected %d/1), "
          "host srmcfg %08x%08x (expected 1/2)", H64(R_(0x6C3)), vc, H64(R_(0x181)));
    expect_lower("VS writes srmcfg vRCID vb (last entry)", lower(1, 1, 1, IDS(vb, 1), 0), C_VS, pb, 1);
    expect_lower("VS writes srmcfg vRCID vinv (unmapped)", lower(1, 1, 1, IDS(vinv, 4), 0), C_VS, def, 4);
    expect_lower("VU, vsrmcfg vRCID vinv", lower(0, 1, 0, 0, 0), C_U, def, 4);
    expect_lower("HS, translation on", lower(1, 0, 0, 0, 0), C_HS, eh_r, eh_m);
    expect_lower("U, translation on", lower(0, 0, 0, 0, 0), C_U, 1, 2);
    check_tag("M, translation on", probe_m(), em_r, em_m);
    check_tag("HLV, translation on, vsrmcfg", probe_hlv(), def, 4);
    if (pa) {
      // VS association on, guest-owned sqosid (translated); VU keeps vsrmcfg
      W_(0x7C1, 7);
      l = lower(1, 1, 2, IDS(va, 7), 2);  // the guest writes its sqosid: no trap
      expect_lower("VS writes sqosid vRCID va", l, C_VS, pa_, 7);
      CHECK(l.rd == IDS(va, 7) && R_(0x5C0) == IDS(va, 7), "VS reads back sqosid %08x%08x, M reads %08x%08x",
            H64(l.rd), H64(R_(0x5C0)));
      expect_lower("VU with VS association on", lower(0, 1, 0, 0, 0), C_U, def, 4);
      check_tag("HLV, VS association, translated", probe_hlv(), pa_, 7);
      check_tag("M with MPRV, MPP=S, MPV=1", probe_mprv(1, 1), pa_, 7);
      // a map change applies to the next access
      map[va / 8] = (map[va / 8] & ~(0xFFULL << (8 * (va % 8)))) | ((0x80ULL | (6 & rm)) << (8 * (va % 8)));
      if (va < 8) W_(0x6C1, map[0]); else W_(0x6C2, map[1]);
      expect_lower("VS after remapping vRCID va -> 6", lower(1, 1, 0, 0, 0), C_VS, 6 & rm, 7);
      // translation off again: the guest traps, sqosid is used as physical
      W_(0x6C0, 0);
      expect_lower("VS writes srmcfg, translation off again", lower(1, 1, 1, IDS(1, 1), 0), C_VIRT, 0, 0);
      expect_lower("VS, translation off: sqosid physical", lower(1, 1, 0, 0, 0), C_VS, va, 7);
      W_(0x7C1, 3);
    } else {
      W_(0x6C0, 0);
      expect_lower("VS writes srmcfg, translation off again", lower(1, 1, 1, IDS(1, 1), 0), C_VIRT, 0, 0);
    }
    expect_lower("VU, translation off: srmcfg", lower(0, 1, 0, 0, 0), C_U, 1, 2);
    W_(0x6C1, 0); W_(0x6C2, 0); W_(0x6C3, 0);
  }

  // ---- 7. everything off: srmcfg again
  if (pa) { W_(0x7C1, 0); W_(0x7C0, 0); W_(0x6C4, 0); W_(0x5C0, 0); }
  check_tag("M, all off", probe_m(), 1, 2);
  W_(0x181, 0);
  __asm__ volatile("csrw medeleg, %0\n csrw hedeleg, %1" :: "r"(medeleg), "r"(hedeleg));
  return soc_test_end();
}
