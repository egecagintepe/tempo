import test from 'node:test';
import assert from 'node:assert/strict';
import {
  getWeekPeriod,
  formatMinutes,
  formatStopwatch,
  calculateCategoryTotals,
  calculatePoolBalance,
  validateTransfer,
  canStartSession,
} from './timeEngine.ts';
import type { Category, WorkSession, PoolTransaction } from '../types/index.ts';

test('formatMinutes formats minutes accurately into Turkish strings', () => {
  assert.equal(formatMinutes(150), '2s 30dk');
  assert.equal(formatMinutes(60), '1s');
  assert.equal(formatMinutes(45), '45dk');
  assert.equal(formatMinutes(0), '0dk');
  assert.equal(formatMinutes(-30), '-30dk');
});

test('formatStopwatch produces padded HH:MM:SS', () => {
  assert.equal(formatStopwatch(0), '00:00:00');
  assert.equal(formatStopwatch(65), '00:01:05');
  assert.equal(formatStopwatch(3661), '01:01:01');
  assert.equal(formatStopwatch(7200), '02:00:00');
});

test('getWeekPeriod returns consistent ISO week ID and Monday-Sunday boundaries', () => {
  const testDate = new Date('2026-10-15T12:00:00Z'); // Thursday
  const week = getWeekPeriod(testDate);
  assert.ok(week.id.includes('2026-W'));
  assert.equal(week.start.getDay(), 1); // Monday
  assert.equal(week.end.getDay(), 0); // Sunday
});

test('calculateCategoryTotals properly applies initial target, transfers, and sessions', () => {
  const dummyCat: Category = {
    id: 'cat-projects',
    name: 'Personal Projects',
    description: 'Side projects',
    icon: 'terminal',
    color: '#3B82F6',
    weeklyTargetMinutes: 150, // 2h 30m
    policy: 'strict',
    isArchived: false,
    isCompletedForWeek: false,
    priorityOrder: 1,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  };

  const sessions: WorkSession[] = [
    {
      id: 'sess-1',
      categoryId: 'cat-projects',
      startTime: 1000,
      endTime: 1000 + 3600 * 1000,
      state: 'idle',
      activeSeconds: 3600, // 60 mins
      pauseSeconds: 0,
      breakSeconds: 0,
      segments: [],
      breaks: [],
      weekPeriodId: '2026-W42',
      createdAt: '',
      updatedAt: '',
    },
    {
      id: 'sess-2',
      categoryId: 'cat-projects',
      startTime: 5000,
      endTime: 5000 + 2400 * 1000,
      state: 'idle',
      activeSeconds: 2400, // 40 mins
      pauseSeconds: 0,
      breakSeconds: 0,
      segments: [],
      breaks: [],
      weekPeriodId: '2026-W42',
      createdAt: '',
      updatedAt: '',
    },
  ];

  // Total spent = 60 + 40 = 100 mins (6000 seconds)
  // Remaining = 150 - 100 = 50 mins (3000 seconds)
  const totals = calculateCategoryTotals(dummyCat, sessions, [], '2026-W42');
  assert.equal(totals.spentMinutes, 100);
  assert.equal(totals.spentSeconds, 6000);
  assert.equal(totals.remainingMinutes, 50);
  assert.equal(totals.remainingSeconds, 3000);
  assert.equal(totals.isExhausted, false);
  assert.equal(totals.isOverBudget, false);
});

