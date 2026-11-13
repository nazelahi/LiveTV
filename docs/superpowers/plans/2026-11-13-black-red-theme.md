# Black-Red Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Solarized dark palette with an accessible black-and-red theme.

**Architecture:** All Flutter colors stay in `AppTheme`; Material components are driven by an explicit `ColorScheme.dark`. Two peripheral color maps are updated (featured kinds, Android banner) plus the HTML boot loader.

**Tech Stack:** Flutter, Material 3, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-11-13-black-red-theme-design.md`

## Global Constraints

- Text pairs must meet WCAG AA: 4.5:1 normal text, 3:1 icons/large text.
- No layout or behavior changes.
- No color values outside `AppTheme` for app UI; web boot colors live in `web/`.
- `flutter analyze` and `flutter test` must pass.

## Review Focus

- Small accent text on the gradient background: must stay ≥ 4.5:1 at the lightest gradient stop, not just on `background`.
- White labels on filled buttons: must use `accentFill`, never bright `accent`.
- LIVE/error states: `danger` amber must remain visually distinct from red accents.
- Boot flash: `web/index.html` must not show the old blue spinner or Solarized tones.
- Muted text over `backgroundAlt` cards: ≥ 4.5:1, since cards are lighter than the page.

---

### Task 1: Palette tokens and contrast test

**Files:**
- Modify: `lib/core/app_theme.dart:6-34`
- Test: `test/theme_contrast_test.dart`

**Interfaces:**
- Produces: `AppTheme.accentFill`, `AppTheme.background`, `AppTheme.backgroundAlt`, `AppTheme.accent`, `AppTheme.accentSecondary`, `AppTheme.danger`, `AppTheme.textPrimary`, `AppTheme.textSecondary`, `AppTheme.textMuted`.

- [ ] **Step 1: Write the failing contrast test**

Test computes relative luminance from `Color.r/g/b` and asserts:

```dart
expect(contrast(AppTheme.textPrimary, AppTheme.background), greaterThanOrEqualTo(12));
expect(contrast(AppTheme.textSecondary, AppTheme.background), greaterThanOrEqualTo(7));
expect(contrast(AppTheme.textMuted, AppTheme.background), greaterThanOrEqualTo(4.5));
expect(contrast(AppTheme.textMuted, AppTheme.backgroundAlt), greaterThanOrEqualTo(4.5));
expect(contrast(AppTheme.accent, AppTheme.background), greaterThanOrEqualTo(4.5));
expect(contrast(AppTheme.accentSecondary, AppTheme.background), greaterThanOrEqualTo(4.5));
expect(contrast(AppTheme.danger, AppTheme.background), greaterThanOrEqualTo(4.5));
expect(contrast(const Color(0xFF200003), AppTheme.accent), greaterThanOrEqualTo(4.5));
expect(contrast(Colors.white, AppTheme.accentFill), greaterThanOrEqualTo(4.5));
```

Plus a test that `background` luminance is below `0.02` and `accent` has a red-dominant channel.

- [ ] **Step 2: Run it; expect failures against Solarized values**
- [ ] **Step 3: Set the tokens from the spec palette; add `accentFill`**
- [ ] **Step 4: Re-run; all contrast tests pass**
- [ ] **Step 5: Update both gradients to the spec colors**

### Task 2: Material ColorScheme and component themes

**Files:**
- Modify: `lib/core/app_theme.dart:36-133`

- [ ] **Step 1: Replace `ColorScheme.fromSeed` with explicit `ColorScheme.dark` overrides from the spec**
- [ ] **Step 2: Point input, chip, snackbar, dialog, popup and navigation surfaces at the new tokens**
- [ ] **Step 3: Run `flutter analyze` and the test suite**

### Task 3: Peripheral colors

**Files:**
- Modify: `lib/widgets/featured_visuals.dart:12-15`
- Modify: `lib/widgets/android_download_banner.dart:72-73`
- Modify: `web/index.html:23,55-64`
- Modify: `web/manifest.json:6-7`

- [ ] **Step 1: Map featured kinds to accent / accentSecondary / danger / mauve**
- [ ] **Step 2: Banner button → `accentFill` background, white foreground**
- [ ] **Step 3: Boot loader → `#050506` / `#F2F2F2` / `#FF3B30`; meta and manifest → `#050506`**
- [ ] **Step 4: Run analyze and the full suite**

### Task 4: Visual verification

- [ ] **Step 1: `flutter build web`**
- [ ] **Step 2: Screenshot home, watch and settings at 8080; check text, buttons, badges, banner**
- [ ] **Step 3: Report remaining color anomalies, if any**
