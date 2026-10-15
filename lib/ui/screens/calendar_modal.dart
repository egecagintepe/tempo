import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/tempo_providers.dart';

class CalendarModal extends ConsumerWidget {
  const CalendarModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarEventsAsync = ref.watch(calendarEventsProvider);
    final milestonesAsync = ref.watch(academicMilestonesProvider);

    final dayNames = {
      1: 'Pazartesi',
      2: 'Salı',
      3: 'Çarşamba',
      4: 'Perşembe',
      5: 'Cuma',
      6: 'Cumartesi',
      7: 'Pazar',
    };

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Haftalık Rutin & Akademik Takvim', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
      ),
      body: calendarEventsAsync.when(
        data: (events) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Academic Milestones Section
              milestonesAsync.when(
                data: (milestones) {
                  if (milestones.isEmpty) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.school, size: 18, color: Color(0xFFF59E0B)),
                            SizedBox(width: 8),
                            Text('Akademik Dönem & Sınav Takvimi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFF59E0B))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...milestones.map((m) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(m.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text('${m.startDate} - ${m.endDate}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        )),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // Fixed Days Schedule
              ...List.generate(7, (i) {
                final dayNum = i + 1;
                final dayEvents = events.where((e) => e.dayOfWeek == dayNum).toList();
                if (dayEvents.isEmpty) return const SizedBox.shrink();

                final isToday = DateTime.now().weekday == dayNum;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isToday ? const Color(0xFF2563EB) : Theme.of(context).dividerColor.withOpacity(0.1),
                      width: isToday ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            dayNames[dayNum] ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isToday ? const Color(0xFF2563EB) : null,
                            ),
                          ),
                          if (isToday)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Bugün', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...dayEvents.map((e) {
                        Color badgeColor = const Color(0xFF2563EB);
                        if (e.type == 'internship') badgeColor = const Color(0xFFF59E0B);
                        if (e.type == 'sport') badgeColor = const Color(0xFF10B981);
                        if (e.type == 'rest') badgeColor = const Color(0xFF8B5CF6);

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 90,
                                child: Text(
                                  '${e.startTime} - ${e.endTime}',
                                  style: TextStyle(fontSize: 11, color: badgeColor, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  e.title,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Takvim yüklenemedi: $err')),
      ),
    );
  }
}
