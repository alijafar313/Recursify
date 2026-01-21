import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/app_database.dart';
import 'add_snapshot_screen.dart';

class DayDetailScreen extends StatefulWidget {
  final DateTime date;

  const DayDetailScreen({super.key, required this.date});

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  late Future<List<MoodSnapshot>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _dataFuture = AppDatabase.getSnapshotsForDay(widget.date);
    });
  }

  Future<void> _delete(int id) async {
    await AppDatabase.deleteSnapshot(id);
    _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry deleted')),
      );
    }
  }

  Future<void> _edit(MoodSnapshot snapshot) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => AddSnapshotScreen(existingSnapshot: snapshot)),
    );
    if (changed == true) {
      _refresh();
    }
  }

  Future<void> _addAtSpecificTime() async {
    // If it's today, we might want "Now" by default? 
    // But the user workflow suggests "Add point depending on memory" warning.
    // If we pass specifiedDate, it triggers the "Insert Past" mode.
    // Let's pass the date with current time? Or 12:00?
    // Let's pass DateTime(y, m, d, now.hour, now.minute) if today, else 12:00.
    
    final now = DateTime.now();
    final isToday = widget.date.year == now.year &&
        widget.date.month == now.month &&
        widget.date.day == now.day;
        
    DateTime initial = widget.date;
    if (isToday) {
      initial = now; // Default to now for today
    } else {
      // Default to noon for past days to be safe? Or just 12:00.
      initial = DateTime(widget.date.year, widget.date.month, widget.date.day, 12, 0);
    }

    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddSnapshotScreen(specifiedDate: initial),
      ),
    );
    if (changed == true) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('MMMM d, y').format(widget.date)),
      ),
      body: FutureBuilder<List<MoodSnapshot>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No entries for this day'));
          }

          final list = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final item = list[index];
              final time = DateFormat('h:mm a').format(DateTime.parse(item.timestamp));
              
              // Color code?
              final color = item.intensity > 0 ? Colors.green : (item.intensity < 0 ? Colors.red : Colors.amber);

              return Dismissible(
                key: ValueKey(item.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  color: Colors.red,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => _delete(item.id),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.2),
                    child: Text(
                      item.intensity.toString(),
                      style: TextStyle(color: color, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(item.note ?? ''),
                  trailing: Text(time),
                  onTap: () => _edit(item),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAtSpecificTime,
        icon: const Icon(Icons.add_alarm),
        label: const Text('Add Entry'),
      ),
    );
  }
}
