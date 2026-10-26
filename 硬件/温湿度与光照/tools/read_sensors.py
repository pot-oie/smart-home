#!/usr/bin/env python3
"""Read running MCU RAM through SWD HOTPLUG; never writes, resets or halts it."""
import argparse, json, os, re, struct, subprocess, sys, tempfile, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parents[1] / 'tools'))
from stm32_tools import find_tool

def tool(env,name,pattern):
    return find_tool(env, 'arm-none-eabi-nm' if name=='nm' else name, pattern)

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--count',type=int,default=0,help='0=持续读取，Ctrl+C结束')
    ap.add_argument('--interval',type=float,default=3)
    ap.add_argument('--output',type=Path)
    a=ap.parse_args()
    cli=tool('STM32_PROGRAMMER_CLI','CubeProgrammer','programmer/*/bin/STM32_Programmer_CLI')
    nm=tool('ARM_NM','arm-none-eabi-nm','gnu-tools-for-stm32/*/bin/arm-none-eabi-nm')
    elf=ROOT/'build/Debug/home_observer_board_test.elf'
    if not elf.exists():raise RuntimeError('请先生成Debug ELF，并确认主控烧录的是同一版本。')
    listing=subprocess.check_output([str(nm),'-S',str(elf)],text=True)
    syms={}
    for line in listing.splitlines():
        fields=line.split()
        if len(fields)>=4 and fields[-1] in ['g_dht','g_light']:
            syms[fields[-1]]=(int(fields[0],16),int(fields[1],16))
    if set(syms)!=set(['g_dht','g_light']):raise RuntimeError('ELF缺少双模块调试符号，请检查构建版本。')
    if syms['g_dht'][1]!=60 or syms['g_light'][1]!=52:raise RuntimeError('数据结构版本不匹配，请同步更新读取脚本。')
    begin=min(v[0] for v in syms.values());end=max(v[0]+v[1] for v in syms.values())
    dkeys=['attempts','good_reads','bad_reads','last_good_ms','valid','status','nack_stage','scl_idle','sda_idle','temperature_tenths','humidity_tenths']
    lkeys=['attempts','good_reads','bad_reads','last_good_ms','valid','status','address','raw','lux_tenths','scl_idle','sda_idle','configured','last_command']
    light_states={0:'等待转换',1:'正常',2:'无应答',3:'总线低/超时',4:'饱和'}
    dht_states={0:'等待',1:'正常',2:'无应答',3:'校验失败',4:'总线低/超时',5:'量程外'}
    print('双模块实时读数 | 只读SWD，不复位、不停止采集 | Ctrl+C结束',flush=True)
    print('提示：请关闭其他占用ST-Link的调试会话；工程ELF必须与主控所烧录版本一致。',flush=True)
    rows=[];i=0
    with tempfile.TemporaryDirectory(prefix='iot-sensors-') as td:
        while a.count==0 or i<a.count:
            f=Path(td)/'ram.bin'
            if f.exists():f.unlink()
            p=subprocess.run([str(cli),'-c','port=SWD','freq=4000','mode=HOTPLUG','-u',hex(begin),str(end-begin),str(f)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=30)
            log=re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]','',p.stdout)
            if p.returncode or 'Error:' in log or not f.exists():raise RuntimeError('ST-Link读取失败，检查USB、供电及工具占用。\n'+log[-1800:])
            data=f.read_bytes()
            if len(data)!=end-begin:raise RuntimeError('RAM读取长度不一致。')
            d=struct.unpack_from('<9IiI5B3x2I',data,syms['g_dht'][0]-begin)
            l=struct.unpack_from('<13I',data,syms['g_light'][0]-begin)
            dh=dict(zip(dkeys,d[:11]));dh.update(raw=list(d[11:16]),frame_valid=d[16],within_spec=d[17])
            dh['checksum_ok']=(sum(dh['raw'][:4])&255)==dh['raw'][4]
            li=dict(zip(lkeys,l));stamp=time.strftime('%Y-%m-%d %H:%M:%S')
            row={'host_time':stamp,'dht':dh,'light':li};rows.append(row)
            # A retained value is never displayed as current after frame/transfer failure.
            ds=dht_states.get(dh['status'],'未知状态')
            dt=(f"温度 {dh['temperature_tenths']/10:.1f}℃ | 湿度 {dh['humidity_tenths']/10:.1f}%RH [{ds}]"
                if dh['frame_valid'] else f'温湿度 -- [{ds}]')
            ls=light_states.get(li['status'],'未知状态')
            lt=(f"光照 {li['lux_tenths']/10:.1f} lx [{ls}]" if li['valid'] else f'光照 -- [{ls}]')
            print(f"{stamp} | {dt} | {lt} | 采样计数 温湿度={dh['attempts']} 光照={li['attempts']}",flush=True)
            if a.output:
                a.output.parent.mkdir(parents=True,exist_ok=True)
                a.output.write_text(json.dumps(rows,ensure_ascii=False,indent=2))
            i+=1
            if a.count==0 or i<a.count:time.sleep(max(a.interval,0.5))
if __name__=='__main__':
    try:main()
    except KeyboardInterrupt:print('\n已停止读数；主控继续运行。')
    except (RuntimeError,subprocess.SubprocessError) as e:print(str(e),file=sys.stderr);sys.exit(1)
