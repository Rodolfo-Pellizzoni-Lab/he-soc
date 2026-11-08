// t_iopmp: the IOPMP in front of the APMU (hardware/host/host_domain.sv, i_riscv_iopmp). Whatever the APMU's processing
// element (PE) sends to the SoC passes through it on the way to the crossbar, and the only thing the PE can send there
// is a load or store of the EVU registers (hardware/ip_list/apmu/src/pmu_core.sv, MEMORY_BASE_ADDR). So the PE makes
// those accesses, on command from core 0 through a mailbox in the DSPM (inside the APMU, so not behind the IOPMP). Core
// 0 programs the IOPMP (registers at IOPMP_BASE_ADDR, ariane_soc::IOPMP_PMUBase) and reads the EVU registers itself,
// which does not go through the IOPMP either, so it sees what the PE's stores really did.
//   A. the IOPMP answers with its size (16 memory domains, 32 entries, 4 of them with priority, one source) and is off
//      after a reset. It cannot be turned off again without a reset: a run that finds it on says so and skips B.
//   B. off: the PE's store lands and its load gets the register's value, and nothing is recorded
//   C. on, an entry allowing reads and writes of the EVU registers' page: the same
//   D. that entry read-only: the store does not land and the load works; write-only: the load faults in the PE and
//      gets no data, and the store lands
//   E. an entry for another page only: neither gets through (error "no entry hit")
//   F. a 16-byte NAPOT entry: only addresses inside it get through. The AXI-Lite bridge in front of the IOPMP labels
//      every access with the full bus size, 8 bytes, whatever the PE's strobes say, so the IOPMP checks 8 bytes from the
//      address: a word at +0x8 of the entry gets through and the word at +0xC, inside the entry too, does not. A rule
//      has to cover 8 bytes from the address of every word it allows.
//   G. a TOR entry (the previous entry's address gives its base): its top and its base are both checked
//   H. entries below HWCFG2.prio_entry stop the search at the first entry that matches, allowed or not; later entries
//      that match without permission do not, and the search goes on
//   I. the source's domains: an entry counts only if SRCMD selects its domain, the search walks the selected domains in
//      order, and with no domain selected nothing gets through
//   J. the interrupt (PLIC source IOPMP_PLIC_ID): only with ERRREACT.ie and the bit for the access's direction, until
//      the record is cleared
//   K. an entry allowing everything: the PE's accesses work again after all those denials. The test leaves it like
//      this (and the PE held), so that APMU firmware that runs after it without a reset still gets through.
// Each denial must leave a record: direction, error, address, source and entry; the record is checked and cleared.
// Not covered: the lock bits (only a reset undoes them).
#include "soc_test.h"
#include "iopmp.h"

#define IOPMP(off)      REG32(IOPMP_REG_ADDR(off))
#define HWCFG0_ENABLE   0x80000000u      // write 1 to set (hardware/ip_list/riscv-iopmp: rv_iopmp_regmap.sv)
#define HWCFG0_TOR_EN   0x00000010u
#define HWCFG0_MD_NUM(v)    (((v) >> 24) & 0x7F)
#define HWCFG1_SID_NUM(v)   ((v) & 0xFFFF)
#define HWCFG1_ENTRY_NUM(v) ((v) >> 16)
#define HWCFG2_PRIO(v)      ((v) & 0xFFFF)
#define ENTRY_OFFSET    0x2000           // what the register at IOPMP_ENTRY_OFFSET_OFFSET reads
#define ERRREACT_IE     (1u << 1)
#define ERRREACT_IRE    (1u << 4)
#define ERRREACT_IWE    (1u << 8)
#define PE_SID          1                // the source the PE's accesses carry (host_domain: nsaid)
#define ANY_EID         0xFFFFFFFFu      // for expect_err: an error without a meaningful entry
#define IOPMP_PLIC_ID   14               // ariane_peripherals.sv: irq_sources[13], and the PLIC counts sources from 1
#define PLIC_CLAIM      (SOC_PLIC_BASE + 0x200004)   // hart 0's M-mode context, as PLIC_EN and PLIC_PRIO
#define PLIC_EN         (SOC_PLIC_BASE + 0x2000)
#define PLIC_PRIO       (SOC_PLIC_BASE + 4 * IOPMP_PLIC_ID)
#define IRQ_CYCLES      2000             // bound on the wait for the interrupt
#define PE_CYCLES       100000ULL        // bound on the wait for the PE

