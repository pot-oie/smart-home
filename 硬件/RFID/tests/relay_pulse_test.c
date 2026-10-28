#include "relay_pulse.h"
#include <assert.h>
#include <limits.h>
int main(void) {
    RelayPulse p={0};
    RelayPulse_Update(&p,0,0); assert(!p.active && p.trigger_count==0);
    RelayPulse_Update(&p,1,100); assert(p.active && p.trigger_count==1);
    RelayPulse_Update(&p,1,2000); assert(p.started_ms==100 && p.trigger_count==1);
    RelayPulse_Update(&p,1,3099); assert(p.active);
    RelayPulse_Update(&p,1,3100); assert(!p.active);
    RelayPulse_Update(&p,1,4000); assert(!p.active && p.trigger_count==1);
    RelayPulse_Update(&p,2,5000); assert(p.active && p.trigger_count==2);
    RelayPulse_Update(&p,3,6000); assert(p.active && p.started_ms==6000 && p.trigger_count==3);
    RelayPulse_Update(&p,3,9000); assert(!p.active);
    RelayPulse_Update(&p,4,UINT32_MAX-1000U); assert(p.active);
    RelayPulse_Update(&p,4,1998U); assert(p.active);
    RelayPulse_Update(&p,4,1999U); assert(!p.active);
    return 0;
}
