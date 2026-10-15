import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/tempo_providers.dart';

class SettingsModal extends ConsumerWidget {
  const SettingsModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);
    final notifier = ref.read(settingsNotifierProvider.notifier);
    final db = ref.watch(databaseProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Ayarlar & Yapılandırma', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Section: Appearance
          const Text('Görünüm & Tema', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                RadioListTile<String>(
                  title: const Text('Koyu Tema (Obsidian Dark)', style: TextStyle(fontSize: 13)),
                  value: 'dark',
                  groupValue: settings.theme,
                  onChanged: (val) {
                    if (val != null) notifier.setTheme(val);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Açık Tema (Architectural Neutral)', style: TextStyle(fontSize: 13)),
                  value: 'light',
                  groupValue: settings.theme,
                  onChanged: (val) {
                    if (val != null) notifier.setTheme(val);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('OLED Saf Siyah (True Black)', style: TextStyle(fontSize: 13)),
                  value: 'oled',
                  groupValue: settings.theme,
                  onChanged: (val) {
                    if (val != null) notifier.setTheme(val);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Sistem Temasını Takip Et', style: TextStyle(fontSize: 13)),
                  value: 'system',
                  groupValue: settings.theme,
                  onChanged: (val) {
                    if (val != null) notifier.setTheme(val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Section: Sound & Haptics
          const Text('Ses & Dokunsal Geri Bildirim', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Bildirimler', style: TextStyle(fontSize: 13)),
                  subtitle: const Text('Bütçe uyarıları ve mola bildirimleri', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  value: settings.notificationsEnabled,
                  onChanged: (val) => notifier.toggleNotifications(val),
                ),
                SwitchListTile(
                  title: const Text('Titreşim / Haptik', style: TextStyle(fontSize: 13)),
                  value: settings.vibrationEnabled,
                  onChanged: (val) => notifier.toggleVibration(val),
                ),
                SwitchListTile(
                  title: const Text('Ses Efektleri', style: TextStyle(fontSize: 13)),
                  value: settings.soundEnabled,
                  onChanged: (val) => notifier.toggleSound(val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Section: Backup & Restore
          const Text('Veri Yedekleme & Dışa Aktarma', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.download, color: Color(0xFF2563EB)),
                  title: const Text('JSON Tam Yedek Al', style: TextStyle(fontSize: 13)),
                  subtitle: const Text('Tüm bütçe, oturum ve defter geçmişini dışa aktar', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    try {
                      final jsonStr = await db.exportBackupJson();
                      final dir = await getTemporaryDirectory();
                      final file = File('${dir.path}/tempo_backup_${DateTime.now().millisecondsSinceEpoch}.json');
                      await file.writeAsString(jsonStr);
                      await Share.shareXFiles([XFile(file.path)], text: 'TEMPO Veri Yedeği');
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Yedekleme hatası: $e')),
                        );
                      }
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.upload, color: Color(0xFF06B6D4)),
                  title: const Text('JSON Yedekten Geri Yükle', style: TextStyle(fontSize: 13)),
                  subtitle: const Text('Daha önce kaydedilmiş JSON yedeğini yükle', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    try {
                      final result = await FilePicker.platform.pickFiles(type: FileType.any);
                      if (result != null && result.files.single.path != null) {
                        final file = File(result.files.single.path!);
                        final content = await file.readAsString();
                        await db.restoreBackupJson(content);
                        await ref.read(categoriesNotifierProvider.notifier).loadCategories();
                        await ref.read(tasksNotifierProvider.notifier).loadTasks();
                        await ref.read(sessionsNotifierProvider.notifier).loadSessions();
                        await ref.read(transactionsNotifierProvider.notifier).loadTransactions();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Yedek başarıyla geri yüklendi!')),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Geri yükleme başarısız: $e')),
                        );
                      }
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.table_chart, color: Color(0xFF10B981)),
                  title: const Text('CSV Oturum Geçmişi İndir', style: TextStyle(fontSize: 13)),
                  subtitle: const Text('Excel veya analitik araçları için oturum dökümü', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    try {
                      final csvStr = await db.exportSessionsCsv();
                      final dir = await getTemporaryDirectory();
                      final file = File('${dir.path}/tempo_sessions_${DateTime.now().millisecondsSinceEpoch}.csv');
                      await file.writeAsString(csvStr);
                      await Share.shareXFiles([XFile(file.path)], text: 'TEMPO Oturum Geçmişi CSV');
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('CSV aktarma hatası: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Section: Reset to Seed
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: ListTile(
              leading: const Icon(Icons.restart_alt, color: Color(0xFFF43F5E)),
              title: const Text('Başlangıç Verilerine Sıfırla', style: TextStyle(fontSize: 13, color: Color(0xFFF43F5E), fontWeight: FontWeight.bold)),
              subtitle: const Text('Tüm verileri silip profil başlangıç seed\'ine döndürür', style: TextStyle(fontSize: 11, color: Colors.grey)),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sıfırlamayı Onayla'),
                    content: const Text('Tüm kayıtlar silinip başlangıç profil verilerine dönülecektir. Bu işlem geri alınamaz!'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await db.resetToSeedData();
                          await ref.read(categoriesNotifierProvider.notifier).loadCategories();
                          await ref.read(tasksNotifierProvider.notifier).loadTasks();
                          await ref.read(sessionsNotifierProvider.notifier).loadSessions();
                          await ref.read(transactionsNotifierProvider.notifier).loadTransactions();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Veriler başlangıç seed\'ine sıfırlandı.')),
                            );
                          }
                        },
                        child: const Text('Evet, Sıfırla', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),
          const Center(
            child: Column(
              children: [
                Text('TEMPO — Personal Time Budget OS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                SizedBox(height: 2),
                Text('Sürüm 1.0.0 • 100% Yerel & Çevrimdışı SQLite', style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
