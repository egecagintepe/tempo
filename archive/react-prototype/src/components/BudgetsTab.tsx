import React, { useState } from 'react';
import { useTempo } from '../context/TempoContext.tsx';
import { formatMinutes } from '../engine/timeEngine.ts';
import type { Category, BudgetPolicy } from '../types/index.ts';
import {
  Plus,
  Play,
  CheckCircle2,
  Lock,
  Target,
  Shield,
  Clock,
  ArrowRightLeft,
  ChevronDown,
  ChevronUp,
  X,
  Edit2,
  Trash2,
  ListTodo,
} from 'lucide-react';
import { CategoryIcon, AVAILABLE_ICONS } from './IconHelper.tsx';

const POLICY_INFO: Record<BudgetPolicy, { label: string; desc: string; color: string; icon: typeof Lock }> = {
  strict: {
    label: 'Katı Bütçe',
    desc: 'Süre bittiğinde oturum durur. Ek çalışma için açık transfer gerekir.',
    color: 'text-rose-400 bg-rose-500/10 border-rose-500/20',
    icon: Lock,
  },
  flexible: {
    label: 'Esnek Hedef',
    desc: 'Süre bitince alarm çalar ancak çalışma devam ettirilebilir. Aşım kaydedilir.',
    color: 'text-blue-400 bg-blue-500/10 border-blue-500/20',
    icon: Target,
  },
  protected: {
    label: 'Korunan Zaman',
    desc: 'Bu süre başka kategorilere otomatik aktarılamaz. Özel koruma altındadır.',
    color: 'text-purple-400 bg-purple-500/10 border-purple-500/20',
    icon: Shield,
  },
  deadline: {
    label: 'Teslim Odaklı',
    desc: 'Bitiş tarihi vardır. Süre azaldıkça erken uyarılar verir.',
    color: 'text-amber-400 bg-amber-500/10 border-amber-500/20',
    icon: Clock,
  },
};

const COLOR_PALETTE = [
  '#06B6D4', // Cyan
  '#3B82F6', // Blue
  '#6366F1', // Indigo
  '#8B5CF6', // Purple
  '#EC4899', // Pink
  '#F43F5E', // Rose
  '#EF4444', // Red
  '#F97316', // Orange
  '#F59E0B', // Amber
  '#10B981', // Emerald
  '#14B8A6', // Teal
];

