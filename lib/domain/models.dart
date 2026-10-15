import 'dart:convert';
import 'package:flutter/material.dart';

enum BudgetPolicy { strict, flexible, protected, deadline }

enum TaskPriority { low, medium, high }

enum TaskStatus { todo, inProgress, done, deferred, cancelled }

enum TaskRecurrence { once, daily, weekly, specificDays }

enum SessionState { idle, running, paused, onBreak, completed }

class CategoryModel {
  final String id;
  final String name;
  final String description;
  final String icon;
  final int colorValue;
  final int weeklyTargetMinutes;
  final BudgetPolicy policy;
  final bool isArchived;
  final int priorityOrder;
  final List<int>? scheduledDays; // 1=Mon, ..., 7=Sun
  final String? deadlineDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.colorValue,
    required this.weeklyTargetMinutes,
    required this.policy,
    this.isArchived = false,
    this.priorityOrder = 0,
    this.scheduledDays,
    this.deadlineDate,
    required this.createdAt,
    required this.updatedAt,
  });

  Color get color => Color(colorValue);

  CategoryModel copyWith({
    String? name,
    String? description,
    String? icon,
    int? colorValue,
    int? weeklyTargetMinutes,
    BudgetPolicy? policy,
    bool? isArchived,
    int? priorityOrder,
    List<int>? scheduledDays,
    String? deadlineDate,
    DateTime? updatedAt,
  }) {
    return CategoryModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      colorValue: colorValue ?? this.colorValue,
      weeklyTargetMinutes: weeklyTargetMinutes ?? this.weeklyTargetMinutes,
      policy: policy ?? this.policy,
      isArchived: isArchived ?? this.isArchived,
      priorityOrder: priorityOrder ?? this.priorityOrder,
      scheduledDays: scheduledDays ?? this.scheduledDays,
      deadlineDate: deadlineDate ?? this.deadlineDate,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'color_value': colorValue,
      'weekly_target_minutes': weeklyTargetMinutes,
      'policy': policy.name,
      'is_archived': isArchived ? 1 : 0,
      'priority_order': priorityOrder,
      'scheduled_days': scheduledDays != null ? jsonEncode(scheduledDays) : null,
      'deadline_date': deadlineDate,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    // 1. Color parsing: can be int ('color_value', 'colorValue') or hex string ('color')
    int colorValue = 0xFF2563EB;
    final rawColor = map['color_value'] ?? map['colorValue'] ?? map['color'];
    if (rawColor is num) {
      colorValue = rawColor.toInt();
    } else if (rawColor is String) {
      var s = rawColor.trim();
      if (s.startsWith('#')) s = s.substring(1);
      if (s.length == 6) {
        final parsed = int.tryParse('FF$s', radix: 16);
        if (parsed != null) colorValue = parsed;
      } else if (s.length == 8) {
        final parsed = int.tryParse(s, radix: 16);
        if (parsed != null) colorValue = parsed;
      }
    }

    // 2. Scheduled days: can be List<dynamic> (from JSON) or JSON String (from SQLite)
    List<int>? days;
    final rawDays = map['scheduled_days'] ?? map['scheduledDays'];
    if (rawDays != null) {
      if (rawDays is List) {
        days = rawDays.map((e) => (e as num).toInt()).toList();
      } else if (rawDays is String) {
        try {
          final decoded = jsonDecode(rawDays);
          if (decoded is List) {
            days = decoded.map((e) => (e as num).toInt()).toList();
          }
        } catch (_) {}
      }
    }

    // 3. Policy:
    BudgetPolicy policy = BudgetPolicy.flexible;
    final rawPolicy = map['policy'];
    for (final p in BudgetPolicy.values) {
      if (p.name == rawPolicy) {
        policy = p;
        break;
      }
    }

    // 4. Weekly target minutes:
    final rawTarget = map['weekly_target_minutes'] ?? map['weeklyTargetMinutes'];
    final weeklyTargetMinutes = (rawTarget as num?)?.toInt() ?? 60;

    // 5. Priority order:
    final rawPriority = map['priority_order'] ?? map['priorityOrder'];
    final priorityOrder = (rawPriority as num?)?.toInt() ?? 0;

    // 6. Deadline date:
    final deadlineDate = (map['deadline_date'] ?? map['deadlineDate']) as String?;

    // 7. isArchived:
    final rawArchived = map['is_archived'] ?? map['isArchived'];
    final isArchived = rawArchived is bool
        ? rawArchived
        : (rawArchived as num?)?.toInt() == 1;

    return CategoryModel(
      id: map['id'] as String,
      name: map['name'] as String,
      description: (map['description'] as String?) ?? '',
      icon: (map['icon'] as String?) ?? 'circle',
      colorValue: colorValue,
      weeklyTargetMinutes: weeklyTargetMinutes,
      policy: policy,
      isArchived: isArchived,
      priorityOrder: priorityOrder,
      scheduledDays: days,
      deadlineDate: deadlineDate,
      createdAt: DateTime.tryParse((map['created_at'] ?? map['createdAt'] as String?) ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse((map['updated_at'] ?? map['updatedAt'] as String?) ?? '') ?? DateTime.now(),
    );
  }
}

