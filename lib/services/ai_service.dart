import 'package:cloud_functions/cloud_functions.dart';
import '../data/app_database.dart';

class AIService {
  // No API key needed here anymore! It's safe on the server.
  AIService();

  Future<String> analyzeData() async {
    // 1. Fetch Data (Last 14 days)
    final db = await AppDatabase.getDb();
    
    // --- Mood Snapshots ---
    final snapshots = await db.rawQuery('''
      SELECT 
        date(created_at / 1000, 'unixepoch', 'localtime') as day,
        time(created_at / 1000, 'unixepoch', 'localtime') as time,
        snapshot.intensity,
        problem.title as context,
        snapshot.note
      FROM snapshot
      JOIN problem ON problem.id = snapshot.problem_id
      ORDER BY created_at DESC
      LIMIT 100
    ''');

    // --- Sleep Logs ---
    final sleepLogs = await db.rawQuery('''
      SELECT 
        date(end_time / 1000, 'unixepoch', 'localtime') as wake_day,
        (end_time - start_time) / (1000 * 3600.0) as duration_hours,
        quality
      FROM sleep_log
      ORDER BY end_time DESC
      LIMIT 14
    ''');

    // --- Signals (Habits/Trackers) ---
    // Fetch definitions first
    final signals = await db.query('signal_def');
    final Map<int, String> signalNames = {
      for (var s in signals) s['id'] as int: s['name'] as String
    };

    // Fetch logs
    final signalLogs = await db.rawQuery('''
      SELECT 
        signal_id, 
        value, 
        date(created_at / 1000, 'unixepoch', 'localtime') as day,
        note
      FROM signal_log
      ORDER BY created_at DESC
      LIMIT 50
    ''');

    // --- Observations ---
    final observations = await db.query(
      'observation',
      orderBy: 'created_at DESC',
      limit: 10,
    );

    if (snapshots.isEmpty && signalLogs.isEmpty && observations.isEmpty) {
      return "You haven't logged enough data yet. Please add some moods, trackers, or observations first!";
    }

    // 2. Prepare Data Strings
    final StringBuffer sleepStr = StringBuffer();
    for (var log in sleepLogs) {
      final hours = (log['duration_hours'] as double).toStringAsFixed(1);
      final quality = log['quality'] != null ? ", Quality: ${log['quality']}/5" : "";
      sleepStr.writeln("- ${log['wake_day']}: Slept $hours hours$quality");
    }

    final StringBuffer habitStr = StringBuffer();
    for (var log in signalLogs) {
      final name = signalNames[log['signal_id']] ?? 'Unknown';
      final val = log['value'];
      final day = log['day'];
      final noteVal = log['note'];
      final noteText = noteVal != null ? " ($noteVal)" : "";
      habitStr.writeln("- $day: $name = $val$noteText");
    }

    final StringBuffer obsStr = StringBuffer();
    for (var obs in observations) {
      final content = obs['content'];
      obsStr.writeln("- $content");
    }

    final StringBuffer moodStr = StringBuffer();
    for (var snap in snapshots) {
      final day = snap['day'];
      final time = snap['time'];
      final mood = snap['intensity'];
      final context = snap['context'];
      final note = snap['note'] ?? '';
      moodStr.writeln("- $day at $time: Mood $mood/10. Context: $context. Note: $note");
    }
    
    // 3. Call Firebase Cloud Function
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('analyzeMood');
      
      final result = await callable.call({
        'moodHistory': moodStr.toString(),
        'sleepHistory': sleepStr.toString(),
        'habits': habitStr.toString(),
        'observations': obsStr.toString(),
      });

      final data = result.data as Map<String, dynamic>;
      return data['result'] as String;

    } on FirebaseFunctionsException catch (e) {
      return "AI Error: ${e.message} (Code: ${e.code})";
    } catch (e) {
      return "Error connecting to AI: $e\n\nPlease check your Internet.";
    }
  }
}