// core 0's EVU registers (t_evu): the PC milestones are plain storage, and no event ID selects them here
#define EVU_PAGE_SIZE   0x1000
#define OTHER_PAGE      0x1C000000u      // the on-chip SRAM, just an address the PE does not use
#define REG_A           EVU_PC_REG(0, 0)         // EVU_BASE_ADDR + 0x10
#define REG_A8          EVU_PC_REG(0, 1)         // + 0x18
#define REG_AC          (EVU_PC_REG(0, 1) + 4)   // + 0x1C
#define REG_B           EVU_PC_REG(0, 2)         // + 0x20
#define REG_LOW         EVU_EID_REG(0, 2)        // + 0x4, below REG_A
#define EVU_WORDS       12

#define NAPOT(base, size)  (((uint32_t)(base) >> 2) | ((size) / 8 - 1))   // the entry address of a 2^k-byte region
#define READ_ONLY       (ACCESS_READ)
#define WRITE_ONLY      (ACCESS_WRITE)
#define READ_WRITE      (ACCESS_READ | ACCESS_WRITE)
#define NUM_RULES       6                // the entries used here: each phase turns them off first

// The mailbox, at DSPM_BASE_ADDR: core 0 writes the address and the data and then the command, the PE clears the
// command and counts it in MB_SEQ once it has finished (its store's response has come back). Waiting for MB_SEQ, not
// for the command to clear, also holds if core 0's read overtakes its own write of the command.
#define MB_CMD          (DSPM_BASE_ADDR + 0x00)
#define MB_ADDR         (DSPM_BASE_ADDR + 0x04)
#define MB_DATA         (DSPM_BASE_ADDR + 0x08)
#define MB_RES          (DSPM_BASE_ADDR + 0x0C)  // what the last load got, 0 if it faulted
#define MB_TRAPS        (DSPM_BASE_ADDR + 0x10)  // the PE's exceptions: how many, the last one's cause and pc
#define MB_CAUSE        (DSPM_BASE_ADDR + 0x14)
#define MB_EPC          (DSPM_BASE_ADDR + 0x18)
#define MB_SEQ          (DSPM_BASE_ADDR + 0x1C)
#define MB_WORDS        8
#define CMD_STORE       1
#define CMD_LOAD        2
#define PE_STORE_AT     0x28
#define PE_LOAD_AT      0x34
#define PE_TRAP_AT      0x100            // mtvec's base has its low 8 bits clear on this Ibex (ibex_cs_registers.sv)
#define CAUSE_LOAD_FAULT  5

