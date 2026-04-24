#include "sw/device/silicon_creator/rom/uart.h"
#include "sw/device/silicon_creator/rom/string_lib.h"
#include "sw/tests/common/utils.h"

#define IDMA_BASE      0xfef00000
#define TCDM_BASE      0xfff00000
#define L2_BASE        0x1C001000
#define L3_BASE        0x80000000

#define SIZE           128 // 0x1000 //4KiB
#define OFFSET         32

#define IDMA_SRC_ADDR_OFFSET         0x000000d8
#define IDMA_DST_ADDR_OFFSET         0x000000d0
#define IDMA_LENGTH_OFFSET           0x000000e0
#define IDMA_NEXT_ID_OFFSET          0x00000044
#define IDMA_DONE_ID_OFFSET          0x00000084
#define IDMA_REPS_2                  0x000000f8
#define IDMA_REPS_3                  0x00000110
#define IDMA_CONF                    0x00000000
#define EOC                          0xc11c0018

void printf_init() {
  int * tmp;
  tmp = (int *) 0x1a104074;
  *tmp = 1;
  tmp = (int *) 0x1a10407C;
  *tmp = 1;
  int baud_rate = 9600;
  int test_freq = 25000000;
  uart_set_cfg(0,(test_freq/baud_rate)>>4);
}

void printf_mem(uint32_t b1, uint32_t b2, uint32_t size) {
  uint32_t* ptr1 = (uint32_t*) b1;
  uint32_t* ptr2 = (uint32_t*) b2;
  for (uint32_t i = 0; i < size/4; ++i) {
    printf("%d - 0x%x: %d\t 0x%x: %d\r\n", i, &(ptr1[i]), ptr1[i], &(ptr2[i]), ptr2[i]);
  }
}

void wait_for_idma_eot(int next_id){
    volatile uint32_t *ptr;
    ptr = (uint32_t *) (IDMA_BASE + IDMA_DONE_ID_OFFSET) ;
    while(*ptr!=next_id)
      asm volatile("nop");
}

int issue_idma_transaction(uint32_t src_addr, uint32_t dst_addr, uint32_t num_bytes){
    volatile uint32_t * ptr;
    ptr = (uint32_t *) (IDMA_BASE + IDMA_SRC_ADDR_OFFSET);
    *ptr = src_addr;
    ptr = (uint32_t *) (IDMA_BASE + IDMA_DST_ADDR_OFFSET);
    *ptr = dst_addr;
    ptr = (uint32_t *) (IDMA_BASE + IDMA_LENGTH_OFFSET);
    *ptr = num_bytes;
    ptr = (uint32_t *) (IDMA_BASE + IDMA_CONF);
    *ptr = 0x3<<10;
    ptr = (uint32_t *) (IDMA_BASE + IDMA_REPS_2);
    *ptr = 0x00000001;
    ptr = (uint32_t *) (IDMA_BASE + IDMA_NEXT_ID_OFFSET);
    return *ptr;
}

void mem_init(uint32_t base, uint32_t size, bool mod) {
    int* ptr = (int*) base;
    size_t num_words = size / sizeof(int);
    for (size_t i = 0; i < num_words; ++i) {
        ptr[i] = mod ? i : 0;
    }
}

bool compare_mem(uint32_t b1, uint32_t b2, uint32_t size) {
  uint32_t* ptr1 = (uint32_t*) b1;
  uint32_t* ptr2 = (uint32_t*) b2;
  int err=0;
  for (uint32_t i = 0; i < size/4; ++i) {
    printf("%d - 0x%x: %d\t 0x%x: %d\r\n", i, &(ptr1[i]), ptr1[i], &(ptr2[i]), ptr2[i]);
    if(ptr1[i] != ptr2[i]){
      err++;
    }
  }
  return err;
}

