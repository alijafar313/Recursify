import 'package:google_generative_ai/google_generative_ai.dart';
import '../data/app_database.dart';

class AIService {
  final String apiKey;

  AIService(this.apiKey);

  Future<String> analyzeMoods() async {
    // 1. Fetch Data (Last 14 days)
    final db = await AppDatabase.getDb();
    
    // Get Snapshots
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

    // Get Sleep Logs
    final sleepLogs = await db.rawQuery('''
      SELECT 
        date(end_time / 1000, 'unixepoch', 'localtime') as wake_day,
        (end_time - start_time) / (1000 * 3600.0) as duration_hours
      FROM sleep_log
      ORDER BY end_time DESC
      LIMIT 14
    ''');

    if (snapshots.isEmpty) {
      return "You haven't logged any mood snapshots yet. Please add some data first!";
    }

    // 2. Construct Prompt
    final StringBuffer prompt = StringBuffer();
    prompt.writeln("You are an emotional wellness coach. Analyze the following user data to find patterns between sleep, context, and mood.");
    prompt.writeln("Provide a daily summary and identifies triggers (positive 'Boosters' and negative 'Drainers').");
    prompt.writeln("Be concise, friendly, and use bullet points.");
    prompt.writeln("\n--- DATA START ---");
    
    prompt.writeln("\nSLEEP HISTORY (Last 2 weeks):");
    for (var log in sleepLogs) {
      final hours = (log['duration_hours'] as double).toStringAsFixed(1);
      prompt.writeln("- ${log['wake_day']}: Slept $hours hours");
    }

    prompt.writeln("\nMOOD HISTORY (Last 100 entries):");
    for (var snap in snapshots) {
      final day = snap['day'];
      final time = snap['time'];
      final mood = snap['intensity'];
      final context = snap['context'];
      final note = snap['note'] ?? '';
      prompt.writeln("- $day at $time: Mood $mood/10. Context: $context. Note: $note");
    }
    prompt.writeln("--- DATA END ---\n");
    prompt.writeln("Please analyze this data:");

    // 3. Call Gemini
    try {
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
      final content = [Content.text(prompt.toString())];
      final response = await model.generateContent(content);
      
      return response.text ?? "No analysis generated.";
    } catch (e) {
      return "Error connecting to AI: $e\n\nPlease check your API Key.";
    }
  }
}
