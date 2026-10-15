/**
 * TEMPO — Global Application State & Timer Engine Context
 */

import React, { createContext, useContext, useState, useEffect, useCallback, useMemo } from 'react';
import type {
  Category,
  Task,
  WorkSession,
  PoolTransaction,
  AppSettings,
  BreakSegment,
} from '../types/index.ts';
import {
  getWeekPeriod,
  calculateCategoryTotals,
  calculatePoolBalance,
  validateTransfer,
  canStartSession,
  CategoryTimeTotals,
} from '../engine/timeEngine.ts';
import { storage } from '../services/storage.ts';
import { soundService } from '../services/sound.ts';
import { hapticsService } from '../services/haptics.ts';
import { notificationService } from '../services/notifications.ts';

export type ActiveTab = 'today' | 'budgets' | 'pool' | 'analytics';

interface TempoContextType {
  // State
  categories: Category[];
  tasks: Task[];
  sessions: WorkSession[];
  transactions: PoolTransaction[];
  settings: AppSettings;
  activeSession: WorkSession | null;
  activeTab: ActiveTab;
  currentWeek: { id: string; start: Date; end: Date };
  isFocusModalOpen: boolean;
  isSettingsOpen: boolean;
  isOnboardingOpen: boolean;
  deviceFrameMode: boolean; // Mobile frame 390px vs Responsive
  lastExhaustedWarningCategory: string | null;

  // Navigation
  setActiveTab: (tab: ActiveTab) => void;
  setIsFocusModalOpen: (open: boolean) => void;
  setIsSettingsOpen: (open: boolean) => void;
  setIsOnboardingOpen: (open: boolean) => void;
  setDeviceFrameMode: (enabled: boolean | ((prev: boolean) => boolean)) => void;

  // Category Actions
  addCategory: (category: Omit<Category, 'id' | 'createdAt' | 'updatedAt'>) => void;
  updateCategory: (id: string, updates: Partial<Category>) => void;
  deleteCategory: (id: string) => void;
  markCategoryCompletedForWeek: (id: string, completed: boolean) => void;

  // Task Actions
  addTask: (categoryId: string, title: string, estimatedMinutes?: number) => void;
  toggleTask: (taskId: string) => void;
  deleteTask: (taskId: string) => void;

  // Timer & Session Actions
  startSession: (categoryId: string, taskId?: string) => { success: boolean; error?: string };
  pauseSession: () => void;
  resumeSession: () => void;
  startBreak: (plannedMinutes: number, label?: string) => void;
  endBreak: () => void;
  finishSession: (note?: string) => void;
  discardSession: () => void;
  adjustActiveSessionTime: (deltaSeconds: number) => void;

  // Manual Session Actions (Log historical or edit)
  addManualSession: (session: {
    categoryId: string;
    activeSeconds: number;
    breakSeconds?: number;
    startTime: number;
    note?: string;
  }) => void;
  deleteSession: (id: string) => void;

  // Pool Transfer Actions
  transferToPool: (categoryId: string, minutes: number, note?: string) => { success: boolean; error?: string };
  transferFromPool: (categoryId: string, minutes: number, note?: string) => { success: boolean; error?: string };
  undoTransaction: (transactionId: string) => { success: boolean; error?: string };

  // Settings & Storage Actions
  updateSettings: (updates: Partial<AppSettings>) => void;
  resetAll: () => void;
  importBackup: (jsonString: string) => { success: boolean; error?: string };

  // Computed Helpers
  getCategoryTotals: (categoryId: string) => CategoryTimeTotals;
  poolBalance: {
    balanceMinutes: number;
    addedThisWeekMinutes: number;
    usedThisWeekMinutes: number;
  };
  weeklyTotals: {
    totalBudgetMinutes: number;
    totalSpentMinutes: number;
    totalRemainingMinutes: number;
    progressPercent: number;
  };
}

const TempoContext = createContext<TempoContextType | null>(null);

