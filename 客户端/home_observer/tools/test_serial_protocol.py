import unittest
from serial_protocol import crc16,parse_line,Telemetry


def frame(seq=1,uptime=1000,count=10):
    body=f'IOT1,{seq},{uptime},{count},0,232,136,{count},0,3500,{count},2,130,3,111,900,A1B2C3D4,8,4'.encode()
    return body+f'*{crc16(body):04X}\r\n'.encode()


class SerialProtocolTest(unittest.TestCase):
    def test_known_crc_vector(self):
        self.assertEqual(crc16(b'123456789'),0x29b1)

    def test_hardware_fields_and_invalid_modules(self):
        t=Telemetry()
        t.update(parse_line(frame()),1)
        got=t.update(parse_line(frame(2,2000,11)),2)
        self.assertEqual(got['transport'],'USB-TTL')
        self.assertEqual(got['rfid']['uid'],'A1B2C3D4')
        self.assertTrue(all(s['status']=='invalid' and s['value'] is None for s in got['samples']))
        self.assertEqual(len(got['rfid']['events']),1)

    def test_crc_corruption_and_malformed_uid(self):
        bad=bytearray(frame());bad[12]^=1
        with self.assertRaises(ValueError):parse_line(bytes(bad))
        body=frame().split(b'*')[0].replace(b'A1B2C3D4',b'1234')
        with self.assertRaises(ValueError):parse_line(body+f'*{crc16(body):04X}'.encode())

    def test_duplicate_and_device_restart(self):
        t=Telemetry();r=parse_line(frame(10,10000));t.update(r,1)
        with self.assertRaises(ValueError):t.update(r,2)
        old=t.session;t.update(parse_line(frame(1,1000)),3)
        self.assertNotEqual(t.session,old)

    def test_frozen_module_not_freshened_by_upload(self):
        t=Telemetry();t.update(parse_line(frame()),1)
        t.update(parse_line(frame(2,2000,11)),2)
        got=t.update(parse_line(frame(3,9000,11)),9)
        self.assertTrue(all(s['status']=='stale' for s in got['samples']))
        self.assertEqual(got['rfid']['ageSeconds'],7)

if __name__=='__main__':unittest.main()
