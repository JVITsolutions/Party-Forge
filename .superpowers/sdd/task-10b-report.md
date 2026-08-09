# Task 10B report: retained generator parity

Status: review follow-up implemented and verified; narrow follow-up commit pending at report authoring time. The initial Task 10B implementation is commit `227a5fc`.

## Scope and root cause

- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\equipment-attribute-application`
- Branch: `feat/equipment-attribute-application`
- Starting head: `af6d2aa`; initial Task 10B head: `227a5fc`.
- The initial fix synchronized the four Increment 2 attack, stat, and keyword additions. Review then found that the retained stat and keyword generators were still destructive outside that filtered subset:
  - `tools/create_stat_foundation_data.gd` authored only 31 of the canonical 37 definitions and gave resistances the stale `defense` UI group.
  - `tools/character_upgrade_content_rows.gd` authored only 58 of the canonical 81 keywords, omitting six attributes and seventeen equipment capability keywords.
  - The regression compared only selected IDs and used source-string wiring checks instead of behaviorally executing the default keyword path.
- Strengthening the regression across every retained attack row additionally exposed one older source drift: `rogue_flurry` range was `1.6` in `tools/class_expansion_rows.gd` but `2.0` in the canonical Resource.

## TDD evidence

### Initial Task 10B RED

The initial test-first regression failed with `TEST_SUMMARY: FAIL (14 failures)`, covering the four stale caster-tag arrays, four missing Increment 2 stats plus the absent catalog builder, and four missing keywords plus their order. There were no parse or suite-load failures.

### Review follow-up controlled RED

After replacing the filtered regression with complete-catalog/source-table comparisons, before changing production sources:

```powershell
$env:APPDATA = Join-Path $repo '.superpowers\sdd\task-10b-review-red-appdata'
$env:LOCALAPPDATA = Join-Path $repo '.superpowers\sdd\task-10b-review-red-localappdata'
& $godot --headless --path $repo --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_increment2_generator_parity.gd
```

```text
TEST_SUMMARY: FAIL (461 failures)
TASK10B_REVIEW_RED_EXIT_CODE=1
```

The failures were behavioral parity failures, not parser/script/suite-load failures. They proved the 31-vs-37 stat source catalog, 58-vs-81 keyword source catalog, absent behavioral keyword builder, shifted metadata/order, stale resistance grouping, and `rogue_flurry` range drift.

### Minimal source fix and durable regression

- The stat builder now reproduces all 37 canonical definitions in exact loaded order. The six attributes include exact display/group/format/precision/default/bounds/visibility/tags/keyword/comparison metadata, and all resistances use `ui_group = resistances`.
- The keyword table now reproduces all 81 canonical definitions in exact loaded order, including the six attributes and seventeen equipment capability keywords with exact display, explanation, and capability metadata.
- `create_character_upgrade_data.gd` exposes `build_keyword_catalog()`; both its direct generator and `create_default_data.gd` exercise that same behavioral path.
- The retained expansion row now preserves canonical `rogue_flurry` range `2.0`.
- `test_increment2_generator_parity.gd` now checks every row in all three retained attack tables, exact ordered tags and complete attack metadata, the complete ordered 37-definition stat catalog and every metadata field, the complete ordered 81-definition keyword rows/catalog and every metadata field, and persisted outputs. `PARTY_FORGE_GENERATOR_PARITY_CANONICAL_ROOT` supports comparison against an external snapshot in disposable copies.

### Focused and affected GREEN

Direct parity suite:

```text
TEST_SUMMARY: PASS (0 failures)
TASK10B_REVIEW_FOCUSED_EXIT_CODE=0
```

Affected seven-suite batch (`test_increment2_generator_parity`, typed-combat final fixes, attack damage data, expanded class content, stat catalog, game catalog, and character-upgrade integration):

```text
TEST_SUMMARY: PASS (0 failures)
TASK10B_REVIEW_AFFECTED_EXIT_CODE=0
```

The affected batch retained the intentionally asserted invalid-mitigation diagnostic from `test_typed_combat_final_fixes.gd`; there was no `TEST_FAILURE`.

## Asset-complete disposable cold-copy generation

Fresh disposable project copies were created below ignored `.superpowers/sdd/task-10b-review2-*` paths. The complete ignored `assets/` payload was present, and the keyword/default/expansion copies completed Godot `--import` with exit `0` and 1,192 imported artifacts before accepted generator runs. An external snapshot contained all fifteen canonical attack Resources plus the canonical stat and keyword catalogs, preventing a generated output from becoming its own expected value. No generator ran with the authoritative worktree as `--path`.

The first keyword attempt was rejected as evidence because copied `.png.import` sidecars existed without compiled `.godot/imported` payload. It exited `1` while reloading class presentation dependencies. After the explicit terminating import completed, the accepted asset-complete run succeeded.

| Disposable generator | Generator result | Exact full parity result |
| --- | --- | --- |
| Typed-combat migration | exit `0`; `PARTY_FORGE_TYPED_ATTACK_DATA_SAVED count=9` | exit `0`; `TEST_SUMMARY: PASS (0 failures)` |
| Stat foundation generator | exit `0` | exit `0`; `TEST_SUMMARY: PASS (0 failures)` for all 37 ordered definitions and metadata |
| Character-upgrade/keyword generator | exit `0`; `PARTY_FORGE_CHARACTER_UPGRADE_DATA_SAVED upgrades=25 names=10 keywords=81` | exit `0`; `TEST_SUMMARY: PASS (0 failures)` for all 81 ordered definitions and metadata |
| Default-data generator | exit `0`; `DATA_GENERATION_OK` | exit `0`; `TEST_SUMMARY: PASS (0 failures)` for every retained attack and all 81 behaviorally generated keyword definitions; the same suite also reconfirmed the complete stat source/persisted catalog |
| Class-expansion migration | expected exit `1` on its established later starter-loadout capability diagnostics | exit `0`; `TEST_SUMMARY: PASS (0 failures)` for every emitted retained attack, including `rogue_flurry` |

The class-expansion exit remains the previously recorded, unrelated starter-loadout capability/tag mismatch. Its generated attacks are parity-correct. Cold copies also warn about intentionally absent Git-archive script UIDs and fall back to exact text paths; accepted parity processes exit `0`.

## Complete suite

```powershell
$env:APPDATA = Join-Path $repo '.superpowers\sdd\task-10b-review-full-appdata'
$env:LOCALAPPDATA = Join-Path $repo '.superpowers\sdd\task-10b-review-full-localappdata'
& $godot --headless --path $repo --quit-after 1800 --script res://tests/test_runner.gd
```

Fresh result:

```text
TEST_SUMMARY: PASS (165 suites)
TASK10B_REVIEW_FULL_SUITE_EXIT_CODE=0
```

The complete suite emitted its established intentionally asserted negative-path and shutdown diagnostics. It contained no Task 10B assertion, parser, script-load, or suite-load failure.

## Hygiene and changed files

Follow-up authored files:

- `tools/create_stat_foundation_data.gd`
- `tools/character_upgrade_content_rows.gd`
- `tools/create_character_upgrade_data.gd`
- `tools/class_expansion_rows.gd`
- `tests/unit/test_increment2_generator_parity.gd`
- `.superpowers/sdd/task-10b-report.md`

Hygiene evidence:

- `git diff --check` exits `0`.
- `git diff --name-only -- data` is empty after all authoritative test runs.
- No canonical generated Resource changed in the authoritative worktree.
- The pre-existing untracked `.gd.uid` inventory remains present and unstaged; no `.gd.uid`, `.import`, log, settings root, or scratch copy is a commit candidate.

## Remaining concern

The retained class-expansion migration still exits `1` after attack generation because its older class rows do not yet carry the equipment capability tags required by starter-loadout validation. This is separate from the now-proven attack/stat/keyword generator parity.
