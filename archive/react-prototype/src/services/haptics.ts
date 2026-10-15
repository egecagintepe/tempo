/**
 * TEMPO — Haptics Vibration Service
 */

class HapticsService {
  public enabled: boolean = true;

  light() {
    if (!this.enabled || typeof navigator === 'undefined' || !navigator.vibrate) return;
    try {
      navigator.vibrate(15);
    } catch {}
  }

  medium() {
    if (!this.enabled || typeof navigator === 'undefined' || !navigator.vibrate) return;
    try {
      navigator.vibrate(40);
    } catch {}
  }

  heavy() {
    if (!this.enabled || typeof navigator === 'undefined' || !navigator.vibrate) return;
    try {
      navigator.vibrate([60, 50, 60]);
    } catch {}
  }

  alarm() {
    if (!this.enabled || typeof navigator === 'undefined' || !navigator.vibrate) return;
    try {
      navigator.vibrate([100, 80, 100, 80, 200]);
    } catch {}
  }
}

export const hapticsService = new HapticsService();
