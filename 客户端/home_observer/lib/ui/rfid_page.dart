import 'package:flutter/material.dart';
import '../data/home_controller.dart';
import '../domain/models.dart';
import 'events_page.dart';
import 'style.dart';

class RfidPage extends StatefulWidget {
  const RfidPage(this.c, {super.key});
  final HomeController c;
  @override
  State<RfidPage> createState() => _RfidPageState();
}

class _RfidPageState extends State<RfidPage> {
  final card = TextEditingController(text: 'DEMO01');
  bool failed = false;
  @override
  void dispose() {
    card.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return PageBody(
      title: 'RFID 通行',
      children: [
        CreamCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WarmBadge('模拟数据'),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 68,
                    height: 84,
                    decoration: BoxDecoration(
                      color: Warm.blue.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.door_back_door_outlined,
                      size: 45,
                      color: Warm.blue,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('通行状态', style: TextStyle(color: Warm.muted)),
                        const SizedBox(height: 7),
                        Text(
                          '${c.snapshot?.gateOpen == true ? '允许通行' : '关闭'}模拟',
                          style: Warm.title(25),
                        ),
                        if (!c.live)
                          const Text(
                            '状态陈旧',
                            style: TextStyle(color: Warm.clay, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        CreamCard(
          child: Column(
            children: [
              SectionTitle(
                '授权名单',
                action: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CardsPage(c)),
                  ),
                  child: const Text('管理 ›'),
                ),
              ),
              if (c.config.cards.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('暂无授权卡片', style: TextStyle(color: Warm.muted)),
                ),
              ...c.config.cards.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      _cardIcon(Warm.clay),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.label, style: Warm.title(17)),
                            Text(
                              entry.uid,
                              style: const TextStyle(
                                color: Warm.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      WarmBadge(
                        entry.enabled ? '已授权' : '已停用',
                        color: entry.enabled ? Warm.blue : Warm.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        CreamCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('最近刷卡'),
              if (c.swipes.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('暂无刷卡记录', style: TextStyle(color: Warm.muted)),
                ),
              ...c.swipes
                  .take(8)
                  .map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          _cardIcon(r.allowed ? Warm.blue : Warm.clay),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.uid,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${dateLabel(r.at)} ${hm(r.at)}',
                                  style: const TextStyle(
                                    color: Warm.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          WarmBadge(
                            r.reason,
                            color: r.allowed ? Warm.blue : Warm.clay,
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
        if (c.adapter.isSimulation)
          CreamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('模拟刷卡'),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: card,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(hintText: '卡片标识'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: () {
                        final result = c.simulation!.swipe(
                          card.text,
                          failed: failed,
                        );
                        message(context, result);
                      },
                      child: const Text('刷卡'),
                    ),
                  ],
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: failed,
                  onChanged: (v) => setState(() => failed = v ?? false),
                  title: const Text('读卡失败', style: TextStyle(fontSize: 13)),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cardIcon(Color color) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      shape: BoxShape.circle,
    ),
    child: Icon(Icons.credit_card, size: 22, color: color),
  );
}

class CardsPage extends StatefulWidget {
  const CardsPage(this.c, {super.key});
  final HomeController c;
  @override
  State<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends State<CardsPage> {
  late List<CardEntry> entries;
  String? error;
  @override
  void initState() {
    super.initState();
    entries = List.of(widget.c.config.cards);
  }

  Future<void> add() async {
    final uid = TextEditingController(), name = TextEditingController();
    final result = await showDialog<CardEntry>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('添加卡片', style: Warm.title(21)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: uid,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: '卡片标识'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              CardEntry(uid.text.trim().toUpperCase(), name.text.trim()),
            ),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        entries.add(result);
        error = null;
      });
    }
    // Controllers remain alive until the closing dialog animation finishes.
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      uid.dispose();
      name.dispose();
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.c,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text('授权名单', style: Warm.title(24)),
        backgroundColor: Warm.background,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ...entries.asMap().entries.map(
            (item) => CreamCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.value.label, style: Warm.title(19)),
                        Text(
                          item.value.uid,
                          style: const TextStyle(color: Warm.muted),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: item.value.enabled,
                    onChanged: (v) => setState(
                      () => entries[item.key] = CardEntry(
                        item.value.uid,
                        item.value.label,
                        enabled: v,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '移除 ${item.value.label}',
                    onPressed: () => setState(() => entries.removeAt(item.key)),
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Warm.clay,
                    ),
                  ),
                ],
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: add,
            icon: const Icon(Icons.add),
            label: const Text('添加卡片'),
          ),
          const SizedBox(height: 16),
          if (error != null)
            Text(error!, style: const TextStyle(color: Warm.clay)),
          FilledButton(
            onPressed: widget.c.pending
                ? null
                : () async {
                    final proposed = widget.c.config.patch({
                      'cards': entries.map((c) => c.toJson()).toList(),
                    });
                    final validation = proposed.validate();
                    if (validation != null) {
                      setState(() => error = validation);
                      return;
                    }
                    await widget.c.applySettings(proposed);
                    if (!context.mounted) return;
                    if (widget.c.latestOperation?.state ==
                        RequestState.accepted) {
                      Navigator.pop(context);
                      message(context, '名单已生效');
                    }
                  },
            child: Text(widget.c.pending ? '等待设备结果' : '提交名单'),
          ),
          if (widget.c.latestOperation != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
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
