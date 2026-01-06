import 'package:flutter/material.dart';
import '../data/app_database.dart';
import 'add_snapshot_screen.dart';
import 'analytics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, Object?>> _snapshots = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final data = await AppDatabase.latestSnapshots(limit: 50);
    if (!mounted) return;
    setState(() {
      _snapshots = data;
      _isLoading = false;
    });
  }

  Future<void> _openAddSnapshot() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddSnapshotScreen()),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to SQLite ✅')),
      );
      _reload();
    }
  }

  void _openAnalytics(Map<String, Object?> row) {
    final problemIdAny = row['problem_id'];
    final titleAny = row['title'];

    if (problemIdAny is! int || titleAny is! String) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open analytics (missing data).')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProblemAnalyticsScreen(
          problemId: problemIdAny,
          title: titleAny,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moodly - Home'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _snapshots.isEmpty
              ? const Center(child: Text('No snapshots yet. Tap + to add one.'))
              : ListView.separated(
                  itemCount: _snapshots.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final r = _snapshots[i];

                    final title = (r['title'] as String?) ?? '';
                    final intensity = (r['intensity'] as int?) ?? 0;
                    final note = (r['note'] as String?) ?? '';

                    return ListTile(
                      title: Text(title),
                      subtitle: Text(
                        note.isEmpty
                            ? 'Mood: $intensity/10'
                            : 'Mood: $intensity/10 • $note',
                      ),
                      onTap: () => _openAnalytics(r),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddSnapshot,
        child: const Icon(Icons.add),
      ),
    );
  }
}
