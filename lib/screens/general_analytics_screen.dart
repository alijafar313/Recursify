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
  Map<int, double> _hourlyStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 1. Last 7 days
    final daysData = await AppDatabase.getDailyMoods(limit: 7);
    
    // 2. Hourly stats (Average Daily Cycle)
    final hoursData = await AppDatabase.getAverageDayStats();

    if (!mounted) return;
    setState(() {
      _dailyMoods = daysData.reversed.toList(); // Oldest -> Newest
      _hourlyStats = hoursData;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mood History')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Weekly Trend'),
                  _buildWeeklyChart(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Average Daily Cycle'),
                  const SizedBox(height: 4),
                  const Text(
                    'Your typical mood pattern throughout a day.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  _buildHourlyChart(),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildWeeklyChart() {
    if (_dailyMoods.isEmpty) return _buildEmptyState('No daily logs yet.');

    final spots = <FlSpot>[];
    final dateLabels = <String>[];

    for (int i = 0; i < _dailyMoods.length; i++) {
        final row = _dailyMoods[i];
        final dayStr = row['day'] as String;
        final avg = row['avg_mood'] as double;
        spots.add(FlSpot(i.toDouble(), avg));
        
        try {
            final date = DateTime.parse(dayStr);
            dateLabels.add(DateFormat('EEE').format(date)); // Mon, Tue...
        } catch (_) {
            dateLabels.add('?');
        }
    }

    return _buildChartCard(
      spots: spots, 
      minX: 0, 
      maxX: (spots.length - 1).toDouble(),
      getXLabel: (val) {
        final idx = val.toInt();
        if (idx >= 0 && idx < dateLabels.length) return dateLabels[idx];
        return '';
      },
      tooltipLabel: (val) {
         final idx = val.toInt();
        if (idx >= 0 && idx < _dailyMoods.length) {
            final row = _dailyMoods[idx];
            final d = DateTime.tryParse(row['day'] as String);
            final dStr = d != null ? DateFormat('MMM d').format(d) : '';
            return dStr;
        }
        return '';
      }
    );
  }

  Widget _buildHourlyChart() {
    if (_hourlyStats.isEmpty) return _buildEmptyState('Track more mood changes to see hourly patterns.');

    final sortedHours = _hourlyStats.keys.toList()..sort();
    final spots = <FlSpot>[];

    // We want to show 0..23 on X axis.
    // If we have data for hour h, use it. Else... don't show or interpolate?
    // Since it's "Average", let's just show unconnected dots or connect them if close?
    // Let's connect them.
    
    // We can also just plot the available points.
    for (final h in sortedHours) {
      spots.add(FlSpot(h.toDouble(), _hourlyStats[h]!));
    }

    return _buildChartCard(
      spots: spots,
      minX: 0,
      maxX: 23,
      getXLabel: (val) {
        // Show 6am, 12pm, 6pm, 10pm etc
        final h = val.toInt();
        if (h == 6) return '6am';
        if (h == 12) return '12pm';
        if (h == 18) return '6pm';
        if (h == 23) return '11pm';
        return '';
      },
      tooltipLabel: (val) {
         double normalized = val;
         while (normalized >= 24) normalized -= 24;
         final dt = DateTime(2022, 1, 1, normalized.toInt(), (normalized % 1 * 60).toInt());
         return DateFormat('h:mm a').format(dt).toLowerCase();
      }
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(msg, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
    );
  }

  // REUSABLE CARD WRAPPER WITH HOME-STYLE CHART
  Widget _buildChartCard({
    required List<FlSpot> spots, 
    required double minX, 
    required double maxX,
    required String Function(double) getXLabel,
    required String Function(double) tooltipLabel,
  }) {
    // Determine Y range
    double minY = -6;
    double maxY = 6;
    if (spots.isNotEmpty) {
      final yVals = spots.map((e) => e.y);
      if (yVals.reduce((a, b) => a < b ? a : b) < -5) minY = -10; // Expand if needed
      if (yVals.reduce((a, b) => a > b ? a : b) > 5) maxY = 10;
    }

    // Fix: We must calculate zeroPos relative to the *data* range, not the *axis* range,
    // because LinearGradient applies to the bounding box of the line itself.
    double dataMinY = 0;
    double dataMaxY = 0;
    
    if (spots.isNotEmpty) {
       dataMinY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
       dataMaxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    }
    
    // Safety check for flat line
    if (dataMaxY == dataMinY) {
       dataMaxY += 0.1;
       dataMinY -= 0.1;
    }

    final dataRange = dataMaxY - dataMinY;
    final zeroPos = (0.0 - dataMinY) / dataRange; // 0..1 ratio where 0 is

    // Fix: Hard cut at zero. No "Cyan Band" for the line itself, so values > 0 are Green, < 0 are Red.
    List<Color> gradientColors;
    List<double> gradientStops;

    if (dataMinY >= 0) {
      // All positive -> Green
      gradientColors = [const Color(0xFF20BF55), const Color(0xFF20BF55)];
      gradientStops = [0.0, 1.0];
    } else if (dataMaxY <= 0) {
      // All negative -> Red
      gradientColors = [const Color(0xFFFF2E63), const Color(0xFFFF2E63)];
      gradientStops = [0.0, 1.0];
    } else {
      // 0.02 band logic replaced with SHARP CUT
      gradientColors = [
        const Color(0xFFFF2E63), // Red
        const Color(0xFFFF2E63),
        const Color(0xFF20BF55), // Green
        const Color(0xFF20BF55),
      ];
      gradientStops = [
        0.0,
        zeroPos.clamp(0.0, 1.0),
        (zeroPos + 0.001).clamp(0.0, 1.0),
        1.0,
      ];
    }
    
    // DETECT ZERO SEGMENTS (for Cyan Overlay)
    final List<LineChartBarData> extraLines = [];
    if (spots.length >= 2) {
      List<FlSpot> currentZeroSegment = [];
      for (int i = 0; i < spots.length; i++) {
        final spot = spots[i];
        if ((spot.y).abs() < 0.001) {
           currentZeroSegment.add(spot);
        } else {
           if (currentZeroSegment.length >= 2) {
             extraLines.add(_createZeroBarData(List.from(currentZeroSegment)));
           }
           currentZeroSegment.clear();
        }
      }
      if (currentZeroSegment.length >= 2) {
         extraLines.add(_createZeroBarData(List.from(currentZeroSegment)));
      }
    }

    final mainBarData = LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.18, // Matches Home chart tightness
              preventCurveOverShooting: true, // Fixes artifacts near 0
              barWidth: 4,
              isStrokeCapRound: true,
              shadow: const Shadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4)),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: gradientColors,
                stops: gradientStops,
              ),
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                   Color c = const Color(0xFF08D9D6);
                   if (spot.y > 0.001) c = const Color(0xFF20BF55);
                   if (spot.y < -0.001) c = const Color(0xFFFF2E63);
                   return FlDotCirclePainter(radius: 4, color: Colors.white, strokeWidth: 2, strokeColor: c);
                }
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF20BF55).withOpacity(0.2), 
                    Colors.transparent
                  ],
                ),
                cutOffY: 0,
                applyCutOffY: true, 
              ),
              aboveBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFFFF2E63).withOpacity(0.2),
                    Colors.transparent
                  ],
                ),
                cutOffY: 0,
                applyCutOffY: true,
              )
            );

    return Container(
      height: 250,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            verticalInterval: maxX > 10 ? 6 : 1, // 6h for daily, 1d for weekly
            horizontalInterval: 2,
            getDrawingVerticalLine: (value) {
               return FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1);
            },
            getDrawingHorizontalLine: (value) {
               if (value == 0) return const FlLine(color: Colors.white24, strokeWidth: 1);
               return FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1);
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
               sideTitles: SideTitles(
                 showTitles: true,
                 interval: (maxY - minY) > 12 ? 5 : 2,
                 reservedSize: 24,
                 getTitlesWidget: (val, _) {
                    if (val.abs() >= (maxY.abs() - 1)) return const SizedBox.shrink(); // Hide extremes
                    return Text(val.toInt().toString(), style: const TextStyle(color: Colors.white30, fontSize: 10));
                 } 
               )
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (val, meta) {
                   // Only show label if it matches our getXLabel logic (which might be sparse)
                   final text = getXLabel(val);
                   if (text.isEmpty) return const SizedBox.shrink();
                   return Padding(
                     padding: const EdgeInsets.only(top: 8.0),
                     child: Text(text, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                   );
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            mainBarData,
            ...extraLines,
          ],
            lineTouchData: LineTouchData(
              enabled: false, // Disable touch since we show permanent tooltips
              touchTooltipData: LineTouchTooltipData(
                 getTooltipColor: (_) => Colors.transparent,
                 tooltipPadding: EdgeInsets.zero,
                 tooltipMargin: 5,
                 getTooltipItems: (touchedSpots) {
                   return touchedSpots.map((spot) {
                      final label = tooltipLabel(spot.x);
                      return LineTooltipItem(
                        // Only show label if it's the Hourly chart or sparse enough?
                        // Actually home screen shows Title + Value.
                        // For Weekly: "Mon\n3.5"
                        // For Hourly: "8am\n2.0"
                        spot.y.toStringAsFixed(1),
                        TextStyle(
                          color: spot.y > 0.001 ? const Color(0xFF20BF55) : (spot.y < -0.001 ? const Color(0xFFFF2E63) : const Color(0xFF08D9D6)), 
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        )
                      );
                   }).toList();
                 }
              )
            ),
            
            // SHOW PERMANENT TOOLTIPS
            showingTooltipIndicators: spots.map((s) {
               return ShowingTooltipIndicators([
                 LineBarSpot(
                   mainBarData, // Use mainBarData reference logic
                   0, 
                   s // The spot
                 )
               ]);
            }).toList(),
        ),
      ),
    );
  }
  
  LineChartBarData _createZeroBarData(List<FlSpot> spots) {
    return LineChartBarData(
      spots: spots,
      isCurved: false,
      barWidth: 4,
      color: const Color(0xFF08D9D6), // Neon Cyan
      isStrokeCapRound: true,
      dotData: FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }
}
