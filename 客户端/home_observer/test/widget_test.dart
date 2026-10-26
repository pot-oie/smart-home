import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_observer/main.dart';
import 'package:home_observer/data/home_controller.dart';
import 'package:home_observer/data/local_store.dart';
import 'package:home_observer/data/simulator.dart';
import 'package:home_observer/domain/models.dart';

void main() {
  testWidgets('手机窄屏四页可导航，无标题副文案且断连不显示正常数值', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = HomeController(adapter: SimulatedDevice(), store: MemoryStore());
    await tester.pumpWidget(HomeApp(controller: c));
    await tester.pumpAndSettle();
    expect(find.text('家居观察'), findsOneWidget);
    expect(find.text('模拟数据'), findsOneWidget);
    expect(find.text('设备规则与演示配置'), findsNothing);
    expect(tester.takeException(), isNull);
    for (final i in [1, 2, 3, 0]) {
      await tester.tap(find.byKey(ValueKey('nav-$i')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    c.setConnection(false);
    await tester.pump();
    expect(find.text('设备断连 · 当前数据陈旧'), findsOneWidget);
    expect(c.value(1), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('设置提交显示等待，匹配接受后才显示成功', (tester) async {
    final c = HomeController(adapter: SimulatedDevice(), store: MemoryStore());
    await tester.pumpWidget(HomeApp(controller: c));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('提交设置'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(IndexedStack),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    await tester.tap(find.text('提交设置'));
    await tester.pump();
    expect(c.latestOperation!.state, RequestState.pending);
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pumpAndSettle();
    expect(c.latestOperation!.state, RequestState.accepted);
    expect(find.text('设备已接受'), findsOneWidget);
    final upper = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == '温度上限',
    );
    await tester.ensureVisible(upper);
    await tester.enterText(upper, '32');
    await tester.pump();
    expect(c.config.tHigh, 30);
    expect(find.text('未提交'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
