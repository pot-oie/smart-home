#!/usr/bin/env python3
"""Run only after physical R4 wiring is checked. Backup, program, verify and run."""
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
from read_rfid import ROOT, tool, layout


def main():
    elf=ROOT/'build/Debug/home_observer_board_test.elf'
    layout(elf)  # Refuse incompatible binaries.
    out=ROOT.parents[1]/'artifacts/rfid'/datetime.now().strftime('flash_%Y%m%d_%H%M%S')
    out.mkdir(parents=True,exist_ok=False)
    cli=tool('programmer/*/bin/STM32_Programmer_CLI')
    base=[cli,'-c','port=SWD','freq=4000','mode=NORMAL','reset=SWrst']
    def run(args, name):
        p=subprocess.run(base+args,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=60)
        log=re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]','',p.stdout)
        (out/name).write_text(log)
        if p.returncode or 'Error:' in log: raise RuntimeError(log[-2000:])
        return log
    backup=out/'写入前主控Flash64KB.bin'
    run(['-u','0x08000000','0x10000',str(backup)],'01_备份.log')
    if not backup.exists() or backup.stat().st_size!=65536:
        raise RuntimeError('备份不完整，禁止写入')
    copy=out/'RFID_已写入.elf'
    shutil.copy2(elf,copy)
    log=run(['-w',str(copy),'-v','-rst','-run'],'02_烧录校验运行.log')
    # Verify bytes independently; Programmer wording varies between releases.
    expected=out/'expected.bin'
    subprocess.run([tool('gnu-tools-for-stm32/*/bin/arm-none-eabi-objcopy'),
                    '-O','binary',str(copy),str(expected)],check=True)
    actual=out/'readback.bin'
    run(['-u','0x08000000',str(expected.stat().st_size),str(actual)],'03_回读.log')
    if not actual.exists() or actual.read_bytes()!=expected.read_bytes():
        raise RuntimeError('Flash回读与固件不匹配，请检查日志；不要盲目重复写入')
    run(['-rst','-run'],'04_运行.log')
    (out/'版本.json').write_text(json.dumps({'elf':str(elf),'sha256':hashlib.sha256(copy.read_bytes()).hexdigest(),
        'backupSHA256':hashlib.sha256(backup.read_bytes()).hexdigest(),'symbols':layout(copy)},indent=2))
    print('备份、写入、校验和运行命令已完成；尚需读卡实测。记录：'+str(out))


if __name__=='__main__': main()
