import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models.dart';
import '../../domain/time_engine.dart';
import '../../providers/tempo_providers.dart';
import '../widgets/active_session_bar.dart';

class ProgressTab extends ConsumerStatefulWidget {
  const ProgressTab({super.key});

  @override
  ConsumerState<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends ConsumerState<ProgressTab> with SingleTickerProviderStateMixin {
  late TabController _progressTabController;
  String _selectedCourseId = 'course-rf';

  @override
  void initState() {
    super.initState();
    _progressTabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _progressTabController.dispose();
    super.dispose();
  }

  void _showGradePlannerDialog(BuildContext context, CourseModel course) {
    final midtermCtrl = TextEditingController(text: course.actualMidterm?.toStringAsFixed(0) ?? '');
    final finalCtrl = TextEditingController(text: course.actualFinal?.toStringAsFixed(0) ?? '');
    final projectCtrl = TextEditingController(text: course.projectScore?.toStringAsFixed(0) ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('${course.code} Not Planlayıcı', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ders: ${course.name}', style: const TextStyle(fontSize: 13, color: Colors.white70)),
            const SizedBox(height: 12),
            TextField(
              controller: midtermCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Gerçek Vize Notu (Hedef: 90+)',
                hintText: 'Açıklanınca giriniz',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: finalCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Gerçek Final Notu (Hedef: 90+)',
                hintText: 'Açıklanınca giriniz',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            if (course.assessmentWeights.containsKey('project')) ...[
              const SizedBox(height: 12),
              TextField(
                controller: projectCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Dönem Projesi Notu (%40)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calculate_outlined, color: Color(0xFF2563EB), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ağırlıklar: ${course.assessmentWeights.entries.map((e) => '${e.key.toUpperCase()} %${(e.value * 100).toInt()}').join(' + ')}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat')),
          ElevatedButton(
            onPressed: () {
              final mScore = double.tryParse(midtermCtrl.text.trim());
              final fScore = double.tryParse(finalCtrl.text.trim());
              if (mScore != null) {
                ref.read(coursesNotifierProvider.notifier).updateMidtermScore(course.id, mScore);
              }
              if (fScore != null) {
                ref.read(coursesNotifierProvider.notifier).updateFinalScore(course.id, fScore);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _showTermModeModal(BuildContext context) {
    final currentMode = ref.read(termModeNotifierProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text(
                'Dönem Çalışma Modu Seçimi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 6),
              const Text(
                'Her akademik dönem aynı haftalık bütçeyi kullanmaz. Mod değiştiğinde haftalık kategori hedefleri otomatik güncellenir.',
                style: TextStyle(fontSize: 12, color: Colors.white60),
              ),
              const SizedBox(height: 16),
              ...TermModeModel.predefinedModes.map((mode) {
                final isSelected = mode.type == currentMode.type;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF2563EB).withOpacity(0.15) : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF2563EB) : Colors.white12,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(mode.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('${mode.targetWeeklyHours} saat/hf', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF06B6D4))),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(mode.dateRange, style: const TextStyle(fontSize: 11, color: Colors.white54)),
                        const SizedBox(height: 4),
                        Text(mode.description, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                      ],
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Color(0xFF2563EB))
                        : const Icon(Icons.circle_outlined, color: Colors.white24),
                    onTap: () async {
                      await ref.read(termModeNotifierProvider.notifier).selectTermMode(mode);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${mode.title} aktif edildi. Bütçeler güncellendi.')),
                        );
                      }
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTermMode = ref.watch(termModeNotifierProvider);

    return Scaffold(
      body: Column(
        children: [
          const ActiveSessionBar(),

          // Term Mode Header Banner
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _showTermModeModal(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.35)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.tune, size: 18, color: Color(0xFF2563EB)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Aktif Mod: ${currentTermMode.title}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                ),
                                Text(
                                  '${currentTermMode.targetWeeklyHours}s/hafta • ${currentTermMode.dateRange}',
                                  style: const TextStyle(fontSize: 10, color: Colors.white60),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Color(0xFF2563EB)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4 Sub Tabs
          TabBar(
            controller: _progressTabController,
            indicatorColor: const Color(0xFF2563EB),
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
            tabs: const [
              Tab(text: 'Dersler (90+)'),
              Tab(text: 'Syllabus Haritası'),
              Tab(text: 'C Projesi'),
              Tab(text: 'Boş Zaman'),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _progressTabController,
              children: [
                _buildCoursesView(),
                _buildSyllabusView(),
                _buildCProjectView(),
                _buildLeisureView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 1. COURSES & GRADE PLANNER VIEW ---
  Widget _buildCoursesView() {
    final courses = ref.watch(coursesNotifierProvider);
    final totalsMap = ref.watch(categoryTotalsMapProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        // Semester Target Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF2563EB).withOpacity(0.18), const Color(0xFF06B6D4).withOpacity(0.08)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('HEDEF DÖNEM BAŞARISI', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.0, color: Color(0xFF06B6D4))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                    child: const Text('GPA 3.50+', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF10B981))),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Tüm 4 derste Vize ve Final için 90+ puan hedefi.', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Kredi ve harf notları gerçek sınav sonuçları ve üniversite sistemi girildiğinde hesaplanır.', style: TextStyle(fontSize: 11, color: Colors.white60)),
            ],
          ),
        ),
        const SizedBox(height: 14),

        ...courses.map((c) {
          final estGrade = c.calculateEstimatedGrade();
          String catId = 'cat-rf';
          if (c.id.contains('elek')) catId = 'cat-elek2';
          if (c.id.contains('c')) catId = 'cat-c';
          if (c.id.contains('siber')) catId = 'cat-siber';
          final spent = totalsMap[catId]?.spentMinutes ?? 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Colors.white12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.code, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF2563EB))),
                          Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('Zorluk: ${c.difficulty}/10', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Weights & Estimated Score
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tahmini Başarı', style: TextStyle(fontSize: 10, color: Colors.white38)),
                            Text(
                              estGrade != null ? '${estGrade.toStringAsFixed(1)} / 100' : '90+ (Hedef)',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Bu Hafta Çalışma', style: TextStyle(fontSize: 10, color: Colors.white38)),
                            Text(FlutterTimeEngine.formatMinutes(spent), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        icon: const Icon(Icons.edit, size: 14),
                        label: const Text('Notlar', style: TextStyle(fontSize: 11)),
                        onPressed: () => _showGradePlannerDialog(context, c),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(c.instructorNotes, style: const TextStyle(fontSize: 11, color: Colors.white54, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // --- 2. SYLLABUS HARİTASI VIEW (Week 1 - 14) ---
  Widget _buildSyllabusView() {
    final allTopics = ref.watch(courseTopicsNotifierProvider);
    final courses = ref.watch(coursesNotifierProvider);

    final filteredTopics = allTopics.where((t) => t.courseId == _selectedCourseId).toList()
      ..sort((a, b) => a.weekNumber.compareTo(b.weekNumber));

    return Column(
      children: [
        // Course selector tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: courses.map((c) {
              final isSel = c.id == _selectedCourseId;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(c.code, style: TextStyle(fontWeight: isSel ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
                  selected: isSel,
                  selectedColor: const Color(0xFF2563EB).withOpacity(0.2),
                  onSelected: (val) {
                    if (val) setState(() => _selectedCourseId = c.id);
                  },
                ),
              );
            }).toList(),
          ),
        ),

        Expanded(
          child: filteredTopics.isEmpty
              ? const Center(
                  child: Text('Bu ders için henüz syllabus konusu eklenmemiş.', style: TextStyle(color: Colors.white54)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: filteredTopics.length,
                  itemBuilder: (context, idx) {
                    final topic = filteredTopics[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFF2563EB).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                  child: Text('Hafta ${topic.weekNumber}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                ),
                                _buildMasteryDropdown(topic),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(topic.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            if (topic.description != null && topic.description!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(topic.description!, style: const TextStyle(fontSize: 11, color: Colors.white60)),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  'Soru Provasi: ${topic.questionsCorrect}/${topic.questionsAttempted} doğru (${(topic.accuracyRate * 100).toInt()}%)',
                                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                                  icon: const Icon(Icons.add, size: 14),
                                  label: const Text('Deneme Ekle', style: TextStyle(fontSize: 11)),
                                  onPressed: () {
                                    ref.read(courseTopicsNotifierProvider.notifier).recordPracticeAttempt(topic.id, true);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMasteryDropdown(CourseTopicModel topic) {
    return DropdownButton<MasteryLevel>(
      value: topic.masteryLevel,
      isDense: true,
      underline: const SizedBox(),
      items: const [
        DropdownMenuItem(value: MasteryLevel.notStarted, child: Text('Başlamadım ⚪', style: TextStyle(fontSize: 11))),
        DropdownMenuItem(value: MasteryLevel.reviewed, child: Text('İnceledim 🟡', style: TextStyle(fontSize: 11))),
        DropdownMenuItem(value: MasteryLevel.withHelp, child: Text('Yardımla Çözüyorum 🟠', style: TextStyle(fontSize: 11))),
        DropdownMenuItem(value: MasteryLevel.independent, child: Text('Bağımsız Çözüyorum 🟢', style: TextStyle(fontSize: 11))),
        DropdownMenuItem(value: MasteryLevel.examReady, child: Text('Sınava Hazır 🏆', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
      ],
      onChanged: (val) {
        if (val != null) {
          ref.read(courseTopicsNotifierProvider.notifier).setMasteryLevel(topic.id, val);
        }
      },
    );
  }

  // --- 3. C PROJESİ ÖZEL EKRANI ---
  Widget _buildCProjectView() {
    final phases = [
      {'phase': 'Hafta 8 (16–22 Kas)', 'title': 'Kick-off & Takım Yapısı', 'desc': '4 kişilik ekip, R1–R8 gereksinimleri, mimari planı, Git repo kurulumu.'},
      {'phase': 'Hafta 9 (23–29 Kas)', 'title': 'Modül 1 — Input & Data Processing', 'desc': 'Veri okuma, formatlama, doğrulama ve ilk birim testleri.'},
      {'phase': 'Hafta 10 (30 Kas–6 Ara)', 'title': 'Modül 2 — Engineering Analysis', 'desc': 'Mühendislik hesaplama motoru, matematiksel analiz ve algoritma.'},
      {'phase': 'Hafta 11 (7–13 Ara)', 'title': 'Modül 3 — Decision & Control', 'desc': 'Karar destek kuralları, eşik kontrolleri ve durum makinesi.'},
      {'phase': 'Hafta 12 (14–20 Ara)', 'title': 'Modül 4 — Monitoring & Output', 'desc': 'Görselleştirme, raporlama, loglama ve dosya çıkışı.'},
      {'phase': 'Hafta 13 (21–27 Ara)', 'title': 'Entegrasyon & Code Freeze', 'desc': 'Tüm modüllerin entegrasyonu, uçtan uca testler, kod dondurma.'},
      {'phase': 'Hafta 14 (28–31 Ara)', 'title': 'Final Demo & Sunum', 'desc': 'Canlı gösterim, teknik mülakat soruları ve dokümantasyon teslimi.'},
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withOpacity(0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.3)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('C DİSİPLİNLERARASI PROJE (%40)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2563EB))),
              SizedBox(height: 4),
              Text('4 Öğrenci • 4 Modül • Her öğrenci bir modüle liderlik eder ancak tüm öğrenciler tüm modüllere katkı sağlar.', style: TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...phases.map((p) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            title: Text(p['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['phase']!, style: const TextStyle(fontSize: 11, color: Color(0xFF06B6D4), fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(p['desc']!, style: const TextStyle(fontSize: 11, color: Colors.white60)),
              ],
            ),
          ),
        )),
      ],
    );
  }

  // --- 4. LEISURE / BOŞ ZAMAN VIEW ---
  Widget _buildLeisureView() {
    final items = ref.watch(leisureNotifierProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.spa_outlined, color: Color(0xFF10B981), size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Rest is not unfinished work.\nDinlenme zorunlu görev değildir; suçluluk hissetmeden korunan serbest zamandır.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.bold, height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Text('Kayıtlı medya/eğlence listesi yok.', style: TextStyle(color: Colors.white54)),
            ),
          )
        else
          ...items.map((item) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: Icon(_getLeisureIcon(item.type), color: const Color(0xFF10B981)),
              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(
                '${item.type.toUpperCase()} • ${item.status == "completed" ? "Tamamlandı" : "Backlog"}',
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
              trailing: IconButton(
                icon: Icon(
                  item.status == 'completed' ? Icons.check_circle : Icons.circle_outlined,
                  color: item.status == 'completed' ? const Color(0xFF10B981) : Colors.white24,
                ),
                onPressed: () {
                  final next = item.status == 'completed' ? 'backlog' : 'completed';
                  ref.read(leisureNotifierProvider.notifier).updateStatus(item.id, next);
                },
              ),
            ),
          )),
      ],
    );
  }

  IconData _getLeisureIcon(String type) {
    switch (type) {
      case 'game':
        return Icons.sports_esports;
      case 'anime':
        return Icons.movie_filter;
      case 'movie':
        return Icons.local_movies;
      case 'book':
        return Icons.menu_book;
      default:
        return Icons.sports_esports;
    }
  }
}
