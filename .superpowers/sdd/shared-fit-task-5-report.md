# Shared Humanoid/Fit Task 5 Report

## Outcome

Implemented a separate shared-skinned equipment staging and rebinding path. A candidate is built from only the active fit descriptor's `MeshInstance3D` content, validated against the actor's exact canonical rig and every mesh's real `Skin`/vertex data, attached hidden, and made visible only after the prior equipment can be atomically replaced.

Commit: the enclosing commit named `feat: bind shared skinned equipment`.

## TDD evidence

All Godot runs used `F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe`, this isolated worktree, and task-specific `APPDATA`/`LOCALAPPDATA` roots beneath `.superpowers\sdd`.

### Baseline

Command:

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_forge_humanoid_equipment.gd tests/unit/test_equipment_body_fit_resolution.gd tests/unit/test_humanoid_rig_contract.gd tests/unit/test_humanoid_semantic_sockets.gd
```

Result: exit `0`; `TEST_SUMMARY: PASS (0 failures)`.

### RED

The real-resource tests were written before production changes. Programmatic fixtures contain an `ArrayMesh` with bone/weight arrays, named `Skin` binds, masculine/feminine roots, a duplicate source `Skeleton3D`, and source/root `AnimationPlayer` nodes.

Command:

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_skinned_equipment_binding.gd tests/unit/test_forge_humanoid_equipment.gd
```

Accepted RED result: exit `1`; `TEST_SUMMARY: FAIL (6 failures)`. The binding script did not exist, and the existing model could not equip/rebind shared skin, hide its declared body region, or preserve that equipped state through a failed shared-skin replacement. Two earlier test-authoring invocations exposed test-only type/constant parse mistakes; those were corrected before accepting this behavioral RED, with no production file present.

### Focused GREEN

Command: the same two-suite command as RED with fresh `task-5-green-*` profile roots.

Result: exit `0`; `TEST_SUMMARY: PASS (0 failures)`. The accepted run contained no script, loader, parser, test-failure, or material-cleanup error.

## Verification matrix

Command:

```powershell
& $godot --headless --path . --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_skinned_equipment_binding.gd tests/unit/test_forge_humanoid_equipment.gd tests/unit/test_equipment_body_fit_resolution.gd tests/unit/test_humanoid_rig_contract.gd tests/unit/test_humanoid_semantic_sockets.gd tests/unit/test_character_presentation.gd tests/unit/test_character_presentation_sandbox.gd tests/unit/test_playable_class_presentations.gd tests/unit/test_held_equipment_readability.gd tests/unit/test_equipment_asset_manifest_contract.gd tests/unit/test_fighter_modular_assets.gd tests/unit/test_forge_base_bodies.gd tests/unit/test_forge_vanguard_model.gd tests/unit/test_forge_vanguard_animations.gd
```

Result: exit `0`; `TEST_SUMMARY: PASS (0 failures)`. Character-presentation negative-path cases emitted their established structured diagnostics.

Full suite command:

```powershell
& $godot --headless --path . --quit-after 1800 --script res://tests/test_runner.gd
```

Result: exit `0`; `TEST_SUMMARY: PASS (211 suites)`. Established negative-path suites emitted structured diagnostics; there were no `TEST_FAILURE` lines and the final summary passed.

Final repository gates: `git diff --check` passed; status and diff were inspected before commit.

## Scope and behavior

- Created `scripts/presentation/skinned_equipment_binding.gd`.
- Updated `ForgeHumanoidModel` to dispatch `shared_skin` through the new binder without reusing rigid-socket staging.
- Added real-resource binding coverage and integrated atomic replace/clear/body-region restoration coverage.
- The binder requires the one canonical actor `Skeleton3D`, exact rig/topology/rest metadata, complete unique named canonical binds, exact ordered-bind hash, and weighted in-range vertex influences.
- Only active descriptor roots contribute meshes. Duplicate source skeletons and animations are not copied; a skeleton nested in an active mesh root fails closed as residual rig content.
- Candidate mesh, `Skin`, material override, mesh surface material, and surface override state are duplicated per instance. Each installed mesh's `skeleton` path resolves to the actor skeleton.
- Validation failure frees the candidate and preserves prior equipment. Clear frees installed meshes and recomputes hidden body regions across remaining shared-skin equipment.
- Legacy and rigid-socket equipment paths remain in place and passed their existing suites.
- No scenes, resources, GLBs, icons, or imported asset sidecars were changed.

## Concerns

No implementation blocker or known Task 5 correctness concern remains. Actual imported auto-rig output is still only a candidate: it must pass this runtime's exact canonical rig, named-bind/hash, and vertex-weight validation before installation.
