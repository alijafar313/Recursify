import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// AppDatabase is a small helper class that:
/// 1) Creates / opens a local SQLite database file on the device.
/// 2) Creates our tables the very first time the database is created.
/// 3) Provides functions we can call from the UI (main.dart) to read/write data.
///
/// SQLite stores data in "tables" (like spreadsheets).
/// - problem: unique problem titles (e.g., "job stress", "gf problems")
/// - snapshot: a single logged moment in time (problem + intensity + note + timestamp)
/// - recheck: later evaluation of a snapshot (not used yet, but schema is ready)
class AppDatabase {
  // We keep a single database connection open (singleton pattern).
  static Database? _db;

  /// Returns an open database connection.
  ///
  /// - If the database is already open, we return it immediately.
  /// - If not, we open (or create) the database file and return it.
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
      version: 2,
      onCreate: (db, version) async {
        // This runs ONLY ONCE: when the DB is first created.

        // TABLE: problem
        // Stores unique problem titles.
        await db.execute('''
          CREATE TABLE problem (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL UNIQUE
          );
        ''');

        // TABLE: snapshot
        // Stores each mood/problem entry.
        // created_at is stored as an INTEGER timestamp (milliseconds since epoch).
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
        // Later we’ll store the “Still / Less / Not” evaluation here.
        // CHECK(...) is how SQLite enforces allowed values (like an enum).
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
        // Stores sleep sessions (start and end times).
        await db.execute('''
          CREATE TABLE sleep_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            start_time INTEGER NOT NULL,
            end_time INTEGER NOT NULL,
            quality INTEGER
          );
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Version 2 adds the sleep_log table
          await db.execute('''
            CREATE TABLE sleep_log (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              start_time INTEGER NOT NULL,
              end_time INTEGER NOT NULL,
              quality INTEGER
            );
          ''');
        }
      },
    );

    return _db!;
  }

  // ---------------------------------------------------------------------------
  // WRITE: Save a snapshot
  // ---------------------------------------------------------------------------

  /// Saves a snapshot to SQLite.
  ///
  /// What it does:
  /// 1) Ensures the problem title exists in the `problem` table (no duplicates).
  /// 2) Finds the problem's ID.
  /// 3) Inserts the snapshot into `snapshot`.
  static Future<void> insertSnapshot({
    required String title,
    required int intensity,
    String? note,
  }) async {
    final db = await getDb();

    final cleanTitle = title.trim();
    final cleanNote = (note ?? '').trim();

    // 1) Insert the problem title if it doesn't exist.
    // conflictAlgorithm.ignore means: if "title" already exists, do nothing.
    await db.insert(
      'problem',
      {'title': cleanTitle},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    // 2) Look up the problem ID using the title.
    final rows = await db.query(
      'problem',
      columns: ['id'],
      where: 'title = ?',
      whereArgs: [cleanTitle],
      limit: 1,
    );

    // In normal operation this will always exist, but we guard anyway.
    if (rows.isEmpty) {
      throw Exception('Failed to find problem id for title="$cleanTitle"');
    }

    final problemId = rows.first['id'] as int;

    // 3) Insert the snapshot row.
    // We store time as milliseconds since epoch for easy sorting and uniqueness.
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    await db.insert('snapshot', {
      'problem_id': problemId,
      'created_at': nowMs,
      'intensity': intensity,
      // Store NULL instead of empty string to keep the DB clean.
      'note': cleanNote.isNotEmpty ? cleanNote : null,
    });
  }

  // ---------------------------------------------------------------------------
  // READ: Latest snapshots for home screen list
  // ---------------------------------------------------------------------------

  /// Returns the most recent snapshots, newest first.
  ///
  /// We JOIN snapshot with problem so we can show the title on the home screen.
  /// We also return problem_id because analytics needs it.
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

  // ---------------------------------------------------------------------------
  // READ: Problem title reuse (autocomplete suggestions)
  // ---------------------------------------------------------------------------

  /// Returns all problem titles (alphabetical) so the UI can suggest them.
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

  /// Returns basic statistics for one specific problem.
  ///
  /// Output example:
  /// {
  ///   'total': 12,
  ///   'morning': 2,
  ///   'afternoon': 5,
  ///   'evening': 3,
  ///   'night': 2,
  /// }
  ///
  /// NOTE:
  /// - created_at is stored in milliseconds, but SQLite strftime expects seconds,
  ///   so we use (created_at / 1000).
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

    // Bucket hours into 4 ranges:
    // Morning:   06–11
    // Afternoon: 12–17
    // Evening:   18–21
    // Night:     22–05
    int morning = 0;
    int afternoon = 0;
    int evening = 0;
    int night = 0;

    for (final row in byHour) {
      final hour = row['hour'] as int;
      final countAny = row['count'];

      // SQLite returns ints here, but we cast safely.
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

  /// Returns daily average mood for the last [limit] days.
  /// Output: [{'day': '2025-01-01', 'avg_mood': 7.2}, ...]
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

  /// Calculates "Average Day" stats by correlating snapshots with sleep logs.
  /// Returns a map where key=HourAwake (0..18) and value=AverageIntensity.
  static Future<Map<int, double>> getAverageDayStats() async {
    final db = await getDb();

    // 1. Get all snapshots
    final snapshots = await db.query('snapshot', orderBy: 'created_at ASC');
    
    // 2. Get all sleep logs
    final sleepLogs = await db.query('sleep_log', orderBy: 'end_time ASC');

    if (snapshots.isEmpty || sleepLogs.isEmpty) {
      return {};
    }

    // Bucket accumulators
    final Map<int, List<int>> buckets = {};

    // 3. Simple correlation algorithm
    // Optimized: Since both lists are sorted, we can march through them.
    // But for a prototype with <10k records, a simple search is fine.
    
    for (final snap in snapshots) {
      final snapTime = snap['created_at'] as int;
      final intensity = snap['intensity'] as int;

      // Find the latest sleep log that ends BEFORE this snapshot
      Map<String, Object?>? sleep;
      // iterating backwards is faster to find the recent one
      for (final log in sleepLogs.reversed) {
        final wakeTime = log['end_time'] as int;
        if (wakeTime < snapTime) {
          // Found the sleep session immediately preceding this mood
          // Check if it's "too far" (e.g., > 24 hours ago). If so, maybe they forgot to log sleep.
          if ((snapTime - wakeTime) < 24 * 3600 * 1000) {
            sleep = log;
          }
          break; // Since we look in reverse, the first one we find is the closest
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

    // 4. Calculate averages
    final Map<int, double> results = {};
    buckets.forEach((hour, intensities) {
      final avg = intensities.reduce((a, b) => a + b) / intensities.length;
      results[hour] = avg;
    });

    return results;
  }
}
