import 'dart:async';
import 'package:flutter/material.dart';
import 'data/home_controller.dart';
import 'data/local_store.dart';
import 'data/simulator.dart';
import 'ui/home_page.dart';
import 'ui/events_page.dart';
import 'ui/rfid_page.dart';
import 'ui/settings_page.dart';
import 'ui/style.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    HomeApp(
      controller: HomeController(
        adapter: SimulatedDevice(),
        store: FileStore(),
      ),
    ),
  );
}

class HomeApp extends StatefulWidget {
  const HomeApp({super.key, required this.controller, this.initialize = true});
  final HomeController controller;
  final bool initialize;
  @override
  State<HomeApp> createState() => _HomeAppState();
}

class _HomeAppState extends State<HomeApp> with WidgetsBindingObserver {
  int page = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialize) unawaited(widget.controller.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(widget.controller.saveNow());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.dispose();
    super.dispose();
  }

  Widget navigation() {
    const icons = [
      Icons.home_outlined,
      Icons.description_outlined,
      Icons.sensors,
      Icons.settings_outlined,
    ];
    const labels = ['首页', '事件', 'RFID', '设置'];
    return Container(
      decoration: const BoxDecoration(
        color: Warm.background,
        border: Border(top: BorderSide(color: Warm.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
          child: Row(
            children: List.generate(4, (i) {
              final selected = i == page;
              return Expanded(
                child: Semantics(
                  selected: selected,
                  button: true,
                  label: labels[i],
                  child: InkWell(
                    key: ValueKey('nav-$i'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => page = i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icons[i],
                            color: selected ? Warm.clay : Warm.muted,
                            size: 25,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            labels[i],
                            style: TextStyle(
                              color: selected ? Warm.clay : Warm.muted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 2,
                            width: 28,
                            color: selected ? Warm.clay : Colors.transparent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget content(HomeController c) {
    if (c.loading)
      return const Center(child: CircularProgressIndicator(color: Warm.clay));
    if (c.loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Warm.clay, size: 32),
              const SizedBox(height: 16),
              Text(c.loadError!),
              const SizedBox(height: 12),
              FilledButton(onPressed: c.initialize, child: const Text('重新读取')),
            ],
          ),
        ),
      );
    }
    return IndexedStack(
      index: page,
      children: [
        HomePage(c, onEvents: () => setState(() => page = 1)),
        EventsPage(c),
        RfidPage(c),
        SettingsPage(c),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '家居观察',
    debugShowCheckedModeBanner: false,
    theme: Warm.theme,
    home: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                if (c.storageError != null)
                  MaterialBanner(
                    content: Text(
                      c.storageError!,
                      style: const TextStyle(fontSize: 12),
                    ),
                    actions: [
                      TextButton(onPressed: c.saveNow, child: const Text('重试')),
                    ],
                  ),
                if (!c.loading && !c.live && c.loadError == null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    color: Warm.clay.withValues(alpha: .1),
                    child: const Text(
                      '设备断连 · 当前数据陈旧',
                      style: TextStyle(color: Warm.clay, fontSize: 12),
                    ),
                  ),
                Expanded(child: content(c)),
              ],
            ),
          ),
          bottomNavigationBar: navigation(),
        );
      },
    ),
  );
}
