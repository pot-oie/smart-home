"""IOT1 ASCII telemetry with CRC16/CCITT-FALSE. No ST tools or ELF required."""
import re
import uuid


def crc16(data):
    crc=0xffff
    for b in data:
        crc^=b<<8
        for _ in range(8): crc=((crc<<1)^0x1021 if crc&0x8000 else crc<<1)&0xffff
    return crc


def parse_line(line):
    if len(line)>320: raise ValueError('帧过长')
    line=line.strip(b'\r\n')
    body, checksum=line.rsplit(b'*',1)
    if not re.fullmatch(rb'[0-9A-Fa-f]{4}',checksum) or crc16(body)!=int(checksum,16):
        raise ValueError('帧校验失败')
    f=body.decode('ascii').split(',')
    if len(f)!=19 or f[0]!='IOT1': raise ValueError('帧格式或版本错误')
    keys=['seq','uptime','dhtAttempts','dhtOK','temperature10','humidity10',
          'lightAttempts','lightOK','lux10','rfidPolls','rfidStatus','chipVersion',
          'eventSeq','cardReads','lastSeenMs','uid','sak','atqa']
    row={}
    for key,value in zip(keys,f[1:]):
        if key=='uid':
            if value!='-' and (len(value) not in (8,14,20) or not re.fullmatch('[0-9A-F]+',value)):
                raise ValueError('卡号格式错误')
            row[key]=None if value=='-' else value
        else:
            if not re.fullmatch(r'-?[0-9]{1,10}',value): raise ValueError('数值格式错误')
            n=int(value)
            if key=='temperature10':
                if not -10000<=n<=10000: raise ValueError('温度字段错误')
            elif not 0<=n<=0xffffffff: raise ValueError('计数字段错误')
            row[key]=n
    if row['dhtOK'] not in (0,1) or row['lightOK'] not in (0,1) or row['rfidStatus']>6 or row['chipVersion']>255 or row['sak']>255 or row['atqa']>65535:
        raise ValueError('状态字段错误')
    if row['rfidStatus']==2 and row['uid'] is None: raise ValueError('缺少已读卡号')
    if row['seq']==0: raise ValueError('帧序号错误')
    return row


class Telemetry:
    def __init__(self):
        self.session=uuid.uuid4().hex
        self.last=None
        self.counts={}
        self.changed={}
        self.rfid_events=[]
        self.last_event=0

    def update(self,row,now):
        if self.last is not None:
            if (row['uptime']<self.last['uptime'] or row['seq']<self.last['seq'] or
                (row['seq']==self.last['seq'] and row['uptime']!=self.last['uptime'])):
                self.session=uuid.uuid4().hex
                self.counts.clear(); self.changed.clear(); self.rfid_events=[]; self.last_event=0
            elif row['seq']<=self.last['seq']:
                raise ValueError('重复或倒序帧')
        self.last=dict(row)
        samples=[]
        for sid,count,value,ok in [
            (1,row['dhtAttempts'],row['temperature10']/10,row['dhtOK'] and -200<=row['temperature10']<=600),
            (2,row['dhtAttempts'],row['humidity10']/10,row['dhtOK'] and 0<=row['humidity10']<=1000),
            (3,row['lightAttempts'],row['lux10']/10,row['lightOK'] and row['lux10']<=546125)]:
            if sid in self.counts and self.counts[sid]!=count: self.changed[sid]=now
            self.counts[sid]=count
            age=now-self.changed[sid] if sid in self.changed else None
            status='valid' if ok else 'invalid'
            if age is None or age>6: status='stale'
            samples.append({'id':sid,'attempts':count,'value':value if ok else None,
                            'status':status,'ageSeconds':age})
        polls=row['rfidPolls']
        if 4 in self.counts and self.counts[4]!=polls: self.changed[4]=now
        self.counts[4]=polls
        rfid_age=now-self.changed[4] if 4 in self.changed else None
        if row['eventSeq']>self.last_event and row['uid']:
            self.rfid_events.insert(0,{'eventSeq':row['eventSeq'],'uid':row['uid']})
            self.rfid_events=self.rfid_events[:20]
        self.last_event=row['eventSeq']
        return {'version':1,'session':self.session,'seq':row['seq'],'samples':samples,
                'transport':'USB-TTL','deviceUptimeMs':row['uptime'],
                'rfid':{'status':row['rfidStatus'],'version':row['chipVersion'],
                        'polls':polls,'cardReads':row['cardReads'],'eventSeq':row['eventSeq'],
                        'uid':row['uid'],'ageSeconds':rfid_age,
                        'lastSeenAgeSeconds':((row['uptime']-row['lastSeenMs'])&0xffffffff)/1000 if row['uid'] else None,
                        'events':list(self.rfid_events)}}
