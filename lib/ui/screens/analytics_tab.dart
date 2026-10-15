import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/time_engine.dart';
import '../../providers/tempo_providers.dart';
import '../widgets/active_session_bar.dart';
import '../widgets/icon_mapper.dart';

class AnalyticsTab extends ConsumerWidget {
  const AnalyticsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesNotifierProvider);
    final totalsMap = ref.watch(categoryTotalsMapProvider);
    final summary = ref.watch(weeklySummaryProvider);
    final sessions = ref.watch(sessionsNotifierProvider);
    final week = ref.watch(currentWeekPeriodProvider);
    final dayDistribution = FlutterTimeEngine.calculateDayDistribution(
      sessions: sessions,
      weekPeriodId: week.id,
    );

    final dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    final maxDaySec = dayDistribution.values.fold(0, (maxVal, val) => max(maxVal, val));

    // Sort categories by spent time descending
    final sortedCategories = [...categories];
    sortedCategories.sort((a, b) {
      final spentA = totalsMap[a.id]?.spentSeconds ?? 0;
      final spentB = totalsMap[b.id]?.spentSeconds ?? 0;
      return spentB.compareTo(spentA);
    });

    final totalSpentSec = summary.totalSpentMinutes * 60;

    return ListView(
      padding: const EdgeInsets.only(bottom: 90),
      children: [
        const ActiveSessionBar(),

        // High-level Performance Metrics
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Toplam Çalışma', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        FlutterTimeEngine.formatMinutes(summary.totalSpentMinutes),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Havuz Rezervi', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        FlutterTimeEngine.formatMinutes(summary.poolBalanceMinutes),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'monospace', color: Color(0xFF06B6D4)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Oturum Sayısı', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        '${sessions.length}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'monospace', color: Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Day of the Week Activity Bar Chart
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bar_chart, size: 18, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Text('Günlük Çalışma Dağılımı', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (i) {
                    final dayNum = i + 1;
                    final sec = dayDistribution[dayNum] ?? 0;
                    final heightFactor = maxDaySec > 0 ? (sec / maxDaySec) : 0.0;
                    final barHeight = (heightFactor * 100).clamp(6.0, 100.0);
                    final isToday = DateTime.now().weekday == dayNum;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (sec > 0)
                          Text(
                            '${(sec / 60).round()}m',
                            style: const TextStyle(fontSize: 9, color: Colors.grey),
                          ),
                        const SizedBox(height: 4),
                        Container(
                          width: 24,
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: isToday ? const Color(0xFF2563EB) : const Color(0xFF2563EB).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dayNames[i],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            color: isToday ? const Color(0xFF2563EB) : Colors.grey,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
        ),

        // "Zamanım Nereye Gidiyor?" — Category Breakdown
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.pie_chart_outline, size: 18, color: Color(0xFF06B6D4)),
                    SizedBox(width: 8),
                    Text('Zamanım Nereye Gidiyor?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Bu hafta oturumların kategorilere göre gerçek oransal dağılımı',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ...sortedCategories.map((cat) {
                  final totals = totalsMap[cat.id];
                  final spentSec = totals?.spentSeconds ?? 0;
                  final spentMin = totals?.spentMinutes ?? 0;
                  final ratio = totalSpentSec > 0 ? (spentSec / totalSpentSec) : 0.0;
                  final percent = (ratio * 100).round();

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(IconMapper.getIcon(cat.icon), size: 16, color: cat.color),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                cat.name,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(
                              '${FlutterTimeEngine.formatMinutes(spentMin)} (%$percent)',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: ratio.clamp(0.0, 1.0),
                            minHeight: 5,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation(cat.color),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // Weekly Reflection & Health Assessment
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.insights, size: 18, color: Color(0xFF10B981)),
                    SizedBox(width: 8),
                    Text('Haftalık Bütçe Değerlendirmesi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  summary.totalSpentMinutes >= summary.totalTargetMinutes
                      ? 'Tebrikler! Bu haftalık hedeflenen zaman bütçeni başarıyla tamamladın veya aştın.'
                      : 'Haftalık bütçenin %${summary.totalTargetMinutes > 0 ? ((summary.totalSpentMinutes / summary.totalTargetMinutes) * 100).round() : 0}\'ini kullandın. Kalan süreyi öncelikli işlerine odaklayabilir veya serbest havuza devredebilirsin.',
                  style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
