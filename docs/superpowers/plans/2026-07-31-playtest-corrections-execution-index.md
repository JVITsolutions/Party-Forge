# Playtest Corrections Execution Index

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement these plans task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the approved July 31 playtest correction slice through five independently reviewable implementation plans.

**Architecture:** Preserve the saved live-project state first, then execute isolated plans in dependency order. Simulation/combat contracts land before progression and enemies; UI plans consume those stable interfaces without changing their semantics.

**Tech Stack:** Godot 4.7.1 Mono, typed GDScript, Godot Resources and scenes, PowerShell, Git worktrees, and the existing custom headless test runner.

## Global Constraints

- Approved design: `docs/superpowers/specs/2026-07-31-playtest-corrections-progression-enemy-pacing-design.md` at commit `b7aeec1`.
- Preserve the 22 saved modified files visible on `main` at planning time; do not discard or overwrite them.
- Capture those files in a clearly named baseline commit before creating the implementation worktree.
- Use `F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe` for headless verification.
- Worktree feature implementation must not run against the live editor checkout.
- Reload or restart the live Godot editor after verified commits are integrated; do not let stale in-memory scenes overwrite external edits.
- Production level-up count is exactly five.
- Developer party cap remains exactly 24.
- XP multiplier is 100%–1000% and applies on the next run.
- `range` controls acquisition/effect/travel reach; `area_radius` controls the radius around the resolved impact.
- Boltcaster projectiles are red and linear; Spitter projectiles are purple and homing.
- The five-card reveal preselects outcomes and resolves in about 1.1 seconds.
- No Heat, difficulty selector, item rarity mechanics, full enemy `StatResolver`, inventory/equipment implementation, or mid-run settings application enters this slice.

---

## Execution Order

1. `2026-07-31-playtest-corrections-01-simulation-combat.md`
2. `2026-07-31-playtest-corrections-02-progression-dev-controls.md`
3. `2026-07-31-playtest-corrections-03-enemy-pacing-projectiles.md`
4. `2026-07-31-playtest-corrections-04-level-up-presentation.md`
5. `2026-07-31-playtest-corrections-05-ledger-24-members.md`

Each plan must finish with passing focused tests, the full suite or an evidence-backed list of unrelated failures, parser/import validation, and a bounded commit. Later plans may rebase onto or continue from the verified branch produced by the prior plan.

## Baseline Preservation Gate

- [ ] **Step 1: Record the exact saved live state**

Run from the live checkout:

```powershell
git status --short --branch
git diff --stat
git diff --name-only
git diff --check
```

Expected: the 22 previously recorded modified paths remain present; no new unreviewed path is silently included.

- [ ] **Step 2: Record the pre-existing automated-test state**

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --script res://tests/test_runner.gd 2>&1 | Tee-Object -FilePath 'docs/validation/evidence/2026-07-31-saved-baseline-tests.log'
```

Expected: any failures are recorded verbatim. At planning time, two obsolete Rogue range expectations were known because the saved resource is intentionally `2.0` while older tests expect `1.6`.

- [ ] **Step 3: Commit only the recorded saved baseline**

Stage the exact paths returned by Step 1, including the test evidence log, inspect the staged diff, then commit:

```powershell
git add -- data/attacks/fighter_cleave.tres data/attacks/frost_shard.tres data/attacks/guardian_charge.tres data/attacks/guardian_shockwave.tres data/attacks/mage_burst.tres data/attacks/paladin_smite.tres data/attacks/ranger_shot.tres data/attacks/rogue_flurry.tres data/attacks/spitter_projectile.tres data/attacks/swarmer_contact.tres data/classes/rogue.tres data/damage_types/core_damage_types.tres data/keywords/core_keywords.tres data/stats/core_stats.tres data/upgrades/cards/alacrity.tres data/upgrades/cards/deadeye.tres docs/superpowers/plans/2026-07-29-party-forge-godot-handbook.md scenes/ui/upgrade_card.tscn scripts/game/game_run.gd scripts/ui/health_bar_3d.gd scripts/ui/hud.gd scripts/ui/run_result_panel.gd docs/validation/evidence/2026-07-31-saved-baseline-tests.log
git diff --cached --name-status
git diff --cached --stat
git commit -m "chore: preserve July 31 saved Godot state"
```

Expected: `git status --short` is clean except for intentionally ignored local integrations and generated caches.

- [ ] **Step 4: Create the isolated implementation worktree using the required skill**

Invoke `superpowers:using-git-worktrees`, then create a feature worktree rooted at the clean baseline commit. The intended branch name is `feature/playtest-corrections` and the intended directory is `.worktrees/playtest-corrections`.

Expected: `git status --short --branch` is clean in both the live checkout and feature worktree before Plan 01 begins.

## Final Integration Gate

- [ ] Run all five plans in order and verify every plan commit exists.
- [ ] Run the full suite and parser/import scan in the feature worktree.
- [ ] Run the manual acceptance checklist from the approved design.
- [ ] Integrate the verified branch into `main` without rewriting the saved baseline commit.
- [ ] Restart/reload the live Godot editor before saving anything there.
- [ ] Launch the game from the live checkout and record the final smoke result.
