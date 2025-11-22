**Overview & Purpose**
- This document defines Cashlyze’s end-to-end UI/UX requirements, design tokens, interaction patterns, and developer guidance. It orients designers, developers, and PMs around a shared philosophy and concrete acceptance criteria to deliver a smart, clean, and effortless fintech experience.
- Use this as the source of truth for visual style, accessibility, motion, component behavior, and MVVM implementation patterns.

**Table of Contents**
- Product Overview
- Design Principles
- Brand Identity
- Design Tokens (Colors, Typography, Spacing, Elevation, Motion, Icons)
- Theming (Light/Dark)
- Core Components
- Data Visualization
- Screens & Flows
- Navigation
- MVVM Mapping (Development)
- Accessibility + Testing Checklist
- Localization & Internationalization
- Error Handling & Recovery
- Analytics & Privacy
- Developer Guidance (Versioning, Testing)
- Examples (MVVM binding, Gestures)
- Performance Budgets
- Design Rationale & Competitive Notes
- Onboarding Details
- Privacy & Security Features
- Acceptance Criteria
- Deliverables
- Future Enhancements & Roadmap
- Terminology Standards
- Glossary

**Product Overview**
- Cashlyze focuses on automation, clarity, and actionable insights for personal finance.
- The experience should feel smart, clean, and effortless with minimal friction.
- Visual tone: fintech-grade UI (inspired by Google Pay + money managers) with subtle, purposeful motion.

**Design Principles**
- Automation first: reduce manual input; suggest, auto-categorize, auto-complete.
- Clarity over complexity: prioritize digestible summaries and progressive disclosure.
- Insight-driven: highlight trends, anomalies, and recommendations.
- Minimal and native: avoid clutter; stick to platform conventions; keep elevation low.
- Accessible and inclusive: meet WCAG targets; support text scaling and screen readers.

**Brand Identity**
- Logo: “Cashlyze” in teal with a subtle wave underline.
- Tagline: “Know where your money flows.”
- Tone: friendly, informative, not preachy; emphasize confidence and helpfulness.
- Illustration: soft gradients, financial icons, tasteful Lottie animations.
- Dark mode: muted dark blues with teal highlights; maintain calm confidence.

**Design Tokens**
- Colors
  - Primary: `#2A9D8F` (Teal Green) — trust, finance, primary actions.
  - Accent: `#E9C46A` (Gold) — highlights, secondary emphasis.
  - Background (light): `#F7FAFC` or `#FFFFFF` — clean and airy surfaces.
  - Background (dark): `#0B1220` — muted deep blue backdrop.
  - Text (light): `#0F172A` — slate 900.
  - Subtle Text (light): `#64748B` — slate 500–600.
  - Error/Warning: `#E76F51` — alerts, validation, risky operations.
  - Success: `#2F9E44` — confirmations and positive outcomes.
  - Border/Divider: `#E2E8F0` — light separators; dark: `#334155`.
- Typography
  - Families: Inter (primary) or Poppins (alternate). Sans-serif, fintech-friendly.
  - Scale (base 8px grid):
    - H1: 32–36
    - H2: 28–32
    - H3: 24–28
    - H4: 20–22
    - Subtitle: 16–18
    - Body: 14–16
    - Caption/Label: 12–13
  - Line-height: 1.3–1.6 depending on size.
  - Weight usage: 600 for headings; 400–500 for body; 700 sparingly.
- Spacing
  - 8px grid system: `4, 8, 12, 16, 24, 32, 48` etc.
  - Page padding: 16–24; card padding: 12–16; input spacing: 8–12.
- Radius & Elevation
  - Radius: `8px` default; `12px` for prominent cards; `4px` for chips.
  - Elevation: 0–3 only. Use 0 for base surfaces, 1 for cards, 2–3 for overlays.
- Motion
  - Subtle micro-animations; fluid transitions; avoid distracting effects.
  - Durations: 120–240ms; easing: standard ease-in-out.
  - Reduce motion: respect OS settings; provide non-animated fallbacks.
- Icons
  - Material Icons + Feather; consistent stroke weights.
  - Use semantic icons for tabs, actions, and status.

**Examples & Visuals**
- Motion examples: placeholder links to short clips or Figma prototypes for button press, tab transitions, and bottom sheet reveal.
- Microcopy examples: screenshots or annotated mockups showing success and error banners.
- Placeholders
  - Motion clip: `assets/motion/button-press-demo.gif`
  - Microcopy mock: `assets/microcopy/budget-near-limit.png`