test('pool transfer out reduces category effective budget and updates pool balance', () => {
  const dummyCat: Category = {
    id: 'cat-projects',
    name: 'Personal Projects',
    description: '',
    icon: 'terminal',
    color: '#3B82F6',
    weeklyTargetMinutes: 150,
    policy: 'strict',
    isArchived: false,
    isCompletedForWeek: true,
    priorityOrder: 1,
    createdAt: '',
    updatedAt: '',
  };

  // 100 mins spent
  const sessions: WorkSession[] = [
    {
      id: 's1',
      categoryId: 'cat-projects',
      startTime: 0,
      state: 'idle',
      activeSeconds: 6000,
      pauseSeconds: 0,
      breakSeconds: 0,
      segments: [],
      breaks: [],
      weekPeriodId: '2026-W42',
      createdAt: '',
      updatedAt: '',
    },
  ];

  // Transfer 50 mins remaining to pool
  const transactions: PoolTransaction[] = [
    {
      id: 'tx-1',
      type: 'rollover_to_pool',
      sourceCategoryId: 'cat-projects',
      minutes: 50,
      weekPeriodId: '2026-W42',
      timestamp: Date.now(),
    },
  ];

  const catTotals = calculateCategoryTotals(dummyCat, sessions, transactions, '2026-W42');
  // Initial 150 - 50 out = 100 effectiveTarget
  assert.equal(catTotals.effectiveTargetMinutes, 100);
  assert.equal(catTotals.remainingMinutes, 0);
  assert.equal(catTotals.isExhausted, true);

  const pool = calculatePoolBalance(transactions, '2026-W42');
  assert.equal(pool.balanceMinutes, 50);
  assert.equal(pool.addedThisWeekMinutes, 50);
  assert.equal(pool.usedThisWeekMinutes, 0);

  // Now transfer 30 mins from pool to Book Writing
  const catBook: Category = {
    id: 'cat-book',
    name: 'Kitap Yazma',
    description: '',
    icon: 'book',
    color: '#8B5CF6',
    weeklyTargetMinutes: 90, // 1h 30m
    policy: 'protected',
    isArchived: false,
    isCompletedForWeek: false,
    priorityOrder: 2,
    createdAt: '',
    updatedAt: '',
  };

  const transactions2: PoolTransaction[] = [
    ...transactions,
    {
      id: 'tx-2',
      type: 'pool_to_category',
      targetCategoryId: 'cat-book',
      minutes: 30,
      weekPeriodId: '2026-W42',
      timestamp: Date.now(),
    },
  ];

  const poolAfter = calculatePoolBalance(transactions2, '2026-W42');
  assert.equal(poolAfter.balanceMinutes, 20); // 50 - 30 = 20 remaining in pool
  assert.equal(poolAfter.usedThisWeekMinutes, 30);

  const bookTotals = calculateCategoryTotals(catBook, [], transactions2, '2026-W42');
  assert.equal(bookTotals.effectiveTargetMinutes, 120); // 90 + 30 = 120
  assert.equal(bookTotals.remainingMinutes, 120);
});

test('strict budget blocks new sessions when exhausted', () => {
  const strictCat: Category = {
    id: 'strict-1',
    name: 'Katı Kategori',
    description: '',
    icon: 'lock',
    color: '#EF4444',
    weeklyTargetMinutes: 60,
    policy: 'strict',
    isArchived: false,
    isCompletedForWeek: false,
    priorityOrder: 1,
    createdAt: '',
    updatedAt: '',
  };

  // Spent 60 minutes
  const totals = calculateCategoryTotals(
    strictCat,
    [
      {
        id: 's-full',
        categoryId: 'strict-1',
        startTime: 0,
        state: 'idle',
        activeSeconds: 3600,
        pauseSeconds: 0,
        breakSeconds: 0,
        segments: [],
        breaks: [],
        weekPeriodId: '2026-W42',
        createdAt: '',
        updatedAt: '',
      },
    ],
    [],
    '2026-W42'
  );

  const check = canStartSession(strictCat, totals);
  assert.equal(check.allowed, false);
  assert.ok(check.reason?.includes('Katı Bütçe Doldu'));
});

test('validateTransfer blocks exceeding pool balance or invalid amounts', () => {
  const totals = {
    categoryId: 'c1',
    initialTargetMinutes: 60,
    transferredInMinutes: 0,
    transferredOutMinutes: 0,
    effectiveTargetMinutes: 60,
    effectiveTargetSeconds: 3600,
    spentSeconds: 1800,
    spentMinutes: 30,
    remainingSeconds: 1800,
    remainingMinutes: 30,
    progressPercent: 50,
    isExhausted: false,
    isOverBudget: false,
    overBudgetSeconds: 0,
    sessionCount: 1,
  };

  // Transfer 50 mins from category with only 30 mins remaining
  const res1 = validateTransfer({
    type: 'to_pool',
    categoryId: 'c1',
    minutes: 50,
    categoryTotals: totals,
    poolBalanceMinutes: 0,
    categoryPolicy: 'flexible',
  });
  assert.equal(res1.valid, false);
  assert.ok(res1.error?.includes('Aktarılabilir en fazla süre 30 dakikadır'));

  // Transfer 100 mins from pool with only 20 mins balance
  const res2 = validateTransfer({
    type: 'from_pool',
    categoryId: 'c1',
    minutes: 100,
    categoryTotals: totals,
    poolBalanceMinutes: 20,
    categoryPolicy: 'flexible',
  });
  assert.equal(res2.valid, false);
  assert.ok(res2.error?.includes('Havuzda yeterli süre yok'));
});
