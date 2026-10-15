import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/tempo_theme.dart';
import '../../domain/models.dart';
import '../../domain/time_engine.dart';
import '../../providers/tempo_providers.dart';
import '../widgets/icon_mapper.dart';

class FocusTimerModal extends ConsumerStatefulWidget {
  final CategoryModel category;

  const FocusTimerModal({super.key, required this.category});

  @override
  ConsumerState<FocusTimerModal> createState() => _FocusTimerModalState();
}

class _FocusTimerModalState extends ConsumerState<FocusTimerModal> {
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _showBreakSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mola Süresi Seç',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Zihnini tazelemek için mola ver. Mola süresi çalışma bütçenden düşülmez.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [5, 10, 15, 30].map((mins) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      ref.read(activeSessionNotifierProvider.notifier).startBreak(mins);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$mins',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                          const Text(
                            'dakika',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeSessionNotifierProvider);
    final totalsMap = ref.watch(categoryTotalsMapProvider);
    final totals = totalsMap[widget.category.id];

    final isRunning = active.state == SessionState.running;
    final isBreak = active.state == SessionState.onBreak;
    final isPaused = active.state == SessionState.paused;

    final displaySeconds = isBreak
        ? active.currentBreakRemainingSeconds
        : active.currentWorkSeconds;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 30),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Text(
              widget.category.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.category.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.category.policy.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: widget.category.color,
                    ),
                  ),
                ),
                if (totals != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    'Kalan: ${FlutterTimeEngine.formatMinutes(totals.remainingMinutes)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: totals.isOverBudget ? const Color(0xFFF43F5E) : Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              if (active.isActive) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Oturumu İptal Et?'),
                    content: const Text('Bu oturum kaydedilmeden sonlandırılacaktır.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Geri'),
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(activeSessionNotifierProvider.notifier).cancelSession();
                          Navigator.pop(ctx);
                          Navigator.pop(context);
                        },
                        child: const Text('İptal Et', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Giant Stopwatch Display inside Radial Aura
              Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isBreak
                      ? const Color(0xFFF59E0B).withOpacity(0.06)
                      : widget.category.color.withOpacity(0.06),
                  border: Border.all(
                    color: isBreak
                        ? const Color(0xFFF59E0B).withOpacity(0.4)
                        : widget.category.color.withOpacity(0.4),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isBreak ? const Color(0xFFF59E0B) : widget.category.color)
                          .withOpacity(0.12),
                      blurRadius: 36,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isBreak ? Icons.coffee : IconMapper.getIcon(widget.category.icon),
                        size: 32,
                        color: isBreak ? const Color(0xFFF59E0B) : widget.category.color,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        FlutterTimeEngine.formatStopwatch(displaySeconds, forceHours: true),
                        style: TempoTheme.stopwatchStyle.copyWith(
                          fontSize: 40,
                          color: isBreak
                              ? const Color(0xFFF59E0B)
                              : Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isBreak
                            ? 'MOLA GERİ SAYIMI'
                            : (isRunning ? 'ODAK ZAMANI' : (isPaused ? 'DURAKLATILDI' : 'HAZIR')),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: isBreak
                              ? const Color(0xFFF59E0B)
                              : (isRunning ? const Color(0xFF10B981) : Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Quick Adjust Minute Pills
              if (active.isActive && !isBreak)
                Wrap(
                  spacing: 12,
                  children: [
                    ActionChip(
                      label: const Text('-5 dk', style: TextStyle(fontSize: 12)),
                      onPressed: () => ref.read(activeSessionNotifierProvider.notifier).adjustMinutes(-5),
                    ),
                    ActionChip(
                      label: const Text('+5 dk', style: TextStyle(fontSize: 12)),
                      onPressed: () => ref.read(activeSessionNotifierProvider.notifier).adjustMinutes(5),
                    ),
                    ActionChip(
                      label: const Text('+15 dk', style: TextStyle(fontSize: 12)),
                      onPressed: () => ref.read(activeSessionNotifierProvider.notifier).adjustMinutes(15),
                    ),
                  ],
                ),

              const SizedBox(height: 24),

              // Main Control Action Buttons
              if (!active.isActive) ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.category.color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: () async {
                      final res = await ref.read(activeSessionNotifierProvider.notifier).startSession(
                        categoryId: widget.category.id,
                      );
                      if (!res.isAllowed && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFFF43F5E),
                            content: Text(res.blockReason ?? 'Oturum başlatılamadı!'),
                          ),
                        );
                      }
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow, size: 24),
                        SizedBox(width: 8),
                        Text('Odak Oturumunu Başlat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    // Pause or Resume
                    Expanded(
                      child: SizedBox(
                        height: 54,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: widget.category.color.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          onPressed: () {
                            final notifier = ref.read(activeSessionNotifierProvider.notifier);
                            if (isRunning) {
                              notifier.pauseSession();
                            } else {
                              notifier.resumeSession();
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(isRunning ? Icons.pause : Icons.play_arrow),
                              const SizedBox(width: 6),
                              Text(isRunning ? 'Duraklat' : 'Devam Et'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Break or Resume Work
                    Expanded(
                      child: SizedBox(
                        height: 54,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFF59E0B)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          onPressed: () {
                            final notifier = ref.read(activeSessionNotifierProvider.notifier);
                            if (isBreak) {
                              notifier.resumeSession();
                            } else {
                              _showBreakSelector(context);
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(isBreak ? Icons.play_arrow : Icons.coffee, color: const Color(0xFFF59E0B)),
                              const SizedBox(width: 6),
                              Text(isBreak ? 'Molayı Bitir' : 'Mola Ver', style: const TextStyle(color: Color(0xFFF59E0B))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Finish Session Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: () async {
                      final sess = await ref.read(activeSessionNotifierProvider.notifier).finishSession();
                      if (context.mounted && sess != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Oturum kaydedildi: ${FlutterTimeEngine.formatMinutes((sess.activeSeconds / 60).round())}',
                            ),
                          ),
                        );
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 22),
                        SizedBox(width: 8),
                        Text('Oturumu Tamamla & Kaydet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
