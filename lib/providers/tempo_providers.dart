import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/tempo_database.dart';
import '../domain/models.dart';
import '../domain/time_engine.dart';
import '../services/notification_service.dart';

final databaseProvider = Provider<TempoDatabase>((ref) {
  return TempoDatabase.instance;
});

final currentWeekPeriodProvider = Provider<WeekPeriodInfo>((ref) {
  return FlutterTimeEngine.getWeekPeriod();
});

// --- SETTINGS ---
class SettingsNotifier extends StateNotifier<AppSettingsModel> {
  final TempoDatabase _db;

  SettingsNotifier(this._db) : super(const AppSettingsModel()) {
    _load();
  }

  Future<void> _load() async {
    final s = await _db.getSettings();
    state = s;
  }

  Future<void> setTheme(String theme) async {
    state = state.copyWith(theme: theme);
    await _db.updateSettings(state);
  }

  Future<void> toggleNotifications(bool val) async {
    state = state.copyWith(notificationsEnabled: val);
    await _db.updateSettings(state);
  }

  Future<void> toggleSound(bool val) async {
    state = state.copyWith(soundEnabled: val);
    await _db.updateSettings(state);
  }

  Future<void> toggleVibration(bool val) async {
    state = state.copyWith(vibrationEnabled: val);
    await _db.updateSettings(state);
  }

  Future<void> setDefaultBreak(int minutes) async {
    state = state.copyWith(defaultBreakMinutes: minutes);
    await _db.updateSettings(state);
  }

  Future<void> setDefaultFocusCycle(String cycle) async {
    state = state.copyWith(defaultFocusCycle: cycle);
    await _db.updateSettings(state);
  }
}

final settingsNotifierProvider = StateNotifierProvider<SettingsNotifier, AppSettingsModel>((ref) {
  return SettingsNotifier(ref.watch(databaseProvider));
});

// --- CATEGORIES ---
class CategoriesNotifier extends StateNotifier<List<CategoryModel>> {
  final TempoDatabase _db;

  CategoriesNotifier(this._db) : super([]) {
    loadCategories();
  }

  Future<void> loadCategories() async {
    await _db.initializeSeedDataIfEmpty();
    final list = await _db.getAllCategories();
    state = list;
  }

  Future<void> addCategory(CategoryModel cat) async {
    await _db.insertCategory(cat);
    await loadCategories();
  }

  Future<void> updateCategory(CategoryModel cat) async {
    await _db.updateCategory(cat);
    await loadCategories();
  }

  Future<void> deleteCategory(String id) async {
    await _db.deleteCategory(id);
    await loadCategories();
  }
}

final categoriesNotifierProvider = StateNotifierProvider<CategoriesNotifier, List<CategoryModel>>((ref) {
  return CategoriesNotifier(ref.watch(databaseProvider));
});

// --- TASKS ---
class TasksNotifier extends StateNotifier<List<TaskModel>> {
  final TempoDatabase _db;
  final String _weekPeriodId;

  TasksNotifier(this._db, this._weekPeriodId) : super([]) {
    loadTasks();
  }

  Future<void> loadTasks() async {
    final list = await _db.getTasks(weekPeriodId: _weekPeriodId);
    state = list;
  }

  Future<void> addTask(TaskModel task) async {
    await _db.insertTask(task);
    await loadTasks();
  }

  Future<void> toggleTaskStatus(String taskId) async {
    final idx = state.indexWhere((t) => t.id == taskId);
    if (idx != -1) {
      final task = state[idx];
      final newStatus = task.status == TaskStatus.done ? TaskStatus.todo : TaskStatus.done;
      final updated = task.copyWith(status: newStatus);
      await _db.updateTask(updated);
      await loadTasks();
    }
  }

  Future<void> deleteTask(String id) async {
    await _db.deleteTask(id);
    await loadTasks();
  }
}

final tasksNotifierProvider = StateNotifierProvider<TasksNotifier, List<TaskModel>>((ref) {
  final week = ref.watch(currentWeekPeriodProvider);
  return TasksNotifier(ref.watch(databaseProvider), week.id);
});

// --- SESSIONS ---
class SessionsNotifier extends StateNotifier<List<WorkSessionModel>> {
  final TempoDatabase _db;
  final String _weekPeriodId;

