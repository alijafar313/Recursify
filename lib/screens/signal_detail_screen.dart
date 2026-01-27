import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/app_database.dart';
import '../widgets/generic_chart.dart';

class SignalDetailScreen extends StatefulWidget {
  final Map<String, dynamic> signal;

  const SignalDetailScreen({super.key, required this.signal});

  @override
  State<SignalDetailScreen> createState() => _SignalDetailScreenState();
}

class _SignalDetailScreenState extends State<SignalDetailScreen> {
  List<DateTime> _days = []; // List of days to show (Today + past days with data)
  Map<String, List<Map<String, dynamic>>> _dayLogs = {}; // Cache of logs per day
  Map<String, TimeOfDay> _dayWakes = {}; 
  Map<String, TimeOfDay> _daySleeps = {};
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    
    // 1. Get List of Days (all days with data, plus Today)
    final days = await AppDatabase.getSignalDays(widget.signal['id']);
    
    // 2. Pre-load data for these days (Optimization: could be lazy, but for V1 just load)
    // Actually, let's load on demand or just loop. For < 100 days it's instant.
    // Let's loop.
    
    final Map<String, List<Map<String, dynamic>>> logsMap = {};
    final Map<String, TimeOfDay> wMap = {};
    final Map<String, TimeOfDay> sMap = {};

    for (final d in days) {
       final dayStr = DateFormat('yyyy-MM-dd').format(d);
       
       // Logs
       final logs = await AppDatabase.getSignalLogsForDay(widget.signal['id'], d);
       logsMap[dayStr] = logs;
       
       // Schedule
       final schedule = await AppDatabase.getDaySchedule(dayStr);
       TimeOfDay w = const TimeOfDay(hour: 6, minute: 0);
       TimeOfDay s = const TimeOfDay(hour: 23, minute: 0);

       if (schedule != null) {
          w = TimeOfDay(hour: schedule['wake_h']!, minute: schedule['wake_m']!);
          s = TimeOfDay(hour: schedule['sleep_h']!, minute: schedule['sleep_m']!);
       } else {
           // Fallback to global (could change per day if we tracked global history, but simplified to current global)
           final prefs = await SharedPreferences.getInstance();
           w = TimeOfDay(hour: prefs.getInt('global_wake_h') ?? 6, minute: prefs.getInt('global_wake_m') ?? 0);
           s = TimeOfDay(hour: prefs.getInt('global_sleep_h') ?? 23, minute: prefs.getInt('global_sleep_m') ?? 0);
       }
       wMap[dayStr] = w;
       sMap[dayStr] = s;
    }

    setState(() {
      _days = days;
      _dayLogs = logsMap;
      _dayWakes = wMap;
      _daySleeps = sMap;
      _isLoading = false;
    });
  }

  Future<void> _logValue() async {
    // Show slider dialog
    int _val = 5;
    final noteController = TextEditingController();
    final isPos = (widget.signal['is_positive'] as int? ?? 1) == 1; // DB 1=True, 0=False check
    final colorVal = widget.signal['color_hex'] as int? ?? (isPos ? 0xFF00E676 : 0xFFFF5252);
    final themeColor = Color(colorVal);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Log ${widget.signal['name']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Low (1)', style: TextStyle(color: Colors.white54)),
                      Text('$_val', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      const Text('High (10)', style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                  Slider(
                    value: _val.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    activeColor: themeColor,
                    onChanged: (v) => setSheetState(() => _val = v.toInt()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: noteController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Note (Optional)',
                      labelStyle: TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _saveLog(_val, noteController.text.trim());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Log Entry', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveLog(int value, String note) async {
    await AppDatabase.logSignal(widget.signal['id'], value, note.isEmpty ? null : note, DateTime.now());
    _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    // Determine color based on type
    final isPos = (widget.signal['is_positive'] as int? ?? 1) == 1; 
    final colorVal = widget.signal['color_hex'] as int? ?? (isPos ? 0xFF00E676 : 0xFFFF5252);
    final color = Color(colorVal);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.signal['name']),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () async {
               // ... delete logic
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _logValue,
        backgroundColor: color,
        label: const Text('Log Now', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add, color: Colors.black),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: _days.length,
            itemBuilder: (context, index) {
              final date = _days[index];
              final dayStr = DateFormat('yyyy-MM-dd').format(date);
              final logs = _dayLogs[dayStr] ?? [];
              final w = _dayWakes[dayStr];
              final s = _daySleeps[dayStr];
              
              return Container(
                margin: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMM d').format(date),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 24, 24, 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                           BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: GenericChart(
                        logs: logs,
                        baseColor: color,
                        minVal: 1, 
                        maxVal: 10, 
                        wakeTime: w,
                        sleepTime: s,
                        isPositiveSignal: isPos,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }
}