class TaskModel {
  final String id;
  final String categoryId;
  final String title;
  final String? description;
  final int estimatedMinutes;
  final int actualTrackedMinutes;
  final TaskPriority priority;
  final TaskStatus status;
  final String? deadline;
  final String weekPeriodId;
  final TaskRecurrence recurrence;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TaskModel({
    required this.id,
    required this.categoryId,
    required this.title,
    this.description,
    this.estimatedMinutes = 30,
    this.actualTrackedMinutes = 0,
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.todo,
    this.deadline,
    required this.weekPeriodId,
    this.recurrence = TaskRecurrence.weekly,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isCompleted => status == TaskStatus.done;

  TaskModel copyWith({
    String? title,
    String? description,
    int? estimatedMinutes,
    int? actualTrackedMinutes,
    TaskPriority? priority,
    TaskStatus? status,
    String? deadline,
    String? weekPeriodId,
    TaskRecurrence? recurrence,
    DateTime? updatedAt,
  }) {
    return TaskModel(
      id: id,
      categoryId: categoryId,
      title: title ?? this.title,
      description: description ?? this.description,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      actualTrackedMinutes: actualTrackedMinutes ?? this.actualTrackedMinutes,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      deadline: deadline ?? this.deadline,
      weekPeriodId: weekPeriodId ?? this.weekPeriodId,
      recurrence: recurrence ?? this.recurrence,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'title': title,
      'description': description,
      'estimated_minutes': estimatedMinutes,
      'actual_tracked_minutes': actualTrackedMinutes,
      'priority': priority.name,
      'status': status.name,
      'deadline': deadline,
      'week_period_id': weekPeriodId,
      'recurrence': recurrence.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    TaskPriority prio = TaskPriority.medium;
    final rawPrio = map['priority'];
    for (final p in TaskPriority.values) {
      if (p.name == rawPrio) {
        prio = p;
        break;
      }
    }

    TaskStatus stat = TaskStatus.todo;
    final rawStat = map['status'];
    for (final s in TaskStatus.values) {
      if (s.name == rawStat) {
        stat = s;
        break;
      }
    }

    TaskRecurrence rec = TaskRecurrence.weekly;
    final rawRec = map['recurrence'];
    for (final r in TaskRecurrence.values) {
      if (r.name == rawRec) {
        rec = r;
        break;
      }
    }

    final catId = (map['category_id'] ?? map['categoryId']) as String;
    final estMins = (map['estimated_minutes'] ?? map['estimatedMinutes'] as num?)?.toInt() ?? 30;
    final actMins = (map['actual_tracked_minutes'] ?? map['actualTrackedMinutes'] as num?)?.toInt() ?? 0;
    final weekId = (map['week_period_id'] ?? map['weekPeriodId'] as String?) ?? '';

    return TaskModel(
      id: map['id'] as String,
      categoryId: catId,
      title: map['title'] as String,
      description: map['description'] as String?,
      estimatedMinutes: estMins,
      actualTrackedMinutes: actMins,
      priority: prio,
      status: stat,
      deadline: map['deadline'] as String?,
      weekPeriodId: weekId,
      recurrence: rec,
      createdAt: DateTime.tryParse((map['created_at'] ?? map['createdAt'] as String?) ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse((map['updated_at'] ?? map['updatedAt'] as String?) ?? '') ?? DateTime.now(),
    );
  }
}

class WorkSessionModel {
  final String id;
  final String categoryId;
  final String? taskId;
  final DateTime startTime;
  final DateTime? endTime;
  final SessionState state;
  final int activeSeconds;
  final int pauseSeconds;
  final int breakSeconds;
  final String? note;
  final String weekPeriodId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkSessionModel({
    required this.id,
    required this.categoryId,
    this.taskId,
    required this.startTime,
    this.endTime,
    this.state = SessionState.completed,
    required this.activeSeconds,
    this.pauseSeconds = 0,
    this.breakSeconds = 0,
    this.note,
    required this.weekPeriodId,
    required this.createdAt,
    required this.updatedAt,
  });

  WorkSessionModel copyWith({
    DateTime? endTime,
    SessionState? state,
    int? activeSeconds,
    int? pauseSeconds,
    int? breakSeconds,
    String? note,
    DateTime? updatedAt,
  }) {
    return WorkSessionModel(
      id: id,
      categoryId: categoryId,
      taskId: taskId,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      state: state ?? this.state,
      activeSeconds: activeSeconds ?? this.activeSeconds,
      pauseSeconds: pauseSeconds ?? this.pauseSeconds,
      breakSeconds: breakSeconds ?? this.breakSeconds,
      note: note ?? this.note,
      weekPeriodId: weekPeriodId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'task_id': taskId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'state': state.name,
      'active_seconds': activeSeconds,
      'pause_seconds': pauseSeconds,
      'break_seconds': breakSeconds,
      'note': note,
      'week_period_id': weekPeriodId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory WorkSessionModel.fromMap(Map<String, dynamic> map) {
    SessionState sState = SessionState.completed;
    for (final s in SessionState.values) {
      if (s.name == map['state']) {
        sState = s;
        break;
      }
    }

    return WorkSessionModel(
      id: map['id'] as String,
      categoryId: map['category_id'] as String,
      taskId: map['task_id'] as String?,
      startTime: DateTime.tryParse((map['start_time'] as String?) ?? '') ?? DateTime.now(),
      endTime: map['end_time'] != null ? DateTime.tryParse(map['end_time'] as String) : null,
      state: sState,
      activeSeconds: (map['active_seconds'] as num?)?.toInt() ?? 0,
      pauseSeconds: (map['pause_seconds'] as num?)?.toInt() ?? 0,
      breakSeconds: (map['break_seconds'] as num?)?.toInt() ?? 0,
      note: map['note'] as String?,
      weekPeriodId: (map['week_period_id'] as String?) ?? '',
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse((map['updated_at'] as String?) ?? '') ?? DateTime.now(),
    );
  }
}

class SessionSegmentModel {
  final String id;
  final String sessionId;
  final String type; // 'work' | 'pause'
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;

  const SessionSegmentModel({
    required this.id,
    required this.sessionId,
    required this.type,
    required this.startTime,
    this.endTime,
    required this.durationSeconds,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'type': type,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'duration_seconds': durationSeconds,
    };
  }

  factory SessionSegmentModel.fromMap(Map<String, dynamic> map) {
    return SessionSegmentModel(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      type: (map['type'] as String?) ?? 'work',
      startTime: DateTime.tryParse((map['start_time'] as String?) ?? '') ?? DateTime.now(),
      endTime: map['end_time'] != null ? DateTime.tryParse(map['end_time'] as String) : null,
      durationSeconds: (map['duration_seconds'] as num?)?.toInt() ?? 0,
    );
  }
}

class BreakSegmentModel {
  final String id;
  final String sessionId;
  final DateTime startTime;
  final DateTime? endTime;
  final int plannedMinutes;
  final int actualDurationSeconds;
  final String? label;

  const BreakSegmentModel({
    required this.id,
    required this.sessionId,
    required this.startTime,
    this.endTime,
    required this.plannedMinutes,
    required this.actualDurationSeconds,
    this.label,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'planned_minutes': plannedMinutes,
      'actual_duration_seconds': actualDurationSeconds,
      'label': label,
    };
  }

  factory BreakSegmentModel.fromMap(Map<String, dynamic> map) {
    return BreakSegmentModel(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      startTime: DateTime.tryParse((map['start_time'] as String?) ?? '') ?? DateTime.now(),
      endTime: map['end_time'] != null ? DateTime.tryParse(map['end_time'] as String) : null,
      plannedMinutes: (map['planned_minutes'] as num?)?.toInt() ?? 5,
      actualDurationSeconds: (map['actual_duration_seconds'] as num?)?.toInt() ?? 0,
      label: map['label'] as String?,
    );
  }
}

class PoolTransactionModel {
  final String id;
  final String type; // 'rollover_to_pool' | 'pool_to_category' | 'direct_category_transfer'
  final String? sourceCategoryId;
  final String? targetCategoryId;
  final int minutes;
  final String weekPeriodId;
  final String? note;
  final DateTime timestamp;
  final bool isUndone;

  const PoolTransactionModel({
    required this.id,
    required this.type,
    this.sourceCategoryId,
    this.targetCategoryId,
    required this.minutes,
    required this.weekPeriodId,
    this.note,
    required this.timestamp,
    this.isUndone = false,
  });

  PoolTransactionModel copyWith({bool? isUndone}) {
    return PoolTransactionModel(
      id: id,
      type: type,
      sourceCategoryId: sourceCategoryId,
      targetCategoryId: targetCategoryId,
      minutes: minutes,
      weekPeriodId: weekPeriodId,
      note: note,
      timestamp: timestamp,
      isUndone: isUndone ?? this.isUndone,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'source_category_id': sourceCategoryId,
      'target_category_id': targetCategoryId,
      'minutes': minutes,
      'week_period_id': weekPeriodId,
      'note': note,
      'timestamp': timestamp.toIso8601String(),
      'is_undone': isUndone ? 1 : 0,
    };
  }

  factory PoolTransactionModel.fromMap(Map<String, dynamic> map) {
    return PoolTransactionModel(
      id: map['id'] as String,
      type: map['type'] as String,
      sourceCategoryId: map['source_category_id'] as String?,
      targetCategoryId: map['target_category_id'] as String?,
      minutes: (map['minutes'] as num?)?.toInt() ?? 0,
      weekPeriodId: (map['week_period_id'] as String?) ?? '',
      note: map['note'] as String?,
      timestamp: DateTime.tryParse((map['timestamp'] as String?) ?? '') ?? DateTime.now(),
      isUndone: (map['is_undone'] as num?)?.toInt() == 1,
    );
  }
}

class CalendarEventModel {
  final String id;
  final String title;
  final int dayOfWeek; // 1=Mon, ..., 7=Sun
  final String startTime; // "HH:MM"
  final String endTime; // "HH:MM"
  final String type; // 'lecture' | 'study_block' | 'internship' | 'sport' | 'rest'
  final String? categoryId;

  const CalendarEventModel({
    required this.id,
    required this.title,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.type,
    this.categoryId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'type': type,
      'category_id': categoryId,
    };
  }

  factory CalendarEventModel.fromMap(Map<String, dynamic> map) {
    final dOfWeek = (map['day_of_week'] ?? map['dayOfWeek'] as num?)?.toInt() ?? 1;
    final sTime = (map['start_time'] ?? map['startTime'] as String?) ?? '09:00';
    final eTime = (map['end_time'] ?? map['endTime'] as String?) ?? '10:00';
    final tType = (map['type'] as String?) ?? 'study_block';
    final cId = (map['category_id'] ?? map['categoryId'] as String?);

    return CalendarEventModel(
      id: (map['id'] as String?) ?? 'cal_${dOfWeek}_${sTime.replaceAll(':', '')}_${(map['title'] ?? '').toString().replaceAll(RegExp(r'\s+'), '_')}',
      title: map['title'] as String,
      dayOfWeek: dOfWeek,
      startTime: sTime,
      endTime: eTime,
      type: tType,
      categoryId: cId,
    );
  }
}

class AcademicMilestoneModel {
  final String id;
  final String title;
  final String startDate;
  final String endDate;

  const AcademicMilestoneModel({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'start_date': startDate,
      'end_date': endDate,
    };
  }

  factory AcademicMilestoneModel.fromMap(Map<String, dynamic> map) {
    final sDate = (map['start_date'] ?? map['startDate'] as String?) ?? '';
    final eDate = (map['end_date'] ?? map['endDate'] as String?) ?? '';
    final title = (map['title'] as String?) ?? '';
    final id = (map['id'] as String?) ?? 'ms_${sDate}_${title.replaceAll(RegExp(r'\s+'), '_')}';

    return AcademicMilestoneModel(
      id: id,
      title: title,
      startDate: sDate,
      endDate: eDate,
    );
  }
}

class AppSettingsModel {
  final String theme; // 'system' | 'dark' | 'light' | 'oled'
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool notificationsEnabled;
  final bool smartWarning80;
  final bool smartWarning95;
  final int defaultBreakMinutes;
  final String defaultFocusCycle; // 'continuous' | '25_5' | '50_10' | '90_15'
  final int weekStartDay; // 1 = Monday
  final bool autoWeekReset;
  final String language; // 'tr' | 'en'
  final int seedVersion;

  const AppSettingsModel({
    this.theme = 'dark',
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.notificationsEnabled = true,
    this.smartWarning80 = true,
    this.smartWarning95 = true,
    this.defaultBreakMinutes = 5,
    this.defaultFocusCycle = 'continuous',
    this.weekStartDay = 1,
    this.autoWeekReset = true,
    this.language = 'tr',
    this.seedVersion = 0,
  });

  AppSettingsModel copyWith({
    String? theme,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? notificationsEnabled,
    bool? smartWarning80,
    bool? smartWarning95,
    int? defaultBreakMinutes,
    String? defaultFocusCycle,
    int? weekStartDay,
    bool? autoWeekReset,
    String? language,
    int? seedVersion,
  }) {
    return AppSettingsModel(
      theme: theme ?? this.theme,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      smartWarning80: smartWarning80 ?? this.smartWarning80,
      smartWarning95: smartWarning95 ?? this.smartWarning95,
      defaultBreakMinutes: defaultBreakMinutes ?? this.defaultBreakMinutes,
      defaultFocusCycle: defaultFocusCycle ?? this.defaultFocusCycle,
      weekStartDay: weekStartDay ?? this.weekStartDay,
      autoWeekReset: autoWeekReset ?? this.autoWeekReset,
      language: language ?? this.language,
      seedVersion: seedVersion ?? this.seedVersion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'theme': theme,
      'sound_enabled': soundEnabled ? 1 : 0,
      'vibration_enabled': vibrationEnabled ? 1 : 0,
      'notifications_enabled': notificationsEnabled ? 1 : 0,
      'smart_warning_80': smartWarning80 ? 1 : 0,
      'smart_warning_95': smartWarning95 ? 1 : 0,
      'default_break_minutes': defaultBreakMinutes,
      'default_focus_cycle': defaultFocusCycle,
      'week_start_day': weekStartDay,
      'auto_week_reset': autoWeekReset ? 1 : 0,
      'language': language,
      'seed_version': seedVersion,
    };
  }

  factory AppSettingsModel.fromMap(Map<String, dynamic> map) {
    return AppSettingsModel(
      theme: (map['theme'] as String?) ?? 'dark',
      soundEnabled: (map['sound_enabled'] as num?)?.toInt() != 0,
      vibrationEnabled: (map['vibration_enabled'] as num?)?.toInt() != 0,
      notificationsEnabled: (map['notifications_enabled'] as num?)?.toInt() != 0,
      smartWarning80: (map['smart_warning_80'] as num?)?.toInt() != 0,
      smartWarning95: (map['smart_warning_95'] as num?)?.toInt() != 0,
      defaultBreakMinutes: (map['default_break_minutes'] as num?)?.toInt() ?? 5,
      defaultFocusCycle: (map['default_focus_cycle'] as String?) ?? 'continuous',
      weekStartDay: (map['week_start_day'] as num?)?.toInt() ?? 1,
      autoWeekReset: (map['auto_week_reset'] as num?)?.toInt() != 0,
      language: (map['language'] as String?) ?? 'tr',
      seedVersion: (map['seed_version'] as num?)?.toInt() ?? 0,
    );
  }
}

class ActiveSessionRecord {
  final String id;
  final String categoryId;
  final String? taskId;
  final SessionState state;
  final DateTime sessionStartTime;
  final DateTime lastSegmentStartTime;
  final int accumulatedWorkSeconds;
  final int accumulatedBreakSeconds;
  final int plannedBreakMinutes;
  final String focusCycle;
  final String? note;
  final String weekPeriodId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ActiveSessionRecord({
    this.id = 'current',
    required this.categoryId,
    this.taskId,
    required this.state,
    required this.sessionStartTime,
    required this.lastSegmentStartTime,
    this.accumulatedWorkSeconds = 0,
    this.accumulatedBreakSeconds = 0,
    this.plannedBreakMinutes = 5,
    this.focusCycle = 'continuous',
    this.note,
    required this.weekPeriodId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'task_id': taskId,
      'state': state.name,
      'session_start_time': sessionStartTime.toIso8601String(),
      'last_segment_start_time': lastSegmentStartTime.toIso8601String(),
      'accumulated_work_seconds': accumulatedWorkSeconds,
      'accumulated_break_seconds': accumulatedBreakSeconds,
      'planned_break_minutes': plannedBreakMinutes,
      'focus_cycle': focusCycle,
      'note': note,
      'week_period_id': weekPeriodId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ActiveSessionRecord.fromMap(Map<String, dynamic> map) {
    return ActiveSessionRecord(
      id: (map['id'] as String?) ?? 'current',
      categoryId: map['category_id'] as String,
      taskId: map['task_id'] as String?,
      state: SessionState.values.firstWhere(
        (s) => s.name == map['state'],
        orElse: () => SessionState.running,
      ),
      sessionStartTime: DateTime.tryParse((map['session_start_time'] as String?) ?? '') ?? DateTime.now(),
      lastSegmentStartTime: DateTime.tryParse((map['last_segment_start_time'] as String?) ?? '') ?? DateTime.now(),
      accumulatedWorkSeconds: (map['accumulated_work_seconds'] as num?)?.toInt() ?? 0,
      accumulatedBreakSeconds: (map['accumulated_break_seconds'] as num?)?.toInt() ?? 0,
      plannedBreakMinutes: (map['planned_break_minutes'] as num?)?.toInt() ?? 5,
      focusCycle: (map['focus_cycle'] as String?) ?? 'continuous',
      note: map['note'] as String?,
      weekPeriodId: (map['week_period_id'] as String?) ?? '',
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse((map['updated_at'] as String?) ?? '') ?? DateTime.now(),
    );
  }
}
