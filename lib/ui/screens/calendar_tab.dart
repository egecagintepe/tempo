import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models.dart';
import '../../providers/tempo_providers.dart';
import '../widgets/active_session_bar.dart';

class CalendarTab extends ConsumerStatefulWidget {
  const CalendarTab({super.key});

  @override
  ConsumerState<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends ConsumerState<CalendarTab> with SingleTickerProviderStateMixin {
  late TabController _viewTabController;
  DateTime _selectedDate = DateTime(2026, 10, 15); // Default to current semester date: 15 Oct 2026

  @override
  void initState() {
    super.initState();
    _viewTabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _viewTabController.dispose();
    super.dispose();
  }

  void _showAddEventDialog(BuildContext context) {
    final categories = ref.read(categoriesNotifierProvider);
    final titleController = TextEditingController();
    final startController = TextEditingController(text: '14:00');
    final endController = TextEditingController(text: '15:30');
    int selectedDay = _selectedDate.weekday;
    String selectedType = 'study_block';
    String? selectedCatId = categories.isNotEmpty ? categories.first.id : null;
    bool isTentative = false;
    bool isRest = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Yeni Takvim Etkinliği', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Etkinlik Başlığı',
                        hintText: 'Örn: RF S-Parametreleri Ek Dersi',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: selectedDay,
                      decoration: InputDecoration(
                        labelText: 'Gün',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Pazartesi')),
                        DropdownMenuItem(value: 2, child: Text('Salı')),
                        DropdownMenuItem(value: 3, child: Text('Çarşamba')),
                        DropdownMenuItem(value: 4, child: Text('Perşembe')),
                        DropdownMenuItem(value: 5, child: Text('Cuma')),
                        DropdownMenuItem(value: 6, child: Text('Cumartesi')),
                        DropdownMenuItem(value: 7, child: Text('Pazar')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDlgState(() => selectedDay = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: startController,
                            decoration: InputDecoration(
                              labelText: 'Başlangıç',
                              hintText: '14:00',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: endController,
                            decoration: InputDecoration(
                              labelText: 'Bitiş',
                              hintText: '15:30',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: InputDecoration(
                        labelText: 'Etkinlik Türü',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'study_block', child: Text('Bağımsız Çalışma 📖')),
                        DropdownMenuItem(value: 'class', child: Text('Üniversite Dersi 🎓')),
                        DropdownMenuItem(value: 'internship', child: Text('Staj & Çalışma 💼')),
                        DropdownMenuItem(value: 'fitness', child: Text('Spor / Antrenman 🏋️')),
                        DropdownMenuItem(value: 'leisure', child: Text('Korunan Serbest Zaman 🎮')),
                        DropdownMenuItem(value: 'anime_publish', child: Text('Yayın & Medya İşi 🎬')),
                        DropdownMenuItem(value: 'writing', child: Text('Kitap Yazarlığı ✍️')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDlgState(() {
                            selectedType = val;
                            if (val == 'leisure') isRest = true;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: isTentative,
                      title: const Text('Olası / Kesinleşmemiş (Tentative)', style: TextStyle(fontSize: 13)),
                      subtitle: const Text('Tarih veya saat henüz doğrulanmadıysa işaretle', style: TextStyle(fontSize: 11, color: Colors.white38)),
                      onChanged: (val) => setDlgState(() => isTentative = val ?? false),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isNotEmpty) {
                      final event = CalendarEventModel(
                        id: const Uuid().v4(),
                        title: title,
                        dayOfWeek: selectedDay,
                        startTime: startController.text.trim(),
                        endTime: endController.text.trim(),
                        type: selectedType,
                        categoryId: selectedCatId,
                        isTentative: isTentative,
                        isRest: isRest,
                      );
                      ref.read(calendarEventsNotifierProvider.notifier).addEvent(event);
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Kaydet'),
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
    return Scaffold(
      body: Column(
        children: [
          const ActiveSessionBar(),

          // Header Controls
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 20, color: Color(0xFF06B6D4)),
                const SizedBox(width: 8),
                const Text(
                  'Takvim 2.0',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, fontFamily: 'monospace'),
                ),
                const Spacer(),
                IconButton.filled(
                  icon: const Icon(Icons.add, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  tooltip: 'Etkinlik Ekle',
                  onPressed: () => _showAddEventDialog(context),
                ),
              ],
            ),
          ),

          // 4 Views Bar
          TabBar(
            controller: _viewTabController,
            indicatorColor: const Color(0xFF06B6D4),
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
            tabs: const [
              Tab(text: 'Gün'),
              Tab(text: 'Hafta'),
              Tab(text: 'Ay'),
              Tab(text: 'Dönem Planı'),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _viewTabController,
              children: [
                _buildDayView(),
                _buildWeekView(),
                _buildMonthView(),
                _buildSemesterRoadmapView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 1. DAY VIEW ---
  Widget _buildDayView() {
    final allEvents = ref.watch(calendarEventsNotifierProvider);
    final categories = ref.watch(categoriesNotifierProvider);

    final dayEvents = allEvents.where((e) => e.dayOfWeek == _selectedDate.weekday).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final dayNames = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    final currentDayName = dayNames[_selectedDate.weekday - 1];

    // Conflict detection
    final conflicts = <String>[];
    for (int i = 0; i < dayEvents.length; i++) {
      for (int j = i + 1; j < dayEvents.length; j++) {
        final e1 = dayEvents[i];
        final e2 = dayEvents[j];
        if (e1.startTime.compareTo(e2.endTime) < 0 && e2.startTime.compareTo(e1.endTime) < 0) {
          conflicts.add('${e1.title} ↔ ${e2.title}');
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        // Day Selector Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
                },
              ),
              Column(
                children: [
                  Text(
                    currentDayName.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.2),
                  ),
                  Text(
                    '${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}',
                    style: const TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Conflict alert banner
        if (conflicts.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule, size: 20, color: Color(0xFFEF4444)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Zaman Çakışması: ${conflicts.join(", ")}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

        if (dayEvents.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'Bu gün için planlanan takvim etkinliği yok.\nTamamen serbest veya esnek çalışma.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, height: 1.5),
              ),
            ),
          )
        else
          ...dayEvents.map((evt) {
            Color itemColor = const Color(0xFF2563EB);
            if (evt.isRest || evt.type == 'leisure') {
              itemColor = const Color(0xFF10B981); // Green for rest/leisure
            } else if (evt.type == 'fitness') {
              itemColor = const Color(0xFFF97316); // Orange for fitness
            } else if (evt.type == 'internship') {
              itemColor = const Color(0xFF8B5CF6); // Purple for internship
            } else if (evt.categoryId != null) {
              final found = categories.where((c) => c.id == evt.categoryId);
              if (found.isNotEmpty) itemColor = found.first.color;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: itemColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: evt.isTentative ? itemColor.withOpacity(0.3) : itemColor.withOpacity(0.6),
                  style: evt.isTentative ? BorderStyle.solid : BorderStyle.solid,
                  width: evt.isTentative ? 1.0 : 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 44,
                    decoration: BoxDecoration(
                      color: itemColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${evt.startTime} – ${evt.endTime}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: itemColor),
                            ),
                            if (evt.isTentative) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Olası / Doğrulanacak',
                                  style: TextStyle(fontSize: 9, color: Colors.white70),
                                ),
                              ),
                            ],
                            if (evt.isRest) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Korunan Serbest Zaman 🌱',
                                  style: TextStyle(fontSize: 9, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          evt.title,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        if (evt.location != null)
                          Text(
                            evt.location!,
                            style: const TextStyle(fontSize: 11, color: Colors.white54),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      evt.isCompleted ? Icons.check_circle : Icons.check_circle_outline,
                      color: evt.isCompleted ? const Color(0xFF10B981) : Colors.white24,
                    ),
                    onPressed: () {
                      ref.read(calendarEventsNotifierProvider.notifier).toggleEventCompleted(evt.id);
                    },
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // --- 2. WEEK VIEW ---
  Widget _buildWeekView() {
    final allEvents = ref.watch(calendarEventsNotifierProvider);
    final dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: 7,
      itemBuilder: (context, idx) {
        final dayNumber = idx + 1;
        final events = allEvents.where((e) => e.dayOfWeek == dayNumber).toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

        final isToday = DateTime.now().weekday == dayNumber;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: isToday ? const Color(0xFF06B6D4) : Colors.white12, width: isToday ? 1.5 : 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dayNames[idx],
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: isToday ? const Color(0xFF06B6D4) : null,
                      ),
                    ),
                    Text(
                      '${events.length} blok',
                      style: const TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (events.isEmpty)
                  const Text('Planlanan blok yok (Esnek)', style: TextStyle(fontSize: 12, color: Colors.white38))
                else
                  ...events.map((e) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Text(
                            '${e.startTime}–${e.endTime}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white60),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.title,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: e.isRest ? const Color(0xFF10B981) : null,
                              ),
                            ),
                          ),
                          if (e.isRest)
                            const Text('🌱', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- 3. MONTH VIEW ---
  Widget _buildMonthView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        // Semester Exam Periods Callout Cards
        _buildMonthPeriodCard(
          title: 'VİZE DÖNEMİ (MIDTERMS)',
          dates: '7 – 15 Kasım 2026',
          status: 'Sınav Modu / Yüksek Öncelik',
          color: const Color(0xFFEF4444),
          icon: Icons.assignment_outlined,
          description: 'RF (90+), Elektronik II (90+), C (90+), Cyber (90+). İkincil işler askıya alınır, uyku korunur.',
        ),
        const SizedBox(height: 12),
        _buildMonthPeriodCard(
          title: 'NORMAL DÖNEM & C PROJE MARATONU',
          dates: '16 Kasım – 31 Aralık 2026',
          status: 'Dengeli Bütçe + 4 Modüllü C Projesi',
          color: const Color(0xFF2563EB),
          icon: Icons.code,
          description: 'C 4 Modüllü Proje (Modül 1..4), IELTS 240 dk/hafta başlangıcı, Ajans teslimleri.',
        ),
        const SizedBox(height: 12),
        _buildMonthPeriodCard(
          title: 'FİNAL DÖNEMİ (FINALS)',
          dates: '7 – 19 Ocak 2027',
          status: 'Yoğun Akademik Mod (28 Saat/Hafta)',
          color: const Color(0xFFF59E0B),
          icon: Icons.school_outlined,
          description: 'Dönem sonu klasik sorular, deneme sınavları, C final proje sunumu.',
        ),
      ],
    );
  }

  Widget _buildMonthPeriodCard({
    required String title,
    required String dates,
    required String status,
    required Color color,
    required IconData icon,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: color, letterSpacing: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(dates, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 2),
          Text(status, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4)),
        ],
      ),
    );
  }

  // --- 4. SEMESTER ROADMAP VIEW (15 Oct 2026 - 19 Jan 2027) ---
  Widget _buildSemesterRoadmapView() {
    final roadmapWeeks = [
      {'week': 'Week 4 (12–18 Eki)', 'mode': 'Academic Recovery', 'focus': 'RF Noise giriş, Elektronik Op-amp, C Fonksiyonlar, Cyber Ağ Güv.'},
      {'week': 'Week 5 (19–25 Eki)', 'mode': 'Problem Solving', 'focus': 'Noise Figure/Factor, Current Mirrors, Arrays/Strings, Kill Chain'},
      {'week': 'Week 6 (26 Eki–1 Kas)', 'mode': 'Midterm Prep', 'focus': 'S-Parametreleri, Diff Amp, Struct/File I/O, System Hacking'},
      {'week': 'Week 7 (2–8 Kas)', 'mode': 'Exam Readiness', 'focus': 'Karışık Klasik Sorular, Çoklu Dosya C, Malware, Vize Provası'},
      {'week': '7–15 Kasım 2026', 'mode': 'EXAM MODE: VİZELER', 'focus': 'Tüm 4 Derste 90+ Hedefi. En yakın sınava son 48s odak.'},
      {'week': 'Week 8 (16–22 Kas)', 'mode': 'Post-Midterm Reset', 'focus': 'LNA Başlangıç, Diff Amp, C Proje Takımı & R1-R8 Gereksinimler'},
      {'week': 'Week 9 (23–29 Kas)', 'mode': 'Project Module 1', 'focus': 'LNA Devreleri, Frequency Response, C Modül 1 (Input/Data)'},
      {'week': 'Week 10 (30 Kas–6 Ara)', 'mode': 'Project Module 2', 'focus': 'LNA İnceleme, Frequency Response, C Modül 2 (Analysis)'},
      {'week': 'Week 11 (7–13 Ara)', 'mode': 'Project Module 3', 'focus': 'Mixers Frekans Dönüşümü, C Modül 3 (Decision & Control)'},
      {'week': 'Week 12 (14–20 Ara)', 'mode': 'Project Module 4', 'focus': 'Mixers, Feedback & Stability, C Modül 4 (Output/UI)'},
      {'week': 'Week 13 (21–27 Ara)', 'mode': 'Integration & Freeze', 'focus': 'Oscillators, C Tam Entegrasyon, Testler, Code Freeze'},
      {'week': 'Week 14 (28–31 Ara)', 'mode': 'Demo & Submission', 'focus': 'C Proje Sunumu & Demo, Derslerin Tamamlanması'},
      {'week': '1–6 Ocak 2027', 'mode': 'Final Preparation', 'focus': 'Tüm 4 Ders Klasik Soru Çözümleri, Hata Notları'},
      {'week': '7–19 Ocak 2027', 'mode': 'EXAM MODE: FİNALLER', 'focus': 'Dönem Sonu Sınav Maratonu, Hedef 3.50+ Dönem GPA'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: roadmapWeeks.length,
      itemBuilder: (context, idx) {
        final item = roadmapWeeks[idx];
        final isExam = item['mode']!.contains('EXAM');

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isExam ? const Color(0xFFEF4444).withOpacity(0.1) : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isExam ? const Color(0xFFEF4444).withOpacity(0.5) : Colors.white12,
              width: isExam ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item['week']!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isExam ? const Color(0xFFEF4444) : const Color(0xFF06B6D4),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item['mode']!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isExam ? const Color(0xFFEF4444) : Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item['focus']!,
                style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.3),
              ),
            ],
          ),
        );
      },
    );
  }
}
