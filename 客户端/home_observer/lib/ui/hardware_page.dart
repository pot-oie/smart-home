import 'dart:async';
import 'package:flutter/material.dart';
import '../data/hardware_readings.dart';
import 'style.dart';

class HardwarePage extends StatefulWidget {
  const HardwarePage({super.key});
  @override
  State<HardwarePage> createState() => _HardwarePageState();
}

class _HardwarePageState extends State<HardwarePage> {
  final _client = HardwareClient();
  Timer? _timer;
  HardwareFrame? _frame;
  String? _error;
  bool _busy = false;
  DateTime? _lastNewFrame;
  final _clock = Stopwatch()..start();
  Duration? _receivedTick, _newTick;
  final List<String> _recent = [];

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
  }

  Future<void> _poll() async {
    if (_busy) return;
    _busy = true;
    try {
      final next = await _client.read();
      if (!mounted) return;
      if (_frame != null &&
          _frame!.session == next.session &&
          next.seq < _frame!.seq) {
        throw const FormatException('硬件序号倒退');
      }
      final isNew =
          _frame == null ||
          next.session != _frame!.session ||
          next.seq > _frame!.seq;
      setState(() {
        if (isNew && next.seq > 0) {
          _lastNewFrame = DateTime.now();
          _newTick = _clock.elapsed;
          final light = next.samples.where((s) => s.id == 3).firstOrNull;
          if (light?.status == 'valid' &&
              next.error == null &&
              (next.bridgeAge ?? 99) <= 6) {
            _recent.insert(
              0,
              '${hm(next.readAt?.toLocal())}  光照 ${light!.value!.toStringAsFixed(1)} lx',
            );
            if (_recent.length > 8) _recent.removeLast();
          }
        }
        _frame = next;
        _receivedTick = _clock.elapsed;
        _error = next.error;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '连接中断，请检查 Mac 接收服务和数据连接');
    } finally {
      _busy = false;
    }
  }

  bool get _live =>
      _error == null &&
      _frame != null &&
      _frame!.seq > 0 &&
      (_frame!.bridgeAge ?? 99) +
              (_receivedTick == null
                  ? 99
                  : (_clock.elapsed - _receivedTick!).inMilliseconds / 1000) <=
          6 &&
      _newTick != null &&
      _clock.elapsed - _newTick! <= const Duration(seconds: 6);

  Widget _sensor(int id, String name, String unit, String source) {
    final s = _frame?.samples.where((s) => s.id == id).firstOrNull;
    final elapsed = _receivedTick == null
        ? 99.0
        : (_clock.elapsed - _receivedTick!).inMilliseconds / 1000;
    final age = (s?.age ?? 99) + (_frame?.bridgeAge ?? 99) + elapsed;
    final status = !_live || age > 6 ? 'stale' : s?.status ?? 'stale';
    final readable = status == 'valid' && s?.value != null;
    final label = switch (status) {
      'valid' => '正常',
      'invalid' => '读取异常',
      _ => '等待更新',
    };
    return CreamCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: Warm.title(21))),
              WarmBadge(
                label,
                color: status == 'valid' ? Warm.blue : Warm.clay,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            readable ? '${s!.value!.toStringAsFixed(1)} $unit' : '— $unit',
            style: Warm.title(36),
          ),
          const SizedBox(height: 8),
          Text(
            '$source · 采样次数 ${s?.attempts ?? '—'}',
            style: const TextStyle(color: Warm.muted),
          ),
        ],
      ),
    );
  }

  Widget _rfid() {
    final r = _frame!.rfid!;
    final elapsed = _receivedTick == null
        ? 99.0
        : (_clock.elapsed - _receivedTick!).inMilliseconds / 1000;
    final fresh =
        _live && (r.age ?? 99) + (_frame?.bridgeAge ?? 99) + elapsed <= 6;
    final label = !fresh
        ? '等待更新'
        : switch (r.status) {
            1 => '等待刷卡',
            2 => '卡号已读取',
            0 => '初始化',
            _ => '读卡异常',
          };
    final uid = r.uid;
    final formatted = uid == null
        ? '—'
        : RegExp(r'.{2}').allMatches(uid).map((m) => m.group(0)).join(' ');
    return CreamCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('RFID 读卡', style: Warm.title(21))),
              WarmBadge(label, color: fresh ? Warm.blue : Warm.clay),
            ],
          ),
          const SizedBox(height: 14),
          const Text('最近读到的卡号', style: TextStyle(color: Warm.muted)),
          const SizedBox(height: 6),
          Text(fresh ? formatted : '—', style: Warm.title(25)),
          const SizedBox(height: 10),
          Text(
            '刷卡事件 ${r.eventSeq} · 成功读取 ${r.cardReads} 次',
            style: const TextStyle(color: Warm.muted),
          ),
          const Text('当前验证卡号上传，授权判断尚未接入。', style: TextStyle(color: Warm.muted)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: PageBody(
        title: '家中的此刻',
        large: true,
        children: [
          Row(
            children: [
              const WarmBadge('真实硬件', color: Warm.clay),
              if (_frame?.transport == 'USB-TTL') ...[
                const SizedBox(width: 8),
                const WarmBadge('USB 串口', color: Warm.blue),
              ],
              const SizedBox(width: 8),
              WarmBadge(_live ? '数据更新中' : '等待连接', color: Warm.blue),
            ],
          ),
          const SizedBox(height: 14),
          if (_error != null)
            CreamCard(
              child: Text(_error!, style: const TextStyle(color: Warm.clay)),
            ),
          if (_frame?.rfid != null) _rfid(),
          _sensor(1, '温度', '°C', 'H02 · DHT12'),
          _sensor(2, '湿度', '%RH', 'H02 · DHT12'),
          _sensor(3, '光照', 'lx', 'H03 · BH1750'),
          Text(
            '最近接收：${hm(_lastNewFrame)} · 数据序号 ${_frame?.seq ?? 0}',
            style: const TextStyle(color: Warm.muted),
          ),
          const SizedBox(height: 16),
          const SectionTitle('近期光照读数'),
          CreamCard(
            child: Text(_recent.isEmpty ? '等待实测记录' : _recent.join('\n')),
          ),
          const Text(
            '支持温湿度、光照与 RFID 卡号上传。未连接的传感器暂无读数；远程控制尚未接入。',
            style: TextStyle(color: Warm.muted),
          ),
        ],
      ),
    ),
  );

  @override
  void dispose() {
    _timer?.cancel();
    _client.close();
    super.dispose();
  }
}
