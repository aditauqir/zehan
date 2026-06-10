---
name: plan
description: >-
  Implements the user's request for the Zirn (Zehan) macOS app, then builds and
  launches a Debug build for manual testing. Use when the user invokes /plan or
  asks to plan, implement, build, compile, and run the app to test changes.
disable-model-invocation: true
---
# /plan

End-to-end workflow: **understand the request → implement → build → launch for testing**.

## Parse

Accept `/plan <request>` or a message that clearly asks to plan/build/test the app.

- If the prompt after `/plan` is empty, ask what to implement before coding.
- Treat everything after `/plan` as the feature, fix, or change to deliver.

## Workflow

Copy this checklist and track progress:

```
Plan progress:
- [ ] Step 1: Clarify scope (only if the request is ambiguous)
- [ ] Step 2: Implement the requested change
- [ ] Step 3: Build the app
- [ ] Step 4: Fix build errors and rebuild until success
- [ ] Step 5: Launch the app for testing
- [ ] Step 6: Report what changed and how to verify
```

### Step 1: Clarify scope

Skip when the request is specific. Ask one focused question only when blocked.

### Step 2: Implement

- Keep changes minimal and focused on the request.
- Match existing project conventions in `Zehan/`.
- For Svelte: not applicable. This is a Swift/macOS Xcode project.

### Step 3: Build

From the repository root, run:

```bash
.cursor/skills/plan/scripts/build-and-open.sh --build-only
```

Or manually:

```bash
xcodebuild -project Zehan.xcodeproj \
  -scheme Zehan \
  -configuration Debug \
  -derivedDataPath /tmp/ZehanDerivedData \
  clean build
```

Use `required_permissions: ["all"]` for `xcodebuild` (DerivedData writes outside the workspace).

### Step 4: Fix build errors

If the build fails:

1. Read the compiler errors from the build output.
2. Fix the code.
3. Rebuild. Repeat until `** BUILD SUCCEEDED **`.

Do not launch a broken build.

### Step 5: Launch for testing

After a successful build:

```bash
.cursor/skills/plan/scripts/build-and-open.sh --open-only
```

Or:

```bash
open /tmp/ZehanDerivedData/Build/Products/Debug/Zirn.app
```

Default script behavior (no flags) builds then opens the app.

### Step 6: Report

End with a short summary:

1. **What was implemented** — one or two sentences.
2. **Build result** — succeeded or what was fixed.
3. **App location** — `/tmp/ZehanDerivedData/Build/Products/Debug/Zirn.app`
4. **How to test** — concrete steps in the running app.

## Project reference

| Item | Value |
|------|-------|
| Xcode project | `Zehan.xcodeproj` |
| Scheme | `Zehan` |
| Product | `Zirn.app` |
| Debug output | `/tmp/ZehanDerivedData/Build/Products/Debug/Zirn.app` |

## Rules

- Always run the build yourself; do not tell the user to build unless `xcodebuild` is unavailable.
- Prefer `build-and-open.sh` for consistency.
- Do not commit unless the user explicitly asks.
- If the request is review-only (no code changes), still build and open when the user wants to test the current app.
