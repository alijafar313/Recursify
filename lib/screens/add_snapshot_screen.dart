import 'package:flutter/material.dart';
import '../data/app_database.dart';

class AddSnapshotScreen extends StatefulWidget {
  final DateTime? specifiedDate; // If provided, we are inserting a past entry
  final MoodSnapshot? existingSnapshot; // If provided, we are editing

  const AddSnapshotScreen({super.key, this.specifiedDate, this.existingSnapshot});

  @override
  State<AddSnapshotScreen> createState() => _AddSnapshotScreenState();
}

class _AddSnapshotScreenState extends State<AddSnapshotScreen> {
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  double _intensity = 0; // Neutral start (-5 to 5)
  DateTime _selectedDate = DateTime.now();

  List<String> _titles = [];
  List<String> _filtered = [];

  @override
  void initState() {
    super.initState();
    if (widget.existingSnapshot != null) {
      final s = widget.existingSnapshot!;
      _titleController.text = s.title;
      _noteController.text = s.note ?? '';
      _intensity = s.intensity.toDouble();
      _selectedDate = DateTime.parse(s.timestamp);
    } else if (widget.specifiedDate != null) {
      _selectedDate = widget.specifiedDate!;
    }
    _loadTitles();

    _titleController.addListener(() {
      final q = _titleController.text.trim().toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? []
            : _titles.where((t) => t.toLowerCase().contains(q)).take(6).toList();
      });
    });
  }

  Future<void> _loadTitles() async {
    final titles = await AppDatabase.allProblemTitles();
    if (!mounted) return;
    setState(() => _titles = titles);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );
    if (t != null) {
      final newDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        t.hour,
        t.minute,
      );
      setState(() => _selectedDate = newDate);
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final note = _noteController.text.trim();
    final intensity = _intensity.toInt();

    // Check for "Memory Bias" only if INSERTING a past entry (not editing existing)
    final isPast = DateTime.now().difference(_selectedDate).inHours > 4;
    final isInsert = widget.specifiedDate != null && widget.existingSnapshot == null;
    
    if (isPast && isInsert) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Memory Bias Warning'),
          content: const Text(
            'It is not advised to insert a point depending on memory, '
            'as current mood often influences the recollection of past feelings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save Anyway'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Context is required')),
      );
      return;
    }

    if (widget.existingSnapshot != null) {
      await AppDatabase.updateSnapshot(
        id: widget.existingSnapshot!.id,
        title: title,
        intensity: intensity,
        note: note,
        timestamp: _selectedDate.toIso8601String(),
      );
    } else {
      await AppDatabase.insertSnapshot(
        title: title,
        intensity: intensity,
        note: note,
        timestamp: _selectedDate.toIso8601String(),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingSnapshot != null;
    final isInsert = widget.specifiedDate != null; // Either insert past or editing past

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Snapshot' : (isInsert ? 'Insert Past Entry' : 'New Snapshot')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.specifiedDate != null)
                ListTile(
                  leading: const Icon(Icons.access_time, color: Colors.orange),
                  title: Text(
                    'Time: ${_selectedDate.hour}:${_selectedDate.minute.toString().padLeft(2, '0')}',
                  ),
                  subtitle: const Text('Tap to change time'),
                  trailing: const Icon(Icons.edit),
                  onTap: _pickTime,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Colors.orange),
                  ),
                ),
              if (widget.specifiedDate != null) const SizedBox(height: 16),

              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Context',
                  hintText: 'e.g., Gym, Work, Traffic',
                  border: OutlineInputBorder(),
                ),
              ),

              if (_filtered.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  color: Colors.grey.shade100,
                  height: 120, // Limit height
                  child: ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) {
                      final t = _filtered[i];
                      return ListTile(
                        dense: true,
                        title: Text(t),
                        onTap: () {
                          _titleController.text = t;
                          setState(() => _filtered = []);
                        },
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 16),

              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Any specific details?',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Sad (-5)', style: TextStyle(color: Colors.red)),
                  Text(
                    'Mood: ${_intensity.toInt()}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Text('Happy (+5)', style: TextStyle(color: Colors.green)),
                ],
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _intensity >= 0 ? Colors.green : Colors.red,
                  inactiveTrackColor: Colors.grey.shade300,
                  thumbColor: _intensity == 0
                      ? Colors.amber
                      : (_intensity > 0 ? Colors.green : Colors.red),
                ),
                child: Slider(
                  value: _intensity,
                  min: -5,
                  max: 5,
                  divisions: 10,
                  label: _intensity.toInt().toString(),
                  onChanged: (v) => setState(() => _intensity = v),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: const Text('Save Snapshot'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
