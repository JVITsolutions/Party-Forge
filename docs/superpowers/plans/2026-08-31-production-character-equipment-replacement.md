# Party Forge Production Character and Equipment Replacement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Party Forge's procedural class presentations with two production-ready body families, eighteen fixed class heads, and ninety-nine production-ready modular equipment entries, beginning with a complete Paladin/Dawn Bulwark vertical slice.

**Architecture:** Preserve approved masculine and feminine GLBs as immutable art sources, create versioned game-ready derivatives, and keep Party Forge's gameplay-facing presentation adapter, stable item IDs, and semantic rig roles. Extend the existing presentation contracts for mapped superset skeletons, modular class heads, headwear/accessory fit, surface metadata, and provenance; validate a Paladin-only imported proof before scaling the same pipeline to the other eight classes.

**Tech Stack:** Godot 4.7.1, typed GDScript, Godot Resources and TSCN scenes, glTF 2.0 GLB, Python 3.13 pilot validation tools, 3D Gen Studio 2.4.1, optional Blender only after an explicit Blender operation approval, PBR texture maps, SHA-256 manifests, and the existing Party Forge test runners.

## Global Constraints

- Authoritative repository: `F:/Projects(root)/Game dev/Projects/party-forge`.
- All plan execution occurs in `F:/Projects(root)/Game dev/Projects/party-forge/.worktrees/class-preview-character-model-replacement` on `feat/class-preview-character-model-replacement`.
- Do not modify `.worktrees/living-forge-combat-loop-ui`.
- Do not modify or clean `.worktrees/dawn-bulwark-plate-fit-proof`; preserve its three existing modified files.
- Preserve every immutable source, attempt, review, manifest, hash, and approved copy under `F:/Projects(root)/Game dev/Projects/party-forge-asset-staging/modular-equipment/pilot-0001`.
- Masculine source SHA-256 remains `2d79445ccfa0703c3b67d8d7be41052b87b39153979b645de39d7a186d353eb2`.
- Feminine source SHA-256 remains `dda7ddba6639d655ab9bde7946fe8d34050ae73b6d48a55717928f1d2bd57917`.
- Source rig SHA-256 values remain masculine `8f589e35f16f02fe4aa0f45b5f2c85377a41f9ecc188670bf59159518e6cdbe4` and feminine `173198e3d044418b9765971e8b698664176c05dadd6a5aaa4ddb8df8d4c08667`.
- Use one Godot unit per metre, Y-up, a right-handed scene, feet at local floor `y = 0`, and positive-Z character forward inside the presentation wrapper.
- Keep gameplay collision, movement, targeting, health, combat timing, attack ownership, item IDs, slot IDs, class IDs, save-facing data, and progression unchanged.
- Create one fixed masculine and one fixed feminine head for each of nine classes; the initial milestone has exactly eighteen class-default heads and no face randomization UI.
- All heads share body-specific neck seams, head/neck semantic roles, helmet envelopes, ear anchors, and necklace anchors.
- All ninety-nine equipment bases retain one stable item ID; body-specific presentation variants remain behind that ID.
- Bodies, heads, hair, armour, weapons, and accessories require clean topology, UVs, valid tangent space, PBR materials, recorded texture sets, polished weights or rigid attachments, measured LODs, and fresh visual evidence before production promotion.
- Full helmets, open helmets, and circlets/crowns declare deterministic hair, facial-hair, head-region, and future ear-accessory visibility behavior.
- Free online assets may be acquired as placeholders under Jacob's standing gate only after the active task permits acquisition. Record source, author, acquisition date, hash, exact license, attribution, redistribution, and commercial-use status. Placeholder status cannot become production-approved without explicit review.
- Do not use Blender unless Jacob explicitly approves the named Blender operation.
- Do not run another body-fit preview, allocate an attempt, write geometry, import into Godot, switch a profile, commit, merge, push, delete, overwrite, or clean without the approval gate named by the relevant task.
- A Godot result passes only with process exit `0`, the required terminal summary, and a log scan free of new parser, loader, script, import, crash, or unasserted error diagnostics.
- Use TDD for code and contract changes. Characterize an already-passing behavior instead of fabricating a failure when no production change is required.

---

## File and Ownership Map

### Existing Party Forge files to extend

- `scripts/presentation/character_visual_profile.gd`: class-to-body/head/presentation mapping.
- `scripts/presentation/character_presentation.gd`: game-owned adapter that applies a profile.
- `scripts/presentation/forge_humanoid_model.gd`: body, head, equipment, region, socket, and animation orchestration.
- `scripts/presentation/humanoid_rig_contract.gd`: exact legacy-rig and mapped production-rig validation.
- `scripts/presentation/humanoid_rig_definition.gd`: canonical semantic role definition.
- `scripts/presentation/equipment_visual_definition.gd`: equipment scene and body-fit selection.
- `scripts/presentation/equipment_body_fit_descriptor.gd`: body-specific equipment presentation and hidden body regions.
- `scripts/presentation/equipment_asset_manifest_contract.gd`: import/provenance/surface acceptance schema.
- `scripts/presentation/body_region_catalog.gd`: body-region visibility and imported-region validation.
- `scripts/ui/ledger/character_equipment_preview.gd`: preview instance lifecycle and rotation.
- `data/presentation/profiles/*.tres`: nine class-default presentation/head mappings.
- `data/presentation/humanoid_rigs/pf_humanoid_v1.tres`: legacy canonical role/rest definition.
- Stable equipment directories: `data/equipment/bases/forge_vanguard/`, `data/equipment/bases/greenwood/`, `data/equipment/bases/emberweave/`, `data/equipment/bases/storm_chaplain/`, `data/equipment/bases/dawn_bulwark/`, `data/equipment/bases/nightstep/`, `data/equipment/bases/rime_scholar/`, `data/equipment/bases/grave_covenant/`, and `data/equipment/bases/siege_archer/`.
- Production presentation directories: the matching nine directories under `data/presentation/equipment/`.

### New Party Forge files

