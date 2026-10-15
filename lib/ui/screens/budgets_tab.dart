import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models.dart';
import '../../domain/time_engine.dart';
import '../../providers/tempo_providers.dart';
import '../widgets/active_session_bar.dart';
import '../widgets/icon_mapper.dart';
import 'focus_timer_modal.dart';

class BudgetsTab extends ConsumerWidget {
  const BudgetsTab({super.key});

  void _showAddEditCategoryDialog(BuildContext context, WidgetRef ref, [CategoryModel? existing]) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final descController = TextEditingController(text: existing?.description ?? '');
    final minutesController = TextEditingController(text: (existing?.weeklyTargetMinutes ?? 120).toString());
    BudgetPolicy selectedPolicy = existing?.policy ?? BudgetPolicy.flexible;
    int selectedColor = existing?.colorValue ?? 0xFF2563EB;
    String selectedIcon = existing?.icon ?? 'circle';

    final colorPalette = [
      0xFF2563EB, // Blue
      0xFF06B6D4, // Cyan
      0xFF10B981, // Emerald
      0xFFF59E0B, // Amber
      0xFFF43F5E, // Rose
      0xFF8B5CF6, // Purple
      0xFFEC4899, // Pink
      0xFF14B8A6, // Teal
      0xFFF97316, // Orange
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      existing != null ? 'Kategoriyi Düzenle' : 'Yeni Kategori Ekle',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Kategori Adı',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      decoration: InputDecoration(
                        labelText: 'Açıklama',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: minutesController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Haftalık Hedef Süre (Dakika)',
                        helperText: 'Örn: 420 dk = 7 saat, 120 dk = 2 saat',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Bütçe Davranış Politikası', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<BudgetPolicy>(
                      value: selectedPolicy,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: BudgetPolicy.flexible,
                          child: Text('Esnek (Flexible) — Aşım takip edilir'),
                        ),
                        DropdownMenuItem(
                          value: BudgetPolicy.strict,
                          child: Text('Katı (Strict) — Süre dolunca kilitlenir'),
                        ),
                        DropdownMenuItem(
                          value: BudgetPolicy.protected,
                          child: Text('Korunan (Protected) — Süre aktarımı kısıtlı'),
                        ),
                        DropdownMenuItem(
                          value: BudgetPolicy.deadline,
                          child: Text('Teslim Odaklı (Deadline) — Bitiş tarihi bağlı'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => selectedPolicy = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text('Renk Seçimi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children: colorPalette.map((colVal) {
                        final isSel = selectedColor == colVal;
                        return GestureDetector(
                          onTap: () => setState(() => selectedColor = colVal),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Color(colVal),
                              shape: BoxShape.circle,
                              border: isSel ? Border.all(color: Colors.white, width: 3) : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(selectedColor),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          final name = nameController.text.trim();
                          if (name.isNotEmpty) {
                            final mins = int.tryParse(minutesController.text.trim()) ?? 60;
                            final now = DateTime.now();
                            if (existing != null) {
                              final updated = existing.copyWith(
                                name: name,
                                description: descController.text.trim(),
                                weeklyTargetMinutes: mins,
                                policy: selectedPolicy,
                                colorValue: selectedColor,
                                icon: selectedIcon,
                                updatedAt: now,
                              );
                              ref.read(categoriesNotifierProvider.notifier).updateCategory(updated);
                            } else {
                              final newCat = CategoryModel(
                                id: const Uuid().v4(),
                                name: name,
                                description: descController.text.trim(),
                                icon: selectedIcon,
                                colorValue: selectedColor,
                                weeklyTargetMinutes: mins,
                                policy: selectedPolicy,
                                createdAt: now,
                                updatedAt: now,
                              );
                              ref.read(categoriesNotifierProvider.notifier).addCategory(newCat);
                            }
                            Navigator.pop(ctx);
                          }
                        },
                        child: Text(existing != null ? 'Kaydet' : 'Kategori Oluştur', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Kategori Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showAddEditCategoryDialog(context, ref),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 90),
        children: [
          const ActiveSessionBar(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Bütçe Kategorileri',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${categories.length} Kategori',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          ...categories.map((cat) {
            final totals = totalsMap[cat.id];
            final effTarget = totals?.effectiveTargetMinutes ?? cat.weeklyTargetMinutes;
            final spent = totals?.spentMinutes ?? 0;
            final remaining = totals?.remainingMinutes ?? cat.weeklyTargetMinutes;
            final progress = totals?.progressPercent ?? 0;
            final isOver = totals?.isOverBudget ?? false;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isOver ? const Color(0xFFF43F5E).withOpacity(0.5) : cat.color.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: cat.color.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(IconMapper.getIcon(cat.icon), color: cat.color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    cat.name,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: cat.color.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    cat.policy.name.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: cat.color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (cat.description.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                cat.description,
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                        onPressed: () => _showAddEditCategoryDialog(context, ref, cat),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (progress / 100).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation(
                        isOver ? const Color(0xFFF43F5E) : cat.color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kullanılan: ${FlutterTimeEngine.formatMinutes(spent)} / ${FlutterTimeEngine.formatMinutes(effTarget)}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      Text(
                        isOver
                            ? 'Aşım: ${FlutterTimeEngine.formatMinutes(remaining.abs())}'
                            : 'Kalan: ${FlutterTimeEngine.formatMinutes(remaining)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isOver ? const Color(0xFFF43F5E) : (totals?.isExhausted == true ? const Color(0xFF10B981) : null),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Bottom Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: cat.color,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: const Text('Odaklan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              fullscreenDialog: true,
                              builder: (_) => FocusTimerModal(category: cat),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
