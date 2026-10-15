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

class WeeklyBudgetModel {
  final String id;
  final String categoryId;
  final String weekPeriodId;
  final int allocatedMinutes;
  final int transferredInMinutes;
  final int transferredOutMinutes;
  final bool isCompleted;
  final DateTime createdAt;

  const WeeklyBudgetModel({
    required this.id,
    required this.categoryId,
    required this.weekPeriodId,
    required this.allocatedMinutes,
    this.transferredInMinutes = 0,
    this.transferredOutMinutes = 0,
    this.isCompleted = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'category_id': categoryId,
    'week_period_id': weekPeriodId,
    'allocated_minutes': allocatedMinutes,
    'transferred_in_minutes': transferredInMinutes,
    'transferred_out_minutes': transferredOutMinutes,
    'is_completed': isCompleted ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
  };

  factory WeeklyBudgetModel.fromMap(Map<String, dynamic> map) {
    return WeeklyBudgetModel(
      id: (map['id'] as String?) ?? '',
      categoryId: (map['category_id'] as String?) ?? '',
      weekPeriodId: (map['week_period_id'] as String?) ?? '',
      allocatedMinutes: (map['allocated_minutes'] as num?)?.toInt() ?? 0,
      transferredInMinutes: (map['transferred_in_minutes'] as num?)?.toInt() ?? 0,
      transferredOutMinutes: (map['transferred_out_minutes'] as num?)?.toInt() ?? 0,
      isCompleted: (map['is_completed'] as num?)?.toInt() == 1,
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? '') ?? DateTime.now(),
    );
  }
}

class SubTaskModel {
  final String id;
  final String title;
  final bool isCompleted;

