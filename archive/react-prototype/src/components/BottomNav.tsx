import React from 'react';
import { useTempo, ActiveTab } from '../context/TempoContext.tsx';
import { formatStopwatch } from '../engine/timeEngine.ts';
import { Calendar, Layers, Droplets, BarChart3, Play, Pause, Maximize2, Coffee } from 'lucide-react';
import { CategoryIcon } from './IconHelper.tsx';

export const BottomNav: React.FC = () => {
  const {
    activeTab,
    setActiveTab,
    activeSession,
    categories,
    pauseSession,
    resumeSession,
    setIsFocusModalOpen,
  } = useTempo();

  const activeCategory = activeSession
    ? categories.find(c => c.id === activeSession.categoryId)
    : null;

  const tabs: { id: ActiveTab; label: string; icon: React.ComponentType<{ className?: string }> }[] = [
    { id: 'today', label: 'Bugün', icon: Calendar },
    { id: 'budgets', label: 'Bütçeler', icon: Layers },
    { id: 'pool', label: 'Havuz', icon: Droplets },
    { id: 'analytics', label: 'Analiz', icon: BarChart3 },
  ];

  return (
    <div className="fixed bottom-0 left-0 right-0 z-40 max-w-md mx-auto pointer-events-none">
      {/* Active Session Sticky Mini-Bar (if session exists) */}
      {activeSession && (
        <div className="px-3 pb-2 pointer-events-auto">
          <div
            onClick={() => setIsFocusModalOpen(true)}
            className="flex items-center justify-between px-4 py-2.5 rounded-2xl bg-zinc-900/95 light:bg-zinc-100/95 border border-zinc-700/80 light:border-zinc-300 shadow-2xl backdrop-blur-xl cursor-pointer hover:border-blue-500/50 transition-all group"
          >
            <div className="flex items-center gap-3 min-w-0">
              <div
                className="w-9 h-9 rounded-xl flex items-center justify-center shrink-0 shadow-sm"
                style={{ backgroundColor: `${activeCategory?.color || '#3b82f6'}25`, color: activeCategory?.color || '#3b82f6' }}
              >
                {activeSession.state === 'on_break' ? (
                  <Coffee className="w-5 h-5 text-amber-400 animate-pulse" />
                ) : (
                  <CategoryIcon name={activeCategory?.icon || 'sparkles'} className="w-5 h-5" />
                )}
              </div>
              <div className="min-w-0">
                <div className="flex items-center gap-2">
                  <p className="text-xs font-bold text-white light:text-zinc-900 truncate">
                    {activeCategory?.name || 'Oturum'}
                  </p>
                  <span
                    className={`text-[9px] uppercase px-1.5 py-0.2 rounded font-mono font-semibold ${
                      activeSession.state === 'on_break'
                        ? 'bg-amber-500/20 text-amber-400'
                        : activeSession.state === 'paused'
                        ? 'bg-zinc-800 text-zinc-400'
                        : 'bg-emerald-500/20 text-emerald-400'
                    }`}
                  >
                    {activeSession.state === 'on_break'
                      ? 'MOLA'
                      : activeSession.state === 'paused'
                      ? 'DURAKLADI'
                      : 'ODAKTA'}
                  </span>
                </div>
                <p className="text-sm font-mono font-bold text-zinc-100 light:text-zinc-900 tracking-wider">
                  {formatStopwatch(
                    activeSession.state === 'on_break'
                      ? activeSession.breakSeconds
                      : activeSession.activeSeconds
                  )}
                </p>
              </div>
            </div>

            {/* Quick Controls */}
            <div className="flex items-center gap-1.5" onClick={e => e.stopPropagation()}>
              {activeSession.state === 'running' ? (
                <button
                  onClick={pauseSession}
                  className="w-8 h-8 rounded-full bg-zinc-800 hover:bg-zinc-700 light:bg-zinc-200 light:hover:bg-zinc-300 text-white light:text-zinc-900 flex items-center justify-center transition-all active:scale-90"
                  title="Duraklat"
                >
                  <Pause className="w-4 h-4 fill-current" />
                </button>
              ) : activeSession.state === 'paused' ? (
                <button
                  onClick={resumeSession}
                  className="w-8 h-8 rounded-full bg-blue-600 hover:bg-blue-500 text-white flex items-center justify-center transition-all active:scale-90"
                  title="Devam Et"
                >
                  <Play className="w-4 h-4 fill-current ml-0.5" />
                </button>
              ) : null}

              <button
                onClick={() => setIsFocusModalOpen(true)}
                className="w-8 h-8 rounded-full bg-zinc-800/80 hover:bg-zinc-700 light:bg-zinc-200 light:hover:bg-zinc-300 text-zinc-300 light:text-zinc-700 flex items-center justify-center transition-all active:scale-90"
                title="Tam Ekrana Genişlet"
              >
                <Maximize2 className="w-4 h-4" />
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Bottom Nav Bar */}
      <nav className="pointer-events-auto bg-zinc-950/95 light:bg-zinc-50/95 backdrop-blur-xl border-t border-zinc-800/90 light:border-zinc-200 px-3 py-2 flex items-center justify-around safe-area-pb">
        {tabs.map(tab => {
          const Icon = tab.icon;
          const isActive = activeTab === tab.id;
          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`flex flex-col items-center justify-center py-1 px-3 rounded-xl transition-all active:scale-95 ${
                isActive
                  ? 'text-blue-500 font-semibold'
                  : 'text-zinc-500 hover:text-zinc-300 light:text-zinc-400 light:hover:text-zinc-700'
              }`}
            >
              <div className="relative">
                <Icon className={`w-5 h-5 transition-transform ${isActive ? 'scale-110' : ''}`} />
                {tab.id === 'pool' && (
                  <span className="absolute -top-1 -right-1 w-2 h-2 rounded-full bg-blue-500 animate-ping"></span>
                )}
              </div>
              <span className="text-[11px] mt-1 font-medium">{tab.label}</span>
            </button>
          );
        })}
      </nav>
    </div>
  );
};