**Theming**
- Light Theme
  - Surfaces: background light (`#F7FAFC`), cards white, subtle shadows at elevation 1.
  - Primary buttons: teal background (`#2A9D8F`), white text.
  - Accent elements: gold for highlights (chips, badges, active states).
- Dark Theme
  - Background: muted deep blue (`#0B1220`), cards slightly lighter (`#111827`).
  - Primary: teal accents; ensure contrast ratios ≥ 4.5:1 for text.
  - Dividers: `#334155` and text `#CBD5E1` for legibility.

**Core Components**
- App Bar / Header
  - Title, optional subtitle; primary action on right; back navigation on left.
  - Collapse on scroll (optional) with subtle shadow increase.
- Bottom Navigation (Tabs)
  - Home, Transactions, Budgets, Insights, Settings.
  - Active tab: teal; inactive: subtle text color.
- Card
  - Minimal elevation; optional accent stripe for highlights.
  - Used for account summaries, budget cards, insights.
- Button
  - Types: Primary (teal), Secondary (gold accent), Outline (teal border), Ghost.
  - States: default, hover (web), focus, pressed, disabled, loading with spinner.
- Input
  - Label above, helper/validation text below; clear affordances.
  - Prefix icons for search and currency; numeric keypad for amounts.
- List Item
  - Left icon/avatar, title, subtitle; right value/action; large touch target.
- Chip/Tag
  - Category/filters; outline or filled accent; removable.
- Badge
  - Dot or count; used for notifications.
- Toast/Notification
  - Inline banners for warnings; transient toasts for confirmations.
- Modal/Bottom Sheet
  - Bottom sheet preferred for mobile actions; modal for confirmations.
- Skeleton/Loading
  - Use shimmer on cards and lists; durations 800–1200ms.
- Empty State
  - Soft illustration, concise copy, primary CTA; optional secondary CTA.

**Data Visualization**
- Chart Types
  - Spend trend: line/area with teal line; key points highlighted.
  - Category breakdown: donut chart with accent highlights; limit to 6–8 slices.
  - Budget progress: progress bars with thresholds and alerts.
- Principles
  - Label clarity: axis labels, tooltips; avoid clutter; use progressive disclosure.
  - Color usage: primary for focus; accent for callouts; avoid rainbow overload.
  - Accessibility: provide text alternatives; high-contrast markers; explain insights.

**Screens & Flows**
- Onboarding
  - Welcome, value proposition, privacy note; opt-in for analytics.
  - Quick start: connect bank or add manual accounts; try demo mode if available.
- Account Linking
  - Secure connect (provider screen), success feedback, fallback manual entry.
  - Show last sync time, connection status, and re-auth prompts.
- Dashboard (Home)
  - Total balance, recent transactions, budgets snapshot, top insights.
  - CTA: “View details”, “Add account”, “Create budget”.
- Transactions
  - List with filters (date, category, amount, merchant), search, batch edit.
  - Transaction detail: amount, merchant, category, notes, attachments.
- Budgets
  - Create/edit budget with category selection and period; show progress.
  - Alerts when near/over budget; suggestions (auto-adjust or pause).
- Goals
  - Savings goals with progress; deposit reminders; timeline.
- Insights
  - Monthly trends; category drift; anomaly detection; personalized tips.
- Notifications
  - Feed of alerts; manage preferences; swipe to mark read.
- Settings
  - Profile, security (PIN/biometrics), theme, currency, backup/export.
  - Data controls: clear cache, delete account, privacy options.

**Navigation**
- Pattern: bottom tabs for primary sections; stack navigator for detail flows.
- Gestures: native back; swipe for sheets; subtle transitions; avoid heavy parallax.
- Deep links: support `cashlyze://` for notifications to open specific views.

**MVVM Mapping (Development)**
- ViewModels
  - `DashboardViewModel`: balances, recent transactions, insights.
  - `TransactionsViewModel`: filters, list state, selection, batch actions.
  - `BudgetsViewModel`: budget definitions, progress, alerts.
  - `GoalsViewModel`: goals, progress, reminders.
  - `InsightsViewModel`: charts data, trends, recommendations.
- Views bind to ViewModels via hooks; expose properties and commands; subscribe/notify pattern.
- Services layer handles data (API, storage, analytics); ViewModels coordinate and transform for Views.

**Accessibility**
- Contrast: meet WCAG AA (normal text ≥ 4.5:1; large text ≥ 3:1).
- Text scaling: support OS dynamic type; avoid truncation in key flows.
- Touch targets: minimum 44×44 dp; spacing to prevent accidental taps.
- Screen readers: meaningful `accessibilityLabel` and `accessibilityRole` for interactive elements.
- Reduced motion: respect system settings; provide non-animated states.

