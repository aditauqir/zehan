---
name: looks-good
description: >-
  When the user approves work (e.g. "looks good", "LGTM", "ship it", "that works"),
  clean-build Zirn, uninstall the old app, reinstall fresh, and commit changes.
  Push to GitHub only when the user explicitly asks. Use for Zirn (Zehan) macOS
  app approval and ship workflow.
---

# Looks Good — Build, Install, Commit

Run this end-to-end workflow when the user approves the current work.

## Trigger phrases

Apply this skill when the user says something like:

- looks good
- LGTM
- ship it
- that works
- commit it

Do **not** run on vague praise alone if they are still asking for changes.

**Push is optional.** Only push when the user explicitly says so (e.g. "push it", "push to GitHub", "looks good and push"). Default: commit locally, do not push.

## Workflow

Copy this checklist and track progress:

```
Looks-good progress:
- [ ] Step 1: Clean build + reinstall app
- [ ] Step 2: Fix build errors and retry until success
- [ ] Step 3: Commit changes
- [ ] Step 4: Push to GitHub (only if user asked)
- [ ] Step 5: Report results
```

### Step 1: Clean build + reinstall

From repo root, run:

```bash
.cursor/skills/native-mac-app/scripts/refresh-app.sh
```

Use `required_permissions: ["all"]`.

This script:

1. Quits any running Zirn instance
2. Runs `xcodebuild … clean build`
3. Removes `/Applications/Zirn.app`
4. Copies the fresh build to `/Applications/Zirn.app`
5. Re-registers with Launch Services and opens the app

**Do not** tell the user to test until the build succeeds.

### Step 2: Fix build errors

If the build fails, fix errors and re-run Step 1 until `** BUILD SUCCEEDED **`.

### Step 3: Commit

Follow the repo git safety protocol:

1. Run in parallel: `git status`, `git diff`, `git log -5 --oneline`
2. Draft a concise 1–2 sentence commit message focused on **why**
3. Do not commit secrets (`.env`, credentials, API keys)
4. Stage relevant files and commit via HEREDOC:

```bash
git add -A
git commit -m "$(cat <<'EOF'
Your message here.

EOF
)"
```

5. Run `git status` to verify the commit succeeded

If there are no changes to commit, skip to Step 5 and say so.

### Step 4: Push to GitHub (optional)

Skip unless the user explicitly requested a push in their message.

When they did ask to push:

```bash
git push
```

Use `required_permissions: ["all"]` if network/git credentials are needed.

If push fails (no upstream, auth, conflicts), report the error and stop — do not force-push.

### Step 5: Report

Tell the user:

1. Build result (succeeded / failed)
2. Install path: `/Applications/Zirn.app`
3. Commit hash and message (or "nothing to commit")
4. Push result (pushed / skipped — default skipped unless user asked / failed)

## Rules

- **Never** update git config
- **Never** force-push to main/master
- **Never** skip hooks unless the user explicitly asks
- Match existing commit message style (short imperative summary, optional detail sentence)
- Only commit project-relevant changes from the current session
