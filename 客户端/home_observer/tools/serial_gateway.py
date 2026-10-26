#!/usr/bin/env python3
"""USB-TTL serial upload to local client HTTP; Python stdlib only, no ST dependency."""
import argparse
from datetime import datetime,timezone
import fcntl
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
import json
import os
from pathlib import Path
import select
import termios
import threading
import time
import tty
from serial_protocol import parse_line,Telemetry

lock=threading.Lock()
state={'version':1,'session':'starting','seq':0,'samples':[],'error':'等待串口数据','transport':'USB-TTL'}


def collect(device,stop,record=None):
    while not stop.is_set():
        fd=None
        try:
            fd=os.open(device,os.O_RDWR|os.O_NOCTTY|os.O_NONBLOCK)
            if hasattr(termios,'TIOCEXCL'): fcntl.ioctl(fd,termios.TIOCEXCL)
            tty.setraw(fd,termios.TCSANOW)
            attrs=termios.tcgetattr(fd)
            attrs[2]=(attrs[2]&~(termios.PARENB|termios.CSTOPB|termios.CSIZE))|termios.CS8|termios.CREAD|termios.CLOCAL
            if hasattr(termios,'CRTSCTS'): attrs[2]&=~termios.CRTSCTS
            attrs[4]=termios.B9600; attrs[5]=termios.B9600
            termios.tcsetattr(fd,termios.TCSANOW,attrs)
            termios.tcflush(fd,termios.TCIFLUSH)
            telemetry=Telemetry(); buffer=bytearray(); received=time.monotonic(); invalid=0
            print('已打开 '+device+' · 9600 8N1，等待完整校验帧',flush=True)
            while not stop.is_set():
                ready,_,_=select.select([fd],[],[],.5)
                if not ready:
                    if time.monotonic()-received>6:
                        with lock: state['error']='串口超过6秒未收到有效上传帧'
                    continue
                part=os.read(fd,4096)
                if not part: raise OSError('串口已断开')
                buffer.extend(part)
                while b'\n' in buffer:
                    line,_,rest=buffer.partition(b'\n');buffer=bytearray(rest)
                    try:
                        row=parse_line(bytes(line)); now=time.monotonic()
                        snapshot=telemetry.update(row,now)
                    except (ValueError,UnicodeError):
                        invalid+=1
                        continue
                    received=now
                    snapshot.update(readAt=datetime.now(timezone.utc).isoformat(),error=None,
                                    invalidFrames=invalid,_received=now)
                    with lock: state.clear();state.update(snapshot)
                    output={k:v for k,v in snapshot.items() if not k.startswith('_')}
                    print(json.dumps(output,ensure_ascii=False),flush=True)
                    if record:
                        with record.open('a') as f:f.write(json.dumps(output,ensure_ascii=False)+'\n')
                if len(buffer)>640: buffer.clear();invalid+=1
                if time.monotonic()-received>6:
                    with lock:state['error']='连续数据未通过帧校验或停止更新'
        except (OSError,termios.error) as e:
            with lock:state['error']='串口连接中断：'+str(e)
            print(state['error'],flush=True)
        finally:
            if fd is not None:os.close(fd)
        stop.wait(2)


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path!='/v1/readings':self.send_error(404);return
        with lock:
            result={k:v for k,v in state.items() if not k.startswith('_')}
            result['bridgeAgeSeconds']=max(0,time.monotonic()-state['_received']) if '_received' in state else None
        body=json.dumps(result,ensure_ascii=False).encode()
        self.send_response(200);self.send_header('Content-Type','application/json; charset=utf-8')
        self.send_header('Cache-Control','no-store');self.send_header('Content-Length',str(len(body)))
        self.end_headers();self.wfile.write(body)
    def log_message(self,*_):pass


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--device',required=True)
    ap.add_argument('--port',type=int,default=8765)
    ap.add_argument('--record',type=Path)
    args=ap.parse_args()
    if args.record: args.record.parent.mkdir(parents=True,exist_ok=True)
    server=ThreadingHTTPServer(('127.0.0.1',args.port),Handler)
    stop=threading.Event()
    threading.Thread(target=collect,args=(args.device,stop,args.record),daemon=True).start()
    print(f'USB-TTL上传服务 http://127.0.0.1:{args.port}/v1/readings；无需ST工具或ELF',flush=True)
    try:server.serve_forever()
    except KeyboardInterrupt:pass
    finally:stop.set();server.server_close()

if __name__=='__main__':main()
