import 'package:flutter_test/flutter_test.dart';
import 'package:home_observer/data/simulator.dart';
import 'package:home_observer/domain/models.dart';

void main() {
  final t = DateTime(2026, 10, 13, 9);
  test('持续越界形成一个事件，确认与有效恢复分离', () async {
    final d = SimulatedDevice(responseDelay: Duration.zero);
    addTearDown(d.close);
    d.inputs[1] = 35;
    d.step(t);
    d.step(t.add(const Duration(seconds: 2)));
    expect(d.events, isEmpty);
    d.step(t.add(const Duration(seconds: 3)));
    final e = d.events.values.single;
    d.step(t.add(const Duration(seconds: 4)));
    expect(d.events.length, 1);
    await d.send(DeviceRequest('ack', 'ack', {'eventId': e.id}));
    expect(d.events[e.id]!.active, isTrue);
    expect(d.events[e.id]!.acknowledgedAt, isNotNull);
    d.inputs[1] = 24;
    d.invalid.add(1);
    d.step(t.add(const Duration(seconds: 5)));
    expect(d.events[e.id]!.active, isTrue);
    d.invalid.clear();
    d.inputs[1] = 29.5;
    d.step(t.add(const Duration(seconds: 6)));
    expect(d.events[e.id]!.active, isTrue);
    d.inputs[1] = 28;
    d.step(t.add(const Duration(seconds: 7)));
    expect(d.events[e.id]!.complete, isTrue);
  });
  test('无效样本中断持续条件，陈旧样本不恢复', () async {
    final d = SimulatedDevice();
    addTearDown(d.close);
    d.inputs[1] = 35;
    d.step(t);
    d.invalid.add(1);
    d.step(t.add(const Duration(seconds: 2)));
    d.invalid.clear();
    d.step(t.add(const Duration(seconds: 3)));
    expect(d.events, isEmpty);
    d.step(t.add(const Duration(seconds: 6)));
    expect(d.events.length, 1);
    d.frozen.add(1);
    d.inputs[1] = 24;
    d.step(t.add(const Duration(seconds: 12)));
    expect(d.events.values.single.active, isTrue);
    expect(
      d.samples[1]!.effective(t.add(const Duration(seconds: 12)), true),
      Quality.stale,
    );
  });
  test('窗帘滞回、无效暂停与手动状态', () async {
    final d = SimulatedDevice();
    addTearDown(d.close);
    d.inputs[3] = 80;
    d.step(t);
    expect(d.curtainOpen, isFalse);
    d.inputs[3] = 50;
    d.step(t.add(const Duration(seconds: 1)));
    expect(d.curtainOpen, isFalse);
    d.inputs[3] = 20;
    d.invalid.add(3);
    d.step(t.add(const Duration(seconds: 2)));
    expect(d.curtainOpen, isFalse);
    d.invalid.clear();
    d.step(t.add(const Duration(seconds: 3)));
    expect(d.curtainOpen, isTrue);
    d.config = d.config.patch({'automatic': false, 'curtainOpen': false});
    d.step(t.add(const Duration(seconds: 4)));
    expect(d.curtainOpen, isFalse);
  });
  test('撤防不关闭独立危险提示，活动输入分别判断', () async {
    final d = SimulatedDevice();
    addTearDown(d.close);
    d.config = d.config.patch({'armed': false});
    d.inputs.addAll({5: 1, 6: 1, 7: 1, 8: 1, 9: 1});
    d.step(t);
    expect(d.events.length, 3);
    d.config = d.config.patch({'armed': true});
    d.inputs[6] = 0;
    d.step(t.add(const Duration(seconds: 1)));
    expect(d.events.values.any((e) => e.moduleId == 5), isTrue);
    expect(d.events.values.any((e) => e.moduleId == 6), isFalse);
  });
  test('RFID授权、未知、失败、名单不可用、重复抑制及窗口到期', () async {
    final d = SimulatedDevice();
    addTearDown(d.close);
    d.step(t);
    expect(d.swipe('UNKNOWN', at: t), '未知卡拒绝');
    expect(d.swipe('DEMO01', at: t), '授权通过');
    expect(
      d.swipe('DEMO01', at: t.add(const Duration(seconds: 1))),
      contains('抑制'),
    );
    expect(d.config.armed, isTrue);
    expect(d.gateUntil, t.add(const Duration(seconds: 5)));
    d.config = d.config.patch({'listAvailable': false});
    expect(d.swipe('DEMO01', at: t.add(const Duration(seconds: 3))), '名单不可用');
    expect(
      d.swipe('DEMO02', failed: true, at: t.add(const Duration(seconds: 4))),
      '读卡失败',
    );
    d.step(t.add(const Duration(seconds: 6)));
    expect(d.gateUntil!.isBefore(t.add(const Duration(seconds: 6))), isTrue);
  });
  test('设置拒绝无效关系，请求编号重发返回原结果', () async {
    final d = SimulatedDevice(responseDelay: Duration.zero);
    addTearDown(d.close);
    await d.send(const DeviceRequest('bad', 'settings', {'tHigh': 5}));
    expect(d.config.tHigh, 30);
    await d.send(const DeviceRequest('same', 'settings', {'tHigh': 32}));
    expect(d.config.tHigh, 32);
    await d.send(const DeviceRequest('same', 'settings', {'tHigh': 33}));
    expect(d.config.tHigh, 32);
  });
  test('断连现场继续判断，恢复补传且缓存有界', () async {
    final d = SimulatedDevice();
    addTearDown(d.close);
    final messages = <DeviceMessage>[];
    final sub = d.messages.listen(messages.add);
    addTearDown(sub.cancel);
    d.setConnected(false);
    d.inputs[7] = 1;
    d.step(t);
    expect(d.events.length, 1);
    expect(messages.where((m) => m.kind == 'event'), isEmpty);
    for (var i = 1; i < 140; i++) {
      d.step(t.add(Duration(seconds: i)));
    }
    expect(d.dropped, greaterThan(0));
    d.inputs[7] = 0;
    d.step(t.add(const Duration(seconds: 140)));
    d.setConnected(true);
    expect(messages.where((m) => m.kind == 'event'), isNotEmpty);
    expect(d.events.values.single.active, isFalse);
  });
  test('未启用模块不生成读取错误或报警', () async {
    final d = SimulatedDevice();
    addTearDown(d.close);
    d.config = d.config.patch({
      'enabled': [1, 2, 3, 4],
    });
    d.inputs[7] = 1;
    d.step(t);
    expect(d.samples[7]!.quality, Quality.disabled);
    expect(d.samples[7]!.value, isNull);
    expect(d.events, isEmpty);
  });
}
