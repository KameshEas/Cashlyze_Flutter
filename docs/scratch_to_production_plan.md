# Cashlyze Flutter Delivery Plan — From Scratch to Production

## Environment Setup
- Install Android `cmdline-tools` and set `ANDROID_SDK_ROOT` to the SDK path (Windows: `C:\Users\<you>\AppData\Local\Android\sdk`).
- Optional: Install Visual Studio with the "Desktop development with C++" workload for Windows desktop builds.
- macOS is required for iOS builds and App Store submission; plan iOS work on a Mac later.
- Verify tools with `flutter doctor -v`; confirm `flutter`, `dart`, `adb`, and Chrome are available.

## Project Initialization
- Create a Flutter app with null-safety enabled.
- Add core packages:
  - Navigation: `go_router`
  - State management: `flutter_riverpod` (or `bloc`)
  - Storage: `drift` or `sqflite`, plus `shared_preferences`
  - HTTP: `dio`
  - Charts: `fl_chart`
  - Animations: `lottie`
  - Localization: `intl`, `flutter_localizations`
  - Export/Sharing: `csv`, `share_plus`
  - Android SMS (Android only): `telephony` or `sms_advanced` (ensure Play policy compliance)
- Establish folder structure:
  - `lib/core` (theme, tokens, services, utils)
  - `lib/routes` (go_router configuration)
  - `lib/widgets` (shared components)
  - `lib/features` (onboarding, accounts, transactions, budgets, insights, settings)

## Architecture
- MVVM with Riverpod providers (ViewModel-like) and repositories/services.
- `core/theme`: implement design tokens (colors, typography, spacing, elevation, motion) and light/dark `ThemeData`.
- `core/services`: storage, analytics, formatters; offline queue and exponential backoff for network.
- `routes/app_router.dart`: bottom tabs + nested stacks; deep links `cashlyze://`.

## Phase Roadmap

### Phase 0 — Foundations & Splash
- Tokens and theming; semantic colors and typography.
- Native splash (iOS LaunchScreen, Android drawable) + in-app animated splash (Lottie/Hero) with asset preloading.
- Navigation scaffold via `go_router`; storage baseline with `shared_preferences`.

### Phase 1 — Onboarding & Consent
- Screens: welcome, value props, privacy note, demo mode toggle.
- Analytics opt-in toggle (persisted) and Data Practices explainer.
- Route guard to show onboarding only on first run.

### Phase 2 — Accounts & Data Sources
- Provider stub UI for account linking; manual account entry with validation.
- Android SMS inbox auto-import with runtime permission; iOS fallback via paste/upload (SMS inbox not permitted).
- Parser: normalize merchant, amount, date; idempotent dedupe; logging.

### Phase 3 — Transactions
- List with filters (date, category, amount, merchant) and search.
- Detail view; batch edit (multi-select, apply category/notes, undo);
- Manual add/edit forms with validation; persistence via local DB (drift/sqflite) and repositories.

### Phase 4 — Budgets
- Planner with per-category limits and animated progress bars.
- Bind spent per category from Transactions; warnings ≥ 80% usage.
- CRUD categories; rollover; period selection (month/quarter); notifications; history and charts.

### Phase 5 — Insights
- Trend analysis (weekly/monthly) and category breakdowns.
- Charts via `fl_chart` (line/area, donut) with accessible legends.
- Basic anomaly detection (spikes, category drift).

### Phase 6 — Theming & Accessibility
- Global theme provider and Settings toggle.
- Accessibility: WCAG AA contrast; text scaling; `Semantics` roles; reduced motion; touch targets ≥ 44×44dp.

### Phase 7 — Localization & Internationalization
- `intl` setup with ARB/JSON files and locale fallbacks.
- RTL layout mirroring; icon direction; gestures; currency/date formatting; ICU pluralization.

### Phase 8 — Analytics & Privacy
- Opt-in analytics (screen views, taps); anonymized performance metrics.
- Data retention (rotate logs, anonymize after 30–90 days); export/delete options; privacy explainer.

### Phase 9 — Error Handling & Offline
- Error boundaries and friendly fallback screens; retry actions.
- Offline-first: queue writes; sync on reconnect; show sync status and last updated.
- Network strategy: exponential backoff for transient failures.

### Phase 10 — Performance
- Startup targets: first interactive < 2.5s (warm), < 5s (cold) on mid-range devices.
- Techniques: skeletons/shimmer for loads > 300ms; memoization; lazy lists; image optimization; avoid jank (≤16ms frame times).

### Phase 11 — Testing
- Unit tests: providers/ViewModels, repositories, parsers.
- Widget tests: screens/components; accessibility (`Semantics`) checks.
- Integration tests: navigation flows; data fetch with mocks; golden tests for visuals.
- E2E: `integration_test` for cross-flow validation.

### Phase 12 — Dev Experience & CI/CD
- CI: format, analyze, tests; static analysis.
- CD: Android/iOS build pipelines; environment configs; secrets handling.
- Versioning: tokens and component library governance; changelogs.

### Phase 13 — Store Readiness (Apple & Google)
- Assets & metadata: icons, splash, screenshots, descriptions, categories, age ratings.
- Permissions:
  - iOS: do not attempt SMS inbox reading; provide alternative import.
  - Android: request `READ_SMS` only with explicit opt-in and clear consent.
- Privacy compliance: Data Safety (Google Play), Privacy Nutrition Labels (Apple).
- Signing & identifiers: Android keystore; iOS certificates/provisioning; bundle ids/package names.
- Distribution: TestFlight (iOS), internal/testing tracks (Android); monitoring and crash reporting.

### Phase 14 — Acceptance Criteria (Sign-off)
- Visual: tokens applied; light/dark consistent.
- Interaction: focus/pressed states; native gestures; predictable navigation.
- Responsiveness: adaptive layouts; legible charts across sizes.
- Accessibility: contrast passes; screen readers supported; reduced motion respected.

## Data & Privacy Design
- Respect platform constraints; iOS SMS inbox reading is not allowed.
- Secure storage for tokens; redact sensitive info in app switcher; encrypt sensitive caches; masking and confirmations for risky actions.

## Non-Functional Standards
- Performance budgets and measurement; jank avoidance; image and network optimization.
- Accessibility baseline with audits and dynamic text scaling.
- Error and recovery flows: backoff, offline, retry, conflict resolution.

## Testing Strategy
- Unit tests for logic and parsers.
- Widget tests for UI and accessibility semantics.
- Integration tests for navigation and data flows with mocks.
- Golden tests for visuals; E2E on Android devices.

## CI/CD
- Android: build debug/release APK/AAB; upload to Play internal track.
- iOS: build on macOS runners or Codemagic; upload to TestFlight.
- Web: optional previews for stakeholders.
- Steps: `flutter format`, `flutter analyze`, `flutter test`, build, sign, deploy.

## Release Governance
- Semantic versioning for tokens and components; changelogs; feature flags; staged rollout; crash analytics monitoring.

## Immediate Actions
- Install Android `cmdline-tools` and set `ANDROID_SDK_ROOT`; verify with `flutter doctor -v`.
- Initialize Flutter project, add packages, scaffold folder structure.
- Implement design tokens, theming, navigation, and splash.
- Run on Web (`chrome`) or Android device after toolchain fixes.