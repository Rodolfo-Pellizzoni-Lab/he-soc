#include "debug_printf.h"
#include <common_defines.h>

void write_to_memory(unsigned int value) {
    asm volatile (
        "li t0, 0x10427FFC\n"    // Load address into t0
        "sw %0, 0(t0)\n"         // Store value into the memory location at t0
        :                         // No output operands
        : "r" (value)            // Input operand: 'value' will be placed into t1
        : "t0"                    // Clobbered register
    );
}

void init_print_mem() {
    volatile char *ptr = PRINT_START_ADDRESS;
    while (ptr <= PRINT_END_ADDRESS) {
        *ptr = '\0';
        ptr++;
    }
}



void mem_putchar(char c) {
    // Ensure we don't exceed the memory limit
    static volatile char *output_ptr = PRINT_START_ADDRESS;
    if (output_ptr <= PRINT_END_ADDRESS) {
        *output_ptr = c;
        output_ptr++;
    }
}

int debug_printf(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);

    const char *p;
    for (p = fmt; *p != '\0'; p++) {
        if (*p == '%') {
            p++;
            switch (*p) {
                case 'd': {  // Integer
                    int i = va_arg(args, int);
                    char buffer[10];
                    char *b = buffer + sizeof(buffer) - 1;
                    *b = '\0';
                    if (i == 0) {
                        *(--b) = '0';
                    } else {
                        int is_negative = (i < 0);
                        if (is_negative) i = -i;
                        while (i) {
                            *(--b) = '0' + (i % 10);
                            i /= 10;
                        }
                        if (is_negative) *(--b) = '-';
                    }
                    while (*b) mem_putchar(*b++);
                    break;
                }
                case 'c': {  // Character
                    char c = (char)va_arg(args, int);
                    mem_putchar(c);
                    break;
                }
                case 's': {  // String
                    const char *str = va_arg(args, const char*);
                    while (*str) mem_putchar(*str++);
                    break;
                }
                default:
                    mem_putchar('%');
                    mem_putchar(*p);
                    break;
            }
        } else {
            mem_putchar(*p);
        }
    }

    va_end(args);
    return 0;
}