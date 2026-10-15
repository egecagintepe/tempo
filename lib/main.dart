import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/tempo_theme.dart';
import 'domain/models.dart';
import 'domain/time_engine.dart';
import 'providers/tempo_providers.dart';
import 'services/notification_service.dart';
import 'ui/screens/calendar_tab.dart';
import 'ui/screens/focus_timer_modal.dart';
import 'ui/screens/onboarding_modal.dart';
import 'ui/screens/pool_tab.dart';
import 'ui/screens/progress_tab.dart';
import 'ui/screens/settings_modal.dart';
import 'ui/screens/tasks_tab.dart';
import 'ui/screens/today_tab.dart';
import 'ui/widgets/tempo_logo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  await NotificationService.instance.requestPermissions();

  runApp(const ProviderScope(child: TempoApp()));
}

class TempoApp extends ConsumerWidget {
  const TempoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);

    ThemeMode activeMode;

    switch (settings.theme) {
      case 'light':
        activeMode = ThemeMode.light;
        break;
      case 'oled':
        activeMode = ThemeMode.dark;
        break;
      case 'system':
        activeMode = ThemeMode.system;
        break;
      case 'dark':
      default:
        activeMode = ThemeMode.dark;
        break;
    }

    return MaterialApp(
      title: 'TEMPO — Personal Life Operating System',
      debugShowCheckedModeBanner: false,
      theme: TempoTheme.lightTheme,
      darkTheme: settings.theme == 'oled' ? TempoTheme.oledTheme : TempoTheme.darkTheme,
      themeMode: activeMode,
      home: const TempoHomeScreen(),
    );
  }
}

class TempoHomeScreen extends ConsumerStatefulWidget {
  const TempoHomeScreen({super.key});

  @override
  ConsumerState<TempoHomeScreen> createState() => _TempoHomeScreenState();
}

class _TempoHomeScreenState extends ConsumerState<TempoHomeScreen> {
  int _currentIndex = 0;
  bool _checkedOnboarding = false;

  final List<Widget> _tabs = const [
    TodayTab(),
    TasksTab(),
    CalendarTab(),
    PoolTab(),
    ProgressTab(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstTime();
    });
  }

  void _checkFirstTime() async {
    if (_checkedOnboarding) return;
    _checkedOnboarding = true;

    final db = ref.read(databaseProvider);
    final settings = await db.getSettings();

    // Show onboarding on first install
    if (settings.seedVersion == 0 && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => OnboardingModal(
          onComplete: () => Navigator.pop(ctx),
        ),
      );
    }
  }

  void _openFocusTimer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FocusTimerModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pool = ref.watch(poolBalanceProvider);
    final termMode = ref.watch(termModeNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: TempoLogo(
          size: 26,
          isDark: isDark,
        ),
        actions: [
          // Active Term Mode Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.school, size: 12, color: Color(0xFF2563EB)),
                const SizedBox(width: 4),
                Text(
                  termMode.type == TermModeType.modeAMidtermPrep
                      ? 'Vize Hazırlık'
                      : termMode.type == TermModeType.modeBMidtermWeek
                          ? 'Sınav Modu'
                          : termMode.type == TermModeType.modeCNormalTerm
                              ? 'Normal & Proje'
                              : 'Final Modu',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Quick Free Time Pool Badge in AppBar
          GestureDetector(
            onTap: () {
              setState(() => _currentIndex = 3); // Switch to Pool Tab
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.water_drop, size: 12, color: Color(0xFF06B6D4)),
                  const SizedBox(width: 4),
                  Text(
                    FlutterTimeEngine.formatMinutes(pool.balanceMinutes),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),

          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: 'Ayarlar',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsModal()),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openFocusTimer,
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        tooltip: 'Odak Sayacı',
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.play_arrow, size: 28),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Bugün',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined),
            selectedIcon: Icon(Icons.task_alt),
            label: 'Görevler',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Takvim',
          ),
          NavigationDestination(
            icon: Icon(Icons.water_drop_outlined),
            selectedIcon: Icon(Icons.water_drop),
            label: 'Havuz',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_graph_outlined),
            selectedIcon: Icon(Icons.auto_graph),
            label: 'İlerleme',
          ),
        ],
      ),
    );
  }
}
