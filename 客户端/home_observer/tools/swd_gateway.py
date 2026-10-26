#!/usr/bin/env python3
"""Local development bridge: read running STM32 RAM; never flash/reset/halt."""
import argparse
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import importlib.util
import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import threading
import time
import uuid

PROJECT = Path(os.environ.get('HOME_OBSERVER_BOARD_PROJECT',
    Path(__file__).resolve().parents[3] / '硬件/温湿度与光照')).expanduser().resolve()
state_lock = threading.Lock()
state = {'version': 1, 'session': uuid.uuid4().hex, 'seq': 0,
         'samples': [], 'error': '等待首次硬件读取'}
last_change = {}
previous = {}


def sample(sensor_id, value, status, attempts, now):
    if previous.get(sensor_id) != attempts:
        # First observation does not prove that the firmware is still sampling.
        if sensor_id in previous:
            last_change[sensor_id] = now
        previous[sensor_id] = attempts
    changed = last_change.get(sensor_id)
    age = None if changed is None else max(0, now - changed)
    if age is None or age > 6:
        status = 'stale'
    return {'id': sensor_id, 'value': value, 'status': status,
            'attempts': attempts, 'ageSeconds': age}


def decode(data, symbols, begin, now):
    d = struct.unpack_from('<9IiI5B3x2I', data, symbols['g_dht'][0] - begin)
    l = struct.unpack_from('<13I', data, symbols['g_light'][0] - begin)
    frame_ok = bool(d[16]) and (sum(d[11:15]) & 255) == d[15]
    frame_ok = frame_ok and d[5] in (1, 5)
    t, h = d[9] / 10, d[10] / 10
    temp_status = 'valid' if frame_ok and -20 <= t <= 60 else 'invalid'
    # User display policy: dry-environment RH is normal.
    humidity_status = 'valid' if frame_ok and 0 <= h <= 100 else 'invalid'
    light_ok = l[4] == 1 and l[5] == 1 and l[6] == 0x23 and l[7] < 65535
    return [sample(1, t if frame_ok else None, temp_status, d[0], now),
            sample(2, h if frame_ok else None, humidity_status, d[0], now),
            sample(3, l[8] / 10 if light_ok else None,
                   'valid' if light_ok else 'invalid', l[0], now)]


def collect(stop):
    spec = importlib.util.spec_from_file_location('board_reader', PROJECT / 'tools/read_sensors.py')
    reader = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(reader)
    cli = reader.tool('STM32_PROGRAMMER_CLI', 'CubeProgrammer', 'programmer/*/bin/STM32_Programmer_CLI')
    nm = reader.tool('ARM_NM', 'nm', 'gnu-tools-for-stm32/*/bin/arm-none-eabi-nm')
    listing = subprocess.check_output([str(nm), '-S', str(PROJECT / 'build/Debug/home_observer_board_test.elf')], text=True)
    symbols = {}
    for line in listing.splitlines():
        f = line.split()
        if len(f) >= 4 and f[-1] in ('g_dht', 'g_light'):
            symbols[f[-1]] = (int(f[0], 16), int(f[1], 16))
    if set(symbols) != {'g_dht', 'g_light'} or symbols['g_dht'][1] != 60 or symbols['g_light'][1] != 52:
        raise RuntimeError('ELF调试结构不匹配')
    begin = min(s[0] for s in symbols.values())
    end = max(s[0] + s[1] for s in symbols.values())
    with tempfile.TemporaryDirectory(prefix='iot-gateway-') as td:
        path = Path(td) / 'ram.bin'
        while not stop.is_set():
            try:
                path.unlink(missing_ok=True)
                p = subprocess.run([str(cli), '-c', 'port=SWD', 'freq=4000', 'mode=HOTPLUG',
                                    '-u', hex(begin), str(end-begin), str(path)],
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=12)
                if p.returncode or 'Error:' in p.stdout or not path.exists():
                    raise RuntimeError('ST-LINK读取失败：检查USB连接、供电，关闭其他调试/读数任务')
                data = path.read_bytes()
                if len(data) != end - begin:
                    raise RuntimeError('RAM长度不一致')
                samples = decode(data, symbols, begin, time.monotonic())
                with state_lock:
                    state.update(seq=state['seq'] + 1, samples=samples, error=None,
                                 readAt=datetime.now(timezone.utc).isoformat(), _received=time.monotonic())
                print(json.dumps({k:v for k,v in state.items() if not k.startswith('_')}, ensure_ascii=False), flush=True)
            except Exception as e:
                with state_lock:
                    state['error'] = str(e)
                print(str(e), flush=True)
            stop.wait(3)


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != '/v1/readings':
            self.send_error(404)
            return
        with state_lock:
            result = {k:v for k,v in state.items() if not k.startswith('_')}
            result['bridgeAgeSeconds'] = max(0, time.monotonic() - state['_received']) if '_received' in state else None
        body = json.dumps(result, ensure_ascii=False).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_):
        pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8765)
    args = parser.parse_args()
    server = ThreadingHTTPServer(('127.0.0.1', args.port), Handler)
    stop = threading.Event()
    def worker():
        try:
            collect(stop)
        except Exception as e:
            with state_lock:
                state['error'] = str(e)
            print(str(e), flush=True)
    threading.Thread(target=worker, daemon=True).start()
    print(f'只读硬件转发 http://127.0.0.1:{args.port}/v1/readings；Ctrl+C停止', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        stop.set()
        server.server_close()


if __name__ == '__main__':
    main()
