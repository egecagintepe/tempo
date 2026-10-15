import React, { useState } from 'react';
import { useTempo } from '../context/TempoContext.tsx';
import { formatMinutes, formatStopwatch } from '../engine/timeEngine.ts';
import {
  BarChart3,
  Calendar,
  CheckCircle2,
  Clock,
  Sparkles,
  TrendingUp,
  Filter,
  Plus,
  Trash2,
  X,
  FileText,
} from 'lucide-react';
import { CategoryIcon } from './IconHelper.tsx';

export const AnalyticsTab: React.FC = () => {
  const {
    categories,
    sessions,
    tasks,
    poolBalance,
    weeklyTotals,
    getCategoryTotals,
    currentWeek,
    addManualSession,
    deleteSession,
  } = useTempo();

  const [selectedFilterCategory, setSelectedFilterCategory] = useState<string>('all');
  const [isManualModalOpen, setIsManualModalOpen] = useState(false);

  // Manual Session Form
  const [manualCatId, setManualCatId] = useState(categories[0]?.id || '');
  const [manualDurationMins, setManualDurationMins] = useState(45);
  const [manualBreakMins, setManualBreakMins] = useState(5);
  const [manualNote, setManualNote] = useState('');

  // Weekly category calculations
  const categoryStats = categories
    .filter(c => !c.isArchived)
    .map(cat => {
      const totals = getCategoryTotals(cat.id);
      return {
        cat,
        totals,
      };
    })
    .sort((a, b) => b.totals.spentSeconds - a.totals.spentSeconds);

  const topCategory = categoryStats[0]?.totals.spentSeconds > 0 ? categoryStats[0].cat : null;
  const overBudgetCount = categoryStats.filter(c => c.totals.isOverBudget).length;
  const completedTasksCount = tasks.filter(t => t.isCompleted).length;

  // Day of week breakdown (Mon=0 to Sun=6)
  const daysOfWeek = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  const dayMinutes = [0, 0, 0, 0, 0, 0, 0];

  for (const s of sessions) {
    if (s.weekPeriodId === currentWeek.id) {
      const d = new Date(s.startTime);
      const dayIdx = (d.getDay() + 6) % 7; // Convert 0(Sun)->6, 1(Mon)->0
      dayMinutes[dayIdx] += Math.round(s.activeSeconds / 60);
    }
  }

  const maxDayMinutes = Math.max(...dayMinutes, 60);

  // Filtered session history
  const filteredSessions = sessions.filter(
    s => selectedFilterCategory === 'all' || s.categoryId === selectedFilterCategory
  );

  const handleAddManualSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!manualCatId || manualDurationMins <= 0) return;

    addManualSession({
      categoryId: manualCatId,
      activeSeconds: manualDurationMins * 60,
      breakSeconds: manualBreakMins * 60,
      startTime: Date.now() - (manualDurationMins + manualBreakMins) * 60 * 1000,
      note: manualNote.trim() || undefined,
    });

    setIsManualModalOpen(false);
  };

  // Rule-based insights
  const insights: string[] = [];
  if (topCategory) {
    insights.push(`Bu hafta en çok odaklandığın alan: ${topCategory.name}.`);
  }
  const exhaustedStrict = categoryStats.filter(c => c.cat.policy === 'strict' && c.totals.isExhausted);
  if (exhaustedStrict.length > 0) {
    insights.push(
      `${exhaustedStrict.map(c => c.cat.name).join(', ')} için katı bütçe kotasını başarıyla korudun.`
    );
  }
  if (poolBalance.balanceMinutes > 0) {
    insights.push(
      `Havuzunda ${formatMinutes(poolBalance.balanceMinutes)} serbest zamanın hazır bekliyor.`
    );
  }
  if (weeklyTotals.progressPercent < 50) {
    insights.push(`Haftalık kapasitenin %${weeklyTotals.progressPercent}'sini kullandın; hedefler için yeterli zamanın var.`);
  }

  return (
    <div className="space-y-6 pb-28 pt-2">
      {/* Title */}
      <div className="flex items-center justify-between">
        <div>
          <span className="text-[10px] font-mono tracking-widest text-blue-400 font-bold uppercase">
            GERÇEKLEŞME & RAPORLAR
          </span>
          <h1 className="text-xl font-black tracking-tight text-white light:text-zinc-900 mt-0.5">
            Analiz ve İstatistik
          </h1>
          <p className="text-xs text-zinc-400 light:text-zinc-600 mt-0.5">
            {currentWeek.id.replace('-W', '. Hafta ')} dönemi zaman muhasebesi
          </p>
        </div>

        <button
          onClick={() => {
            setManualCatId(categories[0]?.id || '');
            setManualDurationMins(45);
            setManualBreakMins(5);
            setManualNote('');
            setIsManualModalOpen(true);
          }}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-zinc-800 hover:bg-zinc-700 light:bg-zinc-200 light:hover:bg-zinc-300 text-xs font-semibold text-white light:text-zinc-900 active:scale-95 transition-all"
        >
          <Plus className="w-4 h-4" />
          <span>Manuel Ekle</span>
        </button>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-2 gap-3">
        <div className="p-4 rounded-2xl bg-zinc-900/80 light:bg-zinc-100 border border-zinc-800 light:border-zinc-200">
          <span className="text-[10px] font-mono text-zinc-500 uppercase tracking-wider block">
            Toplam Harcanan
          </span>
          <p className="text-2xl font-mono font-black text-blue-400 mt-1">
            {formatMinutes(weeklyTotals.totalSpentMinutes)}
          </p>
          <p className="text-[11px] text-zinc-400 mt-1">
            Bütçe: {formatMinutes(weeklyTotals.totalBudgetMinutes)}
          </p>
        </div>

        <div className="p-4 rounded-2xl bg-zinc-900/80 light:bg-zinc-100 border border-zinc-800 light:border-zinc-200">
          <span className="text-[10px] font-mono text-zinc-500 uppercase tracking-wider block">
            Kalan Kapasite
          </span>
          <p className="text-2xl font-mono font-black text-emerald-400 mt-1">
            {formatMinutes(weeklyTotals.totalRemainingMinutes)}
          </p>
          <p className="text-[11px] text-zinc-400 mt-1">
            Havuz: +{formatMinutes(poolBalance.balanceMinutes)}
          </p>
        </div>
      </div>

      {/* Daily Activity Chart (Pzt-Paz) */}
      <div className="p-4 rounded-3xl bg-zinc-900/80 light:bg-zinc-100 border border-zinc-800 light:border-zinc-200 space-y-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Calendar className="w-4 h-4 text-blue-400" />
            <h2 className="text-xs font-bold uppercase font-mono text-white light:text-zinc-900">
              Günlere Göre Çalışma
            </h2>
          </div>
          <span className="text-[11px] text-zinc-500 font-mono">Pazartesi – Pazar</span>
        </div>

        <div className="flex items-end justify-between gap-2 h-28 pt-4 pb-1">
          {daysOfWeek.map((day, idx) => {
            const mins = dayMinutes[idx];
            const heightPercent = Math.max(8, Math.round((mins / maxDayMinutes) * 100));
            const isToday = ((new Date().getDay() + 6) % 7) === idx;

            return (
              <div key={day} className="flex-1 flex flex-col items-center gap-1.5 h-full justify-end">
                <span className="text-[9px] font-mono text-zinc-400">{mins > 0 ? `${mins}d` : '-'}</span>
                <div
                  className={`w-full rounded-t-lg transition-all duration-300 ${
                    isToday
                      ? 'bg-gradient-to-t from-blue-600 to-cyan-400 shadow-md shadow-blue-500/20'
                      : mins > 0
                      ? 'bg-zinc-700 light:bg-zinc-300'
                      : 'bg-zinc-800/40 light:bg-zinc-200/50'
                  }`}
                  style={{ height: `${heightPercent}%` }}
                />
                <span
                  className={`text-[10px] font-mono font-bold ${
                    isToday ? 'text-blue-400' : 'text-zinc-500'
                  }`}
                >
                  {day}
                </span>
              </div>
            );
          })}
        </div>
      </div>

      {/* Category Comparison: Planned vs Actual */}
      <div className="p-4 rounded-3xl bg-zinc-900/80 light:bg-zinc-100 border border-zinc-800 light:border-zinc-200 space-y-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <BarChart3 className="w-4 h-4 text-emerald-400" />
            <h2 className="text-xs font-bold uppercase font-mono text-white light:text-zinc-900">
              Kategori Karşılaştırması (Plan vs Gerçek)
            </h2>
          </div>
        </div>

        <div className="space-y-3 pt-1">
          {categoryStats.map(({ cat, totals }) => (
            <div key={cat.id} className="space-y-1">
              <div className="flex items-center justify-between text-xs">
                <div className="flex items-center gap-2">
                  <div
                    className="w-2.5 h-2.5 rounded-full"
                    style={{ backgroundColor: cat.color }}
                  />
                  <span className="font-bold text-white light:text-zinc-900">{cat.name}</span>
                </div>
                <div className="font-mono text-[11px] text-zinc-400">
                  <strong className="text-white light:text-zinc-900">
                    {formatMinutes(totals.spentMinutes)}
                  </strong>{' '}
                  / {formatMinutes(totals.effectiveTargetMinutes)}
                </div>
              </div>

              {/* Stacked Progress Bar */}
              <div className="w-full h-2 rounded-full bg-zinc-800 light:bg-zinc-200 overflow-hidden">
                <div
                  className="h-full rounded-full transition-all"
                  style={{
                    width: `${totals.progressPercent}%`,
                    backgroundColor: cat.color,
                  }}
                />
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Smart Insights Box */}
      {insights.length > 0 && (
        <div className="p-4 rounded-3xl bg-zinc-900/40 light:bg-zinc-100 border border-zinc-800/80 space-y-2">
          <div className="flex items-center gap-2 text-xs font-bold text-amber-400">
            <Sparkles className="w-4 h-4" />
            <span>Haftalık Çıkarımlar</span>
          </div>
          <div className="space-y-1.5 text-xs text-zinc-300 light:text-zinc-700">
            {insights.map((item, i) => (
              <p key={i} className="flex items-start gap-2">
                <span className="text-blue-400">•</span>
                <span>{item}</span>
              </p>
            ))}
          </div>
        </div>
      )}

      {/* Filterable Session History List */}
      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Clock className="w-4 h-4 text-zinc-400" />
            <h2 className="text-sm font-bold text-white light:text-zinc-900 uppercase font-mono">
              Oturum Geçmişi
            </h2>
          </div>
          {/* Category Filter */}
          <select
            value={selectedFilterCategory}
            onChange={e => setSelectedFilterCategory(e.target.value)}
            className="px-2.5 py-1 rounded-xl bg-zinc-900 light:bg-zinc-200 border border-zinc-800 light:border-zinc-300 text-xs text-zinc-300 light:text-zinc-800 focus:outline-none"
          >
            <option value="all">Tüm Kategoriler</option>
            {categories.map(c => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
        </div>

        {filteredSessions.length === 0 ? (
          <div className="p-8 rounded-2xl bg-zinc-900/30 light:bg-zinc-100 text-center text-xs text-zinc-500 border border-dashed border-zinc-800">
            Bu filtrelere uygun oturum kaydı bulunamadı.
          </div>
        ) : (
          <div className="space-y-2">
            {filteredSessions.map(session => {
              const cat = categories.find(c => c.id === session.categoryId);
              return (
                <div
                  key={session.id}
                  className="p-3.5 rounded-2xl bg-zinc-900/70 light:bg-white border border-zinc-800/80 light:border-zinc-200 flex items-center justify-between hover:border-zinc-700 transition-all"
                >
                  <div className="flex items-center gap-3">
                    <div
                      className="w-9 h-9 rounded-xl flex items-center justify-center shrink-0"
                      style={{ backgroundColor: `${cat?.color || '#3b82f6'}20`, color: cat?.color || '#3b82f6' }}
                    >
                      <CategoryIcon name={cat?.icon || 'sparkles'} className="w-4 h-4" />
                    </div>
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="font-bold text-xs text-white light:text-zinc-900">
                          {cat?.name || 'Kategori'}
                        </span>
                        <span className="text-xs font-mono font-bold text-blue-400">
                          {formatStopwatch(session.activeSeconds)}
                        </span>
                      </div>
                      <p className="text-[11px] text-zinc-400 light:text-zinc-600 mt-0.5">
                        {new Date(session.startTime).toLocaleDateString('tr-TR', {
                          day: 'numeric',
                          month: 'short',
                          hour: '2-digit',
                          minute: '2-digit',
                        })}
                        {session.breakSeconds > 0 && ` • Mola: ${formatMinutes(session.breakSeconds / 60)}`}
                      </p>
                      {session.note && (
                        <p className="text-[11px] text-zinc-300 light:text-zinc-700 mt-1 italic flex items-center gap-1">
                          <FileText className="w-3 h-3 text-zinc-500" />
                          <span>{session.note}</span>
                        </p>
                      )}
                    </div>
                  </div>

                  <button
                    onClick={() => {
                      if (confirm('Bu oturum kaydını silmek istediğinize emin misiniz?')) {
                        deleteSession(session.id);
                      }
                    }}
                    className="p-1.5 rounded-lg text-zinc-500 hover:text-rose-400 hover:bg-zinc-800 transition-all"
                    title="Oturumu Sil"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Manual Add Session Modal */}
      {isManualModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/75 backdrop-blur-sm">
          <div className="bg-zinc-900 light:bg-zinc-50 border border-zinc-800 light:border-zinc-200 rounded-3xl w-full max-w-sm p-6 shadow-2xl space-y-4">
            <div className="flex items-center justify-between">
              <h2 className="text-base font-bold text-white light:text-zinc-900 font-mono">
                Manuel Oturum Ekle
              </h2>
              <button
                onClick={() => setIsManualModalOpen(false)}
                className="p-1 rounded-full text-zinc-400 hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleAddManualSubmit} className="space-y-4">
              <div>
                <label className="block text-xs font-medium text-zinc-400 mb-1">Kategori</label>
                <select
                  value={manualCatId}
                  onChange={e => setManualCatId(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-zinc-950 light:bg-white border border-zinc-800 light:border-zinc-300 text-xs text-white light:text-zinc-900 focus:outline-none"
                >
                  {categories.filter(c => !c.isArchived).map(cat => (
                    <option key={cat.id} value={cat.id}>
                      {cat.name}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-xs font-medium text-zinc-400 mb-1">
                  Çalışma Süresi (Dakika)
                </label>
                <input
                  type="number"
                  min="1"
                  max="720"
                  value={manualDurationMins}
                  onChange={e => setManualDurationMins(parseInt(e.target.value) || 0)}
                  className="w-full px-3 py-2 rounded-xl bg-zinc-950 light:bg-white border border-zinc-800 light:border-zinc-300 text-sm font-mono text-white light:text-zinc-900 focus:outline-none"
                />
              </div>

              <div>
                <label className="block text-xs font-medium text-zinc-400 mb-1">
                  Mola Süresi (Dakika)
                </label>
                <input
                  type="number"
                  min="0"
                  max="120"
                  value={manualBreakMins}
                  onChange={e => setManualBreakMins(parseInt(e.target.value) || 0)}
                  className="w-full px-3 py-2 rounded-xl bg-zinc-950 light:bg-white border border-zinc-800 light:border-zinc-300 text-sm font-mono text-white light:text-zinc-900 focus:outline-none"
                />
              </div>

              <div>
                <label className="block text-xs font-medium text-zinc-400 mb-1">
                  Oturum Notu (İsteğe Bağlı)
                </label>
                <input
                  type="text"
                  placeholder="Örn: Noise Figure soruları"
                  value={manualNote}
                  onChange={e => setManualNote(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-zinc-950 light:bg-white border border-zinc-800 light:border-zinc-300 text-xs text-white light:text-zinc-900 focus:outline-none"
                />
              </div>

              <div className="flex items-center justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setIsManualModalOpen(false)}
                  className="px-4 py-2 rounded-xl text-xs font-semibold text-zinc-400 hover:text-white"
                >
                  İptal
                </button>
                <button
                  type="submit"
                  className="px-5 py-2 rounded-xl bg-blue-600 hover:bg-blue-500 text-white text-xs font-bold"
                >
                  Kaydet
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
