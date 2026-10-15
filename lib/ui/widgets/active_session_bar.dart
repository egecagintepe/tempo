import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models.dart';
import '../../domain/time_engine.dart';
import '../../providers/tempo_providers.dart';
import '../screens/focus_timer_modal.dart';
import 'icon_mapper.dart';

class ActiveSessionBar extends ConsumerWidget {
  const ActiveSessionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeSessionNotifierProvider);
    if (!active.isActive) return const SizedBox.shrink();

    final categories = ref.watch(categoriesNotifierProvider);
    final category = categories.firstWhere(
      (c) => c.id == active.categoryId,
      orElse: () => CategoryModel(
        id: active.categoryId ?? '',
        name: 'Oturum',
        description: '',
        icon: 'circle',
        colorValue: 0xFF2563EB,
        weeklyTargetMinutes: 60,
        policy: BudgetPolicy.flexible,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final isBreak = active.state == SessionState.onBreak;
    final isRunning = active.state == SessionState.running;

    final displaySeconds = isBreak
        ? active.currentBreakRemainingSeconds
        : active.currentWorkSeconds;

    final timeString = FlutterTimeEngine.formatStopwatch(displaySeconds, forceHours: false);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isBreak ? const Color(0xFFF59E0B) : category.color.withOpacity(0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isBreak ? const Color(0xFFF59E0B) : category.color).withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => FocusTimerModal(category: category),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Category Icon or Break Indicator
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isBreak
                        ? const Color(0xFFF59E0B).withOpacity(0.15)
                        : category.color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isBreak ? Icons.coffee : IconMapper.getIcon(category.icon),
                    color: isBreak ? const Color(0xFFF59E0B) : category.color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Title and State
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isBreak
                                  ? const Color(0xFFF59E0B)
                                  : (isRunning ? const Color(0xFF10B981) : Colors.grey),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isBreak
                                ? 'Mola (${active.plannedBreakMinutes}dk)'
                                : (isRunning ? 'Odaklanılıyor...' : 'Duraklatıldı'),
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Stopwatch time
                Text(
                  timeString,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 12),
                // Play / Pause Icon Button
                IconButton(
                  icon: Icon(
                    isRunning ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    size: 32,
                    color: isBreak ? const Color(0xFFF59E0B) : category.color,
                  ),
                  onPressed: () {
                    final notifier = ref.read(activeSessionNotifierProvider.notifier);
                    if (isRunning) {
                      notifier.pauseSession();
                    } else {
                      notifier.resumeSession();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
