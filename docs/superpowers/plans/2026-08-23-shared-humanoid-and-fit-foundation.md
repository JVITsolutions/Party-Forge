# Shared Humanoid Rig, Animation Bridge, and Equipment Fit Foundation Plan

> **Execution note:** Execute after the backup/provenance foundation verifies. Preserve all existing item resources through backward-compatible fallbacks and use TDD for every behavior change.

**Goal:** Introduce one canonical rig, deterministically drive it from Party Forge's current pivot animations, and support both rigid and shared-skinned equipment without breaking the current presentation API or 99 existing item identities.

**Architecture:** `fit_policy` (`shared` or `variant`) is independent of `attachment_mode` (`rigid_socket` or `shared_skin`). Existing pivot animations remain authoritative for the pilot and a SkeletonModifier3D bridge applies their evaluated transforms to `pf_humanoid_v1`. Rigid items use semantic sockets; skinned items are staged and rebound to the actor's single Skeleton3D. Body, equipment, material, region-visibility, and grounding changes commit transactionally through the public CharacterPresentation API.

**Tech stack:** Godot 4.7.1, typed GDScript, Skeleton3D, SkeletonModifier3D, Skin, MeshInstance3D, BoneAttachment3D, Resources, existing test runner.

---

## Task 1: Separate fit policy from attachment mode

**Files:**

- Modify: `scripts/presentation/equipment_visual_definition.gd`
- Create: `scripts/presentation/equipment_body_fit_descriptor.gd`
- Create: `tests/unit/test_equipment_body_fit_resolution.gd`
- Modify: `tests/unit/test_fighter_modular_assets.gd`
- Modify: `tests/unit/test_heavy_melee_equipment_content.gd`

**Step 1: Write failing tests**

Prove:

- legacy resources with no fit descriptors resolve `presentation_scene` and its root for both presets
- each descriptor contains body preset ID, PackedScene, explicit mesh-root NodePaths, and hidden body-region IDs
- `fit_policy=shared` may resolve one descriptor/root selection for both bodies
- `fit_policy=variant` requires masculine and feminine descriptors
- two descriptors may reference one multi-fit item scene but must select non-overlapping roots
- `attachment_mode=rigid_socket` requires a semantic socket
- `attachment_mode=shared_skin` requires rig ID, skeleton signature, and bind signature metadata
- fit policy and attachment mode reject unknown values independently
- unknown body presets return null
- icon-only/non-combat entries remain valid without a scene
- all current production definitions validate unchanged
- existing consumers call `presentation_scene_for(active_body)` rather than asserting only the legacy field is non-null

