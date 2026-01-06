import 'package:flutter/material.dart';
import '../data/app_database.dart';

class ProblemAnalyticsScreen extends StatelessWidget {
  final int problemId;
  final String title;

  const ProblemAnalyticsScreen({
    super.key,
    required this.problemId,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<Map<String, Object?>>(
        future: AppDatabase.problemStats(problemId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final data = snap.data ?? {};
          final total = data['total'] as int? ?? 0;
          final morning = data['morning'] as int? ?? 0;
          final afternoon = data['afternoon'] as int? ?? 0;
          final evening = data['evening'] as int? ?? 0;
          final night = data['night'] as int? ?? 0;

          Widget row(String label, int value) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 16)),
                    Text('$value', style: const TextStyle(fontSize: 16)),
                  ],
                ),
              );

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total snapshots: $total',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Time-of-day distribution',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                row('Morning (6–11)', morning),
                row('Afternoon (12–17)', afternoon),
                row('Evening (18–21)', evening),
                row('Night (22–5)', night),
              ],
            ),
          );
        },
      ),
    );
  }
}
