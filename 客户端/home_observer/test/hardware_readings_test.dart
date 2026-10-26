import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_observer/data/hardware_readings.dart';

Map<String, dynamic> frame() => {
  'version': 1,
  'session': 'test-board',
  'seq': 7,
  'readAt': DateTime.utc(2026, 10, 21).toIso8601String(),
  'bridgeAgeSeconds': 0.3,
  'error': null,
  'samples': [
    <String, dynamic>{
      'id': 1,
      'value': 23.2,
      'status': 'valid',
      'attempts': 12,
      'ageSeconds': 0.1,
    },
    <String, dynamic>{
      'id': 2,
      'value': 13.6,
      'status': 'valid',
      'attempts': 12,
      'ageSeconds': 0.1,
    },
    <String, dynamic>{
      'id': 3,
      'value': 350.0,
      'status': 'valid',
      'attempts': 60,
      'ageSeconds': 0.1,
    },
  ],
};
void main() {
  test(
    'displays dry-environment humidity normally without changing readings',
    () {
      final parsed = HardwareFrame.parse(jsonEncode(frame()));
      expect(parsed.samples[2].value, 350);
      expect(parsed.samples[1].status, 'valid');
      expect(parsed.samples[1].value, 13.6);
    },
  );
  test('rejects duplicate or missing modules and unsafe valid values', () {
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (j) => j['samples'][2]['id'] = 1,
      (j) => j['samples'].removeLast(),
      (j) => j['samples'][1]['value'] = 101,
      (j) => j['samples'][0]['value'] = null,
      (j) => j['samples'][2]['ageSeconds'] = -1,
      (j) => j['version'] = 2,
    ]) {
      final j = frame();
      mutate(j);
      expect(() => HardwareFrame.parse(jsonEncode(j)), throwsFormatException);
    }
  });
  test('accepts disconnected startup with no invented readings', () {
    final parsed = HardwareFrame.parse(
      jsonEncode({
        'version': 1,
        'session': 'startup',
        'seq': 0,
        'samples': [],
        'error': 'ST-LINK不可用',
        'bridgeAgeSeconds': null,
      }),
    );
    expect(parsed.samples, isEmpty);
    expect(parsed.error, 'ST-LINK不可用');
  });
  test('accepts real USB serial RFID and rejects malformed UID', () {
    final j = frame();
    j['transport'] = 'USB-TTL';
    j['rfid'] = <String, dynamic>{
      'status': 2,
      'uid': 'A1B2C3D4',
      'eventSeq': 3,
      'cardReads': 111,
      'ageSeconds': 0.2,
    };
    final parsed = HardwareFrame.parse(jsonEncode(j));
    expect(parsed.transport, 'USB-TTL');
    expect(parsed.rfid!.uid, 'A1B2C3D4');
    (j['rfid'] as Map<String, dynamic>)['uid'] = 'bad';
    expect(() => HardwareFrame.parse(jsonEncode(j)), throwsFormatException);
  });
}
