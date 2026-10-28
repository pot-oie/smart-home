#include "board_relay.h"
#include "board_rc522.h"
#include "relay_pulse.h"
volatile RelayDebug g_relay;
volatile uint32_t g_relay_probe_level=1U;
#if BOARD_RELAY_MODE == 1 || BOARD_RELAY_MODE == 2
static RelayPulse pulse;
#endif
#if BOARD_RELAY_MODE != 0
static void write_level(bool high) {
    HAL_GPIO_WritePin(GPIOB,GPIO_PIN_12,high?GPIO_PIN_SET:GPIO_PIN_RESET);
    g_relay.output_high=high;
    g_relay.pin_high=HAL_GPIO_ReadPin(GPIOB,GPIO_PIN_12)==GPIO_PIN_SET;
}
#endif
void BoardRelay_Init(void) {
    g_relay.pulse_ms=RELAY_PULSE_MS;
    g_relay.mode=BOARD_RELAY_MODE;
#if BOARD_RELAY_MODE != 0
    __HAL_RCC_GPIOB_CLK_ENABLE();
    /* Active-low and diagnostic modes start released before enabling output. */
    write_level(BOARD_RELAY_MODE==2 || BOARD_RELAY_MODE==3);
    GPIO_InitTypeDef io={0};
    io.Pin=GPIO_PIN_12;
    /* Release the module's input rather than driving it to only 3.3 V. */
    io.Mode=(BOARD_RELAY_MODE==2 || BOARD_RELAY_MODE==3)
        ? GPIO_MODE_OUTPUT_OD : GPIO_MODE_OUTPUT_PP;
    io.Pull=GPIO_NOPULL; io.Speed=GPIO_SPEED_FREQ_LOW;
    HAL_GPIO_Init(GPIOB,&io);
    g_relay.configured=1;
#endif
}
void BoardRelay_Poll(void) {
#if BOARD_RELAY_MODE == 3
    write_level((g_relay_probe_level&1U)!=0);
#elif BOARD_RELAY_MODE == 1 || BOARD_RELAY_MODE == 2
    RelayPulse_Update(&pulse,g_rfid.event_seq,HAL_GetTick());
    write_level(BOARD_RELAY_MODE==1 ? pulse.active : !pulse.active);
    g_relay.active=pulse.active;
    g_relay.trigger_count=pulse.trigger_count;
    g_relay.last_event_seq=pulse.seen_event;
#endif
}
