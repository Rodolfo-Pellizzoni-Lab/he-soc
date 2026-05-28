#ifndef __BASE_COMPONENT_H__
#define __BASE_COMPONENT_H__
#include <stdint.h>
#include <debug_printf.h>

#define BASE_COMPONENT_ID 1
#define BASE_COMPONENT_BITMASK 0b0001
#define MAX_REQUEST_HANDLERS 64
#define REQUEST_INSTALL_ID 1
#define REQUEST_UNINSTALL_ID 2

typedef struct {
    uint32_t id;
    uint32_t bitmask;
    void* event_handler;
    void* request_handler;
} request_comp_installer_t;

void base_component_init();
void base_component_exit();

void base_component_event_handler();

void base_component_request_register(uint32_t id, void (*handler)(uint32_t* req));

#endif