- `scripts/presentation/humanoid_rig_mapping.gd`: maps canonical roles onto a production skeleton without requiring an exact 19-bone topology.
- `scripts/presentation/character_head_visual_definition.gd`: one class/body head identity and its neck, material, region, and accessory contract.
- `scripts/presentation/headwear_fit_descriptor.gd`: helmet envelope and visibility behavior.
- `scripts/presentation/character_surface_definition.gd`: UV, texture, material-family, tangent, LOD, and source-hash metadata.
- `data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres`: source/runtime mapping for the exact inspected masculine production skeleton.
- `data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres`: source/runtime mapping for the exact inspected feminine production skeleton.
- `data/presentation/heads/forge_vanguard/forge_vanguard_masculine_head.tres` and `forge_vanguard_feminine_head.tres`, plus the corresponding masculine/feminine pair under `ranger/`, `mage/`, `cleric/`, `paladin/`, `rogue/`, `frost_mage/`, `warlock/`, and `marksman/`: eighteen fixed class head definitions.
- `assets/models/characters/pf_humanoid_v2/`: approved imported body, head, hair, and material derivatives only.
- Approved imported equipment directories under `assets/models/equipment/`: `forge_vanguard/`, `greenwood/`, `emberweave/`, `storm_chaplain/`, `dawn_bulwark/`, `nightstep/`, `rime_scholar/`, `grave_covenant/`, and `siege_archer/`.
- `scenes/characters/presentation/pf_humanoid_v2.tscn`: new wrapper; the prototype wrapper remains intact.
- `data/presentation/manifests/pf_character_equipment_v2.json`: approved runtime manifest with no absolute machine paths.
- `tests/unit/test_character_head_visual_definition.gd`: fixed-head and interface validation.
- `tests/unit/test_headwear_fit_descriptor.gd`: helmet/visibility contract validation.
- `tests/unit/test_character_surface_definition.gd`: UV/material/LOD metadata validation.
- `tests/unit/test_production_humanoid_rig_mapping.gd`: mapped-superset rig validation.
- `tests/integration/production_character_preview_runner.gd`: class/body rotation and duplicate-instance evidence.
- `tools/validate_production_character_assets.gd`: import-time manifest/resource/scene validator.
- `docs/qa/character-model-replacement/`: source snapshots, logs, reports, contact sheets, and video indexes.

### External pilot files to extend only under their own approval gates

- `configs/dawn_bulwark_masculine_fitted_shell_recipe.v1.json`.
- New `configs/dawn_bulwark_feminine_fitted_shell_recipe.v1.json`.
- `tools/body_fitted_shell_workflow.py` and its existing focused tests only if the approved option-A correction requires a workflow change.
- New immutable body/head/equipment attempt directories and review records under the existing pilot naming rules.

---

### Task 1: Freeze the Live Baseline and Source Identities

**Files:**
- Create: `docs/qa/character-model-replacement/source-baseline.json`
- Create: `docs/qa/character-model-replacement/source-baseline.md`
- Test: existing repository and external source hashes

**Interfaces:**
- Consumes: current branch HEAD/status, nine profiles, 99 equipment bases, approved body/rig hashes.
- Produces: an immutable baseline record used by every later task to detect drift.

- [ ] **Step 1: Obtain the baseline-operation approval**

Ask Jacob to approve exactly: cold Godot import/test cache writes inside the isolated worktree, read-only source hashing, and the two baseline documentation writes. This approval does not include model generation, geometry work, or asset import.

- [ ] **Step 2: Record pre-operation state**

Run:

```powershell
$project = 'F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\class-preview-character-model-replacement'
git -C $project rev-parse HEAD
git -C $project status --short --branch
git -C 'F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\living-forge-combat-loop-ui' status --short --branch
git -C 'F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\dawn-bulwark-plate-fit-proof' status --short --branch
```

Expected: the isolated branch contains only approved documentation changes; Living Forge is clean; Dawn Bulwark contains exactly the three preserved modifications.

- [ ] **Step 3: Verify the four authoritative hashes**

Run `Get-FileHash -Algorithm SHA256` against the two approved source GLBs and two rigged source GLBs. Expected: exact matches to the four hashes in Global Constraints. Any mismatch stops the task without writing the baseline files.

- [ ] **Step 4: Run a cold import after approval**

Use fresh task-owned `APPDATA` and `LOCALAPPDATA` directories outside the repository and run:

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --editor --path $project --import --quit
```

Expected: exit `0`; no parser, loader, script, or import errors. Preserve the complete log under `docs/qa/character-model-replacement/baseline-import.log` only if that log path was included in the approval.

- [ ] **Step 5: Run the existing full suite**

```powershell
& $godot --headless --path $project --quit-after 1800 --script res://tests/test_runner.gd
```

Expected: exit `0` and one terminal `TEST_SUMMARY: PASS (...)` marker. Record the exact suite count rather than predicting it.

- [ ] **Step 6: Write the baseline record**

Use `git rev-parse HEAD` for `repository_head` and extract the one terminal `TEST_SUMMARY:` line from the preserved full-suite log for `full_suite_summary`. Use `apply_patch` to write `source-baseline.json` with schema version 1, branch `feat/class-preview-character-model-replacement`, profiles 9, catalog equipment bases 99, default equipment entries 98, the four exact hashes from Global Constraints, and the observed import/test exits and summary. Do not write a guessed commit or suite count. `source-baseline.md` links the logs and states that no art asset was changed.

- [ ] **Step 7: Verify and request checkpoint approval**

Run `git diff --check` and compare the two excluded worktree statuses again. Present the exact diff and evidence. Commit only after Jacob approves the baseline checkpoint:

```powershell
git add docs/qa/character-model-replacement/source-baseline.json docs/qa/character-model-replacement/source-baseline.md docs/qa/character-model-replacement/baseline-import.log
git commit -m "docs: freeze character replacement baseline"
```

---

### Task 2: Add Head, Headwear, Surface, and Manifest Contracts

**Files:**
- Create: `scripts/presentation/character_head_visual_definition.gd`
- Create: `scripts/presentation/headwear_fit_descriptor.gd`
- Create: `scripts/presentation/character_surface_definition.gd`
- Modify: `scripts/presentation/character_visual_profile.gd`
- Modify: `scripts/presentation/equipment_body_fit_descriptor.gd`
- Modify: `scripts/presentation/equipment_asset_manifest_contract.gd`
- Create: `tests/unit/test_character_head_visual_definition.gd`
- Create: `tests/unit/test_headwear_fit_descriptor.gd`
- Create: `tests/unit/test_character_surface_definition.gd`
- Modify: `tests/unit/test_character_visual_data.gd`
- Modify: `tests/unit/test_equipment_asset_manifest_contract.gd`

**Interfaces:**
- Consumes: `CharacterVisualProfile.BODY_PRESETS`, existing equipment fit descriptors, and manifest schema version 1.
- Produces: `CharacterHeadVisualDefinition`, `HeadwearFitDescriptor`, `CharacterSurfaceDefinition`, `CharacterVisualProfile.head_for_body()`, and manifest schema version 2.

- [ ] **Step 1: Write failing head-definition tests**

The tests instantiate a valid definition and assert that `validate()` returns empty, then assert failures for a missing class ID, invalid body preset, null scene, empty neck interface, empty helmet envelope, missing left/right ear socket paths, and duplicate hidden-region IDs.

Required public interface:

```gdscript
class_name CharacterHeadVisualDefinition
extends Resource

