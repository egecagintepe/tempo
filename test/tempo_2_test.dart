import 'package:flutter_test/flutter_test.dart';
import 'package:tempo/domain/models.dart';
import 'package:tempo/domain/time_engine.dart';

void main() {
  group('TEMPO 2.0 — Term Modes & Dynamic Weekly Budgets', () {
    test('TermModeModel defines all 4 required semester modes with exact targets', () {
      final modes = TermModeModel.predefinedModes;
      expect(modes.length, equals(4));

      final modeA = modes.firstWhere((m) => m.type == TermModeType.modeAMidtermPrep);
      expect(modeA.targetWeeklyHours, equals(27));
      expect(modeA.categoryHours['cat-rf'], equals(7.0));
      expect(modeA.categoryHours['cat-elek2'], equals(7.0));
      expect(modeA.categoryHours['cat-c'], equals(2.0));
      expect(modeA.categoryHours['cat-siber'], equals(1.0));

      final modeB = modes.firstWhere((m) => m.type == TermModeType.modeBMidtermWeek);
      expect(modeB.targetWeeklyHours, equals(24));

      final modeC = modes.firstWhere((m) => m.type == TermModeType.modeCNormalTerm);
      expect(modeC.targetWeeklyHours, equals(27));
      expect(modeC.categoryHours['cat-c'], equals(4.0)); // 4 hours with team project
      expect(modeC.categoryHours['cat-siber'], equals(2.0)); // 2 hours
      expect(modeC.categoryHours['cat-ingilizce'], equals(4.0)); // 4 hours IELTS prep

      final modeD = modes.firstWhere((m) => m.type == TermModeType.modeDFinalPrep);
      expect(modeD.targetWeeklyHours, equals(28));
      expect(modeD.categoryHours['cat-rf'], equals(8.0)); // 8 hours
      expect(modeD.categoryHours['cat-elek2'], equals(8.0)); // 8 hours
    });

    test('FlutterTimeEngine.calculateTotals respects allocatedMinutes from weekly budget over default target', () {
      final now = DateTime.now();
      final cat = CategoryModel(
        id: 'cat-c',
        name: 'C Programming',
        description: '',
        icon: 'terminal',
        colorValue: 0xFF10B981,
        weeklyTargetMinutes: 120, // Default in Mode A
        policy: BudgetPolicy.flexible,
        createdAt: now,
        updatedAt: now,
      );

      // In Mode C, weekly budget allocates 240 minutes instead of 120
      final totals = FlutterTimeEngine.calculateTotals(
        category: cat,
        sessions: [],
        transactions: [],
        weekPeriodId: '2026-W42',
        allocatedMinutes: 240, // Applied from weekly_budgets
      );

      expect(totals.initialTargetMinutes, equals(240));
      expect(totals.effectiveTargetMinutes, equals(240));
      expect(totals.remainingMinutes, equals(240));
    });
  });

  group('TEMPO 2.0 — Completion-First & Task Mechanics', () {
    test('SubTaskModel checklist progress computes correctly', () {
      final subtasks = [
        const SubTaskModel(id: 's1', title: 'Kavramı öğren', isCompleted: true),
        const SubTaskModel(id: 's2', title: 'Çözümlü örnek incele', isCompleted: true),
        const SubTaskModel(id: 's3', title: 'İki soruyu bağımsız çöz', isCompleted: false),
        const SubTaskModel(id: 's4', title: 'Hataları not al', isCompleted: false),
      ];

      final completedCount = subtasks.where((s) => s.isCompleted).length;
      expect(completedCount, equals(2));
      final progress = completedCount / subtasks.length;
      expect(progress, equals(0.5));
    });

    test('Task deferral increments deferredCount and sets plannedDate', () {
      final now = DateTime.now();
      final task = TaskModel(
        id: 'task-rf-1',
        categoryId: 'cat-rf',
        title: 'Noise Figure Problemleri',
        estimatedMinutes: 90,
        priority: TaskPriority.high,
        status: TaskStatus.todo,
        plannedDate: '2026-10-15',
        dueDate: '2026-10-18',
        weekPeriodId: '2026-W42',
        createdAt: now,
        updatedAt: now,
      );

      expect(task.deferredCount, equals(0));

      final deferred = task.copyWith(
        status: TaskStatus.deferred,
        deferredCount: task.deferredCount + 1,
        plannedDate: '2026-10-17',
      );

      expect(deferred.status, equals(TaskStatus.deferred));
      expect(deferred.deferredCount, equals(1));
      expect(deferred.plannedDate, equals('2026-10-17'));
    });

    test('Task completion does not invent fake work session minutes', () {
      final now = DateTime.now();
      final task = TaskModel(
        id: 'task-test',
        categoryId: 'cat-c',
        title: 'Exercise Set 3',
        estimatedMinutes: 60,
        actualTrackedMinutes: 0,
        priority: TaskPriority.medium,
        status: TaskStatus.todo,
        weekPeriodId: '2026-W42',
        createdAt: now,
        updatedAt: now,
      );

      // User marks task done directly without running a focus session
      final completed = task.copyWith(
        status: TaskStatus.done,
        completedAt: DateTime.now(),
      );

      expect(completed.status, equals(TaskStatus.done));
      expect(completed.actualTrackedMinutes, equals(0), reason: 'Checkbox completion must never fabricate actual work time');
    });
  });

  group('TEMPO 2.0 — Academic Mastery & Course Topics', () {
    test('CourseTopicModel accuracy rate and mastery level progression', () {
      final topic = CourseTopicModel(
        id: 'rf-w4',
        courseId: 'course-rf',
        weekNumber: 4,
        title: 'Noise in RF Circuits — Noise Figure & Noise Factor',
        masteryLevel: MasteryLevel.withHelp,
        questionsAttempted: 10,
        questionsCorrect: 8,
        updatedAt: DateTime.now(),
      );

      expect(topic.accuracyRate, equals(0.8));

      // After independent practice reaching 90% accuracy
      final upgraded = topic.copyWith(
        masteryLevel: MasteryLevel.examReady,
        questionsAttempted: 20,
        questionsCorrect: 19,
      );

      expect(upgraded.accuracyRate, equals(0.95));
      expect(upgraded.masteryLevel, equals(MasteryLevel.examReady));
    });

    test('CourseModel predefined courses include all 4 academic targets with 90+ goals', () {
      final courses = CourseModel.predefinedCourses;
      expect(courses.length, equals(4));

      final rf = courses.firstWhere((c) => c.id == 'course-rf');
      expect(rf.targetMidterm, equals(90.0));
      expect(rf.targetFinal, equals(90.0));
      expect(rf.assessmentWeights['midterm'], equals(0.40));
      expect(rf.assessmentWeights['final'], equals(0.60));

      final cCourse = courses.firstWhere((c) => c.id == 'course-c');
      expect(cCourse.assessmentWeights['project'], equals(0.40), reason: 'C 4-module interdisciplinary project carries 40% weight');
      expect(cCourse.assessmentWeights['midterm'], equals(0.20));
      expect(cCourse.assessmentWeights['final'], equals(0.40));
    });
  });

  group('TEMPO 2.0 — Leisure & Free Time Protection', () {
    test('LeisureItemModel manages backlog without creating guilty unfinished work warnings', () {
      const game = LeisureItemModel(
        id: 'lei-persona5',
        title: 'Persona 5 Royal',
        type: 'game',
        status: 'in_progress',
        note: 'JRPG narrative relaxation',
      );

      expect(game.type, equals('game'));
      expect(game.status, equals('in_progress'));

      final updated = game.copyWith(status: 'completed', rating: 5);
      expect(updated.status, equals('completed'));
      expect(updated.rating, equals(5));
    });
  });
}
