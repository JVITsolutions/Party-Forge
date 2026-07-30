# Party Forge Working-Tree Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the live Party Forge checkout to a clean, runnable state without removing any committed stat, combat, class, catalog, handbook, or upgrade-design work.

**Architecture:** Treat current `HEAD` as immutable and repair only the audited uncommitted delta. Capture a complete external backup, stop the stale editor, restore the ten explicitly audited tracked paths from current `HEAD`, reapply the intentional Godot AI autoload, locally exclude preserved vendor/delivery artifacts, and verify both headless and live behavior before reopening the editor.

**Tech Stack:** Git, PowerShell, Godot 4.7.1 stable Mono, typed GDScript, the existing custom test runner, and the connected Godot AI editor bridge.

## Global Constraints

- Never run `git reset`, `git checkout`, `git clean`, or a recursive delete against the repository.
- Never move, detach, rewrite, or revert `HEAD`; the committed stat backend, typed combat, nine classes, catalog selector, handbook, and character-targeted-upgrades design are immutable recovery inputs.
- Before any restore, require `git merge-base --is-ancestor 5dd6a5d HEAD` to exit `0`; this proves the verified nine-class head remains in history.
- Back up every dirty tracked byte and every untracked artifact before restoring any path.
- Preserve `addons/godotsteam/` and `Party-Forge-Godot-Handbook-6977ae6.zip` in place; exclude them only through `.git/info/exclude`.
- Preserve the tracked `addons/godot_ai/` plugin and commit its required `_mcp_game_helper` autoload.
- Restore the effective `display/window/stretch/aspect="keep"` behavior and the catalog-driven 760x440 class selector with `Content/Scroll/Grid`. Godot 4.7 may canonicalize the `keep` default by omitting its explicit source line when the editor opens.
- Track `tests/unit/test_responsive_ui.gd.uid`.
- Expected automated baseline after repair: `TEST_SUMMARY: PASS (32 suites)` with no `SCRIPT ERROR` or unexpected `TEST_FAILURE`.
- Leave Godot open on the clean saved `res://scenes/game/main.tscn`, stopped, unmodified, and ready; do not use Save All during recovery verification.

---

### Task 1: Back Up and Reconcile the Working Tree

**Files:**
- Restore from current `HEAD`: `data/classes/fighter.tres`
- Restore from current `HEAD`: `data/stats/core_stats.tres`
- Restore from current `HEAD`: `docs/superpowers/plans/2026-07-29-party-forge-godot-handbook.md`
- Modify from restored `HEAD`: `project.godot`
- Restore from current `HEAD`: `scenes/game/main.tscn`
- Restore from current `HEAD`: `scenes/ui/hud.tscn`
- Restore from current `HEAD`: `scripts/game/game_run.gd`
- Restore from current `HEAD`: `scripts/ui/hud.gd`
- Restore from current `HEAD`: `scripts/ui/level_up_panel.gd`
- Restore from current `HEAD`: `scripts/ui/run_result_panel.gd`
- Track: `tests/unit/test_responsive_ui.gd.uid`
- Modify locally only: `.git/info/exclude`
- Create outside repository: `F:\Projects(root)\Game dev\Projects\party-forge-recovery-backups\2026-07-30-working-tree-recovery`

**Interfaces:**
- Consumes: current committed `HEAD`, verified ancestor `5dd6a5d`, the audited dirty-path list, and the currently connected Godot editor.
- Produces: commit containing only the Godot AI autoload and responsive-test UID; preserved local GodotSteam and handbook ZIP; empty `git status --short`.

- [ ] **Step 1: Prove the committed foundations remain in history**

```powershell
$project = 'F:\Projects(root)\Game dev\Projects\party-forge'
git -C $project merge-base --is-ancestor 5dd6a5d HEAD
if ($LASTEXITCODE -ne 0) { throw 'Verified nine-class foundation is not an ancestor of HEAD.' }
git -C $project log -12 --oneline
git -C $project status --short
```

Expected: the log contains `5dd6a5d docs: document nine class catalog`, `b0be05a feat: build catalog driven class selector`, and the six preceding class-expansion commits. Status lists only the ten audited modified paths plus the three approved untracked paths.

- [ ] **Step 2: Stop and close Godot before touching saved resources**

Use the connected editor bridge to stop the game, save no scene, and quit the editor. Then confirm the editor process has exited:

```powershell
Get-Process 'Godot_v4.7.1-stable_mono_win64' -ErrorAction SilentlyContinue
```

Expected: no Party Forge Godot editor process remains. The separate `godot-ai.exe` server may remain running.

