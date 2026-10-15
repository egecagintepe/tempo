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

// --- WEEKLY BUDGETS ---
class WeeklyBudgetsNotifier extends StateNotifier<List<WeeklyBudgetModel>> {
  final TempoDatabase _db;
  final String _weekPeriodId;

  WeeklyBudgetsNotifier(this._db, this._weekPeriodId) : super([]) {
    loadBudgets();
  }

  Future<void> loadBudgets() async {
    final list = await _db.getWeeklyBudgets(_weekPeriodId);
    state = list;
  }

  Future<void> updateAllocatedMinutes(String categoryId, int allocatedMinutes) async {
    await _db.updateWeeklyBudgetAllocatedMinutes(
      categoryId: categoryId,
      weekPeriodId: _weekPeriodId,
      allocatedMinutes: allocatedMinutes,
    );
    await loadBudgets();
  }
}

final weeklyBudgetsNotifierProvider = StateNotifierProvider<WeeklyBudgetsNotifier, List<WeeklyBudgetModel>>((ref) {
  final week = ref.watch(currentWeekPeriodProvider);
  return WeeklyBudgetsNotifier(ref.watch(databaseProvider), week.id);
});

// --- POOL PROMPT STATE ---
class PoolPromptState {
  final String? categoryId;
  final String? categoryName;
  final int remainingMinutes;

  const PoolPromptState({this.categoryId, this.categoryName, this.remainingMinutes = 0});
  bool get hasPrompt => categoryId != null && remainingMinutes > 0;
}

class PoolPromptNotifier extends StateNotifier<PoolPromptState> {
  PoolPromptNotifier() : super(const PoolPromptState());

  void showPrompt({required String categoryId, required String categoryName, required int remainingMinutes}) {
    state = PoolPromptState(categoryId: categoryId, categoryName: categoryName, remainingMinutes: remainingMinutes);
  }

  void dismiss() {
    state = const PoolPromptState();
  }
}

final poolPromptProvider = StateNotifierProvider<PoolPromptNotifier, PoolPromptState>((ref) {
  return PoolPromptNotifier();
});

// --- TASKS ---
class TasksNotifier extends StateNotifier<List<TaskModel>> {
  final TempoDatabase _db;
  final String _weekPeriodId;
  final Ref _ref;

  TasksNotifier(this._db, this._weekPeriodId, this._ref) : super([]) {
    loadTasks();
  }

  Future<void> loadTasks() async {
    await _db.ensureWeekRollover(_weekPeriodId);
    final list = await _db.getAllTasks(weekPeriodId: _weekPeriodId);
    state = list;
  }

  Future<void> addTask(TaskModel task) async {
    await _db.insertTask(task);
    await loadTasks();
  }

  Future<void> updateTask(TaskModel task) async {
    await _db.updateTask(task);
    await loadTasks();
  }

