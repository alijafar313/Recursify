import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/app_database.dart';

class GeneralAnalyticsScreen extends StatefulWidget {
  const GeneralAnalyticsScreen({super.key});

  @override
  State<GeneralAnalyticsScreen> createState() => _GeneralAnalyticsScreenState();
}

class _GeneralAnalyticsScreenState extends State<GeneralAnalyticsScreen> {
  List<Map<String, Object?>> _dailyMoods = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Fetch last 30 days of mood history
    final data = await AppDatabase.getDailyMoods(limit: 30);
    if (!mounted) return;
    setState(() {
      _dailyMoods = data.reversed.toList(); // Chronological order
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // If we have data, prepare spots
    List<FlSpot> spots = [];
    List<String> dates = [];
    
    for (int i = 0; i < _dailyMoods.length; i++) {
        final row = _dailyMoods[i];
        final dayStr = row['day'] as String;
        final avg = row['avg_mood'] as double;
        spots.add(FlSpot(i.toDouble(), avg));
        
        // Parse "YYYY-MM-DD"
        try {
            final date = DateTime.parse(dayStr);
            dates.add(DateFormat('MM/dd').format(date));
        } catch (_) {
            dates.add(dayStr);
        }
    }

    // Calculate min and max Y to determine gradient stops
    double minYVal = 0;
    double maxYVal = 0;
    if (spots.isNotEmpty) {
      minYVal = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
      maxYVal = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    }
    
    // Gradient stops calculation
    List<Color> gradientColors = [Colors.red, Colors.red, Colors.green, Colors.green];
    List<double> gradientStops = [0.0, 0.5, 0.5, 1.0];

    if (maxYVal <= 0) {
      gradientColors = [Colors.red, Colors.red];
      gradientStops = [0.0, 1.0];
    } else if (minYVal >= 0) {
      gradientColors = [Colors.green, Colors.green];
      gradientStops = [0.0, 1.0];
    } else {
      final range = maxYVal - minYVal;
      final zeroPos = (0.0 - minYVal) / range;
      final epsilon = 0.02;
      
      gradientColors = [
        Colors.red, 
        Colors.red, 
        Colors.amber, 
        Colors.amber, 
        Colors.green, 
        Colors.green
      ];
      gradientStops = [
        0.0, 
        (zeroPos - epsilon).clamp(0.0, 1.0), 
        (zeroPos - epsilon + 0.001).clamp(0.0, 1.0),
        (zeroPos + epsilon).clamp(0.0, 1.0),
        (zeroPos + epsilon + 0.001).clamp(0.0, 1.0), 
        1.0
      ];
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mood History')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mood Trends',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Green area: Above Neutral (> 0)\nRed area: Below Neutral (< 0)',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  if (_dailyMoods.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'Not enough data yet.\nLog your mood to see trends!',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    AspectRatio(
                      aspectRatio: 1.5,
                      child: LineChart(
                        LineChartData(
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (spot) => Colors.blueGrey,
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((touchedSpot) {
                                  final date = dates[touchedSpot.x.toInt()];
                                  return LineTooltipItem(
                                    '$date\nScore: ${touchedSpot.y.toStringAsFixed(1)}',
                                    const TextStyle(color: Colors.white),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 1,
                            getDrawingHorizontalLine: (value) {
                                return FlLine(
                                    color: Colors.grey.withOpacity(0.2),
                                    strokeWidth: 1,
                                );
                            },
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 30,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  if (index >= 0 && index < dates.length) {
                                     // Show stats sparsely to avoid overlap
                                     if (dates.length > 10 && index % 3 != 0) return const SizedBox.shrink();
                                     return Padding(
                                       padding: const EdgeInsets.only(top: 8.0),
                                       child: Text(
                                         dates[index], 
                                         style: const TextStyle(fontSize: 10),
                                       ),
                                     );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  if (value.abs() == 6) return const SizedBox.shrink();
                                  if (value == 0) return const SizedBox.shrink();
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
                          minX: 0,
                          maxX: (spots.length - 1).toDouble(),
                          maxY: 6,
                          minY: -6,
                          extraLinesData: ExtraLinesData(
                            horizontalLines: [
                              HorizontalLine(
                                y: 0.0,
                                color: Colors.black.withOpacity(0.5),
                                strokeWidth: 1,
                                dashArray: [5, 5],
                              ),
                            ],
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              gradient: LinearGradient(
                                colors: gradientColors,
                                stops: gradientStops,
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) {
                                   Color dotColor = Colors.amber;
                                   if (spot.y > 0) dotColor = Colors.green;
                                   if (spot.y < 0) dotColor = Colors.red;
                                   return FlDotCirclePainter(
                                     radius: 4,
                                     color: dotColor,
                                     strokeWidth: 1,
                                     strokeColor: Colors.white,
                                   );
                                },
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.green.withOpacity(0.5),
                                cutOffY: 0.0,
                                applyCutOffY: true,
                              ),
                              aboveBarData: BarAreaData(
                                show: true,
                                color: Colors.redAccent.withOpacity(0.5),
                                cutOffY: 0.0,
                                applyCutOffY: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
