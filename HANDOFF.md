# Handoff — Cursor → Codex (2026-06-30)

Read this first. Local machine state also lives in `AGENT_STATE.md` (gitignored; run `scripts/update-agent-state.sh` to refresh).

## Status

- **Branch:** `feature` → mirrored to `debug` during handoff
- **Version:** 1.4.5 (build 17)
- **Ready for:** Codex testing on `debug`
- **Not ready for:** merge to `main`, Sparkle OTA, or release until user approves

## What was built

Inline LaTeX formula editing for Zirn:

1. **`/formula{}` source syntax** — edit in markdown source, not WYSIWYG boxes
2. **KaTeX preview** — rendered mode shows centered math + copy button
3. **Toolbar ƒ button** — popover with AI assist + **Enter manually** (system hover colors, no default border)
4. **In-editor assist bubble** — when caret is inside `{}`
5. **`/` stays visible** while typing `/formula`
6. **Crash fixes** — no binding mutation in `updateNSView` for manual insert; toolbar no longer exits edit mode on formula click; smart insert location for edit vs rendered mode

## Files touched

| File | Role |
|---|---|
| `Zehan/ContentView.swift` | Formula UI, KaTeX, insertion, toolbar, assist |
| `Zehan/BrainStore.swift` | `generateFormulaLatex`, AI instructions |
| `Zehan/MistralKeychainStore.swift` | Keychain load fallback without biometrics |
| `Zehan.xcodeproj/project.pbxproj` | Release entitlements → `Zirn.release.entitlements` |
| `PATCH_NOTES.md` | v1.4.5 formula entries |
| `Zehan/ZehanRelease.entitlements` | Deleted (use `Zirn.release.entitlements`) |

## Codex: start here

```bash
git fetch --all --prune
git switch debug
git merge --ff-only feature   # or --no-ff if needed

xcodebuild -project Zehan.xcodeproj -scheme Zehan -configuration Debug \
  -destination 'platform=macOS' build

open "$HOME/Library/Developer/Xcode/DerivedData/Zehan-gdquvljfmiosqlfcbxrhjjsnjgfn/Build/Products/Debug/Zirn.app"
```

Use skill **`zirn-branch-flow`** and **`CODEX_RUNBOOK.md`** for branch rules.

## Test checklist

- [ ] Rendered page → ƒ → Enter manually → no hang, `/formula{}` at scroll position or EOF
- [ ] Edit mode → ƒ → Enter manually → inserts at caret, stays editing
- [ ] AI generate from popover and from in-editor bubble
- [ ] Preview renders KaTeX; copy works
- [ ] `/` visible while typing `/formula`
- [ ] Bold/italic/table/regression; reading mode disables ƒ

## Architecture (insertion)

`formulaInsertionRequest.onChange` → `formulaInsertionLocation()` → `insertManualFormulaPlaceholder` or `insertGeneratedFormula` → `setEditing(true)` only if not already editing.

**Do not** reintroduce `shouldInsertFormulaInSource = true` for toolbar manual path — that caused the layout hang.

## Follow-ups (optional)

- Newline spacing for AI-generated popover insert (manual path already has it)
- Assist bubble position on long scrolled docs
- No unit tests yet for formula parsing
