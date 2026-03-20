# HabitCoach Android Roadmap

## Overview

HabitCoach Android would be a **phone-only** app initially, mirroring the iOS standalone experience: interval timer with haptic buzzes, sounds, presets, session history, and premium IAP.

## Scope: Phase 1 (Phone Only)

### Core Features
- Interval timer with configurable duration, end conditions
- Haptic feedback via Android's `VibrationEffect` API (API 26+)
  - Randomized: vary amplitude/pattern each buzz
  - Consistent: fixed vibration pattern
  - Morse code: dot/dash sequences using amplitude control
- Audio feedback via `SoundPool` or `MediaPlayer`
- Preset management (create, edit, delete)
- Session history with local storage (Room database)
- Freemium model with Google Play Billing Library

### Tech Stack
- **Language**: Kotlin
- **UI**: Jetpack Compose (Material 3)
- **Architecture**: MVVM with StateFlow/SharedFlow
- **Storage**: Room (SQLite) for presets and sessions
- **IAP**: Google Play Billing Library v7+
- **Min SDK**: API 26 (Android 8.0) — for VibrationEffect API

### Haptic Considerations
- Android haptic quality varies enormously by device manufacturer
- `VibrationEffect.createOneShot(duration, amplitude)` for basic buzzes
- `VibrationEffect.createWaveform()` for Morse code patterns
- Some devices lack amplitude control — fall back to on/off vibration
- Test on Samsung, Pixel, and at least one budget device

### Shared Logic
The timer logic, Morse code table, and interval math are pure algorithms that can be ported directly from Swift to Kotlin. No platform-specific dependencies in:
- `TimerService` (interval tracking, elapsed time, end conditions)
- `MorsePlayer` (character-to-morse mapping, duration estimation)
- `SessionProfile` / `Session` models

## Scope: Phase 2 (Wear OS — Future)

### Considerations
- **Platform**: Wear OS 4+ (Kotlin, Jetpack Compose for Wear)
- **Haptics**: `Vibrator` API on Wear OS — simpler than Apple Watch haptics
  - No equivalent to WKHapticType's rich patterns
  - Limited to vibration on/off with amplitude
- **Background execution**: No HealthKit workout equivalent
  - Use Ongoing Activity API + foreground service to keep timer alive
  - Battery life impact is a concern
- **Phone-Watch sync**: Data Layer API (Google Play Services)
  - Similar concept to WatchConnectivity but different API
  - Requires Google Play Services on both devices

### Why Wait on Wear OS
1. Haptic hardware on most Wear OS watches is significantly weaker than Apple Watch
2. Background execution model is less reliable — no workout session guarantee
3. Device fragmentation requires more testing
4. Phone-only covers 90%+ of the use case
5. Can gauge Android demand from phone app before investing in Wear OS

## Estimated Effort

| Component | Estimate |
|-----------|----------|
| Android phone app (full feature parity) | 2-3 weeks |
| Google Play Billing integration | 2-3 days |
| Play Store listing + review | 1 week |
| Wear OS companion (future) | 2-3 weeks additional |

## Key Differences from iOS

| Feature | iOS | Android |
|---------|-----|---------|
| Haptics | UIImpactFeedbackGenerator (rich) | VibrationEffect (basic amplitude) |
| Background timer | HealthKit workout session (watch) | Foreground service + notification |
| IAP | StoreKit 2 | Google Play Billing Library |
| Storage | UserDefaults + SwiftData | Room (SQLite) + DataStore |
| Watch sync | WatchConnectivity | Data Layer API |
| Screen wake | isIdleTimerDisabled | FLAG_KEEP_SCREEN_ON |
