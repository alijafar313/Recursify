import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../data/app_database.dart';
import 'package:intl/intl.dart';

class DailyMoodChart extends StatefulWidget {
  final List<MoodSnapshot> snapshots;
  final DateTime date;
  final TimeOfDay? wakeTime;
  final TimeOfDay? sleepTime;
  final bool isOverride; 

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
  State<DailyMoodChart> createState() => _DailyMoodChartState();
}

class _DailyMoodChartState extends State<DailyMoodChart> {
  late ScrollController _scrollController;
  final double _pixelsPerHour = 30.0; // Reduced width per hour
  
  // Computed values
  late double _finalMinX;
  late double _finalMaxX;
  late List<FlSpot> _spots;
  late List<MoodSnapshot> _sortedSnapshots;
  
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    
    // Defer initial scroll until after layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToStart();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Logic to calculate initial scroll position
  void _scrollToStart() {
    if (!mounted) return;
    
    double wakeH = 6.0; // Default fallback
    if (widget.wakeTime != null) {
      wakeH = widget.wakeTime!.hour + widget.wakeTime!.minute / 60.0;
    }
    
    // Find earliest data point
    double minDataH = 999.0;
    if (_spots.isNotEmpty) {
      minDataH = _spots.map((e) => e.x).reduce((a, b) => a < b ? a : b);
    }
    
    // If we have a point earlier than wake time, center on that (align left)
    // Otherwise align left to wake time.
    double targetH = wakeH;
    if (minDataH < wakeH) {
      targetH = minDataH; 
    }
    
    // Add a tiny padding so the point isn't literally on the edge?
    // User said "first time shown on the left side".
    // Let's stick strictly to targetH or maybe targetH - 0.5 for breathing room.
    // "auto-center in a way that the wake up time is the first time shown on the left side" implies exact.
    
    final offset = targetH * _pixelsPerHour;
    
    // Clamp offset to max scroll
    final maxScroll = _scrollController.position.maxScrollExtent;
    final clamped = offset.clamp(0.0, maxScroll);
    
    setState(() {
       // Trigger rebuild if strictly needed? No, jumpTo is enough.
       _scrollController.jumpTo(clamped);
    });
  }
  
  // Re-calculate spots when widget updates
  void _processData() {
     _sortedSnapshots = List<MoodSnapshot>.from(widget.snapshots)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

     _spots = [];
     
     double minDataX = 999.0;
     double maxDataX = -999.0;

     for (var s in _sortedSnapshots) {
        final t = DateTime.parse(s.timestamp);
        final diff = t.difference(DateTime(widget.date.year, widget.date.month, widget.date.day));
        double val = diff.inMinutes / 60.0;
        
        if (val < minDataX) minDataX = val;
        if (val > maxDataX) maxDataX = val;

        _spots.add(FlSpot(val, s.intensity.toDouble()));
     }
     
     // Determine range. 
     // We want full 24 hours (0 to 24) displayed at minimum.
     // Also handle sleep overflow (e.g. up to 28 or 30).
     
     double startLimit = 0.0;
     double endLimit = 24.0;
     
     // Calculate configured sleep end to see if we need to extend
     if (widget.sleepTime != null && widget.wakeTime != null) {
        double sH = widget.sleepTime!.hour + widget.sleepTime!.minute / 60.0;
        double wH = widget.wakeTime!.hour + widget.wakeTime!.minute / 60.0;
        if (sH < wH) sH += 24.0; // Next day
        if (sH > endLimit) endLimit = sH + 1; // Extend graph to cover sleep
     }
     
     // Extend if data is outside limits
     if (maxDataX > endLimit) endLimit = maxDataX + 1;
     
     _finalMinX = startLimit;
     _finalMaxX = endLimit;
  }

