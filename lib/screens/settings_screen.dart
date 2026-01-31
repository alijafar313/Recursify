import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../data/app_database.dart';
import 'trash_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = false;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 21, minute: 0);
  int _intervalHours = 2;

  // New global schedule settings
  TimeOfDay _globalWakeTime = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _globalSleepTime = const TimeOfDay(hour: 23, minute: 0);

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notif_enabled') ?? false;
      
      final startH = prefs.getInt('notif_start_h') ?? 9;
      final startM = prefs.getInt('notif_start_m') ?? 0;
      _startTime = TimeOfDay(hour: startH, minute: startM);

      final endH = prefs.getInt('notif_end_h') ?? 21;
      final endM = prefs.getInt('notif_end_m') ?? 0;
      _endTime = TimeOfDay(hour: endH, minute: endM);

      _intervalHours = prefs.getInt('notif_interval') ?? 2;
      
      final gWakeH = prefs.getInt('global_wake_h') ?? 8;
      final gWakeM = prefs.getInt('global_wake_m') ?? 0;
      _globalWakeTime = TimeOfDay(hour: gWakeH, minute: gWakeM);

      final gSleepH = prefs.getInt('global_sleep_h') ?? 23;
      final gSleepM = prefs.getInt('global_sleep_m') ?? 0;
      _globalSleepTime = TimeOfDay(hour: gSleepH, minute: gSleepM);
      
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_enabled', _notificationsEnabled);
    
    await prefs.setInt('notif_start_h', _startTime.hour);
    await prefs.setInt('notif_start_m', _startTime.minute);

    await prefs.setInt('notif_end_h', _endTime.hour);
    await prefs.setInt('notif_end_m', _endTime.minute);

    await prefs.setInt('notif_interval', _intervalHours);

    await prefs.setInt('global_wake_h', _globalWakeTime.hour);
    await prefs.setInt('global_wake_m', _globalWakeTime.minute);
    await prefs.setInt('global_sleep_h', _globalSleepTime.hour);
    await prefs.setInt('global_sleep_m', _globalSleepTime.minute);

    // Apply logic
    if (_notificationsEnabled) {
      await NotificationService().requestPermissions();
      await NotificationService().scheduleNotifications(
        startTime: _startTime,
        endTime: _endTime,
        interval: Duration(hours: _intervalHours),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifications scheduled!')),
        );
      }
    } else {
      await NotificationService().flutterLocalNotificationsPlugin.cancelAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifications disabled.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          SwitchListTile(
            title: const Text('Enable Mood Reminders'),
            subtitle: const Text('Receive periodic notifications to log your mood'),
            value: _notificationsEnabled,
            onChanged: (val) {
              setState(() => _notificationsEnabled = val);
              _saveSettings();
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Schedule',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            enabled: _notificationsEnabled,
            leading: const Icon(Icons.wb_sunny_outlined),
            title: const Text('Start Time'),
            subtitle: Text(_startTime.format(context)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: _startTime);
              if (t != null) {
                setState(() => _startTime = t);
                _saveSettings();
              }
            },
          ),
          ListTile(
            enabled: _notificationsEnabled,
            leading: const Icon(Icons.nightlight_outlined),
            title: const Text('End Time'),
            subtitle: Text(_endTime.format(context)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: _endTime);
              if (t != null) {
                setState(() => _endTime = t);
                _saveSettings();
              }
            },
          ),
          const SizedBox(height: 16),
          ListTile(
            enabled: _notificationsEnabled,
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Frequency'),
            subtitle: Text('Every $_intervalHours hours'),
            trailing: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _intervalHours,
                items: [1, 2, 3, 4, 6, 8, 12].map((h) {
                  return DropdownMenuItem(value: h, child: Text('$h h'));
                }).toList(),
                onChanged: _notificationsEnabled
                    ? (val) {
                        if (val != null) {
                          setState(() => _intervalHours = val);
                          _saveSettings();
                        }
                      }
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_notificationsEnabled)
            const Card(
              color: Colors.amberAccent,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Tip: You can "Reply" to the notification with just a number (1-10) to log quickly without opening the app!',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
/*
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Daily Schedule (For Graphs)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.wb_twilight),
            title: const Text('Wake Up Time'),
            subtitle: Text(_globalWakeTime.format(context)),
            trailing: const Icon(Icons.edit, size: 16),
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: _globalWakeTime);
              if (t != null) {
                setState(() => _globalWakeTime = t);
                _saveSettings();
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.bed),
            title: const Text('Sleep Time'),
            subtitle: Text(_globalSleepTime.format(context)),
            trailing: const Icon(Icons.edit, size: 16),
            onTap: () async {
              final t = await showTimePicker(context: context, initialTime: _globalSleepTime);
              if (t != null) {
                setState(() => _globalSleepTime = t);
                _saveSettings();
              }
            },
          ),
          */
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Trash'),
            subtitle: const Text('Restore items or empty trash'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TrashScreen()),
              );
            },
          ),
          
          const Divider(),
          ListTile(
            leading: const Icon(Icons.bug_report, color: Colors.purple),
            title: const Text('Developer: Seed Test Data', style: TextStyle(color: Colors.purple)),
            subtitle: const Text('Resets DB & adds mock graphs'),
            onTap: () async {
              await AppDatabase.seedDebugData();
              if (mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Database reset and seeded! Restart maybe needed to refresh caching.')),
                 );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.exposure_zero, color: Colors.purple),
            title: const Text('Developer: Seed Zero Day', style: TextStyle(color: Colors.purple)),
            subtitle: const Text('Sets today to all 0s (Cyan test)'),
            onTap: () async {
              await AppDatabase.seedZeroData();
              if (mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Today seeded with zeros! Refresh Home.')),
                 );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active, color: Colors.purple),
            title: const Text('Developer: Test Notification', style: TextStyle(color: Colors.purple)),
            subtitle: const Text('Triggers the "Log Mood" notification now'),
            onTap: () async {
              await NotificationService().triggerNotification(
                title: 'How are you feeling?',
                body: 'Tap "Quick Log" to enter -5 to 5',
              );
              
              if (mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Notification sent! Check your status bar.')),
                 );
              }
            },
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
