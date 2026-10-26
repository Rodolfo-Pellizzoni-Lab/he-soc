// Boot ROM of the AlSaqr host: every hart parks here until it is told where to go.
//   harts 0 and 1: sleep in wfi until the SCMI mailbox interrupt (PLIC source 10) shows up as the claim of
//                  the hart's S-mode PLIC context, complete it, then jump to the entry the mailbox holds;
//   hart h >= 2:   sleep in wfi once (the APMU counter h-2 overflow interrupt, PLIC source 156 + h - 2, is
//                  what wakes it), complete that interrupt, then jump to the same entry.
// Works for any number of harts: the S-mode context of hart h is 2h+1, its claim/complete register is at
// 0x0C200004 + 0x1000 * (2h+1) and its enable word 0 at 0x0C002000 + 0x80 * (2h+1).
#include "uart.h"
#define SPL_SRC 0x1001000UL
#define SPL_SIZE 0xC000
#define SPL_DEST 0x70000000UL

#define read_csr(reg) ({ unsigned long __tmp;    \
  asm volatile ("csrr %0, " #reg : "=r"(__tmp)); \
  __tmp; })

enum boot_mode_t { JTAG, SPL_ROM };

#define PLIC_BASE       0x0C000000UL
#define PLIC_ENABLE(c)  ((volatile int *)(PLIC_BASE + 0x2000 + 0x80 * (c)))      // enable word 0 of context c
#define PLIC_CLAIM(c)   ((volatile int *)(PLIC_BASE + 0x200004 + 0x1000 * (c)))  // claim / complete of context c
#define MBOX_DOORBELL   ((volatile int *)0x10404024)

int mbox_id = 10;         // SCMI mailbox interrupt: PLIC source 10
int pmu_plic_id0 = 156;   // APMU counter 0 overflow: PLIC source 156; counter k wakes hart k + 2

static inline unsigned long s_context(void) { return 2 * read_csr(mhartid) + 1; }

void wait_for_boot_irq(void) {         // harts 0 and 1: the mailbox interrupt
  volatile int *claim = PLIC_CLAIM(s_context());
  while (*claim != mbox_id)
    __asm__ volatile("wfi;");
}

void wait_for_boot_irq_pmu(void) {     // harts 2 and up: the APMU counter overflow interrupt
  __asm__ volatile("wfi;");
}

void claim_irq(int id) {               // complete the interrupt, then disable enable word 0 of the context
  *PLIC_CLAIM(s_context()) = id;
  *PLIC_ENABLE(s_context()) = 0;
}

void boot(void) {
  *MBOX_DOORBELL = 0;
  __asm__ volatile("li a0, 0x10404000;");
  __asm__ volatile("lwu t0, 0(a0);");
  __asm__ volatile("jr t0;");
}

int main() {
    __asm__ volatile(
        "csrr a0, mhartid;"
        "la a1, device_tree;");

    while (1) {
      if (read_csr(mhartid) < 2) {
          wait_for_boot_irq();
          claim_irq(mbox_id);
      } else {
          wait_for_boot_irq_pmu();
          claim_irq(pmu_plic_id0 + (int)read_csr(mhartid) - 2);
      }
      boot();
    }
}

void handle_trap(void) {
}
