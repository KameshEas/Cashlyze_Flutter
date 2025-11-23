## Scope & Goals
- Establish consistent, accessible UI across all screens using the app’s design tokens and component patterns.
- Align typography, spacing, colors, components, navigation, animations, and states with the design system.
- Support dark/light themes, text scaling, reduced motion, and high-contrast accessibility.

## Foundation & Tokens
- Centralize design tokens in `core/theme/app_theme.dart` and `core/ui/constants.dart`.
- Standardize spacing with `kSpacing8/12/16/24`, radii `kRadius12/16`, and elevations.
- Prohibit inline colors; enforce `ColorScheme` usage: primary `#006D5B`, secondary `#64FFDA`, surface `#1E1E1E`, background `#121212`, error `#CF6679`.
- Define `ThemeData` for both dark and light modes; set `themeMode: ThemeMode.system`.

## Layout & Visual Consistency
- Define responsive breakpoints: compact <600, medium 600–900, expanded ≥900.
- Use `LayoutBuilder` and adaptive layouts (e.g., two-column on ≥900 like `SettingsScreen`).
- Enforce consistent paddings/margins: page `EdgeInsets.all(16/24)`, section `16`, card `16`.
- Use `AspectRatio`/`FittedBox` for images/icons; avoid distortion with `fit: BoxFit.cover/contain`.
- Adopt a grid system (M3) for dashboards: `SliverGrid` or `GridView` with tokenized spacing.

## Typography
- Global font: Inter via `GoogleFonts.interTextTheme` (already configured).
- Map text styles: display/title/headline/body/label with explicit sizes/weights/line-height.
- Enforce `theme.textTheme` across all `Text`; remove local text styling where possible.
- Support dynamic text scaling: verify at 200% using `MediaQuery.textScaler` and adjust chip/button constraints.

## Color & Themes
- Implement a light theme mirroring dark theme tokens; ensure accessible contrast per WCAG AA.
- Add high-contrast variants for critical UI (errors, focus outlines).
- Audit all screens for unapproved color variations; replace with `ColorScheme`.

## Components & Interactions
- Buttons: consistent styles and states (hover/pressed/disabled/focus) via `ElevatedButtonTheme/TextButtonTheme`.
- Inputs: standard `InputDecorationTheme` (labels, helper text, error states, focus ring).
- Cards/lists: unify `CardTheme` and list tiles paddings; consistent dividers.
- Gestures: implement `RefreshIndicator` for lists; `Dismissible` with confirm for destructive actions.

## Navigation & Flow
- Review `GoRouter` (`lib/routes/app_router.dart`) transitions; reduce global fade duration (currently 1500ms) to 250–300ms.
- Verify back navigation across nested shell routes; ensure stacks preserved and deep links follow guards.
- Confirm screen transitions match prototypes; add per-route transitions if needed.

## Animations & Micro-interactions
- Add reduced-motion support: skip/shorten animations when `MediaQuery.disableAnimations` or `accessibleNavigation` is true.
- Use subtle, performant transitions (`FadeTransition`, `AnimatedSwitcher`) within 150–300ms.
- Ensure loading, ripple, and focus states reflect design.

## Content & Copy
- Centralize strings for consistency and future localization.
- Replace placeholders with approved copy; ensure error/help text follows UX writing guidelines.
- Prepare for i18n: scaffold `supportedLocales` and delegate wiring.

## Forms & Input Validation
- Match keyboard types to inputs (email/number/date); enforce capitalization and autofill where applicable.
- Validation states: error/success/warning, with helper/tooltips; inline errors near fields.
- Ensure disabled/read-only visual states align with design.

## Accessibility
- Tap targets ≥48x48; set `materialTapTargetSize: MaterialTapTargetSize.padded`.
- Add `Semantics`/`semanticLabel` for non-text visuals and Lottie animations.
- Logical focus order and screen reader labels on all actionable icons.
- Contrast checks for text on surface/background; avoid color-only cues.

## Performance & Loading
- Use skeletons (`core/widgets/skeleton.dart`) for lists/cards; avoid layout shift by reserving space.
- Defer heavy images; cache lists; prefer `ListView.builder` with `cacheExtent`.
- Maintain smooth performance on budget devices; profile with `flutter devtools`.

## Asset Management
- Use SVG for icons where possible; ensure correct export scale and bounds.
- Optimize images (resolution, compression); define asset variants for pixel densities.
- Integrate Lottie with accessibility labels; lazy load where appropriate.

## Error Handling & Empty States
- Implement designed empty states for all major screens (transactions/budgets/EMI).
- Network failure messages with retry; consistent error visuals.
- Style 500/unknown states with design system components.

## Modals, Alerts & Toasts
- Standardize `AlertDialog`/bottom sheets: radius, shadow, scrim opacity, and enter/exit animation.
- Ensure toasts/snackbars don’t overlap key UI; auto-dismiss durations per severity.

## Consistency with Design System
- Audit usage of tokens/components; replace custom elements with design library variants.
- Create reusable UI primitives in `core/ui` (SectionCard, Toolbar, FormField wrappers).
- Maintain reusability and scalability; document component usage via inline examples in code.

## User Data & Privacy UX
- Clear consent flows and permission prompts (camera/location) with rationale and settings shortcuts.
- Consistent saving/loading indicators for data operations; optimistic UI where safe.

## QA & Verification Strategy
- Golden tests for core screens across dark/light themes and 100%/200% text scale.
- Semantics tests for actionable controls and labels.
- Visual regression checks for spacing/typography/color tokens.
- Device matrix: small phone, large phone, tablet.

## Phased Milestones
1) Token Hardening & Theming
- Add light theme, enforce ColorScheme, spacing/radius/elevation tokens.
2) Layout & Typography Alignment
- Apply responsive layouts and text styles across dashboards, lists, forms.
3) Components & States
- Standardize buttons, inputs, cards, lists, gestures; state visuals.
4) Accessibility & Motion
- Tap targets, semantics, contrast, reduced-motion.
5) Performance, Assets & Empty/Error States
- Loading skeletons, asset optimization, designed empty/error screens.
6) QA Automation & Final Polish
- Golden/semantics tests, micro-interactions, copy review.

## Acceptance Criteria
- All screens pass a UI consistency checklist for spacing/typography/colors/components.
- Dark/light themes visually consistent and accessible.
- Text scaling and reduced motion supported app-wide.
- Navigation/back/deep link flows verified without UX breaks.
- Performance stable with no jank; assets optimized.
