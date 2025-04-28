// Copyright 2021 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "uart.h"
#define SPL_SRC 0x1001000UL
#define SPL_SIZE 0xC000
#define SPL_DEST 0x70000000UL

#define read_csr(reg) ({ unsigned long __tmp;    \
  asm volatile ("csrr %0, " #reg : "=r"(__tmp)); \
  __tmp; })

// Boot modes.
enum boot_mode_t { JTAG, SPL_ROM };

int mbox_id = 10;
int pmu_plic_id1 = 156;
int pmu_plic_id2 = 157;

void wait_for_boot_irq(void) {
  int * pointer;
  if(read_csr(mhartid))
    pointer=(int *)0x0C203004;  // Irq Claim process for Context-3
  else
    pointer=(int *)0x0C201004;  // Irq Claim process for Context-1
  while(*pointer != mbox_id)
    __asm__ volatile("wfi;");
}

void wait_for_boot_irq_core2(void) {
  int * pointer1;
  if(read_csr(mhartid))
    pointer1=(int *)0x0C205004;  // Irq Claim process for Context-5
  else
    pointer1=(int *)0x0C201004;  // Irq Claim process for Context-1
  //while(*pointer1 != pmu_plic_id1)
    __asm__ volatile("wfi;");
}

void wait_for_boot_irq_core3(void) {
  int * pointer2;
  if(read_csr(mhartid))
    pointer2=(int *)0x0C207004;  // Irq Claim process for Context-7
  else
    pointer2=(int *)0x0C201004;  // Irq Claim process for Context-1
  //while(*pointer1 != pmu_plic_id1)
    __asm__ volatile("wfi;");
}

void claim_irq(void) {
  int * pointer;
  if(read_csr(mhartid)){
    pointer = (int *) 0x0C203004; // Irq Claim process for Context-3
    *pointer = mbox_id;
    pointer = (int *) 0x0C002180; // disable core 1 plic target
    *pointer = 0x0;
  }
  else{
    pointer = (int *) 0x0C201004;
    *pointer = mbox_id;
    pointer = (int *) 0x0C002080; // disable core 1 plic target
    *pointer = 0x0;
  }
}

void claim_irq_core2(void) {
  int * pointer1;
  if(read_csr(mhartid)){
    pointer1 = (int *) 0x0C205004; // Irq Claim process for Context-5
    *pointer1 = pmu_plic_id1;
    pointer1 = (int *) 0x0C002280; // disable core 1 plic target
    *pointer1 = 0x0;
  }
  else{
    pointer1 = (int *) 0x0C201004;
    *pointer1 = pmu_plic_id1;
    pointer1 = (int *) 0x0C002080; // disable core 1 plic target
    *pointer1 = 0x0;
  }
}

void claim_irq_core3(void) {
  int * pointer2;
  if(read_csr(mhartid)){
    pointer2 = (int *) 0x0C207004; // Irq Claim process for Context-7
    *pointer2 = pmu_plic_id2;
    pointer2 = (int *) 0x0C002380; // disable core 1 plic target
    *pointer2 = 0x0;
  }
  else{
    pointer2 = (int *) 0x0C201004;
    *pointer2 = pmu_plic_id1;
    pointer2 = (int *) 0x0C002080; // disable core 1 plic target
    *pointer2 = 0x0;
  }
}

void boot(void) {
  int * pointer;
  pointer=(int *)0x10404024;
  *pointer=0x0;
  __asm__ volatile("li a0, 0x10404000;");
  __asm__ volatile("lwu t0, 0(a0);");
  __asm__ volatile("jr t0;");
}

int main() {
    //  TODO:Fix uart deadlock

    int * pointer;
    int * pointer1;
    int * pointer2;
    __asm__ volatile(
        "csrr a0, mhartid;"
        "la a1, device_tree;");
      //"ebreak;");

    if(read_csr(mhartid)>1) {
      // while(1)
      //   __asm__ volatile ("wfi;");
    }

    while (1) {
      if (((read_csr(mhartid)) != 2) && ((read_csr(mhartid)) != 3)){
          wait_for_boot_irq();
          claim_irq();
        }
      if ((read_csr(mhartid)) == 2) {
          wait_for_boot_irq_core2();
          claim_irq_core2();
          
        }
        if ((read_csr(mhartid)) == 3) {
          wait_for_boot_irq_core3();
          claim_irq_core3();
          
        }
      boot();
    }
}

void handle_trap(void) {
}
