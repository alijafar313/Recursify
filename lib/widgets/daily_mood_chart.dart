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
    this.onPointTap,
    this.onChartTap,
  });

  final Function(MoodSnapshot)? onPointTap;
  final VoidCallback? onChartTap;

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
      gradientColors = [const Color(0xFF08D9D6), const Color(0xFF08D9D6)]; // Neon Cyan
      gradientStops = [0.0, 1.0];
    } else if (maxY < -0.001) {
      // All negative (strictly)
      gradientColors = [const Color(0xFFFF2E63), const Color(0xFFFF2E63)];
      gradientStops = [0.0, 1.0];
    } else if (minY > 0.001) {
      // All positive (strictly)
      gradientColors = [const Color(0xFF20BF55), const Color(0xFF20BF55)];
      gradientStops = [0.0, 1.0];
    } else {
      // Crossing zero OR touching zero
      final range = maxY - minY;
      // Protect against division by zero (though handled by first if)
      double zeroPos = 0.0;
      if (range > 0) {
        zeroPos = (0.0 - minY) / range;
      }
      
      // 0.02 band logic replaced with SHARP CUT
      // But we still want to handle '0.0 - minY' ratio etc.
      
      // SHARP GRADIENT: Red until 0, Green after 0.
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
    // We want to find sub-lists of spots that are consecutive zeros.
    // e.g. [Pt(1,0), Pt(2,0)] -> Draw Cyan line from 1 to 2.
    // If we have [Pt(1,0), Pt(2,5), Pt(3,0)] -> specific points are cyan, but no line segment.
    
    final List<LineChartBarData> extraLines = [];
    
    if (spots.length >= 2) {
      List<FlSpot> currentZeroSegment = [];
      
      for (int i = 0; i < spots.length; i++) {
        final spot = spots[i];
        if ((spot.y).abs() < 0.001) {
           currentZeroSegment.add(spot);
        } else {
           if (currentZeroSegment.length >= 2) {
             // We have a segment to add
             extraLines.add(_createZeroBarData(List.from(currentZeroSegment)));
           }
           currentZeroSegment.clear();
        }
      }
      // Check last
      if (currentZeroSegment.length >= 2) {
         extraLines.add(_createZeroBarData(List.from(currentZeroSegment)));
      }
    }

    // Create the bar data once so we can reference it
    final mainBarData = LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.18, // Tighter curve to prevent overshooting 0
      preventCurveOverShooting: true, // Prevents wobbling on flat lines (0 to 0)
      barWidth: 5, // Thicker line
      isStrokeCapRound: true,
      shadow: const Shadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)), // Subtle depth
      
      gradient: LinearGradient(
        colors: gradientColors,
        stops: gradientStops,
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ),
      
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
           Color dotColor = const Color(0xFF08D9D6); // Default Cyan
           if (spot.y > 0.001) dotColor = const Color(0xFF20BF55); // Green
           if (spot.y < -0.001) dotColor = const Color(0xFFFF2E63); // Red
           
           // White center, colored ring
           return FlDotCirclePainter(
             radius: 6,
             color: Colors.white,
             strokeWidth: 3,
             strokeColor: dotColor,
           );
        },
      ),
      
      // Fill from Line DOWN to 0 (Positive values) -> Green
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF20BF55).withOpacity(0.3),
            const Color(0xFF20BF55).withOpacity(0.0),
          ],
        ),
        cutOffY: 0,
        applyCutOffY: true,
      ),
      // Fill from Line UP to 0 (Negative values) -> Red
      aboveBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFFFF2E63).withOpacity(0.3),
            const Color(0xFFFF2E63).withOpacity(0.0),
          ],
        ),
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
              enabled: true,
              handleBuiltInTouches: false,
              touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                if (event is FlTapUpEvent) {
                   // We need to check if we tapped the main bar or the zero bar?
                   // Response gives us spots.
                   if (response != null && response.lineBarSpots != null && response.lineBarSpots!.isNotEmpty) {
                      // Tap on a point -> Edit
                      // Find which spot in the MAIN list corresponds to this x 
                      // (Zero bars are just overlays on same X)
                      final touchedSpot = response.lineBarSpots!.first;
                      // Find index in `spots` that matches `touchedSpot.x`
                      // Because `touchedSpot.spotIndex` might refer to the zero-list if we tapped that.
                      
                      final realIndex = spots.indexWhere((s) => (s.x - touchedSpot.x).abs() < 0.001);
                      if (realIndex != -1) {
                         final snapshot = sorted[realIndex];
                         onPointTap?.call(snapshot);
                      }
                   } else {
                      // Tap on background -> Day Detail
                      onChartTap?.call();
                   }
                }
              },
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => Colors.transparent, // Transparent background
                tooltipPadding: EdgeInsets.zero,
                tooltipMargin: 14, // Adjusted to be midway between 5 and 24
                getTooltipItems: (List<LineBarSpot> touchedSpots) {
                  return touchedSpots.map((touchedSpot) {
                    // Match to main spots
                    final index = spots.indexWhere((s) => (s.x - touchedSpot.x).abs() < 0.001);
                    if (index == -1) return null;
                    
                    // We only want to show ONE tooltip per X. 
                    // If we have overlaid bars, we might get multiple items for same X?
                    // Usually separate bars create separate items. 
                    // We can filter duplicates here or just let the MainBarData handle tooltips
                    // Since we passed `showingTooltipIndicators` ONLY for mainBarData, we should be fine?
                    // Actually, overlays might not have tooltips unless we ask.
                    
                    return LineTooltipItem(
                      sorted[index].label ?? sorted[index].title,
                      const TextStyle(
                        color: Colors.white,
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
              drawVerticalLine: true,
              verticalInterval: 3, // More dense: Every 3 hours
              horizontalInterval: 1, // Every single unit (-5, -4, ... 5)
              getDrawingVerticalLine: (value) {
                return FlLine(
                  color: Colors.white.withOpacity(0.05),
                  strokeWidth: 1,
                );
              },
              getDrawingHorizontalLine: (value) {
                if (value == 0) {
                  return const FlLine(color: Colors.white24, strokeWidth: 1); // Distinct zero line
                }
                return FlLine(
                  color: Colors.white.withOpacity(0.05),
                  strokeWidth: 1,
                );
              },
            ),

            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1, 
                  reservedSize: 24,
                  getTitlesWidget: (value, meta) {
                    if (value.abs() == 6) return const SizedBox.shrink();
                    return Text(
                      value.toInt().toString(),
                      style: const TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ),
              
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 0.1, 
                  reservedSize: 22,
                  getTitlesWidget: (value, meta) {
                    // Logic from before...
                    const epsilon = 0.05;

                    bool shouldShow = false;
                    String text = '';
                    
                    if ((value - finalMinX).abs() < epsilon) {
                       shouldShow = true;
                       text = _formatHour(finalMinX);
                    }
                    else if ((value - finalMaxX).abs() < epsilon) {
                       shouldShow = true;
                       text = _formatHour(finalMaxX);
                    }
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
            minX: finalMinX,
            maxX: finalMaxX,
            minY: -6,
            maxY: 6,
            
            rangeAnnotations: RangeAnnotations(
               verticalRangeAnnotations: greyZones.map((z) {
                 return VerticalRangeAnnotation(x1: z.x1, x2: z.x2, color: z.color);
               }).toList(),
            ),
            
            lineBarsData: [
               mainBarData,
               ...extraLines, // Add Zero Lines on top
            ],
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
  LineChartBarData _createZeroBarData(List<FlSpot> spots) {
    return LineChartBarData(
      spots: spots,
      isCurved: false, // Flat lines are straight
      barWidth: 5,
      color: const Color(0xFF08D9D6), // Neon Cyan
      isStrokeCapRound: true,
      dotData: FlDotData(show: false), // Dots handled by main bar
      belowBarData: BarAreaData(show: false),
    );
  }
}

class RangeAnnotationEntry {
  final double x1;
  final double x2;
  final Color color;
  RangeAnnotationEntry({required this.x1, required this.x2, required this.color});
}
