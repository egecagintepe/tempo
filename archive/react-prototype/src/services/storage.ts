/**
 * TEMPO — Local Storage Persistence & Data Engine
 */

import type { Category, Task, WorkSession, PoolTransaction, AppSettings } from '../types/index.ts';

const STORAGE_KEYS = {
  CATEGORIES: 'tempo_categories_v1',
  TASKS: 'tempo_tasks_v1',
  SESSIONS: 'tempo_sessions_v1',
  TRANSACTIONS: 'tempo_transactions_v1',
  SETTINGS: 'tempo_settings_v1',
  ACTIVE_SESSION: 'tempo_active_session_v1',
  ONBOARDED: 'tempo_has_onboarded_v1',
};

export const DEFAULT_SETTINGS: AppSettings = {
  theme: 'dark',
  soundEnabled: true,
  vibrationEnabled: true,
  notificationsEnabled: true,
  smartWarning80: true,
  smartWarning95: true,
  defaultBreakMinutes: 5,
  defaultFocusCycle: 'continuous',
  weekStartDay: 1,
  autoWeekReset: true,
  language: 'tr',
};

export const INITIAL_CATEGORIES: Category[] = [
  {
    id: 'cat-deep-work',
    name: 'Deep Work',
    description: 'Focused problem solving, engineering, and deep focus sessions',
    icon: 'cpu',
    color: '#3B82F6', // Blue
    weeklyTargetMinutes: 420, // 7h
    policy: 'flexible',
    isArchived: false,
    isCompletedForWeek: false,
    priorityOrder: 1,
    scheduledDays: [1, 2, 3, 4, 5],
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: 'cat-study',
    name: 'Study',
    description: 'Academic coursework, lectures, and textbook study',
    icon: 'book-open',
    color: '#06B6D4', // Cyan
    weeklyTargetMinutes: 300, // 5h
    policy: 'flexible',
    isArchived: false,
    isCompletedForWeek: false,
    priorityOrder: 2,
    scheduledDays: [1, 3, 5],
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: 'cat-reading',
    name: 'Reading',
    description: 'Non-fiction books, technical literature, and articles',
    icon: 'bookmark',
    color: '#8B5CF6', // Purple
    weeklyTargetMinutes: 120, // 2h
    policy: 'flexible',
    isArchived: false,
    isCompletedForWeek: false,
    priorityOrder: 3,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: 'cat-language',
    name: 'Language Learning',
    description: 'Vocabulary flashcards, listening comprehension, and grammar',
    icon: 'globe',
    color: '#6366F1', // Indigo
    weeklyTargetMinutes: 120, // 2h
    policy: 'flexible',
    isArchived: false,
    isCompletedForWeek: false,
    priorityOrder: 4,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: 'cat-fitness',
    name: 'Fitness',
    description: 'Workouts, cardio, and physical training',
    icon: 'activity',
    color: '#10B981', // Emerald
    weeklyTargetMinutes: 180, // 3h
    policy: 'flexible',
    isArchived: false,
    isCompletedForWeek: false,
    priorityOrder: 5,
    scheduledDays: [1, 3, 5, 6],
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: 'cat-projects',
    name: 'Personal Projects',
    description: 'Open source tools, software experiments, and side builds',
    icon: 'terminal',
    color: '#14B8A6', // Teal
    weeklyTargetMinutes: 150, // 2h 30m
    policy: 'strict',
    isArchived: false,
    isCompletedForWeek: false,
    priorityOrder: 6,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: 'cat-writing',
    name: 'Creative Writing',
    description: 'Protected creative writing time: cannot be spent elsewhere',
    icon: 'pen-tool',
    color: '#F59E0B', // Amber
    weeklyTargetMinutes: 90, // 1h 30m
    policy: 'protected',
    isArchived: false,
    isCompletedForWeek: false,
    priorityOrder: 7,
    scheduledDays: [7], // Sun
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
];

export const INITIAL_TASKS: Task[] = [
  {
    id: 't-deep-1',
    categoryId: 'cat-deep-work',
    title: 'Core algorithm implementation',
    estimatedMinutes: 60,
    isCompleted: false,
    createdAt: new Date().toISOString(),
  },
  {
    id: 't-study-1',
    categoryId: 'cat-study',
    title: 'Review chapter notes and solve exercises',
    estimatedMinutes: 45,
    isCompleted: false,
    createdAt: new Date().toISOString(),
  },
  {
    id: 't-reading-1',
    categoryId: 'cat-reading',
    title: 'Read chapter 3 & highlight key principles',
    estimatedMinutes: 30,
    isCompleted: false,
    createdAt: new Date().toISOString(),
  },
  {
    id: 't-lang-1',
    categoryId: 'cat-language',
    title: 'Daily vocabulary cards & listening drill',
    estimatedMinutes: 30,
    isCompleted: false,
    createdAt: new Date().toISOString(),
  },
  {
    id: 't-writing-1',
    categoryId: 'cat-writing',
    title: 'Draft scene outline for next chapter',
    estimatedMinutes: 45,
    isCompleted: false,
    createdAt: new Date().toISOString(),
  },
];

export const storage = {
  getCategories(): Category[] {
    try {
      const data = localStorage.getItem(STORAGE_KEYS.CATEGORIES);
      return data ? JSON.parse(data) : INITIAL_CATEGORIES;
    } catch {
      return INITIAL_CATEGORIES;
    }
  },

  saveCategories(categories: Category[]) {
    try {
      localStorage.setItem(STORAGE_KEYS.CATEGORIES, JSON.stringify(categories));
    } catch {}
  },

  getTasks(): Task[] {
    try {
      const data = localStorage.getItem(STORAGE_KEYS.TASKS);
      return data ? JSON.parse(data) : INITIAL_TASKS;
    } catch {
      return INITIAL_TASKS;
    }
  },

  saveTasks(tasks: Task[]) {
    try {
      localStorage.setItem(STORAGE_KEYS.TASKS, JSON.stringify(tasks));
    } catch {}
  },

  getSessions(): WorkSession[] {
    try {
      const data = localStorage.getItem(STORAGE_KEYS.SESSIONS);
      return data ? JSON.parse(data) : [];
    } catch {
      return [];
    }
  },

  saveSessions(sessions: WorkSession[]) {
    try {
      localStorage.setItem(STORAGE_KEYS.SESSIONS, JSON.stringify(sessions));
    } catch {}
  },

  getTransactions(): PoolTransaction[] {
    try {
      const data = localStorage.getItem(STORAGE_KEYS.TRANSACTIONS);
      return data ? JSON.parse(data) : [];
    } catch {
      return [];
    }
  },

  saveTransactions(transactions: PoolTransaction[]) {
    try {
      localStorage.setItem(STORAGE_KEYS.TRANSACTIONS, JSON.stringify(transactions));
    } catch {}
  },

  getSettings(): AppSettings {
    try {
      const data = localStorage.getItem(STORAGE_KEYS.SETTINGS);
      return data ? { ...DEFAULT_SETTINGS, ...JSON.parse(data) } : DEFAULT_SETTINGS;
    } catch {
      return DEFAULT_SETTINGS;
    }
  },

  saveSettings(settings: AppSettings) {
    try {
      localStorage.setItem(STORAGE_KEYS.SETTINGS, JSON.stringify(settings));
    } catch {}
  },

  getActiveSession(): WorkSession | null {
    try {
      const data = localStorage.getItem(STORAGE_KEYS.ACTIVE_SESSION);
      return data ? JSON.parse(data) : null;
    } catch {
      return null;
    }
  },

  saveActiveSession(session: WorkSession | null) {
    try {
      if (session) {
        localStorage.setItem(STORAGE_KEYS.ACTIVE_SESSION, JSON.stringify(session));
      } else {
        localStorage.removeItem(STORAGE_KEYS.ACTIVE_SESSION);
      }
    } catch {}
  },

  hasOnboarded(): boolean {
    try {
      return localStorage.getItem(STORAGE_KEYS.ONBOARDED) === 'true';
    } catch {
      return false;
    }
  },

  setOnboarded(value: boolean) {
    try {
      localStorage.setItem(STORAGE_KEYS.ONBOARDED, value ? 'true' : 'false');
    } catch {}
  },

  exportFullBackup(): string {
    const backup = {
      version: 1,
      appName: 'TEMPO - Personal Time Budget OS',
      exportDate: new Date().toISOString(),
      categories: this.getCategories(),
      tasks: this.getTasks(),
      sessions: this.getSessions(),
      transactions: this.getTransactions(),
      settings: this.getSettings(),
    };
    return JSON.stringify(backup, null, 2);
  },

  importFullBackup(jsonString: string): { success: boolean; error?: string } {
    try {
      const parsed = JSON.parse(jsonString);
      if (!parsed || !Array.isArray(parsed.categories)) {
        return { success: false, error: 'Geçersiz yedekleme dosyası formatı.' };
      }
      this.saveCategories(parsed.categories);
      if (Array.isArray(parsed.tasks)) this.saveTasks(parsed.tasks);
      if (Array.isArray(parsed.sessions)) this.saveSessions(parsed.sessions);
      if (Array.isArray(parsed.transactions)) this.saveTransactions(parsed.transactions);
      if (parsed.settings) this.saveSettings(parsed.settings);
      return { success: true };
    } catch (e: unknown) {
      return { success: false, error: (e as Error).message || 'Dosya okunamadı' };
    }
  },

  exportSessionsCsv(): string {
    const sessions = this.getSessions();
    const categories = this.getCategories();
    const catMap = new Map(categories.map(c => [c.id, c.name]));

    const headers = ['ID', 'Kategori', 'Hafta', 'Başlangıç', 'Bitiş', 'Aktif Süre (Saniye)', 'Mola Süresi (Saniye)', 'Not'];
    const rows = sessions.map(s => [
      s.id,
      `"${catMap.get(s.categoryId) || s.categoryId}"`,
      s.weekPeriodId,
      new Date(s.startTime).toISOString(),
      s.endTime ? new Date(s.endTime).toISOString() : '',
      s.activeSeconds,
      s.breakSeconds,
      `"${(s.note || '').replace(/"/g, '""')}"`,
    ]);

    return [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
  },

  resetAllData() {
    try {
      localStorage.clear();
      this.saveCategories(INITIAL_CATEGORIES);
      this.saveTasks(INITIAL_TASKS);
      this.saveSessions([]);
      this.saveTransactions([]);
      this.saveSettings(DEFAULT_SETTINGS);
      this.setOnboarded(true);
    } catch {}
  },
};
