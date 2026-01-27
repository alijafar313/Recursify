import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class GenericChart extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  final int minVal;
  final int maxVal;
  final Color baseColor;
  final TimeOfDay? wakeTime;
  final TimeOfDay? sleepTime;
  final bool isPositiveSignal;

  const GenericChart({
    super.key,
    required this.logs,
    this.minVal = 1,
    this.maxVal = 10,
    this.baseColor = Colors.blueAccent,
    this.wakeTime,
    this.sleepTime,
    this.isPositiveSignal = true,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Calculate Time Range (Logic from DailyMoodChart)
    double startHour = 6.0;
    double endHour = 30.0; // 6 AM next day

    if (wakeTime != null && sleepTime != null) {
      startHour = wakeTime!.hour + wakeTime!.minute / 60.0;
      double sleepH = sleepTime!.hour + sleepTime!.minute / 60.0;
      if (sleepH < startHour) sleepH += 24.0; 
      endHour = sleepH;
    }

    double cfgStart = startHour;
    double cfgEnd = endHour;

    // 2. Process Data
    final List<FlSpot> spots = [];
    double minDataX = 999.0;
    double maxDataX = -999.0;

    // We assume logs are for a specific "Day".
    // We need the reference date from the first log or pass it in? 
    // GenericChart usually receives logs for "Today" or "Selected Date".
    // But logs contains 'created_at'.
    // We'll infer reference date from the first log if available, strictly for "Start of Day" calc.
    // Or simpler: just map time to 0-24 or 0-48 relative to the day of the log.
    
    if (logs.isNotEmpty) {
      // Find "Start of Day" (Midnight) of the logs. 
      // Assuming all logs are from same day generally.
      final firstDt = DateTime.fromMillisecondsSinceEpoch(logs.first['created_at']);
      final midnight = DateTime(firstDt.year, firstDt.month, firstDt.day);

      for (var log in logs) {
         final dt = DateTime.fromMillisecondsSinceEpoch(log['created_at']);
         // Handle crossing midnight?
         // If dt is generally on 'midnight' day:
         double val = dt.hour + (dt.minute / 60.0);
         
         // If our range goes into next day (e.g. 26.0), and log is 01:00 AM next day...
         // We need to know if it belongs to "Next Day".
         // The simplest heuristic without passing "Date":
         // If val < startHour (e.g. 1 < 8) and endHour > 24, add 24.
         if (val < startHour && endHour > 24) {
            val += 24;
         }

         if (val < minDataX) minDataX = val;
         if (val > maxDataX) maxDataX = val;
         
         spots.add(FlSpot(val, log['value'].toDouble()));
      }
    }

    // Auto-expand
    double finalMinX = cfgStart;
    double finalMaxX = cfgEnd;
    
    if (minDataX < finalMinX) finalMinX = minDataX;
    if (maxDataX > finalMaxX) finalMaxX = maxDataX;

    // 3. Styling
    final double minY = minVal.toDouble();
    final double maxY = maxVal.toDouble();

    // If Negative signal, EVERYTHING is RED. 
    // If Positive signal, we use the baseColor (which is usually Green, but could be user defined).
    // Actually, user spec says: "Negative -> everything red".
    
    final effectiveColor = isPositiveSignal ? baseColor : const Color(0xFFFF2E63);

    final mainBarData = LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.35,
      barWidth: 5,
      isStrokeCapRound: true,
      shadow: const Shadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
      
      color: effectiveColor, 
      gradient: LinearGradient(
        colors: [effectiveColor, effectiveColor], 
      ),

      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 6,
            color: Colors.white,
            strokeWidth: 3,
            strokeColor: effectiveColor,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            effectiveColor.withOpacity(0.3),
            effectiveColor.withOpacity(0.0),
          ],
        ),
      ),
    );

    return SizedBox(
      height: 300,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LineChart(
          LineChartData(
             minX: finalMinX,
             maxX: finalMaxX,
             minY: minY - 1,
             maxY: maxY + 1, // Add buffer

             gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1, 
                getDrawingHorizontalLine: (value) {
                  // Only grid lines for integer values? 
                  return const FlLine(color: Colors.transparent); // Hide all for sleek look
                },
             ),

             titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: (maxY - minY) > 10 ? 5 : 1, // Dynamic interval
                    reservedSize: 24,
                    getTitlesWidget: (value, meta) {
                       if (value < minY || value > maxY) return const SizedBox.shrink();
                       return Text(
                         value.toInt().toString(),
                         style: const TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold),
                       );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 0.1, // Frequent checks
                    reservedSize: 22,
                    getTitlesWidget: (value, meta) {
                      const epsilon = 0.05;
                      bool shouldShow = false;
                      String text = '';

                      // Show Start (Wake)
                      if ((value - finalMinX).abs() < epsilon) {
                         shouldShow = true;
                         text = _formatHour(finalMinX);
                      }
                      // Show End (Sleep)
                      else if ((value - finalMaxX).abs() < epsilon) {
                         shouldShow = true;
                         text = _formatHour(finalMaxX);
                      }
                      // Show Data Points
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

                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          text,
                          style: const TextStyle(
                            color: Colors.white70, 
                            fontSize: 10, 
                            fontWeight: FontWeight.w600
                          ),
                        ),
                      );
                    },
                  ),
                ),
             ),
             
             borderData: FlBorderData(show: false),
             lineBarsData: [mainBarData],
             
             lineTouchData: LineTouchData(
               touchTooltipData: LineTouchTooltipData(
                 getTooltipColor: (_) => Colors.transparent,
                 tooltipPadding: EdgeInsets.zero,
                 tooltipMargin: 5,
                 getTooltipItems: (touchedSpots) {
                   return touchedSpots.map((spot) {
                     return LineTooltipItem(
                       spot.y.toInt().toString(), // Show Value
                       TextStyle(color: effectiveColor, fontWeight: FontWeight.bold),
                     );
                   }).toList();
                 },
               ),
             ),
          ),
        ),
      ),
    );
  }

  String _formatHour(double value) {
    double normalized = value;
    while (normalized >= 24) normalized -= 24;
    final dt = DateTime(2022, 1, 1, normalized.toInt(), (normalized % 1 * 60).toInt());
    return DateFormat('h:mm a').format(dt).toLowerCase().replaceAll(':00', ''); 
  }
}
