import 'package:flutter/material.dart';

class Warm {
  static const background = Color(0xFFF5F0E7),
      card = Color(0xFFFCF9F3),
      ink = Color(0xFF382519),
      muted = Color(0xFF998E80),
      clay = Color(0xFFBC6147),
      blue = Color(0xFF596F7B),
      gold = Color(0xFFEBC778),
      line = Color(0xFFE9E1D5);
  static TextStyle title(double size) => TextStyle(
    fontFamily: 'HomeSerif',
    fontSize: size,
    fontWeight: FontWeight.w600,
    color: ink,
    height: 1.22,
  );
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'HomeSerif',
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: clay,
      brightness: Brightness.light,
      surface: card,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: ink, fontSize: 14, height: 1.5),
      bodySmall: TextStyle(color: muted, fontSize: 12, height: 1.45),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: clay,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: clay),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? clay
              : line.withValues(alpha: .55),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.white : muted,
        ),
        side: const WidgetStatePropertyAll(BorderSide.none),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
    ),
    dividerColor: line,
  );
}

String hm(DateTime? d) => d == null
    ? '—'
    : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String dateLabel(DateTime d) {
  final n = DateTime.now();
  if (d.year == n.year && d.month == n.month && d.day == n.day) return '今日';
  return '${d.month}月${d.day}日';
}

class CreamCard extends StatelessWidget {
  const CreamCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = const EdgeInsets.only(bottom: 14),
  });
  final Widget child;
  final EdgeInsets padding, margin;
  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    padding: padding,
    decoration: BoxDecoration(
      color: Warm.card,
      borderRadius: BorderRadius.circular(26),
    ),
    child: child,
  );
}

class WarmHeader extends StatelessWidget {
  const WarmHeader(this.title, {super.key, this.large = false});
  final String title;
  final bool large;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: large ? 180 : 130,
    child: Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned(
          right: -70,
          top: large ? -20 : -78,
          width: 350,
          height: large ? 220 : 230,
          child: Image.asset(
            'assets/images/home_art.png',
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ),
        Positioned(
          left: 23,
          bottom: large ? 48 : 34,
          right: 110,
          child: Text(title, style: Warm.title(large ? 37 : 32), maxLines: 2),
        ),
      ],
    ),
  );
}

class WarmBadge extends StatelessWidget {
  const WarmBadge(this.text, {super.key, this.color = Warm.muted});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(text, style: TextStyle(fontSize: 12, color: color)),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Expanded(child: Text(title, style: Warm.title(21))),
        if (action != null) action!,
      ],
    ),
  );
}

class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.title,
    required this.children,
    this.large = false,
  });
  final String title;
  final List<Widget> children;
  final bool large;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WarmHeader(title, large: large),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.label, {super.key, this.icon = Icons.inbox_outlined});
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => CreamCard(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(icon, size: 32, color: Warm.muted),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: Warm.muted)),
        ],
      ),
    ),
  );
}

void message(BuildContext context, String text) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(text), backgroundColor: Warm.ink));
