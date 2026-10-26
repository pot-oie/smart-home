#ifndef BOARD_BH1750_H
#define BOARD_BH1750_H
#include "main.h"
typedef struct {
    uint32_t attempts, good_reads, bad_reads, last_good_ms;
    uint32_t valid, status, address, raw, lux_tenths;
    uint32_t scl_idle, sda_idle, configured, last_command;
} LightDebug;
/* status: 0 waiting, 1 OK, 2 no ACK, 3 bus low/timeout, 4 saturated. */
extern volatile LightDebug g_light;
void BoardLight_Init(void);
void BoardLight_Poll(void);
#endif
