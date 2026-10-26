import 'package:flutter/material.dart';
import '../data/home_controller.dart';
import '../domain/models.dart';
import 'chart.dart';
import 'events_page.dart';
import 'style.dart';

class ModulesPage extends StatefulWidget {
  const ModulesPage(this.c, {super.key});
  final HomeController c;
  @override
  State<ModulesPage> createState() => _ModulesPageState();
}

class _ModulesPageState extends State<ModulesPage> {
  late Set<int> enabled;
  @override
  void initState() {
    super.initState();
    enabled = widget.c.config.enabled.toSet();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.c,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text('模块管理', style: Warm.title(24)),
        backgroundColor: Warm.background,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CreamCard(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(
              children: moduleNames.entries
                  .map(
                    (e) => CheckboxListTile(
                      value: enabled.contains(e.key),
                      onChanged: (v) => setState(
                        () => v == true
                            ? enabled.add(e.key)
                            : enabled.remove(e.key),
                      ),
                      title: Text(e.value),
                      subtitle: Text(
                        qualityNames[widget.c.quality(e.key)]!,
                        style: const TextStyle(color: Warm.muted, fontSize: 12),
                      ),
                      controlAffinity: ListTileControlAffinity.trailing,
                    ),
                  )
                  .toList(),
            ),
          ),
          FilledButton(
            onPressed: widget.c.pending
                ? null
                : () async {
                    await widget.c.applySettings(
                      widget.c.config.patch({
                        'enabled': enabled.toList()..sort(),
                      }),
                    );
                    if (context.mounted &&
                        widget.c.latestOperation?.state ==
                            RequestState.accepted)
                      message(context, '启用表已生效');
                  },
            child: Text(widget.c.pending ? '等待设备结果' : '提交启用表'),
          ),
          if (widget.c.latestOperation != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                operationText(widget.c.latestOperation!),
                style: const TextStyle(color: Warm.muted, fontSize: 12),
              ),
            ),
        ],
      ),
    ),
  );
}

class HistoryPage extends StatefulWidget {
  const HistoryPage(this.c, {super.key});
  final HomeController c;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  int id = 1, hours = 1;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.c,
    builder: (context, _) {
      final cutoff = DateTime.now().subtract(Duration(hours: hours));
      final points = widget.c.history
          .where((p) => p.at.isAfter(cutoff))
          .toList();
      return Scaffold(
        appBar: AppBar(
          title: Text('监测历史', style: Warm.title(24)),
          backgroundColor: Warm.background,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: id,
                    items: [1, 2, 3]
                        .map(
                          (i) => DropdownMenuItem(
                            value: i,
                            child: Text(moduleNames[i]!),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => id = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: hours,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('最近 1 小时')),
                      DropdownMenuItem(value: 24, child: Text('最近 24 小时')),
                    ],
                    onChanged: (v) => setState(() => hours = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            CreamCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${moduleNames[id]} · 模拟记录', style: Warm.title(20)),
                  const SizedBox(height: 16),
                  TemperatureChart(points, moduleId: id, height: 180),
                  const SizedBox(height: 10),
                  Text(
                    '${points.length} 条已接收记录',
                    style: const TextStyle(color: Warm.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (points.isEmpty) const EmptyState('此范围内暂无记录'),
            ...points.reversed.take(50).map((p) {
              final sample = p.samples.where((s) => s.id == id).firstOrNull;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${dateLabel(p.at)} ${hm(p.at)}'),
                trailing: Text(
                  '${sample?.quality == Quality.valid ? sample?.value?.toStringAsFixed(1) ?? '—' : '—'} ${sample?.unit ?? ''}',
                ),
                subtitle: Text(
                  qualityNames[sample?.quality] ?? '无数据',
                  style: const TextStyle(color: Warm.muted, fontSize: 12),
                ),
              );
            }),
          ],
        ),
      );
    },
  );
}