**Step 2: Confirm RED**

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 120 --script res://tests/focused_test_runner.gd -- res://tests/unit/test_equipment_body_fit_resolution.gd res://tests/unit/test_fighter_modular_assets.gd res://tests/unit/test_heavy_melee_equipment_content.gd
```

**Step 3: Implement the minimum backward-compatible API**

Add typed fit descriptors, `fit_policy`, `attachment_mode`, topology/rest/Skin signature fields, and `body_fit_for(body_preset_id)`. Keep `presentation_scene` as the legacy fallback descriptor root. Validation requires every explicit root to exist and ensures runtime installs only the requested descriptor's roots.

**Step 4: Confirm GREEN and commit**

```powershell
git add scripts/presentation/equipment_visual_definition.gd scripts/presentation/equipment_body_fit_descriptor.gd tests/unit/test_equipment_body_fit_resolution.gd tests/unit/test_fighter_modular_assets.gd tests/unit/test_heavy_melee_equipment_content.gd
git commit -m "feat: separate equipment fit and attachment contracts"
```

## Task 2: Define and serialize `pf_humanoid_v1`

**Files:**

- Create: `scripts/presentation/humanoid_rig_definition.gd`
- Create: `scripts/presentation/humanoid_rig_contract.gd`
- Create: `data/presentation/humanoid_rigs/pf_humanoid_v1.tres`
- Create: `tests/unit/test_humanoid_rig_contract.gd`

**Step 1: Write failing tests with programmatic Skeleton3D fixtures**

Require:

- stable rig ID `pf_humanoid_v1`
- unique semantic roles for hips, spine, chest, neck, head, paired upper/lower arms, hands, upper/lower legs, feet, and toes
- each role maps to a canonical bone name and the current animated pivot NodePath
- every mapped bone and pivot exists exactly once
- parent relationships match the approved humanoid hierarchy
- all rest transforms are finite and invertible
- topology and canonical-rest signatures are independently stable and do not depend on resource UID, import order, or timestamps
- canonical rest components are quantized to 1e-6 before hashing
- a separate Skin signature serializes ordered bind names and 1e-6-quantized bind-pose matrices
- every Skin bind is name-based, unique, and resolves to a canonical bone; numeric-only and unnamed binds are rejected
- changed bone length, parent, rest rotation, missing role, or duplicate role rejects or changes the signature

**Step 2: Implement deterministic signatures**

Create three serializers: topology uses stable role, bone name, parent role, and pivot path; canonical rest uses role-ordered transforms quantized to 1e-6; Skin binds use bind order, required bind names, resolved canonical bone roles, and bind-pose matrices quantized to 1e-6. Hash each UTF-8 serialization separately with SHA-256.

**Step 3: Create the canonical resource now**

Populate the mapping to Party Forge's current pivot hierarchy. This resource must exist before the animation bridge, import validator, or asset-production validation uses it.

**Step 4: Confirm GREEN and commit**

```powershell
git add scripts/presentation/humanoid_rig_definition.gd scripts/presentation/humanoid_rig_contract.gd data/presentation/humanoid_rigs/pf_humanoid_v1.tres tests/unit/test_humanoid_rig_contract.gd
git commit -m "feat: define canonical humanoid rig"
```

## Task 3: Drive the canonical skeleton from current pivot animations

**Files:**

- Create: `scripts/presentation/legacy_pivot_skeleton_driver.gd`
- Create: `tests/unit/test_legacy_pivot_skeleton_driver.gd`
- Modify: `tests/unit/test_humanoid_animation_quality.gd`

**Step 1: Write failing bridge tests**

Build a test wrapper containing the current pivot hierarchy, canonical Skeleton3D, rig resource, and SkeletonModifier3D driver. Require:

- the driver is a direct child of its target Skeleton3D and obtains that parent through `get_skeleton()`
- rest pose maps pivots to identity bone-pose deltas without double-applying canonical rest
- evaluated pivot translation/rotation drives the corresponding bones after AnimationPlayer evaluation
- pivot world transforms convert to skeleton space before delta calculation
- each pivot delta is calculated from its captured skeleton-space pivot rest, applied to canonical bone global rest, converted through the desired parent global, and finally converted to a local delta from canonical bone rest
- currently unmapped `HitPivot` and `BodyPivot` motion reaches the mapped root bone through the pivot's skeleton-space global transform
- modifier influence is 1.0 and the callback performs no manual interpolation
- missing pivots/bones, non-finite transforms, or signature mismatch fail closed
- the driver never edits bone rest transforms
- idle, walk, attack, hit, loop, and method/event tracks retain their current IDs, lengths, and event times
- both body meshes receive identical skeleton poses

**Step 2: Implement a SkeletonModifier3D bridge**

Make the driver a direct child of Skeleton3D and override Godot 4.7's `_process_modification_with_delta(delta)` hook. At validated setup, capture every pivot rest in skeleton space and canonical bone global/local rest. Each callback converts the current pivot global into skeleton space, computes `current_pivot * inverse(rest_pivot)`, applies that delta to canonical bone global rest, derives desired local from the already-derived desired parent global, and passes `inverse(canonical_local_rest) * desired_local` to `set_bone_pose()`. Process parents before children. Set modifier influence to 1.0; do not blend in code.

**Step 3: Run the bridge and existing animation suites**

**Step 4: Commit**

```powershell
git add scripts/presentation/legacy_pivot_skeleton_driver.gd tests/unit/test_legacy_pivot_skeleton_driver.gd tests/unit/test_humanoid_animation_quality.gd
git commit -m "feat: bridge pivot animations to canonical skeleton"
```

## Task 4: Resolve semantic sockets without imported node-name dependencies

**Files:**

- Modify: `scripts/presentation/forge_humanoid_model.gd`
- Create: `tests/unit/test_humanoid_semantic_sockets.gd`

**Step 1: Write failing tests**

Require an owned `SemanticSockets` root with all eleven slot identities. Verify rig-backed BoneAttachment3D sockets take precedence, current `SLOT_SOCKET_PATHS` remain a fallback, held/projectile/action anchors remain discoverable, and a missing semantic mapping cannot redirect to the wrong bone.

**Step 2: Implement one internal resolver**

Route slot checks, rigid equipment staging, and transform queries through the resolver. Imported GLB names never become gameplay contracts.

**Step 3: Confirm focused GREEN and commit**

## Task 5: Rebind shared-skinned equipment to the actor skeleton

**Files:**

- Create: `scripts/presentation/skinned_equipment_binding.gd`
- Modify: `scripts/presentation/forge_humanoid_model.gd`
- Modify: `tests/unit/test_forge_humanoid_equipment.gd`
- Create: `tests/unit/test_skinned_equipment_binding.gd`

**Step 1: Write failing real-resource tests**

Programmatically create scenes containing Skeleton3D, MeshInstance3D, Skin, multiple masculine/feminine mesh roots, and AnimationPlayer nodes. Require:

- only MeshInstance3D/Skin content is staged from a shared-skinned item
- each staged mesh's skeleton path targets the actor's canonical Skeleton3D
- only the mesh roots named by the active fit descriptor are staged; the other body's roots are never installed
- all Skin binds are named, resolve to canonical bones, and match the exact approved ordered-bind hash
- the source item's duplicate Skeleton3D and AnimationPlayer are not installed
- missing skin, unweighted vertices, signature mismatch, unknown bones, or residual duplicate rig aborts staging
- failed staging leaves prior equipment untouched
- clearing equipment frees installed meshes and restores hidden body regions

**Step 2: Implement a separate shared-skin staging path**

Rigid socket logic must not be reused for skinned meshes. Stage candidate meshes and duplicated per-instance Skin/material state, validate against the actor skeleton, then commit atomically.

**Step 3: Confirm focused GREEN and commit**

## Task 6: Make body, fit, hidden regions, and grounding one public transaction

**Files:**

- Modify: `scripts/presentation/forge_humanoid_model.gd`
- Modify: `scripts/presentation/character_presentation.gd`
- Create: `tests/unit/test_character_body_fit_transaction.gd`

**Step 1: Write failing public-API tests**

Call `CharacterPresentation.set_body_preset()` rather than private model methods. Assert successful shared/variant fit swaps and complete rollback when any fitted scene, shared skin, semantic socket, body-region declaration, or grounding check fails. Verify visible body, equipment instances, materials, hidden regions, palette, active preset, transforms, and ground position all remain unchanged after rejection.

**Step 2: Implement staged commit/rollback**

The model prepares a candidate body/equipment/region state and computes candidate bounds/grounding before mutation. CharacterPresentation commits only the validated candidate; it never returns false after leaving a changed body active.

**Step 3: Confirm focused GREEN and commit**

## Task 7: Support imported multi-surface materials and body-region visibility

**Files:**

- Create: `scripts/presentation/body_region_catalog.gd`
- Modify: `scripts/presentation/forge_humanoid_model.gd`
- Create: `tests/unit/test_imported_surface_materials.gd`
- Create: `tests/unit/test_body_region_visibility.gd`

**Step 1: Write failing tests**

Require exactly seventeen skinned MeshInstance3D children named with the `BodyRegion__` prefix plus one of the exact design IDs, while sharing no more than four body Material resources. Reject missing, duplicate, or unknown region nodes. Test per-fit `hide_body_regions` and exact restoration on clear/replacement/failure. Create imported-style MeshInstance3D fixtures with null `material_override` and multiple surface materials. Require palette mapping, per-instance duplication, hit flash, downed feedback, and restoration on every surface without mutating shared source materials.

**Step 2: Implement surface-aware material state**

Read each active surface material, duplicate it per equipped instance, and apply overrides per surface. Reject unsupported material types during promotion rather than silently skipping feedback.

**Step 3: Confirm focused GREEN and commit**

## Task 8: Add import-readiness validation

**Files:**

- Create: `tools/validate_humanoid_import.gd`
- Create: `tests/unit/test_humanoid_import_validator.gd`

**Step 1: Write failing tests**

Validate body coverage, canonical signatures, pivot-driver mapping, body height, grounding, finite transforms, semantic sockets, body regions, triangle/material/texture budgets, UV0, normals/tangents, and skin weights. Validate shared-skinned item scenes separately and reject installed duplicate skeletons/animation players.

**Step 2: Implement a read-only entry point**

Accept explicit masculine scene, feminine scene, and existing `pf_humanoid_v1.tres` `res://` paths. Reject absolute resource paths and missing arguments. Success prints body counts and shared signatures.

**Step 3: Run all focused foundation suites and the full suite**

Require `TEST_SUMMARY: PASS` with a count greater than the preceding baseline.

**Step 4: Commit**

## Completion criteria

- Existing 99 item identities still load and equip.
- Current pivot animations visibly deform the canonical Skeleton3D through tested mapping.
- Shared-skinned equipment uses the actor skeleton with no duplicate rig/player.
- Rigid items use semantic sockets.
- Fit, attachment, region visibility, materials, and grounding commit or roll back together.
- The canonical rig resource exists before asset production begins.
- Full suite passes with no production GLB or icon promoted yet.
