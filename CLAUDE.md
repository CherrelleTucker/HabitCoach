# HabitCoach Development Guidelines

## Project

iOS + Apple Watch haptic reminder app. Swift/SwiftUI, MVVM architecture.

- **iOS target**: HabitCoach (iOS 17+)
- **watchOS target**: HabitCoachWatch (watchOS 10+)
- **Bundle ID**: com.ctuckersolutions.habitcoach

## Architecture

- **Pattern**: MVVM with SwiftUI
- **Shared code**: `Shared/` directory has target membership in both iOS and watchOS targets
- **Models**: Plain structs conforming to `Codable` and `Identifiable`
- **ViewModels**: `@Observable` classes (iOS 17+ Observation framework)
- **Services**: Singleton or injected service classes wrapping Apple frameworks

## Conventions

- Views in `Views/` directories per target
- ViewModels suffixed with `ViewModel`
- Services suffixed with `Service` or `Manager`
- No third-party dependencies — Apple frameworks only

## Key Services

| Service | Purpose |
|---------|---------|
| `WorkoutManager` | HealthKit workout session for background execution on Watch |
| `HapticService` | WKHapticType playback on Watch |
| `TimerService` | Core interval timer logic (shared) |
| `ConnectivityService` | WatchConnectivity iPhone ↔ Watch sync |
| `PersistenceService` | SwiftData (iOS) / UserDefaults (watchOS) |

## Build & Run

- Open `HabitCoach/HabitCoach.xcodeproj` in Xcode 16+
- Select scheme: HabitCoach (iOS) or HabitCoachWatch (watchOS)
- Cmd+R to run

## Committing

See [GIT_GUIDELINES.md](GIT_GUIDELINES.md) for commit conventions.

## Research Reference

- `research/habit-reminder-wearable/report.md` — full technical feasibility study
- `research/habit-reminder-wearable/client_feasibility_report.md` — client-facing report
- `research/habit-reminder-wearable/requirements.md` — core requirements
