import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/models.dart';
import 'device_adapter.dart';
import 'local_store.dart';
import 'simulator.dart';

class HomeController extends ChangeNotifier {
  HomeController({
    required this.adapter,
    required this.store,
    this.requestTimeout = const Duration(seconds: 4),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;
  final DateTime Function() _now;
  final DeviceAdapter adapter;
  final LocalStore store;
  final Duration requestTimeout;
  Settings config = const Settings();
  Snapshot? snapshot;
  final Map<String, SafetyEvent> events = {};
  final List<SwipeRecord> swipes = [];
  final List<HistoryPoint> history = [];
  final List<Operation> operations = [];
  bool loading = true, _disposed = false, connected = false;
  String? loadError, storageError;
  StreamSubscription<DeviceMessage>? _subscription;
  Timer? _clock, _saveTimer;
  final Map<String, Timer> _timeouts = {};
  int _requestSeq = 0;
  int discardedEvents = 0;
  final _session = DateTime.now().microsecondsSinceEpoch;
  DateTime? _lastHistory;
  Future<void> _writes = Future.value();
  SimulatedDevice? get simulation =>
      adapter is SimulatedDevice ? adapter as SimulatedDevice : null;
  Operation? get latestOperation => operations.isEmpty ? null : operations.last;
  bool get pending => operations.any((o) => o.state == RequestState.pending);
  bool get live =>
      connected &&
      snapshot != null &&
      _now().difference(snapshot!.at) <= const Duration(seconds: 5);
  Sample? sample(int id) =>
      snapshot?.samples.where((s) => s.id == id).firstOrNull;
  Quality quality(int id) =>
      sample(id)?.effective(_now(), live) ?? Quality.initializing;
  double? value(int id) =>
      quality(id) == Quality.valid ? sample(id)?.value : null;
  List<SafetyEvent> get sortedEvents =>
      events.values.toList()
        ..sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));
  Future<void> initialize() async {
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      final saved = await store.load();
      if (saved != null) {
        discardedEvents = saved['discardedEvents'] as int? ?? 0;
        config = Settings.fromJson(Map<String, dynamic>.from(saved['config']));
        if (config.validate() != null) throw const FormatException('已保存设置无效');
        events.clear();
        for (final j in saved['events'] as List) {
          final e = SafetyEvent.fromJson(Map<String, dynamic>.from(j));
          events[e.id] = e;
        }
        swipes
          ..clear()
          ..addAll(
            (saved['swipes'] as List).map(
              (j) => SwipeRecord.fromJson(Map<String, dynamic>.from(j)),
            ),
          );
        history
          ..clear()
          ..addAll(
            (saved['history'] as List).map(
              (j) => HistoryPoint.fromJson(Map<String, dynamic>.from(j)),
            ),
          );
        operations
          ..clear()
          ..addAll(
            (saved['operations'] as List).map(
              (j) => Operation.fromJson(Map<String, dynamic>.from(j)),
            ),
          );
      }
      if (simulation != null) {
        simulation!.config = config;
        simulation!.restoreEvents(events.values);
      }
      connected = adapter.connected;
      _subscription ??= adapter.messages.listen(
        receive,
        onError: (Object e) {
          storageError = '设备数据异常：$e';
          notifyListeners();
        },
      );
      adapter.start();
      _clock ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_disposed) notifyListeners();
      });
      loading = false;
      notifyListeners();
    } catch (e) {
      loadError = '本地记录读取失败：$e';
      loading = false;
      notifyListeners();
    }
  }

  void receive(DeviceMessage message) {
    if (_disposed) return;
    switch (message.kind) {
      case 'connection':
        connected = message.payload as bool;
      case 'snapshot':
        final next = message.payload as Snapshot;
        if (snapshot != null &&
            snapshot!.bootId == next.bootId &&
            next.seq <= snapshot!.seq)
          return;
        snapshot = next;
        if (_lastHistory == null ||
            next.at.difference(_lastHistory!) >= const Duration(seconds: 5)) {
          history.add(
            HistoryPoint(
              next.at,
              next.samples
                  .map(
                    (s) => Sample(
                      s.id,
                      s.value,
                      s.effective(next.at, true),
                      s.sampledAt,
                    ),
                  )
                  .toList(),
            ),
          );
          _lastHistory = next.at;
          if (history.length > 2000)
            history.removeRange(0, history.length - 2000);
        }
      case 'event':
        final e = message.payload as SafetyEvent;
        final prev = events[e.id];
        adapter.receipt(e.id, e.revision);
        if (prev != null && prev.revision >= e.revision) return;
        // Separate timestamps merge safely even when recovery and acknowledgment arrive out of order.
        events[e.id] = SafetyEvent(
          id: e.id,
          label: e.label,
          moduleId: e.moduleId,
          triggeredAt: e.triggeredAt,
          recoveredAt: e.recoveredAt ?? prev?.recoveredAt,
          acknowledgedAt: e.acknowledgedAt ?? prev?.acknowledgedAt,
          revision: e.revision,
        );
        while (events.length > 300) {
          final oldest = sortedEvents.reversed
              .where((e) => !e.active)
              .firstOrNull;
          if (oldest == null) break;
          if (!oldest.complete) discardedEvents++;
          events.remove(oldest.id);
        }
      case 'rfid':
        final swipe = message.payload as SwipeRecord;
        if (swipes.any((r) => r.id == swipe.id)) return;
        swipes.insert(0, swipe);
        if (swipes.length > 200) swipes.removeLast();
      case 'result':
        final result = message.payload as DeviceResult;
        final op = operations
            .where((o) => o.id == result.requestId)
            .firstOrNull;
        if (op == null || op.state != RequestState.pending) return;
        _timeouts.remove(op.id)?.cancel();
        op.state = result.accepted
            ? RequestState.accepted
            : RequestState.rejected;
        op.reason = result.reason;
        if (result.accepted && result.config != null) config = result.config!;
      default:
        return;
    }
    notifyListeners();
    _scheduleSave();
  }

  Future<String> send(
    String action,
    Map<String, dynamic> args, {
    required String label,
  }) async {
    final id = 'app-$_session-${++_requestSeq}';
    final op = Operation(id, label, _now());
    operations.add(op);
    if (operations.length > 50) {
      final i = operations.indexWhere((o) => o.state != RequestState.pending);
      if (i >= 0) operations.removeAt(i);
    }
    _timeouts[id] = Timer(requestTimeout, () {
      if (op.state == RequestState.pending) {
        op.state = RequestState.timeout;
        op.reason = '未收到对应设备结果，请核查后重提';
        notifyListeners();
        _scheduleSave();
      }
      _timeouts.remove(id);
    });
    notifyListeners();
    _scheduleSave();
    try {
      await adapter.send(DeviceRequest(id, action, args));
    } catch (e) {
      if (op.state == RequestState.pending) {
        _timeouts.remove(id)?.cancel();
        op.state = RequestState.rejected;
        op.reason = '发送失败：$e';
        notifyListeners();
        _scheduleSave();
      }
    }
    return id;
  }

  Future<String> applySettings(Settings proposed) =>
      send('settings', proposed.toJson(), label: '更新设置');
  Future<String> acknowledge(SafetyEvent event) =>
      send('ack', {'eventId': event.id}, label: '确认 ${event.label}');
  void setInput(int id, double value) {
    simulation?.inputs[id] = value;
    simulation?.step(DateTime.now());
  }

  void setConnection(bool online) => simulation?.setConnected(online);
  Map<String, dynamic> checkpoint() => {
    'schema': 1,
    'discardedEvents': discardedEvents,
    'config': config.toJson(),
    'events': events.values.map((e) => e.toJson()).toList(),
    'swipes': swipes.map((e) => e.toJson()).toList(),
    'history': history.map((e) => e.toJson()).toList(),
    'operations': operations.map((e) => e.toJson()).toList(),
  };
  void _scheduleSave() {
    if (_saveTimer?.isActive ?? false) return;
    _saveTimer = Timer(const Duration(seconds: 2), () {
      saveNow();
    });
  }

  Future<void> saveNow() {
    _saveTimer?.cancel();
    final data = checkpoint();
    _writes = _writes.then((_) async {
      try {
        await store.save(data);
        storageError = null;
      } catch (e) {
        storageError = '本地保存失败：$e';
      }
      if (!_disposed) notifyListeners();
    });
    return _writes;
  }

  Future<void> shutdown() async {
    _clock?.cancel();
    _saveTimer?.cancel();
    for (final t in _timeouts.values) {
      t.cancel();
    }
    await _subscription?.cancel();
    await adapter.close();
    await saveNow();
  }

  @override
  void dispose() {
    _disposed = true;
    _clock?.cancel();
    _saveTimer?.cancel();
    for (final t in _timeouts.values) {
      t.cancel();
    }
    _subscription?.cancel();
    adapter.close();
    super.dispose();
  }
}
