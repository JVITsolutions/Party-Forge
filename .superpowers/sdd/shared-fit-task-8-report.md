# Shared Humanoid/Fit Task 8 Report

## Outcome

The read-only humanoid import-readiness validator is implemented and verified. It validates explicit masculine and feminine `PackedScene` resources against the existing `pf_humanoid_v1.tres` contract, and exposes separate programmatic shared-skinned-item validation for exact active roots and item-specific budgets.

The implementation commit is the enclosing commit named `feat: validate humanoid import readiness`; its exact hash is reported in the parent handoff because this tracked report is part of that commit.

No production GLB, icon, imported resource, `.import` sidecar, scene, presentation resource, project setting, or runtime script was modified or promoted.

## Read-only CLI

The entry point is:

```powershell
& $godot --headless --path . --script res://tools/validate_humanoid_import.gd -- `
  --masculine-scene res://path/to/masculine.tscn `
  --feminine-scene res://path/to/feminine.tscn `
  --rig res://data/presentation/humanoid_rigs/pf_humanoid_v1.tres
```

All three paths are mandatory, normalized `res://` paths. Absolute/local paths, `user://`, traversal, duplicates, missing values/resources, and unknown or write-like arguments fail closed. The tool contains no file/directory creation, resource saving, project-setting mutation, import mutation, or builder dependency.

Successful validation emits one deterministic line containing masculine/feminine region and triangle counts plus the shared topology, canonical-rest, and Skin-bind signatures.

## TDD evidence

All Godot commands used `F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe` from the isolated `feat/modular-equipment-pilot` worktree with Task 8-specific `APPDATA` and `LOCALAPPDATA` roots under `.superpowers\sdd`.

### Accepted initial RED

The complete programmatic body/shared-item fixture suite was written before `tools/validate_humanoid_import.gd` existed.

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- res://tests/unit/test_humanoid_import_validator.gd
```

Result: exit `1`; `TEST_SUMMARY: FAIL (1 failures)`. The exact assertion was `humanoid import validator implementation exists: expected true`. A test-only typed-script parse issue was corrected before this accepted RED; the accepted run had no parser, loader, fixture, or script error.

### Texture-family hardening RED

After the first focused GREEN, source review found that the 2K resolution gate did not yet enforce the design's four-maps-per-material-family maximum. A five-texture material fixture was added before the production check.

Result: exit `1`; `TEST_SUMMARY: FAIL (2 failures)`. The two failures were exactly the reject assertion and the missing precise diagnostic `material uses 5 textures; maximum is 4`.

### Focused GREEN

The final focused command exited `0` with `TEST_SUMMARY: PASS (0 failures)`. Output contained no parser, loader, script, orphan, leak, ObjectDB, resource-still-in-use, or renderer-cleanup diagnostic.

## Validation matrix

### Body pair

- explicit masculine and feminine scenes and the canonical rig resource
- exactly one canonical `Skeleton3D` per body, exact topology/parents/rests, and the stored topology/rest signatures
- exactly one direct-child `LegacyPivotSkeletonDriver`, exact rig reference, scene-root pivot authority, and influence `1.0`
- finite, invertible local transforms throughout the scene
- exact direct `SemanticSockets` identities and canonical BoneAttachment3D bone/skeleton mappings for all eleven equipment slots
- exactly seventeen `BodyRegion__<id>` skinned mesh regions, with missing/duplicate/unknown/type/material contracts delegated to the established catalog
- visible geometry height `1.60..1.85 m` and ground Y tolerance `0.001 m`
- 10,000-triangle hard cap, four-material hard cap, 2K texture-dimension cap, and four texture maps per material family
- triangle primitives, finite vertices, UV0, finite normals, usable tangents, named canonical Skin binds, exact shared bind signature, at most four positive weights, valid bind indices, normalized weights, and no unweighted vertices
- exact Skin-bind signature equality between the masculine and feminine body scenes

### Shared-skinned items

- explicit non-empty normalized active-root paths, with missing/duplicate/overlapping roots rejected
- only selected roots contribute meshes and metrics
- selected/installed roots contain no `Skeleton3D` or `AnimationPlayer`
- every selected mesh resolves a source skeleton with the exact canonical bones, parents, and rests
- exact caller-supplied Skin-bind signature
- the same UV0, normal, tangent, finite geometry, material, texture, and vertex-weight contracts as bodies
- explicit positive per-item triangle, material, and texture-size budgets
- auto-rig-like `AutoRigHips` skeleton/Skin names and unweighted vertices reject precisely

### CLI/read-only coverage

- valid explicit in-memory-loaded `res://` fixtures exercise the actual `run_cli` control flow and exact success line
- missing arguments/resources, absolute paths, `user://`, traversal, and `--write` reject nonzero
- a source audit rejects file-write, resource-save, directory-create, project-setting, and import-mutation capabilities
- the validator has no dependency on `build_shared_humanoid_scene.gd`

## Regression verification

### Foundation and affected consumer matrix

