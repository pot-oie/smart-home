#include "board_bh1750.h"
#include "board_soft_i2c.h"
#define ADDRESS 0x23U /* H03 ADD must be tied LOW; 0x5c conflicts with DHT12. */
volatile LightDebug g_light;
static uint32_t last_poll_ms, ready_ms;
static bool command(uint8_t value) {
    g_light.last_command=value;
    bool ok=Bus_Start() && Bus_Write(ADDRESS<<1) && Bus_Write(value);
    Bus_Stop(); return ok && !Bus_Failed();
}
void BoardLight_Init(void) {
    Bus_Init(); g_light.address=ADDRESS; last_poll_ms=HAL_GetTick();
}
void BoardLight_Poll(void) {
    uint32_t now=HAL_GetTick();
    if ((uint32_t)(now-last_poll_ms)<500U) return;
    last_poll_ms=now; g_light.attempts++; g_light.valid=0;
    Bus_ClearFault(); Bus_Release(); Bus_DelayUs(100);
    g_light.scl_idle=Bus_SclHigh(); g_light.sda_idle=Bus_SdaHigh();
    if (!g_light.scl_idle || !g_light.sda_idle) {
        g_light.status=3; g_light.configured=0; g_light.bad_reads++; return;
    }
    if (!g_light.configured) {
        /* Explicit MTreg=69, continuous H-resolution (raw / 1.2 lux). */
        const uint8_t setup[]={0x01,0x07,0x42,0x65,0x10};
        for (unsigned i=0;i<sizeof setup;i++) {
            if (!command(setup[i])) {
                g_light.status=Bus_Failed()?3:2; g_light.bad_reads++; return;
            }
        }
        g_light.configured=1; ready_ms=HAL_GetTick(); g_light.status=0; return;
    }
    if ((uint32_t)(now-ready_ms)<200U) { g_light.status=0; return; }
    uint8_t hi=0,lo=0;
    bool ok=Bus_Start() && Bus_Write((ADDRESS<<1)|1U) &&
            Bus_Read(&hi,true) && Bus_Read(&lo,false);
    Bus_Stop();
    if (!ok || Bus_Failed()) {
        g_light.status=Bus_Failed()?3:2; g_light.configured=0;
        g_light.bad_reads++; return;
    }
    g_light.raw=((uint32_t)hi<<8)|lo;
    g_light.lux_tenths=(g_light.raw*25U+1U)/3U;
    if (g_light.raw==65535U) {
        g_light.status=4; g_light.bad_reads++; return;
    }
    g_light.status=1; g_light.valid=1; g_light.good_reads++;
    g_light.last_good_ms=now;
}
