import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tempo/data/seed_parser.dart';
import 'package:tempo/data/tempo_database.dart';
import 'package:tempo/domain/models.dart';
import 'package:tempo/domain/time_engine.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SeedParser Unit & Validation Tests', () {
    test('Correctly parses and validates .local/personal_profile.json', () {
      final file = File('.local/personal_profile.json');
      expect(file.existsSync(), isTrue, reason: 'Personal profile seed file must exist locally');

      final content = file.readAsStringSync();
      final Map<String, dynamic> data = jsonDecode(content);

      final result = SeedParser.parse(data, targetWeekPeriodId: '2026-W42');

      expect(result.isValid, isTrue, reason: 'Personal seed must be valid with zero fatal errors');
      expect(result.validationErrors, isEmpty);
      expect(result.edition, equals('personal'));
      expect(result.version, equals(1));
      expect(result.appTitle, equals('TEMPO Personal'));

      // Check Categories
      expect(result.categories.length, equals(10), reason: 'Must have exactly 10 personal categories');
      expect(result.totalCategoryMinutes, equals(1620), reason: 'Total weekly minutes must equal 1620 (27h)');

      // Verify specific category details & camelCase conversion
      final rfCat = result.categories.firstWhere((c) => c.id == 'cat-rf');
      expect(rfCat.name, equals('RF'));
      expect(rfCat.weeklyTargetMinutes, equals(420));
      expect(rfCat.colorValue, equals(0xFF06B6D4), reason: 'Hex #06B6D4 must convert to 0xFF06B6D4');
      expect(rfCat.policy, equals(BudgetPolicy.flexible));
      expect(rfCat.priorityOrder, equals(1));
      expect(rfCat.scheduledDays, equals([1, 2, 6]));

      final elekCat = result.categories.firstWhere((c) => c.id == 'cat-elek2');
      expect(elekCat.name, equals('Elektronik II'));
      expect(elekCat.weeklyTargetMinutes, equals(420));
      expect(elekCat.colorValue, equals(0xFF3B82F6));
      expect(elekCat.scheduledDays, equals([1, 4, 5, 6]));

      final anizonCat = result.categories.firstWhere((c) => c.id == 'cat-anizon');
      expect(anizonCat.policy, equals(BudgetPolicy.strict));
      expect(anizonCat.weeklyTargetMinutes, equals(150));

      final webCat = result.categories.firstWhere((c) => c.id == 'cat-web-ajansi');
      expect(webCat.policy, equals(BudgetPolicy.deadline));
      expect(webCat.deadlineDate, equals('2026-10-20'));

      final kitapCat = result.categories.firstWhere((c) => c.id == 'cat-kitap');
      expect(kitapCat.policy, equals(BudgetPolicy.protected));
      expect(kitapCat.weeklyTargetMinutes, equals(90));

      // Check Tasks
      expect(result.tasks.length, equals(19), reason: 'Must parse all 19 personal tasks');
      for (final t in result.tasks) {
        expect(t.weekPeriodId, equals('2026-W42'), reason: 'Tasks without explicit weekPeriodId must get targetWeek');
        expect(result.categories.any((c) => c.id == t.categoryId), isTrue,
            reason: 'Task categoryId must refer to a valid category');
      }

      final task1 = result.tasks.firstWhere((t) => t.id == 't-rf-1');
      expect(task1.title, contains('RF Temel Kavramları'));
      expect(task1.estimatedMinutes, equals(60));
      expect(task1.priority, equals(TaskPriority.high));
      expect(task1.recurrence, equals(TaskRecurrence.once));

      // Check Calendar Events
      expect(result.calendarEvents.length, equals(19), reason: 'Must parse all 19 calendar events');
      final event1 = result.calendarEvents.firstWhere((e) => e.id == 'cal-mon-elek2-class');
      expect(event1.dayOfWeek, equals(1));
      expect(event1.startTime, equals('10:40'));
      expect(event1.endTime, equals('12:30'));
      expect(event1.categoryId, equals('cat-elek2'));

      // Check Academic Milestones
      expect(result.academicMilestones.length, equals(7), reason: 'Must parse 7 academic milestones');
      final m1 = result.academicMilestones.firstWhere((m) => m.title.contains('Vizeler'));
      expect(m1.startDate, equals('2026-11-07'));
      expect(m1.endDate, equals('2026-11-15'));
    });

    test('Correctly parses and validates config/seeds/public.json', () {
      final file = File('config/seeds/public.json');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      final Map<String, dynamic> data = jsonDecode(content);

      final result = SeedParser.parse(data, targetWeekPeriodId: '2026-W42');

      expect(result.isValid, isTrue);
      expect(result.edition, equals('public'));
      expect(result.categories.length, equals(7));
      expect(result.totalCategoryMinutes, equals(1380));
      expect(result.tasks.length, equals(5));
      expect(result.calendarEvents, isEmpty);
    });

    test('Diagnoses invalid seed and produces descriptive validationErrors', () {
      final invalidData = {
        'edition': 'broken',
        'categories': [
          {'name': 'No ID Category'}, // Missing id!
        ],
        'tasks': [
          {'id': 't1', 'title': 'Task with no category'}, // Missing categoryId!
        ],
      };

      final result = SeedParser.parse(invalidData);
      expect(result.isValid, isFalse);
      expect(result.validationErrors.any((e) => e.contains('missing an "id"')), isTrue);
      expect(result.validationErrors.any((e) => e.contains('missing "categoryId"')), isTrue);
    });
  });

  group('SQLite Seed Integration & Database Seeding', () {
    late TempoDatabase db;
    late Database rawDb;

    setUp(() async {
      db = TempoDatabase.instance;
      rawDb = await db.database;
      // Clean all tables for a pristine test environment
      await rawDb.transaction((txn) async {
        await txn.delete('session_segments');
        await txn.delete('break_segments');
        await txn.delete('sessions');
        await txn.delete('tasks');
        await txn.delete('task_occurrences');
        await txn.delete('pool_transactions');
        await txn.delete('calendar_events');
        await txn.delete('academic_milestones');
        await txn.delete('weekly_budgets');
        await txn.delete('weekly_periods');
        await txn.delete('categories');
        await txn.update('settings', {'seed_version': 0});
      });
    });

    test('Clean Install: Personal profile loads all 10 categories, 1620 mins budgets, tasks, calendar & milestones', () async {
      final content = File('.local/personal_profile.json').readAsStringSync();
      final Map<String, dynamic> data = jsonDecode(content);

      // Load seed into database
      await db.loadSeedData(data);

      // 1. Verify Categories
      final cats = await db.getAllCategories();
      expect(cats.length, equals(10), reason: 'All 10 personal categories must be stored in SQLite');
      final totalTarget = cats.fold(0, (sum, c) => sum + c.weeklyTargetMinutes);
      expect(totalTarget, equals(1620), reason: 'Total weekly target minutes must be exactly 1620');

      // Verify colors parsed from hex to ARGB integer
      final rf = cats.firstWhere((c) => c.id == 'cat-rf');
      expect(rf.colorValue, equals(0xFF06B6D4));

      // 2. Verify Weekly Budgets
      final currentWeekId = FlutterTimeEngine.getWeekPeriod().id;
      final budgetRows = await rawDb.query('weekly_budgets', where: 'week_period_id = ?', whereArgs: [currentWeekId]);
      expect(budgetRows.length, equals(10), reason: 'Every category must have a weekly_budget record for current week');
      final totalBudgetMinutes = budgetRows.fold(0, (sum, r) => sum + (r['allocated_minutes'] as int));
      expect(totalBudgetMinutes, equals(1620), reason: 'Allocated budget minutes must equal 1620 minutes');

      // 3. Verify Tasks
      final tasks = await db.getTasks(weekPeriodId: currentWeekId);
      expect(tasks.length, equals(19), reason: 'All 19 tasks must be available for the current week period');

      // 4. Verify Calendar Events
      final events = await rawDb.query('calendar_events');
      expect(events.length, equals(19), reason: 'All 19 calendar events must be inserted');

      // 5. Verify Academic Milestones
      final milestones = await rawDb.query('academic_milestones');
      expect(milestones.length, equals(7), reason: 'All 7 academic milestones must be inserted');

      // 6. Verify Settings seed_version
      final settings = await db.getSettings();
      expect(settings.seedVersion, equals(1), reason: 'seed_version in settings must be updated to 1');
    });

    test('Idempotency: Re-running loadSeedData does not duplicate records or crash', () async {
      final content = File('.local/personal_profile.json').readAsStringSync();
      final Map<String, dynamic> data = jsonDecode(content);

      await db.loadSeedData(data);
      // Run second time (should be completely idempotent)
      await db.loadSeedData(data);

      final cats = await db.getAllCategories();
      expect(cats.length, equals(10));

      final currentWeekId = FlutterTimeEngine.getWeekPeriod().id;
      final tasks = await db.getTasks(weekPeriodId: currentWeekId);
      expect(tasks.length, equals(19));

      final events = await rawDb.query('calendar_events');
      expect(events.length, equals(19));
    });

    test('Lossless Recovery: Repairs previously failed fallback install without losing user sessions or custom tasks', () async {
      final now = DateTime.now();
      final currentWeekId = FlutterTimeEngine.getWeekPeriod().id;

      // Simulate the previously broken state:
      // 1. Fallback created only 'cat-deep-work'
      await rawDb.insert('categories', {
        'id': 'cat-deep-work',
        'name': 'Deep Work',
        'description': 'Focused problem solving',
        'icon': 'cpu',
        'color_value': 0xFF2563EB,
        'weekly_target_minutes': 420,
        'policy': 'flexible',
        'is_archived': 0,
        'priority_order': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // 2. User recorded a 25-minute session under 'cat-deep-work'
      await rawDb.insert('sessions', {
        'id': 'session-user-1',
        'category_id': 'cat-deep-work',
        'start_time': now.subtract(const Duration(minutes: 30)).toIso8601String(),
        'end_time': now.subtract(const Duration(minutes: 5)).toIso8601String(),
        'state': 'completed',
        'active_seconds': 1500, // 25m
        'pause_seconds': 0,
        'break_seconds': 0,
        'note': 'User real work session',
        'week_period_id': currentWeekId,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // 3. User created a custom personal task
      await rawDb.insert('tasks', {
        'id': 'task-custom-user',
        'category_id': 'cat-deep-work',
        'title': 'User Custom Task That Must Not Be Lost',
        'estimated_minutes': 45,
        'actual_tracked_minutes': 25,
        'priority': 'high',
        'status': 'inProgress',
        'week_period_id': currentWeekId,
        'recurrence': 'once',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // Execute lossless repair
      final content = File('.local/personal_profile.json').readAsStringSync();
      final report = await db.repairSeedDataLossless(jsonStr: content);

      expect(report.categoriesAdded, equals(10), reason: 'Should add the 10 missing personal categories');
      expect(report.tasksAdded, equals(19), reason: 'Should add the 19 personal profile tasks');
      expect(report.eventsAdded, equals(19), reason: 'Should add all 19 calendar events');
      expect(report.milestonesAdded, equals(7), reason: 'Should add all 7 milestones');

      // CRITICAL: Verify user data was NOT deleted!
      final preservedSession = await rawDb.query('sessions', where: 'id = ?', whereArgs: ['session-user-1']);
      expect(preservedSession.isNotEmpty, isTrue, reason: 'User recorded session must NOT be deleted');
      expect(preservedSession.first['active_seconds'], equals(1500));

      final preservedTask = await rawDb.query('tasks', where: 'id = ?', whereArgs: ['task-custom-user']);
      expect(preservedTask.isNotEmpty, isTrue, reason: 'User custom task must NOT be deleted');

      // Since cat-deep-work had real user sessions, it was preserved alongside the 10 personal categories
      final allCategories = await db.getAllCategories();
      expect(allCategories.length, equals(11), reason: '10 personal categories + 1 preserved user category');
      expect(allCategories.any((c) => c.id == 'cat-rf'), isTrue);
      expect(allCategories.any((c) => c.id == 'cat-elek2'), isTrue);
      expect(allCategories.any((c) => c.id == 'cat-deep-work'), isTrue);
    });
  });
}
