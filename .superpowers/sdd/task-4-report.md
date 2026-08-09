# Task 4 report: immutable item-roll equipment projection

Status: implementation and local verification complete on `feat/equipment-attribute-application`. Task 5 was not started.

## Scope and contract

- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\equipment-attribute-application`.
- Starting head: `3372410` (`fix: preserve caster tags during regeneration`).
- Task 4 commit: this report's commit (`feat: project equipped item rolls into stats`); resolve the immutable hash with `git log -1`.
- Added `EquipmentModifierProjection`, which exposes only `error`, `source`, and `ok()` plus constructors for atomic success/failure results.
- Added pure `EquipmentModifierProjector.project(member_id, container_id, state, active_item_ids, equipment, foundation, stats)`.
- The projector emits exactly one `equipment_member_<member_id>` source, including an empty source for an empty active set.
- Active item rolls become ordinary `StatModifier` records, preserving all five supported operations and required tags. No parallel stat calculation was added.
- Detailed IDs encode member, canonical slot, immutable item instance, affix index/definition, and roll index.
- Labels use the approved actual em dash: `<base display name> — <affix display name>`.
- Inputs are read through defensive ownership/registry copies. Items, affixes, rolls, equipment bases, foundation definitions, stat definitions, and class Resources are never mutated.

## Validation and atomicity

Projection rejects invalid input before exposing a source. Stable diagnostics use:

```text
PARTY_FORGE_EQUIPMENT_PROJECTION_ERROR member=<id> slot=<slot> item=<item> affix=<affix> roll=<roll> stat=<stat> reason=<reason>
```

The boundary validates member/container/catalog presence, equipment-container kind, active identity uniqueness and exact-one placement, registry references, base and affix identities, affix kind/tier/roll shape, known stats, supported operations, finite and in-range values, required tags, materialized-roll/definition parity, detailed modifier identity uniqueness, complete item codec validity, and the final source through `StatResolver.validate_sources()`.

Disabled/inactive items are deliberately skipped before item/roll projection, so none of their implicit, attribute, typed-damage, or tagged rolls can contribute.

## TDD evidence

### Controlled missing-service RED

Command:

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_equipment_modifier_projector.gd
```

Exact result before production files existed:

```text
TEST_SUMMARY: FAIL (2 failures)
TASK4_RED_EXIT_CODE=1
```

Both failures were the requested missing projector/result scripts. The test suite itself loaded and returned a normal assertion summary; this was not Godot's misleading parser-abort/exit-zero behavior.

### Registration/import

After implementation and syntax correction, a bounded editor import registered both new global classes:

```text
[ DONE ] first_scan_filesystem
[ DONE ] update_scripts_classes
[ DONE ] loading_editor_layout
TASK4_IMPORT_EXIT_CODE=0
```

### Review regression RED

Self-review identified that one item referenced from two equipment slots would otherwise project twice. A test-first duplicate-reference case exited `1` with exactly three assertions: the result incorrectly succeeded, exposed a source, and lacked the required stable error. Counting equipped references before projection made the same case fail closed atomically.

### Focused GREEN

Fresh focused result after all code/test changes:

```text
TEST_SUMMARY: PASS (0 failures)
TASK4_FOCUSED_GREEN_EXIT_CODE=0
```

The final focused output contains no parser, load, assertion, or Task 4 warning diagnostic.

## Coverage

- One active item contains an implicit, attribute prefix, typed-damage suffix, and tagged melee roll; all four appear exactly once and in deterministic slot/affix/roll order.
- A separately equipped inactive item contributes nothing.
- Exact source metadata, detailed modifier IDs, actual-em-dash labels, values, operations, and required tags are asserted.
- Repeated identical input produces byte-equivalent source documents.
- Ownership `to_dictionary()` bytes, caller item dictionaries, and the active-ID array remain unchanged.
- Empty active sets retain a uniform replaceable source with zero modifiers.
- Flat, increased, reduced, more, and less operations project without translation.
- Non-finite values, unsupported operations, unknown stats, empty tags, duplicate active IDs, unknown active IDs, duplicate equipped references, null ownership, and a null stat catalog all fail with exact stable errors, no partial source, and byte-equivalent ownership.

## Complete-suite result

Godot: `4.7.1.stable.official.a13da4feb`.

Fresh complete suite after the final production/test changes:

```text
TEST_SUMMARY: PASS (160 suites)
TASK4_FULL_SUITE_EXIT_CODE=0
```

This is one suite above Task 3's recorded 159-suite baseline. The runner retains its established intentional negative-path `ERROR`/`WARNING` diagnostics, but no `TEST_FAILURE`, script/parse/load failure, or non-zero exit remained.

## Files and hygiene

- `.superpowers/sdd/task-4-report.md`
- `scripts/equipment/equipment_modifier_projection.gd`
- `scripts/equipment/equipment_modifier_projector.gd`
- `tests/unit/test_equipment_modifier_projector.gd`

The bounded import generated `.gd.uid` sidecars for both new scripts and the new test alongside the worktree's pre-existing untracked generated sidecars. No `.gd.uid`, `.import`, `.godot`, ignored scratch artifact, or unrelated file is staged or included in the Task 4 commit.

## Concerns

- No open Task 4 production concern is known.
- The complete runner output is not diagnostically pristine because established tests intentionally exercise and log rejection paths. The authoritative summary is `PASS (160 suites)` with exit `0`; focused Task 4 output is clean.
