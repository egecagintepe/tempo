import React, { useState } from 'react';
import { useTempo } from '../context/TempoContext.tsx';
import { formatMinutes, formatStopwatch } from '../engine/timeEngine.ts';
import confetti from 'canvas-confetti';
import {
  Play,
  Pause,
  Square,
  Coffee,
  RotateCcw,
  Plus,
  Minus,
  CheckCircle2,
  X,
  Clock,
  Sparkles,
  ArrowRightLeft,
  Minimize2,
  Lock,
} from 'lucide-react';
import { CategoryIcon } from './IconHelper.tsx';

export const FocusTimerModal: React.FC = () => {
  const {
    activeSession,
    categories,
    isFocusModalOpen,
    setIsFocusModalOpen,
    pauseSession,
    resumeSession,
    startBreak,
    endBreak,
    finishSession,
    discardSession,
    adjustActiveSessionTime,
    getCategoryTotals,
    transferToPool,
    markCategoryCompletedForWeek,
  } = useTempo();

  const [isBreakPickerOpen, setIsBreakPickerOpen] = useState(false);
  const [isFinishConfirmOpen, setIsFinishConfirmOpen] = useState(false);
  const [finishNote, setFinishNote] = useState('');
  const [transferRemainingToPool, setTransferRemainingToPool] = useState(false);

  if (!isFocusModalOpen || !activeSession) return null;

  const category = categories.find(c => c.id === activeSession.categoryId);
  if (!category) return null;

  const totals = getCategoryTotals(category.id);
  const isBreak = activeSession.state === 'on_break';
  const isPaused = activeSession.state === 'paused';
  const isRunning = activeSession.state === 'running';

  const currentBreak = activeSession.breaks[activeSession.breaks.length - 1];
  const breakRemainingSeconds = currentBreak
    ? Math.max(0, currentBreak.plannedMinutes * 60 - activeSession.breakSeconds)
    : 0;

  const handleOpenFinish = () => {
    pauseSession();
    setFinishNote('');
    setTransferRemainingToPool(false);
    setIsFinishConfirmOpen(true);
  };

  const handleConfirmFinish = () => {
    const remainingMins = Math.max(0, totals.remainingMinutes);
    if (transferRemainingToPool && remainingMins > 0) {
      transferToPool(category.id, remainingMins, `Haftalık bitiş: ${category.name}`);
      markCategoryCompletedForWeek(category.id, true);
      confetti({ particleCount: 60, spread: 70, origin: { y: 0.6 } });
    }
    finishSession(finishNote.trim() || undefined);
    setIsFinishConfirmOpen(false);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/95 backdrop-blur-2xl p-4 safe-area-inset">
      {/* Container simulating high-end digital stopwatch OS screen */}
      <div className="relative w-full max-w-md h-full max-h-[860px] flex flex-col justify-between p-6 rounded-3xl border border-zinc-800/80 bg-gradient-to-b from-zinc-950 via-zinc-900 to-black text-white shadow-2xl overflow-hidden">
        {/* Dynamic Category Color Aura */}
        <div
          className="absolute -top-32 left-1/2 -translate-x-1/2 w-80 h-80 rounded-full blur-3xl opacity-25 pointer-events-none transition-all duration-700"
          style={{ backgroundColor: isBreak ? '#F59E0B' : category.color }}
        />

        {/* Top Bar: Category Info & Minimize Button */}
        <div className="flex items-center justify-between z-10 pt-2">
          <div className="flex items-center gap-2.5">
            <div
              className="w-10 h-10 rounded-2xl flex items-center justify-center shrink-0 border"
              style={{
                backgroundColor: `${category.color}25`,
                borderColor: `${category.color}50`,
                color: category.color,
              }}
            >
              <CategoryIcon name={category.icon} className="w-5 h-5" />
            </div>
            <div>
              <div className="flex items-center gap-1.5">
                <span className="font-extrabold text-base tracking-tight">{category.name}</span>
                {category.policy === 'strict' && (
                  <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-rose-500/20 text-rose-400 font-bold border border-rose-500/30">
                    KATI BÜTÇE
                  </span>
                )}
                {category.policy === 'protected' && (
                  <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-purple-500/20 text-purple-400 font-bold border border-purple-500/30">
                    KORUNAN
                  </span>
                )}
              </div>
              <p className="text-xs text-zinc-400 mt-0.5">
                Haftalık Bütçe: {formatMinutes(totals.effectiveTargetMinutes)}
              </p>
            </div>
          </div>

          <button
            onClick={() => setIsFocusModalOpen(false)}
            className="w-9 h-9 rounded-full bg-zinc-900/80 hover:bg-zinc-800 border border-zinc-800 text-zinc-400 hover:text-white flex items-center justify-center transition-all active:scale-90"
            title="Arka Plana Al (Sayaç Devam Eder)"
          >
            <Minimize2 className="w-4 h-4" />
          </button>
        </div>

        {/* Center: Big Digital Stopwatch Screen */}
        <div className="my-auto text-center space-y-6 z-10 py-4">
          {/* Mode Pill Indicator */}
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full text-xs font-mono font-bold tracking-wider uppercase border shadow-sm transition-all">
            {isBreak ? (
              <span className="text-amber-400 bg-amber-500/10 border-amber-500/20 px-3 py-1 rounded-full flex items-center gap-1.5">
                <Coffee className="w-3.5 h-3.5 animate-pulse" />
                MOLA MODU
              </span>
            ) : isPaused ? (
              <span className="text-zinc-400 bg-zinc-800/80 border-zinc-700 px-3 py-1 rounded-full flex items-center gap-1.5">
                <Pause className="w-3.5 h-3.5" />
                DURAKLATILDI
              </span>
            ) : (
              <span className="text-emerald-400 bg-emerald-500/10 border-emerald-500/20 px-3 py-1 rounded-full flex items-center gap-1.5">
                <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping" />
                ODAK ÇALIŞMASI
              </span>
            )}
          </div>

          {/* Primary Big Numbers */}
          <div>
            <p className="text-xs font-mono tracking-widest text-zinc-500 uppercase font-semibold">
              {isBreak ? 'MOLA SAYACI' : 'OTURUM SÜRESİ'}
            </p>
            <div className="font-mono font-black text-6xl tracking-tight text-white mt-1 tabular-nums drop-shadow-lg">
              {isBreak
                ? formatStopwatch(activeSession.breakSeconds)
                : formatStopwatch(activeSession.activeSeconds)}
            </div>
          </div>

          {/* Category Budget Balance Pill */}
          <div className="inline-block p-4 rounded-2xl bg-zinc-900/80 border border-zinc-800/90 font-mono max-w-xs mx-auto">
            <div className="flex items-center justify-between gap-6 text-xs">
              <div>
                <span className="text-zinc-500 block uppercase text-[10px]">Kalan Bütçe</span>
                <span
                  className={`font-bold text-sm ${
                    totals.isExhausted
                      ? 'text-rose-400'
                      : totals.remainingMinutes <= 30
                      ? 'text-amber-400'
                      : 'text-emerald-400'
                  }`}
                >
                  {formatMinutes(totals.remainingMinutes)}
                </span>
              </div>
              <div className="h-6 w-px bg-zinc-800" />
              <div>
                <span className="text-zinc-500 block uppercase text-[10px]">Haftalık İlerleme</span>
                <span className="font-bold text-sm text-blue-400">%{totals.progressPercent}</span>
              </div>
            </div>

            {/* Micro Progress Bar */}
            <div className="w-full h-1.5 rounded-full bg-zinc-800 mt-2.5 overflow-hidden">
              <div
                className="h-full rounded-full transition-all duration-300"
                style={{
                  width: `${totals.progressPercent}%`,
                  backgroundColor: totals.isExhausted && category.policy === 'strict' ? '#F43F5E' : category.color,
                }}
              />
            </div>
          </div>

          {/* Time Fine-Tuning Stepper (+/- 5m) */}
          <div className="flex items-center justify-center gap-3 pt-1">
            <button
              onClick={() => adjustActiveSessionTime(-300)}
              className="flex items-center gap-1 px-2.5 py-1 rounded-xl bg-zinc-900 hover:bg-zinc-800 border border-zinc-800 text-xs font-mono text-zinc-400 hover:text-white transition-all active:scale-95"
              title="5 Dakika Çıkar"
            >
              <Minus className="w-3 h-3" />
              <span>5 dk</span>
            </button>
            <span className="text-[10px] text-zinc-600 font-mono uppercase">İnce Ayar</span>
            <button
              onClick={() => adjustActiveSessionTime(300)}
              className="flex items-center gap-1 px-2.5 py-1 rounded-xl bg-zinc-900 hover:bg-zinc-800 border border-zinc-800 text-xs font-mono text-zinc-400 hover:text-white transition-all active:scale-95"
              title="5 Dakika Ekle"
            >
              <Plus className="w-3 h-3" />
              <span>5 dk</span>
            </button>
          </div>
        </div>

        {/* Bottom Controls Area */}
        <div className="space-y-3 z-10 pb-2">
          {/* Main Action Buttons */}
          <div className="grid grid-cols-3 gap-3">
            {/* Break / End Break Button */}
            {isBreak ? (
              <button
                onClick={endBreak}
                className="py-4 rounded-2xl bg-amber-500 hover:bg-amber-400 text-black font-extrabold text-xs flex flex-col items-center justify-center gap-1 shadow-lg shadow-amber-500/20 active:scale-95 transition-all"
              >
                <Play className="w-5 h-5 fill-current" />
                <span>Çalışmaya Dön</span>
              </button>
            ) : (
              <button
                onClick={() => setIsBreakPickerOpen(true)}
                className="py-4 rounded-2xl bg-zinc-900 hover:bg-zinc-800 border border-zinc-800 text-zinc-200 font-bold text-xs flex flex-col items-center justify-center gap-1 active:scale-95 transition-all"
              >
                <Coffee className="w-5 h-5 text-amber-400" />
                <span>Mola Ver</span>
              </button>
            )}

            {/* Play / Pause Primary Button */}
            {isRunning ? (
              <button
                onClick={pauseSession}
                className="py-4 rounded-2xl bg-zinc-800 hover:bg-zinc-700 text-white font-extrabold text-xs flex flex-col items-center justify-center gap-1 active:scale-95 transition-all shadow-md"
              >
                <Pause className="w-6 h-6 fill-current" />
                <span>Duraklat</span>
              </button>
            ) : (
              <button
                onClick={resumeSession}
                disabled={category.policy === 'strict' && totals.isExhausted}
                className="py-4 rounded-2xl bg-blue-600 hover:bg-blue-500 disabled:opacity-50 text-white font-extrabold text-xs flex flex-col items-center justify-center gap-1 shadow-lg shadow-blue-500/25 active:scale-95 transition-all"
              >
                <Play className="w-6 h-6 fill-current ml-0.5" />
                <span>Devam Et</span>
              </button>
            )}

            {/* Finish & Save Session Button */}
            <button
              onClick={handleOpenFinish}
              className="py-4 rounded-2xl bg-emerald-600/90 hover:bg-emerald-500 text-white font-extrabold text-xs flex flex-col items-center justify-center gap-1 shadow-lg shadow-emerald-600/20 active:scale-95 transition-all"
            >
              <Square className="w-5 h-5 fill-current" />
              <span>Bitir & Kaydet</span>
            </button>
          </div>

          {/* Discard link */}
          <div className="flex items-center justify-center pt-1">
            <button
              onClick={() => {
                if (confirm('Oturumu kaydetmeden iptal etmek istediğinize emin misiniz?')) {
                  discardSession();
                }
              }}
              className="text-[11px] text-zinc-500 hover:text-rose-400 transition-colors"
            >
              Oturumu İptal Et / Sil
            </button>
          </div>
        </div>
      </div>

      {/* Break Duration Picker Modal */}
      {isBreakPickerOpen && (
        <div className="fixed inset-0 z-60 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md">
          <div className="bg-zinc-900 border border-zinc-800 rounded-3xl w-full max-w-xs p-5 shadow-2xl space-y-4 text-center">
            <div className="w-10 h-10 rounded-2xl bg-amber-500/15 text-amber-400 mx-auto flex items-center justify-center">
              <Coffee className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-bold text-sm text-white font-mono">Mola Süresi Seç</h3>
              <p className="text-xs text-zinc-400 mt-1">
                Mola süresi çalışma bütçesinden tüketilmez.
              </p>
            </div>

            <div className="grid grid-cols-2 gap-2 pt-1 font-mono">
              {[5, 10, 15, 30].map(mins => (
                <button
                  key={mins}
                  onClick={() => {
                    startBreak(mins, `${mins} Dakika Mola`);
                    setIsBreakPickerOpen(false);
                  }}
                  className="py-3 rounded-xl bg-zinc-950 hover:bg-zinc-800 border border-zinc-800 text-xs font-bold text-white transition-all active:scale-95"
                >
                  {mins} Dakika
                </button>
              ))}
            </div>

            <button
              onClick={() => setIsBreakPickerOpen(false)}
              className="w-full py-2 text-xs font-semibold text-zinc-400 hover:text-white"
            >
              Vazgeç
            </button>
          </div>
        </div>
      )}

      {/* Finish Session & Pool Transfer Dialog */}
      {isFinishConfirmOpen && (
        <div className="fixed inset-0 z-60 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md">
          <div className="bg-zinc-900 border border-zinc-800 rounded-3xl w-full max-w-sm p-6 shadow-2xl space-y-4 text-left">
            <div className="flex items-center gap-2.5">
              <div className="w-10 h-10 rounded-2xl bg-emerald-500/15 text-emerald-400 flex items-center justify-center">
                <CheckCircle2 className="w-5 h-5" />
              </div>
              <div>
                <h3 className="font-bold text-sm text-white font-mono">Oturum Tamamlandı</h3>
                <p className="text-xs text-zinc-400">{category.name}</p>
              </div>
            </div>

            {/* Session Summary Card */}
            <div className="p-3.5 rounded-2xl bg-zinc-950 border border-zinc-800 font-mono text-xs space-y-2">
              <div className="flex justify-between">
                <span className="text-zinc-500">Aktif Çalışma:</span>
                <span className="font-bold text-blue-400">
                  {formatStopwatch(activeSession.activeSeconds)}
                </span>
              </div>
              <div className="flex justify-between">
                <span className="text-zinc-500">Mola Süresi:</span>
                <span className="font-bold text-amber-400">
                  {formatMinutes(activeSession.breakSeconds / 60)}
                </span>
              </div>
              <div className="flex justify-between border-t border-zinc-800 pt-2">
                <span className="text-zinc-500">Kalan Bütçe:</span>
                <span className="font-bold text-emerald-400">
                  {formatMinutes(totals.remainingMinutes)}
                </span>
              </div>
            </div>

            {/* Session Note */}
            <div>
              <label className="block text-xs font-medium text-zinc-400 mb-1">
                Kısa Not (İsteğe Bağlı)
              </label>
              <input
                type="text"
                value={finishNote}
                onChange={e => setFinishNote(e.target.value)}
                placeholder="Örn: Bölüm 1-2 yüklendi, RF soruları bitti"
                className="w-full px-3 py-2 rounded-xl bg-zinc-950 border border-zinc-800 text-xs text-white focus:outline-none focus:border-blue-500"
              />
            </div>

            {/* Prompt: Transfer Remaining to Pool if finished */}
            {totals.remainingMinutes > 0 && (
              <label className="flex items-start gap-2.5 p-3 rounded-2xl bg-blue-950/20 border border-blue-500/30 cursor-pointer">
                <input
                  type="checkbox"
                  checked={transferRemainingToPool}
                  onChange={e => setTransferRemainingToPool(e.target.checked)}
                  className="mt-0.5 rounded border-zinc-700 text-blue-600 focus:ring-0 cursor-pointer"
                />
                <div className="text-xs">
                  <span className="font-bold text-blue-400 block">
                    Bu haftalık işleri tamamladım
                  </span>
                  <span className="text-zinc-400 text-[11px] leading-relaxed">
                    Kalan {formatMinutes(totals.remainingMinutes)} süreyi Serbest Zaman Havuzu'na aktar.
                  </span>
                </div>
              </label>
            )}

            <div className="flex items-center justify-end gap-2 pt-2">
              <button
                type="button"
                onClick={() => setIsFinishConfirmOpen(false)}
                className="px-4 py-2 rounded-xl text-xs font-semibold text-zinc-400 hover:text-white"
              >
                Geri
              </button>
              <button
                type="button"
                onClick={handleConfirmFinish}
                className="px-5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold shadow-lg shadow-emerald-500/20"
              >
                Kaydet ve Kapat
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
