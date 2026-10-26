#ifndef BOARD_SOFT_I2C_H
#define BOARD_SOFT_I2C_H
#include "main.h"
#include <stdbool.h>
/* Shared, single-threaded open-drain PB6/PB7 bus. Board pull-ups required. */
void Bus_Init(void);
void Bus_ClearFault(void);
bool Bus_Failed(void);
void Bus_Release(void);
bool Bus_SclHigh(void);
bool Bus_SdaHigh(void);
void Bus_DelayUs(uint32_t us);
bool Bus_Start(void);
void Bus_Stop(void);
bool Bus_Write(uint8_t value);
bool Bus_Read(uint8_t *value,bool ack);
#endif
