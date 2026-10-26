#include "board_uart_upload.h"
#include "board_dht12.h"
#include "board_bh1750.h"
#include "board_rc522.h"
#include <stdio.h>
#include <stdint.h>

static uint32_t sequence, last_upload;
static uint16_t crc16(const char *p, unsigned n) {
    uint16_t crc=0xffff;
    for (unsigned i=0;i<n;i++) {
        crc^=(uint16_t)(uint8_t)p[i]<<8;
        for (unsigned bit=0;bit<8;bit++)
            crc=(uint16_t)((crc&0x8000U)?(crc<<1)^0x1021U:crc<<1);
    }
    return crc;
}
void BoardUpload_Init(void) {
    __HAL_RCC_GPIOA_CLK_ENABLE(); __HAL_RCC_USART1_CLK_ENABLE();
    GPIO_InitTypeDef io={0}; io.Pin=GPIO_PIN_9;
    io.Mode=GPIO_MODE_AF_PP; io.Speed=GPIO_SPEED_FREQ_HIGH;
    HAL_GPIO_Init(GPIOA,&io);
    USART1->CR1=0; USART1->CR2=0; USART1->CR3=0;
    USART1->BRR=(HAL_RCC_GetPCLK2Freq()+4800U)/9600U;
    USART1->CR1=USART_CR1_UE|USART_CR1_TE;
    last_upload=HAL_GetTick();
}
void BoardUpload_Poll(void) {
    uint32_t now=HAL_GetTick();
    if ((uint32_t)(now-last_upload)<1000U) return;
    last_upload=now;
    char uid[21], frame[320];
    unsigned n=g_rfid.uid_length;
    if (n==4U || n==7U || n==10U) {
        const char digits[]="0123456789ABCDEF";
        for (unsigned i=0;i<n;i++) {
            uint8_t b=g_rfid.uid[i]; uid[i*2]=digits[b>>4]; uid[i*2+1]=digits[b&15];
        }
        uid[n*2]=0;
    } else { uid[0]='-'; uid[1]=0; }
    unsigned frame_ok=g_dht.frame_valid && (g_dht.status==1U || g_dht.status==5U);
    unsigned light_ok=g_light.valid && g_light.status==1U;
    int len=snprintf(frame,sizeof(frame),
        "IOT1,%lu,%lu,%lu,%u,%ld,%lu,%lu,%u,%lu,%lu,%lu,%lu,%lu,%lu,%lu,%s,%u,%lu",
        (unsigned long)++sequence,(unsigned long)now,(unsigned long)g_dht.attempts,
        frame_ok,(long)g_dht.temperature_tenths,(unsigned long)g_dht.humidity_tenths,
        (unsigned long)g_light.attempts,light_ok,(unsigned long)g_light.lux_tenths,
        (unsigned long)g_rfid.polls,(unsigned long)g_rfid.status,(unsigned long)g_rfid.version,
        (unsigned long)g_rfid.event_seq,(unsigned long)g_rfid.card_reads,
        (unsigned long)g_rfid.last_seen_ms,uid,(unsigned)g_rfid.sak,(unsigned long)g_rfid.atqa);
    if (len<0 || (unsigned)len>=sizeof(frame)-8U) return;
    uint16_t crc=crc16(frame,(unsigned)len);
    int end=snprintf(frame+len,sizeof(frame)-(unsigned)len,"*%04X\r\n",(unsigned)crc);
    if (end!=7) return;
    unsigned total=(unsigned)len+(unsigned)end;
    /* Bounded synchronous transmit; one short frame/s at 9600 baud. */
    uint32_t start=HAL_GetTick();
    for (unsigned i=0;i<total;i++) {
        while (!(USART1->SR&USART_SR_TXE))
            if ((uint32_t)(HAL_GetTick()-start)>500U) return;
        USART1->DR=(uint8_t)frame[i];
    }
}
