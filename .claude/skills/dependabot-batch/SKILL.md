---
name: dependabot-batch
description: Triage, verify, merge, and deploy a batch of open Dependabot PRs for this project. Reads tuneable autonomy dials to decide which PRs to auto-merge vs escalate. Use when the user asks to process Dependabot PRs, do a Dependabot sweep, clear the Dependabot queue, or similar.
---

# Dependabot batch playbook

This skill runs the repeatable workflow for clearing a batch of Dependabot PRs:
inventory → triage → per-PR rebase/verify/merge → deploy. It gates autonomy
against three config files and one policy section below.

## Config files to read at start

1. `.claude/dependabot-autonomy.yml` -- tuneable dials (auto/ask, compatibility floor)
2. `.claude/dependabot-never-auto.yml` -- gem-specific manual-only list
3. `.claude/known-flakes.md` -- fingerprints for distinguishing flakes from real CI failures

Read all three before Phase 1. Reference them in later phases.

## Hard veto (policy, not a dial)

These categories **always** downgrade to "ask" regardless of dials or compatibility
score. Do not auto-merge under any circumstance:

- Any **major** version bump (x.0.0 in semver)
- Any bump to **ruby** (Gemfile `ruby` directive or `.ruby-version`)
- Any bump to **rails** itself
- Any gem listed in `dependabot-never-auto.yml`
- Any **grouped** Dependabot branch matching `dependabot/bundler/multi-*` -- refuse to process and point the user at their `.github/dependabot.yml` config; per project convention, bundler bumps must be individual

## Phase 1: Inventory

Run `gh pr list --state open --author app/dependabot --json number,title,headRefName,body`.

For each PR, extract and display in a compact table:

| PR | Gem | From → To | Bump type | Group | CI | Compat % |

- **Bump type:** patch / minor / major (from the "From → To" semver delta)
- **Group:** dev-only (gem lives only in `:development` or `:development, :test`) vs runtime (anything else). Check against `Gemfile`.
- **CI:** from `gh pr checks <n>` -- pass / fail / pending
- **Compat %:** parse the Dependabot body -- look for a "Compatibility Score" badge or text. Report `N/A` if absent.

## Phase 2: Pre-flight & triage

**Main-health precheck.** Before touching any PR branch, confirm `main`'s latest
CI run is green (`gh run list --branch main --limit 1`). If red, bail with a
message and stop -- do not rebase onto a broken base.

**Merge-method detection.** Query the repo to find which merge strategies are
allowed and pick the method this batch will use:

```
gh api "repos/{owner}/{repo}" --jq '{squash:.allow_squash_merge,merge:.allow_merge_commit,rebase:.allow_rebase_merge}'
```

Pick the first allowed method in this priority order: **squash → merge → rebase**.
Squash is preferred for clean dependency-bump history; the others are fallbacks
when the repo disallows squash. Store the chosen flag (`--squash` / `--merge` /
`--rebase`) and reuse it for every merge in this batch. If none are allowed,
stop and surface the repo settings to the user.

Do **not** change the repo's merge-method settings to enable squash -- repo
policy is not scoped to this skill, so flipping it would change the default
across all merges (UI, other tools, contributors). Adapt to the repo instead.

**Grouped-branch refusal.** If any PR branch matches `dependabot/bundler/multi-*`,
refuse to process it and point the user at `.github/dependabot.yml`.

**CI failure triage.** For each PR with `CI: fail`:

- Fetch the failure trace (`gh run view <run-id> --log-failed`)
- Match against `known-flakes.md` fingerprints
- If **all** failing PRs match known flake patterns → per the
  `separate_flake_fix_pr` dial, propose a standalone flake-fix PR first,
  stop, and wait for the user to approve/merge it. After they do, re-run the
  skill.
- If **any** failure is not a known flake → stop, surface the trace, and ask the
  user. Do not proceed on that PR.

## Phase 3: Merge order

Propose an order, lowest blast radius first:

1. Dev-only patch bumps
2. Dev-only minor bumps
3. Runtime patch bumps
4. Runtime minor bumps
5. Anything requiring "ask" (majors, never-auto list, sub-floor compat, Ruby/Rails)

Surface the order to the user and proceed.

## Phase 4: Per-PR loop

For each PR in order:

1. `gh pr checkout <n>`
2. `git fetch origin main && git rebase origin/main`
   - If rebase conflicts, stop and surface to the user
3. `bundle install`
4. `bundle exec rake` -- must be clean (per project CLAUDE.md, rubocop first then rspec)
   - If rubocop surfaces new offenses (e.g. from a new cop in a rubocop-plugin bump),
     fix at source in one attempt. Never use `# rubocop:disable`. If not cleanly
     fixable in one pass, stop and ask.
5. `git push --force-with-lease origin <branch>`
6. Monitor CI with the Monitor tool polling `gh pr checks <n>`
7. **Gating decision** once CI is `SUCCESS`:

   | Condition | Action |
   |-----------|--------|
   | Hard veto (major / Ruby / Rails / never-auto list / grouped) | Announce green, wait for user merge |
   | Compat % below `compatibility_score_floor` (or N/A) | Announce green, wait for user merge |
   | Dev-only + patch/minor + `merge_dev_only_with_green_ci: auto` | `gh pr merge <n> <merge-flag> --delete-branch` |
   | Runtime + patch/minor + `merge_runtime_bumps: auto` | `gh pr merge <n> <merge-flag> --delete-branch` |
   | Either dial set to `ask` | Announce green, wait for user merge |

8. After each auto-merge or user-reported merge, `git checkout main && git pull --ff-only` and re-rebase the next PR on the updated main before processing it. This avoids CI running on a stale base.

## Phase 5: Post-batch verification

After the last PR merges:

1. `git checkout main && git pull --ff-only`
2. `bundle install`
3. `bundle exec rake` -- must be clean and green (538 specs / 0 failures, 145 files / 0 offenses, or current equivalents)

If rake fails here, stop. Do not deploy.

## Phase 6: Deploy

If `deploy_after_batch: auto` and Phase 5 passed: run `bin/deploy`. Do not ask.

`bin/deploy` handles its own failure detection (health check, crashed-dyno
detection, rollback hint). Surface its output. If it exits non-zero, surface
the failure and do not treat the batch as complete.

## Post-run summary

Close the session with a table:

| PR | Gem | Bump | Outcome |
|----|-----|------|---------|
| #31 | data_migrate | 11.3.0 → 11.3.1 | auto-merged |
| #29 | importmap-rails | 2.1.0 → 2.2.3 | awaiting user merge (compat N/A) |
| ... | ... | ... | ... |

Plus:
- Flake-fix PR (if any): number, status
- Deploy: release number, health check result

## Escalation rules (short reference)

- Main CI red at start → stop
- Rebase conflict → stop, surface diff
- Grouped-branch PR present → refuse, point at config
- CI failure with unknown fingerprint → stop, surface trace, ask
- Rubocop offense not cleanly fixable in one pass → stop, ask
- `bin/deploy` non-zero exit → stop, surface logs

## Flake-registry upkeep

When a new flake is diagnosed and fixed in the course of running this skill,
append a new entry to `.claude/known-flakes.md` (newest at bottom) before
finishing the session. Include: error signature, typical trigger, fix pattern,
first-observed date and file.
