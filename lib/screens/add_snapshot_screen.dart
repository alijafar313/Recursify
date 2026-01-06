import 'package:flutter/material.dart';
import '../data/app_database.dart';

class AddSnapshotScreen extends StatefulWidget {
  const AddSnapshotScreen({super.key});

  @override
  State<AddSnapshotScreen> createState() => _AddSnapshotScreenState();
}

class _AddSnapshotScreenState extends State<AddSnapshotScreen> {
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();

  double _intensity = 5;

  List<String> _titles = [];
  List<String> _filtered = [];

  @override
  void initState() {
    super.initState();

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

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final note = _noteController.text.trim();
    final intensity = _intensity.toInt();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required')),
      );
      return;
    }

    await AppDatabase.insertSnapshot(
      title: title,
      intensity: intensity,
      note: note,
    );

    if (!mounted) return;
    Navigator.of(context).pop(true); // tells Home: saved successfully
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Snapshot'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Context',
                  hintText: 'e.g., job stress, relationship, motivation',
                ),
              ),

              if (_filtered.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) {
                      final t = _filtered[i];
                      return ListTile(
                        dense: true,
                        title: Text(t),
                        onTap: () {
                          _titleController.text = t;
                          _titleController.selection =
                              TextSelection.fromPosition(
                            TextPosition(offset: t.length),
                          );
                          setState(() => _filtered = []);
                        },
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 12),

              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'What happened?',
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 20),

              Text(
                'Mood: ${_intensity.toInt()} / 10',
                style: const TextStyle(fontSize: 16),
              ),
              Slider(
                value: _intensity,
                min: 0,
                max: 10,
                divisions: 10,
                label: _intensity.toInt().toString(),
                onChanged: (v) => setState(() => _intensity = v),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