  SessionsNotifier(this._db, this._weekPeriodId) : super([]) {
    loadSessions();
  }

  Future<void> loadSessions() async {
    final list = await _db.getSessionsForWeek(_weekPeriodId);
    state = list;
  }

  Future<void> addSession(WorkSessionModel session) async {
    await _db.insertSession(session);
    await loadSessions();
  }

  Future<void> deleteSession(String id) async {
    await _db.deleteSession(id);
    await loadSessions();
  }
}

final sessionsNotifierProvider = StateNotifierProvider<SessionsNotifier, List<WorkSessionModel>>((ref) {
  final week = ref.watch(currentWeekPeriodProvider);
  return SessionsNotifier(ref.watch(databaseProvider), week.id);
});

// --- TRANSACTIONS ---
class TransactionsNotifier extends StateNotifier<List<PoolTransactionModel>> {
  final TempoDatabase _db;
  final String _weekPeriodId;

  TransactionsNotifier(this._db, this._weekPeriodId) : super([]) {
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    final list = await _db.getTransactionsForWeek(_weekPeriodId);
    state = list;
  }

  Future<void> addTransaction(PoolTransactionModel tx) async {
    await _db.insertTransaction(tx);
    await loadTransactions();
  }

  Future<void> undoTransaction(String txId) async {
    await _db.markTransactionUndone(txId);
    await loadTransactions();
  }
}

final transactionsNotifierProvider = StateNotifierProvider<TransactionsNotifier, List<PoolTransactionModel>>((ref) {
  final week = ref.watch(currentWeekPeriodProvider);
  return TransactionsNotifier(ref.watch(databaseProvider), week.id);
});

// --- CALENDAR EVENTS ---
final calendarEventsProvider = FutureProvider<List<CalendarEventModel>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getCalendarEvents();
});

// --- ACADEMIC MILESTONES ---
final academicMilestonesProvider = FutureProvider<List<AcademicMilestoneModel>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.getAcademicMilestones();
});

// --- ACTIVE SESSION NOTIFIER ---
class ActiveSessionState {
  final bool isActive;
  final String? categoryId;
  final String? taskId;
  final SessionState state; // running, paused, onBreak
  final DateTime? sessionStartTime;
  final DateTime? lastSegmentStartTime;
  final int accumulatedWorkSeconds;
  final int accumulatedBreakSeconds;
  final int plannedBreakMinutes;
  final String focusCycle;
  final String? note;

  const ActiveSessionState({
    this.isActive = false,
    this.categoryId,
    this.taskId,
    this.state = SessionState.idle,
    this.sessionStartTime,
    this.lastSegmentStartTime,
    this.accumulatedWorkSeconds = 0,
    this.accumulatedBreakSeconds = 0,
    this.plannedBreakMinutes = 5,
    this.focusCycle = 'continuous',
    this.note,
  });

  /// Computes exact work seconds using wall-clock time
  int get currentWorkSeconds {
    if (!isActive) return 0;
    if (state == SessionState.running && lastSegmentStartTime != null) {
      final elapsed = DateTime.now().difference(lastSegmentStartTime!).inSeconds;
      return accumulatedWorkSeconds + elapsed;
    }
    return accumulatedWorkSeconds;
  }

  /// Computes exact break seconds remaining
  int get currentBreakElapsedSeconds {
    if (!isActive) return 0;
    if (state == SessionState.onBreak && lastSegmentStartTime != null) {
      final elapsed = DateTime.now().difference(lastSegmentStartTime!).inSeconds;
      return accumulatedBreakSeconds + elapsed;
    }
    return accumulatedBreakSeconds;
  }

  int get currentBreakRemainingSeconds {
    final totalPlannedSeconds = plannedBreakMinutes * 60;
    return totalPlannedSeconds - currentBreakElapsedSeconds;
  }

