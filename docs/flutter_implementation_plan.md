# Cashlyze Flutter Implementation Plan (Phase by Phase)

This plan sequences the full build from splash to production releases on Apple App Store and Google Play. It maps Cashlyze’s UI/UX requirements into Flutter architecture, packages, and acceptance criteria.

## Phase 0 — Foundations & Splash
- Architecture & folder structure
  - `lib/`
    - `core/` (theme, tokens, utils, services)
    - `features/` (onboarding, accounts, transactions, budgets, insights, settings)
    - `widgets/` (shared UI components)
    - `routes/` (go_router configuration)
  - State management: prefer Riverpod or Bloc; expose ViewModels-like providers.
- Design tokens & theming
  - Colors, typography, spacing, elevation, motion tokens.
  - `ThemeData` with light/dark themes; keep semantic color names.
- Splash
  - Native splash (iOS LaunchScreen storyboard / Android drawable).
  - Animated in-app splash (Hero/Lottie) with asset preloading.
- Navigation
  - `go_router` for tabs + nested stacks; deep links with scheme `cashlyze://`.
- Storage baseline
  - `shared_preferences` for simple flags; `sqflite` or `drift` for transactions/budgets.

## Phase 1 — Onboarding & Consent
- Screens: welcome, value props, privacy note, demo mode.
- Analytics opt-in toggle (persisted) and explanation modal.
- Data Practices explainer: what is collected, why, how to opt-out.
- Route guard to show onboarding only on first run.

## Phase 2 — Accounts & Data Sources
- Account linking
  - Provider stub UI (later integrate real aggregators/API).
  - Manual account entry form with validation.
- SMS Auto-import
  - Android: use `telephony` or `sms_advanced` to read inbox with runtime permission.
  - iOS: SMS inbox reading is not permitted; provide paste/upload fallback.
- Parser
  - Normalize merchant, amount, date; map to transaction entity.
  - Idempotent dedupe across messages; logging and error handling.

## Phase 3 — Transactions
- List
  - Filters: date range, category, amount, merchant; search.
  - Empty/loading states; pull-to-refresh.
- Detail view
  - Amount, merchant, category, notes, attachments.
- Batch edit
  - Multi-select; apply category/notes; undo.
- Manual add/edit
  - Forms with validation and keyboard types.
- Persistence
  - Replace demo data with local DB (drift/sqflite) and repository layer.

## Phase 4 — Budgets
- Planner screen
  - Per-category sliders for monthly limits; animated progress bars.
  - Warnings at ≥80% usage; color transitions (green/amber/red).
- Data binding
  - Compute spent per category from Transactions in the selected period.
- Features
  - Create/edit/delete categories; rollover; month/quarter selection.
  - Notifications: near/over budget; in-app banners.
  - History and charts (progress over time).

## Phase 5 — Insights
- Trend analysis
  - Weekly/monthly spend trends; category breakdowns.
- Charts
  - `fl_chart` (line/area, pie/donut); accessible legends and colors.
- Anomaly detection
  - Basic spikes and category drift; callouts with microcopy.

## Phase 6 — Theming & Accessibility
- Global theming with Riverpod/Bloc provider.
- Accessibility
  - Contrast (WCAG AA); text scaling; semantic roles (`Semantics` widget).
  - Large touch targets (≥48dp); reduced motion preference.
- Dark theme parity across screens.

## Phase 7 — Localization & Internationalization
- i18n
  - `flutter_localizations`, `intl` for messages and formatting.
  - JSON/ARB translation files and locale fallbacks.
- RTL support
  - Layout mirroring; icon direction; gesture adjustments.
- Currency/date/number formatting via `intl`.

## Phase 8 — Analytics & Privacy
- Analytics
  - Screen views, taps (opt-in); anonymized performance metrics.
- Privacy
  - Data retention rules; cache controls; export/delete.
- Documentation
  - In-app privacy explainer; external policy link.

## Phase 9 — Error Handling & Offline
- Error boundaries
  - Friendly fallback screens and retry actions.
- Offline-first
  - Queue writes; sync on reconnect; show sync status and last updated.
- Network strategy
  - Exponential backoff for transient failures.

## Phase 10 — Performance
- Targets
  - Startup: first interactive < 2.5s (warm), < 5s (cold) on mid-range devices.
  - Smooth animations; avoid jank; keep frame times ≤16ms.
- Techniques
  - Skeletons/shimmer for loads >300ms.
  - Memoization; virtualization/lazy lists; image optimization.

## Phase 11 — Testing
- Unit tests
  - Providers/ViewModels, repositories, parsers.
- Widget tests
  - Screens and components; accessibility (Semantics) checks.
- Integration tests
  - Navigation flows; data fetch with mocks; golden tests for visuals.
- E2E
  - Consider `flutter_driver` alternatives like `integration_test`.

## Phase 12 — Dev Experience & CI/CD
- CI
  - Lint, tests, format checks; static analysis.
- CD
  - Build pipelines for Android/iOS; environment configs and secrets handling.
- Versioning
  - Design tokens and component library governance; changelogs.

## Phase 13 — Store Readiness (Apple & Google)
- Assets & metadata
  - App icons, splash, screenshots, descriptions, categories, age ratings.
- Permissions
  - iOS: do not attempt SMS inbox reading; provide paste/upload alternative.
  - Android: request `READ_SMS` only with explicit opt-in and clear consent.
- Privacy compliance
  - Data Safety (Google Play), Privacy Nutrition Labels (Apple).
- Signing & identifiers
  - Android keystore; iOS certificates/provisioning; bundle ids/package names.
- Distribution
  - Beta: TestFlight (iOS), internal/testing tracks (Android).
- Monitoring
  - Crash reporting; analytics production keys.

## Phase 14 — Acceptance Criteria (Sign-off)
- Visual
  - Tokens applied (colors, typography, spacing, elevation); light/dark consistent.
- Interaction
  - Clear focus/pressed states; native gestures; predictable navigation.
- Responsiveness
  - Adaptive layouts; charts legible across screen sizes.
- Accessibility
  - Contrast passes; screen readers supported; reduced motion respected.

---

## Suggested Flutter Packages
- Navigation: `go_router`
- State: `flutter_riverpod` or `bloc`
- Storage: `sqflite` or `drift`, `shared_preferences`
- Charts: `fl_chart`
- Animations: `lottie`
- HTTP: `dio`
- CSV/Export: `csv`, `share_plus`
- SMS (Android): `telephony` or `sms_advanced` (ensure Play policy compliance)
- Localization: `intl`, `flutter_localizations`

## Folder Structure Example
```
lib/
  core/
    theme/
      colors.dart
      typography.dart
      spacing.dart
      elevation.dart
    services/
      storage_service.dart
      analytics_service.dart
    utils/
      formatters.dart
      result.dart
  routes/
    app_router.dart
  widgets/
    app_bar.dart
    card.dart
    progress_bar.dart
  features/
    onboarding/
      onboarding_screen.dart
    accounts/
      account_link_screen.dart
    transactions/
      transactions_screen.dart
      transaction_detail_screen.dart
    budgets/
      budget_planner_screen.dart
    insights/
      insights_screen.dart
    settings/
      settings_screen.dart
```

## Development Notes
- MVVM with Providers: isolate business logic and persistence from UI.
- Keep tokens and components reusable; maintain accessibility semantics.
- Respect platform constraints: iOS SMS reading is not allowed.
- Document consent and privacy; provide opt-out at any time.

## Milestones & Tracking
- Convert the above phases into backlog tickets.
- Define sprint goals per phase and acceptance tests.
- Use the acceptance criteria section to gate releases.