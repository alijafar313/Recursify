import 'package:flutter/material.dart';
import '../data/app_database.dart';
import 'signal_detail_screen.dart';

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  List<Map<String, dynamic>> _signals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await AppDatabase.getSignals();
      if (mounted) {
        setState(() {
          _signals = s;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading signals: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        // Show error to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _createSignal() async {
    final controller = TextEditingController();
    bool isPositive = true; // Default

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('New Custom Tracker'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                 TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Name (e.g. Nicotine, Focus)',
                    hintText: 'What are you tracking?',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 24),
                const Text("What type of habit is this?", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDialogState(() => isPositive = true),
                        child: Container(
                           padding: const EdgeInsets.symmetric(vertical: 12),
                           decoration: BoxDecoration(
                             color: isPositive ? const Color(0xFF00E676).withOpacity(0.2) : Colors.transparent,
                             border: Border.all(color: isPositive ? const Color(0xFF00E676) : Colors.grey),
                             borderRadius: BorderRadius.circular(8),
                           ),
                           child: const Column(
                             children: [
                               Icon(Icons.thumb_up, color: Color(0xFF00E676)),
                               SizedBox(height: 4),
                               Text("Positive", style: TextStyle(color: Color(0xFF00E676))),
                             ],
                           ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDialogState(() => isPositive = false),
                        child: Container(
                           padding: const EdgeInsets.symmetric(vertical: 12),
                           decoration: BoxDecoration(
                             color: !isPositive ? const Color(0xFFFF5252).withOpacity(0.2) : Colors.transparent,
                             border: Border.all(color: !isPositive ? const Color(0xFFFF5252) : Colors.grey),
                             borderRadius: BorderRadius.circular(8),
                           ),
                           child: const Column(
                             children: [
                               Icon(Icons.thumb_down, color: Color(0xFFFF5252)),
                               SizedBox(height: 4),
                               Text("Negative", style: TextStyle(color: Color(0xFFFF5252))),
                             ],
                           ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                    final n = controller.text.trim();
                    if (n.isEmpty) {
                       // Do nothing or show indicator? 
                       // Since it's a simple dialog, typically we validate.
                       // Let's just not close it? But simple Dialogs are stateless usually.
                       // We need to pass the check.
                       // Actually, let's just make the button do nothing if empty.
                       // User will realize.
                       return;
                    }
                    Navigator.pop(ctx, {'name': n, 'isPositive': isPositive});
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && (result['name'] as String).isNotEmpty) {
      await AppDatabase.createSignal(result['name'], result['isPositive']);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Modern Dark Theme styling implied by User preference
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('Signals', style: TextStyle(fontWeight: FontWeight.bold)),
            floating: true,
            automaticallyImplyLeading: false, 
            actions: [
              IconButton(onPressed: _createSignal, icon: const Icon(Icons.add)),
            ],
          ),
          if (_signals.isEmpty)
             SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.track_changes, size: 64, color: Colors.grey.shade700),
                    const SizedBox(height: 16),
                    const Text(
                      'No Custom Signals Yet',
                      style: TextStyle(color: Colors.grey, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _createSignal,
                      child: const Text('Create Your First Tracker'),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final s = _signals[index];
                    return _SignalCard(signal: s, onTap: () async {
                      await Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (_) => SignalDetailScreen(signal: s)),
                      );
                      _load();
                    });
                  },
                  childCount: _signals.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SignalCard extends StatelessWidget {
  final Map<String, dynamic> signal;
  final VoidCallback onTap;

  const _SignalCard({required this.signal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorVal = signal['color_hex'] as int? ?? 0xFF00E676;
    final color = Color(colorVal);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1E1E1E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        onTap: onTap,
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8)],
          ),
        ),
        title: Text(
          signal['name'],
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        subtitle: const Text(
          'Tap to view graph & log',
          style: TextStyle(color: Colors.white30, fontSize: 12),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade600),
      ),
    );
  }
}