class OperationsPage extends StatelessWidget {
  const OperationsPage(this.c, {super.key});
  final HomeController c;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text('操作记录', style: Warm.title(24)),
        backgroundColor: Warm.background,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (c.operations.isEmpty) const EmptyState('暂无操作'),
          ...c.operations.reversed.map(
            (o) => CreamCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(o.label, style: Warm.title(19)),
                  const SizedBox(height: 8),
                  Text(
                    operationText(o),
                    style: TextStyle(
                      color: o.state == RequestState.accepted
                          ? Warm.blue
                          : Warm.clay,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${hm(o.submittedAt)} · ${o.id}',
                    style: const TextStyle(fontSize: 11, color: Warm.muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class SimulationPage extends StatefulWidget {
  const SimulationPage(this.c, {super.key});
  final HomeController c;
  @override
  State<SimulationPage> createState() => _SimulationPageState();
}

class _SimulationPageState extends State<SimulationPage> {
  final fields = <int, TextEditingController>{};
  @override
  void initState() {
    super.initState();
    for (final id in [1, 2, 3])
      fields[id] = TextEditingController(
        text: widget.c.simulation?.inputs[id].toString() ?? '',
      );
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.c,
    builder: (context, _) {
      final c = widget.c, sim = c.simulation;
      if (sim == null)
        return Scaffold(
          appBar: AppBar(title: const Text('设备连接')),
          body: const EmptyState('当前不是模拟模式'),
        );
      return Scaffold(
        appBar: AppBar(
          title: Text('模拟设备', style: Warm.title(24)),
          backgroundColor: Warm.background,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: WarmBadge('模拟数据'),
            ),
            const SizedBox(height: 15),
            CreamCard(
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('设备传输'),
                    subtitle: Text(c.live ? '在线' : '断连'),
                    value: c.connected,
                    onChanged: c.setConnection,
                  ),
                  DropdownButtonFormField<ReplyMode>(
                    initialValue: sim.replyMode,
                    decoration: const InputDecoration(labelText: '设置响应'),
                    items: const [
                      DropdownMenuItem(
                        value: ReplyMode.accept,
                        child: Text('接受'),
                      ),
                      DropdownMenuItem(
                        value: ReplyMode.reject,
                        child: Text('拒绝'),
                      ),
                      DropdownMenuItem(
                        value: ReplyMode.timeout,
                        child: Text('超时'),
                      ),
                    ],
                    onChanged: (v) => setState(() => sim.replyMode = v!),
                  ),
                ],
              ),
            ),
            CreamCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('环境输入'),
                  ...fields.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: e.value,
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: true,
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: moduleNames[e.key],
                          suffixText: e.key == 1
                              ? '°C'
                              : e.key == 2
                              ? '%RH'
                              : '相对量',
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        try {
                          final proposed = fields.map(
                            (k, v) => MapEntry(k, double.parse(v.text)),
                          );
                          if (proposed.values.any((v) => !v.isFinite))
                            throw const FormatException();
                          if (proposed[2]! < 0 ||
                              proposed[2]! > 100 ||
                              proposed[3]! < 0 ||
                              proposed[3]! > 100)
                            throw const FormatException();
                          sim.inputs.addAll(proposed);
                          sim.step(DateTime.now());
                          message(context, '模拟输入已更新');
                        } catch (_) {
                          message(context, '请输入有效数值，湿度和光强为 0–100');
                        }
                      },
                      child: const Text('应用输入'),
                    ),
                  ),
                ],
              ),
            ),
            CreamCard(
              child: Column(
                children: [
                  const SectionTitle('安全输入'),
                  ...[5, 6, 7, 8, 9].map(
                    (id) => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(moduleNames[id]!),
                      value: (sim.inputs[id] ?? 0) > 0,
                      onChanged: (v) {
                        sim.inputs[id] = v ? 1 : 0;
                        sim.step(DateTime.now());
                      },
                    ),
                  ),
                ],
              ),
            ),
            CreamCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('数据状态'),
                  ...[1, 2, 3, 4].map(
                    (id) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        initialValue: sim.invalid.contains(id)
                            ? 'invalid'
                            : sim.frozen.contains(id)
                            ? 'stale'
                            : 'valid',
                        decoration: InputDecoration(labelText: moduleNames[id]),
                        items: const [
                          DropdownMenuItem(value: 'valid', child: Text('正常更新')),
                          DropdownMenuItem(
                            value: 'invalid',
                            child: Text('读取异常'),
                          ),
                          DropdownMenuItem(value: 'stale', child: Text('停止更新')),
                        ],
                        onChanged: (v) {
                          sim.invalid.remove(id);
                          sim.frozen.remove(id);
                          if (v == 'invalid') sim.invalid.add(id);
                          if (v == 'stale') sim.frozen.add(id);
                          sim.step(DateTime.now());
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            CreamCard(
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('名单可用'),
                    value: sim.config.listAvailable,
                    onChanged: (v) {
                      sim.config = sim.config.patch({'listAvailable': v});
                      setState(() {});
                    },
                  ),
                  Text(
                    '缓存丢弃 ${sim.dropped} 条 · 事件丢弃 ${sim.droppedEvents + c.discardedEvents} 条',
                    style: const TextStyle(color: Warm.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: () {
                sim.resetInputs();
                for (final e in fields.entries) {
                  e.value.text = sim.inputs[e.key].toString();
                }
                setState(() {});
                message(context, '模拟输入已恢复');
              },
              child: const Text('恢复默认输入'),
            ),
          ],
        ),
      );
    },
  );
}
