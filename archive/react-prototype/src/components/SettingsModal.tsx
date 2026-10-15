import React, { useState } from 'react';
import { useTempo } from '../context/TempoContext.tsx';
import { storage } from '../services/storage.ts';
import { soundService } from '../services/sound.ts';
import { hapticsService } from '../services/haptics.ts';
import {
  X,
  Moon,
  Sun,
  Volume2,
  Vibrate,
  Bell,
  Download,
  Upload,
  RotateCcw,
  ShieldCheck,
  Smartphone,
  Info,
} from 'lucide-react';

export const SettingsModal: React.FC = () => {
  const {
    settings,
    updateSettings,
    isSettingsOpen,
    setIsSettingsOpen,
    resetAll,
    importBackup,
  } = useTempo();

  const [importText, setImportText] = useState('');
  const [showImportArea, setShowImportArea] = useState(false);

  if (!isSettingsOpen) return null;

  const handleDownloadJson = () => {
    const jsonStr = storage.exportFullBackup();
    const blob = new Blob([jsonStr], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `tempo-yedek-${new Date().toISOString().split('T')[0]}.json`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const handleDownloadCsv = () => {
    const csvStr = storage.exportSessionsCsv();
    const blob = new Blob([csvStr], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `tempo-oturumlar-${new Date().toISOString().split('T')[0]}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const handleExecuteImport = () => {
    if (!importText.trim()) return;
    const res = importBackup(importText.trim());
    if (res.success) {
      alert('Yedek başarıyla geri yüklendi!');
      setShowImportArea(false);
      setImportText('');
    } else {
      alert(`Hata: ${res.error}`);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md safe-area-inset">
      <div className="bg-zinc-900 light:bg-zinc-50 border border-zinc-800 light:border-zinc-200 rounded-3xl w-full max-w-md p-6 shadow-2xl space-y-6 max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between pb-3 border-b border-zinc-800 light:border-zinc-200">
          <div>
            <h2 className="text-base font-bold text-white light:text-zinc-900 font-mono">
              Ayarlar & Tercihler
            </h2>
            <p className="text-xs text-zinc-400 light:text-zinc-600">
              TEMPO Personal Time Budget OS
            </p>
          </div>
          <button
            onClick={() => setIsSettingsOpen(false)}
            className="p-1 rounded-full text-zinc-400 hover:text-white"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Section: Theme */}
        <div className="space-y-2">
          <label className="text-xs font-mono font-bold uppercase text-zinc-400 light:text-zinc-600 block">
            Görünüm & Tema
          </label>
          <div className="grid grid-cols-4 gap-2">
            {[
              { id: 'dark', label: 'Koyu', icon: Moon },
              { id: 'oled', label: 'OLED', icon: Moon },
              { id: 'light', label: 'Açık', icon: Sun },
              { id: 'system', label: 'Sistem', icon: Smartphone },
            ].map(t => {
              const Icon = t.icon;
              return (
                <button
                  key={t.id}
                  onClick={() => updateSettings({ theme: t.id as any })}
                  className={`py-2.5 px-2 rounded-xl border text-center transition-all flex flex-col items-center gap-1.5 ${
                    settings.theme === t.id
                      ? 'bg-blue-600 text-white border-blue-500 font-bold'
                      : 'bg-zinc-950 light:bg-zinc-200/60 border-zinc-800 text-zinc-400 hover:text-white'
                  }`}
                >
                  <Icon className="w-4 h-4" />
                  <span className="text-[11px]">{t.label}</span>
                </button>
              );
            })}
          </div>
        </div>

        {/* Section: Audio & Alerts */}
        <div className="space-y-3">
          <label className="text-xs font-mono font-bold uppercase text-zinc-400 light:text-zinc-600 block">
            Ses & Uyarılar
          </label>

          <div className="space-y-2">
            <div className="flex items-center justify-between p-3 rounded-2xl bg-zinc-950 light:bg-zinc-200/50 border border-zinc-800/80">
              <div className="flex items-center gap-2.5">
                <Volume2 className="w-4 h-4 text-blue-400" />
                <div>
                  <span className="text-xs font-bold text-white light:text-zinc-900 block">
                    Sesli Sinyaller
                  </span>
                  <span className="text-[10px] text-zinc-500">
                    Oturum başlangıç, mola ve bütçe zil sesleri
                  </span>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => soundService.playFinish()}
                  className="px-2 py-1 rounded bg-zinc-800 hover:bg-zinc-700 text-[10px] font-mono text-zinc-300"
                >
                  Test
                </button>
                <input
                  type="checkbox"
                  checked={settings.soundEnabled}
                  onChange={e => updateSettings({ soundEnabled: e.target.checked })}
                  className="rounded border-zinc-700 text-blue-600 focus:ring-0 cursor-pointer"
                />
              </div>
            </div>

            <div className="flex items-center justify-between p-3 rounded-2xl bg-zinc-950 light:bg-zinc-200/50 border border-zinc-800/80">
              <div className="flex items-center gap-2.5">
                <Vibrate className="w-4 h-4 text-emerald-400" />
                <div>
                  <span className="text-xs font-bold text-white light:text-zinc-900 block">
                    Titreşim (Haptics)
                  </span>
                  <span className="text-[10px] text-zinc-500">Dokunsal geri bildirim</span>
                </div>
              </div>
              <input
                type="checkbox"
                checked={settings.vibrationEnabled}
                onChange={e => {
                  updateSettings({ vibrationEnabled: e.target.checked });
                  if (e.target.checked) hapticsService.light();
                }}
                className="rounded border-zinc-700 text-blue-600 focus:ring-0 cursor-pointer"
              />
            </div>

            <div className="flex items-center justify-between p-3 rounded-2xl bg-zinc-950 light:bg-zinc-200/50 border border-zinc-800/80">
              <div className="flex items-center gap-2.5">
                <Bell className="w-4 h-4 text-amber-400" />
                <div>
                  <span className="text-xs font-bold text-white light:text-zinc-900 block">
                    Akıllı Bütçe Uyarıları
                  </span>
                  <span className="text-[10px] text-zinc-500">Son 15 dk ve 5 dk sinyalleri</span>
                </div>
              </div>
              <input
                type="checkbox"
                checked={settings.smartWarning80 && settings.smartWarning95}
                onChange={e =>
                  updateSettings({
                    smartWarning80: e.target.checked,
                    smartWarning95: e.target.checked,
                  })
                }
                className="rounded border-zinc-700 text-blue-600 focus:ring-0 cursor-pointer"
              />
            </div>
          </div>
        </div>

        {/* Section: Data Backup & Restore */}
        <div className="space-y-3">
          <label className="text-xs font-mono font-bold uppercase text-zinc-400 light:text-zinc-600 block">
            Veri Yedekleme & Dışa Aktar
          </label>

          <div className="grid grid-cols-2 gap-2">
            <button
              onClick={handleDownloadJson}
              className="flex items-center justify-center gap-1.5 py-2.5 px-3 rounded-2xl bg-zinc-950 hover:bg-zinc-800 light:bg-zinc-200 light:hover:bg-zinc-300 border border-zinc-800 text-xs font-bold text-white light:text-zinc-900 transition-all active:scale-95"
            >
              <Download className="w-4 h-4 text-blue-400" />
              <span>JSON Yedek</span>
            </button>

            <button
              onClick={handleDownloadCsv}
              className="flex items-center justify-center gap-1.5 py-2.5 px-3 rounded-2xl bg-zinc-950 hover:bg-zinc-800 light:bg-zinc-200 light:hover:bg-zinc-300 border border-zinc-800 text-xs font-bold text-white light:text-zinc-900 transition-all active:scale-95"
            >
              <Download className="w-4 h-4 text-emerald-400" />
              <span>CSV Oturumlar</span>
            </button>
          </div>

          {!showImportArea ? (
            <button
              onClick={() => setShowImportArea(true)}
              className="w-full py-2 rounded-xl bg-zinc-950 light:bg-zinc-200 border border-zinc-800 text-xs text-zinc-400 hover:text-white flex items-center justify-center gap-1.5"
            >
              <Upload className="w-3.5 h-3.5" />
              <span>JSON Yedek Geri Yükle</span>
            </button>
          ) : (
            <div className="p-3 rounded-2xl bg-zinc-950 border border-zinc-800 space-y-2">
              <label className="text-[11px] text-zinc-400 block">
                Yedek JSON metnini buraya yapıştırın:
              </label>
              <textarea
                rows={3}
                value={importText}
                onChange={e => setImportText(e.target.value)}
                placeholder='{"version": 1, ...}'
                className="w-full p-2 rounded-xl bg-zinc-900 border border-zinc-700 text-xs font-mono text-white focus:outline-none"
              />
              <div className="flex items-center justify-end gap-2">
                <button
                  onClick={() => setShowImportArea(false)}
                  className="px-3 py-1 rounded-lg text-xs text-zinc-400 hover:text-white"
                >
                  Vazgeç
                </button>
                <button
                  onClick={handleExecuteImport}
                  className="px-3 py-1 rounded-lg bg-blue-600 hover:bg-blue-500 text-white text-xs font-bold"
                >
                  İçe Aktar
                </button>
              </div>
            </div>
          )}
        </div>

        {/* Section: Reset Data */}
        <div className="pt-2 border-t border-zinc-800/80">
          <button
            onClick={() => {
              if (
                confirm(
                  'Tüm verileri sıfırlayıp varsayılan örneklere (Deep Work, Study, Reading vb.) dönmek istediğinize emin misiniz?'
                )
              ) {
                resetAll();
                alert('Veriler başlangıç durumuna sıfırlandı.');
              }
            }}
            className="w-full py-2.5 rounded-2xl bg-rose-500/10 hover:bg-rose-500/20 border border-rose-500/30 text-rose-400 text-xs font-bold flex items-center justify-center gap-1.5 active:scale-95 transition-all"
          >
            <RotateCcw className="w-4 h-4" />
            <span>Varsayılan Bütçelere Sıfırla (27 Saat)</span>
          </button>
        </div>

        {/* Footer info */}
        <div className="text-center text-[10px] text-zinc-500 font-mono space-y-0.5 pt-1">
          <p>TEMPO — Personal Time Budget OS v1.0.0</p>
          <p>Tamamen Çevrimdışı • Sıfır Sunucu • Yerel Gizlilik</p>
        </div>
      </div>
    </div>
  );
};
