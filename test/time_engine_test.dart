import 'package:flutter_test/flutter_test.dart';
import 'package:tempo/domain/models.dart';
import 'package:tempo/domain/time_engine.dart';

void main() {
  group('FlutterTimeEngine — Formatting & Date Boundaries', () {
    test('formatMinutes formats minutes accurately into Turkish strings', () {
      expect(FlutterTimeEngine.formatMinutes(150), equals('2s 30dk'));
      expect(FlutterTimeEngine.formatMinutes(60), equals('1s'));
      expect(FlutterTimeEngine.formatMinutes(45), equals('45dk'));
      expect(FlutterTimeEngine.formatMinutes(0), equals('0dk'));
      expect(FlutterTimeEngine.formatMinutes(-30), equals('-30dk'));
      expect(FlutterTimeEngine.formatMinutes(-90), equals('-1s 30dk'));
    });

    test('formatStopwatch produces padded HH:MM:SS or MM:SS', () {
      expect(FlutterTimeEngine.formatStopwatch(0), equals('00:00:00'));
      expect(FlutterTimeEngine.formatStopwatch(65), equals('00:01:05'));
      expect(FlutterTimeEngine.formatStopwatch(3661), equals('01:01:01'));
      expect(FlutterTimeEngine.formatStopwatch(7200), equals('02:00:00'));
      expect(FlutterTimeEngine.formatStopwatch(65, forceHours: false), equals('01:05'));
    });

    test('getWeekPeriod returns consistent ISO week ID with Monday-Sunday boundaries', () {
      final testDate = DateTime.utc(2026, 10, 15, 12, 0); // Thursday
      final week = FlutterTimeEngine.getWeekPeriod(testDate);

      expect(week.id, contains('2026-W'));
      expect(week.start.weekday, equals(DateTime.monday));
      expect(week.end.weekday, equals(DateTime.sunday));
      expect(week.end.isAfter(week.start), isTrue);
    });
  });

  group('FlutterTimeEngine — Budget Arithmetic & Equations', () {
    final now = DateTime.now();

    final testCategory = CategoryModel(
      id: 'cat-test',
      name: 'Deep Work',
      description: 'Focus testing',
      icon: 'cpu',
      colorValue: 0xFF2563EB,
      weeklyTargetMinutes: 120, // 2 hours = 7200 seconds
      policy: BudgetPolicy.strict,
      createdAt: now,
      updatedAt: now,
    );

    test('calculateTotals computes base budget, spent time, and remaining time correctly', () {
      final sessions = [
        WorkSessionModel(
          id: 's1',
          categoryId: 'cat-test',
          startTime: now.subtract(const Duration(hours: 1)),
          endTime: now,
          activeSeconds: 3600, // 60 mins
          weekPeriodId: '2026-W42',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final totals = FlutterTimeEngine.calculateTotals(
        category: testCategory,
        sessions: sessions,
        transactions: [],
        weekPeriodId: '2026-W42',
      );

      expect(totals.initialTargetMinutes, equals(120));
      expect(totals.effectiveTargetMinutes, equals(120));
      expect(totals.spentMinutes, equals(60));
      expect(totals.spentSeconds, equals(3600));
      expect(totals.remainingMinutes, equals(60));
      expect(totals.remainingSeconds, equals(3600));
      expect(totals.progressPercent, equals(50));
      expect(totals.isExhausted, isFalse);
      expect(totals.isOverBudget, isFalse);
      expect(totals.sessionCount, equals(1));
    });

    test('calculateTotals includes activeRunningSeconds for live real-time sync', () {
      final totals = FlutterTimeEngine.calculateTotals(
        category: testCategory,
        sessions: [],
        transactions: [],
        weekPeriodId: '2026-W42',
        activeRunningSeconds: 1800, // 30 mins running in background
      );

      expect(totals.spentMinutes, equals(30));
      expect(totals.spentSeconds, equals(1800));
      expect(totals.remainingMinutes, equals(90));
      expect(totals.progressPercent, equals(25));
      expect(totals.sessionCount, equals(1));
    });

    test('transfers correctly modify effectiveTarget and maintain zero-sum invariant', () {
      final transactions = [
        // 30 mins transferred into category
        PoolTransactionModel(
          id: 'tx-1',
          type: 'pool_to_category',
          targetCategoryId: 'cat-test',
          minutes: 30,
          weekPeriodId: '2026-W42',
          timestamp: now,
        ),
        // 10 mins transferred out of category
        PoolTransactionModel(
          id: 'tx-2',
          type: 'rollover_to_pool',
          sourceCategoryId: 'cat-test',
          minutes: 10,
          weekPeriodId: '2026-W42',
          timestamp: now,
        ),
      ];

      // Base 120 + 30 in - 10 out = 140 effective
      final totals = FlutterTimeEngine.calculateTotals(
        category: testCategory,
        sessions: [],
        transactions: transactions,
        weekPeriodId: '2026-W42',
      );

      expect(totals.transferredInMinutes, equals(30));
      expect(totals.transferredOutMinutes, equals(10));
      expect(totals.effectiveTargetMinutes, equals(140));
      expect(totals.remainingMinutes, equals(140));
    });
  });

  group('FlutterTimeEngine — Free Time Pool Mechanics', () {
    final now = DateTime.now();

    test('calculatePoolBalance correctly balances incoming rollovers and outgoing allocations', () {
      final transactions = [
        PoolTransactionModel(
          id: 'tx-1',
          type: 'rollover_to_pool',
          sourceCategoryId: 'cat-1',
          minutes: 50,
          weekPeriodId: '2026-W42',
          timestamp: now,
        ),
        PoolTransactionModel(
          id: 'tx-2',
          type: 'pool_to_category',
          targetCategoryId: 'cat-2',
          minutes: 20,
          weekPeriodId: '2026-W42',
          timestamp: now,
        ),
      ];

      final pool = FlutterTimeEngine.calculatePoolBalance(
        transactions: transactions,
        weekPeriodId: '2026-W42',
      );

      expect(pool.addedThisWeekMinutes, equals(50));
      expect(pool.usedThisWeekMinutes, equals(20));
      expect(pool.balanceMinutes, equals(30));
    });

    test('undone transactions are strictly ignored in pool calculation', () {
      final transactions = [
        PoolTransactionModel(
          id: 'tx-1',
          type: 'rollover_to_pool',
          sourceCategoryId: 'cat-1',
          minutes: 60,
          weekPeriodId: '2026-W42',
          timestamp: now,
          isUndone: true, // Undone
        ),
      ];

      final pool = FlutterTimeEngine.calculatePoolBalance(
        transactions: transactions,
        weekPeriodId: '2026-W42',
      );

      expect(pool.balanceMinutes, equals(0));
    });

    test('validateTransfer blocks exceeding remaining budget or pool balance', () {
      const dummyTotals = CategoryCalculatedTotals(
        categoryId: 'c1',
        initialTargetMinutes: 60,
        transferredInMinutes: 0,
        transferredOutMinutes: 0,
        effectiveTargetMinutes: 60,
        effectiveTargetSeconds: 3600,
        spentSeconds: 1800,
        spentMinutes: 30,
        remainingSeconds: 1800, // 30 minutes left
        remainingMinutes: 30,
        progressPercent: 50,
        isExhausted: false,
        isOverBudget: false,
        overBudgetSeconds: 0,
        sessionCount: 1,
      );

      // Attempt to transfer 40 mins to pool when only 30 mins remain
      final invalidToPool = FlutterTimeEngine.validateTransfer(
        type: 'to_pool',
        minutes: 40,
        categoryTotals: dummyTotals,
        poolBalanceMinutes: 0,
        categoryPolicy: BudgetPolicy.flexible,
      );
      expect(invalidToPool.isValid, isFalse);
      expect(invalidToPool.errorMessage, contains('30 dakikadır'));

      // Attempt to allocate 50 mins from pool when pool balance is only 15 mins
      final invalidFromPool = FlutterTimeEngine.validateTransfer(
        type: 'from_pool',
        minutes: 50,
        categoryTotals: dummyTotals,
        poolBalanceMinutes: 15,
        categoryPolicy: BudgetPolicy.flexible,
      );
      expect(invalidFromPool.isValid, isFalse);
      expect(invalidFromPool.errorMessage, contains('Havuzda yeterli süre yok'));

      // Protected category requires forceProtected flag
      final protectedCheck = FlutterTimeEngine.validateTransfer(
        type: 'to_pool',
        minutes: 15,
        categoryTotals: dummyTotals,
        poolBalanceMinutes: 0,
        categoryPolicy: BudgetPolicy.protected,
        forceProtected: false,
      );
      expect(protectedCheck.isValid, isFalse);
      expect(protectedCheck.errorMessage, contains('Korunan Zaman modundadır'));
    });
  });

  group('FlutterTimeEngine — Policy Enforcement & Session Gates', () {
    final now = DateTime.now();

    test('strict budget blocks starting when exhausted', () {
      final strictCategory = CategoryModel(
        id: 'cat-strict',
        name: 'Strict Project',
        description: '',
        icon: 'lock',
        colorValue: 0xFFEF4444,
        weeklyTargetMinutes: 60,
        policy: BudgetPolicy.strict,
        createdAt: now,
        updatedAt: now,
      );

      const exhaustedTotals = CategoryCalculatedTotals(
        categoryId: 'cat-strict',
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
        sessionCount: 1,
      );

      final check = FlutterTimeEngine.canStartSession(
        category: strictCategory,
        totals: exhaustedTotals,
      );

      expect(check.isAllowed, isFalse);
      expect(check.blockReason, contains('Katı Bütçe Doldu'));
    });

    test('flexible budget allows starting even when over-budget', () {
      final flexCategory = CategoryModel(
        id: 'cat-flex',
        name: 'Flexible Course',
        description: '',
        icon: 'book',
        colorValue: 0xFF3B82F6,
        weeklyTargetMinutes: 60,
        policy: BudgetPolicy.flexible,
        createdAt: now,
        updatedAt: now,
      );

      const overTotals = CategoryCalculatedTotals(
        categoryId: 'cat-flex',
        initialTargetMinutes: 60,
        transferredInMinutes: 0,
        transferredOutMinutes: 0,
        effectiveTargetMinutes: 60,
        effectiveTargetSeconds: 3600,
        spentSeconds: 4200,
        spentMinutes: 70,
        remainingSeconds: -600,
        remainingMinutes: -10,
        progressPercent: 100,
        isExhausted: true,
        isOverBudget: true,
        overBudgetSeconds: 600,
        sessionCount: 2,
      );

      final check = FlutterTimeEngine.canStartSession(
        category: flexCategory,
        totals: overTotals,
      );

      expect(check.isAllowed, isTrue);
    });
  });
}
