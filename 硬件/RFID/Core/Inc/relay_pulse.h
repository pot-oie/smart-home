#ifndef RELAY_PULSE_H
#define RELAY_PULSE_H
#include <stdint.h>
#include <stdbool.h>
#define RELAY_PULSE_MS 3000U
/* Consume debounced RFID event IDs rather than every successful RF poll. */
typedef struct {
    uint32_t seen_event, started_ms, trigger_count;
    bool active;
} RelayPulse;
void RelayPulse_Update(RelayPulse *state, uint32_t event, uint32_t now);
#endif
