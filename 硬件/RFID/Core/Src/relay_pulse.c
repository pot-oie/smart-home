#include "relay_pulse.h"
void RelayPulse_Update(RelayPulse *state, uint32_t event, uint32_t now) {
    if (event!=state->seen_event) {
        state->seen_event=event;
        if (event!=0U) {
            state->active=true;
            state->started_ms=now;
            state->trigger_count++;
        }
    }
    if (state->active && (uint32_t)(now-state->started_ms)>=RELAY_PULSE_MS)
        state->active=false;
}
