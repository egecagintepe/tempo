import '../domain/models.dart';
import '../domain/time_engine.dart';

/// Structured, strongly-typed result of parsing and validating a TEMPO seed JSON file.
class SeedParseResult {
  final String edition;
  final int version;
  final String appTitle;
  final String tagline;
  final int? expectedTotalWeeklyMinutes;
  final List<CategoryModel> categories;
  final List<TaskModel> tasks;
  final List<CalendarEventModel> calendarEvents;
  final List<AcademicMilestoneModel> academicMilestones;
  final List<String> warnings;
  final List<String> validationErrors;

  const SeedParseResult({
    required this.edition,
    required this.version,
    required this.appTitle,
    required this.tagline,
    this.expectedTotalWeeklyMinutes,
    required this.categories,
    required this.tasks,
    required this.calendarEvents,
    required this.academicMilestones,
    this.warnings = const [],
    this.validationErrors = const [],
  });

  /// Total minutes allocated across all parsed categories.
  int get totalCategoryMinutes =>
      categories.fold(0, (sum, c) => sum + c.weeklyTargetMinutes);

  /// True if there are zero fatal validation errors and at least one category.
  bool get isValid => validationErrors.isEmpty && categories.isNotEmpty;

  @override
  String toString() {
    return 'SeedParseResult(edition: $edition, version: $version, categories: ${categories.length}, '
        'totalMinutes: $totalCategoryMinutes, tasks: ${tasks.length}, events: ${calendarEvents.length}, '
        'milestones: ${academicMilestones.length}, errors: ${validationErrors.length}, warnings: ${warnings.length})';
  }
}

/// Structured outcome of a lossless seed data repair operation.
class SeedRepairReport {
  final int categoriesAdded;
  final int tasksAdded;
  final int eventsAdded;
  final int milestonesAdded;
  final int budgetsEnsured;
  final bool cleanedFallback;
  final String message;

  const SeedRepairReport({
    required this.categoriesAdded,
    required this.tasksAdded,
    required this.eventsAdded,
    required this.milestonesAdded,
    required this.budgetsEnsured,
    required this.cleanedFallback,
    required this.message,
  });

  @override
  String toString() => message;
}

