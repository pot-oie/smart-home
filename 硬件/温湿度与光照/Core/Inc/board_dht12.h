#ifndef BOARD_DHT12_H
#define BOARD_DHT12_H
#include "main.h"
/* Debug-only sensor bring-up; PB6=SCL, PB7=SDA, external 3.3 V pull-ups required. */
typedef enum { DHT_WAITING=0, DHT_OK=1, DHT_NO_ACK=2,
               DHT_CHECKSUM=3, DHT_BUS_LOW=4, DHT_RANGE=5 } DhtStatus;
typedef struct {
    uint32_t attempts, good_reads, bad_reads, last_good_ms;
    uint32_t valid, status, nack_stage, scl_idle, sda_idle;
    int32_t temperature_tenths;
    uint32_t humidity_tenths;
    uint8_t raw[5];
    uint32_t frame_valid, within_spec;
} DhtDebug;
extern volatile DhtDebug g_dht;
void BoardDht_Init(void);
void BoardDht_Poll(void);
#endif
