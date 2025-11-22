# Cashlyze To‑Do (Start → Production)

Sequenced backlog from splash/onboarding to App Store and Play Store readiness.

## Phase 0 — Foundations & Splash
- [x] Design tokens: colors, typography, spacing, motion; extract theme helpers
- [ ] Animated splash + native splash integration; preload assets/fonts
- [ ] Navigation scaffold: bottom tabs + root stack; deep link config skeleton
- [ ] Storage baseline: `AsyncStorage` wrappers and schema versioning

## Phase 1 — Onboarding & Consent
- [ ] Onboarding: welcome, value proposition, privacy note, demo mode toggle
- [ ] Analytics consent toggle (opt‑in), persisted
- [ ] Data Practices explainer screen (privacy policy link)
- [ ] SMS auto‑import consent capture (explain capability and limits)

## Phase 2 — Accounts & Data Sources
- [ ] Account linking provider screen (secure connect), success feedback
- [ ] Manual account entry fallback with validation
- [ ] Auto‑import SMS (Android native): READ_SMS, inbox reader, parser integration
- [ ] Expo Go fallback: paste/upload text for parsing; robust error handling
- [ ] Parser: normalize amounts/merchants/dates; idempotent dedupe; logs

## Phase 3 — Transactions
- [ ] Transactions list with filters (date, category, amount, merchant) and search
- [ ] Transaction Detail: amount, merchant, category, notes, attachments
- [ ] Batch edit: multi‑select, apply category/notes; undo support
- [ ] Manual add/edit transaction flow with validation
- [ ] Replace demo data with persistent storage for transactions

## Phase 4 — Budgets
- [ ] Bind real “spent per category” from Transactions
- [ ] Create/edit/delete custom budget categories
- [ ] Monthly rollover and period selection (month/quarter)
- [ ] Notifications for near/over budget and in‑app warnings
- [ ] Budget history and charts (progress over time)

## Phase 5 — Insights
- [ ] Real trend analysis over transactions (weekly/monthly)
- [ ] Charts: line/area, donut; accessible legends and high contrast
- [ ] Basic anomaly detection (spikes, category drift)

## Phase 6 — Theming & Accessibility
- [ ] Global light/dark theme; Settings toggle wired to provider
- [ ] WCAG AA contrast validation; fix low‑contrast elements
- [ ] Accessibility: labels/roles, touch targets ≥ 44×44, dynamic type, reduced motion
- [ ] Screen‑reader linearization and focus order review

## Phase 7 — Localization & Internationalization
- [ ] i18n setup with translation files and locale fallbacks
- [ ] Currency/number/date formatting via `Intl.*`
- [ ] RTL layout mirroring and icon directionality
- [ ] ICU pluralization implementation

## Phase 8 — Analytics & Privacy
- [ ] Wire opt‑in analytics (screen views, taps), anonymized performance metrics
- [ ] Data retention policy (rotate logs, anonymize after 30–90 days)
- [ ] Export/delete options; clear cache controls

## Phase 9 — Error Handling & Offline
- [ ] Error boundaries with friendly fallback and retry
- [ ] Exponential backoff for network requests; offline‑first queuing for writes
- [ ] Sync status and last updated time; recovery flows (“Try again”, “Change account”)

## Phase 10 — Performance
- [ ] Startup: first interactive < 2.5s (warm), < 5s (cold)
- [ ] Skeletons with shimmer for loads > 300ms; timeouts at 10s with retry
- [ ] JS frame ≤ 16ms; minimize slow frames; image and bundle optimization

## Phase 11 — Testing
- [ ] Unit tests: ViewModels, utilities (state transitions, commands)
- [ ] Integration tests: hooks + views; navigation flows; data fetch with mocks
- [ ] UI automation: Detox/Maestro for tabs, modals, gestures
- [ ] Accessibility test pass: roles/labels; contrast snapshots

## Phase 12 — Dev Experience & CI/CD
- [ ] Versioning for tokens & component library; changelogs and governance
- [ ] CI pipelines for lint, tests, typecheck; CD for builds and release channels
- [ ] Environment config management; secrets not committed; secure storage usage

## Phase 13 — Store Readiness (Apple & Google)
- [ ] App metadata: icons, splash, screenshots, descriptions, categories, age rating
- [ ] Permissions disclosure and usage strings
  - [ ] iOS: update `Info.plist` usage descriptions; note SMS inbox read is not permitted – use alternative import on iOS
  - [ ] Android: request `READ_SMS` only where compliant; implement opt‑in and clear consent; follow Play policies
- [ ] Privacy compliance: data safety (Google), privacy nutrition labels (Apple)
- [ ] App signing: keystore (Android), certificates and provisioning (iOS)
- [ ] Bundle identifiers and package names
- [ ] Build & distribution: EAS builds/TestFlight (iOS), open/internal testing tracks (Android)
- [ ] Crash reporting and analytics production keys
- [ ] Legal pages: privacy policy URL, terms of service, consent flows

## Phase 14 — Acceptance Criteria (Sign‑off)
- [ ] Visual: tokens adhered (colors, type, spacing, elevation); light/dark consistent
- [ ] Interaction: distinct states; native gestures; predictable navigation
- [ ] Responsiveness: adaptive layouts; charts legible across devices
- [ ] Accessibility: contrast passes; screen readers supported; reduced motion respected