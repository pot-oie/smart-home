import 'package:flutter/material.dart';
import '../data/home_controller.dart';
import '../domain/models.dart';
import 'details.dart';
import 'events_page.dart';
import 'style.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage(this.c, {super.key});
  final HomeController c;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final fields = <String, TextEditingController>{
    for (final k in [
      'tLow',
      'tHigh',
      'tMargin',
      'hLow',
      'hHigh',
      'hMargin',
      'lightOpen',
      'lightClose',
      'holdSeconds',
    ])
      k: TextEditingController(),
  };
  Settings? _bound;
  bool automatic = true, armed = true, curtainOpen = false;
  String? error;
  bool advanced = false;
  bool dirty = false, submitted = false;
  void fill(Settings c) {
    _bound = c;
    dirty = false;
    for (final key in fields.keys) {
      fields[key]!.text = c.toJson()[key].toString();
    }
    automatic = c.automatic;
    armed = c.armed;
    curtainOpen = c.curtainOpen;
  }

  @override
  void initState() {
    super.initState();
    fill(widget.c.config);
  }

  @override
  void dispose() {
    for (final f in fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  Widget field(String key, String label, String unit) => TextField(
    controller: fields[key],
    onChanged: (_) => setState(() {
      dirty = true;
      submitted = false;
    }),
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    ),
    decoration: InputDecoration(labelText: label, suffixText: unit),
  );
  Widget pair(Widget a, Widget b) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: a),
      const SizedBox(width: 12),
      Expanded(child: b),
    ],
  );
  Future<void> submit() async {
    try {
      final draft = <String, dynamic>{};
      for (final key in fields.keys) {
        draft[key] = key == 'holdSeconds'
            ? int.parse(fields[key]!.text)
            : double.parse(fields[key]!.text);
      }
      draft.addAll({
        'automatic': automatic,
        'armed': armed,
        'curtainOpen': curtainOpen,
      });
      final proposed = widget.c.config.patch(draft);
      final validation = proposed.validate();
      if (validation != null) {
        setState(() => error = validation);
        return;
      }
      setState(() {
        error = null;
        submitted = true;
      });
      await widget.c.applySettings(proposed);
    } catch (_) {
      setState(() => error = '请填写有效数值，持续时间需为整数');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bound != widget.c.config) fill(widget.c.config);
    final c = widget.c;
    return PageBody(
      title: '设置',
      children: [
        const Align(alignment: Alignment.centerLeft, child: WarmBadge('模拟数据')),
        const SizedBox(height: 18),
        CreamCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('环境报警'),
              pair(field('tLow', '温度下限', '°C'), field('tHigh', '温度上限', '°C')),
              const SizedBox(height: 14),
              pair(field('hLow', '湿度下限', '%RH'), field('hHigh', '湿度上限', '%RH')),
              const SizedBox(height: 14),
              field('holdSeconds', '持续时间', '秒'),
              TextButton(
                onPressed: () => setState(() => advanced = !advanced),
                child: Text(advanced ? '收起恢复区间' : '恢复区间'),
              ),
              if (advanced) ...[
                pair(
                  field('tMargin', '温度恢复余量', '°C'),
                  field('hMargin', '湿度恢复余量', '%RH'),
                ),
              ],
            ],
          ),
        ),
        CreamCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionTitle('窗帘模拟'),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: true, label: Text('自动')),
                  ButtonSegment(value: false, label: Text('手动')),
                ],
                selected: {automatic},
                onSelectionChanged: (v) => setState(() {
                  automatic = v.first;
                  dirty = true;
                  submitted = false;
                }),
              ),
              const SizedBox(height: 15),
              if (!automatic)
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: true, label: Text('开帘模拟')),
                    ButtonSegment(value: false, label: Text('关帘模拟')),
                  ],
                  selected: {curtainOpen},
                  onSelectionChanged: (v) => setState(() {
                    curtainOpen = v.first;
                    dirty = true;
                    submitted = false;
                  }),
                ),
              if (automatic)
                pair(
                  field('lightOpen', '开帘相对光强', ''),
                  field('lightClose', '关帘相对光强', ''),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('当前状态', style: TextStyle(color: Warm.muted)),
                  const Spacer(),
                  Text('${c.snapshot?.curtainOpen == true ? '开帘' : '关帘'}模拟'),
                ],
              ),
            ],
          ),
        ),
        CreamCard(
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Warm.gold.withValues(alpha: .2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  color: Warm.gold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('活动布防', style: Warm.title(20))),
              Switch(
                value: armed,
                onChanged: (v) => setState(() {
                  armed = v;
                  dirty = true;
                  submitted = false;
                }),
              ),
            ],
          ),
        ),
        CreamCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.grid_view_rounded, color: Warm.blue),
                title: const Text('模块管理'),
                trailing: const Icon(Icons.chevron_right, color: Warm.muted),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ModulesPage(c)),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link, color: Warm.blue),
                title: const Text('设备连接'),
                subtitle: Text(
                  c.live ? '模拟设备在线' : '设备断连',
                  style: const TextStyle(fontSize: 12, color: Warm.muted),
                ),
                trailing: const Icon(Icons.chevron_right, color: Warm.muted),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SimulationPage(c)),
                ),
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(error!, style: const TextStyle(color: Warm.clay)),
          ),
        FilledButton(
          onPressed: c.pending ? null : submit,
          child: Text(c.pending ? '等待设备结果' : '提交设置'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            (c.latestOperation == null || (dirty && !submitted))
                ? '未提交'
                : operationText(c.latestOperation!),
            textAlign: TextAlign.center,
            style: TextStyle(
              color:
                  c.latestOperation?.state == RequestState.rejected ||
                      c.latestOperation?.state == RequestState.timeout
                  ? Warm.clay
                  : Warm.muted,
              fontSize: 12,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => OperationsPage(c)),
          ),
          child: const Text('操作记录'),
        ),
      ],
    );
  }
}
