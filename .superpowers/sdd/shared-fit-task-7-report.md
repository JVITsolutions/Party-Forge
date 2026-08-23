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

## Cross-suite shutdown lifecycle correction

The earlier ordering-dependent warning was a real retained-script defect, not a harmless non-authoritative-order artifact. The coordinator's exact focused order reproduced at base `7ef1bb3` with exit `0` and `TEST_SUMMARY: PASS (0 failures)`, followed by:

```text
WARNING: 20 ObjectDB instances were leaked at exit (run with `--verbose` for details).
ERROR: 6 resources still in use at exit (run with --verbose for details).
```

### Reduction and ownership chain

- `test_imported_surface_materials.gd` followed by `test_character_body_fit_transaction.gd` reproduced the exact 20-instance/6-resource leak.
- `test_body_region_visibility.gd` followed by the transaction suite reproduced the same leak.
- The transaction suite followed by `test_skinned_equipment_binding.gd`, either Task 7 suite followed by the binding suite, and each suite alone shut down cleanly.
- Existing pre-Task-7 descriptor users also reproduced before the transaction suite: `test_equipment_body_fit_resolution.gd` and `test_forge_humanoid_equipment.gd`. This proved the new fixtures were not retaining nodes or materials.
- Verbose output identified fourteen retained `GDScriptNativeClass` objects and six retained `GDScript` objects. The six resources were five Godot AI helper scripts plus the sole Task-related resource `res://scripts/presentation/equipment_body_fit_descriptor.gd`; no `Node`, mesh, material, Skin, PackedScene, or descriptor instance was reported retained.
- A compile-only diagnostic made `test_character_body_fit_transaction.gd.run()` return immediately, yet the leak remained after a descriptor-using predecessor. A reduced probe was clean until it declared the loop over `GameCatalog.load_defaults().classes`; adding only that declaration restored the exact 20/6 shutdown failure, while the probe alone remained clean.

The ownership chain was therefore compile/load-time: resolving `GameCatalog` loads its typed static `EQUIPMENT_CATALOG`, which preloads `core_equipment_catalog.tres`; the catalog owns equipment base definitions, which own presentation definitions, whose `body_fits` own `EquipmentBodyFitDescriptor` resources and the already-cached descriptor GDScript. Loading that graph after a focused predecessor had established the descriptor global class produced the order-sensitive Godot script-unload cycle. Nulling the focused runner's local suite/script temporaries did not change the failure and rejected the runner-local-lifetime hypothesis.

### Regression RED and root-cause fix

`tests/unit/test_focused_runner_shutdown_lifecycle.gd` launches the exact minimal focused child order and asserts its exit code, PASS marker, ObjectDB cleanliness, and resource cleanliness. Before the fix it exited `1` with exactly two failures:

```text
focused lifecycle child releases every ObjectDB instance: expected true
focused lifecycle child releases every resource: expected true
TEST_SUMMARY: FAIL (2 failures)
```

The single root-cause correction keeps the transaction suite's all-class name-map coverage but discovers and loads the `res://data/classes/*.tres` class resources directly. That unit test no longer resolves the unrelated global `GameCatalog` and its static equipment graph while a presentation descriptor script is already cached. No production runtime, shared runner, catalog, resource, scene, or Task 7 fixture behavior changed.

### Corrected verification evidence

After the fix, the regression, both Task 7 minimal sequences, the pre-Task-7 baseline, and the exact coordinator order each exited `0`, emitted `TEST_SUMMARY: PASS (0 failures)`, and contained none of `ObjectDB instances were leaked`, `resources still in use at exit`, `SCRIPT ERROR`, or `TEST_FAILURE`.

The 22-suite affected matrix comprised the nineteen established Task 6 presentation/content suites, both Task 7 suites, and the new shutdown regression. It exited `0` with `TEST_SUMMARY: PASS (0 failures)`. Only the established assertion-owned character-presentation negative diagnostics appeared; shutdown was pristine.

The fresh full command was:

```powershell
& $godot --headless --path . --quit-after 1800 --script res://tests/test_runner.gd
```

It exited `0` with `TEST_SUMMARY: PASS (215 suites)`. Established assertion-owned negative-path diagnostics remained, and there was no `TEST_FAILURE`, script-unload warning, ObjectDB leak warning, or resource-still-in-use error at shutdown.

The only remaining Task 7 concern is unchanged: actual art assets still require Task 8 import-readiness validation before promotion.