- [ ] **Step 3: Capture a complete external recovery copy**

```powershell
$project = 'F:\Projects(root)\Game dev\Projects\party-forge'
$backup = 'F:\Projects(root)\Game dev\Projects\party-forge-recovery-backups\2026-07-30-working-tree-recovery'
if (Test-Path -LiteralPath $backup) { throw "Backup already exists: $backup" }
New-Item -ItemType Directory -Path $backup | Out-Null
git -C $project diff --binary --output="$backup\working-tree.patch"
git -C $project status --porcelain=v2 | Set-Content -Encoding UTF8 "$backup\status-before.txt"
git -C $project rev-parse HEAD | Set-Content -Encoding ASCII "$backup\head-before.txt"
Copy-Item -LiteralPath "$project\Party-Forge-Godot-Handbook-6977ae6.zip" -Destination $backup
Copy-Item -LiteralPath "$project\addons\godotsteam" -Destination "$backup\godotsteam" -Recurse
Copy-Item -LiteralPath "$project\tests\unit\test_responsive_ui.gd.uid" -Destination $backup
Get-FileHash -Algorithm SHA256 "$project\Party-Forge-Godot-Handbook-6977ae6.zip" | Format-List | Out-File "$backup\artifact-hashes.txt"
Get-ChildItem -LiteralPath "$project\addons\godotsteam" -Recurse -File | Get-FileHash -Algorithm SHA256 | Format-Table -AutoSize | Out-File -Append "$backup\artifact-hashes.txt"
```

Expected: the backup contains the binary Git patch, status, exact starting HEAD, the ZIP, a complete GodotSteam copy, the UID, and hashes. The source artifacts remain untouched in the project.

- [ ] **Step 4: Reconfirm the dirty set has not changed since the audit**

```powershell
$expectedModified = @(
  'data/classes/fighter.tres',
  'data/stats/core_stats.tres',
  'docs/superpowers/plans/2026-07-29-party-forge-godot-handbook.md',
  'project.godot',
  'scenes/game/main.tscn',
  'scenes/ui/hud.tscn',
  'scripts/game/game_run.gd',
  'scripts/ui/hud.gd',
  'scripts/ui/level_up_panel.gd',
  'scripts/ui/run_result_panel.gd'
)
$actualModified = @(git -C $project diff --name-only)
Compare-Object $expectedModified $actualModified
if ($actualModified.Count -ne $expectedModified.Count -or (Compare-Object $expectedModified $actualModified)) {
  throw 'Dirty tracked scope changed after backup; stop for a fresh audit.'
}
```

Expected: `Compare-Object` prints nothing.

- [ ] **Step 5: Restore only the ten audited tracked paths from current HEAD**

```powershell
git -C $project restore --source=HEAD -- `
  data/classes/fighter.tres `
  data/stats/core_stats.tres `
  docs/superpowers/plans/2026-07-29-party-forge-godot-handbook.md `
  project.godot `
  scenes/game/main.tscn `
  scenes/ui/hud.tscn `
  scripts/game/game_run.gd `
  scripts/ui/hud.gd `
  scripts/ui/level_up_panel.gd `
  scripts/ui/run_result_panel.gd
```

Expected: the tracked working tree matches current `HEAD`. This command does not alter commits, other paths, the ZIP, GodotSteam, or the UID.

- [ ] **Step 6: Reapply the intentional Godot AI autoload**

Patch `project.godot` so its display and autoload sections are exactly:

```ini
[autoload]

_mcp_game_helper="*res://addons/godot_ai/runtime/game_helper.gd"

[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/mode=3
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
```

Expected: the game helper remains available, and the responsive aspect setting is restored.

- [ ] **Step 7: Locally exclude preserved artifacts without changing project policy**

Append these exact lines to `.git/info/exclude` if absent:

```gitignore
/Party-Forge-Godot-Handbook-*.zip
/addons/godotsteam/
```

Do not add them to `.gitignore`, and do not delete or move either artifact.

- [ ] **Step 8: Stage and inspect only intentional recovery changes**

```powershell
git -C $project add -- project.godot tests/unit/test_responsive_ui.gd.uid
git -C $project diff --cached --check
git -C $project diff --cached --name-status
git -C $project diff --cached -- project.godot tests/unit/test_responsive_ui.gd.uid
git -C $project status --short
```

Expected: the index contains only `project.godot` and `tests/unit/test_responsive_ui.gd.uid`. The project diff adds the autoload while retaining `window/stretch/aspect="keep"`; the UID contains `uid://cwon70rpdxxsc`. Ignored GodotSteam and ZIP remain on disk but do not appear in status.

