import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';

/// AppDatabase is a small helper class that:
/// 1) Creates / opens a local SQLite database file on the device.
/// 2) Creates our tables the very first time the database is created.
/// 3) Provides functions we can call from the UI to read/write data.
class AppDatabase {
  // We keep a single database connection open (singleton pattern).
  static Database? _db;

  /// Returns an open database connection.
  static Future<Database> getDb() async {
    // If already opened, reuse it.
    if (_db != null) return _db!;

    // getDatabasesPath() gives a safe device location for database files.
    final dbPath = await getDatabasesPath();

    // join(...) builds a correct path like ".../moodly.db" on any platform.
    final path = join(dbPath, 'moodly.db');

    // openDatabase will create the DB file if it doesn't exist.
    _db = await openDatabase(
      path,
      version: 11,
      onCreate: (db, version) async {
        // TABLE: problem
        await db.execute('''
          CREATE TABLE problem (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL UNIQUE
          );
        ''');

        // TABLE: snapshot
        await db.execute('''
          CREATE TABLE snapshot (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            problem_id INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            intensity INTEGER NOT NULL,
            note TEXT,
            FOREIGN KEY (problem_id) REFERENCES problem(id)
          );
        ''');

        // TABLE: recheck
        await db.execute('''
          CREATE TABLE recheck (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            snapshot_id INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            status TEXT NOT NULL CHECK (status IN ('STILL', 'LESS', 'NOT')),
            FOREIGN KEY (snapshot_id) REFERENCES snapshot(id)
          );
        ''');

        // TABLE: sleep_log
        await db.execute('''
          CREATE TABLE sleep_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            start_time INTEGER NOT NULL,
            end_time INTEGER NOT NULL,
            quality INTEGER
          );
        ''');

        // TABLE: day_schedule (Overrides)
        await db.execute('''
          CREATE TABLE day_schedule (
            date TEXT PRIMARY KEY, 
            wake_h INTEGER NOT NULL,
            wake_m INTEGER NOT NULL,
            sleep_h INTEGER NOT NULL,
            sleep_m INTEGER NOT NULL
          );
        ''');

        // TABLE: observation
        await db.execute('''
          CREATE TABLE observation (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            deleted_at INTEGER
          );
        ''');

        // TABLE: problem_solution
        await db.execute('''
          CREATE TABLE problem_solution (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            problem TEXT NOT NULL,
            solution TEXT NOT NULL,
            thumbs_up INTEGER DEFAULT 0,
            thumbs_down INTEGER DEFAULT 0,
            created_at INTEGER NOT NULL,
            deleted_at INTEGER
          );
        ''');

        // TABLE: parked_thought
        await db.execute('''
          CREATE TABLE parked_thought (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content TEXT NOT NULL,
            original_intensity INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            reviewed_at INTEGER,
            resolution TEXT
          );
        ''');

        // TABLE: signal_def
        await db.execute('''
          CREATE TABLE signal_def (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            min_val INTEGER DEFAULT 1,
            max_val INTEGER DEFAULT 10,
            color_hex INTEGER DEFAULT 4280391411,
            is_positive INTEGER DEFAULT 1
          );
        ''');

        // TABLE: signal_log
        await db.execute('''
          CREATE TABLE signal_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            signal_id INTEGER NOT NULL,
            value INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            note TEXT,
            FOREIGN KEY(signal_id) REFERENCES signal_def(id) ON DELETE CASCADE
          );
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE sleep_log (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              start_time INTEGER NOT NULL,
              end_time INTEGER NOT NULL,
              quality INTEGER
            );
          ''');
        }
        if (oldVersion < 3) {
           await db.execute('''
            CREATE TABLE day_schedule (
              date TEXT PRIMARY KEY,
              wake_h INTEGER NOT NULL,
              wake_m INTEGER NOT NULL,
              sleep_h INTEGER NOT NULL,
              sleep_m INTEGER NOT NULL
            );
          ''');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE observation (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              content TEXT NOT NULL,
              created_at INTEGER NOT NULL
            );
          ''');
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE problem_solution (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              problem TEXT NOT NULL,
              solution TEXT NOT NULL,
              thumbs_up INTEGER DEFAULT 0,
              thumbs_down INTEGER DEFAULT 0,
              created_at INTEGER NOT NULL
            );
          ''');
        }
        if (oldVersion < 6) {
          // Add deleted_at columns
           try { await db.execute('ALTER TABLE observation ADD COLUMN deleted_at INTEGER'); } catch (_) {}
           try { await db.execute('ALTER TABLE problem_solution ADD COLUMN deleted_at INTEGER'); } catch (_) {}
        }
        if (oldVersion < 7) {
          await db.execute('''
            CREATE TABLE parked_thought (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              content TEXT NOT NULL,
              original_intensity INTEGER NOT NULL,
              created_at INTEGER NOT NULL,
              reviewed_at INTEGER,
              resolution TEXT -- 'dismissed', 'integrated', 'false_alarm'
            );
          ''');
        }
        if (oldVersion < 8) {
           // We skip this block effectively since we handle it in < 9 properly with IF NOT EXISTS
        }
        if (oldVersion < 9) {
           await db.execute('''
            CREATE TABLE IF NOT EXISTS signal_def (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              min_val INTEGER DEFAULT 1,
              max_val INTEGER DEFAULT 10,
              color_hex INTEGER DEFAULT 4280391411,
              is_positive INTEGER DEFAULT 1
            );
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS signal_log (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              signal_id INTEGER NOT NULL,
              value INTEGER NOT NULL,
              created_at INTEGER NOT NULL,
              note TEXT,
              FOREIGN KEY(signal_id) REFERENCES signal_def(id) ON DELETE CASCADE
            );
          ''');
        }
        if (oldVersion < 10) {
           try { await db.execute('ALTER TABLE observation ADD COLUMN deleted_at INTEGER'); } catch (_) {}
           try { await db.execute('ALTER TABLE problem_solution ADD COLUMN deleted_at INTEGER'); } catch (_) {}
        }
        if (oldVersion < 11) {
          // Re-force creation of signal tables for users who missed it in v9/v10
           await db.execute('''
            CREATE TABLE IF NOT EXISTS signal_def (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              min_val INTEGER DEFAULT 1,
              max_val INTEGER DEFAULT 10,
              color_hex INTEGER DEFAULT 4280391411,
              is_positive INTEGER DEFAULT 1
            );
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS signal_log (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              signal_id INTEGER NOT NULL,
              value INTEGER NOT NULL,
              created_at INTEGER NOT NULL,
              note TEXT,
              FOREIGN KEY(signal_id) REFERENCES signal_def(id) ON DELETE CASCADE
            );
          ''');
        }
      },
    );

    return _db!;
  }

  // ---------------------------------------------------------------------------
  // SIGNALS (Custom Trackers)
  // ---------------------------------------------------------------------------

  static Future<int> createSignal(String name, bool isPositive) async {
    final db = await getDb();
    final color = isPositive ? 0xFF00E676 : 0xFFFF5252; // Green vs Red
    return db.insert('signal_def', {
      'name': name,
      'is_positive': isPositive ? 1 : 0,
      'color_hex': color,
    });
  }

  static Future<List<Map<String, dynamic>>> getSignals() async {
    final db = await getDb();
    return db.query('signal_def');
  }

  // Get days that have logs for this signal, ordered by date DESC
  static Future<List<DateTime>> getSignalDays(int signalId) async {
    final db = await getDb();
    final res = await db.rawQuery('''
      SELECT DISTINCT created_at FROM signal_log 
      WHERE signal_id = ? 
      ORDER BY created_at DESC
    ''', [signalId]);
    
    final Set<String> uniqueDays = {};
    for (var row in res) {
      final dt = DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int);
      uniqueDays.add(DateFormat('yyyy-MM-dd').format(dt));
    }
    
    final List<DateTime> days = uniqueDays.map((d) => DateTime.parse(d)).toList();
    
    // Ensure Today is present if empty? Or just return list.
    // If user just created it, list is empty. We should probably force Today if empty or always show Today at top.
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (!uniqueDays.contains(todayStr)) {
      days.insert(0, DateTime.now());
    }
    
    return days;
  }

  static Future<void> logSignal(int signalId, int value, String? note, DateTime date) async {
    final db = await getDb();
    await db.insert('signal_log', {
      'signal_id': signalId,
      'value': value,
      'created_at': date.millisecondsSinceEpoch,
      'note': note,
    });
  }

  static Future<List<Map<String, dynamic>>> getSignalLogsForDay(int signalId, DateTime date) async {
    final db = await getDb();
    final start = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59).millisecondsSinceEpoch;
    
    return db.query(
      'signal_log', 
      where: 'signal_id = ? AND created_at BETWEEN ? AND ?', 
      whereArgs: [signalId, start, end],
      orderBy: 'created_at ASC'
    );
  }

  // ---------------------------------------------------------------------------
  // WRITE: Save a snapshot
  // ---------------------------------------------------------------------------

  /// Saves a snapshot to SQLite.
  static Future<void> insertSnapshot({
    required String title,
    required int intensity,
    String? note,
    String? timestamp, // Optional: ISO8601 formatted string
  }) async {
    final db = await getDb();

    final cleanTitle = title.trim();
    final cleanNote = (note ?? '').trim();

    await db.insert(
      'problem',
      {'title': cleanTitle},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    final rows = await db.query(
      'problem',
      columns: ['id'],
      where: 'title = ?',
      whereArgs: [cleanTitle],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw Exception('Failed to find problem id for title="$cleanTitle"');
    }

    final problemId = rows.first['id'] as int;

    // Use provided timestamp or 'now'
    final int createdMs;
    if (timestamp != null) {
      createdMs = DateTime.parse(timestamp).millisecondsSinceEpoch;
    } else {
      createdMs = DateTime.now().millisecondsSinceEpoch;
    }

    await db.insert('snapshot', {
      'problem_id': problemId,
      'created_at': createdMs,
      'intensity': intensity,
      'note': cleanNote.isNotEmpty ? cleanNote : null,
    });
  }

  /// Updates an existing snapshot.
  static Future<void> updateSnapshot({
    required int id,
    required String title,
    required int intensity,
    String? note,
    required String timestamp,
  }) async {
    final db = await getDb();
    final cleanTitle = title.trim();
    final cleanNote = (note ?? '').trim();

    // Ensure title exists
    await db.insert(
      'problem',
      {'title': cleanTitle},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    final rows = await db.query(
      'problem',
      columns: ['id'],
      where: 'title = ?',
      whereArgs: [cleanTitle],
      limit: 1,
    );

    if (rows.isEmpty) throw Exception('Problem not found');
    final problemId = rows.first['id'] as int;

    final createdMs = DateTime.parse(timestamp).millisecondsSinceEpoch;

    await db.update(
      'snapshot',
      {
        'problem_id': problemId,
        'created_at': createdMs,
        'intensity': intensity,
        'note': cleanNote.isNotEmpty ? cleanNote : null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete a snapshot by ID
  static Future<void> deleteSnapshot(int id) async {
    final db = await getDb();
    await db.delete('snapshot', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // READ: Latest snapshots for home screen list
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, Object?>>> latestSnapshots({
    int limit = 20,
  }) async {
    final db = await getDb();

    return db.rawQuery('''
      SELECT
        snapshot.id AS snapshot_id,
        snapshot.problem_id AS problem_id,
        problem.title AS title,
        snapshot.intensity AS intensity,
        snapshot.note AS note,
        snapshot.created_at AS created_at
      FROM snapshot
      JOIN problem ON problem.id = snapshot.problem_id
      ORDER BY snapshot.created_at DESC
      LIMIT ?
    ''', [limit]);
  }

  /// Fetch snapshots for a specific "Day" (06:00 to 06:00 next day)
  static Future<List<MoodSnapshot>> getSnapshotsForDay(DateTime date) async {
    final db = await getDb();
    
    // Day starts at 06:00 of the given date
    final start = DateTime(date.year, date.month, date.day, 6).millisecondsSinceEpoch;
    // Ends at 06:00 of the next day
    final end = DateTime(date.year, date.month, date.day, 6).add(const Duration(days: 1)).millisecondsSinceEpoch;

    final rows = await db.rawQuery('''
      SELECT
        snapshot.id,
        problem.title,
        snapshot.intensity,
        snapshot.note,
        snapshot.created_at
      FROM snapshot
      JOIN problem ON problem.id = snapshot.problem_id
      WHERE snapshot.created_at >= ? AND snapshot.created_at < ?
      ORDER BY snapshot.created_at ASC
    ''', [start, end]);

    return rows.map((row) {
      final ms = row['created_at'] as int;
      return MoodSnapshot(
        id: row['id'] as int,
        title: row['title'] as String,
        intensity: row['intensity'] as int,
        note: row['note'] as String?,
        timestamp: DateTime.fromMillisecondsSinceEpoch(ms).toIso8601String(),
      );
    }).toList();
  }

  /// Get all unique Dates that have data (for the list builder)
  /// We shift time by -6 hours so that 00:00-05:59 belongs to the previous day.
  static Future<List<DateTime>> getDaysWithData() async {
    final db = await getDb();
    // 6 hours = 21600 seconds.
    // We subtract this from unix epoch (seconds) to shift the day boundary.
    final rows = await db.rawQuery('''
      SELECT DISTINCT
        date((created_at / 1000) - 21600, 'unixepoch', 'localtime') as day_str
      FROM snapshot
      ORDER BY day_str DESC
    ''');
    
    return rows.map((r) => DateTime.parse(r['day_str'] as String)).toList();
  }

  // ---------------------------------------------------------------------------
  // READ: Problem title reuse (autocomplete suggestions)
  // ---------------------------------------------------------------------------

  static Future<List<String>> allProblemTitles() async {
    final db = await getDb();

    final rows = await db.query(
      'problem',
      columns: ['title'],
      orderBy: 'title COLLATE NOCASE ASC', // case-insensitive sorting
    );

    return rows
        .map((r) => (r['title'] as String?) ?? '')
        .where((t) => t.isNotEmpty)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // ANALYTICS: Count + time-of-day distribution
  // ---------------------------------------------------------------------------

  static Future<Map<String, Object?>> problemStats(int problemId) async {
    final db = await getDb();

    // Total number of snapshots for this problem
    final total = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM snapshot WHERE problem_id = ?',
            [problemId],
          ),
        ) ??
        0;

    // Count by hour (0..23)
    final byHour = await db.rawQuery('''
      SELECT
        CAST(strftime('%H', created_at / 1000, 'unixepoch') AS INTEGER) AS hour,
        COUNT(*) AS count
      FROM snapshot
      WHERE problem_id = ?
      GROUP BY hour
      ORDER BY hour
    ''', [problemId]);

    int morning = 0;
    int afternoon = 0;
    int evening = 0;
    int night = 0;

    for (final row in byHour) {
      final hour = row['hour'] as int;
      final countAny = row['count'];
      final count = (countAny is int) ? countAny : (countAny as num).toInt();

      if (hour >= 6 && hour <= 11) {
        morning += count;
      } else if (hour >= 12 && hour <= 17) {
        afternoon += count;
      } else if (hour >= 18 && hour <= 21) {
        evening += count;
      } else {
        night += count;
      }
    }

    return {
      'total': total,
      'morning': morning,
      'afternoon': afternoon,
      'evening': evening,
      'night': night,
    };
  }

  // ---------------------------------------------------------------------------
  // SLEEP LOGS
  // ---------------------------------------------------------------------------

  static Future<void> insertSleep({
    required int startTime,
    required int endTime,
    int? quality,
  }) async {
    final db = await getDb();
    await db.insert('sleep_log', {
      'start_time': startTime,
      'end_time': endTime,
      'quality': quality,
    });
  }

  static Future<List<Map<String, Object?>>> latestSleepLogs({int limit = 7}) async {
    final db = await getDb();
    return db.query(
      'sleep_log',
      orderBy: 'end_time DESC',
      limit: limit,
    );
  }

  // ---------------------------------------------------------------------------
  // ADVANCED ANALYTICS
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, Object?>>> getDailyMoods({int limit = 7}) async {
    final db = await getDb();
    
    // SQLite's 'date' function returns YYYY-MM-DD
    return db.rawQuery('''
      SELECT
        date(created_at / 1000, 'unixepoch', 'localtime') as day,
        AVG(intensity) as avg_mood
      FROM snapshot
      GROUP BY day
      ORDER BY day DESC
      LIMIT ?
    ''', [limit]);
  }

  static Future<Map<int, double>> getAverageDayStats() async {
    final db = await getDb();

    // 1. Get all snapshots
    final snapshots = await db.query('snapshot', orderBy: 'created_at ASC');
    
    // 2. Get all sleep logs
    final sleepLogs = await db.query('sleep_log', orderBy: 'end_time ASC');

    if (snapshots.isEmpty || sleepLogs.isEmpty) {
      return {};
    }

    final Map<int, List<int>> buckets = {};

    for (final snap in snapshots) {
      final snapTime = snap['created_at'] as int;
      final intensity = snap['intensity'] as int;

      Map<String, Object?>? sleep;
      for (final log in sleepLogs.reversed) {
        final wakeTime = log['end_time'] as int;
        if (wakeTime < snapTime) {
          if ((snapTime - wakeTime) < 24 * 3600 * 1000) {
            sleep = log;
          }
          break;
        }
      }

      if (sleep != null) {
        final wakeTime = sleep['end_time'] as int;
        final diffMs = snapTime - wakeTime;
        final hoursAwake = (diffMs / (1000 * 3600)).floor();

        if (hoursAwake >= 0 && hoursAwake < 24) {
          buckets.putIfAbsent(hoursAwake, () => []).add(intensity);
        }
      }
    }

    final Map<int, double> results = {};
    buckets.forEach((hour, intensities) {
      final avg = intensities.reduce((a, b) => a + b) / intensities.length;
      results[hour] = avg;
    });

    return results;
  }
  // ---------------------------------------------------------------------------
  // SCHEDULE OVERRIDES
  // ---------------------------------------------------------------------------
  
  static Future<void> setDaySchedule(String dateStr, int wH, int wM, int sH, int sM) async {
    final db = await getDb();
    await db.insert(
      'day_schedule',
      {
        'date': dateStr,
        'wake_h': wH,
        'wake_m': wM,
        'sleep_h': sH,
        'sleep_m': sM,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Map<String, int>?> getDaySchedule(String dateStr) async {
    final db = await getDb();
    final rows = await db.query(
      'day_schedule',
      where: 'date = ?',
      whereArgs: [dateStr],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return {
      'wake_h': r['wake_h'] as int,
      'wake_m': r['wake_m'] as int,
      'sleep_h': r['sleep_h'] as int,
      'sleep_m': r['sleep_m'] as int,
    };
  }

  // ---------------------------------------------------------------------------
  // OBSERVATIONS
  // ---------------------------------------------------------------------------

  static Future<void> insertObservation(String content) async {
    final db = await getDb();
    await db.insert('observation', {
      'content': content,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<void> updateObservation(int id, String content) async {
    final db = await getDb();
    await db.update(
      'observation',
      {'content': content},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<List<Map<String, Object?>>> getObservations() async {
    final db = await getDb();
    return db.query(
      'observation',
      where: 'deleted_at IS NULL',
      orderBy: 'created_at DESC',
    );
  }

  static Future<void> deleteObservation(int id) async { // Soft Delete
    final db = await getDb();
    await db.update(
      'observation', 
      {'deleted_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id]
    );
  }

  static Future<void> restoreObservation(int id) async {
    final db = await getDb();
    await db.update(
      'observation', 
      {'deleted_at': null},
      where: 'id = ?',
      whereArgs: [id]
    );
  }

  static Future<void> hardDeleteObservation(int id) async {
    final db = await getDb();
    await db.delete('observation', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // PROBLEM - SOLUTION (STRATEGIES)
  // ---------------------------------------------------------------------------

  static Future<void> insertProblemSolution(String problem, String solution) async {
    final db = await getDb();
    await db.insert('problem_solution', {
      'problem': problem,
      'solution': solution,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<void> updateProblemSolution(int id, String problem, String solution) async {
    final db = await getDb();
    await db.update(
      'problem_solution',
      {'problem': problem, 'solution': solution},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<List<Map<String, Object?>>> getProblemSolutions() async {
    final db = await getDb();
    return db.query(
      'problem_solution',
      where: 'deleted_at IS NULL',
      orderBy: 'created_at DESC'
    );
  }

  static Future<void> voteProblemSolution(int id, bool isUp) async {
    final db = await getDb();
    if (isUp) {
      await db.rawUpdate('UPDATE problem_solution SET thumbs_up = thumbs_up + 1 WHERE id = ?', [id]);
    } else {
      await db.rawUpdate('UPDATE problem_solution SET thumbs_down = thumbs_down + 1 WHERE id = ?', [id]);
    }
  }

  static Future<void> deleteProblemSolution(int id) async { // Soft delete
    final db = await getDb();
    await db.update(
      'problem_solution',
      {'deleted_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> restoreProblemSolution(int id) async {
    final db = await getDb();
    await db.update(
      'problem_solution', 
      {'deleted_at': null},
      where: 'id = ?',
      whereArgs: [id]
    );
  }

  static Future<void> hardDeleteProblemSolution(int id) async {
    final db = await getDb();
    await db.delete('problem_solution', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // TRASH MANAGEMENT
  // ---------------------------------------------------------------------------

  static Future<Map<String, List<Map<String, Object?>>>> getTrash() async {
    final db = await getDb();
    final obs = await db.query('observation', where: 'deleted_at IS NOT NULL', orderBy: 'deleted_at DESC');
    final strats = await db.query('problem_solution', where: 'deleted_at IS NOT NULL', orderBy: 'deleted_at DESC');
    return {
      'observations': obs,
      'strategies': strats,
    };
  }

  static Future<void> cleanupTrash() async {
    final db = await getDb();
    final cutoff = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    
    await db.delete('observation', where: 'deleted_at IS NOT NULL AND deleted_at < ?', whereArgs: [cutoff]);
    await db.delete('problem_solution', where: 'deleted_at IS NOT NULL AND deleted_at < ?', whereArgs: [cutoff]);
    await db.delete('parked_thought', where: 'reviewed_at IS NOT NULL AND reviewed_at < ?', whereArgs: [cutoff]);
  }

  // ---------------------------------------------------------------------------
  // AMPLIFICATION WINDOW LOGIC
  // ---------------------------------------------------------------------------

  /// Returns {startOffsetHours, endOffsetHours} relative to SLEEP TIME.
  /// e.g. {-2.0, 0.0} means "2 hours before sleep until sleep".
  /// Returns null if no clear pattern found.
  static Future<Map<String, double>?> analyzeAmplificationWindow() async {
    final db = await getDb();
    
    // Get last 30 days of data
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30)).millisecondsSinceEpoch;
    
    final snaps = await db.query('snapshot', where: 'created_at > ?', whereArgs: [start]);
    
    if (snaps.length < 10) return null; // Not enough data
    
    // Hardcoded Simulation for "Self-Discovery" if logic is complex:
    return {'start': -2.5, 'end': -0.5}; // e.g. 2.5 hours before sleep to 0.5 hours before sleep
  }

  // ---------------------------------------------------------------------------
  // PARKED THOUGHTS
  // ---------------------------------------------------------------------------

  static Future<void> parkThought(String content, int intensity) async {
    final db = await getDb();
    await db.insert('parked_thought', {
      'content': content,
      'original_intensity': intensity,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<List<Map<String, dynamic>>> getPendingParkedThoughts() async {
    final db = await getDb();
    return db.query('parked_thought', where: 'reviewed_at IS NULL', orderBy: 'created_at ASC');
  }

  static Future<void> resolveParkedThought(int id, String resolution) async {
    final db = await getDb();
    await db.update('parked_thought', {
      'reviewed_at': DateTime.now().millisecondsSinceEpoch,
      'resolution': resolution,
    }, where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> seedDebugData() async {
    final db = await getDb();
    
    // Clear existing
    await db.delete('snapshot');
    await db.delete('day_schedule');
    await db.delete('problem_solution');
    await db.delete('observation');
    await db.delete('signal_def');
    await db.delete('signal_log');

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Day 0: Normal "Good" Day (06:00 - 23:00) - curve up then stable
    await _insertSnap(db, today, 7, 0, 0);
    await _insertSnap(db, today, 10, 0, 2);
    await _insertSnap(db, today, 14, 0, 4);
    await _insertSnap(db, today, 18, 0, 3);
    await _insertSnap(db, today, 22, 0, 1);

    // Day -1: "Stressful" Day (Zig Zag)
    final d1 = today.subtract(const Duration(days: 1));
    await _insertSnap(db, d1, 8, 0, -1);
    await _insertSnap(db, d1, 11, 30, -3);
    await _insertSnap(db, d1, 13, 0, 2); // Recovery lunch
    await _insertSnap(db, d1, 16, 0, -4); // Crash
    await _insertSnap(db, d1, 20, 0, -2);

    // Day -2: "Early Bird" Test (Data OUTSIDE standard wake time)
    final d2 = today.subtract(const Duration(days: 2));
    await _insertSnap(db, d2, 4, 30, 3); // Early workout?
    await _insertSnap(db, d2, 7, 0, 5); 
    await _insertSnap(db, d2, 12, 0, 2);
    await _insertSnap(db, d2, 20, 0, 0);

    // Day -3: "Override" Day
    // User sets schedule: Wake 10:00, Sleep 02:00
    final d3 = today.subtract(const Duration(days: 3));
    
    await db.insert('day_schedule', {
      'date': DateFormat('yyyy-MM-dd').format(d3),
      'wake_h': 10, 'wake_m': 0,
      'sleep_h': 23, 'sleep_m': 0,
    });
    
    await _insertSnap(db, d3, 9, 0, -2); // Woke up early, grumpy (Outside schedule)
    await _insertSnap(db, d3, 11, 0, 1); // inside
    await _insertSnap(db, d3, 15, 0, 3);
    await _insertSnap(db, d3, 22, 0, 2);

    // Day -4: "Flat Line"
    final d4 = today.subtract(const Duration(days: 4));
    await _insertSnap(db, d4, 8, 0, 0);
    await _insertSnap(db, d4, 12, 0, 0);
    await _insertSnap(db, d4, 16, 0, 0);
    await _insertSnap(db, d4, 20, 0, 0);
    
    // Seed some insights
    await insertObservation('I feel better when I drink water.');
    await insertProblemSolution('Trouble sleeping', 'Read a book instead of phone');
    await voteProblemSolution(1, true); 
  }

  static Future<void> _insertSnap(Database db, DateTime date, int h, int m, int intensity) async {
    // Ensure we have a default problem
    await db.insert('problem', {'title': 'General'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final rows = await db.query('problem', where: 'title = ?', whereArgs: ['General']);
    final pid = rows.first['id'] as int;

    // Create timestamp
    final dt = DateTime(date.year, date.month, date.day, h, m);
    await db.insert('snapshot', {
      'problem_id': pid,
      'intensity': intensity,
      'created_at': dt.millisecondsSinceEpoch,
    });
  }
}

/// Data model for a single mood entry
class MoodSnapshot {
  final int id;
  final String title;
  final int intensity;
  final String? note;
  final String timestamp;

  MoodSnapshot({
    required this.id,
    required this.title,
    required this.intensity,
    this.note,
    required this.timestamp,
  });
}
