# Contributing to TEMPO

We welcome contributions from the community!

## Development Guidelines

1. **Flutter & Dart Standards:** Ensure clean, formatted code with zero analyzer warnings (`flutter analyze`).
2. **Deterministic Time Engine:** Any changes to time calculations, budget arithmetic, or pool mechanics must be accompanied by comprehensive unit tests in `test/time_engine_test.dart`.
3. **Privacy First:** Never commit personal categories, student schedules, or real-life sensitive data into public config or test fixtures. Always use generic public examples (e.g. Deep Work, Study, Reading, Fitness).
4. **Offline First:** Do not add third-party cloud SDKs, ads, or tracking libraries to core functionality.
