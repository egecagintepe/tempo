import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/tempo_theme.dart';
import 'domain/time_engine.dart';
import 'providers/tempo_providers.dart';
import 'services/notification_service.dart';
import 'ui/screens/analytics_tab.dart';
import 'ui/screens/budgets_tab.dart';
import 'ui/screens/calendar_modal.dart';
import 'ui/screens/onboarding_modal.dart';
import 'ui/screens/pool_tab.dart';
import 'ui/screens/settings_modal.dart';
import 'ui/screens/today_tab.dart';

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
      title: 'TEMPO — Personal Time Budget OS',
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
    BudgetsTab(),
    PoolTab(),
    AnalyticsTab(),
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

  @override
  Widget build(BuildContext context) {
    final pool = ref.watch(poolBalanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'TEMPO.',
              style: TextStyle(fontWeight: FontWeight.w900, fontFamily: 'monospace', fontSize: 18),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('OS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        actions: [
          // Quick Free Time Pool Badge in AppBar
          GestureDetector(
            onTap: () {
              setState(() => _currentIndex = 2); // Switch to Pool Tab
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.water_drop, size: 14, color: Color(0xFF06B6D4)),
                  const SizedBox(width: 4),
                  Text(
                    'Havuz: ${FlutterTimeEngine.formatMinutes(pool.balanceMinutes)}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined, size: 20),
            tooltip: 'Haftalık Rutin & Takvim',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CalendarModal()),
              );
            },
          ),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Bugün',
          ),
          NavigationDestination(
            icon: Icon(Icons.layers_outlined),
            selectedIcon: Icon(Icons.layers),
            label: 'Bütçeler',
          ),
          NavigationDestination(
            icon: Icon(Icons.water_drop_outlined),
            selectedIcon: Icon(Icons.water_drop),
            label: 'Havuz',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Analiz',
          ),
        ],
      ),
    );
  }
}
