# Shared Humanoid/Fit Task 7 Report

## Outcome

Imported body-region and multi-surface material runtime support is implemented and verified. The implementation commit is the enclosing commit named `feat: support imported body regions and surfaces`; its exact hash is reported in the parent handoff because this tracked report is part of that commit.

The exact canonical body-region IDs are:

`head`, `hair`, `neck`, `torso`, `upper_arm_left`, `upper_arm_right`, `forearm_left`, `forearm_right`, `hand_left`, `hand_right`, `hips`, `thigh_left`, `thigh_right`, `shin_left`, `shin_right`, `foot_left`, and `foot_right`.

## TDD evidence

All commands used `F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe` from the isolated `feat/modular-equipment-pilot` worktree.

### Accepted behavioral RED

Both new suites were created before either production file changed. After correcting a test-only semantic-socket fixture so the failure represented the requested behavior, the accepted command was:

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_imported_surface_materials.gd tests/unit/test_body_region_visibility.gd
```

Result: exit `1`; `TEST_SUMMARY: FAIL (11 failures)`. The exact failures proved that the body-region catalog was absent; imported null-override surfaces received no per-surface overrides or instance isolation; unsupported surface material replacement committed and destroyed the prior item; name-derived body regions did not hide; and an unknown hidden-region declaration replaced the live equipment/visibility state. The accepted RED had no parser, loader, or fixture error.

### Focused GREEN

The same two-suite command after implementation exited `0` with `TEST_SUMMARY: PASS (0 failures)`. The accepted output had no parser, loader, script, renderer-material-cleanup, orphan, or leak diagnostic.

## Verification

### Affected fit, transaction, equipment, shared-skin, presentation, and feedback matrix

The final matrix ran the established nineteen Task 6 presentation/content suites followed by both new Task 7 suites: character body-fit transaction, equipment body-fit resolution, Forge humanoid equipment, skinned equipment binding, semantic sockets, grounding/UI, character presentation and sandbox, humanoid rig, playable-class presentation, held-equipment readability, equipment manifest, Fighter modular assets, Forge base bodies, Forge Vanguard model/animations, and caster/heavy-melee/ranged equipment content.

Result: exit `0`; `TEST_SUMMARY: PASS (0 failures)`. Only the character-presentation suites' established assertion-owned negative diagnostics appeared. There was no renderer material cleanup, unload, orphan, or leak diagnostic.

### Full suite

```powershell
& $godot --headless --path . --quit-after 1800 --script res://tests/test_runner.gd
```

Fresh exact-source result: exit `0`; `TEST_SUMMARY: PASS (214 suites)`. The run retained established assertion-owned negative-path diagnostics and ended without `TEST_FAILURE`, material-cleanup, script-unload, ObjectDB/resource leak, or orphan warnings.

## Scope and behavior

- Created `scripts/presentation/body_region_catalog.gd` with the exact ordered seventeen-ID contract, strict missing/duplicate/unknown/type/Skin/surface validation, and a four-source-Material maximum.
- Updated `scripts/presentation/forge_humanoid_model.gd` to derive imported regions from `BodyRegion__<id>` names while preserving metadata-based legacy bodies, reject invalid imported bodies, validate hidden-region declarations before promotion, and restore authored visibility across clear, replacement, and rejection paths.
- Imported meshes with null `material_override` now promote each active StandardMaterial3D surface into a unique per-model override and immutable clean base. Material-level `palette_region` metadata takes precedence over the legacy mesh-level fallback.
- Palette changes, wearer accents, hit flash, downed desaturation, feedback clearing, replacement, and clear cover every cached surface. Shared source materials remain unchanged.
- Unsupported active surface material types fail preflight before live equipment is cleared. Shared-skin and body-fit staging retain Task 6 atomicity; rejected candidates are cleaned without renderer diagnostics.
- Added programmatic imported-style fixtures in `tests/unit/test_imported_surface_materials.gd` and `tests/unit/test_body_region_visibility.gd`.
- No production scene, resource, GLB, icon, imported asset, or UID sidecar was modified.

## Concerns

No blocking or known Task 7 correctness concern remains. A diagnostic probe that placed either new suite immediately before the transaction suite exposed a Godot script-unload-order warning; the accepted affected matrix and both sorted full-suite runs were clean, so the warning was not reproducible in authoritative execution order and did not represent retained runtime nodes or materials. Actual art assets remain outside this task and still require Task 8 import-readiness validation before promotion.
