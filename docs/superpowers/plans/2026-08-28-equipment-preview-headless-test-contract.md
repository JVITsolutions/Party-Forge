# Equipment Preview Headless Test Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the two stale equipment-ledger full-suite failures by aligning their headless unit expectations with the visibility-gated preview contract, without changing production behavior.

**Architecture:** `CharacterEquipmentPreview` remains the sole authority for SubViewport scheduling: effectively visible presentations render continuously and invisible or detached presentations stay suspended. The broad equipment-ledger unit fixture remains synchronous and headless, while the two existing real-SceneTree integration runners continue to prove visible activation, hiding, deactivation, and reactivation.

**Tech Stack:** Godot 4.7.1 Mono, GDScript, Party Forge focused/full test runners, Git linked worktree.

## Global Constraints

- Do not modify any production script, scene, resource, asset, or rendering behavior.
- Modify exactly the two stale render-mode assertions and their messages in `tests/unit/test_equipment_inventory_ledger_page.gd`.
- Preserve every actor creation, deactivation cleanup, reactivation, and equipped-visual assertion.
- Keep `tests/integration/character_equipment_preview_visibility_runner.gd` and `tests/integration/equipment_ledger_preview_runner.gd` unchanged and passing.
- The complete suite must finish with `TEST_SUMMARY: PASS`.
- Use isolated temporary `APPDATA` and `LOCALAPPDATA` roots for every Godot command.
- Do not push, merge, or clean the linked worktree.

---

### Task 1: Correct the Invisible Headless Preview Expectations

**Files:**
- Modify: `tests/unit/test_equipment_inventory_ledger_page.gd:56`
- Modify: `tests/unit/test_equipment_inventory_ledger_page.gd:69`
- Test: `tests/unit/test_equipment_inventory_ledger_page.gd`
- Verify unchanged: `tests/integration/character_equipment_preview_visibility_runner.gd`
- Verify unchanged: `tests/integration/equipment_ledger_preview_runner.gd`

**Interfaces:**
- Consumes: `CharacterEquipmentPreview._sync_rendering()`, where a valid presentation uses `SubViewport.UPDATE_ALWAYS` only when `is_visible_in_tree()` is true.
- Produces: a unit contract that separates presentation actor lifecycle from effective SceneTree visibility.

- [ ] **Step 1: Re-run the existing RED proof**

Run the focused unit test before editing:

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
$testData = Join-Path ([IO.Path]::GetTempPath()) ('party-forge-equipment-preview-red-' + [guid]::NewGuid().ToString('N'))
$env:APPDATA = Join-Path $testData 'appdata'
$env:LOCALAPPDATA = Join-Path $testData 'localappdata'
New-Item -ItemType Directory -Path $env:APPDATA,$env:LOCALAPPDATA -Force | Out-Null
& $godot --headless --path (Get-Location).Path --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_equipment_inventory_ledger_page.gd
```

Expected: `TEST_SUMMARY: FAIL (2 failures)` with only `active equipment page enables preview rendering: expected 4, got 0` and `reactivation resumes preview rendering: expected 4, got 0`. The actor creation, cleanup, rebuild, and equipment assertions must not fail.

- [ ] **Step 2: Apply the minimal test-contract correction**

Replace the activation assertion with:

```gdscript
TestAssertions.equal(subviewport.render_target_update_mode, SubViewport.UPDATE_DISABLED, "headless active equipment page builds its preview while invisible rendering stays suspended", failures)
```

Replace the reactivation assertion with:

```gdscript
TestAssertions.equal(subviewport.render_target_update_mode, SubViewport.UPDATE_DISABLED, "headless reactivation rebuilds its preview while invisible rendering stays suspended", failures)
```

Do not change production files or any other assertion.

- [ ] **Step 3: Verify focused GREEN**

Run the same focused command with a new isolated data root.

Expected: `TEST_SUMMARY: PASS (0 failures)`.

- [ ] **Step 4: Verify both visible lifecycle contracts**

Run sequentially with new isolated data roots:

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 900 --script res://tests/integration/character_equipment_preview_visibility_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/equipment_ledger_preview_runner.gd
```

Expected exactly once:

```text
CHARACTER_EQUIPMENT_PREVIEW_VISIBILITY_SUMMARY: PASS
TASK11_EQUIPMENT_LEDGER_PREVIEW_SUMMARY: PASS (0 failures)
```

- [ ] **Step 5: Verify the complete suite**

Run with another new isolated data root:

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 3000 --script res://tests/test_runner.gd
```

Expected: terminal `TEST_SUMMARY: PASS` and exit code `0`.

- [ ] **Step 6: Verify exact scope and hygiene**

```powershell
git diff --check
git diff --name-only HEAD
git diff -- tests/unit/test_equipment_inventory_ledger_page.gd
git status --short
```

Expected: no diff-check errors; the implementation delta names only `tests/unit/test_equipment_inventory_ledger_page.gd`; the diff contains exactly two expectation/message replacements; no generated UID or unrelated file appears.

- [ ] **Step 7: Commit the reviewed repair**

After independent spec and code-quality review approves the exact diff:

```powershell
git add -- tests/unit/test_equipment_inventory_ledger_page.gd
git commit -m "test: align equipment preview visibility contract"
```

Expected: one test-only commit and a clean worktree. Do not push or merge.
