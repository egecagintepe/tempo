/**
 * TEMPO — Local Notification Service
 */

class NotificationService {
  public enabled: boolean = true;

  async requestPermission(): Promise<boolean> {
    if (typeof window === 'undefined' || !('Notification' in window)) {
      return false;
    }
    try {
      const permission = await Notification.requestPermission();
      return permission === 'granted';
    } catch {
      return false;
    }
  }

  isPermissionGranted(): boolean {
    if (typeof window === 'undefined' || !('Notification' in window)) {
      return false;
    }
    return Notification.permission === 'granted';
  }

  notify(title: string, body: string, icon?: string) {
    if (!this.enabled || !this.isPermissionGranted()) return;
    try {
      new Notification(title, {
        body,
        icon: icon || '/favicon.ico',
      });
    } catch {
      // Fallback
    }
  }
}

export const notificationService = new NotificationService();
