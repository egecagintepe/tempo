import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models.dart';
import '../../domain/time_engine.dart';
import '../../providers/tempo_providers.dart';
import '../widgets/active_session_bar.dart';
import '../widgets/icon_mapper.dart';
import 'focus_timer_modal.dart';

class TasksTab extends ConsumerStatefulWidget {
  const TasksTab({super.key});

  @override
  ConsumerState<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends ConsumerState<TasksTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _activeFilter = 'all'; // 'all', 'overdue', 'academic', 'project', 'done'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showTaskDetailSheet(BuildContext context, TaskModel task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TaskDetailSheet(task: task),
    );
  }

  void _showCreateTaskDialog(BuildContext context) {
    final categories = ref.read(categoriesNotifierProvider);
    if (categories.isEmpty) return;

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final minutesController = TextEditingController(text: '45');
    String selectedCatId = categories.first.id;
    TaskPriority priority = TaskPriority.medium;
    DateTime? plannedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final theme = Theme.of(context);
            return AlertDialog(
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Yeni Görev Planla', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Açıklama / Hedef Notu (İsteğe Bağlı)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 12),
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
                        if (val != null) setDlgState(() => selectedCatId = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minutesController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Tahmini Süre (Dk)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<TaskPriority>(
                            value: priority,
                            decoration: InputDecoration(
                              labelText: 'Öncelik',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            items: const [
                              DropdownMenuItem(value: TaskPriority.high, child: Text('Yüksek 🔥')),
                              DropdownMenuItem(value: TaskPriority.medium, child: Text('Normal ⚡')),
                              DropdownMenuItem(value: TaskPriority.low, child: Text('Düşük 🌱')),
                            ],
                            onChanged: (val) {
                              if (val != null) setDlgState(() => priority = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Colors.white24),
                      ),
                      leading: const Icon(Icons.event_outlined, size: 20),
                      title: Text(
                        plannedDate == null
                            ? 'Planlanan Tarih Seç'
                            : 'Planlanan: ${plannedDate!.day}.${plannedDate!.month}.${plannedDate!.year}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_month, size: 18),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: plannedDate ?? DateTime.now(),
                            firstDate: DateTime(2026, 10, 1),
                            lastDate: DateTime(2027, 2, 1),
                          );
                          if (picked != null) {
                            setDlgState(() => plannedDate = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
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
                      final pDateStr = plannedDate != null
                          ? '${plannedDate!.year}-${plannedDate!.month.toString().padLeft(2, '0')}-${plannedDate!.day.toString().padLeft(2, '0')}'
                          : null;

                      final task = TaskModel(
                        id: const Uuid().v4(),
                        categoryId: selectedCatId,
                        title: title,
                        description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                        estimatedMinutes: mins,
                        priority: priority,
                        plannedDate: pDateStr,
                        dueDate: pDateStr,
                        weekPeriodId: week.id,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );
                      ref.read(tasksNotifierProvider.notifier).addTask(task);
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Görevi Oluştur'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final allTasks = ref.watch(tasksNotifierProvider);
    final categories = ref.watch(categoriesNotifierProvider);
    final planning = ref.watch(planningAnalysisProvider);

    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // 1. Filter by view (Bugün, Bu Hafta, Tümü)
    List<TaskModel> filterByTab(int tabIndex) {
      if (tabIndex == 0) {
        // Bugün: plannedDate or dueDate == today or high priority undone
        return allTasks.where((t) {
          if (t.plannedDate == todayStr || t.dueDate == todayStr) return true;
          return false;
        }).toList();
      } else if (tabIndex == 1) {
        // Bu Hafta
        return allTasks;
      } else {
        // Tümü
        return allTasks;
      }
    }

    // 2. Apply sub-filter
    List<TaskModel> applySubFilter(List<TaskModel> tasks) {
      var result = tasks;
      if (_searchQuery.isNotEmpty) {
        result = result.where((t) => t.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
      }
      switch (_activeFilter) {
        case 'overdue':
          result = result.where((t) {
            if (t.status == TaskStatus.done) return false;
            if (t.dueDate != null && t.dueDate!.compareTo(todayStr) < 0) return true;
            if (t.plannedDate != null && t.plannedDate!.compareTo(todayStr) < 0) return true;
            return false;
          }).toList();
          break;
        case 'academic':
          result = result.where((t) {
            final cat = categories.firstWhere((c) => c.id == t.categoryId, orElse: () => categories.first);
            return cat.id.contains('rf') || cat.id.contains('elek') || cat.id.contains('c') || cat.id.contains('siber');
          }).toList();
          break;
        case 'done':
          result = result.where((t) => t.status == TaskStatus.done).toList();
          break;
        case 'todo':
          result = result.where((t) => t.status != TaskStatus.done).toList();
          break;
        case 'high':
          result = result.where((t) => t.priority == TaskPriority.high && t.status != TaskStatus.done).toList();
          break;
      }
      return result;
    }

    return Scaffold(
      body: Column(
        children: [
          const ActiveSessionBar(),

          // Capacity Alert Banner if deficit exists
          if (planning.hasCapacityDeficit)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Kapasite Açığı: Bekleyen görevler kalan süreden ${FlutterTimeEngine.formatMinutes(planning.capacityDeficitMinutes)} fazla. Görev erteleme önerilir.',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B)),
                    ),
                  ),
                ],
              ),
            ),

          // Search and Filter Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Görev ara...',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.white38),
                        prefixIcon: Icon(Icons.search, size: 18),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  icon: const Icon(Icons.add, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  tooltip: 'Yeni Görev',
                  onPressed: () => _showCreateTaskDialog(context),
                ),
              ],
            ),
          ),

          // Sub-filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('Tümü', 'all'),
                _buildFilterChip('Yapılacaklar', 'todo'),
                _buildFilterChip('Gecikenler (${planning.overdueTasks.length})', 'overdue', isAlert: planning.hasOverdue),
                _buildFilterChip('Yüksek Öncelik 🔥', 'high'),
                _buildFilterChip('Akademik 🎓', 'academic'),
                _buildFilterChip('Tamamlananlar ✓', 'done'),
              ],
            ),
          ),

          // Primary Tabs: Bugün / Bu Hafta / Tümü
          TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF2563EB),
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
            tabs: [
              Tab(text: 'Bugün (${filterByTab(0).where((t) => t.status != TaskStatus.done).length})'),
              Tab(text: 'Bu Hafta (${filterByTab(1).where((t) => t.status != TaskStatus.done).length})'),
              Tab(text: 'Tümü (${allTasks.length})'),
            ],
          ),

          // Task Lists
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTaskList(applySubFilter(filterByTab(0))),
                _buildTaskList(applySubFilter(filterByTab(1))),
                _buildTaskList(applySubFilter(filterByTab(2))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String key, {bool isAlert = false}) {
    final isSelected = _activeFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isAlert && !isSelected ? const Color(0xFFEF4444) : null,
          ),
        ),
        backgroundColor: isAlert ? const Color(0xFFEF4444).withOpacity(0.12) : null,
        selectedColor: const Color(0xFF2563EB).withOpacity(0.2),
        checkmarkColor: const Color(0xFF2563EB),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (_) => setState(() => _activeFilter = key),
      ),
    );
  }

  Widget _buildTaskList(List<TaskModel> tasks) {
    if (tasks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_alt_outlined, size: 48, color: Colors.white24),
            SizedBox(height: 12),
            Text(
              'Bu görünümde görev yok.',
              style: TextStyle(fontSize: 14, color: Colors.white54, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 4),
            Text(
              'Dinlen veya yeni bir görev planla.',
              style: TextStyle(fontSize: 12, color: Colors.white38),
            ),
          ],
        ),
      );
    }

    final categories = ref.watch(categoriesNotifierProvider);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final cat = categories.firstWhere(
          (c) => c.id == task.categoryId,
          orElse: () => categories.first,
        );

        final isDone = task.status == TaskStatus.done;
        final subtaskCompleted = task.subtasks.where((s) => s.isCompleted).length;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: isDone ? Colors.white10 : cat.color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _showTaskDetailSheet(context, task),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Interactive Checkbox
                      Transform.scale(
                        scale: 1.15,
                        child: Checkbox(
                          value: isDone,
                          activeColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          onChanged: (_) {
                            ref.read(tasksNotifierProvider.notifier).toggleTaskStatus(task.id);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Task Title & Category Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                decoration: isDone ? TextDecoration.lineThrough : null,
                                color: isDone ? Colors.white38 : null,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(IconMapper.getIcon(cat.icon), size: 12, color: cat.color),
                                const SizedBox(width: 4),
                                Text(
                                  cat.name,
                                  style: TextStyle(fontSize: 11, color: cat.color, fontWeight: FontWeight.bold),
                                ),
                                if (task.plannedDate != null) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.calendar_today, size: 10, color: Colors.white38),
                                  const SizedBox(width: 3),
                                  Text(
                                    task.plannedDate!,
                                    style: const TextStyle(fontSize: 10, color: Colors.white54),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Priority Chip
                      if (task.priority == TaskPriority.high && !isDone)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('🔥 Acil', style: TextStyle(fontSize: 10, color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                        ),

                      const SizedBox(width: 6),

                      // Quick Focus Start Action
                      if (!isDone)
                        IconButton(
                          icon: const Icon(Icons.play_circle_fill, size: 26, color: Color(0xFF2563EB)),
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
                    ],
                  ),

                  // Subtasks indicator & time track footer
                  if (task.subtasks.isNotEmpty || task.actualTrackedMinutes > 0 || task.estimatedMinutes > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 48, top: 4),
                      child: Row(
                        children: [
                          if (task.subtasks.isNotEmpty) ...[
                            const Icon(Icons.checklist, size: 13, color: Colors.white54),
                            const SizedBox(width: 4),
                            Text(
                              '$subtaskCompleted/${task.subtasks.length} alt görev',
                              style: const TextStyle(fontSize: 11, color: Colors.white54),
                            ),
                            const SizedBox(width: 12),
                          ],
                          const Icon(Icons.timer_outlined, size: 13, color: Colors.white38),
                          const SizedBox(width: 3),
                          Text(
                            task.actualTrackedMinutes > 0
                                ? '${task.actualTrackedMinutes}/${task.estimatedMinutes} dk'
                                : '${task.estimatedMinutes} dk tahmini',
                            style: const TextStyle(fontSize: 11, color: Colors.white54),
                          ),
                          if (task.deferredCount > 0) ...[
                            const SizedBox(width: 12),
                            const Icon(Icons.update, size: 13, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 3),
                            Text(
                              '${task.deferredCount}x ertelendi',
                              style: const TextStyle(fontSize: 10, color: Color(0xFFF59E0B)),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TaskDetailSheet extends ConsumerStatefulWidget {
  final TaskModel task;
  const _TaskDetailSheet({required this.task});

  @override
  ConsumerState<_TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends ConsumerState<_TaskDetailSheet> {
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  final TextEditingController _newSubtaskController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _notesController = TextEditingController(text: widget.task.notes ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _newSubtaskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch latest task state
    final allTasks = ref.watch(tasksNotifierProvider);
    final currentTask = allTasks.firstWhere((t) => t.id == widget.task.id, orElse: () => widget.task);
    final categories = ref.watch(categoriesNotifierProvider);
    final cat = categories.firstWhere((c) => c.id == currentTask.categoryId, orElse: () => categories.first);

    final isDone = currentTask.status == TaskStatus.done;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Category & Priority Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cat.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cat.color.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(IconMapper.getIcon(cat.icon), size: 14, color: cat.color),
                      const SizedBox(width: 6),
                      Text(cat.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cat.color)),
                    ],
                  ),
                ),
                const Spacer(),
                if (currentTask.plannedDate != null)
                  Text(
                    'Plan: ${currentTask.plannedDate}',
                    style: const TextStyle(fontSize: 12, color: Colors.white60),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Task Title
            TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Görev başlığı',
              ),
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  ref.read(tasksNotifierProvider.notifier).updateTask(currentTask.copyWith(title: val.trim()));
                }
              },
            ),
            const Divider(color: Colors.white12),

            // Stats grid
            Row(
              children: [
                _buildStat('Tahmini', '${currentTask.estimatedMinutes} dk'),
                _buildStat('Kayıtlı Çalışma', '${currentTask.actualTrackedMinutes} dk'),
                _buildStat('Durum', isDone ? 'Tamamlandı ✓' : 'Bekliyor ⚡'),
              ],
            ),
            const SizedBox(height: 16),

            // Subtasks Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Alt Görevler / Kontrol Listesi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  '${currentTask.subtasks.where((s) => s.isCompleted).length}/${currentTask.subtasks.length}',
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Subtask items
            ...currentTask.subtasks.map((subtask) {
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: subtask.isCompleted,
                title: Text(
                  subtask.title,
                  style: TextStyle(
                    fontSize: 13,
                    decoration: subtask.isCompleted ? TextDecoration.lineThrough : null,
                    color: subtask.isCompleted ? Colors.white38 : null,
                  ),
                ),
                onChanged: (_) {
                  ref.read(tasksNotifierProvider.notifier).toggleSubtask(currentTask.id, subtask.id);
                },
              );
            }),

            // Add new subtask input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newSubtaskController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Alt görev ekle...',
                      hintStyle: const TextStyle(fontSize: 13, color: Colors.white38),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onSubmitted: (val) => _addNewSubtask(currentTask),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: () => _addNewSubtask(currentTask),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Action Buttons (Focus, Defer, Delete)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 20),
                    label: const Text('Odak Başlat', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => FocusTimerModal(
                          preselectedCategoryId: currentTask.categoryId,
                          preselectedTaskId: currentTask.id,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  ),
                  icon: const Icon(Icons.update, size: 18),
                  label: const Text('Ertele'),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2027, 2, 1),
                    );
                    if (picked != null) {
                      final pStr = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                      ref.read(tasksNotifierProvider.notifier).deferTask(currentTask.id, pStr);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                  tooltip: 'Sil',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        title: const Text('Görevi Sil?'),
                        content: const Text('Bu işlem geri alınamaz.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('İptal')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                            onPressed: () {
                              ref.read(tasksNotifierProvider.notifier).deleteTask(currentTask.id);
                              Navigator.pop(dCtx);
                              Navigator.pop(context);
                            },
                            child: const Text('Sil'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addNewSubtask(TaskModel task) {
    final title = _newSubtaskController.text.trim();
    if (title.isNotEmpty) {
      final newSt = SubTaskModel(
        id: const Uuid().v4(),
        title: title,
        isCompleted: false,
      );
      final updatedList = [...task.subtasks, newSt];
      ref.read(tasksNotifierProvider.notifier).updateTask(task.copyWith(subtasks: updatedList));
      _newSubtaskController.clear();
    }
  }

  Widget _buildStat(String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
