# Cashlyze – Production Readiness Plan

This plan outlines the steps and standards to move Cashlyze from a working prototype to a production-ready application across Android, iOS, and Web. It is organized by domain with concrete actions, owners, and verification guidance.

## 1) Architecture & Configuration
- Environments: dev, staging, prod; configure via `--dart-define=ENV=<env>` and `--dart-define=FIREBASE_PROJECT_ID=<id>`.
- Routing: keep `GoRouter` guards enforced; start at `/splash` and route based on auth/onboarding.
- Secrets: never commit keys; use CI secrets and platform keychain/keystore.
- Feature flags: plan to introduce Firebase Remote Config for gradual rollouts.

## 2) Security & Privacy
- Firebase rules:
  - Restrict `users/{uid}` docs to `request.auth.uid == uid`.
  - Validate data types and required fields with `rules_version = '2'`.
  - Create indexes for query-heavy collections.
- Authentication hardening:
  - Enforce email verification before enabling sensitive features.
  - Rate-limit password reset and sign-in error feedback.
- Privacy compliance: publish Privacy Policy, Terms; prepare DSR workflows (GDPR/CCPA).

## 3) Authentication UX
- Enforce verified email on first sign-in; show verify banner with resend.
- Forgot password flows implemented; ensure throttling and friendly messaging.
- Sign out UX added with confirmation and success toast.
- Social sign-in backlog: Google/Apple; store provider info in `users/{uid}`.

## 4) Data Model & Integrity
- Canonical `users/{uid}` document creation on signup.
- Add schema docs for future domain models: `accounts`, `transactions`, `budgets`.
- Migrations: version each doc with `schemaVersion`; add background migration tooling (Cloud Functions or app-side).
- Server-side validation: move risky calculations/server secrets to Cloud Functions.

## 5) Performance & Responsiveness
- 60fps animation budget; prefer implicit animations; keep rebuild scopes small.
- Replace deprecated `withOpacity` → `withValues` (completed).
- Optimize lists: use item extents, pagination; avoid heavy shaders on first frame.
- Image and Lottie caching: pre-warm where appropriate; add placeholders.
- Profile with `flutter run --profile` and leaderboards for frame build/raster times.

## 6) Accessibility & Localization
- Minimum contrast 4.5:1 for text; verify dark theme tokens.
- Semantics: labels for icons, focus order, larger touch targets.
- Keyboard navigation for Web; ensure visible focus rings.
- Localization: scaffold `intl` setup and extract strings; default en-US.

## 7) Observability
- Crash reporting: Firebase Crashlytics.
- Analytics: Firebase Analytics with screen names (router integration) and key events (signup, onboarding complete, sign out).
- Structured logs: avoid PII; filter on network failures and auth events.

## 8) Quality Engineering
- Testing strategy:
  - Unit tests for services and providers.
  - Widget tests for `AuthScreen`, `SplashScreen`, `OnboardingScreen` flows.
  - Integration tests for end-to-end auth and routing.
  - Golden tests for core UI components.
- Static checks: `flutter analyze` clean (completed); enable CI to enforce.
- Code review: establish PR template and “no secrets” check.

## 9) Release Engineering
- Android: App Bundle, Play signing, product flavors, ProGuard/R8, min SDK.
- iOS: Signing, provisioning, ATS, background modes, App Store assets.
- Web: PWA manifest, service worker, caching strategy; deploy on Firebase Hosting or Vercel.
- Versioning: semantic version; bump build numbers automatically in CI.
- Store listings: screenshots, descriptions, privacy disclosures.

## 10) Operations
- Feature flags & rollout: Remote Config; define kill-switches for risky features.
- Maintenance: ability to show maintenance banner (Remote Config toggle).
- Backups & retention: define retention for user data; export processes.

## 11) Current Status Snapshot
- Splash route and animated fade: implemented and configurable.
- Route guards: enforced; signed-out redirects to `/login`.
- Onboarding flag set only in `OnboardingScreen` on “Get Started”.
- Sign out UX: confirmation and success toast added.
- Analyzer: clean (no issues).

## 12) Near-Term Action List
- Security rules authoring and tests (high)
- Email verification gate with UI prompts (high)
- Crashlytics and Analytics instrumentation (high)
- CI pipeline (analyze, test, build for 3 targets) (high)
- Accessibility pass and localization scaffolding (medium)
- Offline caching for critical screens (medium)
- Performance profiling on low-end devices (medium)

## 13) CI/CD Pipeline (Proposed)
- GitHub Actions:
  - Jobs: `analyze`, `test`, `build_android`, `build_ios`, `build_web`.
  - Cache pub packages; use `--dart-define` per environment.
  - Upload artifacts; gate merges on checks.
- Secrets management: store signing keys and `google-services` config in repo secrets or CI key vault.

## 14) Definition of Done (Prod)
- Security rules authored, reviewed, and tested.
- Analyzer clean; test coverage baseline met; integration tests passing.
- Crash/analytics wired; dashboards monitored.
- Release builds validated on devices; no critical performance regressions.
- Store assets prepared and validated.

---

## Appendix – File Pointers
- Splash animation: `lib/features/splash/splash_screen.dart`
- Routing guards and transitions: `lib/routes/app_router.dart`
- Auth screen and flows: `lib/features/auth/auth_screen.dart`
- Onboarding flow: `lib/features/onboarding/onboarding_screen.dart`
- Theme tokens: `lib/core/theme/app_theme.dart`