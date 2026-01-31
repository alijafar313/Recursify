import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'sleep_screen.dart';
import 'general_analytics_screen.dart';
import 'ai_screen.dart';
import 'observations_screen.dart';
import 'tracker_screen.dart';
import 'time_block_screen.dart';

import 'settings_screen.dart';
import '../services/amplification_service.dart';
import '../services/notification_service.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // We use a GlobalKey to access HomeScreen state to refresh it
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();
  
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // Check amplification state on startup
    AmplificationService().checkState().then((_) {
      if (mounted) setState(() {});
    });
    
    // Request Notification Permissions on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().requestPermissions();
    });

      _screens = [
       HomeScreen(key: _homeKey),
       const TimeBlockScreen(),
       const GeneralAnalyticsScreen(),
       const TrackerScreen(),
       const ObservationsScreen(),
       const AIScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moodly'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
               await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              // Refresh Home when returning from settings (e.g. after seeding data)
              _homeKey.currentState?.refreshData();
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            label: 'Signals',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.lightbulb_outline),
            label: 'Insights',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.psychology), 
            label: 'AI',
          ),
        ],
      ),
    );
  }
}