@export var id: StringName
@export var class_id: StringName
@export var body_preset_id: StringName
@export var presentation_scene: PackedScene
@export var mesh_root_path: NodePath
@export var neck_interface_id: StringName
@export var helmet_envelope_id: StringName
@export var left_ear_socket_path: NodePath
@export var right_ear_socket_path: NodePath
@export var head_region_ids: Array[StringName] = []
@export var surface: CharacterSurfaceDefinition

func validate() -> PackedStringArray:
    var errors := PackedStringArray()
    if id.is_empty():
        errors.append("head id is empty")
    if class_id.is_empty():
        errors.append("head %s class id is empty" % id)
    if body_preset_id not in [&"masculine", &"feminine"]:
        errors.append("head %s body preset %s is invalid" % [id, body_preset_id])
    if presentation_scene == null:
        errors.append("head %s presentation scene is missing" % id)
    if mesh_root_path.is_empty() or mesh_root_path.is_absolute():
        errors.append("head %s mesh root path must be relative" % id)
    if neck_interface_id.is_empty() or helmet_envelope_id.is_empty():
        errors.append("head %s neck interface and helmet envelope are required" % id)
    if left_ear_socket_path.is_empty() or right_ear_socket_path.is_empty():
        errors.append("head %s ear socket paths are required" % id)
    var seen_regions: Dictionary = {}
    for region_id: StringName in head_region_ids:
        if region_id.is_empty() or seen_regions.has(region_id):
            errors.append("head %s has empty or duplicate region %s" % [id, region_id])
        seen_regions[region_id] = true
    if surface == null:
        errors.append("head %s surface definition is missing" % id)
    else:
        for reason: String in surface.validate():
            errors.append("head %s %s" % [id, reason])
    return errors
```

- [ ] **Step 2: Run the head-definition test RED**

```powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_character_head_visual_definition.gd
```

Expected: nonzero exit because the resource class does not exist.

- [ ] **Step 3: Implement the minimal head definition and profile mapping**

Add to `CharacterVisualProfile`:

```gdscript
@export var class_heads: Array[CharacterHeadVisualDefinition] = []

func head_for_body(body_preset_id: StringName) -> CharacterHeadVisualDefinition:
    for head: CharacterHeadVisualDefinition in class_heads:
        if head != null and head.body_preset_id == body_preset_id:
            return head
    return null
```

Extend `validate()` so each profile requires exactly one masculine and one feminine head only when `class_heads` is non-empty. This preserves legacy profiles until the v2 resources are introduced.

- [ ] **Step 4: Write and implement the headwear descriptor contract**

Required interface:

```gdscript
class_name HeadwearFitDescriptor
extends Resource

const CATEGORIES: Array[StringName] = [&"full_helmet", &"open_helmet", &"circlet"]

@export var category: StringName
@export var compatible_envelope_ids: Array[StringName] = []
@export var hide_head_region_ids: Array[StringName] = []
@export var helmet_safe_hair_id: StringName

func validate() -> PackedStringArray:
    var errors := PackedStringArray()
    if category not in CATEGORIES:
        errors.append("headwear category %s is invalid" % category)
    var seen_envelopes: Dictionary = {}
    for envelope_id: StringName in compatible_envelope_ids:
        if envelope_id.is_empty() or seen_envelopes.has(envelope_id):
            errors.append("headwear has empty or duplicate envelope %s" % envelope_id)
        seen_envelopes[envelope_id] = true
    if compatible_envelope_ids.is_empty():
        errors.append("headwear compatible envelopes are empty")
    var seen_regions: Dictionary = {}
    for region_id: StringName in hide_head_region_ids:
        if region_id.is_empty() or seen_regions.has(region_id):
            errors.append("headwear has empty or duplicate hidden region %s" % region_id)
        seen_regions[region_id] = true
    if category == &"open_helmet" and helmet_safe_hair_id.is_empty():
        errors.append("open helmet requires a helmet-safe hair id")
    return errors
```

Tests require a known category, non-empty unique envelope IDs, unique region IDs, and deterministic hair behavior: full helmets may use an empty safe-hair ID because hair is hidden; open helmets must provide a safe-hair ID; circlets may preserve ordinary hair.

- [ ] **Step 5: Write and implement the surface contract**

Required interface:

```gdscript
class_name CharacterSurfaceDefinition
extends Resource

@export var source_sha256: String
@export var uv_set_count: int
@export var tangent_status: StringName
@export var texture_paths: Dictionary = {}
@export var material_family_ids: Array[StringName] = []
@export var lod_triangle_counts: Array[int] = []

