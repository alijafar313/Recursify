import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/app_database.dart';

class AIService {
  final String apiKey;

  AIService(this.apiKey);

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

    // 2. Construct Prompt
    final StringBuffer prompt = StringBuffer();
    prompt.writeln("You are an emotional wellness coach. Analyze the following user data to find patterns between sleep, context, habits (signals), and mood.");
    prompt.writeln("Provide a daily summary and identify triggers (positive 'Boosters' and negative 'Drainers').");
    prompt.writeln("Also note any trends in the user's observations.");
    prompt.writeln("Be concise, friendly, and use bullet points.");
    
    prompt.writeln("\n--- SLEEP HISTORY (Last 2 weeks) ---");
    for (var log in sleepLogs) {
      final hours = (log['duration_hours'] as double).toStringAsFixed(1);
      final quality = log['quality'] != null ? ", Quality: ${log['quality']}/5" : "";
      prompt.writeln("- ${log['wake_day']}: Slept $hours hours$quality");
    }

    prompt.writeln("\n--- HABITS / TRACKERS (Last 50 entries) ---");
    for (var log in signalLogs) {
      final name = signalNames[log['signal_id']] ?? 'Unknown';
      final val = log['value'];
      final day = log['day'];
      final noteVal = log['note'];
      final noteText = noteVal != null ? " ($noteVal)" : ""; // e.g. " (Low energy)"
      prompt.writeln("- $day: $name = $val$noteText");
    }

    prompt.writeln("\n--- OBSERVATIONS (Last 10) ---");
    for (var obs in observations) {
      final content = obs['content'];
      prompt.writeln("- $content");
    }

    prompt.writeln("\n--- MOOD HISTORY (Last 100 entries) ---");
    for (var snap in snapshots) {
      final day = snap['day'];
      final time = snap['time'];
      final mood = snap['intensity'];
      final context = snap['context'];
      final note = snap['note'] ?? '';
      prompt.writeln("- $day at $time: Mood $mood/10. Context: $context. Note: $note");
    }
    
    prompt.writeln("\nPlease analyze this data:");

    // 3. Call OpenAI
    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {'role': 'system', 'content': 'You are a helpful, empathetic data analyst for a mental health app.'},
            {'role': 'user', 'content': prompt.toString()},
          ],
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'] as String;
      } else {
        return "Error from OpenAI (${response.statusCode}): ${response.body}";
      }
    } catch (e) {
      return "Error connecting to AI: $e\n\nPlease check your Internet and API Key.";
    }
  }
}
