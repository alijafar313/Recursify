import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../data/app_database.dart';
import 'package:intl/intl.dart';

class DailyMoodChart extends StatelessWidget {
  final List<MoodSnapshot> snapshots;
  final DateTime date;
  final TimeOfDay? wakeTime;
  final TimeOfDay? sleepTime;
  final bool isOverride; // If true, user manually set this day's schedule, so no grey warnings.

  const DailyMoodChart({
    super.key,
    required this.snapshots,
    required this.date,
    this.wakeTime,
    this.sleepTime,
    this.isOverride = false,
  });

  @override
  Widget build(BuildContext context) {
    // If no data, we still render the chart to show the empty grid (blank with no points)
    // The spots list will simply be empty.

    // Sort by timestamp
    final sorted = List<MoodSnapshot>.from(snapshots)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final List<FlSpot> spots = [];
    final List<int> tooltipsOnSpots = [];

    // Default 6 AM -> 10 PM if not provided??
    // Actually user said 6 to 6 is too long.
    // If not provided, fallback to 8 AM - 11 PM? Or 6 AM - 6 AM (old behavior).
    // Let's assume wakeTime/sleepTime are passed. If not, default to 6->30 (6am next day).
    
    double startHour = 6.0;
    double endHour = 30.0; // 6 AM next day

    if (wakeTime != null && sleepTime != null) {
      startHour = wakeTime!.hour + wakeTime!.minute / 60.0;
      double sleepH = sleepTime!.hour + sleepTime!.minute / 60.0;
      if (sleepH < startHour) sleepH += 24.0; // Next day
      endHour = sleepH;
    }

    // Determine configured range
    double cfgStart = startHour;
    double cfgEnd = endHour;

    // Check actual data range
    double minDataX = 999.0;
    double maxDataX = -999.0;

    for (int i = 0; i < sorted.length; i++) {
      final s = sorted[i];
      final t = DateTime.parse(s.timestamp);

      // We need to map t to our "day" time scale.
      // E.g. Date is Jan 5.
      // If t is Jan 5 08:00 -> 8.0
      // If t is Jan 6 01:00 -> 25.0
      
      // Calculate hours from the start of `date` (midnight).
      // If date=Jan 5, t=Jan 5 08:00. diff = 8 hours.
      final diff = t.difference(DateTime(date.year, date.month, date.day));
      double val = diff.inMinutes / 60.0;

      // Special case: if we are using the "6 to 6" logic from before, 
      // we handled "early morning" specially.
      // Now, we just trust the date/time diff.
      // BUT if the user logged something at 1AM on Jan 5, and our "Date" is Jan 4?
      // The `AppDatabase` query `getSnapshotsForDay` logic uses 6AM -> 6AM.
      // Let's stick to that query logic for fetching, but for display, 
      // we map raw hours.
      // IF the query returns it, it belongs to this "Day".
      
      // However, our `val` above assumes 0-24 for the main day.
      // If logic fetched Jan 5 06:00 to Jan 6 06:00.
      // Jan 6 01:00 would be 25.0.
      
      // Correct mapping:
      // If t is on `date`, val is 0..24.
      // If t is on `date` + 1, val is 24..48.
      
      // Wait, we need to handle "Pre-wake" on the same day?
      // e.g. wake is 8AM. Log at 7AM.
      // 7.0 is < 8.0.
      
      // So simple hour mapping is fine.
      
      if (val < minDataX) minDataX = val;
      if (val > maxDataX) maxDataX = val;

      spots.add(FlSpot(val, s.intensity.toDouble()));
      tooltipsOnSpots.add(i);
    }
    
    // Auto-expand
    double finalMinX = cfgStart;
    double finalMaxX = cfgEnd;
    
    if (minDataX < finalMinX) finalMinX = minDataX;
    if (maxDataX > finalMaxX) finalMaxX = maxDataX;
    
    // Grey areas calculation
    // If !isOverride, we show grey for [finalMinX, cfgStart] and [cfgEnd, finalMaxX]
    // ONLY if those ranges exist.
    
    List<RangeAnnotationEntry> greyZones = [];
    if (!isOverride) {
      if (finalMinX < cfgStart) {
        greyZones.add(RangeAnnotationEntry(
           x1: finalMinX, x2: cfgStart, color: Colors.grey.withOpacity(0.2)
        ));
      }
      if (finalMaxX > cfgEnd) {
         greyZones.add(RangeAnnotationEntry(
           x1: cfgEnd, x2: finalMaxX, color: Colors.grey.withOpacity(0.2)
         ));
      }
    }

    // Calculate min and max Y to determine gradient stops
    double minY = 0;
    double maxY = 0;
    if (spots.isNotEmpty) {
      minY = spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
      maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    }
    
    // Gradient stops calculation
    List<Color> gradientColors = [Colors.red, Colors.red, Colors.green, Colors.green];
    List<double> gradientStops = [0.0, 0.5, 0.5, 1.0];

    if (minY == 0 && maxY == 0) {
      // Flat line at 0 (Neutral)
      gradientColors = [Colors.amber, Colors.amber];
      gradientStops = [0.0, 1.0];
    } else if (maxY <= 0) {
      // All negative
      gradientColors = [Colors.red, Colors.red];
      gradientStops = [0.0, 1.0];
    } else if (minY >= 0) {
      // All positive
      gradientColors = [Colors.green, Colors.green];
      gradientStops = [0.0, 1.0];
    } else {
      // Crossing zero
      // Calculate where 0 is in the range [minY, maxY]
      final range = maxY - minY;
      final zeroPos = (0.0 - minY) / range;
      
      // We want a tiny yellow band at zero? Or just hard cut?
      // User said: "zero is neutral, which makes it yellow"
      // Let's add a small band around zeroPos
      final epsilon = 0.02; // 2% band
      
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

    // Create the bar data once so we can reference it
    final mainBarData = LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.2,
      barWidth: 3,
      isStrokeCapRound: true,
      
      gradient: LinearGradient(
        colors: gradientColors,
        stops: gradientStops,
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ),
      
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
      
      // Fill from Line DOWN to 0 (Positive values) -> Green
      belowBarData: BarAreaData(
        show: true,
        color: Colors.green.withOpacity(0.5),
        cutOffY: 0,
        applyCutOffY: true,
      ),
      // Fill from Line UP to 0 (Negative values) -> Red
      aboveBarData: BarAreaData(
        show: true,
        color: Colors.redAccent.withOpacity(0.5),
        cutOffY: 0,
        applyCutOffY: true,
      ),
    );

    return SizedBox(
      height: 300, // Make it big
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LineChart(
          LineChartData(
            // Tooltips (Titles)
            showingTooltipIndicators: tooltipsOnSpots.map((index) {
              return ShowingTooltipIndicators([
                LineBarSpot(
                  mainBarData,
                  0,
                  spots[index],
                ),
              ]);
            }).toList(),
            
            lineTouchData: LineTouchData(
              enabled: false,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => Colors.transparent, // Transparent background
                tooltipPadding: EdgeInsets.zero,
                tooltipMargin: 5,
                getTooltipItems: (List<LineBarSpot> touchedSpots) {
                  return touchedSpots.map((touchedSpot) {
                    final index = spots.indexOf(touchedSpot);
                    if (index == -1) return null;
                    return LineTooltipItem(
                      sorted[index].title,
                      const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    );
                  }).toList();
                },
              ),
            ),

            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1, // Show lines for every integer
              getDrawingHorizontalLine: (value) {
                if (value == 0) {
                  return const FlLine(color: Colors.black, strokeWidth: 1.5);
                }
                return FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1);
              },
            ),

            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1, // Every number -5 to 5
                  reservedSize: 24,
                  getTitlesWidget: (value, meta) {
                    if (value.abs() == 6) return const SizedBox.shrink();
                    return Text(
                      value.toInt().toString(),
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    );
                  },
                ),
              ),
              
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 0.1, // Check very frequently to match specific points
                  reservedSize: 22,
                  getTitlesWidget: (value, meta) {
                    // Logic:
                    // 1. Is this 'value' equal to (or very close to) Wake Time?
                    // 2. Is this 'value' equal to (or very close to) Sleep Time?
                    // 3. Is this 'value' equal to (or very close to) any Data Point X?
                    // If yes, return Text. Else SizedBox.

                    // We need a small epsilon for float comparison.
                    const epsilon = 0.05;

                    bool shouldShow = false;
                    String text = '';
                    
                    // Check Start (Wake)
                    if ((value - finalMinX).abs() < epsilon) {
                       shouldShow = true;
                       text = _formatHour(finalMinX);
                    }
                    // Check End (Sleep)
                    else if ((value - finalMaxX).abs() < epsilon) {
                       shouldShow = true;
                       text = _formatHour(finalMaxX);
                    }
                    // Check Data points
                    else {
                      for (final spot in spots) {
                        if ((value - spot.x).abs() < epsilon) {
                          shouldShow = true;
                          text = _formatHour(spot.x);
                          break;
                        }
                      }
                    }

                    if (!shouldShow) return const SizedBox.shrink();

                    // Optional: Avoid overlapping??
                    // For now, let's just show them. Overlapping might occur if data is dense.
                    // fl_chart might not handle overlapping well automatically with this custom logic.
                    // A simple heuristic: if we just showed a label "close" to this one, skip?
                    // Hard to track state inside this callback efficiently without side effects.
                    // But typically fl_chart calls these in order.
                    
                    // Optimization: We only want to match exactly ONCE per "point". 
                    // Since interval is 0.1, we might match multiple times for a point at 9.0 (8.9, 9.0, 9.1).
                    // We should strictly match the closest interval step.
                    // Or better: Use 'getTitlesWidget' just to look up if 'value' is IN a "Show List".
                    
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        text,
                        style: const TextStyle(
                          color: Colors.black, 
                          fontSize: 10,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            borderData: FlBorderData(show: false),
            minX: finalMinX,
            maxX: finalMaxX,
            minY: -6,
            maxY: 6,
            
            rangeAnnotations: RangeAnnotations(
               verticalRangeAnnotations: greyZones.map((z) {
                 return VerticalRangeAnnotation(x1: z.x1, x2: z.x2, color: z.color);
               }).toList(),
            ),
            
            lineBarsData: [mainBarData],
          ),
        ),
      ),
    );
  }

  String _formatHour(double value) {
    double normalized = value;
    while (normalized >= 24) normalized -= 24;
    final dt = DateTime(2022, 1, 1, normalized.toInt(), (normalized % 1 * 60).toInt());
    return DateFormat('h:mm a').format(dt).toLowerCase().replaceAll(':00', ''); // 9 am, 2:30 pm
  }
}

class RangeAnnotationEntry {
  final double x1;
  final double x2;
  final Color color;
  RangeAnnotationEntry({required this.x1, required this.x2, required this.color});
}
