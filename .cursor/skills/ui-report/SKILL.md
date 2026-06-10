---
name: ui-report
description: >-
  Requires a structured typography and color report after every Zirn UI change.
  Use when editing SwiftUI views, styling, fonts, colors, gradients, splash
  screen, sidebar, Home, or Zirn Chat (HelpDesk). Use when the user invokes
  /ui-report or asks for UI changes with font/color documentation.
disable-model-invocation: true
---
# UI Report

For **every UI change** in Zirn, end your response with a **UI change report**. Do not skip it.

## Before editing

1. Open the target view in `Zehan/ContentView.swift` (most UI lives here) or the relevant file.
2. Note existing font, size, color, and gradient values you are replacing.
3. Match surrounding conventions unless the user asks otherwise.

## After editing

Always report **font**, **size**, **color**, **where** (view + element), and **gradient** (if any).

Use this template:

```markdown
## UI change report

| Where | Element | Font | Size | Weight / design | Color | Gradient |
|-------|---------|------|------|-----------------|-------|----------|
| SplashView | Welcome greeting | PTSerif-Regular | 40 | regular (custom) | white @ 78% | — |
| HelpDeskView / composer | Send button (hover) | SF Pro (system) | 24 | semibold | white / accentColor | — |

### Chat-specific (if Zirn Chat was touched)
- **AnimatedThinkingBorder** (`ContentView.swift`): angular gradient — white 12% → white 72% → lime `(0.78, 0.93, 0.30)` @ 84% → white 18% → white 12%; rotates 360° / 1.35s
- **User message bubble**: `.ultraThinMaterial`, corner radius 16, no fill gradient
- **Composer**: `.ultraThinMaterial` background, stroke `Color.primary` @ 12%; thinking state uses `AnimatedThinkingBorder(cornerRadius: 18)`

### Files changed
- `Zehan/ContentView.swift` — …
```

Only list rows for elements you **added or changed**. If nothing in chat changed, omit the chat section.

## Zirn reference tokens

| Area | Common pattern |
|------|----------------|
| Splash background | `LinearGradient` top `(0.10, 0.10, 0.10)` → bottom `(0.075, 0.075, 0.075)` |
| Splash greeting | `AppFont.ptSerifRegular` (`PTSerif-Regular`), size 40, `white.opacity(0.78)` |
| Body / sidebar | `.system(size: 11–14, weight: .regular–.semibold)` |
| Secondary text | `.foregroundStyle(.secondary)` or `.primary.opacity(0.58–0.82)` |
| Chat header | "Zirn Chat" — system 30pt bold |
| Chat empty state | icon 38pt semibold secondary; title 18pt semibold primary; body 13pt secondary |
| Chat thinking pill | "Thinking..." — 11pt semibold, primary @ 78%, `AnimatedThinkingBorder` |
| Custom font | Register in `ZirnApp.registerBundledFonts()`; constant in `WelcomeGreeting.swift` → `AppFont` |

## Rules

- Report **exact** values from code (size, opacity, RGB if explicit, semantic name if system).
- Say **where** using struct name + element (e.g. `HelpDeskMessageBubble` / user bubble background).
- For chat UI, always document gradient usage even when unchanged but nearby code was edited.
- If you introduce a new gradient, list every stop color and opacity.
- Pair with `/plan` when the user also wants a build and install to `/Applications/Zirn.app`.

## Examples

**User:** Make the splash greeting larger.

Report must include a row for `SplashView` with old vs new size (e.g. 40 → 48), unchanged PT Serif font, unchanged white @ 78%.

**User:** Darken the chat composer border.

Report must include `HelpDeskView / composer` stroke color before and after, and note whether `AnimatedThinkingBorder` gradient was untouched.
