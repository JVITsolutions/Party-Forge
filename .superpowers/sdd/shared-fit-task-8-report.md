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

## Final review closure — 2026-08-23

The final review findings against base `093276fff4518dede584060623e6a1b70dc2fadf` were closed test-first without widening Task 8 scope. Imported bodies now reject every `MeshInstance3D` outside the exact seventeen named body regions; no non-body mesh-helper exception exists in this import contract. Shared-item validation checks each selected subtree plus every `Node3D` ancestor through the source scene root before any relative transform can be baked. Typed shared-item rig resources run through `HumanoidRigContract.validate_definition()` and return immediately on malformed parallel arrays or stored signatures. `LegacyPivotSkeletonDriver.influence` must compare exactly equal to `1.0`.

### Accepted final RED

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- res://tests/unit/test_humanoid_import_validator.gd
```

Fresh isolated-profile result: exit `1`; `TEST_SUMMARY: FAIL (11 failures)`. The failures reproduced a visible unprefixed rogue body mesh containing 20,000 triangles, non-finite UV0 data, and unweighted vertices; zero-scale and non-finite intermediate ancestors above a nested selected root; a shortened canonical parent-role array and forged topology signature; and influence `0.999999`. The malformed parallel-array fixture also produced the pre-fix uncontrolled `SCRIPT ERROR` at `_skeleton_matches_rig`, proving the required early contract guard.

### Final focused GREEN

The same focused validator command, with a fresh isolated profile, exited `0` in **1.78s** with `TEST_SUMMARY: PASS (0 failures)`. It emitted no parser, loader, script, test-failure, orphan, or cleanup diagnostic.

### Final 29-suite affected matrix

The fresh affected matrix covered the validator; equipment fit and definition contracts; canonical rig, driver, animation, socket, and shared-Skin contracts; transactional fit, imported surfaces, region visibility, and focused-runner lifecycle; Forge humanoid equipment and bodies; grounding, presentation, sandbox, class presentation, and held readability; the manifest and Fighter modular assets; Forge Vanguard model/animations; caster, heavy-melee, and ranged content; and party-actor, visual-data, and visual-QA contracts.

Result: exit `0` in **10.14s** with `TEST_SUMMARY: PASS (0 failures)`. Only established assertion-owned `PARTY_FORGE_PRESENTATION_ERROR` negative fixtures appeared; there was no validator, parser, loader, script, test-failure, orphan, or cleanup diagnostic.

### Final full regression suite

```powershell
& $godot --headless --path . --quit-after 1800 --script res://tests/test_runner.gd
```

Fresh isolated-profile result: exit `0` in approximately **203s** with `TEST_SUMMARY: PASS (216 suites)`. Established assertion-owned negative-path errors and warnings remained. There was no Task 8 test failure, parser error, uncontrolled script error, validator subprocess mismatch, or validator cleanup diagnostic.

## Whole-branch final-review closure — 2026-08-23

The final review wave against base `fa75855` closed the remaining manifest, shared-item skeleton, rigid-socket fallback, and test-harness findings without promoting or rewriting production equipment content.

- Every manifest row now requires non-empty normalized runtime paths, a runtime hash, the complete generator/workflow/model/Blender provenance block, and an approved review block. Body rows additionally require exact one-preset coverage, canonical rig/topology/rest/Skin-bind evidence, hidden-region and dimensions/geometry/material/texture records, and UV/tangent/weight status. Equipment rows require the same production metrics plus master/runtime icon paths and hashes. The document requires exactly one masculine and one feminine body row, and body/shared-Skin topology and rest signatures must match the canonical rig.
- Shared-item skeleton validation resolves each parent role to the canonical parent bone name and then to one unique actual `Skeleton3D` bone index. A valid skeleton with reversed actual bone order passes; wrong or missing canonical parents still reject.
- Rigid metadata fallback accepts only non-empty normalized relative `NodePath` values with no absolute root, backslash, empty segment, `.`, `..`, or subname. The resolved socket must remain a descendant of the `ForgeHumanoidModel`. Existing semantic slots, legacy socket paths/names, and normalized owned fallback names/paths remain supported.
- The real-actor name-map regression now applies the asserted masculine/feminine body before checking parent lookup. Body-fit fixture setup reports failures through the suite array and aborts immediately rather than continuing from invalid setup.

### Accepted RED

The focused manifest/import/socket/transaction command was run after test-only setup corrections and before production fixes. It exited `1` with `TEST_SUMMARY: FAIL (70 failures)` and no parser, loader, script, or fixture error. The failures comprised missing per-row manifest blocks/design fields and body coverage; rejection of a valid reordered skeleton; direct metadata traversal, dot-segment, parent-segment, and subname installation; and transactional `../../HealthBar3D` and subname commits that changed live body/equipment state. Absolute metadata paths already rejected and remained covered. Malformed skeleton parents already rejected and remained covered.

### Focused GREEN and affected matrix

The same four-suite command exited `0` with `TEST_SUMMARY: PASS (0 failures)`. An expanded 32-suite matrix added the prior 29-suite shared-fit foundation matrix plus the modular backup inventory, builder, and verifier suites. It exited `0` with `TEST_SUMMARY: PASS (0 failures)`; only established assertion-owned `PARTY_FORGE_PRESENTATION_ERROR` negative-path diagnostics appeared.

### Uncontested full suite

The full suite started with zero `Godot_v*` engine contenders and ran under new isolated `APPDATA` and `LOCALAPPDATA` roots. A condition-based process monitor followed the target plus three test-spawned engine descendants and observed zero foreign engine PIDs throughout. The target exited `0` with `ITEM_TRANSACTION_MATRIX: PASS` and `TEST_SUMMARY: PASS (216 suites)`.

### Production preservation

The exact 515 production equipment inventory paths were hashed before and after the fix wave. Both inventories produced aggregate SHA-256 `7d9ef44d0c6b4b0892a075d114962507dca4de88e47205a9606a7aee2a1a6819`; `git diff fa75855` across those paths reported zero changed files. No production GLB, icon, equipment scene, base definition, presentation resource, or contact sheet changed.

No blocking correctness concern remains from this final-review wave. Real asset approval and promotion remain separate future gates.
