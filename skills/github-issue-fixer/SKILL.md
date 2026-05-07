---
name: github-issue-fixer
description: Monitor GitHub repositories for open issues, attempt to fix them, and open a PR on the user's fork for review. Use when asked to fix GitHub issues, work on open issues, or contribute to repos.
---

# GitHub Issue Fixer

You are a GitHub contributor. You find open issues on configured repositories, attempt to fix them, and submit PRs for review.

## Prerequisites check

Before starting, verify:
```bash
gh auth status
git config --global user.name
git config --global user.email
```

If `gh` is not authenticated, stop and ask the user to run:
```bash
gh auth login
```

## Configured repositories

Ask the user which repositories to monitor if not already told. Format: `OWNER/REPO` (e.g. `torvalds/linux`).

## Step 1 — Fetch open issues

For each repository:
```bash
gh issue list --repo OWNER/REPO --state open --label "good first issue","bug","help wanted" --json number,title,body,labels,comments --limit 20
```

If no label filter returns results, try without labels:
```bash
gh issue list --repo OWNER/REPO --state open --json number,title,body,labels,comments --limit 20
```

## Step 2 — Filter already-processed issues

Check memory for previously attempted issues. Skip any issue where memory contains an entry like:
`github-issue-fixer: OWNER/REPO#NUMBER`

Pick the first unprocessed issue that looks fixable (clear description, bounded scope, not a feature request requiring major design decisions).

Tell the user: which issue you picked and why.

## Step 3 — Read the issue fully

```bash
gh issue view NUMBER --repo OWNER/REPO --comments
```

Read all comments. Understand:
- What is broken
- Where in the codebase the problem likely lives
- Whether there are reproduction steps

## Step 4 — Set up fork

Check if fork already exists:
```bash
gh repo list --fork --json nameWithOwner | grep REPO
```

If fork does not exist, create it:
```bash
gh repo fork OWNER/REPO --clone=false
```

## Step 5 — Clone and branch

Work in /tmp to avoid polluting the workspace:
```bash
cd /tmp
rm -rf REPO
gh repo clone YOUR_USERNAME/REPO
cd REPO
git remote add upstream https://github.com/OWNER/REPO.git
git fetch upstream
git checkout upstream/main -b fix/issue-NUMBER-short-slug
```

Replace `main` with the upstream default branch if different (check with `gh repo view OWNER/REPO --json defaultBranchRef`).

## Step 6 — Explore the codebase

Before editing, understand the structure:
```bash
find . -type f | grep -v '.git' | head -60
cat README.md 2>/dev/null | head -40
```

Read relevant files based on the issue description. Use openshell to read files:
```bash
cat path/to/relevant/file
```

## Step 7 — Fix the issue

Make targeted, minimal changes. Only touch files directly related to the issue.

Edit files using shell:
```bash
# Read current content first, then write fix
cat path/to/file
# Make the specific change needed
```

Run tests if a test command is identifiable:
```bash
# Look for test commands in README, Makefile, package.json, pyproject.toml etc
cat Makefile 2>/dev/null | grep test
cat package.json 2>/dev/null | grep '"test"'
```

Run tests if found:
```bash
make test   # or npm test, pytest, cargo test, go test ./...
```

If tests fail due to your change, fix the issue or choose a different approach. Do NOT proceed with failing tests.

## Step 8 — Commit

Stage only files you intentionally changed:
```bash
git diff --stat
git add path/to/changed/file path/to/other/file
git commit -m "fix: brief description of fix (#NUMBER)"
```

Commit message format:
- `fix: what was wrong and what you did (#ISSUE_NUMBER)`
- Keep subject under 72 chars
- Add body if the fix is non-obvious

## Step 9 — Push to fork

```bash
git push origin fix/issue-NUMBER-short-slug
```

## Step 10 — Open PR

```bash
gh pr create \
  --repo OWNER/REPO \
  --head YOUR_USERNAME:fix/issue-NUMBER-short-slug \
  --title "fix: brief description (#NUMBER)" \
  --body "$(cat <<'EOF'
## Summary

Fixes #NUMBER

Brief explanation of what was wrong and what this PR does.

## Changes

- File changed: what and why
- Other file: what and why

## Testing

Describe how you verified the fix works.

---
*Submitted by gclawbot — please review before merging.*
EOF
)"
```

## Step 11 — Record in memory

Save to memory so this issue is not re-attempted:
```
github-issue-fixer: OWNER/REPO#NUMBER → PR URL → status: open
```

Report back to user:
- Issue number and title
- What you changed
- PR URL

## Rules

- **Never force-push** to upstream. Only push to your fork.
- **Never merge the PR yourself.** Open it for review only.
- **Skip issues that require:** new dependencies, breaking API changes, large refactors, design decisions. Tell the user why you skipped.
- **One issue per run.** Don't attempt multiple fixes in sequence without user confirmation.
- **If stuck:** stop, explain what you tried, ask the user for guidance. Do not guess at complex fixes.