export const BudgetsTab: React.FC = () => {
  const {
    categories,
    tasks,
    getCategoryTotals,
    startSession,
    addCategory,
    updateCategory,
    deleteCategory,
    markCategoryCompletedForWeek,
    transferToPool,
    addTask,
    toggleTask,
    deleteTask,
  } = useTempo();

  const [filterPolicy, setFilterPolicy] = useState<string>('all');
  const [expandedCategoryId, setExpandedCategoryId] = useState<string | null>(null);

  // Modal States
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [editingCategory, setEditingCategory] = useState<Category | null>(null);
  const [transferPromptCategory, setTransferPromptCategory] = useState<Category | null>(null);
  const [transferMinutesInput, setTransferMinutesInput] = useState<number>(30);
  const [newTaskTitle, setNewTaskTitle] = useState('');

  // Form State for Create / Edit
  const [formName, setFormName] = useState('');
  const [formDesc, setFormDesc] = useState('');
  const [formHours, setFormHours] = useState('2');
  const [formMins, setFormMins] = useState('0');
  const [formColor, setFormColor] = useState(COLOR_PALETTE[1]);
  const [formIcon, setFormIcon] = useState('sparkles');
  const [formPolicy, setFormPolicy] = useState<BudgetPolicy>('flexible');

  const openCreateModal = () => {
    setEditingCategory(null);
    setFormName('');
    setFormDesc('');
    setFormHours('2');
    setFormMins('0');
    setFormColor(COLOR_PALETTE[Math.floor(Math.random() * COLOR_PALETTE.length)]);
    setFormIcon('target');
    setFormPolicy('flexible');
    setIsCreateModalOpen(true);
  };

  const openEditModal = (cat: Category) => {
    setEditingCategory(cat);
    setFormName(cat.name);
    setFormDesc(cat.description || '');
    setFormHours(String(Math.floor(cat.weeklyTargetMinutes / 60)));
    setFormMins(String(cat.weeklyTargetMinutes % 60));
    setFormColor(cat.color);
    setFormIcon(cat.icon);
    setFormPolicy(cat.policy);
    setIsCreateModalOpen(true);
  };

  const handleSaveCategory = (e: React.FormEvent) => {
    e.preventDefault();
    if (!formName.trim()) return;

    const totalMinutes = (parseInt(formHours) || 0) * 60 + (parseInt(formMins) || 0);
    if (totalMinutes <= 0) {
      alert('Lütfen haftalık geçerli bir süre belirleyin.');
      return;
    }

    if (editingCategory) {
      updateCategory(editingCategory.id, {
        name: formName.trim(),
        description: formDesc.trim(),
        weeklyTargetMinutes: totalMinutes,
        color: formColor,
        icon: formIcon,
        policy: formPolicy,
      });
    } else {
      addCategory({
        name: formName.trim(),
        description: formDesc.trim(),
        weeklyTargetMinutes: totalMinutes,
        color: formColor,
        icon: formIcon,
        policy: formPolicy,
        isArchived: false,
        isCompletedForWeek: false,
        priorityOrder: categories.length + 1,
      });
    }
    setIsCreateModalOpen(false);
  };

  const handlePromptPoolTransfer = (cat: Category) => {
    const totals = getCategoryTotals(cat.id);
    const remaining = Math.max(0, totals.remainingMinutes);
    setTransferPromptCategory(cat);
    setTransferMinutesInput(remaining);
  };

  const executePoolTransferFromPrompt = () => {
    if (!transferPromptCategory) return;
    const res = transferToPool(transferPromptCategory.id, transferMinutesInput);
    if (res.success) {
      markCategoryCompletedForWeek(transferPromptCategory.id, true);
      setTransferPromptCategory(null);
    } else {
      alert(res.error);
    }
  };

  const filteredCategories = categories
    .filter(c => !c.isArchived)
    .filter(c => filterPolicy === 'all' || c.policy === filterPolicy);

  return (
    <div className="space-y-5 pb-28 pt-2">
      {/* Top Header & Add Button */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold font-mono text-white light:text-zinc-900">
            Haftalık Bütçeler
          </h1>
          <p className="text-xs text-zinc-400 light:text-zinc-600 mt-0.5">
            Her etkinliğin bağımsız ve korunan zaman kotası
          </p>
        </div>
        <button
          onClick={openCreateModal}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-blue-600 hover:bg-blue-500 text-white font-semibold text-xs shadow-md active:scale-95 transition-all"
        >
          <Plus className="w-4 h-4" />
          <span>Kategori Ekle</span>
        </button>
      </div>

      {/* Policy Filter Pills */}
      <div className="flex items-center gap-1.5 overflow-x-auto pb-1 text-xs no-scrollbar">
        {[
          { id: 'all', label: 'Tümü' },
          { id: 'strict', label: 'Katı Bütçe' },
          { id: 'flexible', label: 'Esnek Hedef' },
          { id: 'protected', label: 'Korunan Zaman' },
          { id: 'deadline', label: 'Teslim Odaklı' },
        ].map(pill => (
          <button
            key={pill.id}
            onClick={() => setFilterPolicy(pill.id)}
            className={`px-3 py-1.5 rounded-xl font-medium shrink-0 transition-all ${
              filterPolicy === pill.id
                ? 'bg-zinc-100 text-zinc-900 font-bold dark:bg-white dark:text-zinc-950'
                : 'bg-zinc-900/80 light:bg-zinc-200/70 text-zinc-400 light:text-zinc-600 hover:bg-zinc-800'
            }`}
          >
            {pill.label}
          </button>
        ))}
      </div>

      {/* Categories List */}
      <div className="space-y-3">
        {filteredCategories.map(cat => {
          const totals = getCategoryTotals(cat.id);
          const policyMeta = POLICY_INFO[cat.policy];
          const PolicyIcon = policyMeta.icon;
          const isExpanded = expandedCategoryId === cat.id;
          const catTasks = tasks.filter(t => t.categoryId === cat.id);

          return (
            <div
              key={cat.id}
              className={`rounded-2xl border transition-all overflow-hidden ${
                cat.isCompletedForWeek
                  ? 'bg-zinc-900/40 border-emerald-900/50 light:bg-zinc-50'
                  : 'bg-zinc-900/80 light:bg-zinc-100 border-zinc-800 light:border-zinc-200 hover:border-zinc-700'
              }`}
            >
              {/* Category Main Header Card */}
              <div className="p-4">
                <div className="flex items-start justify-between gap-3">
                  <div className="flex items-center gap-3">
                    <div
                      className="w-11 h-11 rounded-2xl flex items-center justify-center shrink-0 shadow-sm"
                      style={{ backgroundColor: `${cat.color}20`, color: cat.color }}
                    >
                      <CategoryIcon name={cat.icon} className="w-5 h-5" />
                    </div>
                    <div>
                      <div className="flex items-center gap-2">
                        <h2 className="font-bold text-sm text-white light:text-zinc-900">
                          {cat.name}
                        </h2>
                        {cat.isCompletedForWeek && (
                          <span className="flex items-center gap-1 text-[10px] font-semibold text-emerald-400 bg-emerald-950/60 border border-emerald-800/60 px-1.5 py-0.5 rounded-full">
                            <CheckCircle2 className="w-3 h-3" />
                            Tamamlandı
                          </span>
                        )}
                      </div>
                      <p className="text-xs text-zinc-400 light:text-zinc-600 mt-0.5 line-clamp-1">
                        {cat.description || 'Haftalık zaman bütçesi'}
                      </p>
                    </div>
                  </div>

                  {/* Policy Badge */}
                  <div
                    className={`flex items-center gap-1 px-2 py-0.5 rounded-lg text-[10px] font-mono font-semibold border ${policyMeta.color}`}
                    title={policyMeta.desc}
                  >
                    <PolicyIcon className="w-3 h-3" />
                    <span>{policyMeta.label}</span>
                  </div>
                </div>

                {/* Numbers Row */}
                <div className="grid grid-cols-3 gap-2 mt-4 p-2.5 rounded-xl bg-zinc-950/60 light:bg-zinc-200/50 border border-zinc-800/40 light:border-zinc-300/60 font-mono text-center">
                  <div>
                    <span className="text-[10px] uppercase text-zinc-500">Hedef</span>
                    <p className="text-xs font-bold text-white light:text-zinc-900 mt-0.5">
                      {formatMinutes(totals.effectiveTargetMinutes)}
                    </p>
                  </div>
                  <div>
                    <span className="text-[10px] uppercase text-blue-400">Harcanan</span>
                    <p className="text-xs font-bold text-blue-400 mt-0.5">
                      {formatMinutes(totals.spentMinutes)}
                    </p>
                  </div>
                  <div>
                    <span className="text-[10px] uppercase text-emerald-400">Kalan</span>
                    <p
                      className={`text-xs font-bold mt-0.5 ${
                        totals.isExhausted
                          ? 'text-rose-400'
                          : totals.remainingMinutes <= 30
                          ? 'text-amber-400'
                          : 'text-emerald-400'
                      }`}
                    >
                      {formatMinutes(totals.remainingMinutes)}
                    </p>
                  </div>
                </div>

                {/* Progress Bar */}
                <div className="w-full h-2 rounded-full bg-zinc-800 light:bg-zinc-200 mt-3 overflow-hidden">
                  <div
                    className="h-full rounded-full transition-all duration-300"
                    style={{
                      width: `${totals.progressPercent}%`,
                      backgroundColor: totals.isExhausted && cat.policy === 'strict' ? '#F43F5E' : cat.color,
                    }}
                  />
                </div>

                {/* Actions Row */}
                <div className="flex items-center justify-between mt-3.5 pt-2 border-t border-zinc-800/60 light:border-zinc-200">
                  <div className="flex items-center gap-1.5">
                    {/* Start Timer */}
                    <button
                      onClick={() => {
                        const res = startSession(cat.id);
                        if (!res.success && res.error) alert(res.error);
                      }}
                      className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-blue-600 hover:bg-blue-500 text-white font-semibold text-xs transition-all shadow-sm active:scale-95"
                    >
                      <Play className="w-3.5 h-3.5 fill-current" />
                      <span>Odaklan</span>
                    </button>

                    {/* Finish Week & Transfer to Pool */}
                    {totals.remainingMinutes > 0 && (
                      <button
                        onClick={() => handlePromptPoolTransfer(cat)}
                        className="flex items-center gap-1 px-2.5 py-1.5 rounded-xl bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 text-xs font-medium transition-all active:scale-95"
                        title="İşleri tamamla ve kalan süreyi havuza aktar"
                      >
                        <ArrowRightLeft className="w-3.5 h-3.5" />
                        <span>Havuza Aktar</span>
                      </button>
                    )}
                  </div>

                  <div className="flex items-center gap-1">
                    {/* Toggle Tasks / Details */}
                    <button
                      onClick={() => setExpandedCategoryId(isExpanded ? null : cat.id)}
                      className="p-1.5 rounded-lg text-zinc-400 hover:text-zinc-200 light:text-zinc-600 hover:bg-zinc-800 light:hover:bg-zinc-200 transition-all flex items-center gap-1 text-xs"
                      title="Görevler ve Detaylar"
                    >
                      <ListTodo className="w-4 h-4" />
                      {catTasks.length > 0 && (
                        <span className="font-mono text-[10px] bg-zinc-800 light:bg-zinc-300 px-1.5 py-0.2 rounded-full">
                          {catTasks.filter(t => t.isCompleted).length}/{catTasks.length}
                        </span>
                      )}
                      {isExpanded ? <ChevronUp className="w-3.5 h-3.5" /> : <ChevronDown className="w-3.5 h-3.5" />}
                    </button>

                    {/* Edit */}
                    <button
                      onClick={() => openEditModal(cat)}
                      className="p-1.5 rounded-lg text-zinc-400 hover:text-zinc-200 light:text-zinc-600 hover:bg-zinc-800 light:hover:bg-zinc-200 transition-all"
                      title="Kategoriyi Düzenle"
                    >
                      <Edit2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </div>

              {/* Expanded Tasks & Details View */}
              {isExpanded && (
                <div className="bg-zinc-950/70 light:bg-zinc-200/40 p-4 border-t border-zinc-800/60 light:border-zinc-300 space-y-3">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-mono font-semibold uppercase text-zinc-400">
                      Haftalık Görevler
                    </span>
                    <span className="text-[11px] text-zinc-500">
                      {catTasks.filter(t => t.isCompleted).length} tamamlandı
                    </span>
                  </div>

                  {/* Task List */}
                  <div className="space-y-1.5">
                    {catTasks.map(task => (
                      <div
                        key={task.id}
                        className="flex items-center justify-between p-2 rounded-xl bg-zinc-900/60 light:bg-white border border-zinc-800/40 light:border-zinc-200 text-xs"
                      >
                        <div
                          onClick={() => toggleTask(task.id)}
                          className="flex items-center gap-2 cursor-pointer flex-1"
                        >
                          <input
                            type="checkbox"
                            checked={task.isCompleted}
                            onChange={() => {}}
                            className="rounded border-zinc-700 text-blue-600 focus:ring-0 cursor-pointer"
                          />
                          <span
                            className={
                              task.isCompleted
                                ? 'line-through text-zinc-500'
                                : 'text-zinc-200 light:text-zinc-800 font-medium'
                            }
                          >
                            {task.title}
                          </span>
                        </div>
                        <button
                          onClick={() => deleteTask(task.id)}
                          className="text-zinc-500 hover:text-rose-400 p-1"
                        >
                          <X className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    ))}
                  </div>

                  {/* Add New Task Input */}
                  <div className="flex items-center gap-1.5 pt-1">
                    <input
                      type="text"
                      placeholder="Yeni haftalık görev ekle..."
                      value={newTaskTitle}
                      onChange={e => setNewTaskTitle(e.target.value)}
                      onKeyDown={e => {
                        if (e.key === 'Enter' && newTaskTitle.trim()) {
                          addTask(cat.id, newTaskTitle.trim());
                          setNewTaskTitle('');
                        }
                      }}
                      className="flex-1 px-3 py-1.5 rounded-xl bg-zinc-900 light:bg-white border border-zinc-800 light:border-zinc-300 text-xs text-white light:text-zinc-900 focus:outline-none focus:border-blue-500"
                    />
                    <button
                      onClick={() => {
                        if (newTaskTitle.trim()) {
                          addTask(cat.id, newTaskTitle.trim());
                          setNewTaskTitle('');
                        }
                      }}
                      className="px-3 py-1.5 rounded-xl bg-zinc-800 hover:bg-zinc-700 light:bg-zinc-300 text-xs font-semibold text-white light:text-zinc-900"
                    >
                      Ekle
                    </button>
                  </div>

                  {/* Danger Zone: Archive */}
                  <div className="pt-2 flex justify-end">
                    <button
                      onClick={() => {
                        if (confirm(`"${cat.name}" kategorisini arşivlemek istediğinize emin misiniz? Geçmiş oturumlar korunacaktır.`)) {
                          deleteCategory(cat.id);
                        }
                      }}
                      className="text-[11px] text-zinc-500 hover:text-rose-400 flex items-center gap-1 transition-colors"
                    >
                      <Trash2 className="w-3 h-3" />
                      <span>Kategoriyi Arşivle</span>
                    </button>
                  </div>
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* Modal: Create or Edit Category */}
      {isCreateModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/75 backdrop-blur-sm">
          <div className="bg-zinc-900 light:bg-zinc-50 border border-zinc-800 light:border-zinc-200 rounded-3xl w-full max-w-md p-6 shadow-2xl space-y-4 max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between">
              <h2 className="text-base font-bold text-white light:text-zinc-900 font-mono">
                {editingCategory ? 'Kategoriyi Düzenle' : 'Yeni Zaman Bütçesi'}
              </h2>
              <button
                onClick={() => setIsCreateModalOpen(false)}
                className="p-1 rounded-full text-zinc-400 hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSaveCategory} className="space-y-4">
              <div>
                <label className="block text-xs font-medium text-zinc-400 mb-1">Kategori Adı</label>
                <input
                  type="text"
                  required
                  value={formName}
                  onChange={e => setFormName(e.target.value)}
                  placeholder="Örn: Deep Work, Reading, Study"
                  className="w-full px-3 py-2 rounded-xl bg-zinc-950 light:bg-white border border-zinc-800 light:border-zinc-300 text-sm text-white light:text-zinc-900 focus:outline-none focus:border-blue-500"
                />
              </div>

              <div>
                <label className="block text-xs font-medium text-zinc-400 mb-1">Açıklama</label>
                <input
                  type="text"
                  value={formDesc}
                  onChange={e => setFormDesc(e.target.value)}
                  placeholder="Kısa not veya odak hedefi"
                  className="w-full px-3 py-2 rounded-xl bg-zinc-950 light:bg-white border border-zinc-800 light:border-zinc-300 text-sm text-white light:text-zinc-900 focus:outline-none focus:border-blue-500"
                />
              </div>

              {/* Time Budget Input (Hours and Minutes) */}
              <div>
                <label className="block text-xs font-medium text-zinc-400 mb-1">
                  Haftalık Süre Bütçesi
                </label>
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <div className="relative">
                      <input
                        type="number"
                        min="0"
                        max="168"
                        value={formHours}
                        onChange={e => setFormHours(e.target.value)}
                        className="w-full px-3 py-2 rounded-xl bg-zinc-950 light:bg-white border border-zinc-800 light:border-zinc-300 text-sm text-white light:text-zinc-900 focus:outline-none focus:border-blue-500 font-mono"
                      />
                      <span className="absolute right-3 top-2.5 text-xs text-zinc-500">saat</span>
                    </div>
                  </div>
                  <div>
                    <div className="relative">
                      <input
                        type="number"
                        min="0"
                        max="59"
                        step="5"
                        value={formMins}
                        onChange={e => setFormMins(e.target.value)}
                        className="w-full px-3 py-2 rounded-xl bg-zinc-950 light:bg-white border border-zinc-800 light:border-zinc-300 text-sm text-white light:text-zinc-900 focus:outline-none focus:border-blue-500 font-mono"
                      />
                      <span className="absolute right-3 top-2.5 text-xs text-zinc-500">dakika</span>
                    </div>
                  </div>
                </div>
              </div>

              {/* Policy Selection */}
              <div>
                <label className="block text-xs font-medium text-zinc-400 mb-1.5">
                  Bütçe Politikası
                </label>
                <div className="grid grid-cols-2 gap-2">
                  {(['strict', 'flexible', 'protected', 'deadline'] as BudgetPolicy[]).map(pol => {
                    const info = POLICY_INFO[pol];
                    const Icon = info.icon;
                    return (
                      <button
                        type="button"
                        key={pol}
                        onClick={() => setFormPolicy(pol)}
                        className={`p-2.5 rounded-xl border text-left transition-all ${
                          formPolicy === pol
                            ? 'bg-blue-600/15 border-blue-500 text-blue-400'
                            : 'bg-zinc-950/50 light:bg-zinc-100 border-zinc-800 light:border-zinc-200 text-zinc-400 hover:border-zinc-700'
                        }`}
                      >
                        <div className="flex items-center gap-1.5 font-bold text-xs">
                          <Icon className="w-3.5 h-3.5" />
                          <span>{info.label}</span>
                        </div>
                        <p className="text-[10px] text-zinc-500 mt-1 line-clamp-2">
                          {info.desc}
                        </p>
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Color Selection */}
              <div>
                <label className="block text-xs font-medium text-zinc-400 mb-1.5">Renk Kimliği</label>
                <div className="flex items-center gap-2 flex-wrap">
                  {COLOR_PALETTE.map(c => (
                    <button
                      type="button"
                      key={c}
                      onClick={() => setFormColor(c)}
                      className={`w-7 h-7 rounded-full transition-transform ${
                        formColor === c ? 'scale-125 ring-2 ring-white' : 'hover:scale-110'
                      }`}
                      style={{ backgroundColor: c }}
                    />
                  ))}
                </div>
              </div>

              {/* Icon Selection */}
              <div>
                <label className="block text-xs font-medium text-zinc-400 mb-1.5">Simge</label>
                <div className="flex items-center gap-2 flex-wrap">
                  {AVAILABLE_ICONS.map(ic => (
                    <button
                      type="button"
                      key={ic}
                      onClick={() => setFormIcon(ic)}
                      className={`w-8 h-8 rounded-xl flex items-center justify-center transition-all ${
                        formIcon === ic
                          ? 'bg-blue-600 text-white'
                          : 'bg-zinc-950 light:bg-zinc-200 text-zinc-400 hover:text-white'
                      }`}
                    >
                      <CategoryIcon name={ic} className="w-4 h-4" />
                    </button>
                  ))}
                </div>
              </div>

              {/* Submit Buttons */}
              <div className="flex items-center justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setIsCreateModalOpen(false)}
                  className="px-4 py-2 rounded-xl text-xs font-semibold text-zinc-400 hover:text-white"
                >
                  İptal
                </button>
                <button
                  type="submit"
                  className="px-5 py-2 rounded-xl bg-blue-600 hover:bg-blue-500 text-white text-xs font-bold shadow-lg shadow-blue-500/20"
                >
                  {editingCategory ? 'Kaydet' : 'Oluştur'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal: Transfer Remaining to Pool Prompt */}
      {transferPromptCategory && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/75 backdrop-blur-sm">
          <div className="bg-zinc-900 light:bg-zinc-50 border border-zinc-800 light:border-zinc-200 rounded-3xl w-full max-w-sm p-6 shadow-2xl space-y-4">
            <div className="text-center space-y-2">
              <div className="w-12 h-12 rounded-2xl bg-emerald-500/15 border border-emerald-500/30 text-emerald-400 mx-auto flex items-center justify-center">
                <ArrowRightLeft className="w-6 h-6" />
              </div>
              <h2 className="text-base font-bold text-white light:text-zinc-900">
                Kalan Süreyi Havuza Aktar
              </h2>
              <p className="text-xs text-zinc-400 light:text-zinc-600">
                "{transferPromptCategory.name}" kategorisindeki işlerini tamamladın mı? Kullanılmayan süreyi Serbest Zaman Havuzu'na bırakabilirsin.
              </p>
            </div>

            <div className="p-3.5 rounded-2xl bg-zinc-950 light:bg-zinc-200 border border-zinc-800 text-center font-mono">
              <p className="text-xs text-zinc-500 uppercase">Aktarılacak Süre</p>
              <div className="flex items-center justify-center gap-2 mt-1">
                <input
                  type="number"
                  min="5"
                  max={getCategoryTotals(transferPromptCategory.id).remainingMinutes}
                  value={transferMinutesInput}
                  onChange={e => setTransferMinutesInput(parseInt(e.target.value) || 0)}
                  className="w-24 text-center py-1 rounded-lg bg-zinc-900 light:bg-white text-lg font-bold text-emerald-400 border border-zinc-700"
                />
                <span className="text-sm font-bold text-zinc-400">dakika</span>
              </div>
            </div>

            <div className="flex items-center justify-end gap-2 pt-2">
              <button
                type="button"
                onClick={() => setTransferPromptCategory(null)}
                className="px-4 py-2 rounded-xl text-xs font-semibold text-zinc-400 hover:text-white"
              >
                Vazgeç
              </button>
              <button
                type="button"
                onClick={executePoolTransferFromPrompt}
                className="px-4 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold shadow-lg shadow-emerald-500/20"
              >
                Havuza Aktar ve Tamamla
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