  ActiveSessionState copyWith({
    bool? isActive,
    String? categoryId,
    String? taskId,
    SessionState? state,
    DateTime? sessionStartTime,
    DateTime? lastSegmentStartTime,
    int? accumulatedWorkSeconds,
    int? accumulatedBreakSeconds,
    int? plannedBreakMinutes,
    String? focusCycle,
    String? note,
  }) {
    return ActiveSessionState(
      isActive: isActive ?? this.isActive,
      categoryId: categoryId ?? this.categoryId,
      taskId: taskId ?? this.taskId,
      state: state ?? this.state,
      sessionStartTime: sessionStartTime ?? this.sessionStartTime,
      lastSegmentStartTime: lastSegmentStartTime ?? this.lastSegmentStartTime,
      accumulatedWorkSeconds: accumulatedWorkSeconds ?? this.accumulatedWorkSeconds,
      accumulatedBreakSeconds: accumulatedBreakSeconds ?? this.accumulatedBreakSeconds,
      plannedBreakMinutes: plannedBreakMinutes ?? this.plannedBreakMinutes,
      focusCycle: focusCycle ?? this.focusCycle,
      note: note ?? this.note,
    );
  }
}

class ActiveSessionNotifier extends StateNotifier<ActiveSessionState> {
  final Ref _ref;
  Timer? _ticker;

  ActiveSessionNotifier(this._ref) : super(const ActiveSessionState());

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.isActive) {
        state = state.copyWith(); // triggers UI rebuild with wall-clock calculation

        // Check if break has completed
        if (state.state == SessionState.onBreak && state.currentBreakRemainingSeconds <= 0) {
          NotificationService.instance.showBreakCompletedNotification();
        }
      }
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  bool startSession({
    required String categoryId,
    String? taskId,
    String focusCycle = 'continuous',
    String? note,
  }) {
    // Only one active session at a time
    if (state.isActive) {
      return false;
    }

    final now = DateTime.now();
    state = ActiveSessionState(
      isActive: true,
      categoryId: categoryId,
      taskId: taskId,
      state: SessionState.running,
      sessionStartTime: now,
      lastSegmentStartTime: now,
      accumulatedWorkSeconds: 0,
      accumulatedBreakSeconds: 0,
      focusCycle: focusCycle,
      note: note,
    );

    _startTicker();
    return true;
  }

  void pauseSession() {
    if (!state.isActive || state.state != SessionState.running) return;

    final now = DateTime.now();
    final elapsed = now.difference(state.lastSegmentStartTime!).inSeconds;

    state = state.copyWith(
      state: SessionState.paused,
      accumulatedWorkSeconds: state.accumulatedWorkSeconds + elapsed,
      lastSegmentStartTime: now,
    );
  }

  void resumeSession() {
    if (!state.isActive || state.state == SessionState.running) return;

    final now = DateTime.now();
    int newBreakAccum = state.accumulatedBreakSeconds;

    if (state.state == SessionState.onBreak) {
      final elapsedBreak = now.difference(state.lastSegmentStartTime!).inSeconds;
      newBreakAccum += elapsedBreak;
    }

    state = state.copyWith(
      state: SessionState.running,
      accumulatedBreakSeconds: newBreakAccum,
      lastSegmentStartTime: now,
    );
  }

  void startBreak(int minutes) {
    if (!state.isActive) return;

    final now = DateTime.now();
    int newWorkAccum = state.accumulatedWorkSeconds;

    if (state.state == SessionState.running) {
      newWorkAccum += now.difference(state.lastSegmentStartTime!).inSeconds;
    }

    state = state.copyWith(
      state: SessionState.onBreak,
      plannedBreakMinutes: minutes,
      accumulatedWorkSeconds: newWorkAccum,
      lastSegmentStartTime: now,
    );
  }

  void adjustMinutes(int deltaMinutes) {
    if (!state.isActive) return;
    final deltaSeconds = deltaMinutes * 60;
    final newSeconds = (state.accumulatedWorkSeconds + deltaSeconds).clamp(0, 86400);
    state = state.copyWith(accumulatedWorkSeconds: newSeconds);
  }

  Future<WorkSessionModel?> finishSession() async {
    if (!state.isActive) return null;

    final now = DateTime.now();
    int totalWork = state.accumulatedWorkSeconds;
    int totalBreak = state.accumulatedBreakSeconds;

    if (state.state == SessionState.running && state.lastSegmentStartTime != null) {
      totalWork += now.difference(state.lastSegmentStartTime!).inSeconds;
    } else if (state.state == SessionState.onBreak && state.lastSegmentStartTime != null) {
      totalBreak += now.difference(state.lastSegmentStartTime!).inSeconds;
    }

    final week = _ref.read(currentWeekPeriodProvider);
    final categoryId = state.categoryId!;
    final taskId = state.taskId;

    final session = WorkSessionModel(
      id: const Uuid().v4(),
      categoryId: categoryId,
      taskId: taskId,
      startTime: state.sessionStartTime ?? now,
      endTime: now,
      state: SessionState.completed,
      activeSeconds: totalWork,
      breakSeconds: totalBreak,
      note: state.note,
      weekPeriodId: week.id,
      createdAt: state.sessionStartTime ?? now,
      updatedAt: now,
    );

    // Save to Database
    await _ref.read(sessionsNotifierProvider.notifier).addSession(session);

    // Categories lookup for notification
    final categories = _ref.read(categoriesNotifierProvider);
    final cat = categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => CategoryModel(
        id: categoryId,
        name: 'Oturum',
        description: '',
        icon: 'circle',
        colorValue: 0xFF2563EB,
        weeklyTargetMinutes: 60,
        policy: BudgetPolicy.flexible,
        createdAt: now,
        updatedAt: now,
      ),
    );

    NotificationService.instance.showTimerCompletedNotification(
      categoryName: cat.name,
      durationText: FlutterTimeEngine.formatMinutes((totalWork / 60).round()),
    );

    cancelSession();
    return session;
  }

  void cancelSession() {
    _stopTicker();
    state = const ActiveSessionState();
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }
}