bool dma_test(uint32_t b1, uint32_t b2, uint32_t size) {
  int next_id;
  mem_init(b1, size, 1);
  mem_init(b2, size, 0);
  printf(" --- pre transaction ---\r\n");
  printf_mem(b1, b2, size);
  next_id = issue_idma_transaction(b1, b2, size);
  wait_for_idma_eot(next_id);
  printf(" --- post transaction ---\r\n");
  printf_mem(b1, b2, size);
  return compare_mem(b1, b2, size);
}

int main(int argc, char **argv) {
  bool b=0;

  printf_init();

  printf("--------------------- FROM HRAM TO TCDM ---------------------\r\n");
  b = b || dma_test(L3_BASE, TCDM_BASE, SIZE);

  printf("--------------------- FROM TCDM TO HRAM ---------------------\r\n");
  b = b || dma_test(TCDM_BASE, L3_BASE, SIZE);

  printf("--------------------- FROM HRAM TO TCDM WITH OFFSET ---------------------\r\n");
  b = b || dma_test((L3_BASE + OFFSET), (TCDM_BASE + OFFSET), SIZE);

  printf("--------------------- FROM TCDM TO HRAM WITH OFFSET ---------------------\r\n");
  b = b || dma_test((TCDM_BASE + OFFSET), (L3_BASE + OFFSET), SIZE);

  return b;
}









/*
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>
#include "utils.h"

#define IDMA_BASE 		 0xfef00000
#define TCDM_BASE      0xfff00000
#define L2_BASE        0x1C001000
#define L3_BASE        0x80000000

#define SIZE           0x1000 //4KiB

#define IDMA_SRC_ADDR_OFFSET         0x000000d8
#define IDMA_DST_ADDR_OFFSET         0x000000d0
#define IDMA_LENGTH_OFFSET           0x000000e0
#define IDMA_NEXT_ID_OFFSET          0x00000044
#define IDMA_DONE_ID_OFFSET          0x00000084
#define IDMA_REPS_2                  0x000000f8
#define IDMA_REPS_3                  0x00000110
#define IDMA_CONF                    0x00000000
#define EOC                          0xc11c0018

void wait_for_idma_eot(int next_id){
    volatile uint32_t *ptr;
    ptr = (uint32_t *) (IDMA_BASE + IDMA_DONE_ID_OFFSET) ;
    while(*ptr!=next_id)
      asm volatile("nop");
}

int issue_idma_transaction(uint32_t src_addr, uint32_t dst_addr, uint32_t num_bytes){
    volatile uint32_t * ptr;
    ptr = (uint32_t *) (IDMA_BASE + IDMA_SRC_ADDR_OFFSET);
    *ptr = src_addr;
    ptr = (uint32_t *) (IDMA_BASE + IDMA_DST_ADDR_OFFSET);
    *ptr = dst_addr;
    ptr = (uint32_t *) (IDMA_BASE + IDMA_LENGTH_OFFSET);
    *ptr = num_bytes;
    ptr = (uint32_t *) (IDMA_BASE + IDMA_CONF);
    *ptr = 0x3<<10;
    ptr = (uint32_t *) (IDMA_BASE + IDMA_REPS_2);
    *ptr = 0x00000001;
    ptr = (uint32_t *) (IDMA_BASE + IDMA_NEXT_ID_OFFSET);
    return *ptr;
}

int main() {

  int volatile  * ptr;
  int b;
  int err = 0;

  int next_id;

  for(int i = 0; i<1024; i++){
    ptr = (int *) TCDM_BASE + i*4;
    *ptr = i;
  }

  next_id = issue_idma_transaction(TCDM_BASE,L2_BASE,SIZE);

  wait_for_idma_eot(next_id);

  for(int i = 0; i<SIZE/4; i++){
    ptr = (int *) L2_BASE + i;
    b = *ptr;
    if(b!=i)
      err++;
  }

  if(err!=0){
    ptr = (int *) EOC;
    *ptr = 0xFFFFFFFF;
    return -1;
  }
  else
    return 0;

}
*/
