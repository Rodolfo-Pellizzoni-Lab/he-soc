#include "sw/device/silicon_creator/rom/uart.h"
#include "sw/device/silicon_creator/rom/string_lib.h"
#include "sw/tests/common/utils.h"

#define IDMA_BASE      0xfef00000
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

void printf_mem(uint32_t b1, uint32_t size) {
  uint32_t* ptr1 = (uint32_t*) b1;
  for (uint32_t i = 0; i < size/4; ++i) {
    printf("%d - 0x%x: %x\r\n", i, &(ptr1[i]), ptr1[i]);
   }
}

void mem_init(uint32_t base, uint32_t size, bool mod) {
    int* ptr = (int*) base;
    size_t num_words = size / sizeof(int);
    for (size_t i = 0; i < num_words; ++i) {
        ptr[i] = mod ? num_words - i + 1 : 0;
    }
}

bool addr_test(uint32_t b1, uint32_t size) {
  int next_id;
  printf(" --- init memory ---\r\n");
  mem_init(b1, size, 1);
  printf(" --- print memory content ---\r\n");
  printf_mem(b1, size);
  return 0;
}

int main(int argc, char **argv) {
  bool b=0;

  printf_init();

  printf("--------------------- FROM HRAM TO TCDM ---------------------\r\n");
  b = b || addr_test(L3_BASE, SIZE);

  return b;
}
