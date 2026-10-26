import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_observer/data/home_controller.dart';
import 'package:home_observer/data/local_store.dart';
import 'package:home_observer/data/simulator.dart';
import 'package:home_observer/domain/models.dart';
import 'package:home_observer/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('大量重复触发保持有界并报告未确认事件淘汰', () async {
    final d = SimulatedDevice();
    addTearDown(d.close);
    final base = DateTime(2026, 10, 13);
    for (var i = 0; i < 320; i++) {
      d.inputs[7] = 1;
      d.step(base.add(Duration(seconds: i * 2)));
      d.inputs[7] = 0;
      d.step(base.add(Duration(seconds: i * 2 + 1)));
    }
    expect(d.events.length, 300);
    expect(d.droppedEvents, 20);
  });
  test('冻结数据入历史时保留陈旧状态', () async {
    final d = SimulatedDevice();
    final c = HomeController(adapter: d, store: MemoryStore());
    addTearDown(c.shutdown);
    await c.initialize();
    d.frozen.add(1);
    d.step(DateTime.now().add(const Duration(seconds: 6)));
    expect(
      c.history.last.samples.firstWhere((s) => s.id == 1).quality,
      Quality.stale,
    );
  });
  test('撤防不自动清除活动事件，但有效无活动可恢复', () async {
    final d = SimulatedDevice();
    addTearDown(d.close);
    final now = DateTime.now();
    d.inputs[5] = 1;
    d.step(now);
    d.config = d.config.patch({'armed': false});
    d.step(now.add(const Duration(seconds: 1)));
    expect(d.events.values.single.active, isTrue);
    d.inputs[5] = 0;
    d.step(now.add(const Duration(seconds: 2)));
    expect(d.events.values.single.recoveredAt, isNotNull);
    expect(d.events.values.single.acknowledgedAt, isNull);
  });
  testWidgets('320像素与较大字号仍可操作四页', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = HomeController(adapter: SimulatedDevice(), store: MemoryStore());
    await tester.pumpWidget(HomeApp(controller: c));
    await tester.pumpAndSettle();
    for (final i in [1, 2, 3, 0]) {
      await tester.tap(find.byKey(ValueKey('nav-$i')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
