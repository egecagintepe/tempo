import 'dart:math';
import 'models.dart';

class CategoryCalculatedTotals {
  final String categoryId;
  final int initialTargetMinutes;
  final int transferredInMinutes;
  final int transferredOutMinutes;
  final int effectiveTargetMinutes;
  final int effectiveTargetSeconds;
  final int spentSeconds;
  final int spentMinutes;
  final int remainingSeconds;
  final int remainingMinutes;
  final int progressPercent;
  final bool isExhausted;
  final bool isOverBudget;
  final int overBudgetSeconds;
  final int sessionCount;

  const CategoryCalculatedTotals({
    required this.categoryId,
    required this.initialTargetMinutes,
    required this.transferredInMinutes,
    required this.transferredOutMinutes,
    required this.effectiveTargetMinutes,
    required this.effectiveTargetSeconds,
    required this.spentSeconds,
    required this.spentMinutes,
    required this.remainingSeconds,
    required this.remainingMinutes,
    required this.progressPercent,
    required this.isExhausted,
    required this.isOverBudget,
    required this.overBudgetSeconds,
    required this.sessionCount,
  });
}

class PoolBalanceTotals {
  final int balanceMinutes;
  final int addedThisWeekMinutes;
  final int usedThisWeekMinutes;

  const PoolBalanceTotals({
    required this.balanceMinutes,
    required this.addedThisWeekMinutes,
    required this.usedThisWeekMinutes,
  });
}

class WeekPeriodInfo {
  final String id;
  final DateTime start;
  final DateTime end;

  const WeekPeriodInfo({
    required this.id,
    required this.start,
    required this.end,
  });
}

class TransferValidationResult {
  final bool isValid;
  final String? errorMessage;

  const TransferValidationResult({required this.isValid, this.errorMessage});
}

class SessionPermissionResult {
  final bool isAllowed;
  final String? blockReason;

  const SessionPermissionResult({required this.isAllowed, this.blockReason});
}

class FlutterTimeEngine {
  /// Returns ISO week period string (e.g. "2026-W42") and boundaries (Mon 00:00 to Sun 23:59:59)
  static WeekPeriodInfo getWeekPeriod([DateTime? date]) {
    final now = date ?? DateTime.now();
    // Monday is 1, Sunday is 7 in Dart DateTime.weekday
    final mondayDiff = now.weekday - DateTime.monday;
    final monday = DateTime(now.year, now.month, now.day - mondayDiff, 0, 0, 0);
    final sunday = DateTime(monday.year, monday.month, monday.day + 6, 23, 59, 59, 999);

    // Calculate ISO 8601 week number
    final d = DateTime.utc(now.year, now.month, now.day);
    final dayNum = d.weekday;
    final thursday = d.add(Duration(days: 4 - dayNum));
    final yearStart = DateTime.utc(thursday.year, 1, 1);
    final weekNo = ((thursday.difference(yearStart).inDays) / 7).floor() + 1;
    final weekId = '${thursday.year}-W${weekNo.toString().padLeft(2, '0')}';

    return WeekPeriodInfo(id: weekId, start: monday, end: sunday);
  }

  /// Formats minutes into human-readable Turkish time string (e.g. 150 -> "2s 30dk", -20 -> "-20dk")
  static String formatMinutes(int minutes) {
    final isNeg = minutes < 0;
    final absMin = minutes.abs();
    final h = absMin ~/ 60;
    final m = absMin % 60;
    final sign = isNeg ? '-' : '';

    if (h == 0) return '$sign${m}dk';
    if (m == 0) return '$sign${h}s';
    return '$sign${h}s ${m}dk';
  }

  /// Formats seconds into digital stopwatch format (e.g. 3665 -> "01:01:05" or "01:05")
  static String formatStopwatch(int seconds, {bool forceHours = true}) {
    final isNeg = seconds < 0;
    final absSec = seconds.abs();
    final h = absSec ~/ 3600;
    final m = (absSec % 3600) ~/ 60;
    final s = absSec % 60;

    String pad(int n) => n.toString().padLeft(2, '0');
    final sign = isNeg ? '-' : '';

    if (forceHours || h > 0) {
      return '$sign${pad(h)}:${pad(m)}:${pad(s)}';
    }
    return '$sign${pad(m)}:${pad(s)}';
  }

