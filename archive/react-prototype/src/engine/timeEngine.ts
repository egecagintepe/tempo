/**
 * TEMPO — Pure Calculation & Mathematical Business Logic Engine
 * All functions are deterministic and unit-testable.
 */

import type { Category, WorkSession, PoolTransaction } from '../types/index.ts';

/**
 * Returns ISO week period string (e.g. "2026-W42") and boundaries
 */
export function getWeekPeriod(date: Date = new Date()): { id: string; start: Date; end: Date } {
  const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  const dayNum = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const weekNo = Math.ceil((((d.getTime() - yearStart.getTime()) / 86400000) + 1) / 7);
  const weekId = `${d.getUTCFullYear()}-W${String(weekNo).padStart(2, '0')}`;

  // Local week Monday 00:00:00 to Sunday 23:59:59.999
  const current = new Date(date);
  const currentDay = current.getDay(); // 0 is Sun, 1 is Mon
  const diffToMonday = currentDay === 0 ? -6 : 1 - currentDay;

  const monday = new Date(current);
  monday.setDate(current.getDate() + diffToMonday);
  monday.setHours(0, 0, 0, 0);

  const sunday = new Date(monday);
  sunday.setDate(monday.getDate() + 6);
  sunday.setHours(23, 59, 59, 999);

  return { id: weekId, start: monday, end: sunday };
}

/**
 * Formats minutes into human-readable Turkish time string (e.g. 150m -> "2s 30dk")
 */
export function formatMinutes(minutes: number): string {
  const isNegative = minutes < 0;
  const absMin = Math.abs(Math.round(minutes));
  const h = Math.floor(absMin / 60);
  const m = absMin % 60;
  const prefix = isNegative ? '-' : '';
  if (h === 0) return `${prefix}${m}dk`;
  if (m === 0) return `${prefix}${h}s`;
  return `${prefix}${h}s ${m}dk`;
}

/**
 * Formats seconds into digital stopwatch format (e.g. 3661 -> "01:01:01" or "01:05")
 */
export function formatStopwatch(seconds: number, forceHours: boolean = true): string {
  const isNeg = seconds < 0;
  const absSec = Math.abs(Math.round(seconds));
  const h = Math.floor(absSec / 3600);
  const m = Math.floor((absSec % 3600) / 60);
  const s = absSec % 60;

  const pad = (n: number) => String(n).padStart(2, '0');
  const sign = isNeg ? '-' : '';

  if (forceHours || h > 0) {
    return `${sign}${pad(h)}:${pad(m)}:${pad(s)}`;
  }
  return `${sign}${pad(m)}:${pad(s)}`;
}

export interface CategoryTimeTotals {
  categoryId: string;
  initialTargetMinutes: number;
  transferredInMinutes: number;
  transferredOutMinutes: number;
  effectiveTargetMinutes: number;
  effectiveTargetSeconds: number;
  spentSeconds: number;
  spentMinutes: number;
  remainingSeconds: number;
  remainingMinutes: number;
  progressPercent: number;
  isExhausted: boolean;
  isOverBudget: boolean;
  overBudgetSeconds: number;
  sessionCount: number;
}

/**
 * Calculates accurate budget totals for a category in a given week.
 * Enforces equation:
 * effectiveTarget = initialTarget + transferredIn - transferredOut
 * remaining = effectiveTarget - spent
 */
export function calculateCategoryTotals(
  category: Category,
  sessions: WorkSession[],
  transactions: PoolTransaction[],
  weekPeriodId: string,
  activeSessionDurationSeconds: number = 0
): CategoryTimeTotals {
  const initialTargetMinutes = category.weeklyTargetMinutes;

  // Transactions affecting this category in this week (and not undone)
  const activeTx = transactions.filter(t => !t.isUndone && t.weekPeriodId === weekPeriodId);

  let transferredInMinutes = 0;
  let transferredOutMinutes = 0;

  for (const t of activeTx) {
    if (t.targetCategoryId === category.id) {
      transferredInMinutes += t.minutes;
    }
    if (t.sourceCategoryId === category.id) {
      transferredOutMinutes += t.minutes;
    }
  }

  const effectiveTargetMinutes = Math.max(0, initialTargetMinutes + transferredInMinutes - transferredOutMinutes);
  const effectiveTargetSeconds = effectiveTargetMinutes * 60;

  // Filter sessions for this category in this week
  const weekSessions = sessions.filter(
    s => s.categoryId === category.id && s.weekPeriodId === weekPeriodId
  );

  let spentSeconds = 0;
  for (const s of weekSessions) {
    spentSeconds += s.activeSeconds;
  }
  spentSeconds += activeSessionDurationSeconds;

  const spentMinutes = Math.round(spentSeconds / 60);
  const remainingSeconds = effectiveTargetSeconds - spentSeconds;
  const remainingMinutes = Math.round(remainingSeconds / 60);

  const progressPercent = effectiveTargetSeconds > 0
    ? Math.min(100, Math.round((spentSeconds / effectiveTargetSeconds) * 100))
    : (spentSeconds > 0 ? 100 : 0);

  const isExhausted = remainingSeconds <= 0;
  const isOverBudget = remainingSeconds < 0;
  const overBudgetSeconds = isOverBudget ? Math.abs(remainingSeconds) : 0;

  return {
    categoryId: category.id,
    initialTargetMinutes,
    transferredInMinutes,
    transferredOutMinutes,
    effectiveTargetMinutes,
    effectiveTargetSeconds,
    spentSeconds,
    spentMinutes,
    remainingSeconds,
    remainingMinutes,
    progressPercent,
    isExhausted,
    isOverBudget,
    overBudgetSeconds,
    sessionCount: weekSessions.length + (activeSessionDurationSeconds > 0 ? 1 : 0),
  };
}

