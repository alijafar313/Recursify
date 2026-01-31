import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/app_database.dart';

class TimeBlockScreen extends StatefulWidget {
  const TimeBlockScreen({super.key});

  @override
  State<TimeBlockScreen> createState() => _TimeBlockScreenState();
}

class _TimeBlockScreenState extends State<TimeBlockScreen> {
  int _selectedDay = DateTime.now().weekday; // 1=Mon, 7=Sun
  List<TimeBlock> _blocks = [];
  bool _isLoading = true;

  final List<String> _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _loadBlocks();
  }

  Future<void> _loadBlocks() async {
    setState(() => _isLoading = true);
    try {
      final blocks = await AppDatabase.getTimeBlocksForDay(_selectedDay);
      if (mounted) {
        setState(() {
          _blocks = blocks;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading blocks: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        // Show a snackbar or similar if appropriate, but at least stop the spinner
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Failed to load schedule: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addOrEditBlock([TimeBlock? existingBlock]) async {
    final isEditing = existingBlock != null;
    final nameController = TextEditingController(text: existingBlock?.name ?? '');
    TimeOfDay startTime = existingBlock != null 
        ? TimeOfDay(hour: existingBlock.startH, minute: existingBlock.startM)
        : const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = existingBlock != null 
        ? TimeOfDay(hour: existingBlock.endH, minute: existingBlock.endM)
        : const TimeOfDay(hour: 10, minute: 0);

    int selectedColor = existingBlock?.colorHex ?? 0xFF00E676;
    
    // Palette
    final colors = [
      0xFF00E676, // Green
      0xFF2979FF, // Blue
      0xFFFF1744, // Red
      0xFFFFC400, // Amber
      0xFFAA00FF, // Purple
      0xFF78909C, // Blue Grey
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24, 
                right: 24, 
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditing ? 'Edit Block' : 'New Time Block',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Activity Name (e.g. Gym)',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Color Picker
                  SizedBox(
                    height: 50,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: colors.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                         final color = colors[index];
                         final isSelected = color == selectedColor;
                         return GestureDetector(
                           onTap: () => setModalState(() => selectedColor = color),
                           child: Container(
                             width: 40,
                             height: 40,
                             decoration: BoxDecoration(
                               color: Color(color),
                               shape: BoxShape.circle,
                               border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                               boxShadow: isSelected 
                                 ? [BoxShadow(color: Color(color).withOpacity(0.6), blurRadius: 8)] 
                                 : null,
                             ),
                             child: isSelected ? const Icon(Icons.check, color: Colors.black, size: 20) : null,
                           ),
                         );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _TimePickerButton(
                          label: 'Start',
                          time: startTime,
                          onTap: () async {
                            final t = await showTimePicker(context: context, initialTime: startTime);
                            if (t != null) setModalState(() => startTime = t);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _TimePickerButton(
                          label: 'End',
                          time: endTime,
                          onTap: () async {
                            final t = await showTimePicker(context: context, initialTime: endTime);
                            if (t != null) setModalState(() => endTime = t);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(selectedColor),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                         if (nameController.text.trim().isEmpty) return;
                         
                         if (isEditing) {
                           await AppDatabase.updateTimeBlock(
                             id: existingBlock!.id,
                             name: nameController.text.trim(),
                             startH: startTime.hour,
                             startM: startTime.minute,
                             endH: endTime.hour,
                             endM: endTime.minute,
                             dayOfWeek: _selectedDay,
                             colorHex: selectedColor,
                           );
                         } else {
                           await AppDatabase.createTimeBlock(
                             name: nameController.text.trim(),
                             startH: startTime.hour,
                             startM: startTime.minute,
                             endH: endTime.hour,
                             endM: endTime.minute,
                             dayOfWeek: _selectedDay,
                             colorHex: selectedColor,
                           );
                         }
                         Navigator.pop(ctx);
                         _loadBlocks();
                      },
                      child: Text(isEditing ? 'Save Changes' : 'Create Block', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if (isEditing) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                        ),
                        onPressed: () async {
                          await AppDatabase.deleteTimeBlock(existingBlock!.id);
                          Navigator.pop(ctx);
                          _loadBlocks();
                        },
                        child: const Text('Delete Block'),
                      ),
                    ),
                    // Add buffer for safe area/bottom bar
                     SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                  ]
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showCopyDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Copy Schedule', style: TextStyle(color: Colors.white)),
          content: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               ListTile(
                 leading: const Icon(Icons.copy_all, color: Colors.blueAccent),
                 title: const Text('Copy to All Days', style: TextStyle(color: Colors.white)),
                 subtitle: const Text('Overwrite all other days with this schedule', style: TextStyle(color: Colors.white54)),
                 onTap: () async {
                   for (int i = 1; i <= 7; i++) {
                     if (i == _selectedDay) continue;
                     await AppDatabase.copyDayBlocks(_selectedDay, i);
                   }
                   Navigator.pop(ctx);
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to all days!')));
                 },
               ),
               const Divider(color: Colors.white24),
               ListTile(
                 leading: const Icon(Icons.calendar_today, color: Colors.orangeAccent),
                 title: const Text('Copy to Weekdays (Mon-Fri)', style: TextStyle(color: Colors.white)),
                 onTap: () async {
                   for (int i = 1; i <= 5; i++) {
                     if (i == _selectedDay) continue;
                     await AppDatabase.copyDayBlocks(_selectedDay, i);
                   }
                   Navigator.pop(ctx);
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to weekdays!')));
                 },
               ),
                ListTile(
                 leading: const Icon(Icons.weekend, color: Colors.greenAccent),
                 title: const Text('Copy to Weekends (Sat-Sun)', style: TextStyle(color: Colors.white)),
                 onTap: () async {
                   for (int i = 6; i <= 7; i++) {
                     if (i == _selectedDay) continue;
                     await AppDatabase.copyDayBlocks(_selectedDay, i);
                   }
                   Navigator.pop(ctx);
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to weekends!')));
                 },
               ),
             ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Weekly Schedule'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _showCopyDialog,
            tooltip: 'Copy Schedule',
          ),
        ],
      ),
      body: Column(
        children: [
          // Day Selector
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: 7,
              itemBuilder: (context, index) {
                final dayNum = index + 1;
                final isSelected = dayNum == _selectedDay;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedDay = dayNum);
                    _loadBlocks();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 12),
                    width: 50,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF00E676) : const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF00E676).withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4))
                            ]
                          : [],
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _dayNames[index],
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white60,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(builder: (context, constraints) {
                  // Calculate height: 24 hours * 60 px/hr (example)
                  const double hourHeight = 60.0;
                  const double totalHeight = 24 * hourHeight + 20; // 20 padding

                  return SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 80), // Fab space
                    child: SizedBox(
                      height: totalHeight,
                      child: Stack(
                        children: [
                          // Background Grid
                          for (int i = 0; i <= 24; i++)
                            Positioned(
                              top: i * hourHeight,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 1,
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                          // Time Labels
                          for (int i = 0; i <= 24; i++)
                            Positioned(
                              top: i * hourHeight - 6,
                              left: 16,
                              child: Text(
                                '${i.toString().padLeft(2, '0')}:00',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.3),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            
                          // Blocks
                          ..._blocks.map((block) {
                             final startMins = block.startH * 60 + block.startM;
                             final endMins = block.endH * 60 + block.endM;
                             final durationMins = endMins - startMins;
                             
                             final double top = (startMins / 60) * hourHeight;
                             final double height = (durationMins / 60) * hourHeight;
                             
                             // Default green is 0xFF00E676
                             final Color color = block.colorHex != null 
                                 ? Color(block.colorHex!) 
                                 : const Color(0xFF00E676);

                             return Positioned(
                               top: top,
                               left: 70, // offset for time labels
                               right: 16,
                               height: height > 0 ? height : 1, // Ensure visibility
                               child: GestureDetector(
                                 onTap: () => _addOrEditBlock(block),
                                 child: Container(
                                   decoration: BoxDecoration(
                                     color: color.withOpacity(0.5), // More opaque
                                     border: Border.all(color: color, width: 2),
                                     borderRadius: BorderRadius.circular(8),
                                   ),
                                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                   child: Column(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     mainAxisAlignment: MainAxisAlignment.center,
                                     children: [
                                       if (height > 20)
                                          Text(
                                            block.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        if (height > 40)
                                          Text(
                                            '${_fmtTime(block.startH, block.startM)} - ${_fmtTime(block.endH, block.endM)}',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.9),
                                              fontSize: 10,
                                              shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                     ],
                                   ),
                                 ),
                               ),
                             );
                          }).toList(),
                          
                          // Current Time Indicator (if selected day is today)
                          if (_selectedDay == DateTime.now().weekday) 
                            Builder(builder: (c) {
                               final now = DateTime.now();
                               final mins = now.hour * 60 + now.minute;
                               final top = (mins / 60) * hourHeight;
                               return Positioned(
                                 top: top,
                                 left: 0,
                                 right: 0,
                                 child: Row(
                                    children: [
                                       Container(
                                         width: 50,
                                         alignment: Alignment.centerRight,
                                         child: const Text('Now', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold))
                                       ),
                                       const SizedBox(width: 8),
                                       Expanded(child: Container(height: 1, color: Colors.redAccent)),
                                    ]
                                 ),
                               );
                            }),
                        ],
                      ),
                    ),
                  );
                }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditBlock(),
        backgroundColor: const Color(0xFF00E676),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  String _fmtTime(int h, int m) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, h, m);
    return DateFormat.jm().format(dt);
  }
}

class _TimePickerButton extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimePickerButton({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              time.format(context),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
