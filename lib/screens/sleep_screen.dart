import 'package:flutter/material.dart';
import '../data/app_database.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  // We'll add logic to load sleep logs here similar to Home
  // For now, it's a basic implementation to allow adding sleep.
  
  List<Map<String, Object?>> _sleepLogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final data = await AppDatabase.latestSleepLogs();
    if (!mounted) return;
    setState(() {
      _sleepLogs = data;
      _isLoading = false;
    });
  }

  Future<void> _addSleepLog() async {
    // Show a dialog or screen to pick start/end times.
    // For simplicity V1, let's just add a dummy entry or simple dialog.
    // Ideally we want TimeOfDay pickers.
    
    // Let's create a quick dialog for now to test the DB.
    final now = DateTime.now();
    final result = await showDialog<bool>(
      context: context, 
      builder: (ctx) => _AddSleepDialog(),
    );

    if (result == true) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep Tracker'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sleepLogs.isEmpty
              ? const Center(child: Text('No sleep logs yet.'))
              : ListView.separated(
                  itemCount: _sleepLogs.length,
                  separatorBuilder: (_,__) => const Divider(),
                  itemBuilder: (context, i) {
                    final log = _sleepLogs[i];
                    final startMs = log['start_time'] as int;
                    final endMs = log['end_time'] as int;
                    
                    final start = DateTime.fromMillisecondsSinceEpoch(startMs);
                    final end = DateTime.fromMillisecondsSinceEpoch(endMs);
                    final duration = end.difference(start);
                    
                    final hours = duration.inHours;
                    final mins = duration.inMinutes % 60;

                    return ListTile(
                      leading: const Icon(Icons.bed),
                      title: Text('${start.hour}:${start.minute.toString().padLeft(2, '0')} - ${end.hour}:${end.minute.toString().padLeft(2, '0')}'),
                      subtitle: Text('Duration: ${hours}h ${mins}m'),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSleepLog,
        child: const Icon(Icons.bed), // Icon for adding sleep
      ),
    );
  }
}

class _AddSleepDialog extends StatefulWidget {
  @override
  State<_AddSleepDialog> createState() => _AddSleepDialogState();
}

class _AddSleepDialogState extends State<_AddSleepDialog> {
  // Defaults
  TimeOfDay _bedTime = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 0);

  Future<void> _pickTime(bool isBedTime) async {
    final initial = isBedTime ? _bedTime : _wakeTime;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        if (isBedTime) _bedTime = picked;
        else _wakeTime = picked;
      });
    }
  }

  Future<void> _save() async {
    final now = DateTime.now();
    // This is a naive implementation: it assumes bed time was "yesterday" if it's PM and wake time is AM today.
    // Or we just calculate loose timestamps relative to "today".
    // For V1 prototyping, let's assume we are logging "last night's sleep".
    
    // If bedTime is > wakeTime, assume bedTime was yesterday.
    
    var bedDateTime = DateTime(now.year, now.month, now.day, _bedTime.hour, _bedTime.minute);
    var wakeDateTime = DateTime(now.year, now.month, now.day, _wakeTime.hour, _wakeTime.minute);

    if (bedDateTime.isAfter(wakeDateTime)) {
        // e.g. Bed 23:00, Wake 07:00. Bed must be yesterday.
        bedDateTime = bedDateTime.subtract(const Duration(days: 1));
    }
    
    await AppDatabase.insertSleep(
      startTime: bedDateTime.millisecondsSinceEpoch,
      endTime: wakeDateTime.millisecondsSinceEpoch,
    );
    
    if(!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Log Sleep'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('Bed Time:'),
              const Spacer(),
              TextButton(
                onPressed: () => _pickTime(true),
                child: Text(_bedTime.format(context)),
              ),
            ],
          ),
          Row(
            children: [
              const Text('Wake Time:'),
              const Spacer(),
              TextButton(
                onPressed: () => _pickTime(false),
                child: Text(_wakeTime.format(context)),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