// The PE's program (rv32i) at its boot address (this Ibex starts at boot_addr itself, not at +0x80)
static const uint32_t pe_prog[] = {
  0x104290B7,                      //    lui  x1, 0x10429      the mailbox (DSPM_BASE_ADDR)
  0x10427137,                      //    lui  x2, 0x10427      this program (ISPM_BASE_ADDR)
  0x10010113,                      //    addi x2, x2, 0x100    its trap handler (PE_TRAP_AT)
  0x30511073,                      //    csrw mtvec, x2
  0x0000A183,                      // 1: lw   x3, 0(x1)        MB_CMD
  0xFE018EE3,                      //    beq  x3, x0, 1b
  0x0040A203,                      //    lw   x4, 4(x1)        MB_ADDR
  0x0080A283,                      //    lw   x5, 8(x1)        MB_DATA
  0x00100313,                      //    addi x6, x0, 1        CMD_STORE
  0x00619663,                      //    bne  x3, x6, 2f
  0x00522023,                      //    sw   x5, 0(x4)        the store (PE_STORE_AT)
  0x0100006F,                      //    j    3f
  0x00000393,                      // 2: li   x7, 0
  0x00022383,                      //    lw   x7, 0(x4)        the load (PE_LOAD_AT); a fault leaves x7 at 0
  0x0070A623,                      //    sw   x7, 12(x1)       MB_RES
  0x0000A023,                      // 3: sw   x0, 0(x1)        MB_CMD
  0x01C0A483,                      //    lw   x9, 28(x1)       MB_SEQ
  0x00148493,                      //    addi x9, x9, 1
  0x0090AE23,                      //    sw   x9, 28(x1)
  0xFC5FF06F,                      //    j    1b
  [PE_TRAP_AT / 4] =
  0x0100A403,                      //    lw   x8, 16(x1)       MB_TRAPS
  0x00140413,                      //    addi x8, x8, 1
  0x0080A823,                      //    sw   x8, 16(x1)
  0x34202473,                      //    csrr x8, mcause
  0x0080AA23,                      //    sw   x8, 20(x1)       MB_CAUSE
  0x34102473,                      //    csrr x8, mepc
  0x0080AC23,                      //    sw   x8, 24(x1)       MB_EPC
  0x00440413,                      //    addi x8, x8, 4        go on after the access
  0x34141073,                      //    csrw mepc, x8
  0x30200073,                      //    mret
};
_Static_assert(DSPM_BASE_ADDR == 0x10429000 && ISPM_BASE_ADDR == 0x10427000, "t_iopmp: the PE program's constants");

static uint32_t stamp;               // for a new value in every store
static uint32_t last_store_traps;    // the PE's exceptions in the last pe_store
static uint32_t denied_stores, denied_store_traps;

static uint32_t next_value(void) { return 0x5A000000u | ++stamp; }

// the PE makes one access and has finished it on return; a PE that does not answer ends the test
static void pe_cmd(uint32_t cmd, uint32_t addr, uint32_t data) {
  const uint32_t seq = REG32(MB_SEQ);
  REG32(MB_ADDR) = addr;
  REG32(MB_DATA) = data;
  REG32(MB_CMD) = cmd;
  __asm__ volatile("fence" ::: "memory");
  const uint64_t t0 = soc_cycles();
  while (REG32(MB_SEQ) == seq) {
    if (soc_cycles() - t0 > PE_CYCLES) {
      CHECK(0, "the PE did not finish command %u at 0x%08x (traps %u, cause %u, pc 0x%08x)", cmd, addr, REG32(MB_TRAPS),
            REG32(MB_CAUSE), REG32(MB_EPC));
      exit(soc_test_end());
    }
  }
}

// the PE stores a new value at addr: 1 if it landed there, 0 if the register kept its value
static int pe_store(uint32_t addr) {
  const uint32_t before = REG32(addr), v = next_value(), traps = REG32(MB_TRAPS);
  pe_cmd(CMD_STORE, addr, v);
  const uint32_t after = REG32(addr);
  last_store_traps = REG32(MB_TRAPS) - traps;
  CHECK(after == v || after == before, "the PE's store to 0x%08x of 0x%08x: the register went from 0x%08x to 0x%08x", addr,
        v, before, after);
  return after == v;
}

// the PE loads from addr, which core 0 sets to a new value first: 1 if it got the value, 0 if the load faulted
static int pe_load(uint32_t addr) {
  const uint32_t v = next_value(), traps = REG32(MB_TRAPS);
  REG32(addr) = v;
  __asm__ volatile("fence" ::: "memory");
  (void)REG32(addr);
  pe_cmd(CMD_LOAD, addr, 0);
  const uint32_t res = REG32(MB_RES), t = REG32(MB_TRAPS) - traps;
  if (t == 0) {
    CHECK(res == v, "the PE's load from 0x%08x got 0x%08x, not 0x%08x", addr, res, v);
    return 1;
  }
  CHECK(t == 1 && REG32(MB_CAUSE) == CAUSE_LOAD_FAULT && REG32(MB_EPC) == ISPM_BASE_ADDR + PE_LOAD_AT && res == 0,
        "the PE's load from 0x%08x: %u traps, cause %u, pc 0x%08x, data 0x%08x", addr, t, REG32(MB_CAUSE), REG32(MB_EPC),
        res);
  return 0;
}

