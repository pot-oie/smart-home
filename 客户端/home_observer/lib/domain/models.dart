enum Quality { valid, invalid, stale, disabled, initializing }

enum ReplyMode { accept, reject, timeout }

enum RequestState { pending, accepted, rejected, timeout }

const moduleNames = <int, String>{
  1: '温度',
  2: '湿度',
  3: '光敏',
  4: 'RFID',
  5: '人体红外',
  6: '震动',
  7: '火焰',
  8: '燃气',
  9: '水接触',
  10: '空气质量',
  11: '声音',
  12: '土壤湿度',
  13: '倾斜',
  14: '距离',
};
const qualityNames = <Quality, String>{
  Quality.valid: '有效',
  Quality.invalid: '读取异常',
  Quality.stale: '陈旧',
  Quality.disabled: '未启用',
  Quality.initializing: '初始化',
};

class Sample {
  final int id;
  final double? value;
  final Quality quality;
  final DateTime? sampledAt;
  const Sample(this.id, this.value, this.quality, this.sampledAt);
  String get name => moduleNames[id] ?? '未知模块';
  String get unit => switch (id) {
    1 => '°C',
    2 => '%RH',
    3 => '相对 %',
    8 => '原始量',
    10 || 11 || 12 => '相对量',
    _ => '状态',
  };
  Quality effective(DateTime now, bool connected) =>
      quality == Quality.valid &&
          (!connected ||
              sampledAt == null ||
              now.difference(sampledAt!) > const Duration(seconds: 5))
      ? Quality.stale
      : quality;
  Map<String, dynamic> toJson() => {
    'id': id,
    'value': value,
    'quality': quality.name,
    'sampledAt': sampledAt?.toIso8601String(),
  };
  factory Sample.fromJson(Map<String, dynamic> j) => Sample(
    j['id'],
    (j['value'] as num?)?.toDouble(),
    Quality.values.byName(j['quality']),
    j['sampledAt'] == null ? null : DateTime.parse(j['sampledAt']),
  );
}

class CardEntry {
  final String uid, label;
  final bool enabled;
  const CardEntry(this.uid, this.label, {this.enabled = true});
  Map<String, dynamic> toJson() => {
    'uid': uid,
    'label': label,
    'enabled': enabled,
  };
  factory CardEntry.fromJson(Map<String, dynamic> j) =>
      CardEntry(j['uid'], j['label'], enabled: j['enabled'] ?? true);
}

class Settings {
  final double tLow,
      tHigh,
      tMargin,
      hLow,
      hHigh,
      hMargin,
      lightOpen,
      lightClose;
  final int holdSeconds;
  final bool armed, automatic, curtainOpen, listAvailable;
  final List<int> enabled;
  final List<CardEntry> cards;
  const Settings({
    this.tLow = 10,
    this.tHigh = 30,
    this.tMargin = 1,
    this.hLow = 20,
    this.hHigh = 80,
    this.hMargin = 3,
    this.lightOpen = 35,
    this.lightClose = 65,
    this.holdSeconds = 3,
    this.armed = true,
    this.automatic = true,
    this.curtainOpen = false,
    this.listAvailable = true,
    this.enabled = const [1, 2, 3, 4, 5, 6, 7, 8, 9],
    this.cards = const [
      CardEntry('DEMO01', '演示卡 01'),
      CardEntry('DEMO02', '演示卡 02'),
    ],
  });
  Map<String, dynamic> toJson() => {
    'tLow': tLow,
    'tHigh': tHigh,
    'tMargin': tMargin,
    'hLow': hLow,
    'hHigh': hHigh,
    'hMargin': hMargin,
    'lightOpen': lightOpen,
    'lightClose': lightClose,
    'holdSeconds': holdSeconds,
    'armed': armed,
    'automatic': automatic,
    'curtainOpen': curtainOpen,
    'listAvailable': listAvailable,
    'enabled': enabled,
    'cards': cards.map((c) => c.toJson()).toList(),
  };
  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
    tLow: (j['tLow'] as num).toDouble(),
    tHigh: (j['tHigh'] as num).toDouble(),
    tMargin: (j['tMargin'] as num).toDouble(),
    hLow: (j['hLow'] as num).toDouble(),
    hHigh: (j['hHigh'] as num).toDouble(),
    hMargin: (j['hMargin'] as num).toDouble(),
    lightOpen: (j['lightOpen'] as num).toDouble(),
    lightClose: (j['lightClose'] as num).toDouble(),
    holdSeconds: j['holdSeconds'],
    armed: j['armed'],
    automatic: j['automatic'],
    curtainOpen: j['curtainOpen'],
    listAvailable: j['listAvailable'],
    enabled: List<int>.from(j['enabled']),
    cards: (j['cards'] as List)
        .map((c) => CardEntry.fromJson(Map<String, dynamic>.from(c)))
        .toList(),
  );
  Settings patch(Map<String, dynamic> patch) =>
      Settings.fromJson({...toJson(), ...patch});
  String? validate() {
    if ([
      tLow,
      tHigh,
      tMargin,
      hLow,
      hHigh,
      hMargin,
      lightOpen,
      lightClose,
    ].any((n) => !n.isFinite))
      return '数值必须有效';
    if (tLow >= tHigh || tMargin <= 0 || tMargin * 2 >= tHigh - tLow)
      return '温度上下限或恢复余量无效';
    if (hLow < 0 ||
        hHigh > 100 ||
        hLow >= hHigh ||
        hMargin <= 0 ||
        hMargin * 2 >= hHigh - hLow)
      return '湿度范围或恢复余量无效';
    if (holdSeconds < 1 || holdSeconds > 60) return '持续时间需为 1–60 秒';
    if (lightOpen < 0 || lightClose > 100 || lightOpen >= lightClose)
      return '开帘阈值必须小于关帘阈值';
    if (enabled.any((id) => !moduleNames.containsKey(id)) ||
        enabled.toSet().length != enabled.length)
      return '模块编号无效';
    if (cards.length > 100 ||
        cards.any(
          (c) =>
              c.uid.trim().isEmpty ||
              c.uid.length > 32 ||
              c.label.trim().isEmpty,
        ) ||
        cards.map((c) => c.uid).toSet().length != cards.length)
      return '卡片标识需唯一且不超过 32 字符，名单最多 100 项';
    return null;
  }
}

