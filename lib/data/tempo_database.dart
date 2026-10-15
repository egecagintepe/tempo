import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../domain/models.dart';
import '../domain/time_engine.dart';

class TempoDatabase {
  static final TempoDatabase instance = TempoDatabase._internal();
  TempoDatabase._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'tempo_os_v1.db');

    return await openDatabase(
      path,
      version: 2,
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
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX idx_tasks_category ON tasks(category_id);');
    await db.execute('CREATE INDEX idx_tasks_week ON tasks(week_period_id);');

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
        seed_version INTEGER NOT NULL DEFAULT 0
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

  // --- SEED INITIALIZATION (Idempotent) ---
  Future<void> initializeSeedDataIfEmpty() async {
    final db = await database;
    final categoryCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM categories'),
    ) ?? 0;

    if (categoryCount > 0) {
      return; // Already initialized, preserve user customisations!
    }

    try {
      String jsonStr = '';
      try {
        jsonStr = await rootBundle.loadString('assets/seed.json');
      } catch (_) {
        jsonStr = await rootBundle.loadString('config/seeds/public.json');
      }

      final Map<String, dynamic> data = jsonDecode(jsonStr);
      await loadSeedData(data);
    } catch (e) {
      // Fallback: create 3 basic categories if asset reading fails
      await insertCategory(CategoryModel(
        id: 'cat-deep-work',
        name: 'Deep Work',
        description: 'Focused problem solving',
        icon: 'cpu',
        colorValue: 0xFF2563EB,
        weeklyTargetMinutes: 420,
        policy: BudgetPolicy.flexible,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }
  }

  Future<void> loadSeedData(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      // 1. Categories
      if (data['categories'] is List) {
        for (final item in data['categories']) {
          final cat = CategoryModel.fromMap(item);
          await txn.insert(
            'categories',
            cat.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // 2. Tasks
      if (data['tasks'] is List) {
        for (final item in data['tasks']) {
          final task = TaskModel.fromMap(item);
          await txn.insert(
            'tasks',
            task.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // 3. Calendar Events
      if (data['calendarEvents'] is List) {
        for (final item in data['calendarEvents']) {
          final evt = CalendarEventModel.fromMap(item);
          await txn.insert(
            'calendar_events',
            evt.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // 4. Academic Milestones
      if (data['academicMilestones'] is List) {
        for (final item in data['academicMilestones']) {
          final ms = AcademicMilestoneModel.fromMap(item);
          await txn.insert(
            'academic_milestones',
            ms.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // 5. Update seed version in settings
      await txn.update(
        'settings',
        {'seed_version': (data['version'] as num?)?.toInt() ?? 1},
        where: 'id = ?',
        whereArgs: ['app_settings'],
      );
    });
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
    await db.insert('tasks', task.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateTask(TaskModel task) async {
    final db = await database;
    await db.update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
  }

  Future<void> deleteTask(String taskId) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [taskId]);
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
    final sessions = await db.query('sessions');
    final transactions = await db.query('pool_transactions');
    final events = await db.query('calendar_events');
    final settings = await db.query('settings');

    final backup = {
      'schema_version': 1,
      'app': 'TEMPO',
      'exported_at': DateTime.now().toIso8601String(),
      'categories': categories,
      'tasks': tasks,
      'sessions': sessions,
      'pool_transactions': transactions,
      'calendar_events': events,
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
      await txn.delete('tasks');
      await txn.delete('task_occurrences');
      await txn.delete('pool_transactions');
      await txn.delete('calendar_events');
      await txn.delete('categories');

      for (final cat in parsed['categories']) {
        await txn.insert('categories', cat as Map<String, dynamic>);
      }

      if (parsed['tasks'] is List) {
        for (final t in parsed['tasks']) {
          await txn.insert('tasks', t as Map<String, dynamic>);
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
      await txn.delete('tasks');
      await txn.delete('task_occurrences');
      await txn.delete('pool_transactions');
      await txn.delete('calendar_events');
      await txn.delete('categories');
    });

    await initializeSeedDataIfEmpty();
  }
}
