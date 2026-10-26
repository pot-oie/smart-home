#ifndef BOARD_UART_UPLOAD_H
#define BOARD_UART_UPLOAD_H
#include "main.h"
/* USART1 PA9 TX only, 9600 8N1. PA10 is not enabled. */
void BoardUpload_Init(void);
void BoardUpload_Poll(void);
#endif