A 27-suite matrix covered Task 8 plus fit resolution/equipment validation, canonical rig, pivot driver, animation quality, semantic sockets, shared-Skin binding, transactional body-fit, imported surfaces, body regions, focused-runner shutdown lifecycle, Forge humanoid equipment, grounding/UI, character presentation/sandbox, playable-class presentations, held readability, equipment manifest, Fighter modular assets, both Forge base bodies, Forge Vanguard model/animations, and caster/heavy-melee/ranged content.

Result: exit `0`; `TEST_SUMMARY: PASS (0 failures)`. Only the established assertion-owned `PARTY_FORGE_PRESENTATION_ERROR` negative-path diagnostics appeared. There was no test, parser, loader, script, orphan, leak, ObjectDB, resource-still-in-use, or renderer-cleanup diagnostic.

### Full suite

```powershell
& $godot --headless --path . --quit-after 1800 --script res://tests/test_runner.gd
```

Fresh isolated-profile result: exit `0`; `TEST_SUMMARY: PASS (216 suites)`, greater than the preceding 215-suite baseline. Established assertion-owned negative-path diagnostics remained; there was no `TEST_FAILURE`, Task 8 script error, ObjectDB/resource leak, orphan, or script-unload shutdown diagnostic.

## Scope

- Created `tools/validate_humanoid_import.gd`.
- Created `tests/unit/test_humanoid_import_validator.gd` with fully programmatic `PackedScene`, `Skeleton3D`, `Skin`, mesh-array, material, texture, driver, socket, and body-region fixtures.
- Created this durable Task 8 evidence report.
- Existing 99 item identities and all production content were left untouched; the full suite is the regression evidence for continued loading/runtime compatibility.

## Concerns

No blocking or known Task 8 correctness concern remains. Real body/item GLBs intentionally do not exist in this foundation task, so no real asset is claimed ready or promoted. Each future approved body/item export must run through this validator with its design-specified per-item budgets before integration.

## Review repair evidence — 2026-08-23

The follow-up review findings against base `269431c8d69366baaac0b50d08f17ae74bb1383c` were repaired with additional test-first coverage. The validator now:

- validates each selected shared-item root and every traversed `Node3D` transform as finite and invertible before geometry inspection;
- rejects active-root `NodePath` subnames;
- requires tangents only when the effective surface material has an enabled normal map, while always requiring finite UV0 coordinates;
- computes body height and ground metrics from effectively visible meshes only, including ancestor visibility;
- counts distinct `Texture2D` resource identities per material family while retaining the per-texture size cap;
- compares shared-item skeleton rests using the exact canonical 1e-6-quantized serialization contract rather than approximate transform equality;
- guards the rig type as `HumanoidRigDefinition` before any typed contract call; and
- has a structural read-only capability audit plus real subprocess coverage of `_initialize()`, OS arguments, deterministic output, and process exit codes.

### Accepted review RED

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- res://tests/unit/test_humanoid_import_validator.gd
```

Result: exit `1`; `TEST_SUMMARY: FAIL (22 failures)`. The failures reproduced finite UV0, conditional tangent, reused-map identity, own/ancestor visibility, shared-root subname/transform, quantized-rest, and rig-type findings. The wrong-rig cases also exposed the three uncontrolled typed-call script errors that the deterministic type guard was intended to eliminate.

### Focused review GREEN and real CLI subprocess

The same focused command, from a fresh isolated profile, exited `0` with `TEST_SUMMARY: PASS (0 failures)`. Its suite created disposable packed body scenes, launched `tools/validate_humanoid_import.gd` as the actual child process, verified a valid OS-argument request produced `PARTY_FORGE_HUMANOID_IMPORT_OK` and exit `0`, verified `--write` produced the deterministic read-only rejection and exit `1`, and removed the disposable resources. No fixture resource remained in the worktree.

### Expanded affected foundation matrix

A 29-suite focused matrix covered the validator plus body-fit/equipment contracts, canonical rig, pivot driver, animation quality, semantic sockets, shared-Skin binding, body-fit transaction, imported surfaces, body-region visibility, focused-runner lifecycle, Forge equipment and bodies, presentation/grounding, playable-class presentation, readability, manifest, modular Fighter, Forge Vanguard, caster/heavy-melee/ranged content, party-actor presentation, and visual-data/QA contracts.

Result: exit `0`; `TEST_SUMMARY: PASS (0 failures)`. Only established assertion-owned `PARTY_FORGE_PRESENTATION_ERROR` negative fixtures appeared.

### Full regression suite

```powershell
& $godot --headless --path . --quit-after 1800 --script res://tests/test_runner.gd
```

Fresh isolated-profile result: exit `0`; `TEST_SUMMARY: PASS (216 suites)`. No suite file was added, so the required threshold remained at least 216. Established assertion-owned negative-path diagnostics remained; there was no Task 8 test failure, parser or script error, subprocess mismatch, orphan, ObjectDB, resource-still-in-use, or validator cleanup diagnostic.