  const SubTaskModel({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  SubTaskModel copyWith({String? title, bool? isCompleted}) {
    return SubTaskModel(
      id: id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'is_completed': isCompleted ? 1 : 0,
  };

  factory SubTaskModel.fromMap(Map<String, dynamic> map) {
    final rawComp = map['is_completed'] ?? map['isCompleted'];
    return SubTaskModel(
      id: (map['id'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      isCompleted: rawComp is bool ? rawComp : (rawComp as num?)?.toInt() == 1,
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
  final String? plannedDate; // 'YYYY-MM-DD'
  final String? dueDate; // 'YYYY-MM-DD'
  final String? dueTime; // 'HH:MM'
  final String? plannedTimeWindow; // '20:00-21:00'
  final String? parentTaskId;
  final String? courseId;
  final String? taskType; // 'academic' | 'personal' | 'project' | 'habit' | 'anime_publish'
  final List<SubTaskModel> subtasks;
  final String? notes;
  final DateTime? completedAt;
  final int deferredCount;
  final String? source;
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
    this.plannedDate,
    this.dueDate,
    this.dueTime,
    this.plannedTimeWindow,
    this.parentTaskId,
    this.courseId,
    this.taskType,
    this.subtasks = const [],
    this.notes,
    this.completedAt,
    this.deferredCount = 0,
    this.source,
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
    String? plannedDate,
    String? dueDate,
    String? dueTime,
    String? plannedTimeWindow,
    String? parentTaskId,
    String? courseId,
    String? taskType,
    List<SubTaskModel>? subtasks,
    String? notes,
    DateTime? completedAt,
    int? deferredCount,
    String? source,
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
      plannedDate: plannedDate ?? this.plannedDate,
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
      plannedTimeWindow: plannedTimeWindow ?? this.plannedTimeWindow,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      courseId: courseId ?? this.courseId,
      taskType: taskType ?? this.taskType,
      subtasks: subtasks ?? this.subtasks,
      notes: notes ?? this.notes,
      completedAt: completedAt ?? this.completedAt,
      deferredCount: deferredCount ?? this.deferredCount,
      source: source ?? this.source,
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
      'planned_date': plannedDate,
      'due_date': dueDate,
      'due_time': dueTime,
      'planned_time_window': plannedTimeWindow,
      'parent_task_id': parentTaskId,
      'course_id': courseId,
      'task_type': taskType,
      'notes': notes,
      'completed_at': completedAt?.toIso8601String(),
      'deferred_count': deferredCount,
      'source': source,
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

    List<SubTaskModel> subtasksList = const [];
    final rawSubtasks = map['subtasks_json'] ?? map['subtasks'];
    if (rawSubtasks != null) {
      if (rawSubtasks is List) {
        final list = <SubTaskModel>[];
        for (int idx = 0; idx < rawSubtasks.length; idx++) {
          final item = rawSubtasks[idx];
          if (item is String) {
            list.add(SubTaskModel(
              id: 'sub_${map['id'] ?? 'task'}_$idx',
              title: item,
              isCompleted: false,
            ));
          } else if (item is Map) {
            list.add(SubTaskModel.fromMap(Map<String, dynamic>.from(item)));
          }
        }
        subtasksList = list;
      } else if (rawSubtasks is String && rawSubtasks.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawSubtasks);
          if (decoded is List) {
            final list = <SubTaskModel>[];
            for (int idx = 0; idx < decoded.length; idx++) {
              final item = decoded[idx];
              if (item is String) {
                list.add(SubTaskModel(
                  id: 'sub_${map['id'] ?? 'task'}_$idx',
                  title: item,
                  isCompleted: false,
                ));
              } else if (item is Map) {
                list.add(SubTaskModel.fromMap(Map<String, dynamic>.from(item)));
              }
            }
            subtasksList = list;
          }
        } catch (_) {}
      }
    }

    final pDate = (map['planned_date'] ?? map['plannedDate']) as String?;
    final dDate = (map['due_date'] ?? map['dueDate'] ?? map['deadline']) as String?;
    final dTime = (map['due_time'] ?? map['dueTime']) as String?;
    final pWindow = (map['planned_time_window'] ?? map['plannedTimeWindow']) as String?;
    final pTaskId = (map['parent_task_id'] ?? map['parentTaskId']) as String?;
    final cId = (map['course_id'] ?? map['courseId']) as String?;
    final tType = (map['task_type'] ?? map['taskType']) as String?;
    final tNotes = (map['notes']) as String?;
    final compAtStr = (map['completed_at'] ?? map['completedAt']) as String?;
    final defCount = (map['deferred_count'] ?? map['deferredCount'] as num?)?.toInt() ?? 0;
    final src = (map['source']) as String?;

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
      plannedDate: pDate,
      dueDate: dDate,
      dueTime: dTime,
      plannedTimeWindow: pWindow,
      parentTaskId: pTaskId,
      courseId: cId,
      taskType: tType,
      subtasks: subtasksList,
      notes: tNotes,
      completedAt: compAtStr != null ? DateTime.tryParse(compAtStr) : null,
      deferredCount: defCount,
      source: src,
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
  final String type; // 'lecture' | 'study_block' | 'internship' | 'sport' | 'rest' | 'anime_publish' | 'family'
  final String? categoryId;
  final String? specificDate; // 'YYYY-MM-DD' for date-specific/one-time events
  final bool isTentative; // for unconfirmed events
  final bool isCompleted;
  final bool isRest; // rest/leisure flag
  final String recurrence; // 'weekly' | 'once' | 'specific_date'
  final String? location;
  final String? notes;

  const CalendarEventModel({
    required this.id,
    required this.title,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.type,
    this.categoryId,
    this.specificDate,
    this.isTentative = false,
    this.isCompleted = false,
    this.isRest = false,
    this.recurrence = 'weekly',
    this.location,
    this.notes,
  });

  CalendarEventModel copyWith({
    String? title,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    String? type,
    String? categoryId,
    String? specificDate,
    bool? isTentative,
    bool? isCompleted,
    bool? isRest,
    String? recurrence,
    String? location,
    String? notes,
  }) {
    return CalendarEventModel(
      id: id,
      title: title ?? this.title,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      specificDate: specificDate ?? this.specificDate,
      isTentative: isTentative ?? this.isTentative,
      isCompleted: isCompleted ?? this.isCompleted,
      isRest: isRest ?? this.isRest,
      recurrence: recurrence ?? this.recurrence,
      location: location ?? this.location,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'type': type,
      'category_id': categoryId,
      'specific_date': specificDate,
      'is_tentative': isTentative ? 1 : 0,
      'is_completed': isCompleted ? 1 : 0,
      'is_rest': isRest ? 1 : 0,
      'recurrence': recurrence,
      'location': location,
      'notes': notes,
    };
  }

  factory CalendarEventModel.fromMap(Map<String, dynamic> map) {
    final dOfWeek = (map['day_of_week'] ?? map['dayOfWeek'] as num?)?.toInt() ?? 1;
    final sTime = (map['start_time'] ?? map['startTime'] as String?) ?? '09:00';
    final eTime = (map['end_time'] ?? map['endTime'] as String?) ?? '10:00';
    final tType = (map['type'] as String?) ?? 'study_block';
    final cId = (map['category_id'] ?? map['categoryId'] as String?);
    final sDate = (map['specific_date'] ?? map['specificDate']) as String?;
    final isTent = (map['is_tentative'] ?? map['isTentative']);
    final isComp = (map['is_completed'] ?? map['isCompleted']);
    final isRst = (map['is_rest'] ?? map['isRest']) ?? (tType == 'rest' || tType == 'family' || tType == 'gaming');
    final rec = (map['recurrence'] as String?) ?? 'weekly';
    final loc = (map['location'] as String?);
    final nts = (map['notes'] as String?);

    return CalendarEventModel(
      id: (map['id'] as String?) ?? 'cal_${dOfWeek}_${sTime.replaceAll(':', '')}_${(map['title'] ?? '').toString().replaceAll(RegExp(r'\s+'), '_')}',
      title: map['title'] as String,
      dayOfWeek: dOfWeek,
      startTime: sTime,
      endTime: eTime,
      type: tType,
      categoryId: cId,
      specificDate: sDate,
      isTentative: isTent is bool ? isTent : (isTent as num?)?.toInt() == 1,
      isCompleted: isComp is bool ? isComp : (isComp as num?)?.toInt() == 1,
      isRest: isRst is bool ? isRst : (isRst as num?)?.toInt() == 1,
      recurrence: rec,
      location: loc,
      notes: nts,
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

enum MasteryLevel {
  notStarted,   // Hiç başlamadım
  reviewed,     // İnceledim
  withHelp,     // Yardımla çözebiliyorum
  independent,  // Bağımsız çözebiliyorum
  examReady,    // Sınav düzeyinde hazırım (90+)
}

class CourseTopicModel {
  final String id;
  final String courseId;
  final int weekNumber; // 1-14
  final String title;
  final String? description;
  final MasteryLevel masteryLevel;
  final int questionsAttempted;
  final int questionsCorrect;
  final String? notes;
  final DateTime updatedAt;

  const CourseTopicModel({
    required this.id,
    required this.courseId,
    required this.weekNumber,
    required this.title,
    this.description,
    this.masteryLevel = MasteryLevel.notStarted,
    this.questionsAttempted = 0,
    this.questionsCorrect = 0,
    this.notes,
    required this.updatedAt,
  });

  double get accuracyRate => questionsAttempted > 0 ? (questionsCorrect / questionsAttempted) : 0.0;

  CourseTopicModel copyWith({
    String? title,
    String? description,
    MasteryLevel? masteryLevel,
    int? questionsAttempted,
    int? questionsCorrect,
    String? notes,
    DateTime? updatedAt,
  }) {
    return CourseTopicModel(
      id: id,
      courseId: courseId,
      weekNumber: weekNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      masteryLevel: masteryLevel ?? this.masteryLevel,
      questionsAttempted: questionsAttempted ?? this.questionsAttempted,
      questionsCorrect: questionsCorrect ?? this.questionsCorrect,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'course_id': courseId,
      'week_number': weekNumber,
      'title': title,
      'description': description,
      'mastery_level': masteryLevel.name,
      'questions_attempted': questionsAttempted,
      'questions_correct': questionsCorrect,
      'notes': notes,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory CourseTopicModel.fromMap(Map<String, dynamic> map) {
    MasteryLevel mLevel = MasteryLevel.notStarted;
    final rawLevel = map['mastery_level'] ?? map['masteryLevel'];
    for (final m in MasteryLevel.values) {
      if (m.name == rawLevel) {
        mLevel = m;
        break;
      }
    }

    return CourseTopicModel(
      id: map['id'] as String,
      courseId: (map['course_id'] ?? map['courseId']) as String,
      weekNumber: (map['week_number'] ?? map['weekNumber'] as num?)?.toInt() ?? 1,
      title: map['title'] as String,
      description: map['description'] as String?,
      masteryLevel: mLevel,
      questionsAttempted: (map['questions_attempted'] ?? map['questionsAttempted'] as num?)?.toInt() ?? 0,
      questionsCorrect: (map['questions_correct'] ?? map['questionsCorrect'] as num?)?.toInt() ?? 0,
      notes: map['notes'] as String?,
      updatedAt: DateTime.tryParse((map['updated_at'] ?? map['updatedAt'] as String?) ?? '') ?? DateTime.now(),
    );
  }
}

class CourseModel {
  final String id;
  final String name;
  final String code;
  final int difficulty; // 1-10
  final double targetMidterm;
  final double? actualMidterm;
  final double targetFinal;
  final double? actualFinal;
  final double? projectScore;
  final Map<String, double> assessmentWeights;
  final String instructorNotes;

  const CourseModel({
    required this.id,
    required this.name,
    required this.code,
    required this.difficulty,
    this.targetMidterm = 90.0,
    this.actualMidterm,
    this.targetFinal = 90.0,
    this.actualFinal,
    this.projectScore,
    this.assessmentWeights = const {'midterm': 0.4, 'final': 0.6},
    this.instructorNotes = '',
  });

  double? calculateEstimatedGrade() {
    double total = 0;
    double totalWeight = 0;
    if (assessmentWeights.containsKey('midterm')) {
      final w = assessmentWeights['midterm']!;
      total += (actualMidterm ?? targetMidterm) * w;
      totalWeight += w;
    }
    if (assessmentWeights.containsKey('final')) {
      final w = assessmentWeights['final']!;
      total += (actualFinal ?? targetFinal) * w;
      totalWeight += w;
    }
    if (assessmentWeights.containsKey('project')) {
      final w = assessmentWeights['project']!;
      total += (projectScore ?? 90.0) * w;
      totalWeight += w;
    }
    return totalWeight > 0 ? (total / totalWeight) : null;
  }

  static List<CourseModel> get predefinedCourses => const [
    CourseModel(
      id: 'course-rf',
      name: 'Radio Frequency Integrated Circuits',
      code: 'RF-IC',
      difficulty: 10,
      targetMidterm: 90.0,
      targetFinal: 90.0,
      assessmentWeights: {'midterm': 0.4, 'final': 0.6},
      instructorNotes: '10/10 zorluk. Problem çözme odaklı ilerle, Noise Figure & S-Parametreleri kritik.',
    ),
    CourseModel(
      id: 'course-elek2',
      name: 'Electronic Circuits II',
      code: 'EC-II',
      difficulty: 9,
      targetMidterm: 90.0,
      targetFinal: 90.0,
      assessmentWeights: {'midterm': 0.4, 'final': 0.6},
      instructorNotes: 'Op-amp, Current Mirror, Differential Amp, Frequency Response & Stability.',
    ),
    CourseModel(
      id: 'course-c',
      name: 'C Programming & Interdisciplinary Project',
      code: 'CENG-C',
      difficulty: 7,
      targetMidterm: 90.0,
      targetFinal: 90.0,
      projectScore: 95.0,
      assessmentWeights: {'midterm': 0.2, 'project': 0.4, 'final': 0.4},
      instructorNotes: '%40 proje ağırlığı. 4 modüllü mimari, Git, kod incelemesi ve entegrasyon.',
    ),
    CourseModel(
      id: 'course-siber',
      name: 'Cybersecurity',
      code: 'CENG445',
      difficulty: 7,
      targetMidterm: 90.0,
      targetFinal: 90.0,
      assessmentWeights: {'midterm': 0.4, 'final': 0.6},
      instructorNotes: 'Tehdit modelleme, ağ güvenliği, zararlı yazılım, web güvenliği ve mevzuat.',
    ),
  ];
}

enum TermModeType {
  modeAMidtermPrep, // 15 Oct - 6 Nov (27h)
  modeBMidtermWeek, // 7 - 15 Nov (Exam Mode)
  modeCNormalTerm,  // 16 Nov - 31 Dec (27h)
  modeDFinalPrep,   // 1 - 19 Jan (28h)
}

class TermModeModel {
  final TermModeType type;
  final String title;
  final String dateRange;
  final int targetWeeklyHours;
  final String description;
  final Map<String, double> categoryHours;

  const TermModeModel({
    required this.type,
    required this.title,
    required this.dateRange,
    required this.targetWeeklyHours,
    required this.description,
    required this.categoryHours,
  });

  static List<TermModeModel> get predefinedModes => [
    const TermModeModel(
      type: TermModeType.modeAMidtermPrep,
      title: 'Vize Hazırlık Modu',
      dateRange: '15 Ekim – 6 Kasım',
      targetWeeklyHours: 27,
      description: 'RF (7h) ve Elektronik II (7h) ağırlıklı toparlanma ve soru provası.',
      categoryHours: {
        'cat-rf': 7.0,
        'cat-elek2': 7.0,
        'cat-c': 2.0,
        'cat-siber': 1.0,
        'cat-ingilizce': 2.0,
        'cat-almanca': 0.5,
        'cat-media': 2.5,
        'cat-web-ajansi': 2.0,
        'cat-dev': 1.0,
        'cat-kitap': 1.5,
        'cat-bitirme': 0.5,
      },
    ),
    const TermModeModel(
      type: TermModeType.modeBMidtermWeek,
      title: 'Vize Haftası (Sınav Modu)',
      dateRange: '7 – 15 Kasım',
      targetWeeklyHours: 24,
      description: 'En yakın sınava odaklanma, hafifleyen ikincil işler, korunan uyku.',
      categoryHours: {
        'cat-rf': 8.0,
        'cat-elek2': 8.0,
        'cat-c': 3.0,
        'cat-siber': 2.0,
        'cat-ingilizce': 0.5,
        'cat-almanca': 0.0,
        'cat-media': 1.5,
        'cat-web-ajansi': 0.5,
        'cat-dev': 0.0,
        'cat-kitap': 0.5,
        'cat-bitirme': 0.0,
      },
    ),
    const TermModeModel(
      type: TermModeType.modeCNormalTerm,
      title: 'Normal Dönem & Proje Modu',
      dateRange: '16 Kasım – 31 Aralık',
      targetWeeklyHours: 27,
      description: 'C 4 modüllü dönem projesi (4h), IELTS hazırlığı (4h) ve dengeli tempo.',
      categoryHours: {
        'cat-rf': 4.0,
        'cat-elek2': 4.0,
        'cat-c': 4.0,
        'cat-siber': 2.0,
        'cat-ingilizce': 4.0,
        'cat-almanca': 1.5,
        'cat-media': 2.5,
        'cat-web-ajansi': 2.0,
        'cat-dev': 1.0,
        'cat-kitap': 1.5,
        'cat-bitirme': 0.5,
      },
    ),
    const TermModeModel(
      type: TermModeType.modeDFinalPrep,
      title: 'Final Hazırlık Modu',
      dateRange: '1 – 19 Ocak 2027',
      targetWeeklyHours: 28,
      description: 'Yoğun akademik sınav maratonu. RF (8h) + Elektronik II (8h) + C (4h) + Cyber (3h).',
      categoryHours: {
        'cat-rf': 8.0,
        'cat-elek2': 8.0,
        'cat-c': 4.0,
        'cat-siber': 3.0,
        'cat-ingilizce': 1.0,
        'cat-almanca': 0.0,
        'cat-media': 2.5,
        'cat-web-ajansi': 0.0,
        'cat-dev': 0.0,
        'cat-kitap': 1.0,
        'cat-bitirme': 0.5,
      },
    ),
  ];
}

class LeisureItemModel {
  final String id;
  final String title;
  final String type; // 'game' | 'anime' | 'movie' | 'book' | 'other'
  final String status; // 'backlog' | 'in_progress' | 'completed'
  final String? note;
  final int? rating;

  const LeisureItemModel({
    required this.id,
    required this.title,
    required this.type,
    this.status = 'backlog',
    this.note,
    this.rating,
  });

  LeisureItemModel copyWith({
    String? title,
    String? type,
    String? status,
    String? note,
    int? rating,
  }) {
    return LeisureItemModel(
      id: id,
      title: title ?? this.title,
      type: type ?? this.type,
      status: status ?? this.status,
      note: note ?? this.note,
      rating: rating ?? this.rating,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'type': type,
    'status': status,
    'note': note,
    'rating': rating,
  };

  factory LeisureItemModel.fromMap(Map<String, dynamic> map) {
    return LeisureItemModel(
      id: (map['id'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      type: (map['type'] as String?) ?? 'game',
      status: (map['status'] as String?) ?? 'backlog',
      note: map['note'] as String?,
      rating: (map['rating'] as num?)?.toInt(),
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
  final String currentTermMode;

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
    this.currentTermMode = 'modeAMidtermPrep',
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
    String? currentTermMode,
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
      currentTermMode: currentTermMode ?? this.currentTermMode,
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
      'current_term_mode': currentTermMode,
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
      currentTermMode: (map['current_term_mode'] as String?) ?? 'modeAMidtermPrep',
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