final activeSessionNotifierProvider = StateNotifierProvider<ActiveSessionNotifier, ActiveSessionState>((ref) {
  return ActiveSessionNotifier(ref);
});

// --- TOTALS & SUMMARIES ---
final categoryTotalsMapProvider = Provider<Map<String, CategoryCalculatedTotals>>((ref) {
  final categories = ref.watch(categoriesNotifierProvider);
  final sessions = ref.watch(sessionsNotifierProvider);
  final transactions = ref.watch(transactionsNotifierProvider);
  final week = ref.watch(currentWeekPeriodProvider);
  final active = ref.watch(activeSessionNotifierProvider);

  final map = <String, CategoryCalculatedTotals>{};

  for (final cat in categories) {
    final runningSecs = (active.isActive && active.categoryId == cat.id)
        ? active.currentWorkSeconds
        : 0;

    final totals = FlutterTimeEngine.calculateTotals(
      category: cat,
      sessions: sessions,
      transactions: transactions,
      weekPeriodId: week.id,
      activeRunningSeconds: runningSecs,
    );
    map[cat.id] = totals;
  }

  return map;
});

final poolBalanceProvider = Provider<PoolBalanceTotals>((ref) {
  final transactions = ref.watch(transactionsNotifierProvider);
  final week = ref.watch(currentWeekPeriodProvider);
  return FlutterTimeEngine.calculatePoolBalance(
    transactions: transactions,
    weekPeriodId: week.id,
  );
});

class WeeklyBudgetSummary {
  final int totalTargetMinutes;
  final int totalSpentMinutes;
  final int totalRemainingMinutes;
  final int poolBalanceMinutes;
  final int completedCategoriesCount;
  final int activeCategoriesCount;

  const WeeklyBudgetSummary({
    required this.totalTargetMinutes,
    required this.totalSpentMinutes,
    required this.totalRemainingMinutes,
    required this.poolBalanceMinutes,
    required this.completedCategoriesCount,
    required this.activeCategoriesCount,
  });
}

final weeklySummaryProvider = Provider<WeeklyBudgetSummary>((ref) {
  final totalsMap = ref.watch(categoryTotalsMapProvider);
  final pool = ref.watch(poolBalanceProvider);

  int totalTarget = 0;
  int totalSpent = 0;
  int totalRemaining = 0;
  int completedCount = 0;

  for (final t in totalsMap.values) {
    totalTarget += t.effectiveTargetMinutes;
    totalSpent += t.spentMinutes;
    totalRemaining += t.remainingMinutes;
    if (t.isExhausted) {
      completedCount++;
    }
  }

  return WeeklyBudgetSummary(
    totalTargetMinutes: totalTarget,
    totalSpentMinutes: totalSpent,
    totalRemainingMinutes: totalRemaining,
    poolBalanceMinutes: pool.balanceMinutes,
    completedCategoriesCount: completedCount,
    activeCategoriesCount: totalsMap.length,
  );
});