export const TempoProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [currentWeek] = useState(() => getWeekPeriod());
  const [categories, setCategories] = useState<Category[]>(() => storage.getCategories());
  const [tasks, setTasks] = useState<Task[]>(() => storage.getTasks());
  const [sessions, setSessions] = useState<WorkSession[]>(() => storage.getSessions());
  const [transactions, setTransactions] = useState<PoolTransaction[]>(() => storage.getTransactions());
  const [settings, setSettings] = useState<AppSettings>(() => storage.getSettings());
  const [activeSession, setActiveSession] = useState<WorkSession | null>(() => storage.getActiveSession());

  const [activeTab, setActiveTab] = useState<ActiveTab>('today');
  const [isFocusModalOpen, setIsFocusModalOpen] = useState(false);
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);
  const [isOnboardingOpen, setIsOnboardingOpen] = useState(() => !storage.hasOnboarded());
  const [deviceFrameMode, setDeviceFrameMode] = useState<boolean>(true); // Default to clean mobile phone container
  const [lastExhaustedWarningCategory, setLastExhaustedWarningCategory] = useState<string | null>(null);

  // Sync settings with services
  useEffect(() => {
    soundService.enabled = settings.soundEnabled;
    hapticsService.enabled = settings.vibrationEnabled;
    notificationService.enabled = settings.notificationsEnabled;

    // Apply theme class to document
    const root = document.documentElement;
    root.classList.remove('dark', 'light', 'oled');
    if (settings.theme === 'dark') {
      root.classList.add('dark');
    } else if (settings.theme === 'oled') {
      root.classList.add('dark', 'oled');
    } else if (settings.theme === 'light') {
      root.classList.add('light');
    } else {
      // system
      if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
        root.classList.add('dark');
      } else {
        root.classList.add('light');
      }
    }
  }, [settings]);

  // Save changes to localStorage
  useEffect(() => {
    storage.saveCategories(categories);
  }, [categories]);

  useEffect(() => {
    storage.saveTasks(tasks);
  }, [tasks]);

  useEffect(() => {
    storage.saveSessions(sessions);
  }, [sessions]);

  useEffect(() => {
    storage.saveTransactions(transactions);
  }, [transactions]);

  useEffect(() => {
    storage.saveSettings(settings);
  }, [settings]);

  useEffect(() => {
    storage.saveActiveSession(activeSession);
  }, [activeSession]);

  // Helper to compute category totals
  const getCategoryTotals = useCallback(
    (categoryId: string): CategoryTimeTotals => {
      const category = categories.find(c => c.id === categoryId);
      if (!category) {
        return {
          categoryId,
          initialTargetMinutes: 0,
          transferredInMinutes: 0,
          transferredOutMinutes: 0,
          effectiveTargetMinutes: 0,
          effectiveTargetSeconds: 0,
          spentSeconds: 0,
          spentMinutes: 0,
          remainingSeconds: 0,
          remainingMinutes: 0,
          progressPercent: 0,
          isExhausted: true,
          isOverBudget: false,
          overBudgetSeconds: 0,
          sessionCount: 0,
        };
      }
      const activeSessionSeconds =
        activeSession && activeSession.categoryId === categoryId && activeSession.state === 'running'
          ? 0 // activeSeconds is already ticked into activeSession
          : 0;

      return calculateCategoryTotals(category, sessions, transactions, currentWeek.id, activeSessionSeconds);
    },
    [categories, sessions, transactions, currentWeek.id, activeSession]
  );

  // Pool balance calculation
  const poolBalance = useMemo(() => {
    return calculatePoolBalance(transactions, currentWeek.id);
  }, [transactions, currentWeek.id]);

  // Overall weekly totals
  const weeklyTotals = useMemo(() => {
    let totalBudgetMinutes = 0;
    let totalSpentMinutes = 0;

    for (const cat of categories.filter(c => !c.isArchived)) {
      const totals = calculateCategoryTotals(cat, sessions, transactions, currentWeek.id);
      totalBudgetMinutes += totals.effectiveTargetMinutes;
      totalSpentMinutes += totals.spentMinutes;
    }

    const totalRemainingMinutes = Math.max(0, totalBudgetMinutes - totalSpentMinutes);
    const progressPercent = totalBudgetMinutes > 0
      ? Math.min(100, Math.round((totalSpentMinutes / totalBudgetMinutes) * 100))
      : 0;

    return {
      totalBudgetMinutes,
      totalSpentMinutes,
      totalRemainingMinutes,
      progressPercent,
    };
  }, [categories, sessions, transactions, currentWeek.id]);

  // 1-second Interval Timer Heartbeat
  useEffect(() => {
    if (!activeSession) return;
    if (activeSession.state !== 'running' && activeSession.state !== 'on_break') return;

    const interval = setInterval(() => {
      setActiveSession(prev => {
        if (!prev) return null;

        if (prev.state === 'running') {
          const newActiveSec = prev.activeSeconds + 1;
          const currentCat = categories.find(c => c.id === prev.categoryId);

          if (currentCat) {
            // Check totals with the new active second
            const tempSession: WorkSession = {
              ...prev,
              activeSeconds: newActiveSec,
            };
            const updatedSessions = [...sessions.filter(s => s.id !== prev.id), tempSession];
            const updatedTotals = calculateCategoryTotals(
              currentCat,
              updatedSessions,
              transactions,
              currentWeek.id
            );

            // Warning thresholds: 15 min (900s), 5 min (300s), 1 min (60s)
            if (settings.smartWarning80 && updatedTotals.remainingSeconds === 900) {
              soundService.playWarning();
              hapticsService.light();
              notificationService.notify(
                'TEMPO — Bütçe Uyarısı',
                `${currentCat.name}: Kalan bütçe 15 dakika.`
              );
            } else if (settings.smartWarning95 && updatedTotals.remainingSeconds === 300) {
              soundService.playWarning();
              hapticsService.medium();
              notificationService.notify(
                'TEMPO — Bütçe Uyarısı',
                `${currentCat.name}: Son 5 dakikanız kaldı!`
              );
            } else if (updatedTotals.remainingSeconds === 60) {
              soundService.playWarning();
              hapticsService.heavy();
            }

            // Budget Exhausted check
            if (updatedTotals.remainingSeconds <= 0 && lastExhaustedWarningCategory !== currentCat.id) {
              setLastExhaustedWarningCategory(currentCat.id);
              soundService.playExhaustedAlarm();
              hapticsService.alarm();
              notificationService.notify(
                'TEMPO — Bütçe Tamamlandı',
                `${currentCat.name} için bu haftalık süreni tamamladın.`
              );

              // If strict budget: automatically transition to paused or finish boundary
              if (currentCat.policy === 'strict') {
                return {
                  ...prev,
                  activeSeconds: newActiveSec,
                  state: 'paused',
                  updatedAt: new Date().toISOString(),
                };
              }
            }
          }

          return {
            ...prev,
            activeSeconds: newActiveSec,
            updatedAt: new Date().toISOString(),
          };
        } else if (prev.state === 'on_break') {
          const newBreakSec = prev.breakSeconds + 1;
          const currentBreak = prev.breaks[prev.breaks.length - 1];

          // Check if break finished
          if (currentBreak && newBreakSec >= currentBreak.plannedMinutes * 60) {
            if (newBreakSec === currentBreak.plannedMinutes * 60) {
              soundService.playFinish();
              hapticsService.heavy();
              notificationService.notify(
                'TEMPO — Mola Bitti',
                'Molanız sona erdi. Çalışmaya dönme zamanı!'
              );
            }
          }

          return {
            ...prev,
            breakSeconds: newBreakSec,
            updatedAt: new Date().toISOString(),
          };
        }

        return prev;
      });
    }, 1000);

    return () => clearInterval(interval);
  }, [
    activeSession?.state,
    categories,
    sessions,
    transactions,
    currentWeek.id,
    settings,
    lastExhaustedWarningCategory,
  ]);

  // Session Control Handlers
  const startSession = useCallback(
    (categoryId: string, taskId?: string): { success: boolean; error?: string } => {
      const category = categories.find(c => c.id === categoryId);
      if (!category) return { success: false, error: 'Kategori bulunamadı.' };

      const totals = getCategoryTotals(categoryId);
      const check = canStartSession(category, totals);
      if (!check.allowed) {
        soundService.playWarning();
        hapticsService.medium();
        return { success: false, error: check.reason };
      }

      // If already running this or another session, finish or confirm
      const now = Date.now();
      const newSession: WorkSession = {
        id: `sess-${now}-${Math.random().toString(36).substring(2, 7)}`,
        categoryId,
        taskId,
        startTime: now,
        state: 'running',
        activeSeconds: 0,
        pauseSeconds: 0,
        breakSeconds: 0,
        segments: [{ id: `seg-${now}`, type: 'work', startTime: now, durationSeconds: 0 }],
        breaks: [],
        weekPeriodId: currentWeek.id,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      setActiveSession(newSession);
      setIsFocusModalOpen(true);
      setLastExhaustedWarningCategory(null);
      soundService.playStart();
      hapticsService.medium();
      return { success: true };
    },
    [categories, getCategoryTotals, currentWeek.id]
  );

  const pauseSession = useCallback(() => {
    if (!activeSession || activeSession.state !== 'running') return;
    setActiveSession(prev => {
      if (!prev) return null;
      return {
        ...prev,
        state: 'paused',
        updatedAt: new Date().toISOString(),
      };
    });
    soundService.playPause();
    hapticsService.light();
  }, [activeSession]);

  const resumeSession = useCallback(() => {
    if (!activeSession) return;
    const cat = categories.find(c => c.id === activeSession.categoryId);
    if (cat) {
      const totals = getCategoryTotals(cat.id);
      if (cat.policy === 'strict' && totals.isExhausted) {
        soundService.playWarning();
        hapticsService.medium();
        return;
      }
    }
    setActiveSession(prev => {
      if (!prev) return null;
      return {
        ...prev,
        state: 'running',
        updatedAt: new Date().toISOString(),
      };
    });
    soundService.playStart();
    hapticsService.light();
  }, [activeSession, categories, getCategoryTotals]);

  const startBreak = useCallback(
    (plannedMinutes: number, label: string = 'Kısa Mola') => {
      if (!activeSession) return;
      const now = Date.now();
      const newBreak: BreakSegment = {
        id: `brk-${now}`,
        startTime: now,
        plannedMinutes,
        actualDurationSeconds: 0,
        label,
      };
      setActiveSession(prev => {
        if (!prev) return null;
        return {
          ...prev,
          state: 'on_break',
          breaks: [...prev.breaks, newBreak],
          updatedAt: new Date().toISOString(),
        };
      });
      soundService.playPause();
      hapticsService.medium();
    },
    [activeSession]
  );

  const endBreak = useCallback(() => {
    if (!activeSession || activeSession.state !== 'on_break') return;
    setActiveSession(prev => {
      if (!prev) return null;
      return {
        ...prev,
        state: 'running',
        updatedAt: new Date().toISOString(),
      };
    });
    soundService.playStart();
    hapticsService.medium();
  }, [activeSession]);

  const finishSession = useCallback(
    (note?: string) => {
      if (!activeSession) return;
      const now = Date.now();
      const completedSession: WorkSession = {
        ...activeSession,
        endTime: now,
        state: 'idle',
        note: note || activeSession.note,
        updatedAt: new Date().toISOString(),
      };

      setSessions(prev => [completedSession, ...prev]);
      setActiveSession(null);
      setIsFocusModalOpen(false);
      soundService.playFinish();
      hapticsService.heavy();
    },
    [activeSession]
  );

  const discardSession = useCallback(() => {
    setActiveSession(null);
    setIsFocusModalOpen(false);
    hapticsService.light();
  }, []);

  const adjustActiveSessionTime = useCallback((deltaSeconds: number) => {
    setActiveSession(prev => {
      if (!prev) return null;
      const newActive = Math.max(0, prev.activeSeconds + deltaSeconds);
      return { ...prev, activeSeconds: newActive, updatedAt: new Date().toISOString() };
    });
  }, []);

  // Category Operations
  const addCategory = useCallback((categoryData: Omit<Category, 'id' | 'createdAt' | 'updatedAt'>) => {
    const now = new Date().toISOString();
    const newCategory: Category = {
      ...categoryData,
      id: `cat-${Date.now()}-${Math.random().toString(36).substring(2, 6)}`,
      createdAt: now,
      updatedAt: now,
    };
    setCategories(prev => [...prev, newCategory]);
    soundService.playTap();
  }, []);

  const updateCategory = useCallback((id: string, updates: Partial<Category>) => {
    setCategories(prev =>
      prev.map(c => (c.id === id ? { ...c, ...updates, updatedAt: new Date().toISOString() } : c))
    );
  }, []);

  const deleteCategory = useCallback((id: string) => {
    // Soft delete/archive to preserve historic logs
    setCategories(prev =>
      prev.map(c => (c.id === id ? { ...c, isArchived: true, updatedAt: new Date().toISOString() } : c))
    );
  }, []);

  const markCategoryCompletedForWeek = useCallback((id: string, completed: boolean) => {
    setCategories(prev =>
      prev.map(c => (c.id === id ? { ...c, isCompletedForWeek: completed, updatedAt: new Date().toISOString() } : c))
    );
  }, []);

  // Task Operations
  const addTask = useCallback((categoryId: string, title: string, estimatedMinutes?: number) => {
    const newTask: Task = {
      id: `task-${Date.now()}`,
      categoryId,
      title,
      estimatedMinutes,
      isCompleted: false,
      createdAt: new Date().toISOString(),
    };
    setTasks(prev => [...prev, newTask]);
    soundService.playTap();
  }, []);

  const toggleTask = useCallback((taskId: string) => {
    setTasks(prev =>
      prev.map(t => (t.id === taskId ? { ...t, isCompleted: !t.isCompleted } : t))
    );
    hapticsService.light();
  }, []);

  const deleteTask = useCallback((taskId: string) => {
    setTasks(prev => prev.filter(t => t.id !== taskId));
  }, []);

  // Manual Session operations
  const addManualSession = useCallback(
    (params: {
      categoryId: string;
      activeSeconds: number;
      breakSeconds?: number;
      startTime: number;
      note?: string;
    }) => {
      const now = new Date().toISOString();
      const newSession: WorkSession = {
        id: `sess-manual-${Date.now()}`,
        categoryId: params.categoryId,
        startTime: params.startTime,
        endTime: params.startTime + (params.activeSeconds + (params.breakSeconds || 0)) * 1000,
        state: 'idle',
        activeSeconds: params.activeSeconds,
        pauseSeconds: 0,
        breakSeconds: params.breakSeconds || 0,
        note: params.note,
        segments: [],
        breaks: [],
        weekPeriodId: currentWeek.id,
        createdAt: now,
        updatedAt: now,
      };
      setSessions(prev => [newSession, ...prev]);
      soundService.playTap();
    },
    [currentWeek.id]
  );

  const deleteSession = useCallback((id: string) => {
    setSessions(prev => prev.filter(s => s.id !== id));
  }, []);

  // Free Time Pool Operations
  const transferToPool = useCallback(
    (categoryId: string, minutes: number, note?: string): { success: boolean; error?: string } => {
      const category = categories.find(c => c.id === categoryId);
      if (!category) return { success: false, error: 'Kategori bulunamadı.' };

      const totals = getCategoryTotals(categoryId);
      const validation = validateTransfer({
        type: 'to_pool',
        categoryId,
        minutes,
        categoryTotals: totals,
        poolBalanceMinutes: poolBalance.balanceMinutes,
        categoryPolicy: category.policy,
        forceProtected: true, // user explicit confirmation
      });

      if (!validation.valid) {
        soundService.playWarning();
        return { success: false, error: validation.error };
      }

      const tx: PoolTransaction = {
        id: `tx-${Date.now()}`,
        type: 'rollover_to_pool',
        sourceCategoryId: categoryId,
        minutes,
        weekPeriodId: currentWeek.id,
        note: note || `${category.name} bütçesinden havuza aktarıldı`,
        timestamp: Date.now(),
      };

      setTransactions(prev => [tx, ...prev]);
      soundService.playFinish();
      hapticsService.medium();
      return { success: true };
    },
    [categories, getCategoryTotals, poolBalance.balanceMinutes, currentWeek.id]
  );

  const transferFromPool = useCallback(
    (categoryId: string, minutes: number, note?: string): { success: boolean; error?: string } => {
      const category = categories.find(c => c.id === categoryId);
      if (!category) return { success: false, error: 'Kategori bulunamadı.' };

      const totals = getCategoryTotals(categoryId);
      const validation = validateTransfer({
        type: 'from_pool',
        categoryId,
        minutes,
        categoryTotals: totals,
        poolBalanceMinutes: poolBalance.balanceMinutes,
        categoryPolicy: category.policy,
      });

      if (!validation.valid) {
        soundService.playWarning();
        return { success: false, error: validation.error };
      }

      const tx: PoolTransaction = {
        id: `tx-${Date.now()}`,
        type: 'pool_to_category',
        targetCategoryId: categoryId,
        minutes,
        weekPeriodId: currentWeek.id,
        note: note || `Havuzdan ${category.name} bütçesine eklendi`,
        timestamp: Date.now(),
      };

      setTransactions(prev => [tx, ...prev]);
      soundService.playFinish();
      hapticsService.medium();
      return { success: true };
    },
    [categories, getCategoryTotals, poolBalance.balanceMinutes, currentWeek.id]
  );

  const undoTransaction = useCallback((transactionId: string): { success: boolean; error?: string } => {
    setTransactions(prev =>
      prev.map(t => (t.id === transactionId ? { ...t, isUndone: true } : t))
    );
    soundService.playTap();
    hapticsService.light();
    return { success: true };
  }, []);

  // Settings & Storage Actions
  const updateSettings = useCallback((updates: Partial<AppSettings>) => {
    setSettings(prev => ({ ...prev, ...updates }));
  }, []);

  const resetAll = useCallback(() => {
    storage.resetAllData();
    setCategories(storage.getCategories());
    setTasks(storage.getTasks());
    setSessions([]);
    setTransactions([]);
    setSettings(storage.getSettings());
    setActiveSession(null);
  }, []);

  const importBackup = useCallback((jsonString: string) => {
    const result = storage.importFullBackup(jsonString);
    if (result.success) {
      setCategories(storage.getCategories());
      setTasks(storage.getTasks());
      setSessions(storage.getSessions());
      setTransactions(storage.getTransactions());
      setSettings(storage.getSettings());
      soundService.playFinish();
    }
    return result;
  }, []);

  return (
    <TempoContext.Provider
      value={{
        categories,
        tasks,
        sessions,
        transactions,
        settings,
        activeSession,
        activeTab,
        currentWeek,
        isFocusModalOpen,
        isSettingsOpen,
        isOnboardingOpen,
        deviceFrameMode,
        lastExhaustedWarningCategory,

        setActiveTab,
        setIsFocusModalOpen,
        setIsSettingsOpen,
        setIsOnboardingOpen,
        setDeviceFrameMode,

        addCategory,
        updateCategory,
        deleteCategory,
        markCategoryCompletedForWeek,

        addTask,
        toggleTask,
        deleteTask,

        startSession,
        pauseSession,
        resumeSession,
        startBreak,
        endBreak,
        finishSession,
        discardSession,
        adjustActiveSessionTime,

        addManualSession,
        deleteSession,

        transferToPool,
        transferFromPool,
        undoTransaction,

        updateSettings,
        resetAll,
        importBackup,

        getCategoryTotals,
        poolBalance,
        weeklyTotals,
      }}
    >
      {children}
    </TempoContext.Provider>
  );
};

export const useTempo = () => {
  const context = useContext(TempoContext);
  if (!context) {
    throw new Error('useTempo must be used within a TempoProvider');
  }
  return context;
};
