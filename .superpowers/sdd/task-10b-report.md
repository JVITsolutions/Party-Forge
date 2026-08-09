# Task 10B report: retained generator parity

Status: implementation and verification complete; scoped commit pending at report authoring time.

## Scope and root cause

- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\equipment-attribute-application`
- Branch: `feat/equipment-attribute-application`
- Starting head: `af6d2aa` (`fix: align run context coordinator lifecycle`)
- The checked-in Increment 2 Resources were canonical, but three retained authoring paths could overwrite their new rows with stale data:
  - `tools/migrate_typed_combat_data.gd` omitted `caster` from Mage and Cleric attack tags and retained non-canonical ordering.
  - `tools/create_stat_foundation_data.gd` omitted `melee_damage`, `ranged_damage`, `caster_damage`, and `party_influence`.
  - `tools/character_upgrade_content_rows.gd`, consumed by both `tools/create_character_upgrade_data.gd` and `tools/create_default_data.gd`, omitted the four matching keywords.
- `tools/create_default_data.gd` and `tools/class_expansion_rows.gd` already retained the exact Frost Mage/Warlock and Mage/Cleric caster arrays from the Task 3 follow-up. They were covered rather than rewritten.
- The remediation is limited to the Increment 2 attacks/stats/keywords named by the review finding. Existing output outside that increment was not normalized or regenerated in the authoritative worktree.

## TDD evidence

### Controlled RED

Command:

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
$env:APPDATA = Join-Path $repo '.superpowers\sdd\task-10b-red-appdata'
$env:LOCALAPPDATA = Join-Path $repo '.superpowers\sdd\task-10b-red-localappdata'
& $godot --headless --path $repo --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_increment2_generator_parity.gd
```

Result:

```text
TEST_SUMMARY: FAIL (14 failures)
TASK10B_RED_EXIT_CODE=1
```

There were no parser, script-load, or suite-load failures. The 14 assertions consisted of:

- four exact/sorted tag failures for the stale Mage and Cleric typed-combat migration rows;
- four missing Increment 2 stat rows plus the absent testable catalog-construction seam;
- four missing keyword rows plus the missing exact Increment 2 keyword order.

### Minimal source fix

- Mage now retains `[area, caster, fire, projectile]`; Cleric retains `[caster, lightning, projectile]` in the typed-combat migration.
- The stat generator exposes `build_catalog()` and `_initialize()` saves that exact catalog. It appends the four canonical definitions with exact ID, display name, UI group, value format, precision/default/bounds, visibility, capability tags, keyword ID, and default comparison direction.
- The retained keyword table appends the four exact canonical ID/display/explanation/capability rows in canonical order.
- `tests/unit/test_increment2_generator_parity.gd` covers unique IDs, every retained attack table, exact source-row-to-canonical metadata, exact ordered and normalized caster tags, generated/persisted stat and keyword metadata, and the generator-wiring paths through the character-upgrade, default-data, and class-expansion scripts.
- Setting `PARTY_FORGE_GENERATOR_PARITY_CANONICAL_ROOT` lets the same durable suite compare disposable generated Resources with a cold-copied canonical snapshot instead of comparing against the active `res://data` tree.

### Focused GREEN

New direct parity suite:

```text
TEST_SUMMARY: PASS (0 failures)
TASK10B_FOCUSED_PERSISTED_GREEN_EXIT_CODE=0
```

Affected seven-suite batch:

```powershell
& $godot --headless --path $repo --quit-after 600 --script res://tests/focused_test_runner.gd -- `
  tests/unit/test_increment2_generator_parity.gd `
  tests/unit/test_typed_combat_final_fixes.gd `
  tests/unit/test_attack_damage_data.gd `
  tests/unit/test_expanded_class_content.gd `
  tests/unit/test_stat_catalog.gd `
  tests/unit/test_game_catalog.gd `
  tests/unit/test_character_upgrade_integration.gd
```

```text
TEST_SUMMARY: PASS (0 failures)
TASK10B_AFFECTED_GREEN_EXIT_CODE=0
```

The affected batch retained the intentionally asserted invalid-mitigation diagnostic from `test_typed_combat_final_fixes.gd`; there was no `TEST_FAILURE`.

## Disposable cold-copy generation and exact parity

A Git archive of starting head was expanded below ignored `.superpowers/sdd/task-10b-cold-*` paths. Only the three modified source files and parity suite were overlaid. The four canonical attacks plus canonical stat and keyword catalogs were copied to `res://task10b_canonical`; their duplicate top-level Resource UIDs were removed in scratch only. No generator ran with the authoritative worktree as `--path`.

