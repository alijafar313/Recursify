import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/app_database.dart';

class ObservationsScreen extends StatefulWidget {
  const ObservationsScreen({super.key});

  @override
  State<ObservationsScreen> createState() => _ObservationsScreenState();
}

class _ObservationsScreenState extends State<ObservationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _observations = [];
  List<Map<String, dynamic>> _strategies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      if (mounted) {
        setState(() {
          _observations = List<Map<String, dynamic>>.from(obs);
          _strategies = List<Map<String, dynamic>>.from(strats);
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Error loading Observations: $e\n$stack');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red),
        );
      }
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
        await AppDatabase.updateObservation(id, content.trim());
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
        await AppDatabase.updateProblemSolution(id, problem.trim(), solution.trim());
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
  // FAB Action Logic
  // ---------------------------------------------------------------------------

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Observation'),
                subtitle: const Text('Record a general insight or rule'),
                onTap: () {
                  Navigator.pop(context);
                  _addOrEditObservation();
                },
              ),
              ListTile(
                leading: const Icon(Icons.lightbulb_outline), // or psychology?
                title: const Text('Problem-Solution'),
                subtitle: const Text('Log a strategy to test over time'),
                onTap: () {
                  Navigator.pop(context);
                  _addOrEditStrategy();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // UI BUILDERS
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Observations'),
            Tab(text: 'Strategies'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildObservationsList(),
                _buildStrategiesList(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddOptions,
        child: const Icon(Icons.add),
      ),
    );
  }
}
