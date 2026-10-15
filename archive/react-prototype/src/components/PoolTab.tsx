import React, { useState } from 'react';
import { useTempo } from '../context/TempoContext.tsx';
import { formatMinutes, formatStopwatch } from '../engine/timeEngine.ts';
import confetti from 'canvas-confetti';
import {
  Droplets,
  ArrowRight,
  RotateCcw,
  Plus,
  Minus,
  Sparkles,
  Info,
  Clock,
  ShieldAlert,
  Check,
  X,
} from 'lucide-react';
import { CategoryIcon } from './IconHelper.tsx';

export const PoolTab: React.FC = () => {
  const {
    poolBalance,
    categories,
    transactions,
    transferFromPool,
    transferToPool,
    undoTransaction,
    getCategoryTotals,
  } = useTempo();

  const [isTransferModalOpen, setIsTransferModalOpen] = useState(false);
  const [transferDirection, setTransferDirection] = useState<'from_pool' | 'to_pool'>('from_pool');
  const [selectedCategoryId, setSelectedCategoryId] = useState<string>('');
  const [minutesToTransfer, setMinutesToTransfer] = useState<number>(30);
  const [customNote, setCustomNote] = useState('');

  const activeCategories = categories.filter(c => !c.isArchived);

  const openTransferModal = (direction: 'from_pool' | 'to_pool') => {
    setTransferDirection(direction);
    setSelectedCategoryId(activeCategories[0]?.id || '');
    setMinutesToTransfer(30);
    setCustomNote('');
    setIsTransferModalOpen(true);
  };

  const selectedCategory = categories.find(c => c.id === selectedCategoryId);
  const selectedCatTotals = selectedCategoryId ? getCategoryTotals(selectedCategoryId) : null;

  const handleExecuteTransfer = (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedCategoryId) return;

    if (transferDirection === 'from_pool') {
      const res = transferFromPool(selectedCategoryId, minutesToTransfer, customNote);
      if (res.success) {
        confetti({ particleCount: 50, spread: 60, origin: { y: 0.6 } });
        setIsTransferModalOpen(false);
      } else {
        alert(res.error);
      }
    } else {
      const res = transferToPool(selectedCategoryId, minutesToTransfer, customNote);
      if (res.success) {
        confetti({ particleCount: 50, spread: 60, origin: { y: 0.6 } });
        setIsTransferModalOpen(false);
      } else {
        alert(res.error);
      }
    }
  };

  return (
    <div className="space-y-6 pb-28 pt-2">
      {/* Title */}
      <div>
        <span className="text-[10px] font-mono tracking-widest text-blue-400 font-bold uppercase">
          MERKEZİ ZAMAN REZERVİ
        </span>
        <h1 className="text-xl font-black tracking-tight text-white light:text-zinc-900 mt-0.5">
          Serbest Zaman Havuzu
        </h1>
        <p className="text-xs text-zinc-400 light:text-zinc-600 mt-1">
          Erken bitirdiğin işlerden kazandığın saatleri dilediğin projeye aktar.
        </p>
      </div>

      {/* Hero Pool Visual Card */}
      <div className="relative overflow-hidden rounded-3xl bg-gradient-to-b from-blue-950/50 via-zinc-900 to-zinc-950 light:from-blue-50 light:to-white border border-blue-500/30 p-6 text-center shadow-2xl">
        {/* Glow backdrop */}
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-48 h-48 bg-blue-500/10 rounded-full blur-3xl pointer-events-none" />

        <div className="flex items-center justify-center gap-1.5 text-xs font-mono font-bold text-blue-400 uppercase tracking-widest mb-2">
          <Droplets className="w-4 h-4 animate-bounce" />
          <span>AVAILABLE TIME</span>
        </div>

        {/* Big Digital Numbers */}
        <div className="font-mono font-black text-5xl tracking-tight text-white light:text-zinc-900 my-2">
          {formatStopwatch(poolBalance.balanceMinutes * 60, false)}
        </div>

        <p className="text-sm font-medium text-zinc-400 light:text-zinc-600">
          Kullanılabilir Boş Süre:{' '}
          <strong className="text-blue-400">{formatMinutes(poolBalance.balanceMinutes)}</strong>
        </p>

        {/* Quick Stats Grid */}
        <div className="grid grid-cols-2 gap-3 mt-6 pt-4 border-t border-zinc-800/80 light:border-zinc-200 text-left font-mono">
          <div className="p-3 rounded-2xl bg-zinc-900/60 light:bg-zinc-100 border border-zinc-800/60">
            <span className="text-[10px] text-zinc-500 uppercase tracking-wider block">
              Havuza Eklenen
            </span>
            <p className="text-base font-bold text-emerald-400 mt-0.5">
              +{formatMinutes(poolBalance.addedThisWeekMinutes)}
            </p>
          </div>
          <div className="p-3 rounded-2xl bg-zinc-900/60 light:bg-zinc-100 border border-zinc-800/60">
            <span className="text-[10px] text-zinc-500 uppercase tracking-wider block">
              Havuzdan Dağıtılan
            </span>
            <p className="text-base font-bold text-blue-400 mt-0.5">
              -{formatMinutes(poolBalance.usedThisWeekMinutes)}
            </p>
          </div>
        </div>

        {/* Action Buttons */}
        <div className="grid grid-cols-2 gap-3 mt-5">
          <button
            onClick={() => openTransferModal('from_pool')}
            disabled={poolBalance.balanceMinutes <= 0}
            className="flex items-center justify-center gap-2 py-3 px-4 rounded-2xl bg-blue-600 hover:bg-blue-500 disabled:opacity-50 disabled:pointer-events-none text-white font-bold text-xs shadow-lg shadow-blue-500/25 active:scale-95 transition-all"
          >
            <Plus className="w-4 h-4" />
            <span>Kategoriye Aktar</span>
          </button>

          <button
            onClick={() => openTransferModal('to_pool')}
            className="flex items-center justify-center gap-2 py-3 px-4 rounded-2xl bg-zinc-800 hover:bg-zinc-700 light:bg-zinc-200 light:hover:bg-zinc-300 text-zinc-200 light:text-zinc-900 font-bold text-xs active:scale-95 transition-all"
          >
            <Minus className="w-4 h-4" />
            <span>Kategoriden Çek</span>
          </button>
        </div>
      </div>

      {/* Transfer Rules Infobox */}
      <div className="p-4 rounded-2xl bg-zinc-900/50 light:bg-zinc-100 border border-zinc-800 light:border-zinc-200 space-y-2">
        <div className="flex items-center gap-2 text-xs font-bold text-white light:text-zinc-900">
          <Info className="w-4 h-4 text-blue-400" />
          <span>Zaman Transfer İlkeleri</span>
        </div>
        <ul className="text-[11px] text-zinc-400 light:text-zinc-600 space-y-1 list-disc list-inside leading-relaxed">
          <li>Aynı dakika asla iki kez harcanamaz. Havuz negatif bakiye veremez.</li>
          <li>Havuza bırakılan süre kaynak kategorinin kotasından güvenle düşülür.</li>
          <li>Tüm transferler atomik kayıt altındadır ve dilediğinde geri alınabilir.</li>
        </ul>
      </div>

      {/* Transaction History (Ledger) */}
      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Clock className="w-4 h-4 text-zinc-400" />
            <h2 className="text-sm font-bold text-white light:text-zinc-900 uppercase font-mono">
              İşlem Defteri (Ledger)
            </h2>
          </div>
          <span className="text-xs text-zinc-500 font-mono">
            {transactions.filter(t => !t.isUndone).length} aktif kayıt
          </span>
        </div>

        {transactions.length === 0 ? (
          <div className="p-6 rounded-2xl bg-zinc-900/30 light:bg-zinc-100 text-center text-xs text-zinc-500 border border-dashed border-zinc-800 light:border-zinc-300">
            Bu hafta henüz bir zaman transferi yapılmadı.
          </div>
        ) : (
          <div className="space-y-2">
            {transactions.map(tx => {
              const sourceCat = tx.sourceCategoryId
                ? categories.find(c => c.id === tx.sourceCategoryId)
                : null;
              const targetCat = tx.targetCategoryId
                ? categories.find(c => c.id === tx.targetCategoryId)
                : null;

              const isFromPool = tx.type === 'pool_to_category';

              return (
                <div
                  key={tx.id}
                  className={`p-3.5 rounded-2xl border flex items-center justify-between transition-all ${
                    tx.isUndone
                      ? 'opacity-40 bg-zinc-950/40 border-zinc-900 line-through'
                      : 'bg-zinc-900/70 light:bg-white border-zinc-800/80 light:border-zinc-200'
                  }`}
                >
                  <div className="flex items-center gap-3">
                    <div
                      className={`w-9 h-9 rounded-xl flex items-center justify-center shrink-0 ${
                        isFromPool
                          ? 'bg-blue-500/15 text-blue-400'
                          : 'bg-emerald-500/15 text-emerald-400'
                      }`}
                    >
                      <ArrowRight className="w-4 h-4" />
                    </div>
                    <div>
                      <div className="flex items-center gap-1.5 text-xs font-bold text-white light:text-zinc-900">
                        {isFromPool ? (
                          <>
                            <span className="text-blue-400">Havuz</span>
                            <span className="text-zinc-500">→</span>
                            <span>{targetCat?.name || 'Kategori'}</span>
                          </>
                        ) : (
                          <>
                            <span>{sourceCat?.name || 'Kategori'}</span>
                            <span className="text-zinc-500">→</span>
                            <span className="text-emerald-400">Havuz</span>
                          </>
                        )}
                        <span className="text-zinc-400 font-mono ml-1 font-bold">
                          ({formatMinutes(tx.minutes)})
                        </span>
                      </div>
                      <p className="text-[10px] text-zinc-500 mt-0.5">
                        {new Date(tx.timestamp).toLocaleTimeString('tr-TR', {
                          hour: '2-digit',
                          minute: '2-digit',
                        })}{' '}
                        • {tx.note || 'Zaman transferi'}
                      </p>
                    </div>
                  </div>

                  {!tx.isUndone && (
                    <button
                      onClick={() => undoTransaction(tx.id)}
                      className="flex items-center gap-1 px-2.5 py-1 rounded-lg bg-zinc-800 hover:bg-zinc-700 light:bg-zinc-200 light:hover:bg-zinc-300 text-zinc-300 light:text-zinc-700 text-xs font-medium active:scale-95 transition-all"
                      title="İşlemi Geri Al"
                    >
                      <RotateCcw className="w-3.5 h-3.5" />
                      <span>Geri Al</span>
                    </button>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Transfer Execution Modal */}
      {isTransferModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/75 backdrop-blur-sm">
          <div className="bg-zinc-900 light:bg-zinc-50 border border-zinc-800 light:border-zinc-200 rounded-3xl w-full max-w-sm p-6 shadow-2xl space-y-4">
            <div className="flex items-center justify-between">
              <h2 className="text-base font-bold text-white light:text-zinc-900 font-mono">
                {transferDirection === 'from_pool' ? 'Havuzdan Kategoriye Aktar' : 'Kategoriden Havuza Çek'}
              </h2>
              <button
                onClick={() => setIsTransferModalOpen(false)}
                className="p-1 rounded-full text-zinc-400 hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleExecuteTransfer} className="space-y-4">
              {/* Category Select */}
              <div>
                <label className="block text-xs font-medium text-zinc-400 mb-1">
                  Hedef / Kaynak Kategori
                </label>
                <select
                  value={selectedCategoryId}
                  onChange={e => setSelectedCategoryId(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-zinc-950 light:bg-white border border-zinc-800 light:border-zinc-300 text-xs text-white light:text-zinc-900 focus:outline-none"
                >
                  {activeCategories.map(cat => (
                    <option key={cat.id} value={cat.id}>
                      {cat.name} ({cat.policy})
                    </option>
                  ))}
                </select>
              </div>

              {/* Minutes Selection Presets */}
              <div>
                <label className="block text-xs font-medium text-zinc-400 mb-1">
                  Aktarılacak Süre (Dakika)
                </label>
                <div className="grid grid-cols-4 gap-1.5 mb-2">
                  {[15, 30, 45, 60].map(mins => (
                    <button
                      type="button"
                      key={mins}
                      onClick={() => setMinutesToTransfer(mins)}
                      className={`py-1.5 rounded-lg text-xs font-mono font-bold transition-all ${
                        minutesToTransfer === mins
                          ? 'bg-blue-600 text-white'
                          : 'bg-zinc-950 light:bg-zinc-200 text-zinc-400 hover:text-white'
                      }`}
                    >
                      +{mins} dk
                    </button>
                  ))}
                </div>
                <input
                  type="number"
                  min="5"
                  max={
                    transferDirection === 'from_pool'
                      ? poolBalance.balanceMinutes
                      : selectedCatTotals?.remainingMinutes || 120
                  }
                  step="5"
                  value={minutesToTransfer}
                  onChange={e => setMinutesToTransfer(parseInt(e.target.value) || 0)}
                  className="w-full px-3 py-2 rounded-xl bg-zinc-950 light:bg-white border border-zinc-800 light:border-zinc-300 text-sm text-white light:text-zinc-900 font-mono focus:outline-none focus:border-blue-500"
                />
              </div>

              {/* Dynamic Live Preview Box */}
              <div className="p-3.5 rounded-2xl bg-zinc-950 light:bg-zinc-200/60 border border-zinc-800 font-mono text-xs space-y-1">
                <span className="text-[10px] text-zinc-500 uppercase tracking-wider block">
                  İşlem Önizlemesi
                </span>
                {transferDirection === 'from_pool' ? (
                  <>
                    <p className="font-bold text-blue-400">
                      {selectedCategory?.name || 'Kategori'} +{minutesToTransfer} dk
                    </p>
                    <p className="text-zinc-400">
                      Havuz: {formatMinutes(poolBalance.balanceMinutes)} →{' '}
                      <strong className="text-white light:text-zinc-900">
                        {formatMinutes(Math.max(0, poolBalance.balanceMinutes - minutesToTransfer))}
                      </strong>
                    </p>
                  </>
                ) : (
                  <>
                    <p className="font-bold text-emerald-400">
                      Havuz +{minutesToTransfer} dk
                    </p>
                    <p className="text-zinc-400">
                      {selectedCategory?.name || 'Kategori'}:{' '}
                      {formatMinutes(selectedCatTotals?.remainingMinutes || 0)} →{' '}
                      <strong className="text-white light:text-zinc-900">
                        {formatMinutes(
                          Math.max(0, (selectedCatTotals?.remainingMinutes || 0) - minutesToTransfer)
                        )}
                      </strong>
                    </p>
                  </>
                )}
              </div>

              <div className="flex items-center justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setIsTransferModalOpen(false)}
                  className="px-4 py-2 rounded-xl text-xs font-semibold text-zinc-400 hover:text-white"
                >
                  İptal
                </button>
                <button
                  type="submit"
                  className="px-5 py-2 rounded-xl bg-blue-600 hover:bg-blue-500 text-white text-xs font-bold shadow-lg shadow-blue-500/20"
                >
                  Onayla ve Aktar
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
