#!/usr/bin/env python3
"""Read running RFID bring-up firmware through SWD HOTPLUG, with same-version ELF."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import struct
import sys
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parents[1] / 'tools'))
from stm32_tools import find_tool

STATES = {0:'初始化', 1:'等待刷卡', 2:'已读到卡号', 3:'SPI连线/供电异常',
          4:'读卡通信异常（检查距离、单卡）', 5:'卡号格式异常', 6:'芯片版本待确认'}


def tool(pattern):
    executable = pattern.rsplit('/', 1)[-1]
    variable = {'STM32_Programmer_CLI':'STM32_PROGRAMMER_CLI',
                'arm-none-eabi-nm':'ARM_NM', 'arm-none-eabi-objcopy':'ARM_OBJCOPY'}[executable]
    return str(find_tool(variable, executable, pattern))


def layout(elf):
    listing = subprocess.check_output([tool('gnu-tools-for-stm32/*/bin/arm-none-eabi-nm'), '-S', str(elf)], text=True)
    symbols = {}
    for line in listing.splitlines():
        f = line.split()
        if len(f)>=4 and f[-1] in ('g_dht','g_light','g_rfid'):
            symbols[f[-1]] = (int(f[0],16), int(f[1],16))
    expected = {'g_dht':60, 'g_light':52, 'g_rfid':52}
    if set(symbols)!=set(expected) or any(symbols[k][1]!=v for k,v in expected.items()):
        raise RuntimeError('ELF结构不匹配，停止读取')
    return symbols


def decode(data, syms, begin):
    d=struct.unpack_from('<9IiI5B3x2I',data,syms['g_dht'][0]-begin)
    light=struct.unpack_from('<13I',data,syms['g_light'][0]-begin)
    r=struct.unpack_from('<8I10B2B2I',data,syms['g_rfid'][0]-begin)
    n=r[7]
    frame_ok=bool(d[16]) and (sum(d[11:15])&255)==d[15] and d[5] in (1,5)
    return {
        'hostTime':datetime.now(timezone.utc).isoformat(),
        'temperature':d[9]/10 if frame_ok else None,
        'humidity':d[10]/10 if frame_ok else None,
        'dhtAttempts':d[0], 'dhtFrameOK':frame_ok,
        'lux':light[8]/10 if light[4] and light[5]==1 else None,
        'lightAttempts':light[0],
        'rfid':{'polls':r[0], 'cardReads':r[1], 'failures':r[2], 'status':r[3],
                'state':STATES.get(r[3],'未知'), 'version':f'0x{r[4]:02X}',
                'lastSeenMs':r[5], 'eventSeq':r[6], 'uidLength':n,
                'lastUID':''.join(f'{v:02X}' for v in r[8:8+n]) if n in (4,7,10) else None,
                'sak':r[18], 'atqa':r[20], 'lastError':r[21]}}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--count',type=int,default=0)
    parser.add_argument('--interval',type=float,default=2)
    parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    syms=layout(ROOT/'build/Debug/home_observer_board_test.elf')
    begin=min(v[0] for v in syms.values()); end=max(v[0]+v[1] for v in syms.values())
    print('RFID只读监视：lastUID为最后一次读卡，不代表卡仍在场。Ctrl+C停止。',flush=True)
    i=0; last_polls=None; changed_at=None
    with tempfile.TemporaryDirectory(prefix='iot-rfid-') as td:
        path=Path(td)/'ram.bin'
        while args.count==0 or i<args.count:
            try:
                path.unlink(missing_ok=True)
                proc=subprocess.run([tool('programmer/*/bin/STM32_Programmer_CLI'),'-c','port=SWD',
                                     'freq=4000','mode=HOTPLUG','-u',hex(begin),str(end-begin),str(path)],
                                    stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=15)
                log=re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]','',proc.stdout)
                if proc.returncode or 'Error:' in log or not path.exists():
                    raise RuntimeError('ST-LINK读取失败：关闭其他调试/转发工具。\n'+log[-1500:])
                data=path.read_bytes()
                if len(data)!=end-begin: raise RuntimeError('RAM长度错误')
                row=decode(data,syms,begin)
                polls=row['rfid']['polls']
                if last_polls is not None and polls < last_polls:
                    changed_at=None
                elif last_polls is not None and polls != last_polls:
                    changed_at=time.monotonic()
                last_polls=polls
                row['linkOnline']=True
                row['samplingConfirmed']=changed_at is not None and time.monotonic()-changed_at<6
                print(json.dumps(row,ensure_ascii=False),flush=True)
                if args.output:
                    args.output.parent.mkdir(parents=True,exist_ok=True)
                    with args.output.open('a') as f: f.write(json.dumps(row,ensure_ascii=False)+'\n')
            except (RuntimeError, subprocess.SubprocessError, OSError) as error:
                if args.count != 0:
                    raise
                # Keep the monitor alive across USB re-enumeration. A failed
                # transfer emits an offline record, never an old sensor sample.
                offline={'hostTime':datetime.now(timezone.utc).isoformat(),
                         'linkOnline':False, 'samplingConfirmed':False,
                         'error':str(error)[-1800:]}
                print(json.dumps(offline,ensure_ascii=False),flush=True)
                if args.output:
                    args.output.parent.mkdir(parents=True,exist_ok=True)
                    with args.output.open('a') as f:
                        f.write(json.dumps(offline,ensure_ascii=False)+'\n')
                last_polls=None; changed_at=None
                time.sleep(3)
                continue
            i+=1
            if args.count==0 or i<args.count: time.sleep(max(.5,args.interval))


if __name__=='__main__':
    try: main()
    except KeyboardInterrupt: print('已停止读取，主控继续运行。')
