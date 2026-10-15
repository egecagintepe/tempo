import 'package:flutter/material.dart';

class OnboardingModal extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingModal({super.key, required this.onComplete});

  @override
  State<OnboardingModal> createState() => _OnboardingModalState();
}

class _OnboardingModalState extends State<OnboardingModal> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final slides = const [
    {
      'badge': 'FELSEFE',
      'title': 'Own your hours.',
      'subtitle': 'Kişisel Zaman Bütçesi',
      'desc': 'Her şeyi bitirmek zorunda değilsin. Hayatındaki etkinliklere ayıracağın zamanı bilinçli olarak seçmelisin.',
      'icon': Icons.local_fire_department,
      'color': Color(0xFF2563EB),
    },
    {
      'badge': 'MİMARİ',
      'title': 'Zaman Bütçelerini Koru',
      'subtitle': 'Katı, Esnek ve Korunan Zaman',
      'desc': 'Bir kategoriye ayrılan süre başka bir kategori tarafından rastgele çalınamaz. Katı bir bütçen bittiğinde sistem oturumu durdurarak zaman sınırlarını korur.',
      'icon': Icons.shield_outlined,
      'color': Color(0xFF8B5CF6),
    },
    {
      'badge': 'SERBEST REZERV',
      'title': 'Serbest Zaman Havuzu',
      'subtitle': 'Zamanını Yeniden Dağıt',
      'desc': '120 dakikalık işini 80 dakikada bitirdiğinde kalan 40 dakikayı serbest havuza aktarabilir ve dilediğin projeye veya dinlenmeye dağıtabilirsin.',
      'icon': Icons.water_drop_outlined,
      'color': Color(0xFF06B6D4),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 520),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: slides.length,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemBuilder: (ctx, idx) {
                  final s = slides[idx];
                  final col = s['color'] as Color;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: col.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          s['badge'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: col,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: col.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(s['icon'] as IconData, size: 40, color: col),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        s['title'] as String,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s['subtitle'] as String,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: col),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        s['desc'] as String,
                        style: const TextStyle(fontSize: 12, height: 1.5, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(slides.length, (i) {
                return Container(
                  width: _currentPage == i ? 20 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? (slides[_currentPage]['color'] as Color)
                        : Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: slides[_currentPage]['color'] as Color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  if (_currentPage < slides.length - 1) {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    widget.onComplete();
                  }
                },
                child: Text(
                  _currentPage < slides.length - 1 ? 'Devam Et' : 'Başlayalım',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
