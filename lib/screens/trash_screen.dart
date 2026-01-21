import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/app_database.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  List<Map<String, dynamic>> _deletedObs = [];
  List<Map<String, dynamic>> _deletedStrats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final trash = await AppDatabase.getTrash();
    if (mounted) {
      setState(() {
        _deletedObs = List<Map<String, dynamic>>.from(trash['observations'] ?? []);
        _deletedStrats = List<Map<String, dynamic>>.from(trash['strategies'] ?? []);
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreObservation(int id) async {
    await AppDatabase.restoreObservation(id);
    _load();
  }

  Future<void> _hardDeleteObservation(int id) async {
    await AppDatabase.hardDeleteObservation(id);
    _load();
  }

  Future<void> _restoreStrategy(int id) async {
    await AppDatabase.restoreProblemSolution(id);
    _load();
  }

  Future<void> _hardDeleteStrategy(int id) async {
    await AppDatabase.hardDeleteProblemSolution(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = _deletedObs.isEmpty && _deletedStrats.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Trash is empty', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      SizedBox(height: 8),
                      Text('Items are automatically deleted after 7 days.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    if (_deletedObs.isNotEmpty) ...[
                      const Text('Observations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ..._deletedObs.map((item) {
                        final id = item['id'] as int;
                        final content = item['content'] as String;
                        final deletedAt = item['deleted_at'] as int;
                        final dateStr = DateFormat('MMM d').format(DateTime.fromMillisecondsSinceEpoch(deletedAt));

                        return Card(
                          child: ListTile(
                            title: Text(content),
                            subtitle: Text('Deleted: $dateStr'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.restore, color: Colors.green),
                                  onPressed: () => _restoreObservation(id),
                                  tooltip: 'Restore',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                                  onPressed: () => _hardDeleteObservation(id),
                                  tooltip: 'Delete Forever',
                                )
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                    ],

                    if (_deletedStrats.isNotEmpty) ...[
                      const Text('Strategies', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ..._deletedStrats.map((item) {
                        final id = item['id'] as int;
                        final problem = item['problem'] as String;
                        final solution = item['solution'] as String;
                        final deletedAt = item['deleted_at'] as int;
                        final dateStr = DateFormat('MMM d').format(DateTime.fromMillisecondsSinceEpoch(deletedAt));

                        return Card(
                          child: ListTile(
                            title: Text('$problem -> $solution'),
                            subtitle: Text('Deleted: $dateStr'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.restore, color: Colors.green),
                                  onPressed: () => _restoreStrategy(id),
                                  tooltip: 'Restore',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                                  onPressed: () => _hardDeleteStrategy(id),
                                  tooltip: 'Delete Forever',
                                )
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
    );
  }
}