func validate() -> PackedStringArray:
    var errors := PackedStringArray()
    if not _is_sha256(source_sha256):
        errors.append("surface source hash must be lowercase SHA-256")
    if uv_set_count < 1:
        errors.append("surface requires at least one UV set")
    if tangent_status != &"valid":
        errors.append("surface tangent status must be valid")
    for channel: Variant in texture_paths:
        var path := str(texture_paths[channel])
        if str(channel).is_empty() or not _is_normalized_res_path(path):
            errors.append("surface texture channel %s path is invalid" % channel)
    var seen_families: Dictionary = {}
    for family_id: StringName in material_family_ids:
        if family_id.is_empty() or seen_families.has(family_id):
            errors.append("surface has empty or duplicate material family %s" % family_id)
        seen_families[family_id] = true
    if material_family_ids.is_empty():
        errors.append("surface material families are empty")
    var previous := 2147483647
    for triangle_count: int in lod_triangle_counts:
        if triangle_count <= 0 or triangle_count >= previous:
            errors.append("surface LOD triangle counts must be positive and strictly decreasing")
            break
        previous = triangle_count
    if lod_triangle_counts.is_empty():
        errors.append("surface LOD triangle counts are empty")
    return errors

func _is_sha256(value: String) -> bool:
    if value.length() != 64:
        return false
    for character: String in value:
        if character not in "0123456789abcdef":
            return false
    return true

func _is_normalized_res_path(path: String) -> bool:
    if not path.begins_with("res://") or "\\" in path:
        return false
    var segments := path.trim_prefix("res://").split("/", true)
    return not segments.has("") and not segments.has(".") and not segments.has("..")
```

`validate()` requires a lowercase 64-character SHA-256, at least one UV set, `tangent_status == &"valid"`, normalized `res://` texture paths, unique non-empty material families, and a strictly decreasing positive LOD triangle-count sequence.

- [ ] **Step 6: Upgrade the manifest contract to schema version 2**

Set `SCHEMA_VERSION := 2`; add row kinds `head`, `hair`, and `accessory`; add required surface fields `uv_set_count`, `tangent_status`, `texture_paths`, `material_family_ids`, and `lod_triangle_counts`; add head fields `class_id`, `body_preset_id`, `neck_interface_id`, `helmet_envelope_id`, and ear socket paths. Add headwear fields only when an equipment row includes the `helmet` slot. Require necklace-anchor metadata for visible `amulet` presentation rows.

The v2 validator continues rejecting absolute machine paths and unapproved rows. It accepts a separate schema-1 validator path only for reading the existing baseline; production-v2 promotion requires schema 2.

- [ ] **Step 7: Run focused GREEN**

```powershell
& $godot --headless --path $project --quit-after 300 --script res://tests/focused_test_runner.gd -- `
  tests/unit/test_character_head_visual_definition.gd `
  tests/unit/test_headwear_fit_descriptor.gd `
  tests/unit/test_character_surface_definition.gd `
  tests/unit/test_character_visual_data.gd `
  tests/unit/test_equipment_asset_manifest_contract.gd
```

Expected: exit `0`, `TEST_SUMMARY: PASS (0 failures)`, and no captured script error.

- [ ] **Step 8: Review and checkpoint**

Run the full suite, `git diff --check`, and inspect the exact diff. Commit only after Jacob approves this contract checkpoint:

```powershell
git add scripts/presentation/character_head_visual_definition.gd scripts/presentation/headwear_fit_descriptor.gd scripts/presentation/character_surface_definition.gd scripts/presentation/character_visual_profile.gd scripts/presentation/equipment_body_fit_descriptor.gd scripts/presentation/equipment_asset_manifest_contract.gd tests/unit/test_character_head_visual_definition.gd tests/unit/test_headwear_fit_descriptor.gd tests/unit/test_character_surface_definition.gd tests/unit/test_character_visual_data.gd tests/unit/test_equipment_asset_manifest_contract.gd
git commit -m "feat: define production character asset contracts"
```

---

### Task 3: Add a Semantic Mapping for Superset Production Skeletons

**Files:**
- Create: `scripts/presentation/humanoid_rig_mapping.gd`
- Modify: `scripts/presentation/humanoid_rig_contract.gd`
- Create: `tests/unit/test_production_humanoid_rig_mapping.gd`
- Modify: `tests/unit/test_humanoid_rig_contract.gd`
- Later create after the body-specific mapping-resource gate: `data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres`
- Later create after the body-specific mapping-resource gate: `data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres`

**Interfaces:**
- Consumes: `HumanoidRigDefinition.roles`, the existing exact-19-bone validator, and an inspected production `Skeleton3D`.
- Produces: `HumanoidRigMapping` and `HumanoidRigContract.validate_mapped_rig(definition, mapping, skeleton, skin)`.

- [ ] **Step 1: Write the mapped-rig RED tests**

Construct an in-memory skeleton with all 19 required mapped bones plus three extra presentation bones. Assert that the legacy exact validator rejects it while the new mapped validator accepts it. Add failures for a missing role, duplicate target bone, missing mapped bone, a mapped child whose required parent is not an ancestor, non-finite rest data, and a Skin missing a mapped bind.

Required resource interface:

```gdscript
class_name HumanoidRigMapping
extends Resource

@export var mapping_id: StringName
@export var canonical_rig_id: StringName = &"pf_humanoid_v1"
@export var role_to_bone: Dictionary = {}
@export var source_skeleton_sha256: String
@export var source_rest_signature: String

