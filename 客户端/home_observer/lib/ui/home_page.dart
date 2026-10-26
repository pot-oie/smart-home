import 'package:flutter/material.dart';
import '../data/home_controller.dart';
import '../domain/models.dart';
import 'chart.dart';
import 'details.dart';
import 'style.dart';

class HomePage extends StatelessWidget {
  const HomePage(this.c, {super.key, required this.onEvents});
  final HomeController c;
  final VoidCallback onEvents;
  @override
  Widget build(BuildContext context) {
    final t = c.value(1), h = c.value(2), l = c.value(3);
    final openEvents = c.sortedEvents.where((e) => !e.complete).length;
    return PageBody(
      title: '家居观察',
      large: true,
      children: [
        CreamCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const WarmBadge('模拟数据'),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => HistoryPage(c)),
                    ),
                    child: const Text('历史'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, box) => Wrap(
                  spacing: 20,
                  runSpacing: 18,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: t?.toStringAsFixed(1) ?? '—',
                            style: TextStyle(
                              fontFamily: 'HomeSerif',
                              fontSize: box.maxWidth < 300 ? 49 : 62,
                              fontWeight: FontWeight.w400,
                              letterSpacing: -2,
                            ),
                          ),
                          const TextSpan(
                            text: ' °C',
                            style: TextStyle(fontSize: 23),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Metric(
                          '湿度',
                          h?.toStringAsFixed(0),
                          '%RH',
                          qualityNames[c.quality(2)]!,
                        ),
                        const SizedBox(width: 20),
                        _Metric(
                          '相对光强',
                          l?.toStringAsFixed(0),
                          '',
                          qualityNames[c.quality(3)]!,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                '温度 · ${qualityNames[c.quality(1)]}',
                style: const TextStyle(color: Warm.muted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TemperatureChart(
                c.history.length > 30
                    ? c.history.sublist(c.history.length - 30)
                    : c.history,
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, box) {
            final tiles = [
              _stateCard(
                Icons.curtains_outlined,
                '窗帘',
                '${c.snapshot?.curtainOpen == true ? '开帘' : '关帘'}模拟',
                c.live ? (c.config.automatic ? '自动' : '手动') : '状态陈旧',
                Warm.clay,
              ),
              _stateCard(
                Icons.door_back_door_outlined,
                '门禁',
                '${c.snapshot?.gateOpen == true ? '允许通行' : '关闭'}模拟',
                c.live ? '' : '状态陈旧',
                Warm.blue,
              ),
            ];
            return box.maxWidth < 310
                ? Column(children: tiles)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: tiles[0]),
                      const SizedBox(width: 12),
                      Expanded(child: tiles[1]),
                    ],
                  );
          },
        ),
        CreamCard(
          child: InkWell(
            onTap: onEvents,
            borderRadius: BorderRadius.circular(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Warm.gold.withValues(alpha: .22),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    openEvents > 0
                        ? Icons.warning_amber_rounded
                        : Icons.verified_user_outlined,
                    color: openEvents > 0 ? Warm.clay : Warm.gold,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('安全事件', style: Warm.title(21)),
                      Text(
                        openEvents == 0 ? '暂无异常' : '$openEvents 项待处理',
                        style: const TextStyle(color: Warm.muted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Warm.muted),
              ],
            ),
          ),
        ),
        CreamCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('设备模块', style: Warm.title(20)),
            subtitle: Text(
              c.live
                  ? '${c.config.enabled.length} 项启用 · ${c.config.armed ? '已布防' : '已撤防'}'
                  : '设备断连 · 数据陈旧',
              style: const TextStyle(color: Warm.muted, fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right, color: Warm.muted),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ModulesPage(c)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stateCard(
    IconData icon,
    String name,
    String value,
    String caption,
    Color color,
  ) => CreamCard(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 47,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Warm.title(17)),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(color: Warm.muted, fontSize: 12),
              ),
              if (caption.isNotEmpty)
                Text(
                  caption,
                  style: const TextStyle(color: Warm.muted, fontSize: 11),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.unit, this.quality);
  final String label, unit, quality;
  final String? value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Warm.muted, fontSize: 12)),
      const SizedBox(height: 4),
      Text.rich(
        TextSpan(
          children: [
            TextSpan(text: value ?? '—', style: const TextStyle(fontSize: 25)),
            TextSpan(text: unit, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
      if (value == null)
        Text(quality, style: const TextStyle(color: Warm.muted, fontSize: 11)),
    ],
  );
}
