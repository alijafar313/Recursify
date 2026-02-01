
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RecurrencePicker extends StatefulWidget {
  final int initialValue;
  final String initialUnit;
  final String? initialWeekDays; // "1,2,3"
  final DateTime? initialStartDate;
  final String initialEndType; // 'never', 'on_date', 'after_occurrences'
  final int? initialEndValue; // date millis or count

  const RecurrencePicker({
    super.key,
    this.initialValue = 1,
    this.initialUnit = 'day',
    this.initialWeekDays,
    this.initialStartDate,
    this.initialEndType = 'never',
    this.initialEndValue,
  });

  @override
  State<RecurrencePicker> createState() => _RecurrencePickerState();
}

class _RecurrencePickerState extends State<RecurrencePicker> {
  late int _repeatValue;
  late String _repeatUnit;
  late Set<int> _weekDays;
  late DateTime _startDate;
  late String _endType;
  late int? _endValue; // Millis or count

  final TextEditingController _occurrencesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repeatValue = widget.initialValue;
    _repeatUnit = widget.initialUnit;
    
    _weekDays = {};
    if (widget.initialWeekDays != null && widget.initialWeekDays!.isNotEmpty) {
      widget.initialWeekDays!.split(',').forEach((e) {
        final i = int.tryParse(e);
        if (i != null) _weekDays.add(i);
      });
    } else {
      // Default to today if empty and weekly
      _weekDays.add(DateTime.now().weekday); 
    }

    _startDate = widget.initialStartDate ?? DateTime.now();
    _endType = widget.initialEndType;
    _endValue = widget.initialEndValue;

    if (_endType == 'after_occurrences' && _endValue != null) {
      _occurrencesController.text = _endValue.toString();
    } else {
      _occurrencesController.text = '13'; // Default from screenshot concept
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Repeats'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEverySection(),
              if (_repeatUnit == 'week') ...[
                 const SizedBox(height: 24),
                 _buildWeekDaySelector(),
              ],
               const SizedBox(height: 32),
              _buildStartsSection(),
               const SizedBox(height: 32),
              _buildEndsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEverySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Every', style: TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 12),
        Row(
          children: [
            // Number Box
            Container(
              width: 80,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade700),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonHideUnderline(
                 child: DropdownButton<int>(
                   value: _repeatValue,
                   isExpanded: true,
                   dropdownColor: Colors.grey.shade800,
                   items: List.generate(30, (i) => i + 1).map((val) => DropdownMenuItem(
                     value: val,
                     child: Text('$val', style: const TextStyle(fontSize: 16)),
                   )).toList(),
                   onChanged: (val) {
                     if (val != null) setState(() => _repeatValue = val);
                   },
                 ),
              ),
            ),
            const SizedBox(width: 16),
            // Unit Box
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade700),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _repeatUnit,
                    isExpanded: true,
                     dropdownColor: Colors.grey.shade800,
                    items: ['day', 'week', 'month', 'year'].map((unit) {
                       // Simple pluralization for display
                       String label = unit;
                       if (_repeatValue > 1) label += 's';
                       return DropdownMenuItem(value: unit, child: Text(label, style: const TextStyle(fontSize: 16)));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _repeatUnit = val);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeekDaySelector() {
    const days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    // 1=Mon .. 7=Sun in DateTime. 
    // BUT common US calendar is Sun=0/1. Let's align with DateTime: Mon=1.
    // Display: S M T W T F S. which usually means Sun Mon Tue.
    // DateTime: 1=Mon, 7=Sun.
    // So UI Order: 7, 1, 2, 3, 4, 5, 6
    final dayInts = [7, 1, 2, 3, 4, 5, 6];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final dInt = dayInts[index];
        final label = days[index];
        final isSelected = _weekDays.contains(dInt);
        
        return InkWell(
          onTap: () {
            setState(() {
              if (isSelected) {
                if (_weekDays.length > 1) _weekDays.remove(dInt);
              } else {
                _weekDays.add(dInt);
              }
            });
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 36, 
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? Colors.blueAccent.shade100 : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.blueAccent : Colors.grey.shade700,
                width: 1.5
              ),
            ),
            child: Text(
              label, 
              style: TextStyle(
                color: isSelected ? Colors.blue.shade900 : Colors.grey,
                fontWeight: FontWeight.bold
              )
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStartsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Starts', style: TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context, 
              initialDate: _startDate, 
              firstDate: DateTime(2020), 
              lastDate: DateTime(2100),
              builder: (ctx, child) {
                 return Theme(data: ThemeData.dark(), child: child!);
              }
            );
            if (picked != null) setState(() => _startDate = picked);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade700),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              DateFormat('MMMM d, y').format(_startDate),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildEndsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ends', style: TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 12),
        
        // Never
        RadioListTile<String>(
          contentPadding: EdgeInsets.zero,
          title: const Text('Never'),
          value: 'never',
          groupValue: _endType,
          onChanged: (val) => setState(() => _endType = val!),
          activeColor: Colors.blueAccent,
        ),
        
        // On [Date]
        RadioListTile<String>(
          contentPadding: EdgeInsets.zero,
          title: Row(
            children: [
              const Text('On   '),
              Expanded(
                child: InkWell(
                  onTap: _endType == 'on_date' ? () async {
                    final picked = await showDatePicker(
                      context: context, 
                      initialDate: (_endValue != null) 
                          ? DateTime.fromMillisecondsSinceEpoch(_endValue!)
                          : DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(), 
                      lastDate: DateTime(2100)
                    );
                    if (picked != null) {
                      setState(() {
                         _endValue = picked.millisecondsSinceEpoch;
                      });
                    }
                  } : () => setState(() {
                    _endType = 'on_date';
                    _endValue = DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                     decoration: BoxDecoration(
                      border: Border.all(color: _endType == 'on_date' ? Colors.blueAccent : Colors.grey.shade700),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      (_endType == 'on_date' && _endValue != null)
                          ? DateFormat('MMM d, y').format(DateTime.fromMillisecondsSinceEpoch(_endValue!))
                          : 'Select Date',
                      style: TextStyle(color: _endType == 'on_date' ? Colors.white : Colors.grey),
                    )
                  ),
                ),
              )
            ],
          ),
          value: 'on_date',
          groupValue: _endType,
          onChanged: (val) => setState(() {
             _endType = val!;
             if (_endValue == null) {
                _endValue = DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch;
             }
          }),
           activeColor: Colors.blueAccent,
        ),
        
        // After [N] occurrences
         RadioListTile<String>(
          contentPadding: EdgeInsets.zero,
          title: Row(
            children: [
              const Text('After '),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _occurrencesController,
                  enabled: _endType == 'after_occurrences',
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                     _endValue = int.tryParse(val) ?? 1;
                  },
                ),
              ),
              const Text(' occurrences'),
            ],
          ),
          value: 'after_occurrences',
          groupValue: _endType,
          onChanged: (val) => setState(() {
             _endType = val!;
             _endValue = int.tryParse(_occurrencesController.text) ?? 13;
          }),
           activeColor: Colors.blueAccent,
        ),
        
      ],
    );
  }

  void _save() {
    String? dayStr;
    if (_repeatUnit == 'week') {
      dayStr = _weekDays.join(',');
    }
    
    Navigator.pop(context, {
      'repeatValue': _repeatValue,
      'repeatUnit': _repeatUnit,
      'weekDays': dayStr,
      'startDate': _startDate.millisecondsSinceEpoch,
      'endType': _endType,
      'endValue': _endValue,
    });
  }
}
