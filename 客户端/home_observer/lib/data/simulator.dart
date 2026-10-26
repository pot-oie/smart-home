import 'dart:async';
import 'dart:collection';
import '../domain/models.dart';
import 'device_adapter.dart';

/// Mock site controller. Rules here are only a reference for future STM32 firmware.
class SimulatedDevice implements DeviceAdapter {
  SimulatedDevice({
    Settings? initial,
    this.responseDelay = const Duration(milliseconds: 550),
    DateTime Function()? now,
  }) : config = initial ?? const Settings(),
       _now = now ?? DateTime.now;
  final DateTime Function() _now;
  Settings config;
  final Duration responseDelay;
  final _stream = StreamController<DeviceMessage>.broadcast(sync: true);
  final Map<int, double> inputs = {
    1: 24.6,
    2: 52,
    3: 68,
    5: 0,
    6: 0,
    7: 0,
    8: 0,
    9: 0,
  };
  final Set<int> invalid = {}, frozen = {};
  final Map<int, Sample> samples = {};
  final Map<int, DateTime> _pending = {};
  final Map<int, String> _active = {};
  final Map<String, SafetyEvent> events = {};
  final Map<String, DateTime> _lastCard = {};
  final LinkedHashMap<String, DeviceResult> _requestCache = LinkedHashMap();
  final Queue<DeviceMessage> _queue = Queue();
  final bootId = 'sim-${DateTime.now().microsecondsSinceEpoch}';
  bool _connected = true, _closed = false, curtainOpen = false;
  DateTime? gateUntil;
  int seq = 0,
      dropped = 0,
      droppedEvents = 0,
      _eventCounter = 0,
      _cardCounter = 0;
  ReplyMode replyMode = ReplyMode.accept;
  Timer? _timer;
  @override
  bool get connected => _connected;
  @override
  bool get isSimulation => true;
  @override
  String get sourceName => '模拟设备';
  @override
  Stream<DeviceMessage> get messages => _stream.stream;
  @override
  void start() {
    step(_now());
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => step(_now()));
  }

  void setConnected(bool connected) {
    _connected = connected;
    _emit(DeviceMessage('connection', connected), force: true);
    if (connected) {
      while (_queue.isNotEmpty) {
        _emit(_queue.removeFirst());
      }
      step(_now());
    }
  }

  void _emit(DeviceMessage m, {bool force = false}) {
    if (_closed) return;
    if (!_connected && !force) {
      if (m.kind != 'snapshot') {
        if (_queue.length >= 128) {
          _queue.removeFirst();
          dropped++;
        }
        _queue.add(m);
      }
      return;
    }
    _stream.add(m);
  }

  void _event(int id, String label, bool abnormal, DateTime now) {
    final key = _active[id];
    if (abnormal) {
      if (key == null) {
        final eid = '$bootId-e${++_eventCounter}';
        _active[id] = eid;
        events[eid] = SafetyEvent(
          id: eid,
          label: label,
          moduleId: id,
          triggeredAt: now,
        );
        _emit(DeviceMessage('event', events[eid]!));
      } else {
        events[key] = events[key]!.update();
        _emit(DeviceMessage('event', events[key]!));
      }
    } else if (key != null) {
      events[key] = events[key]!.update(recoveredAt: now);
      _active.remove(id);
      _emit(DeviceMessage('event', events[key]!));
    }
    while (events.length > 300) {
      final oldest = events.values.where((e) => !e.active).firstOrNull;
      if (oldest == null) break;
      if (!oldest.complete) droppedEvents++;
      events.remove(oldest.id);
    }
  }

  void step(DateTime now) {
    if (_closed) return;
    for (final id in moduleNames.keys) {
      if (!config.enabled.contains(id)) {
        samples[id] = Sample(id, null, Quality.disabled, null);
        continue;
      }
      if (frozen.contains(id)) continue;
      final valid = inputs.containsKey(id) || id == 4;
      samples[id] = Sample(
        id,
        inputs[id],
        invalid.contains(id)
            ? Quality.invalid
            : valid
            ? Quality.valid
            : Quality.initializing,
        now,
      );
    }
    for (final id in [1, 2]) {
      final sample = samples[id];
      if (sample == null ||
          sample.effective(now, true) != Quality.valid ||
          sample.value == null) {
        _pending.remove(id);
        continue;
      }
      final value = sample.value!,
          low = id == 1 ? config.tLow : config.hLow,
          high = id == 1 ? config.tHigh : config.hHigh,
          margin = id == 1 ? config.tMargin : config.hMargin;
      if (value < low || value > high) {
        _pending.putIfAbsent(id, () => now);
        if (now.difference(_pending[id]!).inMilliseconds >=
            config.holdSeconds * 1000) {
          _event(id, id == 1 ? '温度持续越界' : '湿度持续越界', true, now);
        }
      } else {
        _pending.remove(id);
        if (value >= low + margin && value <= high - margin)
          _event(id, id == 1 ? '温度持续越界' : '湿度持续越界', false, now);
      }
    }
    for (final id in [5, 6, 7, 8, 9]) {
      final sample = samples[id];
      if (sample == null ||
          sample.effective(now, true) != Quality.valid ||
          sample.value == null)
        continue;
      if ((id == 5 || id == 6) && !config.armed && sample.value! > 0) continue;
      _event(id, '${moduleNames[id]}提示', sample.value! > 0, now);
    }
    final light = samples[3];
    if (!config.automatic) {
      curtainOpen = config.curtainOpen;
    } else if (light != null &&
        light.effective(now, true) == Quality.valid &&
        light.value != null) {
      if (light.value! >= config.lightClose)
        curtainOpen = false;
      else if (light.value! <= config.lightOpen)
        curtainOpen = true;
    }
    _emit(
      DeviceMessage(
        'snapshot',
        Snapshot(
          bootId,
          ++seq,
          now,
          samples.values.toList(),
          curtainOpen,
          gateUntil != null && now.isBefore(gateUntil!),
        ),
      ),
    );
  }

  String swipe(String uid, {bool failed = false, DateTime? at}) {
    final now = at ?? _now();
    uid = uid.trim().toUpperCase();
    if (uid.isEmpty && !failed) return '请输入卡片标识';
    final prev = _lastCard[uid];
    if (prev != null && now.difference(prev) < const Duration(seconds: 2))
      return '同一卡片短时重复读取已抑制';
    _lastCard[uid] = now;
    if (_lastCard.length > 100) _lastCard.remove(_lastCard.keys.first);
    final reason = failed
        ? '读卡失败'
        : !config.enabled.contains(4) ||
              invalid.contains(4) ||
              frozen.contains(4)
        ? '模块不可用'
        : !config.listAvailable
        ? '名单不可用'
        : config.cards.any((c) => c.enabled && c.uid == uid)
        ? '授权通过'
        : '未知卡拒绝';
    final allowed = reason == '授权通过';
    if (allowed) gateUntil = now.add(const Duration(seconds: 5));
    _emit(
      DeviceMessage(
        'rfid',
        SwipeRecord(
          '$bootId-r${++_cardCounter}',
          uid.isEmpty ? '读取失败' : uid,
          reason,
          allowed,
          now,
        ),
      ),
    );
    step(now);
    return reason;
  }

  @override
  Future<void> send(DeviceRequest request) async {
    if (_closed || !_connected || replyMode == ReplyMode.timeout) return;
    final capturedMode = replyMode;
    await Future<void>.delayed(responseDelay);
    if (_closed || !_connected) return;
    final cached = _requestCache[request.id];
    if (cached != null) {
      _emit(DeviceMessage('result', cached));
      return;
    }
    DeviceResult result;
    if (capturedMode == ReplyMode.reject) {
      result = DeviceResult(request.id, false, reason: '模拟设备拒绝请求');
    } else {
      try {
        if (request.action == 'settings') {
          final candidate = config.patch(request.args);
          final error = candidate.validate();
          if (error != null) {
            result = DeviceResult(request.id, false, reason: error);
          } else {
            config = candidate;
            result = DeviceResult(request.id, true, config: config);
          }
        } else if (request.action == 'ack') {
          final eid = request.args['eventId'];
          final event = events[eid];
          if (event == null) {
            result = DeviceResult(request.id, false, reason: '事件不存在于当前设备会话');
          } else {
            events[eid] = event.update(acknowledgedAt: _now());
            _emit(DeviceMessage('event', events[eid]!));
            result = DeviceResult(request.id, true);
          }
        } else {
          result = DeviceResult(request.id, false, reason: '未知操作');
        }
      } catch (_) {
        result = DeviceResult(request.id, false, reason: '请求数据无效');
      }
    }
    _requestCache[request.id] = result;
    if (_requestCache.length > 32)
      _requestCache.remove(_requestCache.keys.first);
    _emit(DeviceMessage('result', result));
    step(_now());
  }

  @override
  void receipt(String eventId, int revision) {
    /* delivery receipt, not user acknowledgment */
  }
  void restoreEvents(Iterable<SafetyEvent> saved) {
    for (final e in saved) {
      events[e.id] = e;
      if (e.active) _active[e.moduleId] = e.id;
    }
  }

  void resetInputs() {
    inputs.addAll({1: 24.6, 2: 52, 3: 68, 5: 0, 6: 0, 7: 0, 8: 0, 9: 0});
    invalid.clear();
    frozen.clear();
    step(_now());
  }

  @override
  Future<void> close() async {
    _closed = true;
    _timer?.cancel();
    await _stream.close();
  }
}
