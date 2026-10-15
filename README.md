# TEMPO — Personal Time Budget OS
> **"Own your hours."**  
> *You don't have to finish everything. You must consciously allocate the time you dedicate to everything.*

![Flutter](https://img.shields.io/badge/Flutter-3.47.7-blue?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.13.5-0175C2?logo=dart)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Web%20%7C%20Desktop-green)
![License](https://img.shields.io/badge/License-MIT-purple)
![Architecture](https://img.shields.io/badge/Architecture-Riverpod%20%2B%20SQLite%2FDrift-orange)
![Privacy](https://img.shields.io/badge/Privacy-100%25%20Offline%20%26%20Local-success)

---

## What is TEMPO?

**TEMPO** is a high-performance, local-first Time Budget Operating System designed to help individuals consciously allocate, protect, and redistribute their finite hours.

Unlike conventional Pomodoro timers or endless to-do lists, TEMPO operates like a financial budget for your time:

1. **Category Budgets:** Each activity receives a weekly allocation in minutes.
2. **Behavioral Policies:**
   - **Strict:** Session automatically halts when the budget runs out. Starting a new session is blocked unless the budget is increased or time is transferred from the pool.
   - **Flexible:** Soft limit with gentle warnings; allows tracked overtime.
   - **Protected:** High-priority creative or reflective work that cannot be transferred to other categories without explicit confirmation.
   - **Deadline:** Time-sensitive project milestones with deadline counters.
3. **Free Time Pool (Serbest Zaman Havuzu):**
   - Finish a 120-minute task in 80 minutes?
   - Complete the category's weekly tasks, and release the remaining 40 minutes into the **Central Time Pool**.
   - Reallocate pool minutes to creative writing, personal builds, or guilt-free leisure with a single tap.
   - Every transaction is ledger-tracked and can be undone instantly.

---

## Core Architecture

- **Domain Engine:** Deterministic, unit-tested time engine enforcing budget invariants:
  $$\text{Effective Target} = \text{Base Target} + \text{Transfers In} - \text{Transfers Out}$$
  $$\text{Remaining Budget} = \text{Effective Target} - \text{Active Time}$$
  $$\text{Pool Balance} = \sum \text{Rollovers In} - \sum \text{Allocations Out}$$
- **State Persistence:** SQLite database via Drift & path_provider. Full transaction safety, foreign key integrity, and zero cloud dependency.
- **Background Accuracy:** Wall-clock segment timestamps (`DateTime.now()`). If the app is killed or backgrounded, time arithmetic remains exact upon resume.
- **Android Notifications:** Local alarms for budget exhaustion, 80%/95% warnings, and break cycle completions.
- **Editorial UI Design:**
  - Obsidian Dark, Architectural Light, and Pure OLED Black themes.
  - Monospace tabular countdown typography.
  - Sticky mini-player for running sessions.

---

## Dual Distribution Model

TEMPO is built from a single Flutter codebase with two distinct build profiles:

| Feature | TEMPO Public (Open Source) | TEMPO Personal (Private Edition) |
|---|---|---|
| **Distribution** | GitHub Public Release | Local Private Build |
| **Package ID** | `com.tempo.tempo` | `com.tempo.tempo.personal` |
| **App Name** | `TEMPO` | `TEMPO Personal` |
| **Database Storage** | Isolated Public SQLite DB | Isolated Personal SQLite DB |
| **Seed Data** | `config/seeds/public.json` | `.local/personal_profile.json` (Git-ignored) |
| **Default Categories** | Deep Work, Study, Reading, Language, Fitness, Projects, Writing | Custom course syllabus, project sprints, internship schedule, exams |

---

## Building from Source

### Prerequisites
- Flutter SDK `3.47.7` or higher
- Android SDK 36.0+
- Java JDK 17+ (or bundled Android Studio JBR)

```bash
# Verify environment
flutter doctor -v

# Fetch dependencies
flutter pub get
```

### 1. Build Public Release APK
```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_public.ps1
```
Output: `build/app/outputs/flutter-apk/TEMPO-Public-release.apk`

### 2. Build Personal Edition APK
```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_personal.ps1
```
Output: `TEMPO-Personal-release.apk`

---

## Running Automated Tests

```bash
# Run unit and domain engine tests
flutter test

# Run privacy verification audit
powershell -ExecutionPolicy Bypass -File scripts/verify_privacy.ps1
```

---

## License

MIT License. See [LICENSE](LICENSE) for details.
