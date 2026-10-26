import 'package:flutter/material.dart';
import '../data/home_controller.dart';
import '../domain/models.dart';
import 'style.dart';

class EventsPage extends StatefulWidget {
  const EventsPage(this.c, {super.key});
  final HomeController c;
  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  bool history = false;
  @override
  Widget build(BuildContext context) {
    final events = widget.c.sortedEvents
        .where((e) => history ? e.complete : !e.complete)
        .toList();
    return PageBody(
      title: '安全事件',
      children: [
        const Align(alignment: Alignment.centerLeft, child: WarmBadge('模拟数据')),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('待处理')),
              ButtonSegment(value: true, label: Text('历史')),
            ],
            selected: {history},
            onSelectionChanged: (v) => setState(() => history = v.first),
          ),
        ),
        const SizedBox(height: 22),
        if (events.isEmpty)
          EmptyState(
            history ? '暂无已结束事件' : '暂无待处理事件',
            icon: Icons.verified_user_outlined,
          ),
        ...events.map((e) => _event(context, e)),
      ],
    );
  }

  Widget _event(BuildContext context, SafetyEvent e) {
    final quality = widget.c.quality(e.moduleId);
    final known = quality == Quality.valid;
    final waiting = widget.c.operations.any(
      (o) => o.label == '确认 ${e.label}' && o.state == RequestState.pending,
    );
    return CreamCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (e.active ? Warm.clay : Warm.blue).withValues(
                    alpha: .12,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  e.moduleId <= 2
                      ? Icons.thermostat_outlined
                      : Icons.sensors_outlined,
                  color: e.active ? Warm.clay : Warm.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.label, style: Warm.title(20)),
                    Text(
                      '${dateLabel(e.triggeredAt)} ${hm(e.triggeredAt)}',
                      style: const TextStyle(color: Warm.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              WarmBadge(
                e.active ? (known ? '持续异常' : '现场状态未知') : '已恢复',
                color: e.active ? Warm.clay : Warm.blue,
              ),
              WarmBadge(
                e.acknowledgedAt == null ? '未确认' : '已确认',
                color: e.acknowledgedAt == null
                    ? const Color(0xFF9F7731)
                    : Warm.blue,
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Divider(height: 1),
          const SizedBox(height: 15),
          Wrap(
            spacing: 30,
            runSpacing: 13,
            children: [
              _time('触发', e.triggeredAt),
              _time('恢复', e.recoveredAt),
              _time('确认', e.acknowledgedAt),
            ],
          ),
          if (e.acknowledgedAt == null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: waiting
                    ? null
                    : () async {
                        await widget.c.acknowledge(e);
                        if (context.mounted) message(context, '确认请求已提交，等待设备结果');
                      },
                child: Text(waiting ? '等待结果' : '确认知晓'),
              ),
            ),
          ],
          if (widget.c.latestOperation?.label == '确认 ${e.label}') ...[
            const SizedBox(height: 10),
            Text(
              operationText(widget.c.latestOperation!),
              style: const TextStyle(color: Warm.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _time(String label, DateTime? at) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Warm.muted, fontSize: 12)),
      Text(hm(at), style: const TextStyle(fontSize: 20)),
    ],
  );
}

String operationText(Operation o) => switch (o.state) {
  RequestState.pending => '等待设备结果',
  RequestState.accepted => '设备已接受',
  RequestState.rejected => '已拒绝：${o.reason}',
  RequestState.timeout => '已超时：${o.reason}',
};