func validate(definition: HumanoidRigDefinition) -> PackedStringArray:
    var errors := PackedStringArray()
    if mapping_id.is_empty():
        errors.append("humanoid rig mapping id is empty")
    if canonical_rig_id != HumanoidRigContract.CANONICAL_RIG_ID:
        errors.append("humanoid rig mapping canonical id is invalid")
    if definition == null:
        errors.append("humanoid rig mapping definition is missing")
        return errors
    var seen_bones: Dictionary = {}
    for role: StringName in HumanoidRigContract.REQUIRED_ROLES:
        if not role_to_bone.has(role):
            errors.append("humanoid rig mapping is missing role %s" % role)
            continue
        var bone_name := StringName(role_to_bone[role])
        if bone_name.is_empty() or seen_bones.has(bone_name):
            errors.append("humanoid rig mapping role %s has empty or duplicate bone %s" % [role, bone_name])
        seen_bones[bone_name] = true
    if not _is_sha256(source_skeleton_sha256):
        errors.append("humanoid rig mapping source skeleton hash is invalid")
    if source_rest_signature.is_empty():
        errors.append("humanoid rig mapping source rest signature is empty")
    return errors

func _is_sha256(value: String) -> bool:
    if value.length() != 64:
        return false
    for character: String in value:
        if character not in "0123456789abcdef":
            return false
    return true
```

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_production_humanoid_rig_mapping.gd tests/unit/test_humanoid_rig_contract.gd
```

Expected: nonzero exit because `HumanoidRigMapping` and `validate_mapped_rig` do not exist.

- [ ] **Step 3: Implement mapped validation without weakening legacy validation**

Add:

```gdscript
static func validate_mapped_rig(
        definition: HumanoidRigDefinition,
        mapping: HumanoidRigMapping,
        skeleton: Skeleton3D,
        skin: Skin
    ) -> PackedStringArray:
    var errors := PackedStringArray()
    if mapping == null:
        errors.append("humanoid rig mapping is missing")
        return errors
    errors.append_array(mapping.validate(definition))
    if skeleton == null:
        errors.append("mapped humanoid Skeleton3D is missing")
        return errors
    if skin == null:
        errors.append("mapped humanoid Skin is missing")
        return errors
    var bind_names: Dictionary = {}
    for bind_index: int in skin.get_bind_count():
        var bind_name := skin.get_bind_name(bind_index)
        if bind_name.is_empty() or bind_names.has(bind_name):
            errors.append("mapped humanoid Skin has empty or duplicate bind %s" % bind_name)
        bind_names[bind_name] = true
        _validate_transform(skin.get_bind_pose(bind_index), "mapped humanoid Skin bind %s" % bind_name, errors)
    for role: StringName in REQUIRED_ROLES:
        if not mapping.role_to_bone.has(role):
            continue
        var bone_name := StringName(mapping.role_to_bone[role])
        var matches := _bone_indices_named(skeleton, bone_name)
        if matches.size() != 1:
            errors.append("mapped humanoid role %s bone %s must exist exactly once" % [role, bone_name])
            continue
        var bone_index: int = matches[0]
        _validate_transform(skeleton.get_bone_rest(bone_index), "mapped humanoid bone %s rest" % bone_name, errors)
        if not bind_names.has(bone_name):
            errors.append("mapped humanoid Skin is missing bone %s" % bone_name)
        var parent_role := StringName(REQUIRED_PARENT_BY_ROLE[role])
        if parent_role.is_empty() or not mapping.role_to_bone.has(parent_role):
            continue
        var parent_matches := _bone_indices_named(skeleton, StringName(mapping.role_to_bone[parent_role]))
        if parent_matches.size() == 1 and not _bone_is_ancestor(skeleton, parent_matches[0], bone_index):
            errors.append("mapped humanoid role %s does not descend from parent role %s" % [role, parent_role])
    return errors

static func _bone_is_ancestor(skeleton: Skeleton3D, ancestor_index: int, child_index: int) -> bool:
    var cursor := skeleton.get_bone_parent(child_index)
    while cursor >= 0:
        if cursor == ancestor_index:
            return true
        cursor = skeleton.get_bone_parent(cursor)
    return false
```

Implement the four stated validations directly; keep `validate_rig()` unchanged for existing exact-19-bone assets.

- [ ] **Step 4: Run GREEN and regression**

Run the focused two-suite command, then add `test_skinned_equipment_binding.gd` and `test_body_region_visibility.gd`. Expected: exit `0`, one PASS summary, and no new errors.

- [ ] **Step 5: Stop for exact imported-skeleton inspection approval**

Before generating either body-specific mapping resource, require Studio Lead approval under Jacob's delegated routine-gate authority for the exact two-resource write. The inspected source rigs contain 52 Mixamo bones, and each mapping resource must use the exact approved bone names, hierarchy, rests, Skin-bind behavior, source GLB SHA-256, and body-specific rest signature. Never guess from generic Mixamo conventions, combine the bodies into one resource, or normalize their distinct native rests.

- [ ] **Step 6: Checkpoint only after the mapping contract passes**

```powershell
git add scripts/presentation/humanoid_rig_mapping.gd scripts/presentation/humanoid_rig_contract.gd tests/unit/test_production_humanoid_rig_mapping.gd tests/unit/test_humanoid_rig_contract.gd
git commit -m "feat: validate mapped production humanoid rigs"
```

---

### Task 4: Qualify the Game-Ready Masculine and Feminine Body Derivatives

**Files:**
- External immutable attempts under `pilot-0001/bodies/masculine/game-ready/` and `pilot-0001/bodies/feminine/game-ready/`
- Create after approval: `data/presentation/manifests/pf_character_equipment_v2.json` body rows
- Create after approval: `docs/qa/character-model-replacement/body-pair-qualification.md`

**Interfaces:**
- Consumes: approved high-detail and rigged source hashes, Task 2 surface schema, Task 3 rig mapping contract.
- Produces: approved body derivatives with UVs, texture/material sets, LODs, polished skinning, body regions, and exact hashes.

- [ ] **Step 1: Approve the named art-operation route**

Present the exact operation list and tools before running it. 3D Gen Studio operations are allowed only within the approved list. Any Blender cleanup, retopology, UV, baking, weight painting, or export action requires a separate Blender approval naming the inputs and outputs.

- [ ] **Step 2: Preserve source identity**

