import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/app_database.dart';
import '../widgets/daily_mood_chart.dart';
import 'add_snapshot_screen.dart';
import 'day_detail_screen.dart';
import '../services/amplification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<DateTime> _days = [];
  bool _isLoading = true;
  
  // Global Schedule Prefs
  TimeOfDay _globalWake = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _globalSleep = const TimeOfDay(hour: 23, minute: 0);

  // Overrides Cache: "YYYY-MM-DD" -> {wake_h:..., ...}
  Map<String, Map<String, int>> _overrides = {};
  int _refreshTimestamp = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> refreshData() async {
    await _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final days = await AppDatabase.getDaysWithData();
    
    // Ensure "Today" is always first, even if no data yet
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (days.isEmpty || days.first != today) {
      if (days.isNotEmpty && days.first.isAfter(today)) {
        // Data from future? Rare but possible.
      } else {
        days.insert(0, today);
      }
    } else {
      // Today exists in data, no need to add
    }
    
    // Load global prefs
    final prefs = await SharedPreferences.getInstance();
    final gWakeH = prefs.getInt('global_wake_h') ?? 8;
    final gWakeM = prefs.getInt('global_wake_m') ?? 0;
    final gSleepH = prefs.getInt('global_sleep_h') ?? 23;
    final gSleepM = prefs.getInt('global_sleep_m') ?? 0;
    
    // Load overrides for visible days ... simplified: load all or just check?
    // We can load on demand or just load for the days we have.
    final Map<String, Map<String, int>> newOverrides = {};
    for (final d in days) {
      final key = DateFormat('yyyy-MM-dd').format(d);
      final ov = await AppDatabase.getDaySchedule(key);
      if (ov != null) {
        newOverrides[key] = ov;
      }
    }

    if (mounted) {
      setState(() {
        _days = days;
        _isLoading = false;
        _globalWake = TimeOfDay(hour: gWakeH, minute: gWakeM);
        _globalSleep = TimeOfDay(hour: gSleepH, minute: gSleepM);
        _overrides = newOverrides;
        _refreshTimestamp = DateTime.now().millisecondsSinceEpoch;
      });
    }
  }

  void _onDayTap(DateTime date) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DayDetailScreen(date: date),
      ),
    );
    _refresh();
  }

  Future<void> _editDaySchedule(DateTime date, TimeOfDay currentWake, TimeOfDay currentSleep) async {
    TimeOfDay w = currentWake;
    TimeOfDay s = currentSleep;

    final changed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Edit Schedule for ${DateFormat('MMM d').format(date)}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Wake Up'),
                    subtitle: Text(w.format(context)),
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: w);
                      if (t != null) setStateDialog(() => w = t);
                    },
                  ),
                  ListTile(
                    title: const Text('Sleep'),
                    subtitle: Text(s.format(context)),
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: s);
                      if (t != null) setStateDialog(() => s = t);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (changed == true) {
      final key = DateFormat('yyyy-MM-dd').format(date);
      await AppDatabase.setDaySchedule(key, w.hour, w.minute, s.hour, s.minute);
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: _days.length + (AmplificationService().isInWindow ? 1 : 0),
              itemBuilder: (context, idx) {
                // If banner is active, it takes index 0
                bool showBanner = AmplificationService().isInWindow;
                if (showBanner) {
                  if (idx == 0) {
                     return Container(
                       margin: const EdgeInsets.all(16),
                       padding: const EdgeInsets.all(16),
                       decoration: BoxDecoration(
                         color: Colors.purple.withOpacity(0.1),
                         border: Border.all(color: Colors.purpleAccent),
                         borderRadius: BorderRadius.circular(16),
                       ),
                       child: const Column(
                         children: [
                            Text('Amplification Window Detected', style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                            SizedBox(height: 4),
                            Text('Your mind is currently amplifying negative signals. Do not interpret thoughts right now.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                         ],
                       ),
                     );
                  }
                }
                
                final index = showBanner ? idx - 1 : idx;
                final date = _days[index];
                final key = DateFormat('yyyy-MM-dd').format(date);
                final ov = _overrides[key];
                
                TimeOfDay wake = _globalWake;
                TimeOfDay sleep = _globalSleep;
                bool isOverride = false;
                
                if (ov != null) {
                  isOverride = true;
                  wake = TimeOfDay(hour: ov['wake_h']!, minute: ov['wake_m']!);
                  sleep = TimeOfDay(hour: ov['sleep_h']!, minute: ov['sleep_m']!);
                }

                return _DayCard(
                  date: date,
                  wakeTime: wake,
                  sleepTime: sleep,
                  isOverride: isOverride,
                  refreshTimestamp: _refreshTimestamp,
                  onTap: () => _onDayTap(date),
                  onEditSchedule: () => _editDaySchedule(date, wake, sleep),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final changed = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddSnapshotScreen()),
          );
          if (changed == true) {
            _refresh();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _DayCard extends StatefulWidget {
  final DateTime date;
  final TimeOfDay wakeTime;
  final TimeOfDay sleepTime;
  final bool isOverride;
  final int refreshTimestamp;
  final VoidCallback onTap;
  final VoidCallback onEditSchedule;

  const _DayCard({
    required this.date,
    required this.wakeTime,
    required this.sleepTime,
    required this.isOverride,
    required this.refreshTimestamp,
    required this.onTap,
    required this.onEditSchedule,
  });

  @override
  State<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<_DayCard> {
  late Future<List<MoodSnapshot>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _dataFuture = AppDatabase.getSnapshotsForDay(widget.date);
  }

  @override
  void didUpdateWidget(covariant _DayCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.date != oldWidget.date || 
        widget.refreshTimestamp != oldWidget.refreshTimestamp) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1e1e1e), // Dark Matte
            Color(0xFF252525),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: widget.onEditSchedule,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Text(
                            DateFormat('EEEE').format(widget.date).toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM d').format(widget.date),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit, size: 16, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              SizedBox(
                height: 300,
                child: FutureBuilder<List<MoodSnapshot>>(
                  future: _dataFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    return DailyMoodChart(
                      date: widget.date,
                      snapshots: snapshot.data ?? [],
                      wakeTime: widget.wakeTime,
                      sleepTime: widget.sleepTime,
                      isOverride: widget.isOverride,
                      onChartTap: widget.onTap,
                      onPointTap: (s) async {
                         // Edit the snapshot
                         final changed = await Navigator.push(
                           context,
                           MaterialPageRoute(
                             builder: (_) => AddSnapshotScreen(existingSnapshot: s),
                           ),
                         );
                         if (changed == true) {
                           _load();
                         }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
     ),
    );
  }
}
