import 'package:flutter_test/flutter_test.dart';
import 'package:home_observer/data/home_controller.dart';
import 'package:home_observer/data/local_store.dart';
import 'package:home_observer/data/simulator.dart';
import 'package:home_observer/domain/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('配置仅匹配接受结果生效，拒绝、超时保留原配置', () async {
    final d = SimulatedDevice(responseDelay: Duration.zero);
    final c = HomeController(
      adapter: d,
      store: MemoryStore(),
      requestTimeout: const Duration(milliseconds: 30),
    );
    addTearDown(c.shutdown);
    await c.initialize();
    d.replyMode = ReplyMode.reject;
    await c.applySettings(c.config.patch({'tHigh': 32}));
    expect(c.config.tHigh, 30);
    expect(c.latestOperation!.state, RequestState.rejected);
    d.replyMode = ReplyMode.accept;
    await c.applySettings(c.config.patch({'tHigh': 32}));
    expect(c.config.tHigh, 32);
    expect(c.latestOperation!.state, RequestState.accepted);
    d.replyMode = ReplyMode.timeout;
    final id = await c.applySettings(c.config.patch({'tHigh': 33}));
    expect(c.config.tHigh, 32);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(c.latestOperation!.state, RequestState.timeout);
    c.receive(
      DeviceMessage(
        'result',
        DeviceResult(id, true, config: c.config.patch({'tHigh': 33})),
      ),
    );
    expect(c.config.tHigh, 32);
    expect(c.latestOperation!.state, RequestState.timeout);
  });
  test('事件按ID/revision去重，恢复和确认合并', () async {
    final c = HomeController(adapter: SimulatedDevice(), store: MemoryStore());
    addTearDown(c.shutdown);
    await c.initialize();
    final e = SafetyEvent(
      id: 'event-1',
      label: '测试事件',
      moduleId: 7,
      triggeredAt: DateTime.now(),
    );
    c.receive(DeviceMessage('event', e));
    c.receive(DeviceMessage('event', e));
    expect(c.events.length, 1);
    final recovered = e.update(recoveredAt: DateTime.now(), revision: 2);
    c.receive(DeviceMessage('event', recovered));
    c.receive(
      DeviceMessage(
        'event',
        e.update(acknowledgedAt: DateTime.now(), revision: 3),
      ),
    );
    expect(c.events['event-1']!.complete, isTrue);
    c.receive(DeviceMessage('event', e));
    expect(c.events['event-1']!.complete, isTrue);
  });
  test('断连将有效值标陈旧，不显示正常零；重连恢复', () async {
    final c = HomeController(adapter: SimulatedDevice(), store: MemoryStore());
    addTearDown(c.shutdown);
    await c.initialize();
    expect(c.value(1), 24.6);
    c.setConnection(false);
    expect(c.value(1), isNull);
    expect(c.quality(1), Quality.stale);
    c.setConnection(true);
    expect(c.value(1), 24.6);
  });
  test('设置、刷卡、事件与历史保存后可恢复', () async {
    final store = MemoryStore();
    final d = SimulatedDevice(responseDelay: Duration.zero);
    final c = HomeController(adapter: d, store: store);
    await c.initialize();
    await c.applySettings(c.config.patch({'tHigh': 31}));
    d.swipe('DEMO01');
    d.inputs[7] = 1;
    d.step(DateTime.now());
    await c.saveNow();
    await c.shutdown();
    final restored = HomeController(adapter: SimulatedDevice(), store: store);
    addTearDown(restored.shutdown);
    await restored.initialize();
    expect(restored.config.tHigh, 31);
    expect(restored.swipes.single.uid, 'DEMO01');
    expect(restored.events, isNotEmpty);
    expect(restored.history, isNotEmpty);
  });
  test('待处理请求恢复时明确标超时', () {
    final op = Operation.fromJson(
      Operation('x', '设置', DateTime.now()).toJson(),
    );
    expect(op.state, RequestState.timeout);
    expect(op.reason, isNotEmpty);
  });
}