Copy no file over an approved source. Allocate a new immutable attempt directory only after allocation approval. The attempt record binds the source SHA, tool versions, operation list, body preset, output filenames, and expected no-overwrite behavior.

- [ ] **Step 3: Produce game topology and UVs**

For each body derivative, require:

- deformation-aware topology around shoulders, elbows, wrists, hips, knees, ankles, neck, eyes, and mouth;
- one continuous approved neck interface;
- non-overlapping UVs except documented symmetry reuse;
- recorded texel density, padding, and seam policy;
- valid normals and tangents;
- no internal duplicate body shell or zero-area production faces;
- LOD triangle counts recorded in strictly decreasing order.

Do not set final triangle budgets until the exact six-party performance benchmark is measured. Record candidate counts and compare them rather than guessing a production limit.

- [ ] **Step 4: Bake and author the body surface**

Create and connect the required skin surface maps: base colour, roughness, normal, and ambient occlusion; use metallic only where a non-skin embedded material requires it. Separate eye, teeth, hair, and skin material families. Record colour-space and channel packing for every texture.

- [ ] **Step 5: Validate the body interface**

Verify feet at local `y = 0`, positive-Z forward, one-metre scale, neck interface, helmet envelope reference, ear sockets, necklace anchors, body regions, mapped skeleton, Skin binds, and animation deformation. Reject pinching, collapsing, detached vertices, or source-identity drift exceeding the separately approved derivative tolerance.

- [ ] **Step 6: Measure performance and select LODs**

Use a controlled Godot scene only after import approval. Measure one, two, four, and six fully presented party members under the intended high-angle camera, then repeat with representative enemy counts. Record CPU frame time, GPU frame time, VRAM, draw calls, triangles, and visible LOD transitions.

- [ ] **Step 7: Publish body rows only after review**

Add masculine and feminine body rows to the v2 manifest only after Jacob approves contact sheets, turntables, deformation clips, surface inspection, and performance evidence. `approval.validation_result` remains non-approved until that review.

---

### Task 5: Produce Two Fixed Paladin Heads and the Compatibility Envelopes

**Files:**
- External immutable Paladin head/hair attempts
- Create: `data/presentation/heads/paladin/paladin_masculine_head.tres`
- Create: `data/presentation/heads/paladin/paladin_feminine_head.tres`
- Add: corresponding head, hair, eye, and material assets under `assets/models/characters/pf_humanoid_v2/`
- Modify later: `data/presentation/profiles/paladin.tres`
- Test: `tests/unit/test_character_head_visual_definition.gd`

**Interfaces:**
- Consumes: approved body derivatives, neck interfaces, semantic rig mapping, head definition, and surface contract.
- Produces: fixed masculine/feminine Paladin identities that fit the shared head equipment envelopes.

- [ ] **Step 1: Approve exact concept/generation operations**

Record prompt, seed, model, workflow, source hashes, and output paths for each 3D Gen Studio operation. Free placeholder inputs may use the standing gate but remain marked placeholder and cannot be baked into a production-approved head without license review.

- [ ] **Step 2: Create class-readable head identities**

The two Paladin faces share a class identity through controlled visual cues while remaining distinct individuals. Each uses the approved body-specific neck seam, eye line, forward axis, skeleton mapping, and head envelope. Hair and facial hair are separate meshes.

- [ ] **Step 3: Surface the heads**

Create UVs and connected skin/face textures; separate eyes, teeth, hair, and skin material families. Validate face/body skin transitions under neutral, preview, gameplay, and icon lighting. Reject visible neck seams and mismatched tangent/normal response.

- [ ] **Step 4: Validate headwear and accessories**

Test full-helmet, open-helmet, and circlet states. Verify hidden/restored scalp, hair, facial hair, ears, and future ear-accessory regions. Validate left/right ear sockets and necklace anchors. Preserve face geometry inside the agreed helmet envelope.

- [ ] **Step 5: Create the two resource definitions**

Each `.tres` binds the exact approved scene, `class_id = &"paladin"`, correct body preset, neck interface, helmet envelope, ear socket paths, region IDs, and `CharacterSurfaceDefinition`.

- [ ] **Step 6: Run focused contract tests and request visual approval**

Run the head/surface/profile tests. Present front, three-quarter, side, rear, and neutral-expression images plus helmet and necklace states for both heads. No Dawn Bulwark production proceeds until Jacob approves both identities and their compatibility evidence.

---

### Task 6: Complete Dawn Bulwark on Both Bodies

**Files:**
- Preserve and later modify only under approval: `configs/dawn_bulwark_masculine_fitted_shell_recipe.v1.json`
- Create: `configs/dawn_bulwark_feminine_fitted_shell_recipe.v1.json`
- New immutable equipment attempts under `pilot-0001/equipment/dawn_bulwark/`
- Later add approved GLBs/textures under `assets/models/equipment/dawn_bulwark/`
- Modify presentation resources under `data/presentation/equipment/dawn_bulwark/`
- Preserve gameplay resources under `data/equipment/bases/dawn_bulwark/`

**Interfaces:**
- Consumes: approved body pair, Paladin heads, headwear/accessory envelopes, body-fit workflow, and stable Dawn Bulwark item IDs.
- Produces: an eleven-piece masculine/feminine Paladin equipment proof with icons and complete manifests.

- [ ] **Step 1: Obtain the exact option-A correction approval**

Present the localized masculine recipe correction design for cuirass front, backplate, and left pauldron. Ask separately for the exact write-free preview. Do not reuse the consumed preview approval.

- [ ] **Step 2: Run the masculine preview once**

Use the exact approved command and inputs. Require all six component upper bounds at or below `0.06`. A refusal writes no attempt and does not authorize threshold changes or repeated runs.

- [ ] **Step 3: Publish a masculine shell attempt only after preview acceptance**

Allocate and write exactly one attempt only after a separate publication approval. Preserve hashes, component witnesses, source body identity, recipe, policy, output GLB, and weight-transfer evidence.