**Accessibility + Testing Checklist**
- Tools
  - iOS: Accessibility Inspector; VoiceOver.
  - Android: Accessibility Scanner; TalkBack.
  - Contrast: use contrast checkers for AA; verify system high-contrast modes.
  - Automated: `@testing-library/react-native` queries (`getByA11yLabel`, `getByRole`).
- Steps
  - Verify roles/labels for all interactive components.
  - Ensure touch targets ≥ 44×44 dp and sufficient spacing.
  - Test dynamic text scaling (Small–Largest) without truncation in key flows.
  - Validate dark/light theme contrast (≥ 4.5:1 for body text).
  - Exercise reduced motion mode; ensure non-animated fallbacks.
  - Screen-reader linearization: confirm logical reading order.
  - Keyboard/remote navigation (TV/web): focus trapping and visible focus states.

**Localization & Internationalization**
- Content: support translation keys; avoid hard-coded strings.
- Currency: show locale-specific currency symbol, thousands/separators, decimal precision.
- Formats: date/time, number, and measurement localized via `Intl.*` APIs.
- RTL support: validate layout mirroring; iconography directionality; gestures (swipe).
- Pluralization: use ICU message format; test edge cases (zero/one/other).
- Workflow: translation files versioned; locale fallback; QA pass per locale.

**Error Handling & Recovery**
- Network
  - Exponential backoff (`2^n` up to 4 retries), then user prompt.
  - Offline-first: queue writes; show offline badge; auto-resume on reconnect.
- Forms
  - Inline validation; error summary for screen readers; autofill suggestions.
- System
  - Error boundaries at view level; show friendly fallback with retry.
- Recovery flows
  - Provide “Try again”, “Change account”, or “Contact support” actions.
  - Persist unsaved edits; show conflict resolution on sync.

**Analytics & Privacy**
- Data collected (opt-in): basic usage events (screen views, taps), anonymized performance metrics, crash reports.
- Sensitive data: do not collect PII without explicit consent; never store full card/banking details.
- Consent handling
  - Onboarding toggle for analytics; explain value and options.
  - Settings control to opt-in/out at any time; reflect immediately.
- Data retention: rotate logs; anonymize after 30–90 days; provide export/delete options.
- Transparency: privacy policy link; in-app “Data Practices” explainer.

**Developer Guidance**
- Versioning
  - Design tokens: semantic versioning; `major.minor.patch` with changelog.
  - Component library: release branches; deprecation notes; migration guides.
  - Governance: PR review by design + engineering; scheduled release cadence.
- Testing Strategy
  - Unit: ViewModels (state transitions, commands), utilities.
  - Integration: hooks + views; navigation flows; data fetch with mocks.
  - UI automation: Detox/Maestro for tab flows, modals, and gestures.
  - Accessibility tests: verify roles/labels; color contrast snapshots.
  - Motion: assert animation durations via configuration; measure frame stability.

**Examples (MVVM binding, Gestures)**
- MVVM Binding (TypeScript)
  ```ts
  // ViewModel
  class BudgetViewModel {
    private subscribers = new Set<(v: number) => void>();
    private spent = 0;
    subscribe(cb: (v: number) => void) { this.subscribers.add(cb); cb(this.spent); return () => this.subscribers.delete(cb); }
    add(amount: number) { this.spent += amount; this.subscribers.forEach(cb => cb(this.spent)); }
  }

  // Hook
  function useBudgetVM() {
    const vm = useMemo(() => new BudgetViewModel(), []);
    const [spent, setSpent] = useState(0);
    useEffect(() => vm.subscribe(setSpent), [vm]);
    return { spent, add: (v: number) => vm.add(v) };
  }

  // View
  function BudgetCard() {
    const { spent, add } = useBudgetVM();
    return <Button title={`Spent: ${spent}`} onPress={() => add(10)} />;
  }
  ```
- Gesture (Reanimated + Gesture Handler)
  ```tsx
  const translateY = useSharedValue(0);
  const pan = Gesture.Pan()
    .onUpdate(e => { translateY.value = e.translationY; })
    .onEnd(() => { translateY.value = withSpring(0, { damping: 15, stiffness: 120 }); });
  const style = useAnimatedStyle(() => ({ transform: [{ translateY: translateY.value }] }));
  return <GestureDetector gesture={pan}><Animated.View style={style}>{children}</Animated.View></GestureDetector>;
  ```