/**
 * Calculates current Free Time Pool balance in minutes.
 * poolBalance = sum(transfers_into_pool) - sum(transfers_out_of_pool)
 */
export function calculatePoolBalance(
  transactions: PoolTransaction[],
  weekPeriodId: string
): {
  balanceMinutes: number;
  addedThisWeekMinutes: number;
  usedThisWeekMinutes: number;
} {
  const activeTx = transactions.filter(t => !t.isUndone && t.weekPeriodId === weekPeriodId);

  let addedThisWeekMinutes = 0;
  let usedThisWeekMinutes = 0;

  for (const t of activeTx) {
    if (t.type === 'rollover_to_pool' || (t.targetCategoryId === null || t.targetCategoryId === undefined)) {
      addedThisWeekMinutes += t.minutes;
    } else if (t.type === 'pool_to_category' || (t.sourceCategoryId === null || t.sourceCategoryId === undefined)) {
      usedThisWeekMinutes += t.minutes;
    }
  }

  const balanceMinutes = Math.max(0, addedThisWeekMinutes - usedThisWeekMinutes);

  return {
    balanceMinutes,
    addedThisWeekMinutes,
    usedThisWeekMinutes,
  };
}

/**
 * Validates a transfer between pool and category or category to pool.
 * Returns { valid: boolean, error?: string }
 */
export function validateTransfer(params: {
  type: 'to_pool' | 'from_pool';
  categoryId: string;
  minutes: number;
  categoryTotals: CategoryTimeTotals;
  poolBalanceMinutes: number;
  categoryPolicy: Category['policy'];
  forceProtected?: boolean;
}): { valid: boolean; error?: string } {
  const { type, minutes, categoryTotals, poolBalanceMinutes, categoryPolicy, forceProtected } = params;

  if (!minutes || minutes <= 0) {
    return { valid: false, error: 'Süre 0 dakikadan büyük olmalıdır.' };
  }

  if (type === 'to_pool') {
    if (categoryPolicy === 'protected' && !forceProtected) {
      return {
        valid: false,
        error: 'Bu kategori Korunan Zaman modundadır. Süre aktarımı özel onay gerektirir.',
      };
    }
    const maxAvailable = Math.floor(Math.max(0, categoryTotals.remainingSeconds) / 60);
    if (minutes > maxAvailable) {
      return {
        valid: false,
        error: `Aktarılabilir en fazla süre ${maxAvailable} dakikadır (Kalan bütçe: ${formatMinutes(maxAvailable)}).`,
      };
    }
  } else if (type === 'from_pool') {
    if (minutes > poolBalanceMinutes) {
      return {
        valid: false,
        error: `Havuzda yeterli süre yok. Mevcut havuz: ${formatMinutes(poolBalanceMinutes)}.`,
      };
    }
  }

  return { valid: true };
}

/**
 * Checks if a session can be started on a category.
 * Strict budget policy blocks starting if remaining time is 0.
 */
export function canStartSession(category: Category, totals: CategoryTimeTotals): { allowed: boolean; reason?: string } {
  if (category.isArchived) {
    return { allowed: false, reason: 'Arşivlenmiş kategoride oturum başlatılamaz.' };
  }
  if (category.policy === 'strict' && totals.isExhausted) {
    return {
      allowed: false,
      reason: 'Katı Bütçe Doldu! Bu haftalık ayrılan süre tükendi. Ek çalışma için bütçeyi artırın veya havuzdan aktarın.',
    };
  }
  return { allowed: true };
}
