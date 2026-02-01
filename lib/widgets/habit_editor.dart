
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'recurrence_picker.dart';

class HabitEditor extends StatefulWidget {
  final String? initialName;
  final int initialFreqDays; // LEGACY MAPPING: 1=daily, 7=weekly. 
  final int initialH;
  final int initialM;
  final bool initialNotify;
  
  // Advanced Initials (if editing existing)
  final int repeatValue;
  final String repeatUnit;
  final String? weekDays;
  final int? startDate;
  final String endType;
  final int? endValue;

  const HabitEditor({
    super.key,
    this.initialName,
    this.initialFreqDays = 1,
    this.initialH = 9,
    this.initialM = 0,
    this.initialNotify = false,
    this.repeatValue = 1,
    this.repeatUnit = 'day',
    this.weekDays,
    this.startDate,
    this.endType = 'never',
    this.endValue,
  });

  @override
  State<HabitEditor> createState() => _HabitEditorState();
}

class _HabitEditorState extends State<HabitEditor> {
  late TextEditingController _nameController;
  late TimeOfDay _time;
  late bool _notify;
  
  // Recurrence State
  late int _repeatValue;
  late String _repeatUnit;
  late String? _weekDays;
  late DateTime _startDate;
  late String _endType;
  late int? _endValue;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _time = TimeOfDay(hour: widget.initialH, minute: widget.initialM);
    _notify = widget.initialNotify;

    // Initialize Recurrence with passed values OR legacy mapping
    _repeatValue = widget.repeatValue;
    _repeatUnit = widget.repeatUnit;
    _weekDays = widget.weekDays;
    _startDate = widget.startDate != null 
        ? DateTime.fromMillisecondsSinceEpoch(widget.startDate!) 
        : DateTime.now();
    _endType = widget.endType;
    _endValue = widget.endValue;
    
    // Map legacy frequencyDays if repeatUnit is default but freqDays is specific
    if (widget.initialFreqDays == 7 && _repeatUnit == 'day' && _repeatValue == 1) {
       _repeatUnit = 'week';
       _repeatValue = 1;
       // Default to today's weekday
       _weekDays = DateTime.now().weekday.toString();
    }
  }

  String _getRecurrenceSummary() {
    if (_repeatUnit == 'day') {
      if (_repeatValue == 1) return 'Daily';
      return 'Every $_repeatValue days';
    }
    if (_repeatUnit == 'week') {
      String base = (_repeatValue == 1) ? 'Weekly' : 'Every $_repeatValue weeks';
      if (_weekDays != null) {
        final days = _weekDays!.split(',').map((e) {
             final d = int.tryParse(e);
             if (d == null) return '';
             const map = {1:'Mon', 2:'Tue', 3:'Wed', 4:'Thu', 5:'Fri', 6:'Sat', 7:'Sun'};
             return map[d] ?? '';
        }).where((e) => e.isNotEmpty).join(', ');
        if (days.isNotEmpty) base += ' on $days';
      }
      return base;
    }
    if (_repeatUnit == 'month') {
        if (_repeatValue == 1) return 'Monthly';
        return 'Every $_repeatValue months';
    }
     if (_repeatUnit == 'year') {
        if (_repeatValue == 1) return 'Yearly';
        return 'Every $_repeatValue years';
    }
    return 'Custom';
  }

  Future<void> _openRecurrencePicker() async {
    final result = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => RecurrencePicker(
        initialValue: _repeatValue,
        initialUnit: _repeatUnit,
        initialWeekDays: _weekDays,
        initialStartDate: _startDate,
        initialEndType: _endType,
        initialEndValue: _endValue,
      ))
    );

    if (result != null && result is Map) {
      setState(() {
        _repeatValue = result['repeatValue'];
        _repeatUnit = result['repeatUnit'];
        _weekDays = result['weekDays'];
        _startDate = DateTime.fromMillisecondsSinceEpoch(result['startDate']);
        _endType = result['endType'];
        _endValue = result['endValue'];
      });
    }
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) return;
    
    // Calculate legacy frequencyDays approximation
    int legacyFreq = 1;
    if (_repeatUnit == 'week') legacyFreq = 7 * _repeatValue;
    else if (_repeatUnit == 'day') legacyFreq = _repeatValue;
    // ... just an approximation for sorting logic if needed

    Navigator.pop(context, {
      'name': _nameController.text.trim(),
      'timeH': _time.hour,
      'timeM': _time.minute,
      'notify': _notify,
      'freqDays': legacyFreq,
      'repeatValue': _repeatValue,
      'repeatUnit': _repeatUnit,
      'weekDays': _weekDays,
      'startDate': _startDate.millisecondsSinceEpoch,
      'endType': _endType,
      'endValue': _endValue,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Handle keyboard overlap
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 0, 
        right: 0,
        top: 0
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
            // Handle Bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
              child: TextField(
                controller: _nameController,
                autofocus: true,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: 'New Habit',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey)
                ),
              ),
            ),
            const Divider(),
            
            // Recurrence Tile
            ListTile(
              leading: const Icon(Icons.repeat, color: Colors.blueAccent),
              title: Text(_getRecurrenceSummary()),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openRecurrencePicker,
            ),
            
            // Time Tile
             ListTile(
              leading: const Icon(Icons.access_time, color: Colors.amber),
              title: Text(_time.format(context)),
              trailing: const Icon(Icons.expand_more),
              onTap: () async {
                 final t = await showTimePicker(context: context, initialTime: _time);
                 if (t != null) setState(() => _time = t);
              },
            ),
            
            // Notifications
             SwitchListTile(
              secondary: Icon(_notify ? Icons.notifications_active : Icons.notifications_off, color: _notify ? Colors.purpleAccent : Colors.grey),
              title: const Text('Reminders'),
              value: _notify,
              onChanged: (val) => setState(() => _notify = val),
            ),
            
            const SizedBox(height: 16),
            
            // Save Button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                child: const Text('Save Habit', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
        ],
      ),
    );
  }
}
