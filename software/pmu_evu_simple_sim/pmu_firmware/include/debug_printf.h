#ifndef __DPRINTF_H__
#define __DPRINTF_H__

#include <stdarg.h>



#define printf debug_printf

int debug_printf(const char *fmt, ...);
void write_to_memory(unsigned int value);\
void init_print_mem();


#endif