#include "board_soft_i2c.h"
#define SCL GPIO_PIN_6
#define SDA GPIO_PIN_7
#define HALF_US 25U
static uint32_t cycles_us;
static bool clock_timeout;
void Bus_DelayUs(uint32_t us) {
    uint32_t Bus_Start=DWT->CYCCNT;
    while ((uint32_t)(DWT->CYCCNT-Bus_Start)<us*cycles_us) { __NOP(); }
}
static void low(uint16_t pin) { HAL_GPIO_WritePin(GPIOB,pin,GPIO_PIN_RESET); }
static void release(uint16_t pin) { HAL_GPIO_WritePin(GPIOB,pin,GPIO_PIN_SET); }
static bool high(uint16_t pin) { return HAL_GPIO_ReadPin(GPIOB,pin)==GPIO_PIN_SET; }
static bool clock_high(void) {
    release(SCL);
    uint32_t Bus_Start=DWT->CYCCNT;
    while (!high(SCL)) {
        if ((uint32_t)(DWT->CYCCNT-Bus_Start)>=cycles_us*1000U) {
            clock_timeout=true; return false;
        }
    }
    Bus_DelayUs(HALF_US); return true;
}
bool Bus_Start(void) {
    release(SDA);
    if (!clock_high() || !high(SDA)) return false;
    low(SDA); Bus_DelayUs(HALF_US); low(SCL); Bus_DelayUs(HALF_US); return true;
}
void Bus_Stop(void) {
    low(SCL); low(SDA); Bus_DelayUs(HALF_US);
    (void)clock_high(); release(SDA); Bus_DelayUs(HALF_US);
}
bool Bus_Write(uint8_t value) {
    for (unsigned bit=0;bit<8;bit++) {
        if (value&0x80U) release(SDA); else low(SDA);
        Bus_DelayUs(HALF_US);
        if (!clock_high()) return false;
        low(SCL); Bus_DelayUs(HALF_US); value<<=1;
    }
    release(SDA); Bus_DelayUs(HALF_US);
    if (!clock_high()) return false;
    bool ack=!high(SDA);
    low(SCL); Bus_DelayUs(HALF_US); return ack;
}
bool Bus_Read(uint8_t *value,bool ack) {
    *value=0; release(SDA);
    for (unsigned bit=0;bit<8;bit++) {
        Bus_DelayUs(HALF_US);
        if (!clock_high()) return false;
        *value=(uint8_t)((*value<<1)|(high(SDA)?1U:0U));
        low(SCL); Bus_DelayUs(HALF_US);
    }
    if (ack) low(SDA); else release(SDA);
    Bus_DelayUs(HALF_US);
    if (!clock_high()) return false;
    low(SCL); Bus_DelayUs(HALF_US); release(SDA); return true;
}

void Bus_Init(void) {
    static bool initialized;
    if (initialized) return;
    __HAL_RCC_GPIOB_CLK_ENABLE(); release(SCL|SDA);
    GPIO_InitTypeDef io={0};
    io.Pin=SCL|SDA; io.Mode=GPIO_MODE_OUTPUT_OD;
    io.Pull=GPIO_NOPULL; io.Speed=GPIO_SPEED_FREQ_LOW;
    HAL_GPIO_Init(GPIOB,&io);
    CoreDebug->DEMCR|=CoreDebug_DEMCR_TRCENA_Msk;
    DWT->CYCCNT=0; DWT->CTRL|=DWT_CTRL_CYCCNTENA_Msk;
    cycles_us=HAL_RCC_GetHCLKFreq()/1000000U;
    if (!cycles_us) cycles_us=1;
    initialized=true;
}
void Bus_ClearFault(void) { clock_timeout=false; }
bool Bus_Failed(void) { return clock_timeout; }
void Bus_Release(void) { release(SCL|SDA); }
bool Bus_SclHigh(void) { return high(SCL); }
bool Bus_SdaHigh(void) { return high(SDA); }
