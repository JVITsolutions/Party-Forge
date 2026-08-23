# Shared Humanoid/Fit Task 6 Report

## Outcome

Body-preset changes made through `CharacterPresentation.set_body_preset()` now use a staged model candidate. The model resolves every fitted equipment definition for the requested body, validates fitted scenes, shared Skin binding, semantic sockets, and declared hidden regions, then computes candidate visible bounds and grounding without changing live body/equipment state. CharacterPresentation commits only an accepted candidate and never reports failure after activating a changed body.

Commit: the enclosing commit named `feat: make body fit changes transactional`.

## TDD evidence

All Godot runs used `F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe`, this isolated worktree, and task-specific `APPDATA`/`LOCALAPPDATA` roots beneath `.superpowers\sdd`.

### Accepted behavioral RED

The new suite was written before either production file changed. It exercised only the public `CharacterPresentation.set_body_preset()` entry point.

Command:

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_character_body_fit_transaction.gd
```

Result: exit `1`; `TEST_SUMMARY: FAIL (11 failures)`. The failures were the missing shared/variant equipment re-fit and the public API accepting or leaving changed body/region/ground state after fitted-scene, shared-Skin, semantic-socket, body-region, and grounding rejection. There were no parser, loader, or test-setup errors.

The first implementation GREEN exposed one orphan `Node` from the intentional non-`Node3D` fitted-scene rejection. An orphan-count assertion was added before changing cleanup. Its accepted RED was exit `1`, `TEST_SUMMARY: FAIL (1 failures)`, exactly `fitted_scene rejection leaves no orphan candidate nodes: expected 27, got 28`.

### Focused GREEN

Command: the same single-suite command as RED with fresh `task-6-green-accepted` profile roots.

Result: exit `0`; `TEST_SUMMARY: PASS (0 failures)`. No parser, script, test, leak, or orphan warning was emitted.

## Verification

### Required focused matrix

Suites: the new transaction suite plus equipment body-fit resolution, Forge humanoid equipment, shared-skin binding, humanoid semantic sockets, character grounding/UI, character presentation, and character-presentation sandbox.

Result: exit `0`; `TEST_SUMMARY: PASS (0 failures)`. Character-presentation negative-path diagnostics were the suite's established assertions.

### Affected matrix

The nineteen-suite matrix added humanoid rig, playable-class presentations, held-equipment readability, equipment-manifest, Fighter modular assets, Forge base bodies, Forge Vanguard model/animations, and caster/heavy-melee/ranged equipment content.

Result: exit `0`; `TEST_SUMMARY: PASS (0 failures)`.

### Full suite

Command:

```powershell
& $godot --headless --path . --quit-after 1800 --script res://tests/test_runner.gd
```

Result: exit `0`; `TEST_SUMMARY: PASS (212 suites)`. Established negative-path diagnostics appeared; there were no `TEST_FAILURE` lines and the final summary passed.

## Scope and diff

- Modified `scripts/presentation/forge_humanoid_model.gd` with prepare/validate/commit/discard staging for body-fit equipment, hidden regions, candidate bounds, and grounding.
- Modified `scripts/presentation/character_presentation.gd` to use the staged transaction when the model exposes it, while retaining the legacy direct-call path for older model implementations.
- Created `tests/unit/test_character_body_fit_transaction.gd` with public-API shared/variant success and exact rollback coverage.
- Created this task-specific report.
- No production scene, resource, GLB, icon, import sidecar, or other asset was modified.

## Transaction guarantees

- Rigid and shared-skinned equipment candidates are fully resolved and colored in an isolated material cache before live equipment is cleared.
- Shared Skin validation and semantic socket resolution complete before commit.
- Unknown hidden-region declarations reject and free all staged nodes.
- Candidate bounds consider the requested body, planned hidden regions, and staged equipment; invalid or empty bounds reject before body visibility or model position changes.
- Commit validation occurs before the first mutation. After mutation begins, commit performs deterministic replacement, visibility, palette-material cache, hidden-region, grounding, and feedback-color updates and returns success.
- Every rejection preserves node and material identities, body and region visibility, equipment definitions and instances, palette state, active preset, transforms, visible bounds, and ground position.

## Concerns

No blocking or known Task 6 correctness concern remains. Imported auto-rig equipment still must satisfy the existing exact rig/Skin validation before it can participate in this transaction; this task did not modify or promote asset content.

## Important review fixes

The two Important review findings against base `9b46281` were fixed without changing `CharacterPresentation` or any asset/resource content.

- Every resolved target body-fit descriptor now contributes `hide_body_regions` regardless of attachment mode. Unknown rigid-socket regions reject before commit, while valid rigid declarations hide on commit and a target fit that omits them restores authored visibility.
- Candidate bounds now substitute the exact requested visibility for body-preset and body-region nodes instead of inheriting live visibility that the commit will replace. Staged shared-skin and rigid equipment bounds also require effective ancestor visibility; rigid candidates check both their selected attachment ancestry and destination socket ancestry.

### Accepted review RED

The transaction suite was extended first with public `CharacterPresentation.set_body_preset()` coverage for valid rigid hide/restore, unknown rigid-region atomic rejection, restored descendant-region grounding, and an invisible staged attachment ancestor.

Command:

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_character_body_fit_transaction.gd
```

Result before production changes: exit `1`; `TEST_SUMMARY: FAIL (6 failures)`. The precise failures were: the rigid target region remained visible; restored descendant body geometry left `ground_gap = -2.000`; invisible staged equipment produced `ground_gap = 10.500` and `position.y = 10.500`; and the unknown rigid region was accepted, changing the full rollback snapshot. The suite loaded normally with no parser or fixture error.

### Review GREEN and verification

- Focused transaction suite: exit `0`; `TEST_SUMMARY: PASS (0 failures)`.
- Required eight-suite transaction, body-fit, Forge equipment, shared-skin binding, semantic-socket, grounding/UI, character-presentation, and sandbox matrix: exit `0`; `TEST_SUMMARY: PASS (0 failures)`.
- Nineteen-suite affected presentation/content matrix: exit `0`; `TEST_SUMMARY: PASS (0 failures)`.
- Fresh uncontested full suite: exit `0`; `TEST_SUMMARY: PASS (212 suites)`.

The presentation and full-suite runs emitted their established intentional negative-path diagnostics; no `TEST_FAILURE` line was emitted in any GREEN run.

### Review-fix concerns

No blocking or known correctness concern remains from the two Important findings.
