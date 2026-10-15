import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../domain/models.dart';
import '../domain/time_engine.dart';
import 'seed_parser.dart';

class TempoDatabase {
  static final TempoDatabase instance = TempoDatabase._internal();
  final String _customDbName;
  TempoDatabase._internal() : _customDbName = 'tempo_os_v1.db';
  TempoDatabase.custom({String dbName = 'tempo_os_v1.db'}) : _customDbName = dbName;

  Database? _db;
  Future<void>? _seedingFuture;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _customDbName);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS active_session (
              id TEXT PRIMARY KEY DEFAULT 'current',
              category_id TEXT NOT NULL,
              task_id TEXT,
              state TEXT NOT NULL,
              session_start_time TEXT NOT NULL,
              last_segment_start_time TEXT NOT NULL,
              accumulated_work_seconds INTEGER NOT NULL DEFAULT 0,
              accumulated_break_seconds INTEGER NOT NULL DEFAULT 0,
              planned_break_minutes INTEGER NOT NULL DEFAULT 5,
              focus_cycle TEXT NOT NULL DEFAULT 'continuous',
              note TEXT,
              week_period_id TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
            );
          ''');
        }

        if (oldVersion < 3) {
          // 1. Add columns to tasks safely
          final taskCols = [
            'ALTER TABLE tasks ADD COLUMN planned_date TEXT;',
            'ALTER TABLE tasks ADD COLUMN due_date TEXT;',
            'ALTER TABLE tasks ADD COLUMN due_time TEXT;',
            'ALTER TABLE tasks ADD COLUMN planned_time_window TEXT;',
            'ALTER TABLE tasks ADD COLUMN parent_task_id TEXT;',
            'ALTER TABLE tasks ADD COLUMN course_id TEXT;',
            'ALTER TABLE tasks ADD COLUMN task_type TEXT;',
            'ALTER TABLE tasks ADD COLUMN notes TEXT;',
            'ALTER TABLE tasks ADD COLUMN completed_at TEXT;',
            'ALTER TABLE tasks ADD COLUMN deferred_count INTEGER NOT NULL DEFAULT 0;',
            'ALTER TABLE tasks ADD COLUMN source TEXT;',
          ];
          for (final sql in taskCols) {
            try { await db.execute(sql); } catch (_) {}
          }

          // 2. Add columns to calendar_events safely
          final calCols = [
            'ALTER TABLE calendar_events ADD COLUMN specific_date TEXT;',
            'ALTER TABLE calendar_events ADD COLUMN is_tentative INTEGER NOT NULL DEFAULT 0;',
            'ALTER TABLE calendar_events ADD COLUMN is_completed INTEGER NOT NULL DEFAULT 0;',
            'ALTER TABLE calendar_events ADD COLUMN is_rest INTEGER NOT NULL DEFAULT 0;',
            'ALTER TABLE calendar_events ADD COLUMN recurrence TEXT NOT NULL DEFAULT \'weekly\';',
            'ALTER TABLE calendar_events ADD COLUMN location TEXT;',
            'ALTER TABLE calendar_events ADD COLUMN notes TEXT;',
          ];
          for (final sql in calCols) {
            try { await db.execute(sql); } catch (_) {}
          }

          // 3. Add column to settings
          try {
            await db.execute("ALTER TABLE settings ADD COLUMN current_term_mode TEXT NOT NULL DEFAULT 'modeAMidtermPrep';");
          } catch (_) {}

          // 4. Create subtasks table if not exists
          await db.execute('''
            CREATE TABLE IF NOT EXISTS subtasks (
              id TEXT PRIMARY KEY,
              task_id TEXT NOT NULL,
              title TEXT NOT NULL,
              is_completed INTEGER NOT NULL DEFAULT 0,
              FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
            );
          ''');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_subtasks_task ON subtasks(task_id);');

          // 5. Create course_topics table if not exists
          await db.execute('''
            CREATE TABLE IF NOT EXISTS course_topics (
              id TEXT PRIMARY KEY,
              course_id TEXT NOT NULL,
              week_number INTEGER NOT NULL,
              title TEXT NOT NULL,
              description TEXT,
              mastery_level TEXT NOT NULL DEFAULT 'notStarted',
              questions_attempted INTEGER NOT NULL DEFAULT 0,
              questions_correct INTEGER NOT NULL DEFAULT 0,
              notes TEXT,
              last_practiced_at TEXT,
              updated_at TEXT
            );
          ''');
          await db.execute('CREATE INDEX IF NOT EXISTS idx_course_topics_course ON course_topics(course_id);');
          try { await db.execute('ALTER TABLE course_topics ADD COLUMN updated_at TEXT;'); } catch (_) {}

          // 6. Create leisure_items table if not exists
          await db.execute('''
            CREATE TABLE IF NOT EXISTS leisure_items (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              type TEXT NOT NULL DEFAULT 'game',
              status TEXT NOT NULL DEFAULT 'backlog',
              note TEXT,
              rating INTEGER
            );
          ''');

          // 7. Non-destructive migration of cat-c-siber to cat-c and cat-siber
          try {
            final oldCat = await db.query('categories', where: 'id = ?', whereArgs: ['cat-c-siber']);
            if (oldCat.isNotEmpty) {
              final now = DateTime.now().toIso8601String();
              await db.insert('categories', {
                'id': 'cat-c',
                'name': 'C Programming',
                'description': 'C Programming & Interdisciplinary Project',
                'icon': 'code',
                'color_value': 4280656875,
                'weekly_target_minutes': 120,
                'policy': 'flexible',
                'is_archived': 0,
                'priority_order': 3,
                'created_at': now,
                'updated_at': now,
              }, conflictAlgorithm: ConflictAlgorithm.ignore);

              await db.insert('categories', {
                'id': 'cat-siber',
                'name': 'Cybersecurity',
                'description': 'CENG445 Cybersecurity syllabus & labs',
                'icon': 'shield',
                'color_value': 4288679541,
                'weekly_target_minutes': 60,
                'policy': 'flexible',
                'is_archived': 0,
                'priority_order': 4,
                'created_at': now,
                'updated_at': now,
              }, conflictAlgorithm: ConflictAlgorithm.ignore);

              // Archive cat-c-siber to preserve session history
              await db.update('categories', {'is_archived': 1}, where: 'id = ?', whereArgs: ['cat-c-siber']);

              // Reassign tasks if any
              await db.rawUpdate("UPDATE tasks SET category_id = 'cat-siber' WHERE category_id = 'cat-c-siber' AND (LOWER(title) LIKE '%siber%' OR LOWER(title) LIKE '%cyber%');");
              await db.rawUpdate("UPDATE tasks SET category_id = 'cat-c' WHERE category_id = 'cat-c-siber';");
            }
          } catch (_) {}
        }
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        icon TEXT NOT NULL DEFAULT 'circle',
        color_value INTEGER NOT NULL DEFAULT 4280656875,
        weekly_target_minutes INTEGER NOT NULL DEFAULT 60,
        policy TEXT NOT NULL DEFAULT 'flexible',
        is_archived INTEGER NOT NULL DEFAULT 0,
        priority_order INTEGER NOT NULL DEFAULT 0,
        scheduled_days TEXT,
        deadline_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    await db.execute('CREATE INDEX idx_categories_archived ON categories(is_archived);');

    await db.execute('''
      CREATE TABLE weekly_periods (
        id TEXT PRIMARY KEY,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE weekly_budgets (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        week_period_id TEXT NOT NULL,
        allocated_minutes INTEGER NOT NULL,
        transferred_in_minutes INTEGER NOT NULL DEFAULT 0,
        transferred_out_minutes INTEGER NOT NULL DEFAULT 0,
        is_completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE UNIQUE INDEX idx_category_week ON weekly_budgets(category_id, week_period_id);');

    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        estimated_minutes INTEGER NOT NULL DEFAULT 30,
        actual_tracked_minutes INTEGER NOT NULL DEFAULT 0,
        priority TEXT NOT NULL DEFAULT 'medium',
        status TEXT NOT NULL DEFAULT 'todo',
        deadline TEXT,
        week_period_id TEXT NOT NULL,
        recurrence TEXT NOT NULL DEFAULT 'weekly',
        planned_date TEXT,
        due_date TEXT,
        due_time TEXT,
        planned_time_window TEXT,
        parent_task_id TEXT,
        course_id TEXT,
        task_type TEXT,
        notes TEXT,
        completed_at TEXT,
        deferred_count INTEGER NOT NULL DEFAULT 0,
        source TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX idx_tasks_category ON tasks(category_id);');
    await db.execute('CREATE INDEX idx_tasks_week ON tasks(week_period_id);');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS subtasks (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        title TEXT NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX idx_subtasks_task ON subtasks(task_id);');

    await db.execute('''
      CREATE TABLE task_occurrences (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        week_period_id TEXT NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        completed_at TEXT,
        FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE sessions (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        task_id TEXT,
        start_time TEXT NOT NULL,
        end_time TEXT,
        state TEXT NOT NULL DEFAULT 'completed',
        active_seconds INTEGER NOT NULL DEFAULT 0,
        pause_seconds INTEGER NOT NULL DEFAULT 0,
        break_seconds INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        week_period_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX idx_sessions_category_week ON sessions(category_id, week_period_id);');

    await db.execute('''
      CREATE TABLE session_segments (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'work',
        start_time TEXT NOT NULL,
        end_time TEXT,
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE break_segments (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        planned_minutes INTEGER NOT NULL DEFAULT 5,
        actual_duration_seconds INTEGER NOT NULL DEFAULT 0,
        label TEXT,
        FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE pool_transactions (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        source_category_id TEXT,
        target_category_id TEXT,
        minutes INTEGER NOT NULL,
        week_period_id TEXT NOT NULL,
        note TEXT,
        timestamp TEXT NOT NULL,
        is_undone INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (source_category_id) REFERENCES categories (id) ON DELETE SET NULL,
        FOREIGN KEY (target_category_id) REFERENCES categories (id) ON DELETE SET NULL
      );
    ''');
    await db.execute('CREATE INDEX idx_pool_transactions_week ON pool_transactions(week_period_id);');

    await db.execute('''
      CREATE TABLE calendar_events (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        day_of_week INTEGER NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'study_block',
        category_id TEXT,
        specific_date TEXT,
        is_tentative INTEGER NOT NULL DEFAULT 0,
        is_completed INTEGER NOT NULL DEFAULT 0,
        is_rest INTEGER NOT NULL DEFAULT 0,
        recurrence TEXT NOT NULL DEFAULT 'weekly',
        location TEXT,
        notes TEXT,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE academic_milestones (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE course_topics (
        id TEXT PRIMARY KEY,
        course_id TEXT NOT NULL,
        week_number INTEGER NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        mastery_level TEXT NOT NULL DEFAULT 'notStarted',
        questions_attempted INTEGER NOT NULL DEFAULT 0,
        questions_correct INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        last_practiced_at TEXT,
        updated_at TEXT
      );
    ''');
    await db.execute('CREATE INDEX idx_course_topics_course ON course_topics(course_id);');

    await db.execute('''
      CREATE TABLE leisure_items (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'game',
        status TEXT NOT NULL DEFAULT 'backlog',
        note TEXT,
        rating INTEGER
      );
    ''');

    await db.execute('''
      CREATE TABLE schedule_exceptions (
        id TEXT PRIMARY KEY,
        event_date TEXT NOT NULL,
        reason TEXT,
        action TEXT NOT NULL DEFAULT 'skip',
        created_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE settings (
        id TEXT PRIMARY KEY DEFAULT 'app_settings',
        theme TEXT NOT NULL DEFAULT 'dark',
        sound_enabled INTEGER NOT NULL DEFAULT 1,
        vibration_enabled INTEGER NOT NULL DEFAULT 1,
        notifications_enabled INTEGER NOT NULL DEFAULT 1,
        smart_warning_80 INTEGER NOT NULL DEFAULT 1,
        smart_warning_95 INTEGER NOT NULL DEFAULT 1,
        default_break_minutes INTEGER NOT NULL DEFAULT 5,
        default_focus_cycle TEXT NOT NULL DEFAULT 'continuous',
        week_start_day INTEGER NOT NULL DEFAULT 1,
        auto_week_reset INTEGER NOT NULL DEFAULT 1,
        language TEXT NOT NULL DEFAULT 'tr',
        seed_version INTEGER NOT NULL DEFAULT 0,
        current_term_mode TEXT NOT NULL DEFAULT 'modeAMidtermPrep'
      );
    ''');

    await db.insert('settings', {
      'id': 'app_settings',
      'theme': 'dark',
      'sound_enabled': 1,
      'vibration_enabled': 1,
      'notifications_enabled': 1,
      'smart_warning_80': 1,
      'smart_warning_95': 1,
      'default_break_minutes': 5,
      'default_focus_cycle': 'continuous',
      'week_start_day': 1,
      'auto_week_reset': 1,
      'language': 'tr',
      'seed_version': 0,
      'current_term_mode': 'modeAMidtermPrep',
    });

    await db.execute('''
      CREATE TABLE IF NOT EXISTS active_session (
        id TEXT PRIMARY KEY DEFAULT 'current',
        category_id TEXT NOT NULL,
        task_id TEXT,
        state TEXT NOT NULL,
        session_start_time TEXT NOT NULL,
        last_segment_start_time TEXT NOT NULL,
        accumulated_work_seconds INTEGER NOT NULL DEFAULT 0,
        accumulated_break_seconds INTEGER NOT NULL DEFAULT 0,
        planned_break_minutes INTEGER NOT NULL DEFAULT 5,
        focus_cycle TEXT NOT NULL DEFAULT 'continuous',
        note TEXT,
        week_period_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
      );
    ''');
  }

  // --- SEED INITIALIZATION (Idempotent & Transaction-Safe) ---
  Future<void> initializeSeedDataIfEmpty() {
    if (_seedingFuture != null) return _seedingFuture!;
    _seedingFuture = _performInitializeSeedDataIfEmpty();
    return _seedingFuture!;
  }

  Future<void> _performInitializeSeedDataIfEmpty() async {
    final db = await database;
    final categoryCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM categories'),
    ) ?? 0;

    // Check if this installation suffered the previous seed loading crash:
    // Fingerprint of failed install:
    // 1. Exactly 1 category and it is 'cat-deep-work'
    // 2. AND 0 tasks AND 0 calendar_events
    // 3. AND settings table has seed_version == 0
    bool isFailedInstall = false;
    if (categoryCount == 1) {
      final cat = await db.query('categories', where: 'id = ?', whereArgs: ['cat-deep-work']);
      final taskCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM tasks')) ?? 0;
      final calCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM calendar_events')) ?? 0;
      final settings = await getSettings();
      if (cat.isNotEmpty && taskCount == 0 && calCount == 0 && settings.seedVersion == 0) {
        isFailedInstall = true;
      }
    }

    if (categoryCount > 0 && !isFailedInstall) {
      return; // Cleanly initialized, preserve existing user configuration
    }

    try {
      String jsonStr = '';
      try {
        jsonStr = await rootBundle.loadString('assets/seed.json');
      } catch (assetErr) {
        debugPrint('TEMPO: assets/seed.json not found in rootBundle ($assetErr), trying config/seeds/public.json');
        jsonStr = await rootBundle.loadString('config/seeds/public.json');
      }

      final Map<String, dynamic> data = jsonDecode(jsonStr);
      final parseResult = SeedParser.parse(data);
      if (!parseResult.isValid) {
        final errText = parseResult.validationErrors.join('; ');
        debugPrint('TEMPO SEED ERROR: Validation failed: $errText');
        throw StateError('Seed JSON validation failed: $errText');
      }

      // If recovering from a failed install where cat-deep-work had NO recorded sessions, clean up cat-deep-work
      if (isFailedInstall) {
        final sessionsOnDeepWork = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM sessions WHERE category_id = ?', ['cat-deep-work']),
        ) ?? 0;
        if (sessionsOnDeepWork == 0 && !parseResult.categories.any((c) => c.id == 'cat-deep-work')) {
          await db.delete('categories', where: 'id = ?', whereArgs: ['cat-deep-work']);
          debugPrint('TEMPO SEED RECOVERY: Cleaned up empty fallback "cat-deep-work" category.');
        }
      }

      await loadSeedResult(parseResult);
      debugPrint('TEMPO SEED SUCCESS: Loaded ${parseResult.categories.length} categories (${parseResult.totalCategoryMinutes} mins), '
          '${parseResult.tasks.length} tasks, ${parseResult.calendarEvents.length} calendar events, '
          '${parseResult.academicMilestones.length} academic milestones.');
    } catch (e, stack) {
      debugPrint('TEMPO CRITICAL SEED INITIALIZATION ERROR: $e\n$stack');
      rethrow;
    }
  }

  Future<void> loadSeedData(Map<String, dynamic> data) async {
    final result = SeedParser.parse(data);
    if (!result.isValid) {
      final err = result.validationErrors.join('; ');
      debugPrint('TEMPO SEED ERROR: Validation failed in loadSeedData: $err');
      throw ArgumentError('Seed data validation failed: $err');
    }
    await loadSeedResult(result);
  }

  Future<void> loadSeedResult(SeedParseResult result) async {
    final db = await database;
    final currentWeekId = FlutterTimeEngine.getWeekPeriod().id;
    final now = DateTime.now();

    await db.transaction((txn) async {
      // 1. Categories
      for (final cat in result.categories) {
        await txn.insert(
          'categories',
          cat.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 2. Tasks & Subtasks
      for (final task in result.tasks) {
        final taskToInsert = task.weekPeriodId.isEmpty
            ? task.copyWith(weekPeriodId: currentWeekId)
            : task;
        await txn.insert(
          'tasks',
          taskToInsert.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        for (final subtask in taskToInsert.subtasks) {
          final sMap = subtask.toMap();
          sMap['task_id'] = taskToInsert.id;
          await txn.insert(
            'subtasks',
            sMap,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // 3. Calendar Events
      for (final evt in result.calendarEvents) {
        await txn.insert(
          'calendar_events',
          evt.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 4. Academic Milestones
      for (final ms in result.academicMilestones) {
        await txn.insert(
          'academic_milestones',
          ms.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 5. Course Topics
      for (final topic in result.courseTopics) {
        await txn.insert(
          'course_topics',
          topic.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 6. Leisure Items
      for (final item in result.leisureItems) {
        await txn.insert(
          'leisure_items',
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 7. Ensure weekly_periods record exists
      final pRows = await txn.query('weekly_periods', where: 'id = ?', whereArgs: [currentWeekId]);
      if (pRows.isEmpty) {
        final weekInfo = FlutterTimeEngine.getWeekPeriod();
        await txn.insert('weekly_periods', {
          'id': currentWeekId,
          'start_date': weekInfo.start.toIso8601String(),
          'end_date': weekInfo.end.toIso8601String(),
          'created_at': now.toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      // 8. Ensure weekly_budgets for all active categories with their full weekly target minutes
      for (final cat in result.categories) {
        final bRows = await txn.query(
          'weekly_budgets',
          where: 'category_id = ? AND week_period_id = ?',
          whereArgs: [cat.id, currentWeekId],
        );
        if (bRows.isEmpty) {
          await txn.insert('weekly_budgets', {
            'id': '${cat.id}_$currentWeekId',
            'category_id': cat.id,
            'week_period_id': currentWeekId,
            'allocated_minutes': cat.weeklyTargetMinutes,
            'transferred_in_minutes': 0,
            'transferred_out_minutes': 0,
            'is_completed': 0,
            'created_at': now.toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      // 9. Update seed version in settings
      await txn.update(
        'settings',
        {'seed_version': result.version},
        where: 'id = ?',
        whereArgs: ['app_settings'],
      );
    });
  }

  /// Lossless repair and re-import of seed data for existing installations.
  /// Preserves all recorded user sessions, segments, breaks, and custom categories/tasks,
  /// while restoring missing profile categories, tasks, calendar events, and week budgets.
  Future<SeedRepairReport> repairSeedDataLossless({String? jsonStr}) async {
    final db = await database;
    String rawJson = jsonStr ?? '';
    if (rawJson.isEmpty) {
      try {
        rawJson = await rootBundle.loadString('assets/seed.json');
      } catch (_) {
        rawJson = await rootBundle.loadString('config/seeds/public.json');
      }
    }

    final Map<String, dynamic> data = jsonDecode(rawJson);
    final result = SeedParser.parse(data);
    if (!result.isValid) {
      throw StateError('Seed parsing failed during repair: ${result.validationErrors.join("; ")}');
    }

    final currentWeekId = FlutterTimeEngine.getWeekPeriod().id;
    final now = DateTime.now();

    int catsAdded = 0;
    int tasksAdded = 0;
    int eventsAdded = 0;
    int milestonesAdded = 0;
    int topicsAdded = 0;
    int leisureAdded = 0;
    int budgetsEnsured = 0;
    bool cleanedFallback = false;

    await db.transaction((txn) async {
      // Clean fallback if cat-deep-work has 0 sessions and is not in seed
      final deepWorkRows = await txn.query('categories', where: 'id = ?', whereArgs: ['cat-deep-work']);
      if (deepWorkRows.isNotEmpty && !result.categories.any((c) => c.id == 'cat-deep-work')) {
        final sessionsOnDeep = Sqflite.firstIntValue(
          await txn.rawQuery('SELECT COUNT(*) FROM sessions WHERE category_id = ?', ['cat-deep-work']),
        ) ?? 0;
        if (sessionsOnDeep == 0) {
          await txn.delete('categories', where: 'id = ?', whereArgs: ['cat-deep-work']);
          await txn.delete('weekly_budgets', where: 'category_id = ?', whereArgs: ['cat-deep-work']);
          cleanedFallback = true;
        }
      }

      // 1. Categories (Insert if missing, or update target minutes if it was 60 default)
      for (final cat in result.categories) {
        final existing = await txn.query('categories', where: 'id = ?', whereArgs: [cat.id]);
        if (existing.isEmpty) {
          await txn.insert('categories', cat.toMap());
          catsAdded++;
        } else {
          // If category already exists, update color & target minutes if they were uninitialized or default
          final currTarget = existing.first['weekly_target_minutes'] as int? ?? 0;
          if (currTarget == 60 && cat.weeklyTargetMinutes != 60) {
            await txn.update(
              'categories',
              {
                'weekly_target_minutes': cat.weeklyTargetMinutes,
                'color_value': cat.colorValue,
              },
              where: 'id = ?',
              whereArgs: [cat.id],
            );
          }
        }
      }

      // 2. Tasks & Subtasks (Insert missing tasks)
      for (final task in result.tasks) {
        final taskToInsert = task.weekPeriodId.isEmpty
            ? task.copyWith(weekPeriodId: currentWeekId)
            : task;
        final existing = await txn.query('tasks', where: 'id = ?', whereArgs: [taskToInsert.id]);
        if (existing.isEmpty) {
          await txn.insert('tasks', taskToInsert.toMap());
          tasksAdded++;

          for (final subtask in taskToInsert.subtasks) {
            final sMap = subtask.toMap();
            sMap['task_id'] = taskToInsert.id;
            await txn.insert('subtasks', sMap, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }

      // 3. Calendar Events (Insert missing events)
      for (final evt in result.calendarEvents) {
        final existing = await txn.query('calendar_events', where: 'id = ?', whereArgs: [evt.id]);
        if (existing.isEmpty) {
          await txn.insert('calendar_events', evt.toMap());
          eventsAdded++;
        }
      }

      // 4. Academic Milestones (Insert missing milestones)
      for (final ms in result.academicMilestones) {
        final existing = await txn.query('academic_milestones', where: 'id = ?', whereArgs: [ms.id]);
        if (existing.isEmpty) {
          await txn.insert('academic_milestones', ms.toMap());
          milestonesAdded++;
        }
      }

      // 5. Course Topics (Insert missing course topics)
      for (final topic in result.courseTopics) {
        final existing = await txn.query('course_topics', where: 'id = ?', whereArgs: [topic.id]);
        if (existing.isEmpty) {
          await txn.insert('course_topics', topic.toMap());
          topicsAdded++;
        }
      }

      // 6. Leisure Items (Insert missing leisure items)
      for (final item in result.leisureItems) {
        final existing = await txn.query('leisure_items', where: 'id = ?', whereArgs: [item.id]);
        if (existing.isEmpty) {
          await txn.insert('leisure_items', item.toMap());
          leisureAdded++;
        }
      }

      // 7. Ensure weekly_periods record exists
      final pRows = await txn.query('weekly_periods', where: 'id = ?', whereArgs: [currentWeekId]);
      if (pRows.isEmpty) {
        final weekInfo = FlutterTimeEngine.getWeekPeriod();
        await txn.insert('weekly_periods', {
          'id': currentWeekId,
          'start_date': weekInfo.start.toIso8601String(),
          'end_date': weekInfo.end.toIso8601String(),
          'created_at': now.toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      // 8. Ensure weekly_budgets for all active categories
      final allCats = await txn.query('categories', where: 'is_archived = 0');
      for (final catRow in allCats) {
        final catId = catRow['id'] as String;
        final targetMins = catRow['weekly_target_minutes'] as int? ?? 60;
        final bRows = await txn.query(
          'weekly_budgets',
          where: 'category_id = ? AND week_period_id = ?',
          whereArgs: [catId, currentWeekId],
        );
        if (bRows.isEmpty) {
          await txn.insert('weekly_budgets', {
            'id': '${catId}_$currentWeekId',
            'category_id': catId,
            'week_period_id': currentWeekId,
            'allocated_minutes': targetMins,
            'transferred_in_minutes': 0,
            'transferred_out_minutes': 0,
            'is_completed': 0,
            'created_at': now.toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          budgetsEnsured++;
        }
      }

      // 9. Update seed version
      await txn.update(
        'settings',
        {'seed_version': result.version},
        where: 'id = ?',
        whereArgs: ['app_settings'],
      );
    });

    final msg = 'Onarım tamamlandı: $catsAdded kategori, $tasksAdded görev, '
        '$eventsAdded takvim, $milestonesAdded dönüm noktası, $topicsAdded konu, $leisureAdded eğlence eklendi.';
    return SeedRepairReport(
      categoriesAdded: catsAdded,
      tasksAdded: tasksAdded,
      eventsAdded: eventsAdded,
      milestonesAdded: milestonesAdded,
      budgetsEnsured: budgetsEnsured,
      courseTopicsAdded: topicsAdded,
      leisureItemsAdded: leisureAdded,
      cleanedFallback: cleanedFallback,
      message: msg,
    );
  }

  // --- CATEGORIES ---
  Future<List<CategoryModel>> getAllCategories({bool includeArchived = false}) async {
    final db = await database;
    final where = includeArchived ? null : 'is_archived = 0';
    final rows = await db.query(
      'categories',
      where: where,
      orderBy: 'priority_order ASC, name ASC',
    );
    return rows.map((r) => CategoryModel.fromMap(r)).toList();
  }

  Future<void> insertCategory(CategoryModel category) async {
    final db = await database;
    await db.insert(
      'categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateCategory(CategoryModel category) async {
    final db = await database;
    await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<void> deleteCategory(String categoryId) async {
    final db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [categoryId]);
  }

  // --- TASKS ---
  Future<List<TaskModel>> getTasks({String? categoryId, required String weekPeriodId}) async {
    final db = await database;
    String where = 'week_period_id = ?';
    List<dynamic> whereArgs = [weekPeriodId];

    if (categoryId != null) {
      where += ' AND category_id = ?';
      whereArgs.add(categoryId);
    }

    final rows = await db.query('tasks', where: where, whereArgs: whereArgs, orderBy: 'created_at ASC');
    return rows.map((r) => TaskModel.fromMap(r)).toList();
  }

  Future<void> ensureWeekRollover(String currentWeekPeriodId) async {
    final db = await database;
    await db.transaction((txn) async {
      // 1. Ensure weekly_periods record exists
      final pRows = await txn.query('weekly_periods', where: 'id = ?', whereArgs: [currentWeekPeriodId]);
      if (pRows.isEmpty) {
        final weekInfo = FlutterTimeEngine.getWeekPeriod();
        await txn.insert('weekly_periods', {
          'id': currentWeekPeriodId,
          'start_date': weekInfo.start.toIso8601String(),
          'end_date': weekInfo.end.toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      // 2. Ensure weekly_budgets for all active categories
      final catRows = await txn.query('categories', where: 'is_archived = 0');
      for (final cat in catRows) {
        final catId = cat['id'] as String;
        final targetMins = cat['weekly_target_minutes'] as int;
        final bRows = await txn.query(
          'weekly_budgets',
          where: 'category_id = ? AND week_period_id = ?',
          whereArgs: [catId, currentWeekPeriodId],
        );
        if (bRows.isEmpty) {
          await txn.insert('weekly_budgets', {
            'id': '${catId}_$currentWeekPeriodId',
            'category_id': catId,
            'week_period_id': currentWeekPeriodId,
            'allocated_minutes': targetMins,
            'transferred_in_minutes': 0,
            'transferred_out_minutes': 0,
            'is_completed': 0,
            'created_at': DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      // 3. Materialize recurring tasks into current week with status = todo
      final recurringTaskRows = await txn.query(
        'tasks',
        where: 'recurrence != ? AND week_period_id != ?',
        whereArgs: ['once', currentWeekPeriodId],
      );

      for (final rRow in recurringTaskRows) {
        final catId = rRow['category_id'] as String;
        final title = rRow['title'] as String;

        final existing = await txn.query(
          'tasks',
          where: 'category_id = ? AND week_period_id = ? AND title = ?',
          whereArgs: [catId, currentWeekPeriodId, title],
        );

        if (existing.isEmpty) {
          final newId = '${rRow['id']}_$currentWeekPeriodId';
          await txn.insert('tasks', {
            'id': newId,
            'category_id': catId,
            'title': title,
            'description': rRow['description'],
            'estimated_minutes': rRow['estimated_minutes'],
            'actual_tracked_minutes': 0,
            'priority': rRow['priority'],
            'status': 'todo',
            'deadline': rRow['deadline'],
            'week_period_id': currentWeekPeriodId,
            'recurrence': rRow['recurrence'],
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
    });
  }

  // --- ACTIVE SESSIONS (Persistent Crash Recovery) ---
  Future<void> saveActiveSession(ActiveSessionRecord record) async {
    final db = await database;
    await db.insert(
      'active_session',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ActiveSessionRecord?> getActiveSession() async {
    final db = await database;
    final rows = await db.query(
      'active_session',
      where: 'id = ?',
      whereArgs: ['current'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ActiveSessionRecord.fromMap(rows.first);
  }

  Future<void> clearActiveSession() async {
    final db = await database;
    await db.delete('active_session', where: 'id = ?', whereArgs: ['current']);
  }

  Future<void> completeActiveSessionTransaction(WorkSessionModel session) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('sessions', session.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

      if (session.taskId != null && session.taskId!.isNotEmpty && session.activeSeconds > 0) {
        final taskMins = (session.activeSeconds / 60).round();
        await txn.rawUpdate(
          'UPDATE tasks SET actual_tracked_minutes = actual_tracked_minutes + ?, updated_at = ? WHERE id = ?',
          [taskMins, DateTime.now().toIso8601String(), session.taskId],
        );
      }

      await txn.delete('active_session', where: 'id = ?', whereArgs: ['current']);
    });
  }

  Future<void> insertTask(TaskModel task) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('tasks', task.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      for (final subtask in task.subtasks) {
        final sMap = subtask.toMap();
        sMap['task_id'] = task.id;
        await txn.insert('subtasks', sMap, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> updateTask(TaskModel task) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
      if (task.subtasks.isNotEmpty) {
        await txn.delete('subtasks', where: 'task_id = ?', whereArgs: [task.id]);
        for (final subtask in task.subtasks) {
          final sMap = subtask.toMap();
          sMap['task_id'] = task.id;
          await txn.insert('subtasks', sMap, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  Future<void> deleteTask(String taskId) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [taskId]);
  }

  Future<List<TaskModel>> getAllTasks({String? weekPeriodId}) async {
    final db = await database;
    final where = weekPeriodId != null ? 'week_period_id = ?' : null;
    final whereArgs = weekPeriodId != null ? [weekPeriodId] : null;
    final rows = await db.query('tasks', where: where, whereArgs: whereArgs, orderBy: 'created_at ASC');
    
    final tasks = <TaskModel>[];
    for (final r in rows) {
      final task = TaskModel.fromMap(r);
      final subRows = await db.query('subtasks', where: 'task_id = ?', whereArgs: [task.id]);
      final subtasks = subRows.map((s) => SubTaskModel.fromMap(s)).toList();
      tasks.add(task.copyWith(subtasks: subtasks));
    }
    return tasks;
  }

  Future<List<TaskModel>> getTasksForDate(String dateStr) async {
    final db = await database;
    final rows = await db.query(
      'tasks',
      where: 'planned_date = ? OR due_date = ?',
      whereArgs: [dateStr, dateStr],
      orderBy: 'priority DESC, created_at ASC',
    );
    final tasks = <TaskModel>[];
    for (final r in rows) {
      final task = TaskModel.fromMap(r);
      final subRows = await db.query('subtasks', where: 'task_id = ?', whereArgs: [task.id]);
      final subtasks = subRows.map((s) => SubTaskModel.fromMap(s)).toList();
      tasks.add(task.copyWith(subtasks: subtasks));
    }
    return tasks;
  }

  Future<List<TaskModel>> getOverdueTasks(String currentDateStr) async {
    final db = await database;
    final rows = await db.query(
      'tasks',
      where: 'status != ? AND (due_date < ? OR (planned_date < ? AND due_date IS NULL))',
      whereArgs: ['done', currentDateStr, currentDateStr],
      orderBy: 'due_date ASC, priority DESC',
    );
    final tasks = <TaskModel>[];
    for (final r in rows) {
      final task = TaskModel.fromMap(r);
      final subRows = await db.query('subtasks', where: 'task_id = ?', whereArgs: [task.id]);
      final subtasks = subRows.map((s) => SubTaskModel.fromMap(s)).toList();
      tasks.add(task.copyWith(subtasks: subtasks));
    }
    return tasks;
  }

  Future<void> updateTaskStatus(String taskId, TaskStatus status, {DateTime? completedAt}) async {
    final db = await database;
    final updateData = <String, dynamic>{
      'status': status.name,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (status == TaskStatus.done) {
      updateData['completed_at'] = (completedAt ?? DateTime.now()).toIso8601String();
    } else {
      updateData['completed_at'] = null;
    }
    await db.update('tasks', updateData, where: 'id = ?', whereArgs: [taskId]);
  }

  Future<void> deferTask(String taskId, String newPlannedDate) async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE tasks
      SET planned_date = ?, deferred_count = deferred_count + 1, status = 'todo', updated_at = ?
      WHERE id = ?
    ''', [newPlannedDate, DateTime.now().toIso8601String(), taskId]);
  }

  // --- SUBTASKS ---
  Future<List<SubTaskModel>> getSubtasksForTask(String taskId) async {
    final db = await database;
    final rows = await db.query('subtasks', where: 'task_id = ?', whereArgs: [taskId]);
    return rows.map((r) => SubTaskModel.fromMap(r)).toList();
  }

  Future<void> insertSubtask(SubTaskModel subtask, String taskId) async {
    final db = await database;
    final map = subtask.toMap();
    map['task_id'] = taskId;
    await db.insert('subtasks', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSubtask(SubTaskModel subtask) async {
    final db = await database;
    await db.update('subtasks', subtask.toMap(), where: 'id = ?', whereArgs: [subtask.id]);
  }

  Future<void> deleteSubtask(String subtaskId) async {
    final db = await database;
    await db.delete('subtasks', where: 'id = ?', whereArgs: [subtaskId]);
  }

  // --- COURSE TOPICS ---
  Future<List<CourseTopicModel>> getCourseTopics({String? courseId}) async {
    final db = await database;
    final where = courseId != null ? 'course_id = ?' : null;
    final whereArgs = courseId != null ? [courseId] : null;
    final rows = await db.query(
      'course_topics',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'week_number ASC, title ASC',
    );
    return rows.map((r) => CourseTopicModel.fromMap(r)).toList();
  }

  Future<void> updateCourseTopic(CourseTopicModel topic) async {
    final db = await database;
    await db.update('course_topics', topic.toMap(), where: 'id = ?', whereArgs: [topic.id]);
  }

  Future<void> bulkInsertCourseTopics(List<CourseTopicModel> topics) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final topic in topics) {
        await txn.insert('course_topics', topic.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // --- LEISURE ITEMS ---
  Future<List<LeisureItemModel>> getLeisureItems({String? type, String? status}) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;
    if (type != null && status != null) {
      where = 'type = ? AND status = ?';
      whereArgs = [type, status];
    } else if (type != null) {
      where = 'type = ?';
      whereArgs = [type];
    } else if (status != null) {
      where = 'status = ?';
      whereArgs = [status];
    }
    final rows = await db.query('leisure_items', where: where, whereArgs: whereArgs, orderBy: 'title ASC');
    return rows.map((r) => LeisureItemModel.fromMap(r)).toList();
  }

  Future<void> insertLeisureItem(LeisureItemModel item) async {
    final db = await database;
    await db.insert('leisure_items', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateLeisureItem(LeisureItemModel item) async {
    final db = await database;
    await db.update('leisure_items', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> deleteLeisureItem(String id) async {
    final db = await database;
    await db.delete('leisure_items', where: 'id = ?', whereArgs: [id]);
  }

  // --- WEEKLY BUDGETS & TERM MODES ---
  Future<List<WeeklyBudgetModel>> getWeeklyBudgets(String weekPeriodId) async {
    final db = await database;
    final rows = await db.query('weekly_budgets', where: 'week_period_id = ?', whereArgs: [weekPeriodId]);
    return rows.map((r) => WeeklyBudgetModel.fromMap(r)).toList();
  }

  Future<void> updateWeeklyBudgetAllocatedMinutes({
    required String categoryId,
    required String weekPeriodId,
    required int allocatedMinutes,
  }) async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE weekly_budgets
      SET allocated_minutes = ?
      WHERE category_id = ? AND week_period_id = ?
    ''', [allocatedMinutes, categoryId, weekPeriodId]);
  }

  Future<void> applyTermMode(TermModeModel mode, String weekPeriodId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE settings SET current_term_mode = ? WHERE id = ?',
        [mode.type.name, 'app_settings'],
      );

      for (final entry in mode.categoryHours.entries) {
        var catId = entry.key;
        final targetMinutes = (entry.value * 60).round();

        // Check if catId directly exists, or resolve alias
        var catRows = await txn.query('categories', where: 'id = ?', whereArgs: [catId]);
        if (catRows.isEmpty) {
          if (catId == 'cat-media') {
            final match = await txn.rawQuery("SELECT id FROM categories WHERE name LIKE '%Yayın%' OR name LIKE '%Anime%' OR id LIKE '%media%' LIMIT 1");
            if (match.isNotEmpty) {
              catId = match.first['id'] as String;
              catRows = match;
            }
          } else if (catId == 'cat-dev') {
            final match = await txn.rawQuery("SELECT id FROM categories WHERE name LIKE '%Geliştirme%' OR name LIKE '%Dev%' OR id LIKE '%dev%' LIMIT 1");
            if (match.isNotEmpty) {
              catId = match.first['id'] as String;
              catRows = match;
            }
          }
        }
        if (catRows.isEmpty) continue;

        await txn.rawUpdate(
          'UPDATE categories SET weekly_target_minutes = ? WHERE id = ?',
          [targetMinutes, catId],
        );

        final existing = await txn.query(
          'weekly_budgets',
          where: 'category_id = ? AND week_period_id = ?',
          whereArgs: [catId, weekPeriodId],
        );
        if (existing.isNotEmpty) {
          await txn.rawUpdate(
            'UPDATE weekly_budgets SET allocated_minutes = ? WHERE category_id = ? AND week_period_id = ?',
            [targetMinutes, catId, weekPeriodId],
          );
        } else {
          await txn.insert('weekly_budgets', {
            'id': '${catId}_$weekPeriodId',
            'category_id': catId,
            'week_period_id': weekPeriodId,
            'allocated_minutes': targetMinutes,
            'transferred_in_minutes': 0,
            'transferred_out_minutes': 0,
            'is_completed': 0,
            'created_at': DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
    });
  }

  // --- CALENDAR 2.0 EVENTS ---
  Future<void> insertCalendarEvent(CalendarEventModel event) async {
    final db = await database;
    await db.insert('calendar_events', event.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateCalendarEvent(CalendarEventModel event) async {
    final db = await database;
    await db.update('calendar_events', event.toMap(), where: 'id = ?', whereArgs: [event.id]);
  }

  Future<void> deleteCalendarEvent(String id) async {
    final db = await database;
    await db.delete('calendar_events', where: 'id = ?', whereArgs: [id]);
  }

  // --- SESSIONS ---
  Future<List<WorkSessionModel>> getSessionsForWeek(String weekPeriodId) async {
    final db = await database;
    final rows = await db.query(
      'sessions',
      where: 'week_period_id = ?',
      whereArgs: [weekPeriodId],
      orderBy: 'start_time DESC',
    );
    return rows.map((r) => WorkSessionModel.fromMap(r)).toList();
  }

  Future<void> insertSession(WorkSessionModel session) async {
    final db = await database;
    await db.insert('sessions', session.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSession(WorkSessionModel session) async {
    final db = await database;
    await db.update('sessions', session.toMap(), where: 'id = ?', whereArgs: [session.id]);
  }

  Future<void> deleteSession(String sessionId) async {
    final db = await database;
    await db.delete('sessions', where: 'id = ?', whereArgs: [sessionId]);
  }

  // --- POOL TRANSACTIONS ---
  Future<List<PoolTransactionModel>> getTransactionsForWeek(String weekPeriodId) async {
    final db = await database;
    final rows = await db.query(
      'pool_transactions',
      where: 'week_period_id = ?',
      whereArgs: [weekPeriodId],
      orderBy: 'timestamp DESC',
    );
    return rows.map((r) => PoolTransactionModel.fromMap(r)).toList();
  }

  Future<void> insertTransaction(PoolTransactionModel tx) async {
    final db = await database;
    await db.insert('pool_transactions', tx.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> markTransactionUndone(String txId) async {
    final db = await database;
    await db.update(
      'pool_transactions',
      {'is_undone': 1},
      where: 'id = ?',
      whereArgs: [txId],
    );
  }

  // --- CALENDAR EVENTS & MILESTONES ---
  Future<List<CalendarEventModel>> getCalendarEvents() async {
    final db = await database;
    final rows = await db.query('calendar_events', orderBy: 'day_of_week ASC, start_time ASC');
    return rows.map((r) => CalendarEventModel.fromMap(r)).toList();
  }

  Future<List<AcademicMilestoneModel>> getAcademicMilestones() async {
    final db = await database;
    final rows = await db.query('academic_milestones', orderBy: 'start_date ASC');
    return rows.map((r) => AcademicMilestoneModel.fromMap(r)).toList();
  }

  // --- SETTINGS ---
  Future<AppSettingsModel> getSettings() async {
    final db = await database;
    final rows = await db.query('settings', where: 'id = ?', whereArgs: ['app_settings'], limit: 1);
    if (rows.isNotEmpty) {
      return AppSettingsModel.fromMap(rows.first);
    }
    return const AppSettingsModel();
  }

  Future<void> updateSettings(AppSettingsModel settings) async {
    final db = await database;
    await db.update(
      'settings',
      settings.toMap(),
      where: 'id = ?',
      whereArgs: ['app_settings'],
    );
  }

  // --- BACKUP & RESTORE ---
  Future<String> exportBackupJson() async {
    final db = await database;
    final categories = await db.query('categories');
    final tasks = await db.query('tasks');
    final subtasks = await db.query('subtasks');
    final sessions = await db.query('sessions');
    final transactions = await db.query('pool_transactions');
    final events = await db.query('calendar_events');
    final courseTopics = await db.query('course_topics');
    final leisureItems = await db.query('leisure_items');
    final weeklyBudgets = await db.query('weekly_budgets');
    final settings = await db.query('settings');

    final backup = {
      'schema_version': 2,
      'app': 'TEMPO',
      'exported_at': DateTime.now().toIso8601String(),
      'categories': categories,
      'tasks': tasks,
      'subtasks': subtasks,
      'sessions': sessions,
      'pool_transactions': transactions,
      'calendar_events': events,
      'course_topics': courseTopics,
      'leisure_items': leisureItems,
      'weekly_budgets': weeklyBudgets,
      'settings': settings.isNotEmpty ? settings.first : null,
    };

    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  Future<bool> restoreBackupJson(String jsonStr) async {
    final db = await database;
    final dynamic parsed = jsonDecode(jsonStr);

    if (parsed is! Map<String, dynamic> || parsed['categories'] == null) {
      throw Exception('Geçersiz TEMPO yedek dosyası formatı.');
    }

    await db.transaction((txn) async {
      await txn.delete('session_segments');
      await txn.delete('break_segments');
      await txn.delete('sessions');
      await txn.delete('subtasks');
      await txn.delete('tasks');
      await txn.delete('task_occurrences');
      await txn.delete('pool_transactions');
      await txn.delete('calendar_events');
      await txn.delete('course_topics');
      await txn.delete('leisure_items');
      await txn.delete('weekly_budgets');
      await txn.delete('categories');

      for (final cat in parsed['categories']) {
        await txn.insert('categories', cat as Map<String, dynamic>);
      }

      if (parsed['tasks'] is List) {
        for (final t in parsed['tasks']) {
          await txn.insert('tasks', t as Map<String, dynamic>);
        }
      }

      if (parsed['subtasks'] is List) {
        for (final st in parsed['subtasks']) {
          await txn.insert('subtasks', st as Map<String, dynamic>);
        }
      }

      if (parsed['sessions'] is List) {
        for (final s in parsed['sessions']) {
          await txn.insert('sessions', s as Map<String, dynamic>);
        }
      }

      if (parsed['pool_transactions'] is List) {
        for (final tx in parsed['pool_transactions']) {
          await txn.insert('pool_transactions', tx as Map<String, dynamic>);
        }
      }

      if (parsed['calendar_events'] is List) {
        for (final e in parsed['calendar_events']) {
          await txn.insert('calendar_events', e as Map<String, dynamic>);
        }
      }

      if (parsed['course_topics'] is List) {
        for (final ct in parsed['course_topics']) {
          await txn.insert('course_topics', ct as Map<String, dynamic>);
        }
      }

      if (parsed['leisure_items'] is List) {
        for (final li in parsed['leisure_items']) {
          await txn.insert('leisure_items', li as Map<String, dynamic>);
        }
      }

      if (parsed['weekly_budgets'] is List) {
        for (final wb in parsed['weekly_budgets']) {
          await txn.insert('weekly_budgets', wb as Map<String, dynamic>, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      if (parsed['settings'] is Map<String, dynamic>) {
        await txn.update(
          'settings',
          parsed['settings'] as Map<String, dynamic>,
          where: 'id = ?',
          whereArgs: ['app_settings'],
        );
      }
    });

    return true;
  }

  Future<String> exportSessionsCsv() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT s.id, c.name as category_name, s.start_time, s.end_time, s.active_seconds, s.break_seconds, s.note, s.week_period_id
      FROM sessions s
      JOIN categories c ON s.category_id = c.id
      ORDER BY s.start_time DESC
    ''');

    final sb = StringBuffer();
    sb.writeln('Session ID,Category,Start Time,End Time,Active (Seconds),Active (Formatted),Break (Seconds),Note,Week Period');
    for (final r in rows) {
      final activeSec = (r['active_seconds'] as num?)?.toInt() ?? 0;
      final m = activeSec ~/ 60;
      final s = activeSec % 60;
      final formatted = '${m}m ${s}s';
      sb.writeln('${r['id']},"${r['category_name']}",${r['start_time']},${r['end_time']},$activeSec,"$formatted",${r['break_seconds']},"${r['note'] ?? ''}",${r['week_period_id']}');
    }

    return sb.toString();
  }

  Future<void> resetToSeedData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('session_segments');
      await txn.delete('break_segments');
      await txn.delete('sessions');
      await txn.delete('subtasks');
      await txn.delete('tasks');
      await txn.delete('task_occurrences');
      await txn.delete('pool_transactions');
      await txn.delete('calendar_events');
      await txn.delete('course_topics');
      await txn.delete('leisure_items');
      await txn.delete('weekly_budgets');
      await txn.delete('categories');
    });

    await initializeSeedDataIfEmpty();
  }
}
