import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models.dart';
import '../../domain/time_engine.dart';
import '../../providers/tempo_providers.dart';
import '../widgets/active_session_bar.dart';
import '../widgets/icon_mapper.dart';
import 'focus_timer_modal.dart';

class TodayTab extends ConsumerWidget {
  const TodayTab({super.key});

  void _showAddTaskDialog(BuildContext context, WidgetRef ref, List<CategoryModel> categories) {
    if (categories.isEmpty) return;

    final titleController = TextEditingController();
    final minutesController = TextEditingController(text: '45');
    String selectedCatId = categories.first.id;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Bugüne Görev Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Görev Başlığı',
                      hintText: 'Örn: RF Noise Figure problemlerini çöz',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: selectedCatId,
                    decoration: InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    items: categories.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Row(
                          children: [
                            Icon(IconMapper.getIcon(c.icon), size: 16, color: c.color),
                            const SizedBox(width: 8),
                            Text(c.name),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedCatId = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: minutesController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Tahmini Süre (Dakika)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isNotEmpty) {
                      final mins = int.tryParse(minutesController.text.trim()) ?? 45;
                      final week = ref.read(currentWeekPeriodProvider);
                      final now = DateTime.now();
                      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

                      final task = TaskModel(
                        id: const Uuid().v4(),
                        categoryId: selectedCatId,
                        title: title,
                        estimatedMinutes: mins,
                        plannedDate: todayStr,
                        dueDate: todayStr,
                        weekPeriodId: week.id,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );
                      ref.read(tasksNotifierProvider.notifier).addTask(task);
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Ekle'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesNotifierProvider);
    final summary = ref.watch(weeklySummaryProvider);
    final planning = ref.watch(planningAnalysisProvider);
    final allTasks = ref.watch(tasksNotifierProvider);
    final allEvents = ref.watch(calendarEventsNotifierProvider);

    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final dayNames = ['PAZARTESİ', 'SALI', 'ÇARŞAMBA', 'PERŞEMBE', 'CUMA', 'CUMARTESİ', 'PAZAR'];
    final monthNames = ['OCAK', 'ŞUBAT', 'MART', 'NİSAN', 'MAYIS', 'HAZİRAN', 'TEMMUZ', 'AĞUSTOS', 'EYLÜL', 'EKİM', 'KASIM', 'ARALIK'];
    final currentDayStr = dayNames[now.weekday - 1];
    final currentDateFormatted = '${now.day} ${monthNames[now.month - 1]} ${now.year}';

    // Today's events sorted by start time
    final todayEvents = allEvents.where((e) {
      if (e.specificDate != null && e.specificDate == todayStr) return true;
      return e.dayOfWeek == now.weekday;
    }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));

    // Next upcoming event
    final currentTimeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final upcomingEvents = todayEvents.where((e) => e.startTime.compareTo(currentTimeStr) >= 0).toList();
    final nextEvent = upcomingEvents.isNotEmpty ? upcomingEvents.first : (todayEvents.isNotEmpty ? todayEvents.last : null);

    // Today's tasks (planned or due today, or fallback to first 4 active tasks)
    final todayTasks = allTasks.where((t) {
      if (t.status == TaskStatus.done) return false;
      if (t.plannedDate == todayStr || t.dueDate == todayStr) return true;
      return false;
    }).toList();
    final tasksToShow = todayTasks.isNotEmpty ? todayTasks : allTasks.where((t) => t.status != TaskStatus.done).take(4).toList();
    final completedTodayCount = allTasks.where((t) => t.status == TaskStatus.done && t.completedAt != null && t.completedAt!.day == now.day).length;

    // Tomorrow's first event / wake up reminder
    final tomorrowWeekday = now.weekday == 7 ? 1 : now.weekday + 1;
    final tomorrowEvents = allEvents.where((e) => e.dayOfWeek == tomorrowWeekday).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final tomorrowFirst = tomorrowEvents.isNotEmpty ? tomorrowEvents.first : null;
    final tomorrowWakeUp = (tomorrowWeekday == 2 || tomorrowWeekday == 4) ? '07:00 (Staj Günü)' : '08:15';

    return ListView(
      padding: const EdgeInsets.only(bottom: 90),
      children: [
        const ActiveSessionBar(),

        // 1. TOP MORNING DASHBOARD BANNER
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2563EB).withOpacity(0.18),
                  const Color(0xFF06B6D4).withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentDayStr,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            color: Color(0xFF06B6D4),
                          ),
                        ),
                        Text(
                          currentDateFormatted,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Vizeye ${planning.daysToMidterms} Gün',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Bugün kontrol sende. Plan everything. Force nothing. Finish what matters.',
                  style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 16),

                // Quick Snapshot Row
                Row(
                  children: [
                    _buildSnapshotItem('Zorunlu Blok', '${todayEvents.length}'),
                    _buildSnapshotItem('Bugün Görev', '${tasksToShow.length}'),
                    _buildSnapshotItem('Haftalık Bütçe', '${summary.totalSpentMinutes}/${summary.totalTargetMinutes} dk'),
                    _buildSnapshotItem('Havuz', FlutterTimeEngine.formatMinutes(summary.poolBalanceMinutes)),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Capacity Deficit Alert Banner if applicable
        if (planning.hasCapacityDeficit)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFF59E0B)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Planlama Açığı: Bu hafta ${FlutterTimeEngine.formatMinutes(planning.capacityDeficitMinutes)} fazla iş var. Görevleri yeniden dengele veya ertele.',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B)),
                  ),
                ),
              ],
            ),
          ),

        // 2. NEXT UPCOMING EVENT HIGHLIGHT
        if (nextEvent != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF06B6D4), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sıradaki Etkinlik', style: TextStyle(fontSize: 10, color: Colors.white38)),
                        Text(nextEvent.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('${nextEvent.startTime} – ${nextEvent.endTime}', style: const TextStyle(fontSize: 11, color: Color(0xFF06B6D4))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 3. TODAY'S TASKS SECTION
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'BUGÜNÜN GÖREVLERİ',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.white70),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Color(0xFF2563EB), size: 24),
                tooltip: 'Görev Ekle',
                onPressed: () => _showAddTaskDialog(context, ref, categories),
              ),
            ],
          ),
        ),

        if (tasksToShow.isEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: const Center(
              child: Text(
                'Bugün için planlanan bekleyen görev yok.\nHarika durumdasın! Dinlen veya odak başlat.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white54, height: 1.4),
              ),
            ),
          )
        else
          ...tasksToShow.map((task) {
            final cat = categories.firstWhere(
              (c) => c.id == task.categoryId,
              orElse: () => categories.first,
            );
            final isDone = task.status == TaskStatus.done;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDone ? Colors.white10 : cat.color.withOpacity(0.3)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                leading: Checkbox(
                  value: isDone,
                  activeColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                  onChanged: (_) {
                    ref.read(tasksNotifierProvider.notifier).toggleTaskStatus(task.id);
                  },
                ),
                title: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Icon(IconMapper.getIcon(cat.icon), size: 11, color: cat.color),
                    const SizedBox(width: 4),
                    Text(cat.name, style: TextStyle(fontSize: 10, color: cat.color, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Text('${task.estimatedMinutes} dk', style: const TextStyle(fontSize: 10, color: Colors.white38)),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.play_circle_fill, size: 24, color: Color(0xFF2563EB)),
                  tooltip: 'Odak Başlat',
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => FocusTimerModal(
                        preselectedCategoryId: task.categoryId,
                        preselectedTaskId: task.id,
                      ),
                    );
                  },
                ),
              ),
            );
          }),

        // 4. TODAY'S TIMELINE PREVIEW
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'GÜNLÜK ZAMAN ÇİZELGESİ',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.white70),
              ),
              Text(
                '${todayEvents.length} Blok',
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ],
          ),
        ),

        if (todayEvents.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text('Bugün takvimde tanımlı blok yok.', style: TextStyle(fontSize: 12, color: Colors.white38)),
          )
        else
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: todayEvents.map((evt) {
                Color c = const Color(0xFF2563EB);
                if (evt.isRest) c = const Color(0xFF10B981);
                if (evt.type == 'fitness') c = const Color(0xFFF97316);
                if (evt.type == 'internship') c = const Color(0xFF8B5CF6);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 76,
                        child: Text(
                          '${evt.startTime}–${evt.endTime}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c),
                        ),
                      ),
                      Container(
                        width: 3,
                        height: 24,
                        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          evt.title,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (evt.isRest)
                        const Text('🌱 Serbest', style: TextStyle(fontSize: 10, color: Color(0xFF10B981))),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

        // 5. EVENING REVIEW / GÜNÜN ÖZETİ
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            'GÜNÜN DEĞERLENDİRMESİ',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.white70),
          ),
        ),

        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildReviewMetric('Tamamlanan', '$completedTodayCount görev'),
                  _buildReviewMetric('Kalan', '${tasksToShow.length} görev'),
                  _buildReviewMetric('Ertelenen', '${planning.overdueTasks.length} iş'),
                ],
              ),
              const Divider(color: Colors.white10, height: 24),
              Row(
                children: [
                  const Icon(Icons.bedtime_outlined, size: 18, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Yarın Planı: Kalkış $tomorrowWakeUp${tomorrowFirst != null ? " • İlk: ${tomorrowFirst.title}" : ""}',
                      style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSnapshotItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.white54, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildReviewMetric(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38)),
      ],
    );
  }
}
