#ifndef BOARD_RC522_H
#define BOARD_RC522_H
#include "main.h"
/* Initial bring-up only: UID acquisition, no card-memory writes or authorization.
 * PA4=CS(SDA label), PA5=SCK, PA6=MISO, PA7=MOSI, PB0=RST; 3.3V only.
 * status: 0=init,1=no card,2=UID read,3=SPI test failed,4=RF error,
 * 5=unsupported/malformed UID,6=unrecognized version. */
typedef struct {
    uint32_t polls, card_reads, failures, status, version;
    uint32_t last_seen_ms, event_seq, uid_length;
    uint8_t uid[10];
    uint8_t sak;
    uint8_t reserved;
    uint32_t atqa, last_error;
} RfidDebug;
extern volatile RfidDebug g_rfid;
void BoardRfid_Init(void);
void BoardRfid_Poll(void);
#endif