- [ ] **Step 4: Design and preview the feminine shell independently**

Create the feminine recipe from the exact feminine body; do not scale the masculine output blindly. Apply the same six-component and `0.06` construction target. Use separate approval for the write-free preview and separate approval for attempt publication.

- [ ] **Step 5: Finish all eleven item presentations**

Classify every Dawn Bulwark item as skinned, rigid, or hybrid. Create masculine/feminine variants where the fit differs. Declare hidden body/head regions, headwear category, helmet envelope, necklace anchors, socket origins, material families, texture paths, LODs, and source hashes.

- [ ] **Step 6: UV, bake, texture, and materially finish the set**

Use reusable painted-metal, bare-metal, leather, cloth, gemstone, and emission families. Validate wear and dirt scale, material consistency, UV seams, normal/tangent response, and class-tint masks. Do not use depth bias to hide clipping.

- [ ] **Step 7: Render the eleven UI icons**

Render 256-pixel masters and derive 128-pixel runtime icons from the approved 3D masters. Preserve current item IDs and UI paths. Record source GLB/material hashes in the icon manifest.

- [ ] **Step 8: Validate all four Paladin combinations**

Inspect masculine/feminine bodies with masculine/feminine Paladin heads as paired by preset. Capture full rotation plus idle, walk, attack, hit, downed, and revive. Verify helmet, necklace, weapons, shield, body hiding, grounding, and no Z-fighting.

- [ ] **Step 9: Stop for Dawn Bulwark visual acceptance**

Jacob must approve the full body/head/equipment turntables and icons before any Godot production import or Paladin profile switch.

---

### Task 7: Integrate a Paladin-Only v2 Godot Proof

**Files:**
- Create: `scenes/characters/presentation/pf_humanoid_v2.tscn`
- Modify: `scripts/presentation/character_presentation.gd`
- Modify: `scripts/presentation/forge_humanoid_model.gd` only if the wrapper cannot consume the new head/rig contracts without it
- Modify: `data/presentation/profiles/paladin.tres`
- Add approved assets under `assets/models/characters/pf_humanoid_v2/` and `assets/models/equipment/dawn_bulwark/`
- Create: `data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres`
- Create: `data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres`
- Create: `data/presentation/manifests/pf_character_equipment_v2.json`
- Create: `tests/integration/production_character_preview_runner.gd`
- Modify: `tests/unit/test_character_presentation.gd`
- Modify: `tests/unit/test_character_equipment_preview.gd`
- Modify: `tests/unit/test_playable_class_presentations.gd`
- Create: `docs/qa/character-model-replacement/paladin-godot-proof.md`

**Interfaces:**
- Consumes: approved v2 body pair, Paladin heads, Dawn Bulwark set, manifest rows, and rig mapping.
- Produces: one production-v2 Paladin profile while all other classes retain the prototype wrapper.

- [ ] **Step 1: Obtain exact Godot import approval**

List every source asset, destination path, expected generated sidecar/cache behavior, and profile file that will change. No other class profile is in scope.

- [ ] **Step 2: Write failing integration tests**

Tests require Paladin to resolve `pf_humanoid_v2.tscn`, two class heads, mapped rig, eleven default pieces, body/head region hiding, and exactly one active body/head/item instance. They require every non-Paladin profile to remain on `forge_humanoid_model.tscn`.

- [ ] **Step 3: Run RED**

Expected: failures only for absent v2 resources and Paladin mapping; no parser or fixture failure.

- [ ] **Step 4: Import versioned assets and implement the wrapper**

The wrapper instances the selected body and class head, validates the mapped rig, builds semantic `BoneAttachment3D` sockets, applies body/head visibility regions, attaches rigid items, binds skinned items, and exposes the existing `CharacterPresentation` operations. Do not rename gameplay-facing action or slot IDs.

- [ ] **Step 5: Switch only Paladin**

Set Paladin's `presentation_scene` to the v2 wrapper and provide exactly one masculine and one feminine head definition. Preserve every equipment base ID and all combat/action data.

- [ ] **Step 6: Run focused GREEN**

Run the head, surface, rig, manifest, body-region, skinned-equipment, character-presentation, preview, and playable-class suites. Expected: exit `0` and `TEST_SUMMARY: PASS (0 failures)`.

- [ ] **Step 7: Run deterministic visual evidence**

`production_character_preview_runner.gd` captures both Paladin presets at front, three-quarter, side, rear, and evenly sampled full rotation; idle/walk/attack/hit/downed/revive; helmet visibility states; necklace state; and equipment count diagnostics. It fails on blank frames, wrong instance counts, missing resources, non-finite transforms, or framing outside the viewport.

- [ ] **Step 8: Run complete regression and performance gates**

Run cold import, the full test suite, character sandbox, locomotion smoke, icon validator, and six-party performance scene. Preserve exact logs. Require exit `0`, terminal PASS summaries, and no new errors.

- [ ] **Step 9: Obtain Jacob's live visual acceptance**

Present fresh video/turntable evidence from the exact candidate. Rollback is a one-file Paladin profile reference restoration. Do not begin the remaining 88 pieces or 16 heads until Jacob approves the Paladin proof.

- [ ] **Step 10: Checkpoint after acceptance**

Stage only the approved Paladin-v2 files and evidence. Commit only after explicit checkpoint approval:

```powershell
git commit -m "feat: add production Paladin character proof"
```

---

### Task 8: Produce the Remaining Sixteen Heads and Eighty-Eight Equipment Entries

**Files:**
- Add: masculine/feminine head definitions under `data/presentation/heads/forge_vanguard/`, `ranger/`, `mage/`, `cleric/`, `rogue/`, `frost_mage/`, `warlock/`, and `marksman/`.
- Add: approved character/head/hair assets under `assets/models/characters/pf_humanoid_v2/`
- Add: approved equipment assets under `assets/models/equipment/forge_vanguard/`, `greenwood/`, `emberweave/`, `storm_chaplain/`, `nightstep/`, `rime_scholar/`, `grave_covenant/`, and `siege_archer/`.
- Modify: eight non-Paladin profiles only after each set passes
- Modify: eighty-eight presentation definitions while preserving ninety-nine gameplay bases
- Expand: `data/presentation/manifests/pf_character_equipment_v2.json`
- Expand: `docs/qa/character-model-replacement/`

