import 'package:flutter/material.dart';
import 'screens/main_shell.dart';

// ============================================================
// App entry point
// ============================================================
void main() {
  runApp(const MoodlyApp());
}

// ============================================================
// Top-level app widget
// ============================================================
class MoodlyApp extends StatelessWidget {
  const MoodlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Moodly',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainShell(),
    );
  }
}