class SafetyEvent {
  final String id, label;
  final int moduleId, revision;
  final DateTime triggeredAt;
  final DateTime? recoveredAt, acknowledgedAt;
  const SafetyEvent({
    required this.id,
    required this.label,
    required this.moduleId,
    required this.triggeredAt,
    this.recoveredAt,
    this.acknowledgedAt,
    this.revision = 1,
  });
  bool get active => recoveredAt == null;
  bool get complete => recoveredAt != null && acknowledgedAt != null;
  SafetyEvent update({
    DateTime? recoveredAt,
    DateTime? acknowledgedAt,
    int? revision,
  }) => SafetyEvent(
    id: id,
    label: label,
    moduleId: moduleId,
    triggeredAt: triggeredAt,
    recoveredAt: recoveredAt ?? this.recoveredAt,
    acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
    revision: revision ?? this.revision + 1,
  );
  Map<String, dynamic> toJson() => {
    'eventId': id,
    'label': label,
    'moduleId': moduleId,
    'revision': revision,
    'triggeredAt': triggeredAt.toIso8601String(),
    'recoveredAt': recoveredAt?.toIso8601String(),
    'acknowledgedAt': acknowledgedAt?.toIso8601String(),
  };
  factory SafetyEvent.fromJson(Map<String, dynamic> j) => SafetyEvent(
    id: j['eventId'],
    label: j['label'],
    moduleId: j['moduleId'],
    revision: j['revision'],
    triggeredAt: DateTime.parse(j['triggeredAt']),
    recoveredAt: j['recoveredAt'] == null
        ? null
        : DateTime.parse(j['recoveredAt']),
    acknowledgedAt: j['acknowledgedAt'] == null
        ? null
        : DateTime.parse(j['acknowledgedAt']),
  );
}

class SwipeRecord {
  final String id, uid, reason;
  final bool allowed;
  final DateTime at;
  const SwipeRecord(this.id, this.uid, this.reason, this.allowed, this.at);
  Map<String, dynamic> toJson() => {
    'id': id,
    'uid': uid,
    'reason': reason,
    'allowed': allowed,
    'at': at.toIso8601String(),
  };
  factory SwipeRecord.fromJson(Map<String, dynamic> j) => SwipeRecord(
    j['id'],
    j['uid'],
    j['reason'],
    j['allowed'],
    DateTime.parse(j['at']),
  );
}

class Snapshot {
  final String bootId;
  final int seq;
  final DateTime at;
  final List<Sample> samples;
  final bool curtainOpen, gateOpen;
  const Snapshot(
    this.bootId,
    this.seq,
    this.at,
    this.samples,
    this.curtainOpen,
    this.gateOpen,
  );
}

class DeviceRequest {
  final String id, action;
  final Map<String, dynamic> args;
  const DeviceRequest(this.id, this.action, this.args);
  Map<String, dynamic> toJson() => {
    'version': 1,
    'kind': 'request',
    'requestId': id,
    'action': action,
    'args': args,
  };
}

class DeviceResult {
  final String requestId;
  final bool accepted;
  final String reason;
  final Settings? config;
  const DeviceResult(
    this.requestId,
    this.accepted, {
    this.reason = '',
    this.config,
  });
}

class DeviceMessage {
  final String kind;
  final Object payload;
  const DeviceMessage(this.kind, this.payload);
}

class Operation {
  final String id, label;
  final DateTime submittedAt;
  RequestState state;
  String reason;
  Operation(
    this.id,
    this.label,
    this.submittedAt, {
    this.state = RequestState.pending,
    this.reason = '',
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'submittedAt': submittedAt.toIso8601String(),
    'state': state.name,
    'reason': reason,
  };
  factory Operation.fromJson(Map<String, dynamic> j) => Operation(
    j['id'],
    j['label'],
    DateTime.parse(j['submittedAt']),
    state: j['state'] == 'pending'
        ? RequestState.timeout
        : RequestState.values.byName(j['state']),
    reason: j['state'] == 'pending' ? '上次会话未收到结果，请核查后重提' : j['reason'],
  );
}

class HistoryPoint {
  final DateTime at;
  final List<Sample> samples;
  const HistoryPoint(this.at, this.samples);
  Map<String, dynamic> toJson() => {
    'at': at.toIso8601String(),
    'samples': samples.map((s) => s.toJson()).toList(),
  };
  factory HistoryPoint.fromJson(Map<String, dynamic> j) => HistoryPoint(
    DateTime.parse(j['at']),
    (j['samples'] as List)
        .map((s) => Sample.fromJson(Map<String, dynamic>.from(s)))
        .toList(),
  );
}