The initial Git-archive-only character-upgrade attempt wrote a parity-correct keyword catalog but exited `1` later because ignored equipment PNG assets were absent while it reloaded class presentation dependencies. That attempt was rejected as generator evidence. An asset-complete disposable base was built by copying the authoritative `assets/` payload (`robocopy` exit `1`, meaning files copied) and importing it with exit `0`; the accepted run below then completed normally.

| Disposable path | Generator result | Post-generation exact parity |
| --- | --- | --- |
| Typed combat migration | exit `0`; `PARTY_FORGE_TYPED_ATTACK_DATA_SAVED count=9` | exit `0`; `TEST_SUMMARY: PASS (0 failures)` |
| Stat foundation generator | exit `0` | exit `0`; `TEST_SUMMARY: PASS (0 failures)` |
| Character-upgrade/keyword generator | exit `0`; `PARTY_FORGE_CHARACTER_UPGRADE_DATA_SAVED upgrades=25 names=10 keywords=58` | exit `0`; `TEST_SUMMARY: PASS (0 failures)` |
| Default-data generator | exit `0`; `DATA_GENERATION_OK` | exit `0`; `TEST_SUMMARY: PASS (0 failures)` |
| Class-expansion migration | exit `1` on its established later starter-loadout capability/tag diagnostics | exit `0`; `TEST_SUMMARY: PASS (0 failures)` for the emitted attack Resources |

The class-expansion result reproduces the pre-existing Task 3 concern: after rewriting/reloading its attack Resources, its unchanged class-validation phase rejects missing armor-weight and weapon capability tags in the retained class rows. Frost Mage and Warlock generated attacks nevertheless matched the canonical Resources exactly. This unrelated migration repair was not folded into Task 10B.

The cold archive emitted text-path fallback warnings for stale Resource UIDs because generated `.gd.uid` files are intentionally absent from Git archives. All required Resources loaded through their exact text paths, and every accepted parity process exited `0` without `TEST_FAILURE`.

## Complete suite

Command:

```powershell
$env:APPDATA = Join-Path $repo '.superpowers\sdd\task-10b-full-appdata'
$env:LOCALAPPDATA = Join-Path $repo '.superpowers\sdd\task-10b-full-localappdata'
& $godot --headless --path $repo --quit-after 1800 --script res://tests/test_runner.gd
```

Fresh result:

```text
TEST_SUMMARY: PASS (165 suites)
TASK10B_FULL_SUITE_EXIT_CODE=0
```

The complete suite emitted its established intentionally asserted negative-path diagnostics and shutdown diagnostics. It contained no `TEST_FAILURE`, parser error, script-load failure, or Task 10B assertion failure.

## Hygiene and changed files

Authored files:

- `tools/migrate_typed_combat_data.gd`
- `tools/create_stat_foundation_data.gd`
- `tools/character_upgrade_content_rows.gd`
- `tests/unit/test_increment2_generator_parity.gd`
- `.superpowers/sdd/task-10b-report.md`

Hygiene evidence:

- `git diff --check` exited `0`.
- `git diff --name-only -- data` was empty after every authoritative test run.
- No canonical generated Resource changed in the authoritative worktree.
- The pre-existing untracked `.gd.uid` inventory remains present and untouched. No Task 10B `.gd.uid` was generated for the new test.
- Cold copies, settings roots, logs, archive ZIPs, `.godot`, `.import`, and scratch snapshots are ignored and are not commit candidates.

## Concerns

- The retained class-expansion migration still exits `1` in its later class-validation stage for the already-recorded starter-loadout capability/tag mismatch. Its relevant attack output is parity-correct.
- Cold archive runs can warn that untracked script UIDs are invalid and fall back to text paths. The accepted asset-complete generator runs and exact parity checks are process-successful except for the separately documented class-expansion validation failure.
- The full suite is green but intentionally noisy because negative-path tests use `push_error`/`push_warning` and the project retains established shutdown diagnostics.
