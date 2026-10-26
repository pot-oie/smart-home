import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:home_observer/data/home_controller.dart';
import 'package:home_observer/data/local_store.dart';
import 'package:home_observer/data/simulator.dart';
import 'package:home_observer/domain/models.dart';
import 'package:home_observer/main.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('手机运行、四页交互、事件确认与原生本地存储', (tester) async {
    final d = SimulatedDevice();
    final c = HomeController(adapter: d, store: FileStore());
    await tester.pumpWidget(HomeApp(controller: c));
    await tester.pumpAndSettle();
    expect(c.loadError, isNull);
    expect(find.text('家居观察'), findsOneWidget);
    await precacheImage(
      const AssetImage('assets/images/home_art.png'),
      tester.element(find.byType(Scaffold).first),
    );
    // Capture after the first two real simulated samples, without seeding history.
    await tester.pump(const Duration(seconds: 6));
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
    }
    await binding.takeScreenshot('01_home');
    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('刷卡'),
      180,
      scrollable: find
          .descendant(
            of: find.byType(IndexedStack),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    await tester.tap(find.text('刷卡'));
    await tester.pumpAndSettle();
    expect(c.swipes.first.allowed, isTrue);
    expect(c.config.armed, isTrue);
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold).first),
    ).clearSnackBars();
    await tester.drag(
      find
          .descendant(
            of: find.byType(IndexedStack),
            matching: find.byType(SingleChildScrollView),
          )
          .last,
      const Offset(0, 1200),
    );
    await tester.pumpAndSettle();
    await binding.takeScreenshot('03_rfid');
    d.inputs[7] = 1;
    d.step(DateTime.now());
    await tester.tap(find.byKey(const ValueKey('nav-1')));
    await tester.pumpAndSettle();
    expect(c.events.values.any((e) => e.moduleId == 7 && e.active), isTrue);
    await binding.takeScreenshot('02_events');
    final event = c.events.values.firstWhere(
      (e) => e.moduleId == 7 && e.active,
    );
    await c.acknowledge(event);
    await tester.pumpAndSettle();
    expect(c.events[event.id]!.active, isTrue);
    expect(c.events[event.id]!.acknowledgedAt, isNotNull);
    d.inputs[7] = 0;
    d.step(DateTime.now());
    await tester.pumpAndSettle();
    expect(c.events[event.id]!.complete, isTrue);
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('04_settings');
    final proposed = c.config.patch({'tHigh': 31});
    await c.applySettings(proposed);
    await tester.pumpAndSettle();
    expect(c.config.tHigh, 31);
    d.replyMode = ReplyMode.reject;
    await c.applySettings(c.config.patch({'tHigh': 32}));
    await tester.pumpAndSettle();
    expect(c.latestOperation!.state, RequestState.rejected);
    expect(c.config.tHigh, 31);
    d.replyMode = ReplyMode.timeout;
    await c.applySettings(c.config.patch({'tHigh': 33}));
    await tester.pump(const Duration(seconds: 5));
    expect(c.latestOperation!.state, RequestState.timeout);
    expect(c.config.tHigh, 31);
    c.setConnection(false);
    await tester.pump();
    expect(c.value(1), isNull);
    expect(c.quality(1), Quality.stale);
    c.setConnection(true);
    await tester.pumpAndSettle();
    expect(c.value(1), isNotNull);
    await c.saveNow();
    final saved = await FileStore().load();
    expect(saved!['config']['tHigh'], 31);
    expect(saved['swipes'], isNotEmpty);
    expect(saved['events'], isNotEmpty);
    // Leave the demonstration in its default environment after verifying persistence.
    d.replyMode = ReplyMode.accept;
    await c.applySettings(const Settings());
    d.resetInputs();
    await c.saveNow();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
