import React from 'react';
import { useTempo } from '../context/TempoContext.tsx';
import { formatStopwatch, formatMinutes } from '../engine/timeEngine.ts';
import { Settings, Droplets, Smartphone, Monitor, HelpCircle } from 'lucide-react';

export const Header: React.FC = () => {
  const {
    poolBalance,
    currentWeek,
    setIsSettingsOpen,
    setIsOnboardingOpen,
    setActiveTab,
    deviceFrameMode,
    setDeviceFrameMode,
    activeSession,
    categories,
  } = useTempo();

  const todayDateStr = new Intl.DateTimeFormat('tr-TR', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
  }).format(new Date());

  const activeCat = activeSession ? categories.find(c => c.id === activeSession.categoryId) : null;

  return (
    <header className="sticky top-0 z-30 bg-zinc-950/85 dark:bg-zinc-950/90 light:bg-zinc-50/90 backdrop-blur-md border-b border-zinc-800/80 light:border-zinc-200 px-4 py-3 transition-colors">
      <div className="flex items-center justify-between">
        {/* Brand & Date */}
        <div>
          <div className="flex items-center gap-2">
            <span className="font-extrabold text-xl tracking-tight text-white light:text-zinc-900 font-mono">
              TEMPO<span className="text-blue-500">.</span>
            </span>
            <span className="text-[10px] tracking-wider uppercase font-semibold text-zinc-400 bg-zinc-800/80 light:bg-zinc-200 light:text-zinc-700 px-2 py-0.5 rounded-full">
              OS
            </span>
            {activeSession && (
              <span className="flex items-center gap-1.5 text-[11px] font-mono text-emerald-400 bg-emerald-950/70 border border-emerald-800/60 px-2 py-0.5 rounded-full animate-pulse">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-ping"></span>
                {activeCat?.name}: {formatStopwatch(activeSession.activeSeconds, false)}
              </span>
            )}
          </div>
          <p className="text-xs text-zinc-400 light:text-zinc-600 capitalize mt-0.5 font-medium">
            {todayDateStr} • {currentWeek.id.replace('-W', '. Hafta ')}
          </p>
        </div>

        {/* Right Action Icons */}
        <div className="flex items-center gap-2">
          {/* Free Time Pool Quick Button */}
          <button
            onClick={() => setActiveTab('pool')}
            className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg bg-blue-500/15 hover:bg-blue-500/25 border border-blue-500/30 text-blue-400 transition-all text-xs font-mono font-medium shadow-sm active:scale-95"
            title="Serbest Zaman Havuzu"
          >
            <Droplets className="w-3.5 h-3.5 text-blue-400 animate-bounce" />
            <span className="font-semibold">{formatMinutes(poolBalance.balanceMinutes)}</span>
          </button>

          {/* Device Frame Viewport Toggle */}
          <button
            onClick={() => setDeviceFrameMode(prev => !prev)}
            className="p-1.5 rounded-lg text-zinc-400 hover:text-zinc-200 light:text-zinc-600 light:hover:text-zinc-900 hover:bg-zinc-800/60 light:hover:bg-zinc-200 transition-all active:scale-95"
            title={deviceFrameMode ? 'Tam Genişlik Görünüme Geç' : 'Mobil Çerçeve Görünümüne Geç'}
          >
            {deviceFrameMode ? <Monitor className="w-4 h-4" /> : <Smartphone className="w-4 h-4" />}
          </button>

          {/* Guide / Onboarding */}
          <button
            onClick={() => setIsOnboardingOpen(true)}
            className="p-1.5 rounded-lg text-zinc-400 hover:text-zinc-200 light:text-zinc-600 light:hover:text-zinc-900 hover:bg-zinc-800/60 light:hover:bg-zinc-200 transition-all active:scale-95"
            title="Kılavuz ve Felsefe"
          >
            <HelpCircle className="w-4 h-4" />
          </button>

          {/* Settings */}
          <button
            onClick={() => setIsSettingsOpen(true)}
            className="p-1.5 rounded-lg text-zinc-400 hover:text-zinc-200 light:text-zinc-600 light:hover:text-zinc-900 hover:bg-zinc-800/60 light:hover:bg-zinc-200 transition-all active:scale-95"
            title="Ayarlar"
          >
            <Settings className="w-4 h-4" />
          </button>
        </div>
      </div>
    </header>
  );
};