  @override
  Widget build(BuildContext context) {
    _processData();

    // Prepare Grey Zones (Sleep Indicators in background)
    // Wake -> Sleep is active.
    // 0 -> Wake is sleep.
    // Sleep -> End is sleep.
    
    List<RangeAnnotationEntry> greyZones = [];
    if (!widget.isOverride && widget.wakeTime != null && widget.sleepTime != null) {
       double wH = widget.wakeTime!.hour + widget.wakeTime!.minute / 60.0;
       double sH = widget.sleepTime!.hour + widget.sleepTime!.minute / 60.0;
       
       // Pre-wake sleep
       greyZones.add(RangeAnnotationEntry(x1: 0, x2: wH, color: Colors.grey.withOpacity(0.15)));
       
       // Post-sleep sleep
       if (sH < wH) sH += 24.0; // e.g. 23:00 (23) -> 07:00 (31)
       
       greyZones.add(RangeAnnotationEntry(x1: sH, x2: _finalMaxX + 24, color: Colors.grey.withOpacity(0.15))); // +24 safely covers end
    } else {
       // fallback if no times set, maybe 0-6 is grey?
       // Leaving empty if not strictly required, as per existing logic.
    }
    
    // --- Gradient Logic (Same as before) ---
    double minY = 0;
    double maxY = 0;
    if (_spots.isNotEmpty) {
      minY = _spots.map((e) => e.y).reduce((a, b) => a < b ? a : b);
      maxY = _spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    }
    List<Color> gradientColors = [Colors.red, Colors.red, Colors.green, Colors.green];
    List<double> gradientStops = [0.0, 0.5, 0.5, 1.0];

    if (minY == 0 && maxY == 0) {
      gradientColors = [const Color(0xFF08D9D6), const Color(0xFF08D9D6)];
      gradientStops = [0.0, 1.0];
    } else if (maxY < -0.001) {
      gradientColors = [const Color(0xFFFF2E63), const Color(0xFFFF2E63)];
      gradientStops = [0.0, 1.0];
    } else if (minY > 0.001) {
      gradientColors = [const Color(0xFF20BF55), const Color(0xFF20BF55)];
      gradientStops = [0.0, 1.0];
    } else {
      final range = maxY - minY;
      double zeroPos = 0.0;
      if (range > 0) zeroPos = (0.0 - minY) / range;
      gradientColors = [
        const Color(0xFFFF2E63), const Color(0xFFFF2E63),
        const Color(0xFF20BF55), const Color(0xFF20BF55),
      ];
      gradientStops = [
        0.0, zeroPos.clamp(0.0, 1.0), (zeroPos + 0.001).clamp(0.0, 1.0), 1.0,
      ];
    }
    
    // --- Zero Segments Logic ---
    final List<LineChartBarData> extraLines = [];
    if (_spots.length >= 2) {
      List<FlSpot> currentZeroSegment = [];
      for (int i = 0; i < _spots.length; i++) {
        final spot = _spots[i];
        if ((spot.y).abs() < 0.001) {
           currentZeroSegment.add(spot);
        } else {
           if (currentZeroSegment.length >= 2) extraLines.add(_createZeroBarData(List.from(currentZeroSegment)));
           currentZeroSegment.clear();
        }
      }
      if (currentZeroSegment.length >= 2) extraLines.add(_createZeroBarData(List.from(currentZeroSegment)));
    }
    
    // --- Main Bar Data ---
    final mainBarData = LineChartBarData(
      spots: _spots,
      isCurved: true,
      curveSmoothness: 0.18,
      preventCurveOverShooting: true,
      barWidth: 5,
      isStrokeCapRound: true,
      shadow: const Shadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
      gradient: LinearGradient(
        colors: gradientColors, stops: gradientStops,
        begin: Alignment.bottomCenter, end: Alignment.topCenter,
      ),
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
           Color dotColor = const Color(0xFF08D9D6);
           if (spot.y > 0.001) dotColor = const Color(0xFF20BF55);
           if (spot.y < -0.001) dotColor = const Color(0xFFFF2E63);
           return FlDotCirclePainter(radius: 6, color: Colors.white, strokeWidth: 3, strokeColor: dotColor);
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [const Color(0xFF20BF55).withOpacity(0.3), const Color(0xFF20BF55).withOpacity(0.0)],
        ),
        cutOffY: 0, applyCutOffY: true,
      ),
      aboveBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [const Color(0xFFFF2E63).withOpacity(0.3), const Color(0xFFFF2E63).withOpacity(0.0)],
        ),
        cutOffY: 0, applyCutOffY: true,
      ),
    );

    // Calculate total width based on time span
    final double totalWidth = (_finalMaxX - _finalMinX) * _pixelsPerHour;

    return SizedBox(
      height: 350, 
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12), // Revert outer padding
        child: Row(
          children: [
             // --- FIXED Y-AXIS ---
             _buildFixedYAxis(),
             
             // --- SCROLLABLE CHART ---
             Expanded(
               child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: Container(
                   // Internal padding: 
                   // Horizontal (24) -> prevents start/end label clipping
                   // Top (40) -> space for tooltips to overflow without being clipped by ScrollView
                   padding: const EdgeInsets.fromLTRB(24, 40, 24, 0), 
                   width: (totalWidth + 48) < MediaQuery.of(context).size.width ? MediaQuery.of(context).size.width : (totalWidth + 48),
                   child: _buildLineChart(mainBarData, extraLines, greyZones, List.generate(_spots.length, (i) => i)),
                ),
               ),
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildFixedYAxis() {
    return Container(
      width: 30, // Fixed width for axis
      // Top (40) -> Matches chart top padding
      // Bottom (22) -> Matches chart bottom titles reserved size
      padding: const EdgeInsets.fromLTRB(0, 40, 0, 22), 
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(13, (index) {
          // index 0 = 6, index 12 = -6
          final value = 6 - index;
          if (value.abs() == 6) {
             // Invisible placeholder to maintain spacing alignment
             return const SizedBox(height: 10, width: 10); 
          }
          return Text(
            '$value',
            style: const TextStyle(
              color: Colors.white30, 
              fontSize: 10, 
              fontWeight: FontWeight.bold
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLineChart(
    LineChartBarData mainBarData, 
    List<LineChartBarData> extraLines,
    List<RangeAnnotationEntry> greyZones,
    List<int> tooltipsOnSpots
  ) {
    return LineChart(
      LineChartData(
        clipData: const FlClipData.none(),
        showingTooltipIndicators: tooltipsOnSpots.map((index) {
              return ShowingTooltipIndicators([
                LineBarSpot(
                  mainBarData,
                  0,
                  _spots[index],
                ),
              ]);
            }).toList(),
            
            lineTouchData: LineTouchData(
              enabled: true,
              handleBuiltInTouches: false,
              touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                if (event is FlTapUpEvent) {
                   if (response != null && response.lineBarSpots != null && response.lineBarSpots!.isNotEmpty) {
                      final touchedX = response.lineBarSpots!.first.x;
                      final index = _spots.indexWhere((s) => (s.x - touchedX).abs() < 0.001);
                      if (index != -1) {
                         widget.onPointTap?.call(_sortedSnapshots[index]);
                      }
                   } else {
                      widget.onChartTap?.call();
                   }
                }
              },
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => Colors.transparent,
                tooltipPadding: EdgeInsets.zero,
                tooltipMargin: 14,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((touchedSpot) {
                    final index = _spots.indexWhere((s) => (s.x - touchedSpot.x).abs() < 0.001);
                    if (index == -1) return null;
                    final s = _sortedSnapshots[index];
                    return LineTooltipItem(
                      s.label ?? s.title,
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                    );
                  }).toList();
                },
              ),
            ),

            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              verticalInterval: 1, 
              horizontalInterval: 1,
              getDrawingVerticalLine: (value) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1),
              getDrawingHorizontalLine: (value) {
                if (value == 0) return const FlLine(color: Colors.white24, strokeWidth: 1);
                return FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1);
              },
            ),

            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), // Hide internal left titles
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1, 
                  reservedSize: 22,
                  getTitlesWidget: (value, meta) {
                    if (value % 2 == 0) {
                       return Padding(
                         padding: const EdgeInsets.only(top: 8),
                         child: Text(
                           _formatHour(value),
                           style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                         ),
                       );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),

            borderData: FlBorderData(show: false),
            minX: _finalMinX,
            maxX: _finalMaxX,
            minY: -6, maxY: 6,
            
            rangeAnnotations: RangeAnnotations(
               verticalRangeAnnotations: greyZones.map((z) => VerticalRangeAnnotation(x1: z.x1, x2: z.x2, color: z.color)).toList(),
            ),
            
            lineBarsData: [mainBarData, ...extraLines],
      ),
    );
  }

  String _formatHour(double value) {
    double normalized = value;
    while (normalized >= 24) normalized -= 24;
    final h = normalized.toInt();
    // Simple 12am/pm formatting
    if (h == 0) return '12 am';
    if (h == 12) return '12 pm';
    if (h < 12) return '$h am';
    return '${h - 12} pm';
  }

  LineChartBarData _createZeroBarData(List<FlSpot> spots) {
    return LineChartBarData(
      spots: spots, isCurved: false, barWidth: 5, color: const Color(0xFF08D9D6),
      isStrokeCapRound: true, dotData: FlDotData(show: false), belowBarData: BarAreaData(show: false),
    );
  }
}

class RangeAnnotationEntry {
  final double x1;
  final double x2;
  final Color color;
  RangeAnnotationEntry({required this.x1, required this.x2, required this.color});
}