  /// Calculates accurate budget totals for a category in a given week.
  /// Enforces:
  /// effectiveTarget = baseTarget + transferredIn - transferredOut
  /// remaining = effectiveTarget - spent
  static CategoryCalculatedTotals calculateTotals({
    required CategoryModel category,
    required List<WorkSessionModel> sessions,
    required List<PoolTransactionModel> transactions,
    required String weekPeriodId,
    int activeRunningSeconds = 0,
  }) {
    final initialTargetMinutes = category.weeklyTargetMinutes;

    int transferIn = 0;
    int transferOut = 0;

    for (final tx in transactions) {
      if (!tx.isUndone && tx.weekPeriodId == weekPeriodId) {
        if (tx.targetCategoryId == category.id) {
          transferIn += tx.minutes;
        }
        if (tx.sourceCategoryId == category.id) {
          transferOut += tx.minutes;
        }
      }
    }

    final effectiveTargetMinutes = max(0, initialTargetMinutes + transferIn - transferOut);
    final effectiveTargetSeconds = effectiveTargetMinutes * 60;

    int spentSeconds = 0;
    int sessionCount = 0;

    for (final s in sessions) {
      if (s.categoryId == category.id && s.weekPeriodId == weekPeriodId) {
        spentSeconds += s.activeSeconds;
        sessionCount++;
      }
    }

    spentSeconds += activeRunningSeconds;
    if (activeRunningSeconds > 0) {
      sessionCount++;
    }

    final spentMinutes = (spentSeconds / 60).round();
    final remainingSeconds = effectiveTargetSeconds - spentSeconds;
    final remainingMinutes = (remainingSeconds / 60).round();

    final progressPercent = effectiveTargetSeconds > 0
        ? min(100, (spentSeconds / effectiveTargetSeconds * 100).round())
        : (spentSeconds > 0 ? 100 : 0);

    final isExhausted = remainingSeconds <= 0;
    final isOverBudget = remainingSeconds < 0;
    final overBudgetSeconds = isOverBudget ? remainingSeconds.abs() : 0;

    return CategoryCalculatedTotals(
      categoryId: category.id,
      initialTargetMinutes: initialTargetMinutes,
      transferredInMinutes: transferIn,
      transferredOutMinutes: transferOut,
      effectiveTargetMinutes: effectiveTargetMinutes,
      effectiveTargetSeconds: effectiveTargetSeconds,
      spentSeconds: spentSeconds,
      spentMinutes: spentMinutes,
      remainingSeconds: remainingSeconds,
      remainingMinutes: remainingMinutes,
      progressPercent: progressPercent,
      isExhausted: isExhausted,
      isOverBudget: isOverBudget,
      overBudgetSeconds: overBudgetSeconds,
      sessionCount: sessionCount,
    );
  }

  /// Calculates current Free Time Pool balance in minutes.
  /// poolBalance = sum(transfers_into_pool) - sum(transfers_out_of_pool)
  static PoolBalanceTotals calculatePoolBalance({
    required List<PoolTransactionModel> transactions,
    required String weekPeriodId,
  }) {
    int incoming = 0;
    int outgoing = 0;

    for (final tx in transactions) {
      if (!tx.isUndone && tx.weekPeriodId == weekPeriodId) {
        if (tx.type == 'rollover_to_pool' || tx.targetCategoryId == null) {
          incoming += tx.minutes;
        } else if (tx.type == 'pool_to_category' || tx.sourceCategoryId == null) {
          outgoing += tx.minutes;
        }
      }
    }

    final balance = max(0, incoming - outgoing);

    return PoolBalanceTotals(
      balanceMinutes: balance,
      addedThisWeekMinutes: incoming,
      usedThisWeekMinutes: outgoing,
    );
  }

  /// Validates a transfer request between pool and category.
  static TransferValidationResult validateTransfer({
    required String type, // 'to_pool' | 'from_pool'
    required int minutes,
    required CategoryCalculatedTotals categoryTotals,
    required int poolBalanceMinutes,
    required BudgetPolicy categoryPolicy,
    bool forceProtected = false,
  }) {
    if (minutes <= 0) {
      return const TransferValidationResult(
        isValid: false,
        errorMessage: 'Aktarılacak süre 0 dakikadan büyük olmalıdır.',
      );
    }

    if (type == 'to_pool') {
      if (categoryPolicy == BudgetPolicy.protected && !forceProtected) {
        return const TransferValidationResult(
          isValid: false,
          errorMessage: 'Bu kategori Korunan Zaman modundadır. Süre aktarımı özel onay gerektirir.',
        );
      }
      final maxAvailable = max(0, categoryTotals.remainingSeconds ~/ 60);
      if (minutes > maxAvailable) {
        return TransferValidationResult(
          isValid: false,
          errorMessage: 'Aktarılabilir en fazla süre $maxAvailable dakikadır (Kalan bütçe: ${formatMinutes(maxAvailable)}).',
        );
      }
    } else if (type == 'from_pool') {
      if (minutes > poolBalanceMinutes) {
        return TransferValidationResult(
          isValid: false,
          errorMessage: 'Havuzda yeterli süre yok. Mevcut bakiye: ${formatMinutes(poolBalanceMinutes)}.',
        );
      }
    }

    return const TransferValidationResult(isValid: true);
  }

  /// Enforces Category Budget Policies before starting a session
  static SessionPermissionResult canStartSession({
    required CategoryModel category,
    required CategoryCalculatedTotals totals,
  }) {
    if (category.isArchived) {
      return const SessionPermissionResult(
        isAllowed: false,
        blockReason: 'Arşivlenmiş kategoride yeni oturum başlatılamaz.',
      );
    }

    if (category.policy == BudgetPolicy.strict && totals.isExhausted) {
      return const SessionPermissionResult(
        isAllowed: false,
        blockReason: 'Katı Bütçe Doldu! Bu haftalık ayrılan süre tükendi. Ek çalışma için bütçeyi artırın veya serbest havuzdan süre aktarın.',
      );
    }

    return const SessionPermissionResult(isAllowed: true);
  }

  /// Aggregates spent seconds per day of the week (1=Mon ... 7=Sun)
  static Map<int, int> calculateDayDistribution({
    required List<WorkSessionModel> sessions,
    required String weekPeriodId,
  }) {
    final Map<int, int> distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    for (final s in sessions) {
      if (s.weekPeriodId == weekPeriodId) {
        final day = s.startTime.weekday;
        distribution[day] = (distribution[day] ?? 0) + s.activeSeconds;
      }
    }
    return distribution;
  }
}
