import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/models.dart';
import 'style.dart';

class TemperatureChart extends StatelessWidget {
  const TemperatureChart(
    this.points, {
    super.key,
    this.moduleId = 1,
    this.height = 132,
  });
  final List<HistoryPoint> points;
  final int moduleId;
  final double height;
  @override
  Widget build(BuildContext context) {
    final values = points
        .map((p) => p.samples.where((s) => s.id == moduleId).firstOrNull)
        .toList();
    final count = values
        .where((s) => s?.quality == Quality.valid && s?.value != null)
        .length;
    if (count < 2)
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            '等待更多记录',
            style: TextStyle(color: Warm.muted, fontSize: 12),
          ),
        ),
      );
    return Semantics(
      label: '${moduleNames[moduleId]}历史曲线，$count 条有效模拟记录',
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: CustomPaint(painter: _ChartPainter(points, moduleId)),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.points, this.id);
  final List<HistoryPoint> points;
  final int id;
  void label(Canvas canvas, String text, Offset pos, {bool right = false}) {
    final p = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Warm.muted,
          fontSize: 10,
          fontFamily: 'HomeSerif',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(canvas, right ? pos - Offset(p.width, 0) : pos);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final valid = points
        .expand(
          (p) => p.samples.where(
            (s) => s.id == id && s.quality == Quality.valid && s.value != null,
          ),
        )
        .map((s) => s.value!)
        .toList();
    if (valid.length < 2) return;
    final minimum = valid.reduce(math.min),
        maximum = valid.reduce(math.max),
        pad = math.max((maximum - minimum) * .25, id == 1 ? 1.0 : 2.0),
        low = minimum - pad,
        high = maximum + pad;
    final r = Rect.fromLTRB(30, 8, size.width - 5, size.height - 24);
    final grid = Paint()
      ..color = Warm.line
      ..strokeWidth = .8;
    for (var i = 0; i < 3; i++) {
      final y = r.top + r.height * i / 2;
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), grid);
      label(
        canvas,
        (high - (high - low) * i / 2).toStringAsFixed(0),
        Offset(0, y - 7),
      );
    }
    label(canvas, hm(points.first.at), Offset(r.left, r.bottom + 9));
    label(
      canvas,
      hm(points.last.at),
      Offset(r.right, r.bottom + 9),
      right: true,
    );
    final total = points.last.at
        .difference(points.first.at)
        .inMilliseconds
        .toDouble();
    final line = Paint()
      ..color = Warm.clay
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    Path? segment;
    Offset? last;
    void finish() {
      if (segment == null || last == null) return;
      final area = Path.from(segment!)
        ..lineTo(last!.dx, r.bottom)
        ..lineTo(_segmentStart!.dx, r.bottom)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x28BC6147), Color(0x03BC6147)],
          ).createShader(r),
      );
      canvas.drawPath(segment!, line);
      segment = null;
      last = null;
    }

    for (final p in points) {
      final sample = p.samples.where((s) => s.id == id).firstOrNull;
      if (sample == null ||
          sample.quality != Quality.valid ||
          sample.value == null) {
        finish();
        continue;
      }
      final x =
          r.left +
          r.width *
              (total <= 0
                  ? 0
                  : p.at.difference(points.first.at).inMilliseconds / total);
      final y = r.bottom - r.height * (sample.value! - low) / (high - low);
      final at = Offset(x, y);
      if (segment == null) {
        segment = Path()..moveTo(x, y);
        _segmentStart = at;
      } else {
        segment!.lineTo(x, y);
      }
      last = at;
    }
    finish();
  }

  Offset? _segmentStart;
  @override
  bool shouldRepaint(covariant _ChartPainter old) => true;
}