/// Comprehensive, validating seed parser that normalizes both public and personal
/// seed files into strongly-typed domain models.
///
/// Features:
/// - Supports both camelCase (JSON seeds) and snake_case (SQLite tables).
/// - Normalizes hex color strings (#06B6D4) into ARGB integers (0xFF06B6D4).
/// - Normalizes scheduled days from both JSON List<int> and SQLite JSON string.
/// - Injects target week period ID into tasks if not pre-populated.
/// - Validates referential integrity: tasks and calendar events must reference real categories.
/// - Verifies total weekly minutes matching profile declaration (e.g. 1620 mins / 27h).
/// - Produces diagnostic warnings and errors rather than silent swallowing.
class SeedParser {
  static SeedParseResult parse(
    Map<String, dynamic> data, {
    String? targetWeekPeriodId,
  }) {
    final warnings = <String>[];
    final validationErrors = <String>[];

    final edition = (data['edition'] as String?) ?? 'public';
    final version = (data['version'] as num?)?.toInt() ?? 1;
    final appTitle = (data['appTitle'] ?? data['app_title'] as String?) ?? 'TEMPO';
    final tagline = (data['tagline'] as String?) ?? 'Own your hours.';

    int? expectedTotalWeeklyMinutes;
    if (data['userContext'] is Map) {
      final uc = data['userContext'] as Map;
      expectedTotalWeeklyMinutes = (uc['totalWeeklyMinutes'] as num?)?.toInt();
    }

    final weekPeriodId = targetWeekPeriodId ?? FlutterTimeEngine.getWeekPeriod().id;

    // 1. Categories
    final categories = <CategoryModel>[];
    final rawCats = data['categories'];
    if (rawCats is List) {
      for (int i = 0; i < rawCats.length; i++) {
        final item = rawCats[i];
        if (item is Map) {
          try {
            final catMap = Map<String, dynamic>.from(item);
            final id = (catMap['id'] as String?)?.trim();
            final name = (catMap['name'] as String?)?.trim();

            if (id == null || id.isEmpty) {
              validationErrors.add('Category at index $i is missing an "id"');
              continue;
            }
            if (name == null || name.isEmpty) {
              validationErrors.add('Category "$id" is missing a "name"');
              continue;
            }

            final category = CategoryModel.fromMap(catMap);
            categories.add(category);
          } catch (e) {
            validationErrors.add('Failed to parse category at index $i: $e');
          }
        } else {
          validationErrors.add('Category entry at index $i is not a Map');
        }
      }
    } else {
      validationErrors.add('Missing or invalid "categories" array in seed');
    }

    // Validate expected total weekly minutes if specified
    if (expectedTotalWeeklyMinutes != null && categories.isNotEmpty) {
      final actualSum = categories.fold(0, (sum, c) => sum + c.weeklyTargetMinutes);
      if (actualSum != expectedTotalWeeklyMinutes) {
        warnings.add(
          'Total weekly target minutes ($actualSum) does not match expected totalWeeklyMinutes ($expectedTotalWeeklyMinutes)',
        );
      }
    }

    final knownCategoryIds = categories.map((c) => c.id).toSet();

    // 2. Tasks
    final tasks = <TaskModel>[];
    final rawTasks = data['tasks'];
    if (rawTasks is List) {
      for (int i = 0; i < rawTasks.length; i++) {
        final item = rawTasks[i];
        if (item is Map) {
          try {
            final taskMap = Map<String, dynamic>.from(item);
            final id = (taskMap['id'] as String?)?.trim();
            final catId = (taskMap['category_id'] ?? taskMap['categoryId'] as String?)?.trim();
            final title = (taskMap['title'] as String?)?.trim();

            if (id == null || id.isEmpty) {
              validationErrors.add('Task at index $i is missing an "id"');
              continue;
            }
            if (catId == null || catId.isEmpty) {
              validationErrors.add('Task "$id" is missing "categoryId"');
              continue;
            }
            if (!knownCategoryIds.contains(catId)) {
              warnings.add('Task "$id" references unknown categoryId "$catId"');
            }
            if (title == null || title.isEmpty) {
              validationErrors.add('Task "$id" is missing a "title"');
              continue;
            }

            // Ensure week_period_id is assigned
            final rawWeek = taskMap['week_period_id'] ?? taskMap['weekPeriodId'];
            if (rawWeek == null || rawWeek.toString().isEmpty) {
              taskMap['week_period_id'] = weekPeriodId;
            }

            final task = TaskModel.fromMap(taskMap);
            tasks.add(task);
          } catch (e) {
            validationErrors.add('Failed to parse task at index $i: $e');
          }
        }
      }
    }

    // 3. Calendar Events
    final calendarEvents = <CalendarEventModel>[];
    final rawEvents = data['calendarEvents'] ?? data['calendar_events'];
    if (rawEvents is List) {
      for (int i = 0; i < rawEvents.length; i++) {
        final item = rawEvents[i];
        if (item is Map) {
          try {
            final evtMap = Map<String, dynamic>.from(item);
            final title = (evtMap['title'] as String?)?.trim();
            final catId = (evtMap['category_id'] ?? evtMap['categoryId'] as String?)?.trim();

            if (title == null || title.isEmpty) {
              validationErrors.add('Calendar event at index $i is missing a "title"');
              continue;
            }
            if (catId != null && !knownCategoryIds.contains(catId)) {
              warnings.add('Calendar event "$title" references unknown categoryId "$catId"');
            }

            final event = CalendarEventModel.fromMap(evtMap);
            calendarEvents.add(event);
          } catch (e) {
            validationErrors.add('Failed to parse calendar event at index $i: $e');
          }
        }
      }
    }

    // 4. Academic Milestones
    final milestones = <AcademicMilestoneModel>[];
    final rawMilestones = data['academicMilestones'] ?? data['academic_milestones'];
    if (rawMilestones is List) {
      for (int i = 0; i < rawMilestones.length; i++) {
        final item = rawMilestones[i];
        if (item is Map) {
          try {
            final msMap = Map<String, dynamic>.from(item);
            final title = (msMap['title'] as String?)?.trim();
            final startDate = (msMap['start_date'] ?? msMap['startDate'] as String?)?.trim();
            final endDate = (msMap['end_date'] ?? msMap['endDate'] as String?)?.trim();

            if (title == null || title.isEmpty) {
              validationErrors.add('Milestone at index $i is missing a "title"');
              continue;
            }
            if (startDate == null || startDate.isEmpty) {
              validationErrors.add('Milestone "$title" is missing a "startDate"');
              continue;
            }
            if (endDate == null || endDate.isEmpty) {
              validationErrors.add('Milestone "$title" is missing an "endDate"');
              continue;
            }

            final ms = AcademicMilestoneModel.fromMap(msMap);
            milestones.add(ms);
          } catch (e) {
            validationErrors.add('Failed to parse milestone at index $i: $e');
          }
        }
      }
    }

    return SeedParseResult(
      edition: edition,
      version: version,
      appTitle: appTitle,
      tagline: tagline,
      expectedTotalWeeklyMinutes: expectedTotalWeeklyMinutes,
      categories: categories,
      tasks: tasks,
      calendarEvents: calendarEvents,
      academicMilestones: milestones,
      warnings: warnings,
      validationErrors: validationErrors,
    );
  }
}
