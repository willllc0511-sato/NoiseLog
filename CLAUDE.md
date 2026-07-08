# CLAUDE.md

Guidance for AI assistants (Claude Code) working in this repository.

## Project overview

**NoiseLog（騒音ログ）** is a native iOS app for measuring, recording, and
reporting ambient noise — aimed at users documenting noise problems (e.g.
neighbor/upstairs noise) as evidence. The app measures decibel levels in real
time from the microphone, records short audio clips, stores records locally,
and generates monthly PDF reports.

- **Platform:** iOS 17.0+ (SwiftUI, SwiftData, StoreKit 2, AVFoundation)
- **Language:** Swift 5.9
- **UI language:** Japanese (all user-facing strings are in Japanese)
- **Distribution:** App Store (paid subscription). Display name: 騒音ログ.
- **Bundle ID:** `com.will-llc.NoiseLog` (team `2YDCV4Y5W9`)

The app is dark-mode only (`.preferredColorScheme(.dark)` in
`NoiseLogApp.swift`).

## Build & project generation

This project uses **[XcodeGen](https://github.com/yonascalen/XcodeGen)**. The
Xcode project is generated from `project.yml` and is **git-ignored**
(`.gitignore` excludes `*.xcodeproj`). The `NoiseLog.xcodeproj/project.pbxproj`
present in the tree is a generated artifact — **do not hand-edit it**; edit
`project.yml` and regenerate.

```bash
# Regenerate the Xcode project after changing project.yml or adding files
xcodegen generate

# Open in Xcode
open NoiseLog.xcodeproj

# Build number, version, deployment target, entitlements/Info.plist keys
# all live in project.yml — change them there, then regenerate.
```

Note: this is a macOS/Xcode project. It **cannot be built on Linux** — there is
no `xcodebuild` in the remote environment here. Make source changes and reason
about them statically; the human runs the actual build/archive in Xcode.

Key `project.yml` fields you may need to touch:
- `settings.base.MARKETING_VERSION` — user-facing version (e.g. `1.0.1`)
- `settings.base.CURRENT_PROJECT_VERSION` — build number (bumped every release,
  currently `23`; commit messages call these "ビルドNN")
- `deploymentTarget.iOS` — minimum iOS version
- `INFOPLIST_KEY_NSMicrophoneUsageDescription` — mic permission string
- `UIBackgroundModes: [audio]` — allows measurement to continue in background

`ExportOptions.plist` holds App Store export settings (`method: app-store`).

## Source layout

```
NoiseLog/
├── NoiseLogApp.swift          @main entry point; sets .modelContainer(for: NoiseRecord.self)
├── ContentView.swift          Root TabView (4 tabs: ホーム / 記録一覧 / レポート / 設定)
├── Models/
│   └── NoiseRecord.swift       SwiftData @Model: timestamp, decibelLevel, memo, audioFilePath
├── Services/
│   ├── AudioManager.swift       Mic → real-time dB (AVAudioEngine tap + RMS), recording (AVAudioRecorder)
│   └── SubscriptionManager.swift StoreKit 2 subscription (singleton, @MainActor)
├── Theme/
│   └── AppTheme.swift           Colors, dB→color/label mapping, DemoMode flag, Notification.Name
├── Views/
│   ├── HomeView.swift           dB meter + record button (auto-saves ≥5s recordings)
│   ├── RecordListView.swift      List of records with date filter; row views
│   ├── RecordDetailView.swift    Single record: dB, memo editing, audio playback
│   ├── ReportView.swift          Monthly stats + hourly chart + PDF/audio export
│   ├── SettingsView.swift        Subscription, support links, restore, version
│   └── SubscriptionSheetView.swift  Purchase paywall sheet
├── Configuration.storekit      StoreKit local testing config (bundled as a resource)
├── Info.plist                  Generated from project.yml properties
├── Assets.xcassets             App icon, accent color
└── LaunchScreen.storyboard

docs/                            GitHub Pages site (served at willllc0511-sato.github.io/NoiseLog/)
├── privacy-policy.html
├── terms.html                  利用規約
└── tokushoho.html              特定商取引法に基づく表示 (required for Japanese paid apps)
```

## Architecture & conventions

### Data
- **Persistence is SwiftData.** `NoiseRecord` is the only `@Model`. Views query
  it with `@Query(sort: \NoiseRecord.timestamp, order: .reverse)` and mutate via
  `@Environment(\.modelContext)`.
- **Audio files are stored on disk**, not in SwiftData. Only the file *name*
  (`audioFilePath`, e.g. `recording_1712540000.m4a`) is persisted; the full path
  is reconstructed from the Documents directory at read time. When adding audio
  handling, always resolve paths via
  `FileManager.default.urls(for: .documentDirectory, ...)[0]` + last path
  component — never store absolute paths.

### Audio (`AudioManager`)
- An `ObservableObject`, instantiated per-view with `@StateObject` (HomeView).
- Real-time dB: installs a tap on `AVAudioEngine.inputNode`, computes RMS,
  converts with `20*log10(rms) + 100` (an empirical calibration offset — see the
  inline comment "実機で要調整" / "needs tuning on device"). A 500ms display timer
  applies exponential smoothing (`smoothingFactor = 0.3`).
- Recording uses `AVAudioRecorder` (AAC/m4a, 44.1kHz mono). **Max duration is
  300s** (`maxRecordingDuration`); auto-stops at the limit. Peak dB during a
  recording is tracked in `peakDecibel` and is what gets saved.
- Guards for the simulator (invalid audio format → skips) and mic permission.

### Subscription (`SubscriptionManager`)
- **StoreKit 2**, singleton `SubscriptionManager.shared`, `@MainActor`.
- Single product: monthly auto-renewing subscription, product ID
  **`com.willllc.NoiseLog.monthly.v2`** (200 JPY/月). Note the ID uses
  `willllc` while the app bundle prefix is `will-llc` — this is intentional; do
  not "fix" it.
- `loadProduct()` retries 3× with exponential backoff under a 10s overall
  timeout (`loadProductTimedOut` drives a fallback UI).
- Entitlement is derived from `Transaction.currentEntitlements`; a detached
  `Transaction.updates` listener keeps `isSubscribed` fresh (handles Ask-to-Buy
  / SCA `.pending` approvals that resolve later).
- `restoreWithResult()` calls `AppStore.sync()` and returns a `RestoreResult`.
- Purchase/verification failure paths set `purchaseMessage` with guidance to
  restore or contact support rather than silently failing — preserve this
  behavior; it's App-Store-review-driven.

### Feature gating
Recording and record-saving are **gated behind an active subscription**
(`HomeView.toggleRecording` checks `subscriptionManager.isSubscribed`, shows an
alert → paywall). The paywall (`SubscriptionSheetView`) is presented from Home,
Settings, and Report. When adding premium features, gate them the same way and
list them in `SubscriptionSheetView.featureRow(...)`.

### Theming (`AppTheme`)
- All colors come from `AppTheme` (dark navy background, card background, and
  three accent colors: green/yellow/red).
- **dB → semantics** is centralized: `colorForDecibel` and `labelForDecibel`
  use thresholds **<40 = 静か (green), 40–60 = 普通 (yellow), ≥60 = うるさい
  (red)**. Reuse these helpers everywhere; never re-implement the thresholds.

### DemoMode
`DemoMode.isEnabled` (in `AppTheme.swift`) is a **screenshot/demo flag**. When
`true`, list/report views show hard-coded sample data (`DemoRecord.samples`,
`Self.demoHourlyData`, fixed stat values) instead of real records. **It must be
`false` in shipped builds** — the comment says "撮影後にfalseに戻す" (set back to
false after taking screenshots). Verify it's `false` before any release commit.

### PDF export (`ReportView`)
Monthly reports render to PDF via `UIGraphicsPDFRenderer` (`generatePDF()`) and
are shared together with the month's audio files through a `ShareSheet`
(`UIActivityViewController` wrapped as `UIViewControllerRepresentable`). Temp
files are cleaned up on sheet dismiss (`cleanupTempFiles`).

### Navigation / cross-view signaling
Tab switching to Settings is done via a `NotificationCenter` notification
`Notification.Name.openSubscriptionSettings` (defined in `AppTheme.swift`,
observed in `ContentView`). Prefer this existing channel over adding new global
state.

## Conventions to follow

- **Comments and doc comments are in Japanese** (`///` above types/methods).
  Match this style — write new comments in Japanese, concise and descriptive.
- **User-facing strings are Japanese**, hard-coded inline (no localization
  catalog). Keep new strings Japanese and consistent in tone with existing ones.
- Date formatting uses `DateFormatter` with `Locale(identifier: "ja_JP")` and
  formats like `"M/d (EEE) HH:mm"`. Reuse the static formatters in the row views.
- Support / legal URLs point at the GitHub Pages site
  (`https://willllc0511-sato.github.io/NoiseLog/…`) and the support email is
  `support@will0511.com`. Keep these in sync across `SettingsView` and the
  `docs/` HTML if they change.
- `MARK: -` section comments organize every non-trivial file — keep them.
- SwiftUI idioms: `@StateObject` for owned observable objects, `@ObservedObject`
  for the shared subscription singleton, `@Query`/`@Bindable` for SwiftData.

## Git workflow

- Default branch is `main`. Development for the current task happens on the
  designated feature branch (do not push elsewhere without permission).
- **Commit messages are in Japanese** and typically reference the build number,
  e.g. `feat: 録音上限300秒・PDF+音声一括共有（ビルド17）` or `ビルド23: …`. Follow
  this convention; when a change corresponds to a release, bump
  `CURRENT_PROJECT_VERSION` in `project.yml` and mention the build number.
- Do **not** commit generated artifacts beyond what's already tracked; the
  `.xcodeproj` is git-ignored by policy (the checked-in one is a convenience
  artifact).
- Do not open a PR unless explicitly asked.

## Release checklist (App Store)

When preparing a release, verify:
1. `DemoMode.isEnabled == false` in `AppTheme.swift`.
2. `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` bumped in `project.yml`.
3. Product ID (`com.willllc.NoiseLog.monthly.v2`) and price match App Store
   Connect and `Configuration.storekit`.
4. Legal pages (`docs/`) and support email/URLs are current and reachable.
5. `xcodegen generate`, then archive from Xcode using `ExportOptions.plist`.
