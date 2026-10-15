import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models.dart';
import '../../domain/time_engine.dart';
import '../../providers/tempo_providers.dart';
import '../widgets/active_session_bar.dart';

class PoolTab extends ConsumerWidget {
  const PoolTab({super.key});

  void _showTransferDialog(BuildContext context, WidgetRef ref, {required bool isToPool}) {
    final categories = ref.read(categoriesNotifierProvider);
    final totalsMap = ref.read(categoryTotalsMapProvider);
    final pool = ref.read(poolBalanceProvider);

    if (categories.isEmpty) return;

    String selectedCatId = categories.first.id;
    final minutesController = TextEditingController(text: '30');

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
            final cat = categories.firstWhere((c) => c.id == selectedCatId);
            final totals = totalsMap[cat.id];
            final maxRem = totals != null ? (totals.remainingMinutes > 0 ? totals.remainingMinutes : 0) : 0;

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isToPool ? 'Havuza Süre Aktar (Rollover)' : 'Havuzdan Kategoriye Dağıt',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isToPool
                        ? 'İşleri erken biten kategoriden kalan süreyi serbest havuza aktar.'
                        : 'Havuzda biriken serbest dakikaları dilediğin kategoriye ekle.',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCatId,
                    decoration: InputDecoration(
                      labelText: isToPool ? 'Kaynak Kategori' : 'Hedef Kategori',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    items: categories.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedCatId = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  if (isToPool && totals != null)
                    Text(
                      'Bu kategoride aktarılabilir kalan: ${FlutterTimeEngine.formatMinutes(maxRem)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    )
                  else if (!isToPool)
                    Text(
                      'Havuzda mevcut bakiye: ${FlutterTimeEngine.formatMinutes(pool.balanceMinutes)}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF06B6D4)),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: minutesController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Süre (Dakika)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        final mins = int.tryParse(minutesController.text.trim()) ?? 0;
                        if (mins <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Süre 0 dakikadan büyük olmalıdır!')),
                          );
                          return;
                        }

                        if (totals == null) return;

                        final val = FlutterTimeEngine.validateTransfer(
                          type: isToPool ? 'to_pool' : 'from_pool',
                          minutes: mins,
                          categoryTotals: totals,
                          poolBalanceMinutes: pool.balanceMinutes,
                          categoryPolicy: cat.policy,
                        );

                        if (!val.isValid) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(val.errorMessage ?? 'Geçersiz transfer')),
                          );
                          return;
                        }

                        final week = ref.read(currentWeekPeriodProvider);
                        final tx = PoolTransactionModel(
                          id: const Uuid().v4(),
                          type: isToPool ? 'rollover_to_pool' : 'pool_to_category',
                          sourceCategoryId: isToPool ? cat.id : null,
                          targetCategoryId: isToPool ? null : cat.id,
                          minutes: mins,
                          weekPeriodId: week.id,
                          timestamp: DateTime.now(),
                        );

                        ref.read(transactionsNotifierProvider.notifier).addTransaction(tx);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$mins dk başarıyla aktarıldı.')),
                        );
                      },
                      child: const Text('Aktarımı Onayla', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pool = ref.watch(poolBalanceProvider);
    final transactions = ref.watch(transactionsNotifierProvider);
    final categories = ref.watch(categoriesNotifierProvider);

    final lastActiveTx = transactions.where((t) => !t.isUndone).toList();
    final canUndo = lastActiveTx.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.only(bottom: 90),
      children: [
        const ActiveSessionBar(),

        // Large Glowing Reservoir Droplet Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF06B6D4).withOpacity(0.18),
                  const Color(0xFF2563EB).withOpacity(0.08),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.35)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF06B6D4).withOpacity(0.15),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.water_drop, color: Color(0xFF06B6D4), size: 30),
                ),
                const SizedBox(height: 12),
                const Text(
                  'SERBEST ZAMAN HAVUZU',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Color(0xFF06B6D4),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  FlutterTimeEngine.formatMinutes(pool.balanceMinutes),
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Kazanılan ve dilediğince harcanabilir serbest zaman',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 24),

                // Quick Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF06B6D4)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.arrow_downward, size: 16, color: Color(0xFF06B6D4)),
                        label: const Text('Havuza Aktar', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 13, fontWeight: FontWeight.bold)),
                        onPressed: () => _showTransferDialog(context, ref, isToPool: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.arrow_upward, size: 16),
                        label: const Text('Havuzdan Dağıt', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        onPressed: pool.balanceMinutes > 0
                            ? () => _showTransferDialog(context, ref, isToPool: false)
                            : null,
                      ),
                    ),
                  ],
                ),

                if (canUndo) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.undo, size: 16, color: Colors.grey),
                    label: const Text('Son Transferi Geri Al (Undo)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    onPressed: () {
                      final last = lastActiveTx.first;
                      ref.read(transactionsNotifierProvider.notifier).undoTransaction(last.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Son işlem geri alındı.')),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),

        // Transaction Ledger Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Transfer Geçmişi & Defteri',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Text(
                '${transactions.length} Kayıt',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),

        // Ledger List
        if (transactions.isEmpty)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Text(
                'Bu haftalık henüz transfer kaydı yok.\nErken biten işlerinden artan dakikaları havuza aktarabilirsin.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          )
        else
          ...transactions.map((tx) {
            final isToPool = tx.type == 'rollover_to_pool';
            String catName = '';
            if (isToPool && tx.sourceCategoryId != null) {
              final c = categories.where((x) => x.id == tx.sourceCategoryId).toList();
              if (c.isNotEmpty) catName = c.first.name;
            } else if (!isToPool && tx.targetCategoryId != null) {
              final c = categories.where((x) => x.id == tx.targetCategoryId).toList();
              if (c.isNotEmpty) catName = c.first.name;
            }

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: tx.isUndone
                      ? Colors.grey.withOpacity(0.2)
                      : (isToPool ? const Color(0xFF10B981).withOpacity(0.2) : const Color(0xFF2563EB).withOpacity(0.2)),
                ),
              ),
              child: ListTile(
                dense: true,
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: tx.isUndone
                        ? Colors.grey.withOpacity(0.1)
                        : (isToPool ? const Color(0xFF10B981).withOpacity(0.1) : const Color(0xFF2563EB).withOpacity(0.1)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isToPool ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 16,
                    color: tx.isUndone
                        ? Colors.grey
                        : (isToPool ? const Color(0xFF10B981) : const Color(0xFF2563EB)),
                  ),
                ),
                title: Text(
                  isToPool
                      ? '$catName ➔ Havuz'
                      : 'Havuz ➔ $catName',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    decoration: tx.isUndone ? TextDecoration.lineThrough : null,
                    color: tx.isUndone ? Colors.grey : null,
                  ),
                ),
                subtitle: Text(
                  tx.isUndone ? 'İptal Edildi' : 'Onaylandı',
                  style: TextStyle(fontSize: 11, color: tx.isUndone ? Colors.red : Colors.grey),
                ),
                trailing: Text(
                  '${isToPool ? '+' : '-'}${tx.minutes} dk',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    color: tx.isUndone
                        ? Colors.grey
                        : (isToPool ? const Color(0xFF10B981) : const Color(0xFF2563EB)),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