static void expect_no_record(const char *what) {
  const uint32_t info = IOPMP(IOPMP_ERR_REQINFO_OFFSET);
  CHECK(!REQ_INFO_IP_MASK(info), "%s: an error is recorded (info 0x%x, address 0x%08x)", what, info,
        IOPMP(IOPMP_ERR_REQADDR_OFFSET));
}

// the IOPMP's record of the denied access: checked, then cleared
static void expect_record(const char *what, uint32_t addr, uint32_t ttype, uint32_t etype, uint32_t eid) {
  const uint32_t info = IOPMP(IOPMP_ERR_REQINFO_OFFSET), id = IOPMP(IOPMP_ERR_REQID_OFFSET);
  const uint32_t a = IOPMP(IOPMP_ERR_REQADDR_OFFSET), ah = IOPMP(IOPMP_ERR_REQADDRH_OFFSET);
  CHECK(REQ_INFO_IP_MASK(info) && REQ_INFO_TTYPE_MASK(info) == ttype && REQ_INFO_ETYPE_MASK(info) == etype && a == addr &&
        ah == 0 && REQ_ID_SID(id) == PE_SID && (eid == ANY_EID || REQ_ID_EID(id) == eid),
        "%s: record info 0x%x id 0x%x addr 0x%08x%08x, expected direction %u error %u source %u entry %d addr 0x%08x", what,
        info, id, ah, a, ttype, etype, PE_SID, (int)eid, addr);
  IOPMP(IOPMP_ERR_REQINFO_OFFSET) = 1;       // write 1 to clear
  CHECK(!REQ_INFO_IP_MASK(IOPMP(IOPMP_ERR_REQINFO_OFFSET)), "%s: the record did not clear", what);
}

static void expect_allowed(const char *what, uint32_t addr) {
  CHECK(pe_store(addr), "%s: the PE's store to 0x%08x did not land", what, addr);
  CHECK(last_store_traps == 0, "%s: the PE's store to 0x%08x landed and trapped too, cause %u", what, addr,
        REG32(MB_CAUSE));
  CHECK(pe_load(addr), "%s: the PE's load from 0x%08x faulted", what, addr);
  expect_no_record(what);
}

static void expect_store_denied(const char *what, uint32_t addr, uint32_t etype, uint32_t eid) {
  CHECK(!pe_store(addr), "%s: the PE's store to 0x%08x landed", what, addr);
  denied_stores++;
  denied_store_traps += last_store_traps;
  expect_record(what, addr, ACCESS_WRITE, etype, eid);
}

static void expect_load_denied(const char *what, uint32_t addr, uint32_t etype, uint32_t eid) {
  CHECK(!pe_load(addr), "%s: the PE's load from 0x%08x did not fault", what, addr);
  expect_record(what, addr, ACCESS_READ, etype, eid);
}

// entry n: its address in the PMP encoding and its configuration (mode and permissions)
static void rule(int n, uint32_t addr, uint32_t cfg) {
  REG32(IOPMP_REG_ADDR(IOPMP_ENTRY_ADDR_OFFSET) + 16 * n) = addr;
  REG32(IOPMP_REG_ADDR(IOPMP_ENTRY_ADDRH_OFFSET) + 16 * n) = 0;
  REG32(IOPMP_REG_ADDR(IOPMP_ENTRY_CFG_OFFSET) + 16 * n) = cfg;
}

static void rules_off(void) {
  for (int n = 0; n < NUM_RULES; n++) rule(n, 0, MODE_OFF);
}

// domain 0 holds the entries below top0, domain 1 those from top0 to below top1; mds: the domains the source may use
static void domains(uint32_t mds, uint32_t top0, uint32_t top1) {
  IOPMP(IOPMP_MDCFG_OFFSET) = top0;
  IOPMP(IOPMP_MDCFG_OFFSET + 4) = top1;
  IOPMP(IOPMP_SRCMD_EN_OFFSET) = mds << 1;   // bit 0 is the lock
  (void)IOPMP(IOPMP_SRCMD_EN_OFFSET);        // they have landed before the next access of the PE
  __asm__ volatile("fence" ::: "memory");
}