**Interfaces:**
- Consumes: accepted Paladin proof, production contracts, body pair, helmet envelopes, and per-item manifest schema.
- Produces: complete eighteen-head and ninety-nine-item candidate library.

- [ ] **Step 1: Freeze the accepted Paladin pipeline**

Record its exact scripts, tools, material families, UV policies, rig mapping, evidence template, and hashes. Changes to the pipeline after this point require a focused regression against Paladin before batch use.

- [ ] **Step 2: Process one class set at a time**

Order: Fighter/Forge Vanguard, Ranger/Greenwood, Marksman/Siege Archer, Rogue/Nightstep, Mage/Emberweave, Frost Mage/Rime Scholar, Cleric/Storm Chaplain, Warlock/Grave Covenant. For each class:

1. produce its fixed masculine and feminine heads;
2. review identity and helmet-envelope compliance;
3. produce its existing catalog equipment entries;
4. UV, bake, texture, rig/attach, and create LODs;
5. render icons from approved masters;
6. validate both body presets and all required actions;
7. obtain Jacob's class-set visual approval;
8. switch only that class profile after import approval.

- [ ] **Step 3: Preserve exact catalog counts**

Fighter retains 12 available entries including the hammer alternative; Frost Mage retains 10; each other set retains 11. Total remains 99 and the default sheets remain 98 unless a separately approved gameplay design changes them.

- [ ] **Step 4: Run cross-head equipment matrices**

Every helmet is checked against all eighteen heads, not only its originating class. Every visible necklace/amulet is checked against both bodies and every armour neckline it can legally accompany. Record suppress/replace behavior for hair, facial hair, and future earrings.

- [ ] **Step 5: Enforce per-class rollback**

Keep a class on the prototype profile until its body/head/equipment set passes. A failed class reverts only its profile reference and presentation resources; accepted neighboring classes remain intact.

- [ ] **Step 6: Checkpoint each class separately**

Each class checkpoint includes source/provenance manifest rows, approved runtime assets, resources, tests, icons, and evidence. No multi-class bulk commit is used; each class remains independently reversible.

---

### Task 9: Promote and Qualify All Nine Classes

**Files:**
- Modify: all nine profile resources only when the complete candidate is accepted
- Finalize: `data/presentation/manifests/pf_character_equipment_v2.json`
- Create: `docs/qa/character-model-replacement/nine-class-production-acceptance.md`
- Expand: `tests/integration/production_character_preview_runner.gd`
- Modify: affected presentation and catalog tests

**Interfaces:**
- Consumes: nine accepted class sets, eighteen accepted heads, ninety-nine accepted equipment entries, two accepted body derivatives.
- Produces: complete production-v2 class presentation candidate with preserved prototype rollback.

- [ ] **Step 1: Validate all eighteen class/body combinations**

For each combination, assert the fixed head ID, expected default equipment count, one body, one head, one instance per expected item, correct hidden regions, valid rig mapping, animation presence, grounding, and viewport framing.

- [ ] **Step 2: Capture full visual evidence**

Capture front, three-quarter, side, rear, and continuous full rotation; idle, walk, attack, hit, downed, revive, and Cleric heal; equipped/unequipped comparisons; helmet categories; necklace presentation; and representative equipment swaps. Record exact revision and manifest hash in every evidence index.

- [ ] **Step 3: Validate surface and import quality**

Require valid UV/tangent/material/texture/LOD fields for every manifest row. Scan Godot import logs for missing textures, broken Skin binds, unsupported material settings, invalid animation paths, and resource-load failures.

- [ ] **Step 4: Run performance qualification**

Measure one, two, four, and six party members across target 1080p, 1440p, and 4K settings plus representative enemy loads. Record CPU/GPU frame times, VRAM, draw calls, triangles, texture residency, and LOD transitions. A quality reduction requires new visual evidence and approval.

- [ ] **Step 5: Run the complete verification gate**

Run cold import, focused production suites, the full Party Forge suite, presentation sandbox, locomotion smoke, preview visibility runner, icon validator, and performance capture. Require exit `0`, terminal PASS summaries, `git diff --check`, and no excluded-worktree drift.

- [ ] **Step 6: Obtain final production-candidate approval**

Present the contact sheets, rotation videos, animation clips, icons, performance report, manifest, test summaries, known limitations, and rollback procedure. Prototype assets remain present until Jacob approves final promotion.

- [ ] **Step 7: Commit the accepted candidate**

After explicit approval, stage only the exact accepted candidate and evidence:

```powershell
git commit -m "feat: replace playable class presentation assets"
```

Merge and push remain separate explicit decisions handled by the Studio Lead/orchestrator.

---

## Plan Completion Evidence

The program is complete only when all of the following are true:

- two approved production body derivatives trace to immutable source hashes;
- eighteen fixed class heads resolve through profile data;
- all ninety-nine equipment entries retain their stable item IDs and complete presentation/icon chains;
- all helmets pass the eighteen-head compatibility matrix;
- visible amulets/necklaces pass both-body and armour-neckline checks;
- every production asset has valid topology, UVs, tangents, textures, material families, attachment/skin data, and measured LODs;
- every class/body preview is centred and grounded and survives full rotation without Z-fighting, duplicate visuals, stale instances, or body breakthrough;
- rig, animations, sockets, action events, collision, gameplay, saves, and progression remain intact;
- Paladin and each subsequent class received explicit visual acceptance before batch promotion;
- final import, focused tests, full suite, visual runners, icon validation, and performance qualification pass from one exact candidate revision;
- rollback remains possible through profile references while prototype assets are retained;
- the Studio Lead receives the exact accepted branch, revision, evidence paths, known limitations, and merge/push approval state.
