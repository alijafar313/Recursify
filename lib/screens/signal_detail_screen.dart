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
                      child: Stack(
                        children: [
                          // The Chart
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0), // Space for button
                            child: GenericChart(
                              logs: logs,
                              baseColor: color,
                              minVal: 1, 
                              maxVal: 10, 
                              wakeTime: w,
                              sleepTime: s,
                              isPositiveSignal: isPos,
                              // onSpotTap removed, interaction is via the button
                            ),
                          ),
                          // The Edit Button
                          Positioned(
                            top: 0,
                            right: 0,
                            child: InkWell(
                              onTap: () => _showDayEditor(date, logs),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.edit, size: 14, color: Colors.white70),
                                    SizedBox(width: 4),
                                    Text('Edit', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  // Shows a list of all logs for the day, with Add/Edit options
  Future<void> _showDayEditor(DateTime date, List<Map<String, dynamic>> logs) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
         return StatefulBuilder(
           builder: (context, setModalState) {
             // Refresh logs in real-time if we edit one? 
             // Ideally we just reload the parent on close, but within this modal we might need local state.
             // For simplicity, we just rebuild the list.
             
             return SafeArea(
               child: Container(
                 height: MediaQuery.of(context).size.height * 0.6,
                 padding: const EdgeInsets.all(24),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Text(
                           DateFormat('MMM d, yyyy').format(date),
                           style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                         ),
                         IconButton(
                           icon: const Icon(Icons.add_circle, color: Colors.blueAccent, size: 32),
                           onPressed: () async {
                              await _addOrEditLog(null, date); // Add new
                              Navigator.pop(context); // Close LIST to refresh everything? Or refresh list?
                              _showDayEditor(date, await AppDatabase.getSignalLogsForDay(widget.signal['id'], date)); // Hacky refresh
                           },
                         )
                       ],
                     ),
                     const SizedBox(height: 16),
                     Expanded(
                       child: logs.isEmpty 
                         ? const Center(child: Text('No logs for this day.', style: TextStyle(color: Colors.white54)))
                         : ListView.separated(
                             itemCount: logs.length,
                             separatorBuilder: (_, __) => const Divider(color: Colors.white24),
                             itemBuilder: (context, index) {
                               final log = logs[index];
                               final dt = DateTime.fromMillisecondsSinceEpoch(log['created_at']);
                               final val = log['value'];
                               final note = log['note'] ?? '';
                               
                               return ListTile(
                                 contentPadding: EdgeInsets.zero,
                                 leading: Container(
                                   width: 40, height: 40,
                                   alignment: Alignment.center,
                                   decoration: BoxDecoration(
                                     color: Colors.white10,
                                     shape: BoxShape.circle,
                                   ),
                                   child: Text('$val', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
                                 ),
                                 title: Text(DateFormat('h:mm a').format(dt), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                 subtitle: note.isNotEmpty ? Text(note, style: const TextStyle(color: Colors.white70)) : null,
                                 trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.white54),
                                        onPressed: () async {
                                           await _addOrEditLog(log, date);
                                           Navigator.pop(context);
                                           _showDayEditor(date, await AppDatabase.getSignalLogsForDay(widget.signal['id'], date));
                                        },
                                      ),
                                    ],
                                 ),
                               );
                             },
                           ),
                     ),
                   ],
                 ),
               ),
             );
           }
         );
      }
    );
    _loadAll(); // Refresh main screen when closed
  }

  // Replaces _editLog. Handles Create (log=null) and Update (log!=null)
  Future<void> _addOrEditLog(Map<String, dynamic>? log, DateTime date) async {
    final isEditing = log != null;
    
    // Initial State
    int _val = isEditing ? (log!['value'] as int) : 5;
    
    // Time Logic
    DateTime initialTime;
    if (isEditing) {
      initialTime = DateTime.fromMillisecondsSinceEpoch(log!['created_at']);
    } else {
      // If "Today", use Now. If past day, use Noon? Or Now if same day?
      final now = DateTime.now();
      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        initialTime = now;
      } else {
        initialTime = DateTime(date.year, date.month, date.day, 12, 0);
      }
    }
    
    TimeOfDay _time = TimeOfDay.fromDateTime(initialTime);
    final noteController = TextEditingController(text: isEditing ? (log!['note'] as String? ?? '') : '');

    // Theme
    final isPos = (widget.signal['is_positive'] as int? ?? 1) == 1;
    final colorVal = widget.signal['color_hex'] as int? ?? (isPos ? 0xFF00E676 : 0xFFFF5252);
    final themeColor = Color(colorVal);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF2C2C2C), // Slightly lighter for nested
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setSheetState) {
           return SafeArea(
             child: Padding(
               padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
               child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Text(isEditing ? 'Edit Point' : 'Add Point', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                         if (isEditing)
                           TextButton(
                             onPressed: () async {
                                await AppDatabase.deleteSignalLog(log['id']);
                                Navigator.pop(context);
                             },
                             child: const Text('Delete', style: TextStyle(color: Colors.red)),
                           ),
                       ],
                     ),
                     const SizedBox(height: 20),
                     
                     // Time Picker Row
                     InkWell(
                       onTap: () async {
                          final t = await showTimePicker(context: context, initialTime: _time);
                          if (t != null) setSheetState(() => _time = t);
                       },
                       child: Container(
                         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                         decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                         child: Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             const Text('Time', style: TextStyle(color: Colors.white70)),
                             Text(_time.format(context), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                           ],
                         ),
                       ),
                     ),
                     const SizedBox(height: 24),
                     
                     // Value Slider
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
                        labelText: 'Note',
                        labelStyle: TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 32),
                     SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          // Construct DateTime
                          final newDt = DateTime(date.year, date.month, date.day, _time.hour, _time.minute);
                          final note = noteController.text.trim();
                          
                          if (isEditing) {
                             await AppDatabase.updateSignalLog(log['id'], _val, note.isEmpty ? null : note, newDt);
                          } else {
                             await AppDatabase.logSignal(widget.signal['id'], _val, note.isEmpty ? null : note, newDt);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
               ),
             ),
           );
        });
      }
    );
  }
} // End class
