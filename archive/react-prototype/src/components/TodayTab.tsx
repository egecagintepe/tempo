import React from 'react';
import { useTempo } from '../context/TempoContext.tsx';
import { formatMinutes } from '../engine/timeEngine.ts';
import { Play, Sparkles, AlertCircle, ArrowUpRight, Flame, ShieldAlert, CheckCircle2 } from 'lucide-react';
import { CategoryIcon } from './IconHelper.tsx';

export const TodayTab: React.FC = () => {
  const {
    categories,
    weeklyTotals,
    getCategoryTotals,
    startSession,
    setActiveTab,
    setIsFocusModalOpen,
    activeSession,
  } = useTempo();

  // Day of week in Turkey (1=Mon ... 7=Sun)
  const currentDayIndex = (() => {
    const d = new Date().getDay();
    return d === 0 ? 7 : d;
  })();

  const dayNames = ['', 'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
  const todayName = dayNames[currentDayIndex];

  // Scheduled categories for today
  const todayScheduledCategories = categories.filter(
    c => !c.isArchived && c.scheduledDays && c.scheduledDays.includes(currentDayIndex)
  );

  // Quick launch top active categories (unarchived, sorted by priority)
  const activeCategories = categories
    .filter(c => !c.isArchived)
    .sort((a, b) => a.priorityOrder - b.priorityOrder);

  const handleQuickStart = (catId: string) => {
    if (activeSession && activeSession.categoryId === catId) {
      setIsFocusModalOpen(true);
      return;
    }
    const result = startSession(catId);
    if (!result.success && result.error) {
      alert(result.error);
    }
  };

  return (
    <div className="space-y-6 pb-28 pt-2">
      {/* Slogan Banner */}
      <div className="flex items-center justify-between px-1">
        <div>
          <span className="text-[10px] font-mono tracking-widest text-blue-400 font-bold uppercase">
            TEMPO OS • KİŞİSEL ZAMAN BÜTÇESİ
          </span>
          <h1 className="text-2xl font-black tracking-tight text-white light:text-zinc-900 mt-0.5">
            Own your hours.
          </h1>
          <p className="text-xs text-zinc-400 light:text-zinc-600 mt-1">
            "Her şeyi bitirmek zorunda değilsin. Zamanını bilinçli seç."
          </p>
        </div>
        <div className="w-10 h-10 rounded-2xl bg-gradient-to-tr from-blue-600 to-indigo-500 flex items-center justify-center text-white shadow-lg shadow-blue-500/20">
          <Flame className="w-5 h-5 fill-current" />
        </div>
      </div>

      {/* Hero Weekly Budget Card */}
      <div className="relative overflow-hidden rounded-3xl bg-gradient-to-b from-zinc-900 via-zinc-900/90 to-zinc-950 light:from-white light:to-zinc-50 border border-zinc-800 light:border-zinc-200 p-5 shadow-xl">
        <div className="flex items-center justify-between mb-4">
          <span className="text-xs font-mono font-bold tracking-wider uppercase text-zinc-400 light:text-zinc-600">
            HAFTALIK KAPASİTE
          </span>
          <span className="text-xs font-mono font-bold px-2 py-0.5 rounded-full bg-blue-500/10 text-blue-400 border border-blue-500/20">
            %{weeklyTotals.progressPercent} KULLANILDI
          </span>
        </div>

        {/* Big Progress Numbers */}
        <div className="grid grid-cols-3 gap-2 py-2 border-y border-zinc-800/80 light:border-zinc-200">
          <div>
            <p className="text-[10px] font-mono uppercase tracking-wider text-zinc-500">BÜTÇE</p>
            <p className="text-xl font-mono font-black text-white light:text-zinc-900 mt-0.5">
              {formatMinutes(weeklyTotals.totalBudgetMinutes)}
            </p>
          </div>
          <div>
            <p className="text-[10px] font-mono uppercase tracking-wider text-blue-400">HARCANAN</p>
            <p className="text-xl font-mono font-black text-blue-400 mt-0.5">
              {formatMinutes(weeklyTotals.totalSpentMinutes)}
            </p>
          </div>
          <div>
            <p className="text-[10px] font-mono uppercase tracking-wider text-emerald-400">KALAN</p>
            <p className="text-xl font-mono font-black text-emerald-400 mt-0.5">
              {formatMinutes(weeklyTotals.totalRemainingMinutes)}
            </p>
          </div>
        </div>

        {/* Progress Bar Visual */}
        <div className="mt-4 space-y-1.5">
          <div className="w-full h-3 rounded-full bg-zinc-800 light:bg-zinc-200 overflow-hidden p-0.5 flex">
            <div
              className="h-full rounded-full bg-gradient-to-r from-blue-500 via-indigo-500 to-emerald-400 transition-all duration-500"
              style={{ width: `${Math.min(100, weeklyTotals.progressPercent)}%` }}
            />
          </div>
          <div className="flex items-center justify-between text-[11px] text-zinc-400 font-mono">
            <span>0s</span>
            <span>Kapasite: {formatMinutes(weeklyTotals.totalBudgetMinutes)}</span>
          </div>
        </div>
      </div>

      {/* Today's Scheduled Focus (Bugünün Planı) */}
      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <span className="w-2 h-2 rounded-full bg-blue-500"></span>
            <h2 className="text-sm font-bold tracking-tight text-white light:text-zinc-900 uppercase font-mono">
              Bugünün Planı ({todayName})
            </h2>
          </div>
          <span className="text-[11px] text-zinc-500">Haftalık rehber</span>
        </div>

        {todayScheduledCategories.length === 0 ? (
          <div className="p-4 rounded-2xl bg-zinc-900/50 light:bg-zinc-100 border border-zinc-800/60 light:border-zinc-200 text-center">
            <p className="text-xs text-zinc-400 light:text-zinc-600">
              Bugün için sabitlenmiş ders/görev yok. Dilediğin kategoriye odaklanabilirsin.
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-1 gap-2.5">
            {todayScheduledCategories.map(cat => {
              const totals = getCategoryTotals(cat.id);
              return (
                <div
                  key={cat.id}
                  className="p-3.5 rounded-2xl bg-zinc-900/80 light:bg-zinc-100 border border-zinc-800 light:border-zinc-200 flex items-center justify-between hover:border-zinc-700 transition-all"
                >
                  <div className="flex items-center gap-3">
                    <div
                      className="w-10 h-10 rounded-xl flex items-center justify-center shrink-0"
                      style={{ backgroundColor: `${cat.color}20`, color: cat.color }}
                    >
                      <CategoryIcon name={cat.icon} className="w-5 h-5" />
                    </div>
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="font-bold text-sm text-white light:text-zinc-900">
                          {cat.name}
                        </span>
                        {cat.policy === 'strict' && (
                          <span className="text-[9px] font-mono px-1.5 py-0.2 rounded bg-rose-500/20 text-rose-400 font-semibold">
                            KATI
                          </span>
                        )}
                        {cat.policy === 'protected' && (
                          <span className="text-[9px] font-mono px-1.5 py-0.2 rounded bg-purple-500/20 text-purple-400 font-semibold">
                            KORUNAN
                          </span>
                        )}
                      </div>
                      <p className="text-xs text-zinc-400 light:text-zinc-600 mt-0.5 font-mono">
                        Kalan: <strong className="text-emerald-400">{formatMinutes(totals.remainingMinutes)}</strong> / Hedef: {formatMinutes(totals.effectiveTargetMinutes)}
                      </p>
                    </div>
                  </div>

                  <button
                    onClick={() => handleQuickStart(cat.id)}
                    className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-blue-600 hover:bg-blue-500 text-white font-semibold text-xs transition-all shadow-md active:scale-95"
                  >
                    <Play className="w-3.5 h-3.5 fill-current" />
                    <span>Başlat</span>
                  </button>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Quick Launch Categories (Hızlı Başlatma) */}
      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <span className="w-2 h-2 rounded-full bg-emerald-500"></span>
            <h2 className="text-sm font-bold tracking-tight text-white light:text-zinc-900 uppercase font-mono">
              Kategoriler & Hızlı Başlat
            </h2>
          </div>
          <button
            onClick={() => setActiveTab('budgets')}
            className="text-xs text-blue-400 hover:text-blue-300 font-medium flex items-center gap-1 active:underline"
          >
            <span>Tümünü Gör ({categories.filter(c => !c.isArchived).length})</span>
            <ArrowUpRight className="w-3.5 h-3.5" />
          </button>
        </div>

        <div className="grid grid-cols-2 gap-2.5">
          {activeCategories.slice(0, 6).map(cat => {
            const totals = getCategoryTotals(cat.id);
            const isRunningThis = activeSession?.categoryId === cat.id;

            return (
              <div
                key={cat.id}
                onClick={() => handleQuickStart(cat.id)}
                className={`p-3 rounded-2xl border transition-all cursor-pointer relative overflow-hidden group active:scale-[0.98] ${
                  isRunningThis
                    ? 'bg-blue-950/40 border-blue-500/80 shadow-lg shadow-blue-500/10'
                    : 'bg-zinc-900/60 light:bg-zinc-100 hover:bg-zinc-900 border-zinc-800/80 light:border-zinc-200 hover:border-zinc-700'
                }`}
              >
                {/* Accent top stripe */}
                <div
                  className="absolute top-0 left-0 right-0 h-1"
                  style={{ backgroundColor: cat.color }}
                />

                <div className="flex items-center justify-between mb-2">
                  <div
                    className="w-8 h-8 rounded-lg flex items-center justify-center"
                    style={{ backgroundColor: `${cat.color}25`, color: cat.color }}
                  >
                    <CategoryIcon name={cat.icon} className="w-4 h-4" />
                  </div>
                  <span
                    className={`w-6 h-6 rounded-full flex items-center justify-center transition-transform group-hover:scale-110 ${
                      isRunningThis
                        ? 'bg-blue-500 text-white'
                        : 'bg-zinc-800 light:bg-zinc-200 text-zinc-300 light:text-zinc-700 group-hover:bg-blue-600 group-hover:text-white'
                    }`}
                  >
                    <Play className="w-3 h-3 fill-current ml-0.5" />
                  </span>
                </div>

                <h3 className="font-bold text-xs text-white light:text-zinc-900 truncate">
                  {cat.name}
                </h3>

                <div className="flex items-center justify-between text-[11px] font-mono mt-2 text-zinc-400">
                  <span>Kalan:</span>
                  <span
                    className={`font-bold ${
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

                {/* Mini progress bar */}
                <div className="w-full h-1.5 rounded-full bg-zinc-800 light:bg-zinc-200 mt-2 overflow-hidden">
                  <div
                    className="h-full rounded-full transition-all"
                    style={{
                      width: `${totals.progressPercent}%`,
                      backgroundColor: cat.color,
                    }}
                  />
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Tempo Core Principle Quote Card */}
      <div className="p-4 rounded-2xl bg-zinc-900/40 light:bg-zinc-100 border border-zinc-800/60 light:border-zinc-200">
        <div className="flex items-start gap-3">
          <Sparkles className="w-5 h-5 text-amber-400 shrink-0 mt-0.5" />
          <div className="text-xs text-zinc-300 light:text-zinc-700 space-y-1">
            <p className="font-semibold text-white light:text-zinc-900">
              Zaman Bütçelerinin Birbirinden Korunması
            </p>
            <p className="text-zinc-400 light:text-zinc-600 text-[11px] leading-relaxed">
              Bir kategoriye ayrılan süre başka bir kategoriden rastgele çalınamaz. İşini erken bitirdiysen kalan süreyi Serbest Havuz'a aktarabilir ve bilinçli dağıtabilirsin.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};
