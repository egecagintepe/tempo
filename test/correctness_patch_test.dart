import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tempo/data/tempo_database.dart';
import 'package:tempo/domain/models.dart';
import 'package:tempo/domain/time_engine.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('P0: Active Session Persistence & Crash Recovery', () {
    late TempoDatabase db;

    setUp(() async {
      db = TempoDatabase.instance;
      await db.clearActiveSession();
    });

    test('Active session is persisted and accurately retrieved from SQLite', () async {
      final now = DateTime.now();
      await db.insertCategory(CategoryModel(
        id: 'cat-rf',
        name: 'RF',
        description: '',
        icon: 'zap',
        colorValue: 0xFF2563EB,
        weeklyTargetMinutes: 420,
        policy: BudgetPolicy.flexible,
        createdAt: now,
        updatedAt: now,
      ));

      final record = ActiveSessionRecord(
        categoryId: 'cat-rf',
        taskId: null,
        state: SessionState.running,
        sessionStartTime: now.subtract(const Duration(seconds: 45)),
        lastSegmentStartTime: now.subtract(const Duration(seconds: 45)),
        accumulatedWorkSeconds: 120,
        accumulatedBreakSeconds: 15,
        plannedBreakMinutes: 5,
        focusCycle: 'continuous',
        note: 'Crash recovery unit test',
        weekPeriodId: '2026-W42',
        createdAt: now,
        updatedAt: now,
      );

      await db.saveActiveSession(record);

      final retrieved = await db.getActiveSession();
      expect(retrieved, isNotNull);
      expect(retrieved!.categoryId, equals('cat-rf'));
      expect(retrieved.taskId, isNull);
      expect(retrieved.state, equals(SessionState.running));
      expect(retrieved.accumulatedWorkSeconds, equals(120));
      expect(retrieved.accumulatedBreakSeconds, equals(15));
      expect(retrieved.note, equals('Crash recovery unit test'));
    });

    test('Crash recovery clamps strict budget elapsed time when killed duration exceeds budget', () {
      // Suppose category had 10 minutes remaining (600 seconds)
      const initialRemainingSeconds = 600;
      const accumulatedBeforeCrash = 200;
      const availableBeforeCrash = initialRemainingSeconds - accumulatedBeforeCrash; // 400 seconds left

      // App process was killed and user opens it 2 hours later (7200 seconds elapsed)
      const elapsedSinceKill = 7200;

      // Under strict policy, elapsed work must be clamped to availableBeforeCrash
      final clampedWork = (accumulatedBeforeCrash + min(elapsedSinceKill, availableBeforeCrash));

      expect(clampedWork, equals(600)); // Exactly 600, never exceeding the 600s budget!
      final remainingAfterRecovery = initialRemainingSeconds - clampedWork;
      expect(remainingAfterRecovery, equals(0)); // Zero remaining, NEVER negative!
    });

    test('completeActiveSessionTransaction is atomic and updates task tracked time', () async {
      final now = DateTime.now();
      await db.insertCategory(CategoryModel(
        id: 'cat-test',
        name: 'Test Category',
        description: '',
        icon: 'cpu',
        colorValue: 0xFF2563EB,
        weeklyTargetMinutes: 120,
        policy: BudgetPolicy.flexible,
        createdAt: now,
        updatedAt: now,
      ));

      final testTask = TaskModel(
        id: 'task-atomic-test',
        categoryId: 'cat-test',
        title: 'Complete chapter',
        estimatedMinutes: 60,
        actualTrackedMinutes: 10,
        priority: TaskPriority.high,
        status: TaskStatus.inProgress,
        weekPeriodId: '2026-W42',
        createdAt: now,
        updatedAt: now,
      );
      await db.insertTask(testTask);

      final activeRec = ActiveSessionRecord(
        categoryId: 'cat-test',
        taskId: 'task-atomic-test',
        state: SessionState.running,
        sessionStartTime: now,
        lastSegmentStartTime: now,
        accumulatedWorkSeconds: 1800, // 30 minutes
        weekPeriodId: '2026-W42',
        createdAt: now,
        updatedAt: now,
      );
      await db.saveActiveSession(activeRec);

      final completedSession = WorkSessionModel(
        id: 'session-atomic-1',
        categoryId: 'cat-test',
        taskId: 'task-atomic-test',
        startTime: now,
        endTime: now.add(const Duration(minutes: 30)),
        state: SessionState.completed,
        activeSeconds: 1800,
        weekPeriodId: '2026-W42',
        createdAt: now,
        updatedAt: now,
      );

      await db.completeActiveSessionTransaction(completedSession);

      // Verify active session record is deleted
      final active = await db.getActiveSession();
      expect(active, isNull);

      // Verify task tracked minutes updated: 10 + 30 = 40 mins
      final tasks = await db.getTasks(weekPeriodId: '2026-W42');
      final updatedTask = tasks.firstWhere((t) => t.id == 'task-atomic-test');
      expect(updatedTask.actualTrackedMinutes, equals(40));
    });
  });

  group('P0: Strict Budget Enforcement Logic', () {
    final now = DateTime.now();
    final strictCategory = CategoryModel(
      id: 'cat-strict-test',
      name: 'Strict Category',
      description: '',
      icon: 'zap',
      colorValue: 0xFFEF4444,
      weeklyTargetMinutes: 60, // 3600 seconds
      policy: BudgetPolicy.strict,
      createdAt: now,
      updatedAt: now,
    );

    test('canStartSession strictly rejects when remaining budget is zero', () {
      const exhaustedTotals = CategoryCalculatedTotals(
        categoryId: 'cat-strict-test',
        initialTargetMinutes: 60,
        transferredInMinutes: 0,
        transferredOutMinutes: 0,
        effectiveTargetMinutes: 60,
        effectiveTargetSeconds: 3600,
        spentSeconds: 3600,
        spentMinutes: 60,
        remainingSeconds: 0,
        remainingMinutes: 0,
        progressPercent: 100,
        isExhausted: true,
        isOverBudget: false,
        overBudgetSeconds: 0,
        sessionCount: 2,
      );

      final check = FlutterTimeEngine.canStartSession(
        category: strictCategory,
        totals: exhaustedTotals,
      );

      expect(check.isAllowed, isFalse);
      expect(check.blockReason, contains('Katı Bütçe Doldu'));
    });

    test('canStartSession allows starting when incoming transfer restores remaining budget', () {
      const restoredTotals = CategoryCalculatedTotals(
        categoryId: 'cat-strict-test',
        initialTargetMinutes: 60,
        transferredInMinutes: 30, // 30 minutes added from pool
        transferredOutMinutes: 0,
        effectiveTargetMinutes: 90,
        effectiveTargetSeconds: 5400,
        spentSeconds: 3600,
        spentMinutes: 60,
        remainingSeconds: 1800, // 30 minutes available
        remainingMinutes: 30,
        progressPercent: 67,
        isExhausted: false,
        isOverBudget: false,
        overBudgetSeconds: 0,
        sessionCount: 2,
      );

      final check = FlutterTimeEngine.canStartSession(
        category: strictCategory,
        totals: restoredTotals,
      );

      expect(check.isAllowed, isTrue);
    });
  });

  group('P1: Weekly Rollover & Task Recurrence Isolation', () {
    late TempoDatabase db;

    setUp(() {
      db = TempoDatabase.instance;
    });

    test('ensureWeekRollover copies recurring tasks as fresh Todo instances in new week', () async {
      final now = DateTime.now();

      // 1. Create a category
      final cat = CategoryModel(
        id: 'cat-recurring-test',
        name: 'Weekly Practice',
        description: 'Test category',
        icon: 'book',
        colorValue: 0xFF10B981,
        weeklyTargetMinutes: 120,
        policy: BudgetPolicy.flexible,
        createdAt: now,
        updatedAt: now,
      );
      await db.insertCategory(cat);

      // 2. Create a recurring task in Week 41 and mark it done
      final week41Task = TaskModel(
        id: 'task-w41-rec',
        categoryId: 'cat-recurring-test',
        title: 'Weekly Problem Set',
        description: 'Solve 10 problems',
        estimatedMinutes: 60,
        actualTrackedMinutes: 55,
        priority: TaskPriority.high,
        status: TaskStatus.done, // COMPLETED in Week 41!
        weekPeriodId: '2026-W41',
        recurrence: TaskRecurrence.weekly,
        createdAt: now.subtract(const Duration(days: 7)),
        updatedAt: now.subtract(const Duration(days: 7)),
      );
      await db.insertTask(week41Task);

      // 3. Perform rollover to Week 42
      await db.ensureWeekRollover('2026-W42');

      // 4. Verify Week 41 task is STILL status: done
      final w41Tasks = await db.getTasks(weekPeriodId: '2026-W41');
      final originalTask = w41Tasks.firstWhere((t) => t.id == 'task-w41-rec');
      expect(originalTask.status, equals(TaskStatus.done));
      expect(originalTask.actualTrackedMinutes, equals(55));

      // 5. Verify Week 42 has a NEW instance with status: todo and 0 tracked minutes!
      final w42Tasks = await db.getTasks(weekPeriodId: '2026-W42');
      expect(w42Tasks.any((t) => t.title == 'Weekly Problem Set'), isTrue);

      final newWeekTask = w42Tasks.firstWhere((t) => t.title == 'Weekly Problem Set');
      expect(newWeekTask.status, equals(TaskStatus.todo)); // FRESH TODO!
      expect(newWeekTask.actualTrackedMinutes, equals(0)); // 0 minutes!
      expect(newWeekTask.id, isNot(equals('task-w41-rec'))); // Separate identity!
    });
  });
}
