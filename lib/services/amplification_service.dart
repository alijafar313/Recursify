import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/app_database.dart';
import 'package:intl/intl.dart';

class AmplificationService {
  static final AmplificationService _instance = AmplificationService._internal();
  factory AmplificationService() => _instance;
  AmplificationService._internal();

  bool _isInWindow = false;
  Map<String, double>? _windowDef;

  bool get isInWindow => _isInWindow;

  /// Call this periodically or on resume
  Future<void> checkState() async {
    // 1. Get Window Definition (e.g. from DB or Prefs)
    // For V1, we simulate "Discovery" after seeding.
    // If seeded, we use the hardcoded definition from AppDatabase.
    _windowDef = await AppDatabase.analyzeAmplificationWindow();
    
    if (_windowDef == null) {
      _isInWindow = false;
      return;
    }

    final startOffset = _windowDef!['start']!;
    final endOffset = _windowDef!['end']!;

    // 2. Get User's Target Sleep Time for TODAY
    final now = DateTime.now();
    final dayStr = DateFormat('yyyy-MM-dd').format(now);
    
    // Check if we have an override
    final schedule = await AppDatabase.getDaySchedule(dayStr); 
    
    // Default 23:00 if no override
    TimeOfDay sleepTime = const TimeOfDay(hour: 23, minute: 0);
    if (schedule != null) {
      sleepTime = TimeOfDay(hour: schedule['sleep_h']!, minute: schedule['sleep_m']!);
    } else {
       final prefs = await SharedPreferences.getInstance();
       final h = prefs.getInt('global_sleep_h') ?? 23;
       final m = prefs.getInt('global_sleep_m') ?? 0;
       sleepTime = TimeOfDay(hour: h, minute: m);
    }

    // 3. Calculate "Minutes until Sleep"
    // Create DateTime for sleep
    DateTime sleepDt = DateTime(now.year, now.month, now.day, sleepTime.hour, sleepTime.minute);
    
    // If sleep is early morning (e.g. 1 AM), it means "Tomorrow" relative to date, 
    // IF 'now' is late evening.
    // E.g. Now is 23:00. Sleep is 01:00. Difference is 2 hours.
    // E.g. Now is 00:30. Sleep is 01:00. Difference is 0.5 hours.
    // Handling "Next Day Sleep" logic:
    if (sleepTime.hour < 12 && now.hour > 12) {
       sleepDt = sleepDt.add(const Duration(days: 1));
    }
    
    final diff = sleepDt.difference(now);
    final hoursUntilSleep = diff.inMinutes / 60.0;

    // Window logic: "Between 2.5 hours before and 0.5 hours before"
    // means hoursUntilSleep is between 0.5 and 2.5.
    
    // Offset is negative, relative to sleep being 0.
    // startOffset = -2.5. endOffset = -0.5.
    // Current 'offset' = -hoursUntilSleep.
    
    final currentOffset = -hoursUntilSleep;
    
    if (currentOffset >= startOffset && currentOffset <= endOffset) {
        _isInWindow = true;
    } else {
        _isInWindow = false;
    }
  }
}
