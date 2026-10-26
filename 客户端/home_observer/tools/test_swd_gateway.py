import struct
import unittest
import swd_gateway as gateway

class GatewayTest(unittest.TestCase):
    def setUp(self):
        gateway.previous.clear()
        gateway.last_change.clear()
        self.symbols = {'g_dht': (0, 60), 'g_light': (60, 52)}

    def ram(self, count):
        raw = [13, 6, 23, 2, 44]
        d = struct.pack('<9IiI5B3x2I', count, 0, 1, 0, 0, 5, 0, 1, 1, 232, 136, *raw, 1, 0)
        l = struct.pack('<13I', count, count, 0, 0, 1, 1, 0x23, 420, 3500, 1, 1, 1, 0x10)
        return d+l

    def test_counter_freshness_range_and_freeze(self):
        initial = gateway.decode(self.ram(1), self.symbols, 0, 10)
        self.assertTrue(all(s['status'] == 'stale' for s in initial))
        fresh = gateway.decode(self.ram(2), self.symbols, 0, 13)
        self.assertEqual([s['status'] for s in fresh], ['valid', 'valid', 'valid'])
        self.assertEqual(fresh[2]['value'], 350)
        frozen = gateway.decode(self.ram(2), self.symbols, 0, 20)
        self.assertTrue(all(s['status'] == 'stale' for s in frozen))

    def test_checksum_failure_never_valid(self):
        gateway.decode(self.ram(1), self.symbols, 0, 10)
        broken = bytearray(self.ram(2)); broken[44] ^= 1
        result = gateway.decode(broken, self.symbols, 0, 13)
        self.assertEqual(result[0]['status'], 'invalid')
        self.assertIsNone(result[0]['value'])

if __name__ == '__main__': unittest.main()
