#!/usr/bin/env python3
"""Commissioning only: inspect/set the diagnostic relay GPIO via a named SRAM variable."""
import argparse,json,re,struct,subprocess,tempfile,time
from pathlib import Path
from read_rfid import ROOT,tool


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--level',type=int,choices=[0,1])
    a=ap.parse_args()
    elf=ROOT/'build/Debug/home_observer_board_test.elf'
    listing=subprocess.check_output([tool('gnu-tools-for-stm32/*/bin/arm-none-eabi-nm'),'-S',str(elf)],text=True)
    syms={}
    for line in listing.splitlines():
        f=line.split()
        if len(f)>=4 and f[-1] in ('g_relay','g_relay_probe_level'):
            syms[f[-1]]=(int(f[0],16),int(f[1],16))
    if set(syms)!={'g_relay','g_relay_probe_level'} or syms['g_relay'][1]!=32 or syms['g_relay_probe_level'][1]!=4:
        raise RuntimeError('诊断结构不匹配')
    if any(not (0x20000000<=addr and addr+size<=0x20005000) for addr,size in syms.values()):
        raise RuntimeError('禁止写入非SRAM地址')
    cli=tool('programmer/*/bin/STM32_Programmer_CLI')
    base=[cli,'-c','port=SWD','freq=4000','mode=HOTPLUG']
    def run(args):
        p=subprocess.run(base+args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=15)
        log=re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]','',p.stdout)
        if p.returncode or 'Error:' in log:raise RuntimeError(log[-1500:])
    with tempfile.TemporaryDirectory(prefix='relay-probe-') as td:
        f=Path(td)/'relay.bin'
        def read():
            f.unlink(missing_ok=True)
            run(['-u',hex(syms['g_relay'][0]),'32',str(f)])
            raw=f.read_bytes()
            if len(raw)!=32:raise RuntimeError('诊断读取长度异常')
            return dict(zip(['configured','active','triggerCount','lastEvent','pulseMs','mode','outputHigh','pinHigh'],struct.unpack('<8I',raw)))
        before=read()
        if a.level is not None:
            if before['mode']!=3 or before['configured']!=1:
                raise RuntimeError('当前不是继电器GPIO诊断固件，停止写入')
            run(['-w32',hex(syms['g_relay_probe_level'][0]),hex(a.level)])
            time.sleep(1)
        result=read()
        if a.level is not None and (result['outputHigh']!=a.level or result['pinHigh']!=a.level):
            raise RuntimeError('GPIO没有达到要求的电平：'+json.dumps(result))
        print(json.dumps(result,ensure_ascii=False))
        print('GPIO输出：'+('高电平' if result['outputHigh'] else '低电平')+'；继电器是否吸合需观察SW灯/触点，不能由GPIO状态代替。')

if __name__=='__main__':main()
