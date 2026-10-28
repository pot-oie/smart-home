#ifndef BOARD_RELAY_H
#define BOARD_RELAY_H
#include "main.h"
/* PB12. 0=unconfirmed (GPIO not driven), 1=active high, 2=active low, 3=diagnostic GPIO levels.
 * Confirm the actual module at GND and the board's 3.3V before selecting mode. */
#ifndef BOARD_RELAY_MODE
#define BOARD_RELAY_MODE 0
#endif
#if BOARD_RELAY_MODE < 0 || BOARD_RELAY_MODE > 3
#error "Invalid BOARD_RELAY_MODE"
#endif
typedef struct {
    uint32_t configured, active, trigger_count, last_event_seq, pulse_ms;
    uint32_t mode, output_high, pin_high;
} RelayDebug;
extern volatile RelayDebug g_relay;
/* Diagnostic mode only: set 0/1 over SWD; not a relay contact-state signal. */
extern volatile uint32_t g_relay_probe_level;
void BoardRelay_Init(void);
void BoardRelay_Poll(void);
#endif
