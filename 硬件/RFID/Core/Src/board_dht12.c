#include "board_dht12.h"
#include "board_soft_i2c.h"
volatile DhtDebug g_dht;
static uint32_t last_poll_ms;
void BoardDht_Init(void) {
    Bus_Init();
    last_poll_ms=HAL_GetTick(); g_dht.status=DHT_WAITING;
}
void BoardDht_Poll(void) {
    uint32_t now=HAL_GetTick();
    if ((uint32_t)(now-last_poll_ms)<2500U) return;
    last_poll_ms=now;
    g_dht.attempts++; g_dht.valid=0; g_dht.nack_stage=0;
    g_dht.frame_valid=0; g_dht.within_spec=0;
    Bus_Release(); Bus_DelayUs(100);
    g_dht.scl_idle=Bus_SclHigh(); g_dht.sda_idle=Bus_SdaHigh();
    Bus_ClearFault();
    DhtStatus status=DHT_BUS_LOW;
    uint8_t raw[5]={0};
    if (!g_dht.scl_idle || !g_dht.sda_idle || !Bus_Start()) goto done;
    status=DHT_NO_ACK;
    /* DHT12 7-bit address 0x5c: write byte 0xb8, read byte 0xb9. */
    g_dht.nack_stage=1; if (!Bus_Write(0xb8U)) goto stopped;
    g_dht.nack_stage=2; if (!Bus_Write(0x00U)) goto stopped;
    Bus_Stop(); Bus_DelayUs(100);
    if (!Bus_Start()) { status=DHT_BUS_LOW; goto stopped; }
    g_dht.nack_stage=3; if (!Bus_Write(0xb9U)) goto stopped;
    g_dht.nack_stage=0;
    for (unsigned i=0;i<5;i++) {
        if (!Bus_Read(&raw[i],i<4)) { status=DHT_BUS_LOW; goto stopped; }
    }
    for (unsigned i=0;i<5;i++) g_dht.raw[i]=raw[i];
    if ((uint8_t)(raw[0]+raw[1]+raw[2]+raw[3])!=raw[4]) {
        status=DHT_CHECKSUM; goto stopped;
    }
    g_dht.frame_valid=1;
    /* DHT12 sign is the MSB of the temperature DECIMAL byte (raw[3]). */
    int32_t temp=(int32_t)raw[2]*10+(raw[3]&0x7fU);
    if (raw[3]&0x80U) temp=-temp;
    uint32_t humidity=(uint32_t)raw[0]*10+raw[1];
    /* Always retain decoded diagnostics, even when outside the rated range. */
    g_dht.temperature_tenths=temp; g_dht.humidity_tenths=humidity;
    if (raw[1]>9 || (raw[3]&0x7fU)>9 || humidity<200U || humidity>950U ||
        temp < -200 || temp>600) { status=DHT_RANGE; goto stopped; }
    g_dht.within_spec=1;
    status=DHT_OK;
stopped:
    Bus_Stop();
done:
    Bus_Release();
    if (Bus_Failed()) status=DHT_BUS_LOW;
    g_dht.status=status;
    if (status==DHT_OK) {
        g_dht.valid=1; g_dht.good_reads++; g_dht.last_good_ms=now;
    } else { g_dht.bad_reads++; }
}
