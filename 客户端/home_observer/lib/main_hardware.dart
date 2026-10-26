import 'package:flutter/material.dart';
import 'ui/hardware_page.dart';
import 'ui/style.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      title: '家居观察 · 实物读数',
      debugShowCheckedModeBanner: false,
      theme: Warm.theme,
      home: const HardwarePage(),
    ),
  );
}
