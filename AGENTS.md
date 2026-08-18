# AGENTS.md

## Commands

```sh
# Build, analyze, and test — CI only
xcodebuild clean analyze test -project "Front Row.xcodeproj" -scheme "Front Row" -destination "platform=macOS" CODE_SIGNING_ALLOWED=NO

# Build, analyze, and test — locally. Never pass CODE_SIGNING_ALLOWED=NO here: it
# leaves "Front Row UI Tests-Runner.app" unsigned, and Gatekeeper answers the run
# with "is damaged and can't be opened", which hangs until the dialog is dismissed.
xcodebuild clean analyze test -project "Front Row.xcodeproj" -scheme "Front Row" -destination "platform=macOS"

# Lint — must pass before a PR merges
swift-format lint -s -p -r ./

# Auto-fix formatting
swift-format format -p -r -i ./
```

## Architecture

- Target macOS Sequoia 15.6 or later.
- Do not introduce third-party frameworks without asking first.
- Group source files by feature, not by layer. A feature folder holds its models and its views together.
- A feature that outgrows one folder splits by kind into `Models/`, `Views/`, and any domain subfolder it needs (`Conversion/FFmpeg/`). Small features stay flat.
- The root `UI/` and `Models/` folders are only for types used by two or more features. `Main Menu/` and `FrontRowApp` consume everything, so neither justifies a promotion on its own — they count only alongside a second feature.

## Code

- All shared data should use `@Observable` classes with `@State` (for ownership) and `@Bindable` / `@Environment` (for passing).
- Strongly prefer not to use `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject`, or `@EnvironmentObject` unless they are unavoidable, or if they exist in legacy/integration contexts when changing architecture would be complicated.
- Assume strict Swift concurrency rules are being applied.
- Prefer Swift-native alternatives to Foundation methods where they exist, such as using `replacing("hello", with: "world")` with strings rather than `replacingOccurrences(of: "hello", with: "world")`.
- Prefer modern Foundation API, for example `URL.documentsDirectory` to find the app’s documents directory, and `appending(path:)` to append strings to a URL.
- Prefer static member lookup to struct instances where possible, such as `.circle` rather than `Circle()`, and `.borderedProminent` rather than `BorderedProminentButtonStyle()`.
- New code should use modern Swift concurrency rather than old-style Grand Central Dispatch — prefer `Task { @MainActor in }` or actor isolation to `DispatchQueue.main.async()`. Leave working GCD code alone; some APIs only take a queue, and the replacements differ in delivery semantics.
- Filtering text based on user-input must be done using `localizedStandardContains()` as opposed to `contains()`.
- Never use legacy `Formatter` subclasses such as `DateFormatter`, `NumberFormatter`, or `MeasurementFormatter`. Always use the modern `FormatStyle` API instead. For example, to format a date, use `myDate.formatted(date: .abbreviated, time: .shortened)`. To parse a date from a string, use `Date(inputString, strategy: .iso8601)`. For numbers, use `myNumber.formatted(.number)` or custom format styles.
- Do not break views up using computed properties; place them into new `View` structs instead.
- Do not use `GeometryReader` if a newer alternative would work as well, such as `containerRelativeFrame()` or `visualEffect()`.
- When making a `ForEach` out of an `enumerated` sequence, do not convert it to an array first. So, prefer `ForEach(x.enumerated(), id: \.element.id)` instead of `ForEach(Array(x.enumerated()), id: \.element.id)`.
- Place view logic into view models or similar, so it can be tested.
- Avoid `AnyView` unless it is absolutely required.
- Name a Swift file after the primary type inside it. That file may also hold the subviews and helpers that exist to serve that type, whatever their size — a screen and the rows, cards and labels only it builds belong together.
- Split a type out when something that never touches the file's primary type depends on it. That is the test, not line count.
- Name a screen `…View`, its `@Observable` state `…Model` on the same stem (`InspectorView` / `MediaInspectorModel`), and a component inside a screen for the role it plays — `Row`, `Card`, `Button`, `Menu`, `Picker`, `Label`, `Grid`, `Sheet`, `Alert`. Reach for `…View` on a component only when no role noun fits.
- A `ViewModifier` is named `…Modifier` and lives in the file with the `extension View` convenience that applies it.

## Comments

Applies to every file — Swift, YAML, shell, config.

- 1-3 short lines, only when the code cannot say it itself.
- Describe the code as it is. Not what it used to be, what was tried, or why an alternative was rejected — that belongs in the commit message.
- No syntax narration, no obvious mechanics, no references to PRs or people.

## GitHub PRs

- See `CONTRIBUTING.md`.

## Git

- Commits: conventional-ish, concise, grouped.
