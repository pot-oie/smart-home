import 'dart:async';
import 'dart:convert';
import 'dart:io';

class HardwareReading {
  const HardwareReading(
    this.id,
    this.value,
    this.status,
    this.attempts,
    this.age,
  );
  final int id, attempts;
  final double? value, age;
  final String status;
}

class HardwareFrame {
  HardwareFrame(
    this.session,
    this.seq,
    this.readAt,
    this.samples,
    this.error,
    this.bridgeAge,
  );
  final String session;
  final int seq;
  final DateTime? readAt;
  final List<HardwareReading> samples;
  final String? error;
  final double? bridgeAge;
  factory HardwareFrame.parse(String text) {
    final j = jsonDecode(text) as Map<String, dynamic>;
    if (j['version'] != 1 ||
        j['session'] is! String ||
        (j['session'] as String).isEmpty ||
        j['seq'] is! int ||
        j['seq'] < 0) {
      throw const FormatException('硬件数据版本或序号无效');
    }
    double? finite(dynamic v) {
      if (v == null) return null;
      if (v is! num || !v.isFinite) throw const FormatException('读数无效');
      return v.toDouble();
    }

    final seen = <int>{};
    final samples = (j['samples'] as List).map((dynamic item) {
      final s = item as Map<String, dynamic>;
      final id = s['id'];
      final count = s['attempts'];
      final status = s['status'];
      if (id is! int ||
          ![1, 2, 3].contains(id) ||
          !seen.add(id) ||
          count is! int ||
          count < 0 ||
          !['valid', 'invalid', 'stale'].contains(status)) {
        throw const FormatException('硬件样本无效');
      }
      final value = finite(s['value']);
      final age = finite(s['ageSeconds']);
      if ((age != null && age < 0) ||
          (status == 'valid' && (value == null || age == null)) ||
          (id == 1 && status == 'valid' && (value! < -20 || value > 60)) ||
          (id == 2 && status == 'valid' && (value! < 0 || value > 100)) ||
          (id == 3 && status == 'valid' && (value! < 0 || value > 54612.5))) {
        throw const FormatException('样本范围或时间无效');
      }
      return HardwareReading(id, value, status as String, count, age);
    }).toList();
    final seq = j['seq'] as int;
    if (seq > 0 && (seen.length != 3 || j['readAt'] is! String)) {
      throw const FormatException('缺少硬件样本');
    }
    final bridgeAge = finite(j['bridgeAgeSeconds']);
    if (bridgeAge != null && bridgeAge < 0) throw const FormatException('时间无效');
    return HardwareFrame(
      j['session'],
      seq,
      j['readAt'] == null ? null : DateTime.parse(j['readAt']),
      samples,
      j['error'] as String?,
      bridgeAge,
    );
  }
}

class HardwareClient {
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 2);
  Future<HardwareFrame> read() async {
    final request = await _client
        .getUrl(Uri.parse('http://127.0.0.1:8765/v1/readings'))
        .timeout(const Duration(seconds: 2));
    final response = await request.close().timeout(const Duration(seconds: 2));
    if (response.statusCode != 200) throw const HttpException('转发服务不可用');
    final bytes = <int>[];
    await for (final part in response.timeout(const Duration(seconds: 2))) {
      bytes.addAll(part);
      if (bytes.length > 16384) throw const FormatException('响应过大');
    }
    return HardwareFrame.parse(utf8.decode(bytes));
  }

  void close() => _client.close(force: true);
}
