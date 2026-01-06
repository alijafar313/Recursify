import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../data/app_database.dart';

class GeneralAnalyticsScreen extends StatefulWidget {
  const GeneralAnalyticsScreen({super.key});

  @override
  State<GeneralAnalyticsScreen> createState() => _GeneralAnalyticsScreenState();
}

class _GeneralAnalyticsScreenState extends State<GeneralAnalyticsScreen> {
  Map<int, double> _avgDayStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = await AppDatabase.getAverageDayStats();
    if (!mounted) return;
    setState(() {
      _avgDayStats = stats;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Average Day',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Mood relative to hours since waking up.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  if (_avgDayStats.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'Not enough data yet.\nLog your sleep and mood to see insights!',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    AspectRatio(
                      aspectRatio: 1.5,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: 10,
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipColor: (group) => Colors.blueGrey,
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                return BarTooltipItem(
                                  '${rod.toY.toStringAsFixed(1)}/10',
                                  const TextStyle(color: Colors.white),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  return Text('${value.toInt()}h');
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 2,
                                getTitlesWidget: (value, meta) {
                                  return Text(value.toInt().toString());
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: const FlGridData(show: false),
                          barGroups: _avgDayStats.entries.map((e) {
                            final hour = e.key;
                            final score = e.value;
                            Color color = Colors.blue;
                            if (score >= 7.5) color = Colors.amber; // Golden Hour
                            if (score <= 4.0) color = Colors.redAccent; // Red Zone

                            return BarChartGroupData(
                              x: hour,
                              barRods: [
                                BarChartRodData(
                                  toY: score,
                                  color: color,
                                  width: 12,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.circle, color: Colors.amber, size: 12),
                      SizedBox(width: 4),
                      Text('Golden Hour'),
                      SizedBox(width: 16),
                      Icon(Icons.circle, color: Colors.redAccent, size: 12),
                      SizedBox(width: 4),
                      Text('Red Zone'),
                      SizedBox(width: 16),
                      Icon(Icons.circle, color: Colors.blue, size: 12),
                      SizedBox(width: 4),
                      Text('Normal'),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