  Future<void> toggleTaskStatus(String taskId) async {
    final idx = state.indexWhere((t) => t.id == taskId);
    if (idx != -1) {
      final task = state[idx];
      final isNowDone = task.status != TaskStatus.done;
      final newStatus = isNowDone ? TaskStatus.done : TaskStatus.todo;
      final completedAt = isNowDone ? DateTime.now() : null;
      final updated = task.copyWith(status: newStatus, completedAt: completedAt);
      await _db.updateTask(updated);
      await loadTasks();

      if (isNowDone) {
        // Completion-first pool suggestion trigger:
        final catTasks = state.where((t) => t.categoryId == task.categoryId).toList();
        final allDone = catTasks.isNotEmpty && catTasks.every((t) => t.status == TaskStatus.done);
        if (allDone) {
          final totals = _ref.read(categoryTotalsMapProvider)[task.categoryId];
          final categories = _ref.read(categoriesNotifierProvider);
          final cat = categories.firstWhere(
            (c) => c.id == task.categoryId,
            orElse: () => CategoryModel(
              id: task.categoryId,
              name: 'Kategori',
              description: '',
              icon: 'circle',
              colorValue: 0xFF2563EB,
              weeklyTargetMinutes: 60,
              policy: BudgetPolicy.flexible,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          if (totals != null && totals.remainingMinutes > 0 && cat.policy != BudgetPolicy.protected) {
            _ref.read(poolPromptProvider.notifier).showPrompt(
              categoryId: task.categoryId,
              categoryName: cat.name,
              remainingMinutes: totals.remainingMinutes,
            );
          }
        }
      }
    }
  }

  Future<void> toggleSubtask(String taskId, String subtaskId) async {
    final taskIdx = state.indexWhere((t) => t.id == taskId);
    if (taskIdx != -1) {
      final task = state[taskIdx];
      final newSubtasks = task.subtasks.map((s) {
        if (s.id == subtaskId) {
          return s.copyWith(isCompleted: !s.isCompleted);
        }
        return s;
      }).toList();
      final updated = task.copyWith(subtasks: newSubtasks);
      await _db.updateTask(updated);
      await loadTasks();
    }
  }

  Future<void> deferTask(String taskId, String newPlannedDate) async {
    await _db.deferTask(taskId, newPlannedDate);
    await loadTasks();
  }

  Future<void> deleteTask(String id) async {
    await _db.deleteTask(id);
    await loadTasks();
  }
}

final tasksNotifierProvider = StateNotifierProvider<TasksNotifier, List<TaskModel>>((ref) {
  final week = ref.watch(currentWeekPeriodProvider);
  return TasksNotifier(ref.watch(databaseProvider), week.id, ref);
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

  ActiveSessionNotifier(this._ref) : super(const ActiveSessionState()) {
    _recoverActiveSession();
  }

  Future<void> _recoverActiveSession() async {
    final db = _ref.read(databaseProvider);
    final rec = await db.getActiveSession();
    if (rec == null) return;

    final now = DateTime.now();
    final categories = await db.getAllCategories();
    final cat = categories.firstWhere(
      (c) => c.id == rec.categoryId,
      orElse: () => CategoryModel(
        id: rec.categoryId,
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

    int recoveredWorkSecs = rec.accumulatedWorkSeconds;
    int recoveredBreakSecs = rec.accumulatedBreakSeconds;
    SessionState recoveredState = rec.state;
    DateTime recoveredSegmentStart = rec.lastSegmentStartTime;

    if (rec.state == SessionState.running) {
      final elapsed = now.difference(rec.lastSegmentStartTime).inSeconds;
      if (cat.policy == BudgetPolicy.strict) {
        final sessions = await db.getSessionsForWeek(rec.weekPeriodId);
        final txs = await db.getTransactionsForWeek(rec.weekPeriodId);
        final totals = FlutterTimeEngine.calculateTotals(
          category: cat,
          sessions: sessions,
          transactions: txs,
          weekPeriodId: rec.weekPeriodId,
        );

        final availableSecs = (totals.remainingSeconds - rec.accumulatedWorkSeconds).clamp(0, 86400 * 7);
        if (elapsed >= availableSecs) {
          // Strict budget was exhausted while app was away: clamp and auto-pause
          recoveredWorkSecs += availableSecs;
          recoveredState = SessionState.paused;
          recoveredSegmentStart = now;
        } else {
          recoveredWorkSecs += elapsed;
          recoveredSegmentStart = now;
        }
      } else {
        recoveredWorkSecs += elapsed;
        recoveredSegmentStart = now;
      }
    } else if (rec.state == SessionState.onBreak) {
      final elapsedBreak = now.difference(rec.lastSegmentStartTime).inSeconds;
      recoveredBreakSecs += elapsedBreak;
      recoveredSegmentStart = now;
    }

    state = ActiveSessionState(
      isActive: true,
      categoryId: rec.categoryId,
      taskId: rec.taskId,
      state: recoveredState,
      sessionStartTime: rec.sessionStartTime,
      lastSegmentStartTime: recoveredSegmentStart,
      accumulatedWorkSeconds: recoveredWorkSecs,
      accumulatedBreakSeconds: recoveredBreakSecs,
      plannedBreakMinutes: rec.plannedBreakMinutes,
      focusCycle: rec.focusCycle,
      note: rec.note,
    );

    // Update SQLite with the recovered state
    await db.saveActiveSession(ActiveSessionRecord(
      categoryId: rec.categoryId,
      taskId: rec.taskId,
      state: recoveredState,
      sessionStartTime: rec.sessionStartTime,
      lastSegmentStartTime: recoveredSegmentStart,
      accumulatedWorkSeconds: recoveredWorkSecs,
      accumulatedBreakSeconds: recoveredBreakSecs,
      plannedBreakMinutes: rec.plannedBreakMinutes,
      focusCycle: rec.focusCycle,
      note: rec.note,
      weekPeriodId: rec.weekPeriodId,
      createdAt: rec.createdAt,
      updatedAt: now,
    ));

    if (recoveredState == SessionState.running || recoveredState == SessionState.onBreak) {
      _startTicker();
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!state.isActive) return;

      if (state.state == SessionState.running && state.categoryId != null) {
        final categories = _ref.read(categoriesNotifierProvider);
        final cat = categories.firstWhere(
          (c) => c.id == state.categoryId,
          orElse: () => CategoryModel(
            id: state.categoryId!,
            name: 'Oturum',
            description: '',
            icon: 'circle',
            colorValue: 0xFF2563EB,
            weeklyTargetMinutes: 60,
            policy: BudgetPolicy.flexible,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        if (cat.policy == BudgetPolicy.strict) {
          final totals = _ref.read(categoryTotalsMapProvider)[cat.id];
          if (totals != null) {
            if (totals.remainingSeconds <= 0 && state.currentWorkSeconds > 0) {
              pauseSession();
              NotificationService.instance.showTimerCompletedNotification(
                categoryName: cat.name,
                durationText: FlutterTimeEngine.formatMinutes((totals.effectiveTargetSeconds / 60).round()),
              );
              return;
            }
          }
        }
      }

      if (state.state == SessionState.onBreak && state.currentBreakRemainingSeconds <= 0) {
        NotificationService.instance.showBreakCompletedNotification();
      }

      state = state.copyWith();
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  Future<SessionPermissionResult> startSession({
    required String categoryId,
    String? taskId,
    String focusCycle = 'continuous',
    String? note,
  }) async {
    if (state.isActive) {
      return const SessionPermissionResult(
        isAllowed: false,
        blockReason: 'Zaten aktif bir odak oturumu devam ediyor.',
      );
    }

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
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final week = _ref.read(currentWeekPeriodProvider);
    final sessions = _ref.read(sessionsNotifierProvider);
    final transactions = _ref.read(transactionsNotifierProvider);

    final totals = FlutterTimeEngine.calculateTotals(
      category: cat,
      sessions: sessions,
      transactions: transactions,
      weekPeriodId: week.id,
    );

    final permission = FlutterTimeEngine.canStartSession(
      category: cat,
      totals: totals,
    );

    if (!permission.isAllowed) {
      return permission;
    }

    final now = DateTime.now();
    final db = _ref.read(databaseProvider);

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

    await db.saveActiveSession(ActiveSessionRecord(
      categoryId: categoryId,
      taskId: taskId,
      state: SessionState.running,
      sessionStartTime: now,
      lastSegmentStartTime: now,
      accumulatedWorkSeconds: 0,
      accumulatedBreakSeconds: 0,
      plannedBreakMinutes: 5,
      focusCycle: focusCycle,
      note: note,
      weekPeriodId: week.id,
      createdAt: now,
      updatedAt: now,
    ));

    if (cat.policy == BudgetPolicy.strict && totals.remainingSeconds > 0) {
      await NotificationService.instance.scheduleTimerCompletedNotification(
        categoryName: cat.name,
        scheduledDate: now.add(Duration(seconds: totals.remainingSeconds)),
      );
    }

    _startTicker();
    return const SessionPermissionResult(isAllowed: true);
  }

  Future<void> pauseSession() async {
    if (!state.isActive || state.state != SessionState.running) return;

    final now = DateTime.now();
    final elapsed = now.difference(state.lastSegmentStartTime!).inSeconds;
    final totalWork = state.accumulatedWorkSeconds + elapsed;

    state = state.copyWith(
      state: SessionState.paused,
      accumulatedWorkSeconds: totalWork,
      lastSegmentStartTime: now,
    );

    final db = _ref.read(databaseProvider);
    final week = _ref.read(currentWeekPeriodProvider);

    await db.saveActiveSession(ActiveSessionRecord(
      categoryId: state.categoryId!,
      taskId: state.taskId,
      state: SessionState.paused,
      sessionStartTime: state.sessionStartTime ?? now,
      lastSegmentStartTime: now,
      accumulatedWorkSeconds: totalWork,
      accumulatedBreakSeconds: state.accumulatedBreakSeconds,
      plannedBreakMinutes: state.plannedBreakMinutes,
      focusCycle: state.focusCycle,
      note: state.note,
      weekPeriodId: week.id,
      createdAt: state.sessionStartTime ?? now,
      updatedAt: now,
    ));

    await NotificationService.instance.cancelScheduledTimerNotifications();
  }

  Future<void> resumeSession() async {
    if (!state.isActive || state.state == SessionState.running) return;

    final now = DateTime.now();
    int newBreakAccum = state.accumulatedBreakSeconds;

    if (state.state == SessionState.onBreak && state.lastSegmentStartTime != null) {
      final elapsedBreak = now.difference(state.lastSegmentStartTime!).inSeconds;
      newBreakAccum += elapsedBreak;
    }

    state = state.copyWith(
      state: SessionState.running,
      accumulatedBreakSeconds: newBreakAccum,
      lastSegmentStartTime: now,
    );

    final db = _ref.read(databaseProvider);
    final week = _ref.read(currentWeekPeriodProvider);

    await db.saveActiveSession(ActiveSessionRecord(
      categoryId: state.categoryId!,
      taskId: state.taskId,
      state: SessionState.running,
      sessionStartTime: state.sessionStartTime ?? now,
      lastSegmentStartTime: now,
      accumulatedWorkSeconds: state.accumulatedWorkSeconds,
      accumulatedBreakSeconds: newBreakAccum,
      plannedBreakMinutes: state.plannedBreakMinutes,
      focusCycle: state.focusCycle,
      note: state.note,
      weekPeriodId: week.id,
      createdAt: state.sessionStartTime ?? now,
      updatedAt: now,
    ));

    final categories = _ref.read(categoriesNotifierProvider);
    final cat = categories.firstWhere(
      (c) => c.id == state.categoryId,
      orElse: () => throw Exception('Kategori bulunamadı'),
    );

    if (cat.policy == BudgetPolicy.strict) {
      final totals = _ref.read(categoryTotalsMapProvider)[cat.id];
      if (totals != null) {
        final availableSecs = totals.remainingSeconds - state.accumulatedWorkSeconds;
        if (availableSecs > 0) {
          await NotificationService.instance.scheduleTimerCompletedNotification(
            categoryName: cat.name,
            scheduledDate: now.add(Duration(seconds: availableSecs)),
          );
        }
      }
    }
  }

  Future<void> startBreak(int minutes) async {
    if (!state.isActive) return;

    final now = DateTime.now();
    int newWorkAccum = state.accumulatedWorkSeconds;

    if (state.state == SessionState.running && state.lastSegmentStartTime != null) {
      newWorkAccum += now.difference(state.lastSegmentStartTime!).inSeconds;
    }

    state = state.copyWith(
      state: SessionState.onBreak,
      plannedBreakMinutes: minutes,
      accumulatedWorkSeconds: newWorkAccum,
      lastSegmentStartTime: now,
    );

    final db = _ref.read(databaseProvider);
    final week = _ref.read(currentWeekPeriodProvider);

    await db.saveActiveSession(ActiveSessionRecord(
      categoryId: state.categoryId!,
      taskId: state.taskId,
      state: SessionState.onBreak,
      sessionStartTime: state.sessionStartTime ?? now,
      lastSegmentStartTime: now,
      accumulatedWorkSeconds: newWorkAccum,
      accumulatedBreakSeconds: state.accumulatedBreakSeconds,
      plannedBreakMinutes: minutes,
      focusCycle: state.focusCycle,
      note: state.note,
      weekPeriodId: week.id,
      createdAt: state.sessionStartTime ?? now,
      updatedAt: now,
    ));

    await NotificationService.instance.cancelScheduledTimerNotifications();
    await NotificationService.instance.scheduleBreakCompletedNotification(
      scheduledDate: now.add(Duration(minutes: minutes)),
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

    if (cat.policy == BudgetPolicy.strict) {
      final totals = _ref.read(categoryTotalsMapProvider)[categoryId];
      if (totals != null) {
        final maxSecs = totals.remainingSeconds;
        if (totalWork > maxSecs && maxSecs > 0) {
          totalWork = maxSecs;
        }
      }
    }

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

    final db = _ref.read(databaseProvider);
    await db.completeActiveSessionTransaction(session);

    await _ref.read(sessionsNotifierProvider.notifier).loadSessions();
    if (taskId != null) {
      await _ref.read(tasksNotifierProvider.notifier).loadTasks();
    }

    await NotificationService.instance.cancelScheduledTimerNotifications();

    NotificationService.instance.showTimerCompletedNotification(
      categoryName: cat.name,
      durationText: FlutterTimeEngine.formatMinutes((totalWork / 60).round()),
    );

    await cancelSession();
    return session;
  }

  Future<void> cancelSession() async {
    _stopTicker();
    final db = _ref.read(databaseProvider);
    await db.clearActiveSession();
    await NotificationService.instance.cancelScheduledTimerNotifications();
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
  final budgets = ref.watch(weeklyBudgetsNotifierProvider);
  final week = ref.watch(currentWeekPeriodProvider);
  final active = ref.watch(activeSessionNotifierProvider);

  final budgetMap = {for (final b in budgets) b.categoryId: b.allocatedMinutes};

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
      allocatedMinutes: budgetMap[cat.id],
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

// --- COURSE TOPICS ---
class CourseTopicsNotifier extends StateNotifier<List<CourseTopicModel>> {
  final TempoDatabase _db;

  CourseTopicsNotifier(this._db) : super([]) {
    loadTopics();
  }

  Future<void> loadTopics() async {
    final list = await _db.getCourseTopics();
    state = list;
  }

  Future<void> updateTopic(CourseTopicModel topic) async {
    await _db.updateCourseTopic(topic);
    await loadTopics();
  }

  Future<void> setMasteryLevel(String topicId, MasteryLevel level) async {
    final idx = state.indexWhere((t) => t.id == topicId);
    if (idx != -1) {
      final updated = state[idx].copyWith(masteryLevel: level);
      await _db.updateCourseTopic(updated);
      await loadTopics();
    }
  }

  Future<void> recordPracticeAttempt(String topicId, bool isCorrect) async {
    final idx = state.indexWhere((t) => t.id == topicId);
    if (idx != -1) {
      final curr = state[idx];
      final updated = curr.copyWith(
        questionsAttempted: curr.questionsAttempted + 1,
        questionsCorrect: curr.questionsCorrect + (isCorrect ? 1 : 0),
      );
      await _db.updateCourseTopic(updated);
      await loadTopics();
    }
  }
}

final courseTopicsNotifierProvider = StateNotifierProvider<CourseTopicsNotifier, List<CourseTopicModel>>((ref) {
  return CourseTopicsNotifier(ref.watch(databaseProvider));
});

// --- CALENDAR 2.0 EVENTS ---
class CalendarEventsNotifier extends StateNotifier<List<CalendarEventModel>> {
  final TempoDatabase _db;

  CalendarEventsNotifier(this._db) : super([]) {
    loadEvents();
  }

  Future<void> loadEvents() async {
    final list = await _db.getCalendarEvents();
    state = list;
  }

  Future<void> addEvent(CalendarEventModel event) async {
    await _db.insertCalendarEvent(event);
    await loadEvents();
  }

  Future<void> updateEvent(CalendarEventModel event) async {
    await _db.updateCalendarEvent(event);
    await loadEvents();
  }

  Future<void> deleteEvent(String id) async {
    await _db.deleteCalendarEvent(id);
    await loadEvents();
  }

  Future<void> toggleEventCompleted(String id) async {
    final idx = state.indexWhere((e) => e.id == id);
    if (idx != -1) {
      final evt = state[idx];
      final updated = evt.copyWith(isCompleted: !evt.isCompleted);
      await _db.updateCalendarEvent(updated);
      await loadEvents();
    }
  }
}

final calendarEventsNotifierProvider = StateNotifierProvider<CalendarEventsNotifier, List<CalendarEventModel>>((ref) {
  return CalendarEventsNotifier(ref.watch(databaseProvider));
});

// --- LEISURE / REST ITEMS ---
class LeisureNotifier extends StateNotifier<List<LeisureItemModel>> {
  final TempoDatabase _db;

  LeisureNotifier(this._db) : super([]) {
    loadItems();
  }

  Future<void> loadItems() async {
    final list = await _db.getLeisureItems();
    state = list;
  }

  Future<void> addItem(LeisureItemModel item) async {
    await _db.insertLeisureItem(item);
    await loadItems();
  }

  Future<void> updateItem(LeisureItemModel item) async {
    await _db.updateLeisureItem(item);
    await loadItems();
  }

  Future<void> deleteItem(String id) async {
    await _db.deleteLeisureItem(id);
    await loadItems();
  }

  Future<void> updateStatus(String id, String newStatus) async {
    final idx = state.indexWhere((i) => i.id == id);
    if (idx != -1) {
      final updated = state[idx].copyWith(status: newStatus);
      await _db.updateLeisureItem(updated);
      await loadItems();
    }
  }
}

final leisureNotifierProvider = StateNotifierProvider<LeisureNotifier, List<LeisureItemModel>>((ref) {
  return LeisureNotifier(ref.watch(databaseProvider));
});

// --- COURSES & GRADES ---
class CoursesNotifier extends StateNotifier<List<CourseModel>> {
  CoursesNotifier() : super(CourseModel.predefinedCourses);

  void updateCourse(CourseModel updated) {
    state = state.map((c) => c.id == updated.id ? updated : c).toList();
  }

  void updateMidtermScore(String courseId, double score) {
    state = state.map((c) => c.id == courseId ? CourseModel(
      id: c.id,
      name: c.name,
      code: c.code,
      difficulty: c.difficulty,
      targetMidterm: c.targetMidterm,
      actualMidterm: score,
      targetFinal: c.targetFinal,
      actualFinal: c.actualFinal,
      projectScore: c.projectScore,
      assessmentWeights: c.assessmentWeights,
      instructorNotes: c.instructorNotes,
    ) : c).toList();
  }

  void updateFinalScore(String courseId, double score) {
    state = state.map((c) => c.id == courseId ? CourseModel(
      id: c.id,
      name: c.name,
      code: c.code,
      difficulty: c.difficulty,
      targetMidterm: c.targetMidterm,
      actualMidterm: c.actualMidterm,
      targetFinal: c.targetFinal,
      actualFinal: score,
      projectScore: c.projectScore,
      assessmentWeights: c.assessmentWeights,
      instructorNotes: c.instructorNotes,
    ) : c).toList();
  }
}

final coursesNotifierProvider = StateNotifierProvider<CoursesNotifier, List<CourseModel>>((ref) {
  return CoursesNotifier();
});

// --- TERM MODES ---
class TermModeNotifier extends StateNotifier<TermModeModel> {
  final Ref _ref;

  TermModeNotifier(this._ref) : super(TermModeModel.predefinedModes.first) {
    _initMode();
  }

  void _initMode() {
    final settings = _ref.read(settingsNotifierProvider);
    final found = TermModeModel.predefinedModes.firstWhere(
      (m) => m.type.name == settings.currentTermMode,
      orElse: () => TermModeModel.predefinedModes.first,
    );
    state = found;
  }

  Future<void> selectTermMode(TermModeModel mode) async {
    state = mode;
    final db = _ref.read(databaseProvider);
    final week = _ref.read(currentWeekPeriodProvider);
    await db.applyTermMode(mode, week.id);
    await _ref.read(categoriesNotifierProvider.notifier).loadCategories();
    await _ref.read(weeklyBudgetsNotifierProvider.notifier).loadBudgets();
  }
}

final termModeNotifierProvider = StateNotifierProvider<TermModeNotifier, TermModeModel>((ref) {
  return TermModeNotifier(ref);
});

// --- PLANNING ANALYSIS (Rule-Based Planning Engine) ---
class PlanningAnalysis {
  final List<TaskModel> todayTasks;
  final List<TaskModel> overdueTasks;
  final int capacityDeficitMinutes;
  final int daysToMidterms;
  final int daysToFinals;
  final String currentTermModeTitle;
  final List<CalendarEventModel> todayEvents;

  const PlanningAnalysis({
    required this.todayTasks,
    required this.overdueTasks,
    required this.capacityDeficitMinutes,
    required this.daysToMidterms,
    required this.daysToFinals,
    required this.currentTermModeTitle,
    required this.todayEvents,
  });

  bool get hasCapacityDeficit => capacityDeficitMinutes > 0;
  bool get hasOverdue => overdueTasks.isNotEmpty;
}

final planningAnalysisProvider = Provider<PlanningAnalysis>((ref) {
  final allTasks = ref.watch(tasksNotifierProvider);
  final allEvents = ref.watch(calendarEventsNotifierProvider);
  final termMode = ref.watch(termModeNotifierProvider);
  final weeklySummary = ref.watch(weeklySummaryProvider);

  final now = DateTime.now();
  final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final currentDayOfWeek = now.weekday;

  final todayTasks = allTasks.where((t) {
    if (t.status == TaskStatus.done) return false;
    if (t.plannedDate != null && t.plannedDate == todayStr) return true;
    if (t.dueDate != null && t.dueDate == todayStr) return true;
    return false;
  }).toList();

  final displayTasks = todayTasks.isNotEmpty
      ? todayTasks
      : allTasks.where((t) => t.status != TaskStatus.done).take(5).toList();

  final overdueTasks = allTasks.where((t) {
    if (t.status == TaskStatus.done) return false;
    if (t.dueDate != null && t.dueDate!.compareTo(todayStr) < 0) return true;
    if (t.plannedDate != null && t.plannedDate!.compareTo(todayStr) < 0) return true;
    return false;
  }).toList();

  final pendingEstimateMinutes = allTasks
      .where((t) => t.status != TaskStatus.done)
      .fold(0, (sum, t) => sum + t.estimatedMinutes);
  final availableMinutes = weeklySummary.totalRemainingMinutes;
  final deficit = pendingEstimateMinutes > availableMinutes ? (pendingEstimateMinutes - availableMinutes) : 0;

  final midtermDate = DateTime(2026, 11, 7);
  final finalDate = DateTime(2027, 1, 7);
  final daysMidterm = midtermDate.difference(now).inDays;
  final daysFinal = finalDate.difference(now).inDays;

  final todayEvents = allEvents.where((e) {
    if (e.specificDate != null && e.specificDate == todayStr) return true;
    return e.dayOfWeek == currentDayOfWeek;
  }).toList();

  return PlanningAnalysis(
    todayTasks: displayTasks,
    overdueTasks: overdueTasks,
    capacityDeficitMinutes: deficit,
    daysToMidterms: daysMidterm > 0 ? daysMidterm : 0,
    daysToFinals: daysFinal > 0 ? daysFinal : 0,
    currentTermModeTitle: termMode.title,
    todayEvents: todayEvents,
  );
});