**Performance Budgets**
- Startup: first interactive < 2.5s (warm), < 5s (cold) on mid-range devices.
- Memory: < 150MB resident during dashboard; avoid > 200MB peaks.
- JS frame: ≤ 16ms average; slow frame count < 1% during typical interactions.
- CPU: animations keep CPU < 40% on mid-range Android during tab transitions.
- Network: requests ≤ 300ms median; apply caching; batch updates.

**Design Rationale & Competitive Notes**
- Bottom tabs + stack is familiar across fintech apps (Google Pay, PhonePe, Money Manager) ensuring predictability.
- Minimal elevation and calm palette convey trust and clarity, reducing cognitive load.
- MVVM enforces separation of concerns, improving testability and maintainability versus monolithic state.

**Onboarding Details**
- Fallbacks
  - If bank linking fails: show reason, provide retry, alternative provider, or manual entry.
  - Demo mode: optional sample data to explore features without linking accounts.
- Guidance
  - Tooltips for first-time users; progress indicators; privacy note upfront.
  - Show sync status and last updated time post-link.

**Privacy & Security Features**
- App lock: PIN/biometrics; auto-lock on background; configurable timeout.
- Redaction: hide balances in app switcher screenshots.
- Secure storage: use platform secure keystore for tokens; encrypt sensitive caches.
- Masking: obfuscate sensitive values; confirm before destructive actions.
- Audit: basic event logs for security-relevant actions (lock/unlock, export).

**Microcopy**
- Tone: friendly and informative.
- Examples
  - Budget near limit: “Heads up: You’re close to your grocery budget.”
  - Goal achieved: “Nice work — you reached your saving goal!”
  - Error: “We couldn’t sync your account. Try again or check connection.”

**Quality & Performance**
- 60fps animations; avoid layout thrash; use reanimated for interactive motion.
- Show skeletons if data loads exceed 300ms; timeouts at 10s with retry.
- Offline-first reading; queue writes; clear state transitions.

**Acceptance Criteria**
- Visual
  - Colors, typography, spacing, elevation match tokens and system guidelines.
  - Light and dark themes are consistent, readable, and on-brand.
- Interaction
  - Buttons and inputs respond with distinct focus/pressed states.
  - Navigations are predictable; gestures feel native; transitions are subtle.
- Responsiveness
  - Layouts adapt from small to large screens; charts remain legible.
- Accessibility
  - Passes contrast checks; supports screen readers; respects reduced motion.

**Deliverables**
- Figma: styles (colors, type, spacing), components, screen flows, prototypes.
- Token spec: JSON/TS tokens and usage guidelines.
- Component library: buttons, inputs, cards, lists, sheets, charts.
- Interaction specs: motion durations, easing, gestures.
- Content guidelines: tone, microcopy, error/empty states.

**Development Notes (Expo & RN)**
- Libraries
  - `@react-navigation/native` for tabs/stack.
  - `react-native-reanimated` and `react-native-gesture-handler` for motion/gestures.
  - `expo-linear-gradient` for soft gradients; `lottie-react-native` (via Expo) for animations.
- Implementation
  - Encapsulate logic in ViewModels; views remain presentational.
  - Keep styles consistent with tokens; extract shared styles to theme helpers.
  - Test accessibility with VoiceOver/TalkBack and dynamic text sizes.

**Future Enhancements**
- Roadmap (prioritized)
  - Near-term (0–3 months): component library v1, bottom tabs, onboarding + demo mode, budgets MVP.
  - Mid-term (3–6 months): insights charts, localization rollout, accessibility audits, privacy controls.
  - Long-term (6–12 months): collaborative budgets, advanced anomaly detection, export/report templates.

**Terminology Standards**
- Primary action: main CTA in a context (usually teal button).
- Accent: secondary visual emphasis (gold elements).
- Card: contained surface for a related set of information.
- Progressive disclosure: reveal complexity gradually via layering and navigation.

**Glossary**
- WCAG targets: Web Content Accessibility Guidelines thresholds for contrast and accessibility.
- Microcopy: short, helpful text guiding users, especially around errors and confirmations.
- MVVM: Model–View–ViewModel, a pattern separating presentation from logic/state.
- Detox/Maestro: tools for end-to-end UI automation testing on mobile.

**Documentation & Navigation**
- Provide clickable Table of Contents in docs; organize Figma with pages for tokens, components, flows, prototypes.
- Link design tokens to code references; keep version and changelog visible.