// a claim of hart 0's M-mode context within IRQ_CYCLES; 0 if none came
static uint32_t plic_claim(void) {
  const uint64_t t0 = soc_cycles();
  uint32_t id = 0;
  while (!(id = REG32(PLIC_CLAIM)) && soc_cycles() - t0 < IRQ_CYCLES) __asm__ volatile("nop");
  return id;
}

// J: the access has been denied: the interrupt is there or not, then the record clears it and the PLIC has no other
static void expect_irq(const char *what, int want, uint32_t addr, uint32_t ttype) {
  const uint32_t got = plic_claim();
  CHECK(got == (want ? IOPMP_PLIC_ID : 0), "%s: PLIC claim %u, expected %u", what, got, want ? IOPMP_PLIC_ID : 0);
  expect_record(what, addr, ttype, NOT_HIT_ERROR, 0);
  if (got) REG32(PLIC_CLAIM) = got;          // complete, with the line low by now
  __asm__ volatile("fence" ::: "memory");
  const uint32_t again = plic_claim();
  CHECK(again == 0, "%s: PLIC claim %u after the record was cleared", what, again);
}

int main(void) {
  soc_test_begin("t_iopmp");

  // A
  const uint32_t hw0 = IOPMP(IOPMP_HWCFG0_OFFSET), hw1 = IOPMP(IOPMP_HWCFG1_OFFSET), hw2 = IOPMP(IOPMP_HWCFG2_OFFSET);
  const int was_on = (hw0 & HWCFG0_ENABLE) != 0;
  CHECK(HWCFG0_MD_NUM(hw0) == NUMBER_MDS && (hw0 & HWCFG0_TOR_EN), "HWCFG0 0x%08x: expected %d domains, TOR", hw0,
        NUMBER_MDS);
  CHECK(HWCFG1_SID_NUM(hw1) == NUMBER_MASTERS && HWCFG1_ENTRY_NUM(hw1) == NUMBER_ENTRIES,
        "HWCFG1 0x%08x: expected %d sources, %d entries", hw1, NUMBER_MASTERS, NUMBER_ENTRIES);
  CHECK(HWCFG2_PRIO(hw2) == NUMBER_PRIO_ENTRIES, "HWCFG2 0x%08x: expected %d priority entries", hw2, NUMBER_PRIO_ENTRIES);
  CHECK(IOPMP(IOPMP_ENTRY_OFFSET_OFFSET) == ENTRY_OFFSET, "ENTRY_OFFSET 0x%x", IOPMP(IOPMP_ENTRY_OFFSET_OFFSET));
  IOPMP(IOPMP_ERRREACT_OFFSET) = 0;
  if (was_on) {
    IOPMP(IOPMP_ERR_REQINFO_OFFSET) = 1;
    printf("A: the IOPMP is already on: an earlier run and no reset since, so its reset state and B are not checked\r\n");
  } else {
    expect_no_record("A");
  }
  printf("A: %u domains, %u entries, %u with priority, %u source; %s\r\n", HWCFG0_MD_NUM(hw0), HWCFG1_ENTRY_NUM(hw1),
         HWCFG2_PRIO(hw2), HWCFG1_SID_NUM(hw1), was_on ? "on" : "off");

  REG32(PMC_STATUS_ADDR) = 1;                                   // hold the PE
  for (unsigned i = 0; i < sizeof pe_prog / sizeof pe_prog[0]; i++) REG32(ISPM_BASE_ADDR + 4 * i) = pe_prog[i];
  for (int i = 0; i < MB_WORDS; i++) REG32(DSPM_BASE_ADDR + 4 * i) = 0;
  __asm__ volatile("fence" ::: "memory");
  REG32(PMC_BOOT_ADDR) = ISPM_BASE_ADDR;
  REG32(PMC_STATUS_ADDR) = 0;                                   // run

  // B
  if (!was_on) {
    expect_allowed("B", REG_A);
    printf("B: off, no rules: the PE's store and load got through\r\n");
  }

  // C
  rules_off();
  rule(0, NAPOT(EVU_BASE_ADDR, EVU_PAGE_SIZE), MODE_NAPOT | READ_WRITE);
  CHECK(REG32(IOPMP_REG_ADDR(IOPMP_ENTRY_ADDR_OFFSET)) == NAPOT(EVU_BASE_ADDR, EVU_PAGE_SIZE) &&
        REG32(IOPMP_REG_ADDR(IOPMP_ENTRY_CFG_OFFSET)) == (MODE_NAPOT | READ_WRITE),
        "entry 0 read back: address 0x%08x, configuration 0x%x", REG32(IOPMP_REG_ADDR(IOPMP_ENTRY_ADDR_OFFSET)),
        REG32(IOPMP_REG_ADDR(IOPMP_ENTRY_CFG_OFFSET)));
  domains(1 << 0, 1, 1);
  IOPMP(IOPMP_HWCFG0_OFFSET) = HWCFG0_ENABLE;
  CHECK(IOPMP(IOPMP_HWCFG0_OFFSET) & HWCFG0_ENABLE, "the IOPMP did not turn on: HWCFG0 0x%08x",
        IOPMP(IOPMP_HWCFG0_OFFSET));
  __asm__ volatile("fence" ::: "memory");
  expect_allowed("C", REG_A);
  printf("C: on, read/write entry for the EVU page: the PE's store and load got through\r\n");

  // D
  rule(0, NAPOT(EVU_BASE_ADDR, EVU_PAGE_SIZE), MODE_NAPOT | READ_ONLY);
  expect_store_denied("D read-only", REG_A, WRITE_ERROR, 0);
  CHECK(pe_load(REG_A), "D read-only: the PE's load from 0x%08x faulted", (unsigned)REG_A);
  expect_no_record("D read-only");
  rule(0, NAPOT(EVU_BASE_ADDR, EVU_PAGE_SIZE), MODE_NAPOT | WRITE_ONLY);
  expect_load_denied("D write-only", REG_A, READ_ERROR, 0);
  CHECK(pe_store(REG_A), "D write-only: the PE's store to 0x%08x did not land", (unsigned)REG_A);
  expect_no_record("D write-only");
  printf("D: read-only stops the store, write-only stops the load (load fault in the PE)\r\n");

  // E
  rule(0, NAPOT(OTHER_PAGE, EVU_PAGE_SIZE), MODE_NAPOT | READ_WRITE);
  expect_store_denied("E", REG_A, NOT_HIT_ERROR, 0);
  expect_load_denied("E", REG_A, NOT_HIT_ERROR, 0);
  printf("E: an entry for another page only: neither gets through\r\n");

  // F
  rule(0, NAPOT(REG_A, 16), MODE_NAPOT | READ_WRITE);
  expect_allowed("F inside", REG_A);
  expect_allowed("F +8", REG_A8);
  expect_store_denied("F past the end", REG_B, NOT_HIT_ERROR, 0);
  expect_load_denied("F past the end", REG_B, NOT_HIT_ERROR, 0);
  expect_store_denied("F +0xC, 8 bytes checked", REG_AC, WRITE_ERROR, 0);
  printf("F: a 16-byte entry: only inside it, and 8 bytes are checked from each address\r\n");

  // G
  rules_off();
  rule(0, REG_A >> 2, MODE_OFF);
  rule(1, REG_B >> 2, MODE_TOR | READ_WRITE);
  domains(1 << 0, 2, 2);
  expect_allowed("G inside", REG_A);
  expect_store_denied("G top", REG_B, NOT_HIT_ERROR, 1);
  expect_store_denied("G below the base", REG_LOW, NOT_HIT_ERROR, 1);
  printf("G: a TOR entry: its base and top are both checked\r\n");

  // H
  rules_off();
  domains(1 << 0, NUM_RULES, NUM_RULES);
  rule(0, NAPOT(EVU_BASE_ADDR, EVU_PAGE_SIZE), MODE_NAPOT | READ_ONLY);
  rule(5, NAPOT(EVU_BASE_ADDR, EVU_PAGE_SIZE), MODE_NAPOT | READ_WRITE);
  expect_store_denied("H priority", REG_A, WRITE_ERROR, 0);
  rule(0, 0, MODE_OFF);
  rule(4, NAPOT(EVU_BASE_ADDR, EVU_PAGE_SIZE), MODE_NAPOT | READ_ONLY);
  expect_allowed("H no priority", REG_A);
  rule(5, 0, MODE_OFF);
  expect_store_denied("H no priority, last", REG_A, NOT_HIT_ERROR, 5);
  printf("H: a priority entry stops the search, a later entry does not\r\n");

  // I
  rules_off();
  rule(0, NAPOT(EVU_BASE_ADDR, EVU_PAGE_SIZE), MODE_NAPOT | READ_ONLY);
  rule(1, NAPOT(EVU_BASE_ADDR, EVU_PAGE_SIZE), MODE_NAPOT | READ_WRITE);
  domains(1 << 0, 1, 2);
  expect_store_denied("I domain 0", REG_A, WRITE_ERROR, 0);
  domains(1 << 1, 1, 2);
  expect_allowed("I domain 1", REG_A);
  rule(0, NAPOT(OTHER_PAGE, EVU_PAGE_SIZE), MODE_NAPOT | READ_WRITE);
  domains(1 << 0 | 1 << 1, 1, 2);
  expect_allowed("I both", REG_A);
  domains(0, 1, 2);
  expect_store_denied("I none", REG_A, NOT_HIT_ERROR, ANY_EID);
  printf("I: only the source's domains count, in order; with none, nothing gets through\r\n");

  // J
  rules_off();
  rule(0, NAPOT(OTHER_PAGE, EVU_PAGE_SIZE), MODE_NAPOT | READ_WRITE);
  domains(1 << 0, 1, 1);
  REG32(PLIC_PRIO) = 1;
  REG32(PLIC_EN) = 1u << IOPMP_PLIC_ID;
  __asm__ volatile("fence" ::: "memory");
  const struct { uint32_t react; int on_store, on_load; } irq_case[] = {
    { ERRREACT_IE | ERRREACT_IWE, 1, 0 },
    { ERRREACT_IE | ERRREACT_IRE, 0, 1 },
    { ERRREACT_IRE | ERRREACT_IWE, 0, 0 },
  };
  for (unsigned i = 0; i < sizeof irq_case / sizeof irq_case[0]; i++) {
    IOPMP(IOPMP_ERRREACT_OFFSET) = irq_case[i].react;
    (void)IOPMP(IOPMP_ERRREACT_OFFSET);
    CHECK(!pe_store(REG_A), "J: the PE's store landed");
    denied_stores++;
    denied_store_traps += last_store_traps;
    expect_irq("J store", irq_case[i].on_store, REG_A, ACCESS_WRITE);
    CHECK(!pe_load(REG_A), "J: the PE's load did not fault");
    expect_irq("J load", irq_case[i].on_load, REG_A, ACCESS_READ);
  }
  IOPMP(IOPMP_ERRREACT_OFFSET) = 0;
  REG32(PLIC_EN) = 0;
  REG32(PLIC_PRIO) = 0;
  printf("J: the interrupt comes with ie and the access's direction enabled, and goes with the record\r\n");

  // K
  rules_off();
  rule(0, 0x40000000u, MODE_TOR | READ_WRITE);   // TOR up to 4 GiB
  domains(1 << 0, 1, 1);
  expect_allowed("K", REG_A);
  expect_allowed("K", REG_B);
  REG32(PMC_STATUS_ADDR) = 1;                                   // hold the PE
  for (int w = 0; w < EVU_WORDS; w++) REG32(EVU_BASE_ADDR + 4 * w) = 0;
  printf("K: an entry allowing everything: the PE's accesses work again; the IOPMP stays on like this until a reset\r\n");
  printf("the PE took %u exceptions on %u denied stores\r\n", denied_store_traps, denied_stores);

  return soc_test_end();
}