- [ ] **Step 9: Commit the bounded recovery state**

```powershell
git -C $project commit -m "chore: stabilize Godot project state"
git -C $project status --short
git -C $project show --stat --oneline --summary HEAD
```

Expected: the commit contains two files and `git status --short` is empty.

---

### Task 2: Verify Headless and Live Godot Behavior

**Files:**
- Verify: `project.godot`
- Verify: `scenes/ui/hud.tscn`
- Verify: `tests/test_runner.gd`
- Verify live: `scenes/game/main.tscn`

**Interfaces:**
- Consumes: the clean Task 1 checkout and committed Godot AI autoload.
- Produces: import/test evidence, a runnable nine-class selector, clean logs, and a reopened stopped/ready editor.

- [ ] **Step 1: Run parser/import and the complete automated suite**

```powershell
$project = 'F:\Projects(root)\Game dev\Projects\party-forge'
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
$importLog = 'F:\Projects(root)\Game dev\Projects\party-forge-recovery-backups\2026-07-30-working-tree-recovery\import-after.log'
$testLog = 'F:\Projects(root)\Game dev\Projects\party-forge-recovery-backups\2026-07-30-working-tree-recovery\tests-after.log'
& $godot --headless --path $project --import 2>&1 | Tee-Object -FilePath $importLog
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed.' }
& $godot --headless --path $project --script res://tests/test_runner.gd 2>&1 | Tee-Object -FilePath $testLog
if ($LASTEXITCODE -ne 0) { throw 'Party Forge test suite failed.' }
if (-not (Select-String -Path $testLog -Pattern 'TEST_SUMMARY: PASS \(32 suites\)' -Quiet)) { throw 'Expected 32-suite PASS summary missing.' }
if (Select-String -Path $testLog -Pattern 'SCRIPT ERROR|TEST_FAILURE' -Quiet) { throw 'Unexpected script or test failure found.' }
```

Expected: import exits `0`; tests exit `0`; summary is `TEST_SUMMARY: PASS (32 suites)`; intentional negative-test diagnostics may appear, but no `SCRIPT ERROR` or `TEST_FAILURE` appears.

- [ ] **Step 2: Verify the recovered source contracts directly**

```powershell
rg -n '_mcp_game_helper' "$project\project.godot"
rg -n 'class_selection_panel.gd|Content/Scroll/Grid|offset_left = -380.0|offset_right = 380.0' "$project\scenes\ui\hud.tscn"
rg -n 'name="(Fighter|Ranger|Mage|Cleric)" type="Button" parent="ClassSelection/Content"' "$project\scenes\ui\hud.tscn"
```

Expected: the first two searches find the autoload and required selector nodes. The hard-coded-button search returns no matches. After the editor reconnects, require `project_manage(op="settings_get", key="display/window/stretch/aspect")` to return `keep`; accept Godot's clean source canonicalization if the explicit default line is omitted.

- [ ] **Step 3: Reopen Godot visibly on the repaired project**

```powershell
$editor = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64.exe'
Start-Process -FilePath $editor -ArgumentList @('--editor', '--path', $project)
```

Poll the Godot AI session list until `party-forge` reports `readiness="ready"` and `current_scene="res://scenes/game/main.tscn"`. If another scene opens, use the editor bridge to open `main.tscn`.

- [ ] **Step 4: Run the project and verify the nine-class selector**

Clear the connected editor/game log buffers, run the main scene with autosave disabled, and inspect the live UI. The freshly restarted editor must run the clean saved scene without serializing it. Require:

```text
PARTY_FORGE_BOOT_OK
PARTY_FORGE_CLASS_SELECTION_READY
```

The selector must expose nine catalog-generated class buttons, including `Class_marksman`. Select Fighter once and require the run to start without `main.gd:133`, `SCRIPT ERROR`, or new editor/game errors.

- [ ] **Step 5: Stop and prove final cleanliness**

Stop the project through the editor bridge. Open `res://scenes/game/main.tscn`, require editor readiness `ready`, and confirm the freshly loaded scene has no unsaved-change marker. Do not invoke scene save or Save All. Then run:

```powershell
git -C $project status --short
git -C $project diff --check
git -C $project log -5 --oneline
```

Expected: status and diff check are empty. The log retains the stat/class foundation commits in its ancestry and includes `chore: stabilize Godot project state`. Godot remains open, stopped, unmodified, and ready on `main.tscn`.

After recovery, create the character-targeted-upgrades feature worktree through the `using-git-worktrees` workflow. Do not implement that feature in the live root; use the root only for verified integration and Godot AI acceptance.
