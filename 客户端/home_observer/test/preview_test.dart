import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_observer/main.dart';
import 'package:home_observer/data/home_controller.dart';
import 'package:home_observer/data/local_store.dart';
import 'package:home_observer/data/simulator.dart';
import 'package:home_observer/domain/models.dart';

void main() {
  testWidgets('温暖家居四页测试渲染与手机尺寸检查', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      final serif = FontLoader('HomeSerif')
        ..addFont(rootBundle.load('assets/fonts/NotoSerifSC.ttf'));
      await serif.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    });
    final now = DateTime(2026, 1, 1, 9, 41);
    final d = SimulatedDevice(now: () => now);
    final c = HomeController(adapter: d, store: MemoryStore(), now: () => now);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('preview'),
        child: HomeApp(controller: c),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/images/home_art.png'),
        tester.element(find.byType(HomeApp)),
      );
    });
    await tester.pump();
    // Explicit simulated fixture for visual QA, not stored historical measurements.
    c.history.clear();
    for (var i = 0; i < 10; i++) {
      final at = now.subtract(Duration(minutes: 9 - i));
      c.history.add(
        HistoryPoint(at, [
          Sample(1, 23.4 + i * .13, Quality.valid, at),
          Sample(2, 52, Quality.valid, at),
          Sample(3, 68, Quality.valid, at),
        ]),
      );
    }
    d.step(now);
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('preview')),
      matchesGoldenFile('goldens/01_home.png'),
    );
    d.inputs[7] = 1;
    d.step(now);
    await tester.tap(find.byKey(const ValueKey('nav-1')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('preview')),
      matchesGoldenFile('goldens/02_events.png'),
    );
    d.swipe('DEMO01');
    d.swipe('UNKNOWN');
    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('preview')),
      matchesGoldenFile('goldens/03_rfid.png'),
    );
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('preview')),
      matchesGoldenFile('goldens/04_settings.png'),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
