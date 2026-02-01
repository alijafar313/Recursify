import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/app_database.dart';
import '../widgets/habit_editor.dart';

class ObservationsScreen extends StatefulWidget {
  const ObservationsScreen({super.key});

  @override
  State<ObservationsScreen> createState() => _ObservationsScreenState();
}

class _ObservationsScreenState extends State<ObservationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _observations = [];
  List<Map<String, dynamic>> _strategies = [];
  List<Map<String, dynamic>> _habits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
        setState(() {}); // Rebuild FAB when tab changes
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final obs = await AppDatabase.getObservations();
      final strats = await AppDatabase.getProblemSolutions();
      final habits = await AppDatabase.getHabits();
      
      if (mounted) {
        setState(() {
          _observations = List<Map<String, dynamic>>.from(obs);
          _strategies = List<Map<String, dynamic>>.from(strats);
          _habits = List<Map<String, dynamic>>.from(habits);
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Error loading data: $e\n$stack');
       if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  // ---------------------------------------------------------------------------
  // HABITS
  // ---------------------------------------------------------------------------
  
  Future<void> _addOrEditHabit({
    int? id, 
    String? name, 
    int? freq, 
    int? h, 
    int? m, 
    bool? notify,
    int? repeatValue,
    String? repeatUnit,
    String? weekDays,
    int? startDate,
    String? endType,
    int? endValue,
  }) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
         borderRadius: BorderRadius.vertical(top: Radius.circular(20))
      ),
      builder: (ctx) => HabitEditor(
         initialName: name,
         initialFreqDays: freq ?? 1,
         initialH: h ?? 9,
         initialM: m ?? 0,
         initialNotify: notify ?? false,
         repeatValue: repeatValue ?? 1,
         repeatUnit: repeatUnit ?? 'day',
         weekDays: weekDays,
         startDate: startDate,
         endType: endType ?? 'never',
         endValue: endValue,
      )
    );

    if (result != null && result is Map) {
       final rName = result['name'] as String;
       final rH = result['timeH'] as int;
       final rM = result['timeM'] as int;
       final rNotify = result['notify'] as bool;
       final rFreq = result['freqDays'] as int;
       
       final rRepeatVal = result['repeatValue'] as int;
       final rRepeatUnit = result['repeatUnit'] as String;
       final rWeekDays = result['weekDays'] as String?;
       final rStartDate = result['startDate'] as int?;
       final rEndType = result['endType'] as String;
       final rEndValue = result['endValue'] as int?;

       final isEdit = id != null;

       if (isEdit) {
         await AppDatabase.updateHabit(
           id: id!, 
           name: rName, 
           frequencyDays: rFreq, 
           timeH: rH, 
           timeM: rM, 
           notificationsEnabled: rNotify,
           repeatValue: rRepeatVal,
           repeatUnit: rRepeatUnit,
           weekDays: rWeekDays,
           startDate: rStartDate,
           endType: rEndType,
           endValue: rEndValue,
         );
       } else {
         await AppDatabase.insertHabit(
           name: rName, 
           frequencyDays: rFreq, 
           timeH: rH, 
           timeM: rM, 
           notificationsEnabled: rNotify,
           repeatValue: rRepeatVal,
           repeatUnit: rRepeatUnit,
           weekDays: rWeekDays,
           startDate: rStartDate,
           endType: rEndType,
           endValue: rEndValue,
         );
       }
       _load();
    }
  }
  
  Future<void> _deleteHabit(int id) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Habit?'),
          content: const Text('This will move it to the Trash.'),
          actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
          ],
        ),
      );
    
    if (confirmed == true) {
      await AppDatabase.deleteHabit(id);
      _load();
    }
  }

  // ---------------------------------------------------------------------------
  // OBSERVATIONS
  // ---------------------------------------------------------------------------
  
  Future<void> _addOrEditObservation({int? id, String? initialContent}) async {
    String content = initialContent ?? '';
    final isEdit = id != null;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Observation' : 'Add Observation'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. Taking a nap boosted my productivity...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            controller: TextEditingController(text: content),
            onChanged: (val) => content = val,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (content.trim().isNotEmpty) {
                  Navigator.pop(context, true);
                }
              },
              child: Text(isEdit ? 'Save' : 'Add'),
            ),
          ],
        );
      },
    );

    if (result == true && content.trim().isNotEmpty) {
      if (isEdit) {
        await AppDatabase.updateObservation(id!, content.trim());
      } else {
        await AppDatabase.insertObservation(content.trim());
      }
      _load();
    }
  }

  Future<void> _deleteObservation(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Observation?'),
        content: const Text('This will move it to the Trash.'),
        actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    
    if (confirmed == true) {
      await AppDatabase.deleteObservation(id);
      _load();
    }
  }

  // ---------------------------------------------------------------------------
  // STRATEGIES (Problem-Solution)
  // ---------------------------------------------------------------------------

  Future<void> _addOrEditStrategy({int? id, String? initialProblem, String? initialSolution}) async {
    String problem = initialProblem ?? '';
    String solution = initialSolution ?? '';
    final isEdit = id != null;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Strategy' : 'Add Strategy'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Problem',
                  hintText: 'e.g. Tired after work',
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: problem),
                onChanged: (val) => problem = val,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Attempted Solution',
                  hintText: 'e.g. Take a nap',
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: solution),
                onChanged: (val) => solution = val,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (problem.trim().isNotEmpty && solution.trim().isNotEmpty) {
                  Navigator.pop(context, true);
                }
              },
              child: Text(isEdit ? 'Save' : 'Add'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      if (isEdit) {
        await AppDatabase.updateProblemSolution(id!, problem.trim(), solution.trim());
      } else {
        await AppDatabase.insertProblemSolution(problem.trim(), solution.trim());
      }
      _load();
    }
  }

  Future<void> _voteStrategy(int id, bool isUp) async {
    await AppDatabase.voteProblemSolution(id, isUp);
    _load();
  }

  Future<void> _deleteStrategy(int id) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Strategy?'),
          content: const Text('This will move it to the Trash.'),
          actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
          ],
        ),
      );
    
    if (confirmed == true) {
      await AppDatabase.deleteProblemSolution(id);
      _load();
    }
  }

  // ---------------------------------------------------------------------------
  // UI BUILDERS (Strategies & Observations)
  // ---------------------------------------------------------------------------

  Widget _buildObservationsList() {
    if (_observations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.description_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              const Text('No observations yet', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Add notes about your mood patterns.', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
      itemCount: _observations.length,
      itemBuilder: (context, index) {
        final item = _observations[index];
        final id = item['id'] as int;
        final content = item['content'] as String;
        final createdAt = item['created_at'] as int;
        final dateStr = DateFormat('MMM d').format(DateTime.fromMillisecondsSinceEpoch(createdAt));

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _addOrEditObservation(id: id, initialContent: content),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Expanded(child: Text(content, style: const TextStyle(fontSize: 16))),
                         Icon(Icons.edit, size: 16, color: Colors.grey[400]),
                      ],
                   ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(dateStr, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          onPressed: () => _deleteObservation(id),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStrategiesList() {
    if (_strategies.isEmpty) {
       return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.build_circle_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              const Text('No strategies yet', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Log a Problem & Solution to track effectiveness.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
      itemCount: _strategies.length,
      itemBuilder: (context, index) {
        final item = _strategies[index];
        final id = item['id'] as int;
        final problem = item['problem'] as String;
        final solution = item['solution'] as String;
        final up = item['thumbs_up'] as int;
        final down = item['thumbs_down'] as int;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Problem -> Solution Row
                InkWell(
                  onTap: () => _addOrEditStrategy(id: id, initialProblem: problem, initialSolution: solution),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('PROBLEM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.redAccent)),
                            const SizedBox(height: 2),
                            Text(problem, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward, color: Colors.grey),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('SOLUTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.green)),
                            const SizedBox(height: 2),
                            Text(solution, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      Icon(Icons.edit, size: 16, color: Colors.grey[400]),
                    ],
                  ),
                ),
                const Divider(height: 24),
                // Voting Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                     Row(
                       children: [
                         // UP
                         InkWell(
                           onTap: () => _voteStrategy(id, true),
                           borderRadius: BorderRadius.circular(20),
                           child: Padding(
                             padding: const EdgeInsets.all(8.0),
                             child: Row(
                               children: [
                                 const Icon(Icons.thumb_up, size: 18, color: Colors.green),
                                 const SizedBox(width: 4),
                                 Text('$up', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                             ),
                           ),
                         ),
                         const SizedBox(width: 16),
                         // DOWN
                         InkWell(
                           onTap: () => _voteStrategy(id, false),
                           borderRadius: BorderRadius.circular(20),
                           child: Padding(
                             padding: const EdgeInsets.all(8.0),
                             child: Row(
                               children: [
                                 const Icon(Icons.thumb_down, size: 18, color: Colors.redAccent),
                                 const SizedBox(width: 4),
                                 Text('$down', style: const TextStyle(fontWeight: FontWeight.bold)),
                               ],
                             ),
                           ),
                         ),
                       ],
                     ),
                     IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.grey),
                        onPressed: () => _deleteStrategy(id),
                     )
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // FAB Action Logic
  // ---------------------------------------------------------------------------

  void _onFabPressed() {
    final index = _tabController.index;
    if (index == 0) {
      _addOrEditHabit();
    } else if (index == 1) {
      _addOrEditStrategy();
    } else {
      _addOrEditObservation();
    }
  }

  // ---------------------------------------------------------------------------
  // UI BUILDERS
  // ---------------------------------------------------------------------------

  Widget _buildHabitsList() {
    if (_habits.isEmpty) {
        return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120, // Adjust size
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white10, // Subtle background
                ),
                padding: const EdgeInsets.all(24),
                child: Opacity(
                  opacity: 0.9,
                  child: Image.asset(
                    'assets/atomic_habit_molecule.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('No habits yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              const Text('Start building positive routines.', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
      itemCount: _habits.length,
      itemBuilder: (context, index) {
        final item = _habits[index];
        final id = item['id'] as int;
        final name = item['name'] as String;
        final freq = item['frequency_days'] as int;
        final h = item['time_h'] as int;
        final m = item['time_m'] as int;
        final notify = (item['notifications_enabled'] as int) == 1;
        
        // New Recurrence Fields (Check for null for backward compatibility)
        final repeatValue = item['repeat_value'] as int? ?? 1;
        final repeatUnit = item['repeat_unit'] as String? ?? 'day';
        final weekDays = item['week_days'] as String?;
        final startDate = item['start_date'] as int?;
        final endType = item['end_type'] as String? ?? 'never';
        final endValue = item['end_value'] as int?;

        String freqText = 'Daily';
        if (repeatUnit == 'day') {
           if (repeatValue > 1) freqText = 'Every $repeatValue Days';
        } else if (repeatUnit == 'week') {
           freqText = (repeatValue == 1) ? 'Weekly' : 'Every $repeatValue Weeks';
           // Could append "on Mon, Tue" here if space allows
        } else if (repeatUnit == 'month') {
            freqText = 'Monthly';
        }

        // Fallback to legacy if basic
        if (repeatUnit == 'day' && repeatValue == 1 && freq == 7) freqText = 'Weekly';
        
        final timeStr = TimeOfDay(hour: h, minute: m).format(context);

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _addOrEditHabit(
                id: id, 
                name: name, 
                freq: freq, 
                h: h, 
                m: m, 
                notify: notify,
                repeatValue: repeatValue,
                repeatUnit: repeatUnit,
                weekDays: weekDays,
                startDate: startDate,
                endType: endType,
                endValue: endValue
            ),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                   Container(
                     width: 44,
                     height: 44,
                     decoration: const BoxDecoration(
                       shape: BoxShape.circle,
                     ),
                     child: ClipOval(
                       child: Image.asset(
                         'assets/atomic_habit_molecule.png',
                         fit: BoxFit.cover,
                       ),
                     ),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                         const SizedBox(height: 4),
                         Row(
                           children: [
                             Icon(Icons.repeat, size: 14, color: Colors.grey),
                             const SizedBox(width: 4),
                             Text(freqText, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                             const SizedBox(width: 12),
                             Icon(notify ? Icons.notifications_active : Icons.notifications_off, size: 14, color: notify ? Colors.amber : Colors.grey),
                             const SizedBox(width: 4),
                             Text(timeStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                           ],
                         ),
                       ],
                     ),
                   ),
                   IconButton(
                     icon: const Icon(Icons.delete_outline, color: Colors.grey),
                     onPressed: () => _deleteHabit(id),
                   ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ... (Existing Builders) ...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Habits'),
            Tab(text: 'Strategies'),
            Tab(text: 'Observations'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildHabitsList(),
                _buildStrategiesList(),
                _buildObservationsList(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onFabPressed,
        child: const Icon(Icons.add),
      ),
    );
  }
}
