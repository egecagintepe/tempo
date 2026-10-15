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
    final minutesController = TextEditingController(text: '30');
    String selectedCatId = categories.first.id;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Yeni Görev Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Görev Başlığı',
                      hintText: 'Örn: Bölüm okuması ve not çıkarma',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 16),
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
                      final mins = int.tryParse(minutesController.text.trim()) ?? 30;
                      final week = ref.read(currentWeekPeriodProvider);
                      final task = TaskModel(
                        id: const Uuid().v4(),
                        categoryId: selectedCatId,
                        title: title,
                        estimatedMinutes: mins,
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
    final totalsMap = ref.watch(categoryTotalsMapProvider);
    final summary = ref.watch(weeklySummaryProvider);
    final tasks = ref.watch(tasksNotifierProvider);
    final calendarEventsAsync = ref.watch(calendarEventsProvider);
    final todayWeekday = DateTime.now().weekday; // 1=Mon ... 7=Sun

    return ListView(
      padding: const EdgeInsets.only(bottom: 90),
      children: [
        // Sticky Active Session Bar
        const ActiveSessionBar(),

        // Top Weekly Budget Overview Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2563EB).withOpacity(0.12),
                  const Color(0xFF06B6D4).withOpacity(0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Haftalık Zaman Bütçesi',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF06B6D4)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.water_drop, size: 12, color: Color(0xFF06B6D4)),
                          const SizedBox(width: 4),
                          Text(
                            'Havuz: ${FlutterTimeEngine.formatMinutes(summary.poolBalanceMinutes)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      FlutterTimeEngine.formatMinutes(summary.totalRemainingMinutes),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                    ),
                    const SizedBox(width: 8),
                    const Text('kalan', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const Spacer(),
                    Text(
                      'Hedef: ${FlutterTimeEngine.formatMinutes(summary.totalTargetMinutes)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: summary.totalTargetMinutes > 0
                        ? (summary.totalSpentMinutes / summary.totalTargetMinutes).clamp(0.0, 1.0)
                        : 0.0,
                    minHeight: 8,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF2563EB)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Kullanılan: ${FlutterTimeEngine.formatMinutes(summary.totalSpentMinutes)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Text(
                      '${summary.completedCategoriesCount}/${summary.activeCategoriesCount} kategori tamamlandı',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Today's Scheduled Routine (from Calendar Events)
        calendarEventsAsync.when(
          data: (events) {
            final todayEvents = events.where((e) => e.dayOfWeek == todayWeekday).toList();
            if (todayEvents.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.calendar_month, size: 16, color: Color(0xFF06B6D4)),
                      SizedBox(width: 6),
                      Text(
                        'Bugünün Takvim Rutini',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 82,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: todayEvents.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (ctx, idx) {
                        final evt = todayEvents[idx];
                        Color badgeColor = const Color(0xFF2563EB);
                        if (evt.type == 'internship') badgeColor = const Color(0xFFF59E0B);
                        if (evt.type == 'sport') badgeColor = const Color(0xFF10B981);
                        if (evt.type == 'rest') badgeColor = const Color(0xFF8B5CF6);

                        return Container(
                          width: 170,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: badgeColor.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${evt.startTime} - ${evt.endTime}',
                                    style: TextStyle(fontSize: 11, color: badgeColor, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                evt.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        // Quick Focus Launch (Categories scheduled today or all)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hızlı Odaklan',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (ctx, idx) {
                    final cat = categories[idx];
                    final totals = totalsMap[cat.id];
                    final rem = totals?.remainingMinutes ?? cat.weeklyTargetMinutes;

                    return InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => FocusTimerModal(category: cat),
                          ),
                        );
                      },
                      child: Container(
                        width: 130,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cat.color.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(IconMapper.getIcon(cat.icon), size: 20, color: cat.color),
                                Icon(Icons.play_circle_outline, size: 20, color: cat.color.withOpacity(0.8)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  FlutterTimeEngine.formatMinutes(rem),
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Today's Tasks
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Haftalık Görevler',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Görev Ekle', style: TextStyle(fontSize: 12)),
                    onPressed: () => _showAddTaskDialog(context, ref, categories),
                  ),
                ],
              ),
              if (tasks.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Text(
                      'Bu haftalık kayıtlı görev yok.\nYeni görev ekleyerek zaman bütçeni hedeflerle eşleştir.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                )
              else
                ...tasks.map((task) {
                  final cat = categories.firstWhere(
                    (c) => c.id == task.categoryId,
                    orElse: () => CategoryModel(
                      id: task.categoryId,
                      name: '',
                      description: '',
                      icon: 'circle',
                      colorValue: 0xFF2563EB,
                      weeklyTargetMinutes: 60,
                      policy: BudgetPolicy.flexible,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  );

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: task.isCompleted
                            ? const Color(0xFF10B981).withOpacity(0.3)
                            : Theme.of(context).dividerColor.withOpacity(0.1),
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Checkbox(
                        value: task.isCompleted,
                        activeColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        onChanged: (_) {
                          ref.read(tasksNotifierProvider.notifier).toggleTaskStatus(task.id);
                        },
                      ),
                      title: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                          color: task.isCompleted ? Colors.grey : null,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          if (cat.name.isNotEmpty) ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(color: cat.color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 4),
                            Text(cat.name, style: TextStyle(fontSize: 11, color: cat.color)),
                            const SizedBox(width: 8),
                          ],
                          Text('${task.estimatedMinutes} dk', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                        onPressed: () {
                          ref.read(tasksNotifierProvider.notifier).deleteTask(task.id);
                        },
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}
