/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 * TEMPO — Personal Time Budget OS
 */

import React from 'react';
import { TempoProvider, useTempo } from './context/TempoContext.tsx';
import { Header } from './components/Header.tsx';
import { BottomNav } from './components/BottomNav.tsx';
import { TodayTab } from './components/TodayTab.tsx';
import { BudgetsTab } from './components/BudgetsTab.tsx';
import { PoolTab } from './components/PoolTab.tsx';
import { AnalyticsTab } from './components/AnalyticsTab.tsx';
import { FocusTimerModal } from './components/FocusTimerModal.tsx';
import { SettingsModal } from './components/SettingsModal.tsx';
import { OnboardingModal } from './components/OnboardingModal.tsx';

const AppContent: React.FC = () => {
  const { activeTab, deviceFrameMode } = useTempo();

  return (
    <div className="min-h-screen bg-zinc-950 light:bg-zinc-100 text-zinc-100 light:text-zinc-900 transition-colors flex items-center justify-center p-0 sm:p-4">
      {/* Outer Shell - supports mobile phone frame or wide responsive */}
      <div
        className={`w-full transition-all duration-300 relative flex flex-col ${
          deviceFrameMode
            ? 'max-w-[420px] min-h-[880px] h-[92vh] sm:rounded-[40px] border-0 sm:border-8 sm:border-zinc-800/80 shadow-[0_25px_60px_-15px_rgba(0,0,0,0.8)] overflow-hidden bg-black'
            : 'max-w-2xl min-h-screen sm:rounded-3xl border-0 sm:border border-zinc-800 bg-zinc-950 light:bg-zinc-50'
        }`}
      >
        {/* Simulated Phone Dynamic Island / Speaker Notch (only in device frame mode) */}
        {deviceFrameMode && (
          <div className="hidden sm:flex items-center justify-center pt-2 pb-1 bg-zinc-950 select-none">
            <div className="w-24 h-4 bg-zinc-900 rounded-full border border-zinc-800 flex items-center justify-end px-2">
              <div className="w-2 h-2 rounded-full bg-blue-500/50" />
            </div>
          </div>
        )}

        {/* Top Header */}
        <Header />

        {/* Scrollable Main Content Area */}
        <main className="flex-1 overflow-y-auto px-4 pt-2 pb-6 no-scrollbar">
          {activeTab === 'today' && <TodayTab />}
          {activeTab === 'budgets' && <BudgetsTab />}
          {activeTab === 'pool' && <PoolTab />}
          {activeTab === 'analytics' && <AnalyticsTab />}
        </main>

        {/* Floating Bottom Nav & Active Session Pill */}
        <BottomNav />

        {/* Global Modals */}
        <FocusTimerModal />
        <SettingsModal />
        <OnboardingModal />
      </div>
    </div>
  );
};

export default function App() {
  return (
    <TempoProvider>
      <AppContent />
    </TempoProvider>
  );
}
