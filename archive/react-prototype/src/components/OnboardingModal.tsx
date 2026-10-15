import React, { useState } from 'react';
import { useTempo } from '../context/TempoContext.tsx';
import { storage } from '../services/storage.ts';
import {
  Clock,
  ShieldCheck,
  Droplets,
  ArrowRight,
  Sparkles,
  Flame,
  CheckCircle2,
} from 'lucide-react';

export const OnboardingModal: React.FC = () => {
  const { isOnboardingOpen, setIsOnboardingOpen } = useTempo();
  const [step, setStep] = useState(0);

  if (!isOnboardingOpen) return null;

  const slides = [
    {
      badge: 'FELSEFE',
      title: 'Own your hours.',
      subtitle: 'Personal Time Budget OS',
      desc: 'Her şeyi bitirmek zorunda değilsin. Hayatındaki etkinliklere ayıracağın zamanı bilinçli olarak seçmelisin.',
      icon: Flame,
      color: 'from-blue-600 to-indigo-600',
    },
    {
      badge: 'MİMARİ',
      title: 'Zaman Bütçelerini Koru',
      subtitle: 'Katı, Esnek ve Korunan Zaman',
      desc: 'Bir kategoriye ayrılan süre başka bir kategori tarafından rastgele çalınamaz. Katı bir bütçen bittiğinde sistem oturumu durdurarak zaman sınırlarını korur.',
      icon: ShieldCheck,
      color: 'from-indigo-600 to-purple-600',
    },
    {
      badge: 'SERBEST REZERV',
      title: 'Serbest Zaman Havuzu',
      subtitle: 'Zamanını Yeniden Dağıt',
      desc: '150 dakikalık işini 100 dakikada bitirdiğinde kalan 50 dakikayı serbest havuza aktarabilir ve dilediğin projeye dağıtabilirsin.',
      icon: Droplets,
      color: 'from-blue-500 to-cyan-500',
    },
  ];

  const currentSlide = slides[step];
  const Icon = currentSlide.icon;

  const handleNext = () => {
    if (step < slides.length - 1) {
      setStep(step + 1);
    } else {
      storage.setOnboarded(true);
      setIsOnboardingOpen(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/90 backdrop-blur-xl">
      <div className="relative bg-zinc-900 border border-zinc-800 rounded-3xl w-full max-w-sm p-6 shadow-2xl text-center space-y-5 overflow-hidden">
        {/* Glow */}
        <div className="absolute -top-20 left-1/2 -translate-x-1/2 w-48 h-48 bg-blue-500/15 rounded-full blur-3xl pointer-events-none" />

        {/* Step Indicator */}
        <div className="flex items-center justify-center gap-1.5 pt-1">
          {slides.map((_, i) => (
            <div
              key={i}
              className={`h-1.5 rounded-full transition-all duration-300 ${
                i === step ? 'w-6 bg-blue-500' : 'w-1.5 bg-zinc-800'
              }`}
            />
          ))}
        </div>

        {/* Hero Icon */}
        <div
          className={`w-16 h-16 rounded-3xl bg-gradient-to-tr ${currentSlide.color} text-white mx-auto flex items-center justify-center shadow-xl shadow-blue-500/20`}
        >
          <Icon className="w-8 h-8" />
        </div>

        {/* Text */}
        <div className="space-y-1.5">
          <span className="text-[10px] font-mono tracking-widest text-blue-400 font-bold uppercase">
            {currentSlide.badge}
          </span>
          <h2 className="text-xl font-black text-white tracking-tight">{currentSlide.title}</h2>
          <p className="text-xs font-semibold text-zinc-300">{currentSlide.subtitle}</p>
          <p className="text-xs text-zinc-400 pt-1 leading-relaxed">{currentSlide.desc}</p>
        </div>

        {/* Bottom Button */}
        <div className="pt-2">
          <button
            onClick={handleNext}
            className="w-full py-3 rounded-2xl bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-500 hover:to-indigo-500 text-white font-bold text-xs shadow-lg shadow-blue-500/25 flex items-center justify-center gap-2 active:scale-95 transition-all"
          >
            <span>{step === slides.length - 1 ? 'Uygulamaya Başla' : 'Devam Et'}</span>
            <ArrowRight className="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  );
};
