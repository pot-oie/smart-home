import os
import pty
import threading
import time
import unittest
import serial_gateway as gateway
from test_serial_protocol import frame

class SerialGatewayTest(unittest.TestCase):
    def test_posix_serial_receives_crc_frames_and_reports_disconnect(self):
        master,slave=pty.openpty();device=os.ttyname(slave)
        os.set_blocking(master,False)
        stop=threading.Event()
        worker=threading.Thread(target=gateway.collect,args=(device,stop),daemon=True)
        worker.start()
        try:
            # Keep sending until the port setup/flush has completed.
            deadline=time.monotonic()+4;seq=1
            while time.monotonic()<deadline:
                try:os.write(master,b'noise\n'+frame(seq,seq*1000,seq+10))
                except BlockingIOError:pass
                seq+=1
                time.sleep(.12)
                with gateway.lock:
                    if gateway.state.get('seq',0)>=2: break
            with gateway.lock:
                self.assertEqual(gateway.state['transport'],'USB-TTL')
                self.assertEqual(gateway.state['rfid']['uid'],'A1B2C3D4')
                self.assertIsNone(gateway.state['error'])
                self.assertGreater(gateway.state['invalidFrames'],0)
            os.close(master);master=None
            deadline=time.monotonic()+2
            while time.monotonic()<deadline:
                with gateway.lock:
                    if gateway.state['error'] is not None: break
                time.sleep(.05)
            with gateway.lock:self.assertIsNotNone(gateway.state['error'])
        finally:
            stop.set()
            if master is not None:os.close(master)
            os.close(slave)
            worker.join(3)

if __name__=='__main__':unittest.main()
