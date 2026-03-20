# HabitCoach

An iOS + Apple Watch app that delivers interval-based haptic reminders to help users break bad movement habits during physical activity.

## Use Cases

- Physical therapy / injury recovery
- Equestrian training (solo riding)
- Sports form training (golf, basketball, tennis)
- Music practice posture

## Tech Stack

- Swift / SwiftUI (iOS 17+, watchOS 10+)
- WKHapticType for Apple Watch haptics
- HealthKit workout session for background execution
- WatchConnectivity for iPhone ↔ Watch sync
- SwiftData (iOS) / UserDefaults (watchOS) for persistence

## Development

Open `HabitCoach/HabitCoach.xcodeproj` in Xcode 16+.

Requires:
- macOS 15+
- Xcode 16+
- Apple Developer account (for HealthKit and device testing)

## Research

The `research/` directory contains feasibility studies and market research that informed this project. See `research/habit-reminder-wearable/` for the technical feasibility report.
