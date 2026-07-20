# AGENTS.md

## Commands

```sh
# Build (matches CI)
xcodebuild clean build analyze -project "Front Row.xcodeproj" -scheme "Front Row" CODE_SIGNING_ALLOWED=NO

# Test — must pass before a PR merges
xcodebuild test -project "Front Row.xcodeproj" -scheme "Front Row" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO

# Lint — must pass before a PR merges
swift-format lint -s -p -r ./

# Auto-fix formatting
swift-format format -p -r -i ./
```

## Architecture

- Target macOS Sequoia 15.6 or later.
- Do not introduce third-party frameworks without asking first.

## Code

- All shared data should use `@Observable` classes with `@State` (for ownership) and `@Bindable` / `@Environment` (for passing).
- Strongly prefer not to use `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject`, or `@EnvironmentObject` unless they are unavoidable, or if they exist in legacy/integration contexts when changing architecture would be complicated.
- Assume strict Swift concurrency rules are being applied.
- Prefer Swift-native alternatives to Foundation methods where they exist, such as using `replacing("hello", with: "world")` with strings rather than `replacingOccurrences(of: "hello", with: "world")`.
- Prefer modern Foundation API, for example `URL.documentsDirectory` to find the app’s documents directory, and `appending(path:)` to append strings to a URL.
- Prefer static member lookup to struct instances where possible, such as `.circle` rather than `Circle()`, and `.borderedProminent` rather than `BorderedProminentButtonStyle()`.
- Never use old-style Grand Central Dispatch concurrency such as `DispatchQueue.main.async()`. If behavior like this is needed, always use modern Swift concurrency.
- Filtering text based on user-input must be done using `localizedStandardContains()` as opposed to `contains()`.
- Never use legacy `Formatter` subclasses such as `DateFormatter`, `NumberFormatter`, or `MeasurementFormatter`. Always use the modern `FormatStyle` API instead. For example, to format a date, use `myDate.formatted(date: .abbreviated, time: .shortened)`. To parse a date from a string, use `Date(inputString, strategy: .iso8601)`. For numbers, use `myNumber.formatted(.number)` or custom format styles.
- Comments shape: 1-3 short lines; Add comment only if it explains something that isn't immediately obvious from reading the code. No syntax narration, PR/user-specific lore, or obvious mechanics.

- Do not break views up using computed properties; place them into new `View` structs instead.
- Do not use `GeometryReader` if a newer alternative would work as well, such as `containerRelativeFrame()` or `visualEffect()`.
- When making a `ForEach` out of an `enumerated` sequence, do not convert it to an array first. So, prefer `ForEach(x.enumerated(), id: \.element.id)` instead of `ForEach(Array(x.enumerated()), id: \.element.id)`.
- Place view logic into view models or similar, so it can be tested.
- Avoid `AnyView` unless it is absolutely required.
- Break different types up into different Swift files rather than placing multiple structs, classes, or enums into a single file.

## GitHub PRs

- See `CONTRIBUTING.md`.

## Git

- Commits: conventional-ish, concise, grouped.
