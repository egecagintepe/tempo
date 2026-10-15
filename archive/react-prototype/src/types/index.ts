/**
 * TEMPO — Personal Time Budget OS
 * Core TypeScript Data Models & Types
 */

export type BudgetPolicy = 'strict' | 'flexible' | 'protected' | 'deadline';

export interface Category {
  id: string;
  name: string;
  description: string;
  icon: string;
  color: string;
  weeklyTargetMinutes: number; // Stored in minutes
  policy: BudgetPolicy;
  isArchived: boolean;
  isCompletedForWeek: boolean;
  priorityOrder: number;
  scheduledDays?: number[]; // 1=Mon, 2=Tue, ..., 7=Sun
  deadlineDate?: string;
  createdAt: string;
  updatedAt: string;
}

export interface Task {
  id: string;
  categoryId: string;
  title: string;
  estimatedMinutes?: number;
  isCompleted: boolean;
  createdAt: string;
}

export type SessionState = 'idle' | 'running' | 'paused' | 'on_break';

export interface BreakSegment {
  id: string;
  startTime: number; // Unix timestamp ms
  endTime?: number;
  plannedMinutes: number;
  actualDurationSeconds: number;
  label?: string;
}

export interface SessionSegment {
  id: string;
  type: 'work' | 'pause';
  startTime: number; // Unix ms
  endTime?: number;
  durationSeconds: number;
}

export interface WorkSession {
  id: string;
  categoryId: string;
  taskId?: string;
  startTime: number; // Unix ms
  endTime?: number; // Unix ms
  state: SessionState;
  activeSeconds: number;
  pauseSeconds: number;
  breakSeconds: number;
  note?: string;
  segments: SessionSegment[];
  breaks: BreakSegment[];
  weekPeriodId: string; // e.g. "2026-W42"
  createdAt: string;
  updatedAt: string;
}

export type TransactionType = 'rollover_to_pool' | 'pool_to_category' | 'direct_category_transfer';

export interface PoolTransaction {
  id: string;
  type: TransactionType;
  sourceCategoryId?: string; // null if from pool
  targetCategoryId?: string; // null if into pool
  minutes: number;
  weekPeriodId: string;
  note?: string;
  timestamp: number;
  isUndone?: boolean;
}

export interface AppSettings {
  theme: 'system' | 'dark' | 'light' | 'oled';
  soundEnabled: boolean;
  vibrationEnabled: boolean;
  notificationsEnabled: boolean;
  smartWarning80: boolean;
  smartWarning95: boolean;
  defaultBreakMinutes: number;
  defaultFocusCycle: 'continuous' | '25_5' | '50_10' | '90_15';
  weekStartDay: 1; // 1 = Monday
  autoWeekReset: boolean;
  language: 'tr' | 'en';
}

export interface WeekPeriod {
  id: string; // "YYYY-Www"
  startDate: string; // ISO
  endDate: string; // ISO
}
