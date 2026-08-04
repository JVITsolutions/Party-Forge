# Runtime Hygiene Follow-ups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden the main-menu integration runner, stop expected attack cancellations from emitting runtime errors, and remove the 14 known GDScript warnings without changing gameplay.

**Architecture:** Give `PartyForgeMain` and `SettingsScreen` an injectable settings path so integration tests never touch the normal settings artifact. Split expected combat cancellation from invariant-breaking sequence errors while preserving target locking and locomotion recovery. Resolve warnings with explicit types, names, branches, and integer-floor calculations, then verify behavior through focused and full gates.

**Tech Stack:** Godot 4.7.1, typed GDScript, the custom `focused_test_runner.gd`, standalone integration runners, Git worktrees.

## Global Constraints

- Work only in `.worktrees/runtime-hygiene` until review and integration.
- Use test-first RED/GREEN cycles for settings isolation and combat cancellation.
- Do not weaken target revalidation, retarget attacks, or suppress genuine sequence failures.
- Do not touch the four existing safety stashes.
- Physical-controller certification remains deferred until the owner is home.

---

### Task 1: Isolate navigation-runner settings

**Files:**
- Modify: `scripts/game/main.gd`
- Modify: `scripts/ui/settings/settings_screen.gd`
- Modify: `tests/unit/test_settings_screen.gd`
- Modify: `tests/integration/main_menu_navigation_runner.gd`

**Interfaces:**
- Produces: `PartyForgeMain.settings_path: String`, defaulting to `PartyForgeSettingsStore.DEFAULT_PATH`.
- Produces: `SettingsScreen.configure(store, settings, profile_manager = null, settings_path = PartyForgeSettingsStore.DEFAULT_PATH)`.

- [x] **Step 1: Write the failing custom-path persistence test**

Add a test fixture that configures `SettingsScreen` with a unique `user://tests/...cfg` path, applies a changed setting, and asserts that `PartyForgeSettingsStore.load_settings(custom_path)` contains the change.

- [x] **Step 2: Run the focused test and verify RED**

Run:

```powershell
godot --headless --path . --quit-after 60 --script res://tests/focused_test_runner.gd -- tests/unit/test_settings_screen.gd
```

Expected: FAIL because `SettingsScreen.configure` does not yet accept or use the custom path.

- [x] **Step 3: Implement the minimal settings-path injection**

Store the configured path in `SettingsScreen`, pass it to `save_settings`, and have `PartyForgeMain` use its public `settings_path` for both load and screen configuration.

- [x] **Step 4: Move the integration runner to its disposable path**

Set `main.settings_path` before adding it to the tree, save/load only that path, and make cleanup remove only that path plus its `.tmp` and `.bak` artifacts.

- [x] **Step 5: Verify GREEN and the standalone runner**

Run the focused settings test and `main_menu_navigation_runner.gd`; both must pass.

- [x] **Step 6: Commit**

```powershell
git add scripts/game/main.gd scripts/ui/settings/settings_screen.gd tests/unit/test_settings_screen.gd tests/integration/main_menu_navigation_runner.gd
git commit -m "test: isolate main menu navigation settings"
```

### Task 2: Treat target loss as expected attack cancellation

**Files:**
- Modify: `tests/unit/test_attack_sequence_controller.gd`
- Modify: `scripts/combat/attack_sequence_controller.gd`

**Interfaces:**
- Produces: private `_cancel_expected()` behavior that clears the active sequence and restores locomotion without emitting `PARTY_FORGE_ATTACK_SEQUENCE_ERROR`.
- Preserves: `cancel(reason)` as the diagnostic path for missing events, stale protocol state, failed presentation, and explicit abnormal cancellation.

- [x] **Step 1: Write the failing cancellation assertions**

Record the sequence-error count before invalidating the locked target and before downing the owner. Assert that each release clears the sequence, performs no execution or retargeting, restores locomotion, and leaves the error count unchanged.

- [x] **Step 2: Run the focused test and verify RED**

Expected: FAIL because both normal races currently call `cancel(reason)`, which emits `PARTY_FORGE_ATTACK_SEQUENCE_ERROR`.

- [x] **Step 3: Implement the minimal expected-cancellation path**

Add:

```gdscript
func _cancel_expected() -> void:
	_clear_active()
	_return_to_locomotion()
```

Use it only when the locked target is no longer valid at release or the owner becomes downed at release.

- [x] **Step 4: Verify GREEN**

Run `tests/unit/test_attack_sequence_controller.gd` and the playable-class presentation test. Genuine stale, duplicate, and missing-event diagnostics must still be asserted.

- [x] **Step 5: Commit**

```powershell
git add tests/unit/test_attack_sequence_controller.gd scripts/combat/attack_sequence_controller.gd
git commit -m "fix: cancel invalid attack targets quietly"
```

### Task 3: Remove the known GDScript warnings

**Files:**
- Modify: `scripts/game/party_capacity_policy.gd`
- Modify: `scripts/game/combat_test_policy.gd`
- Modify: `scripts/enemies/enemy_projectile.gd`
- Modify: `scripts/ui/ledger/character_ledger.gd`
- Modify: `scripts/settings/party_forge_settings_store.gd`
- Modify: `scripts/profile/profile_codec.gd`
- Modify: `scripts/progression/passive_tree/passive_tree_progression_service.gd`
- Modify: `scripts/ui/settings/additional_settings_page.gd`
- Modify: `scripts/ui/settings/profiles_settings_page.gd`
- Modify: `scripts/ui/class_selection_panel.gd`
- Modify: `scripts/ui/passive_tree/passive_tree_canvas.gd`

**Interfaces:**
- Preserves all public signatures except removing the unused private `profile` argument from `_requirements_pass`.

- [x] **Step 1: Apply behavior-preserving warning corrections**

Rename shadowing parameters/locals, replace incompatible ternaries with explicit branches, use explicit enum casts, express intended integer flooring explicitly, remove the unused private argument, and rename the passive-tree projection parameter.

- [x] **Step 2: Run focused owning suites**

Run the settings, profile, projectile, ledger, class-selection, and passive-tree focused tests. Expected: all pass with no new failure marker.

- [x] **Step 3: Run a fresh import and full suite**

Expected: import exit 0 with zero script/parse/loader errors and exact `TEST_SUMMARY: PASS (112 suites)`.

- [x] **Step 4: Commit**

```powershell
git add scripts
git commit -m "chore: resolve actionable gdscript warnings"
```

### Task 4: Final verification and handoff

**Files:**
- Create: `docs/verification/2026-08-04-runtime-hygiene-followups.md`

**Interfaces:**
- Produces: exact commands, pass markers, known remaining diagnostics, and the deferred physical-controller row.

- [x] **Step 1: Run `git diff --check`, focused regressions, full import, complete suite, and startup smoke**

- [x] **Step 2: Remove only verification-generated sidecars through the established validated allowlist**

- [x] **Step 3: Obtain a fresh read-only review**

- [x] **Step 4: Record evidence and commit the verification document**

- [x] **Step 5: Recheck clean authoritative `main` before any fast-forward integration**
