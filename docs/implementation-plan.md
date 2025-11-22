# Cashlyze – Feature Implementation Plan

This document outlines the step-by-step plan to deliver the core in‑app features and make the app production‑ready. It is structured to minimize risk, keep iteration fast, and maintain code quality.

## Goals
- Implement real data flows for Transactions, Budgets, Insights.
- Provide solid UX (empty states, loading states, dialogs, accessibility).
- Ensure offline-first behavior and robust error handling.
- Maintain analytics visibility and add tests to protect velocity.

## Scope Overview
- Data layer: models, repositories, providers
- Screens wiring: Transactions, Budgets, Insights, Categories
- Settings: preferences (currency, locale), onboarding revisit
- Observability: analytics events and screen tracking
- Quality: tests (unit/widget/integration), CI checks

## Architecture Updates
- Models:
  - `Transaction { id, userId, title, amount, categoryId, date, notes }`
  - `Budget { id, userId, name, allocated, period, categories[] }`
  - `Category { id, userId, name, icon, color }`
- Repositories (Firestore):
  - `TransactionRepository` (CRUD, queries by date range, category, income/expense)
  - `BudgetRepository` (CRUD)
  - `CategoryRepository` (CRUD)
- Providers (Riverpod):
  - `StreamProvider<List<Transaction>>` filtered by user and date range
  - `StreamProvider<List<Budget>>`
  - `StreamProvider<List<Category>>`
  - `Notifier` providers for mutations (create/update/delete)
- Offline-first:
  - Enable Firestore cache persistence
  - Optimistic updates with rollback on failure

## Transactions
- UI (done, demo data): `lib/features/transactions/transactions_screen.dart`
- Wiring to data:
  - Replace demo list with `ref.watch(transactionsProvider(range, filters))`
  - Hook add bottom sheet to `TransactionRepository.create()`
  - Add edit/delete actions via slidable or long-press menu
- Filters:
  - Income/Expense, Category, Date range (7d/30d/90d/custom)
  - Search across title/category
- Validation:
  - Amount numeric, Title non-empty, Date within reasonable bounds
- Empty/Loading:
  - Skeleton list while loading; friendly empty state with CTA to add

## Budgets
- UI (done, demo data): `lib/features/budgets/budget_planner_screen.dart`
- Wiring to data:
  - Load budgets from `BudgetRepository`
  - Compute utilization from transactions aggregates
- Create/Update:
  - Bottom sheet for name/allocated/period
  - Link budgets to categories for category filtering in Insights
- Alerts:
  - Threshold notifications when budget approaches/exceeds limits (later)

## Insights
- UI (done, placeholder data): `lib/features/insights/insights_screen.dart`
- Wiring to data:
  - Aggregate transactions into monthly trend (sum by month)
  - Pie chart by category (sum by category for selected range)
- Controls:
  - Time range chips (7d/30d/90d/custom)
  - Optional income vs. expense toggle

## Categories
- Screen:
  - List, add, edit, delete categories
  - Choose icon and color; ensure a11y contrast
- Integration:
  - Use categories in Transactions filters and Insights breakdown

## Settings
- Preferences:
  - Currency (e.g., USD, EUR) and locale selection
  - Date format
  - “Revisit Onboarding” action (keeps flag unchanged)
- Security:
  - Sign‑out confirmation (implemented)

## Error Handling & Offline
- Error surfaces:
  - Inline error banners with retry for lists
  - Snackbars for mutations with undo where feasible
- Offline:
  - Firestore cache, local optimistic updates
  - Queue failed writes for retry on reconnection (client‑side policy)

## Analytics & Observability
- Events: `signup`, `login`, `sign_out`, `onboarding_complete` (implemented)
- Add:
  - `transaction_add`, `transaction_edit`, `transaction_delete`
  - `budget_create`, `budget_update`, `budget_delete`
  - Screen views via `AnalyticsService.logScreenView()` as needed

## Testing Strategy
- Unit tests:
  - Repositories: correct queries and error handling
  - Providers: filter logic, aggregation correctness
- Widget tests:
  - Transactions add/edit form validates and submits
  - Budgets progress visuals and create flow
  - Insights charts render and update on time-range change
- Integration tests:
  - Auth + splash + onboarding routing
  - Transactions CRUD end‑to‑end with mock Firestore
- CI (added): `.github/workflows/flutter-ci.yml` for analyze/test/build

## Milestones
1. Data layer scaffolding (models, repos, providers) – 1–2 days
2. Transactions wired to data + CRUD – 1–2 days
3. Budgets wired + utilization from aggregates – 1 day
4. Insights wired + time-range controls – 1 day
5. Categories management screen – 1 day
6. Settings preferences (currency/locale) – 0.5 day
7. Offline/error policies + analytics events – 1 day
8. Tests (unit/widget/integration) – 2 days
9. Polish and QA – 1 day

## File Map (planned)
- Models: `lib/core/models/{transaction.dart,budget.dart,category.dart}`
- Repos: `lib/core/repositories/{transaction_repository.dart,budget_repository.dart,category_repository.dart}`
- Providers: `lib/core/providers/{transaction_providers.dart,budget_providers.dart,category_providers.dart}`
- Screens wired:
  - `lib/features/transactions/transactions_screen.dart`
  - `lib/features/budgets/budget_planner_screen.dart`
  - `lib/features/insights/insights_screen.dart`
  - `lib/features/categories/categories_screen.dart` (new)

## Acceptance Criteria
- Live data displayed and mutated from Firestore
- Filters and charts reflect selected ranges and categories
- Error and offline behavior user‑friendly and resilient
- Analyzer clean; tests pass; CI builds succeed for Web/Android/iOS

## Notes
- Email verification currently disabled via `kRequireEmailVerification = false`.
- When ready, set it to `true` to re‑enable gating.