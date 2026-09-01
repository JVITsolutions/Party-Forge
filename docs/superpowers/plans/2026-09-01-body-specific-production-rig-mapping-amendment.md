# Body-Specific Production Rig Mapping Amendment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Amend the pre-resource production-rig contract so Party Forge can validate complete numeric-only imported skins, reproduce the two approved native rest signatures, and resolve exact body-specific mapping identities without creating either production mapping resource.

**Architecture:** HumanoidRigContract remains the single validation boundary and gains a mapped-production-only bind resolver plus a separate fixed-nine-decimal production-rest serializer. HumanoidRigMapping continues to carry source identity, while a stateless, injectable HumanoidRigMappingCatalog resolves masculine/feminine identities without loading absent production resources or mutating active presentation state. Three independently reviewable TDD commits separate bind behavior, rest/source identity, and catalog selection.

**Tech Stack:** Godot 4.7.1 stable Mono, typed GDScript, Godot Skin and Skeleton3D APIs, JSON test fixtures, SHA-256 String hashing, the existing focused_test_runner.gd and test_runner.gd harnesses, PowerShell, and Git.

## Global Constraints

- Authoritative worktree: F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\class-preview-character-model-replacement.
- Required branch: feat/class-preview-character-model-replacement. The immutable approved-design ancestor is fbc3f9e8c3d9853ffbf8d3c21944f970ac41231b and must remain an ancestor of the execution baseline.
- Immediately before Task 1, capture the then-current clean HEAD dynamically as implementationBase. Do not hard-code or predict the plan-correction commit hash.
- Preserve the masculine and feminine candidates' distinct native rest and bind poses.
- Preserve canonical_rig_id = &"pf_humanoid_v1"; do not change gameplay character, class, profile, item, ability, progression, or save-data IDs.
- Preserve validate_rig() as the exact legacy 19-bone validator.
- Preserve validate_skin() as the strict legacy named-bind validator.
- Only validate_mapped_rig() may accept empty bind names, and only when numeric bind indices provide complete, unique, in-range, one-to-one coverage of the exact Skeleton3D.
- If a bind name is present, it must resolve to exactly one skeleton bone and agree with the numeric bind index; the name never overrides the index.
- Missing, duplicate, out-of-range, unresolved, ambiguous, incomplete, or name/index-conflicting binds fail closed in deterministic order.
- Bind poses and mapped rests must remain finite and invertible under MIN_INVERTIBLE_DETERMINANT = 0.000000000001.
- Production rest serialization uses every bone in index order, fixed-nine-decimal Transform3D components, no header, newline separators, and no trailing newline.
- Masculine source SHA-256: 8f589e35f16f02fe4aa0f45b5f2c85377a41f9ecc188670bf59159518e6cdbe4.
- Masculine rest signature: 1ea73d190881c437d8ca6fc10dd7c4f446d2d14523416bcd0731264dad689eda.
- Feminine source SHA-256: 173198e3d044418b9765971e8b698664176c05dadd6a5aaa4ddb8df8d4c08667.
- Feminine rest signature: fad7e1860ef45781179d156654734b6160a7d97df96be43d3eb8c0bc51ea5c85.
- Do not create data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52.tres.
- Do not create data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres or pf_humanoid_v1_mixamo52_feminine.tres during this plan's executed checkpoint.
- Do not mutate, copy, rename, re-export, import, or normalize either immutable GLB.
- Do not modify docs/superpowers/plans/2026-08-31-production-character-equipment-replacement.md in this checkpoint; its singular mapping references are a documented reconciliation dependency.
- Do not perform Task 4 body qualification, manifest, scene, body derivative, Blender, 3D Gen Studio, geometry, rigging, weights, UV, material, texture, head, armor, equipment, gameplay integration, merge, push, fetch, rebase, cleanup, or deletion work.
- Preserve all 65 existing untracked .gd.uid sidecars and 12 existing untracked Task 1/spec/original-plan/evidence files byte-for-byte against C:\Users\Jacob\AppData\Local\Temp\pf-character-task2-reconcile-gate-0001\premerge-untracked-manifest.json.
- Each focused test command must exit 0 for GREEN, emit exactly one terminal TEST_SUMMARY: PASS (0 failures), and have no parser, loader, import, script, crash, segmentation, or leak diagnostics.
- Every RED command must exit nonzero and emit exactly one terminal TEST_SUMMARY: FAIL marker for the named missing behavior, not for a parser, loader, or fixture failure.
- Every code task follows RED, minimal GREEN, full focused regression, git diff --check, exact staging audit, and an independent commit.

---

## File Responsibility Map

| File | Responsibility in this checkpoint |
|---|---|
| scripts/presentation/humanoid_rig_contract.gd | Resolve mapped-production Skin binds, preserve legacy validators, serialize/hash full production skeleton rests, and compare a live skeleton to mapping.source_rest_signature. |
| scripts/presentation/humanoid_rig_mapping.gd | Require source_rest_signature to be a lowercase SHA-256 identity rather than an arbitrary non-empty string. |
| scripts/presentation/humanoid_rig_mapping_catalog.gd | New stateless presentation-only resolver with exact masculine/feminine IDs, source hashes, rest signatures, and future resource-path constants; accepts injected mappings for tests. |
| tests/unit/test_production_humanoid_rig_mapping.gd | RED/GREEN coverage for numeric bind resolution, mapped semantic coverage, hierarchy, finite/invertible transforms, rest identity, and deterministic mapped error ordering. |
| tests/unit/test_humanoid_rig_contract.gd | Explicit regression assertions that validate_rig() remains exact-19 and validate_skin() remains named-only with unchanged error behavior. |
| tests/fixtures/presentation/production_rig_inspection_rest_fixtures.json | Tracked, path-free extraction of the two inspected 52-bone name/parent/rest records and approved signatures; no GLB or production resource. |
| tests/unit/test_production_humanoid_rest_signature.gd | Reconstruct both inspected Skeleton3D fixtures and prove exact serialization bytes and approved SHA-256 values. |
| tests/unit/test_humanoid_rig_mapping_catalog.gd | Prove exact body-preset resolution, identity rejection, injected-fixture isolation, and failure without active-mapping mutation. |

No other tracked file is in scope. In particular, forge_humanoid_model.gd, character_presentation.gd, the original plan, manifests, scenes, GLBs, and .tres files remain untouched.

## Shared Interfaces

The tasks below define and consume these exact interfaces:

~~~gdscript
# scripts/presentation/humanoid_rig_contract.gd
static func validate_mapped_rig(
		definition: HumanoidRigDefinition,
		mapping: HumanoidRigMapping,
		skeleton: Skeleton3D,
		skin: Skin
	) -> PackedStringArray

static func serialize_production_rest(skeleton: Skeleton3D) -> String
static func production_rest_signature(skeleton: Skeleton3D) -> String

# Private mapped-production helper; returned Dictionary maps bone_index -> bind_index.
static func _resolve_mapped_skin_binds(
		skeleton: Skeleton3D,
		skin: Skin,
		errors: PackedStringArray
	) -> Dictionary

# Private mapped-production-only pure helper. Legacy validators do not use it.
static func _matching_name_indices(
		bone_names: Array[StringName],
		target_name: StringName
	) -> PackedInt32Array

# scripts/presentation/humanoid_rig_mapping_catalog.gd
func _init(mapping_by_body_preset: Dictionary = {}) -> void
func resolve(body_preset_id: StringName) -> HumanoidRigMapping
~~~

## Exact Shared 19-Role Mapping

Both later resources use this table. Tests may use synthetic names for generic contract behavior, but catalog identity fixtures use the exact body IDs, hashes, and signatures.

| Role | Bone |
|---|---|
| hips | mixamorig_Hips |
| spine | mixamorig_Spine |
| chest | mixamorig_Spine2 |
| neck | mixamorig_Neck |
| head | mixamorig_Head |
| upper_arm_left | mixamorig_LeftArm |
| lower_arm_left | mixamorig_LeftForeArm |
| hand_left | mixamorig_LeftHand |
| upper_arm_right | mixamorig_RightArm |
| lower_arm_right | mixamorig_RightForeArm |
| hand_right | mixamorig_RightHand |
| upper_leg_left | mixamorig_LeftUpLeg |
| lower_leg_left | mixamorig_LeftLeg |
| foot_left | mixamorig_LeftFoot |
| toe_left | mixamorig_LeftToeBase |
| upper_leg_right | mixamorig_RightUpLeg |
| lower_leg_right | mixamorig_RightLeg |
| foot_right | mixamorig_RightFoot |
| toe_right | mixamorig_RightToeBase |

---

## Mandatory Execution-Baseline Capture

Perform this gate immediately before Task 1 and preserve its output through Task 4. It establishes the only valid implementation diff base while retaining fbc3f9e8c3d9853ffbf8d3c21944f970ac41231b as immutable design provenance.

- [ ] **Step 1: Require a clean, approved baseline tree**

Run:

~~~powershell
$approvedDesignAncestor = 'fbc3f9e8c3d9853ffbf8d3c21944f970ac41231b'
git merge-base --is-ancestor $approvedDesignAncestor HEAD
if ($LASTEXITCODE -ne 0) { throw 'approved design commit is not an ancestor of the execution baseline' }
if (@(git status --porcelain=v1 | Where-Object { $_ -notmatch '^\?\?' }).Count -ne 0) {
    throw 'tracked worktree or index is not clean at implementation baseline capture'
}
$implementationBase = (git rev-parse HEAD).Trim()
~~~

Require branch feat/class-preview-character-model-replacement, 77 preserved untracked files, and no staged or tracked changes. `implementationBase` is intentionally derived from HEAD instead of being self-referential in this plan.

- [ ] **Step 2: Require the exact baseline contents**

Run:

~~~powershell
$requiredBaselinePaths = @(
    'docs/superpowers/specs/2026-09-01-body-specific-production-rig-mapping-amendment-design.md',
    'docs/superpowers/plans/2026-09-01-body-specific-production-rig-mapping-amendment.md'
)
foreach ($path in $requiredBaselinePaths) {
    git cat-file -e "${implementationBase}:$path"
    if ($LASTEXITCODE -ne 0) { throw "baseline is missing $path" }
}
$baselineDelta = @(git diff --name-only $approvedDesignAncestor $implementationBase)
if ($baselineDelta.Count -ne 1 -or $baselineDelta[0] -ne 'docs/superpowers/plans/2026-09-01-body-specific-production-rig-mapping-amendment.md') {
    throw "baseline contains unauthorized post-design paths: $($baselineDelta -join ', ')"
}
$forbiddenBaselinePaths = @(
    'scripts/presentation/humanoid_rig_mapping_catalog.gd',
    'tests/fixtures/presentation/production_rig_inspection_rest_fixtures.json',
    'tests/unit/test_production_humanoid_rest_signature.gd',
    'tests/unit/test_humanoid_rig_mapping_catalog.gd',
    'data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52.tres',
    'data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres',
    'data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres',
    'data/presentation/manifests/pf_character_equipment_v2.json',
    'docs/qa/character-model-replacement/body-pair-qualification.md'
)
foreach ($path in $forbiddenBaselinePaths) {
    git cat-file -e "${implementationBase}:$path" 2>$null
    if ($LASTEXITCODE -eq 0) { throw "baseline already contains forbidden implementation/resource/Task 4 path $path" }
}
~~~

This proves that the baseline tree contains the approved amendment and corrected plan, but no implementation, mapping resource, manifest-v2, body-qualification, or original Task 4 deliverable.

- [ ] **Step 3: Record implementationBase outside the repository**

Run once:

~~~powershell
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$suffix = [guid]::NewGuid().ToString('N').Substring(0, 8)
$baselineEvidenceRoot = "C:\Users\Jacob\AppData\Local\Temp\pf-body-rig-implementation-base-$stamp-$suffix"
New-Item -ItemType Directory -Path $baselineEvidenceRoot -Force | Out-Null
$baselineEvidencePath = Join-Path $baselineEvidenceRoot 'implementation-base.json'
[ordered]@{
    schema_version = 1
    branch = (git branch --show-current).Trim()
    approved_design_ancestor = $approvedDesignAncestor
    implementation_base = $implementationBase
    captured_utc = (Get-Date).ToUniversalTime().ToString('o')
    baseline_delta = @($baselineDelta)
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $baselineEvidencePath -Encoding utf8NoBOM
~~~

Read the JSON back and require its implementation_base to equal `git rev-parse HEAD`, its approved_design_ancestor to equal fbc3f9e8c3d9853ffbf8d3c21944f970ac41231b, and its baseline_delta to contain only the corrected plan path. Report `$baselineEvidencePath` at the final checkpoint. All later review, commit-count, diff, diff-check, and scope commands consume this recorded implementationBase.

---

### Task 1: Resolve Complete Numeric Production Skin Binds Without Weakening Legacy Validation

**Files:**
- Modify: scripts/presentation/humanoid_rig_contract.gd
- Modify: tests/unit/test_production_humanoid_rig_mapping.gd
- Modify: tests/unit/test_humanoid_rig_contract.gd

**Interfaces:**
- Consumes: existing HumanoidRigMapping.role_to_bone, REQUIRED_ROLES, REQUIRED_PARENT_BY_ROLE, _bone_is_ancestor(), and _validate_transform().
- Produces: _resolve_mapped_skin_binds(skeleton, skin, errors) -> Dictionary where each key is a resolved skeleton bone index and each value is the unique Skin bind slot; validate_mapped_rig() consumes that dictionary.
- Produces: mapped-production-only pure _matching_name_indices(bone_names, target_name) -> PackedInt32Array. It accepts a name snapshot rather than Skeleton3D so duplicate-name ambiguity can be tested without constructing an invalid Skeleton3D. Legacy validate_rig(), validate_skin(), and _bone_indices_named() remain unchanged and do not call this helper.

- [ ] **Step 1: Change the production Skin fixture to create explicit numeric indices**

In tests/unit/test_production_humanoid_rig_mapping.gd, replace _skin_for() with this complete helper. Named fixtures now carry both the exact name and matching numeric index, while include_names = false produces the inspected numeric-only shape.

~~~gdscript
func _skin_for(
		skeleton: Skeleton3D,
		omitted_bone: StringName = &"",
		include_names: bool = true
	) -> Skin:
	var skin := Skin.new()
	for bone_index: int in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(bone_index)
		if bone_name == omitted_bone:
			continue
		skin.add_bind(bone_index, skeleton.get_bone_rest(bone_index).affine_inverse())
		if include_names:
			skin.set_bind_name(skin.get_bind_count() - 1, bone_name)
	return skin
~~~

- [ ] **Step 2: Add the numeric-bind RED assertions**

Call _assert_numeric_bind_resolution(failures) from run() immediately after _assert_superset_validation(). Add these exact tests to tests/unit/test_production_humanoid_rig_mapping.gd:

~~~gdscript
func _assert_numeric_bind_resolution(failures: Array[String]) -> void:
	var mapping := _mapping()
	var skeleton := _superset_skeleton(mapping)
	var duplicate_name_snapshot: Array[StringName] = [&"PresentationRoot", &"DuplicateName", &"DuplicateName"]
	var has_name_list_helper := _contract.has_method(&"_matching_name_indices")
	TestAssertions.truthy(has_name_list_helper, "mapped-production duplicate-name resolver exists", failures)
	if has_name_list_helper:
		TestAssertions.equal(
			_contract.call(&"_matching_name_indices", duplicate_name_snapshot, &"DuplicateName"),
			PackedInt32Array([1, 2]),
			"mapped-production duplicate-name resolver returns every matching index deterministically",
			failures
		)

	var numeric_only := _skin_for(skeleton, &"", false)
	TestAssertions.equal(
		_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, numeric_only),
		PackedStringArray(),
		"complete unique numeric-only Skin binds validate",
		failures
	)

	var named_numeric := _skin_for(skeleton)
	TestAssertions.equal(
		_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, named_numeric),
		PackedStringArray(),
		"present names that agree with numeric indices validate",
		failures
	)

	var negative := _skin_for(skeleton, &"", false)
	negative.set_bind_bone(0, -1)
	TestAssertions.truthy(
		_contains(_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, negative), "bind 0 bone index -1 is out of range"),
		"negative numeric bind rejects",
		failures
	)

	var out_of_range := _skin_for(skeleton, &"", false)
	out_of_range.set_bind_bone(0, skeleton.get_bone_count())
	TestAssertions.truthy(
		_contains(_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, out_of_range), "bind 0 bone index %d is out of range" % skeleton.get_bone_count()),
		"out-of-range numeric bind rejects",
		failures
	)

	var duplicate := _skin_for(skeleton, &"", false)
	var final_bind := duplicate.get_bind_count() - 1
	duplicate.set_bind_bone(final_bind, 0)
	var duplicate_errors: PackedStringArray = _contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, duplicate)
	TestAssertions.truthy(_contains(duplicate_errors, "bind %d duplicates skeleton bone 0" % final_bind), "duplicate numeric coverage rejects", failures)
	TestAssertions.truthy(_contains(duplicate_errors, "missing skeleton bone WeaponSocketDriver"), "duplicate coverage also reports the uncovered bone", failures)

	var incomplete := _skin_for(skeleton, &"WeaponSocketDriver", false)
	TestAssertions.truthy(
		_contains(_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, incomplete), "missing skeleton bone WeaponSocketDriver"),
		"incomplete full-skeleton coverage rejects",
		failures
	)

	var missing_name := _skin_for(skeleton)
	missing_name.set_bind_name(0, &"MissingProductionBone")
	TestAssertions.truthy(
		_contains(_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, missing_name), "bind 0 name MissingProductionBone must resolve exactly once"),
		"present bind name with no skeleton match rejects",
		failures
	)

	var name_conflict := _skin_for(skeleton)
	name_conflict.set_bind_name(0, skeleton.get_bone_name(1))
	TestAssertions.truthy(
		_contains(_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, name_conflict), "bind 0 name %s resolves to bone 1 but numeric index is 0" % skeleton.get_bone_name(1)),
		"present name/index conflict rejects",
		failures
	)

	var singular_bind := _skin_for(skeleton, &"", false)
	singular_bind.set_bind_pose(0, Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO))
	TestAssertions.truthy(
		_contains(_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, singular_bind), "bind 0 pose must be invertible"),
		"singular numeric bind pose rejects",
		failures
	)

	var non_finite_bind := _skin_for(skeleton, &"", false)
	var invalid_pose := non_finite_bind.get_bind_pose(0)
	invalid_pose.origin.x = INF
	non_finite_bind.set_bind_pose(0, invalid_pose)
	non_finite_bind.set_bind_bone(0, -1)
	var ordered_errors: PackedStringArray = _contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, non_finite_bind)
	TestAssertions.equal(ordered_errors[0], "mapped humanoid Skin bind 0 pose must be finite", "bind-pose errors lead slot-local resolution errors", failures)
	TestAssertions.equal(ordered_errors[1], "mapped humanoid Skin bind 0 bone index -1 is out of range", "numeric range error follows pose error deterministically", failures)

	skeleton.free()
~~~

- [ ] **Step 3: Add mapped-rest invertibility and semantic-coverage RED assertions**

Append these cases to _assert_rest_and_skin_failures(). They supplement the existing non-finite rest, missing mapped bind, and hierarchy cases.

~~~gdscript
	skeleton = _superset_skeleton(mapping)
	skin = _skin_for(skeleton, &"", false)
	var singular_rest_index := skeleton.find_bone(_bone_for(mapping, &"head"))
	skeleton.set_bone_rest(
		singular_rest_index,
		Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)
	)
	TestAssertions.truthy(
		_contains(_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, skin), "mapped humanoid bone %s rest must be invertible" % _bone_for(mapping, &"head")),
		"singular mapped rest rejects",
		failures
	)
	skeleton.free()

	skeleton = _superset_skeleton(mapping)
	skin = _skin_for(skeleton, _bone_for(mapping, &"hand_right"), false)
	TestAssertions.truthy(
		_contains(_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, skin), "mapped humanoid Skin is missing bone %s" % _bone_for(mapping, &"hand_right")),
		"complete skeleton coverage includes every semantic mapped bone",
		failures
	)
	skeleton.free()
~~~

In the existing non-finite named-Skin assertion in the same function, replace its old name-based error fragment with the mapped resolver's exact bind-slot error:

~~~gdscript
	TestAssertions.truthy(
		_contains(
			_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, skin),
			"mapped humanoid Skin bind %d pose must be finite" % bind_index
		),
		"non-finite named Skin bind rejects",
		failures
	)
~~~

- [ ] **Step 4: Add explicit legacy-containment RED assertions**

In tests/unit/test_humanoid_rig_contract.gd, call _assert_legacy_bind_and_bone_count_errors(failures) from run() after _assert_legacy_validator_rejects_superset_skeleton(), then add:

~~~gdscript
func _assert_legacy_bind_and_bone_count_errors(failures: Array[String]) -> void:
	var definition := _fixture_definition()
	var numeric_only := Skin.new()
	numeric_only.add_bind(0, Transform3D.IDENTITY)
	var skin_errors: PackedStringArray = _contract.call(&"validate_skin", definition, numeric_only)
	TestAssertions.equal(
		skin_errors[0],
		"humanoid rig Skin bind 0 must be named; numeric-only and unnamed binds are invalid",
		"legacy validate_skin keeps its exact named-only error",
		failures
	)
	TestAssertions.equal(
		skin_errors.size(),
		ROLES.size() + 1,
		"legacy validate_skin still reports one unnamed bind plus all nineteen missing canonical bones",
		failures
	)

	var named := _named_skin_for(definition)
	TestAssertions.equal(
		_contract.call(&"validate_skin", definition, named),
		PackedStringArray(),
		"legacy validate_skin still accepts its existing ordered named fixture",
		failures
	)

	var skeleton := _skeleton_for(definition)
	skeleton.add_bone(&"ProductionExtra")
	skeleton.set_bone_rest(skeleton.get_bone_count() - 1, Transform3D.IDENTITY)
	var pivots := _pivot_fixture()
	var rig_errors: PackedStringArray = _contract.call(&"validate_rig", definition, skeleton, pivots)
	TestAssertions.truthy(
		_contains(rig_errors, "humanoid rig bone count must be 19, got 20"),
		"legacy validate_rig keeps exact nineteen-bone rejection",
		failures
	)
	skeleton.free()
	pivots.free()
~~~

- [ ] **Step 5: Run the focused suites and verify trustworthy RED**

Run:

~~~powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
$project = 'F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\class-preview-character-model-replacement'
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_production_humanoid_rig_mapping.gd tests/unit/test_humanoid_rig_contract.gd
~~~

Expected: nonzero process exit and exactly one terminal TEST_SUMMARY: FAIL marker. The missing-production-behavior failures must name mapped-production duplicate-name resolver exists, complete unique numeric-only Skin binds validate, negative numeric bind rejects, out-of-range numeric bind rejects, duplicate numeric coverage rejects, duplicate coverage also reports the uncovered bone, incomplete full-skeleton coverage rejects, present bind name with no skeleton match rejects, present name/index conflict rejects, singular numeric bind pose rejects, bind-pose errors lead slot-local resolution errors, numeric range error follows pose error deterministically, non-finite named Skin bind rejects, and singular mapped rest rejects. The synthetic duplicate-name assertion must not mutate, construct, or serialize a duplicate-name Skeleton3D. There must be no engine, fixture, parser, loader, import, script, crash, segmentation, or leak diagnostic.

- [ ] **Step 6: Implement the mapped-production bind resolver**

In scripts/presentation/humanoid_rig_contract.gd, replace the current bind_names loop in validate_mapped_rig() with:

~~~gdscript
	var bind_index_by_bone_index := _resolve_mapped_skin_binds(skeleton, skin, errors)
~~~

Replace the mapped-bone Skin membership check:

~~~gdscript
		if not bind_index_by_bone_index.has(bone_index):
			errors.append("mapped humanoid Skin is missing bone %s" % bone_name)
~~~

Add this complete private helper immediately after validate_mapped_rig():

~~~gdscript
static func _resolve_mapped_skin_binds(
		skeleton: Skeleton3D,
		skin: Skin,
		errors: PackedStringArray
	) -> Dictionary:
	var bind_index_by_bone_index: Dictionary = {}
	var bone_names: Array[StringName] = []
	for bone_index: int in skeleton.get_bone_count():
		bone_names.append(skeleton.get_bone_name(bone_index))
	for bind_index: int in skin.get_bind_count():
		_validate_transform(
			skin.get_bind_pose(bind_index),
			"mapped humanoid Skin bind %d pose" % bind_index,
			errors
		)
		var bone_index := skin.get_bind_bone(bind_index)
		if bone_index < 0 or bone_index >= skeleton.get_bone_count():
			errors.append("mapped humanoid Skin bind %d bone index %d is out of range" % [bind_index, bone_index])
			continue
		if bind_index_by_bone_index.has(bone_index):
			errors.append("mapped humanoid Skin bind %d duplicates skeleton bone %d" % [bind_index, bone_index])
		else:
			bind_index_by_bone_index[bone_index] = bind_index
		var bind_name := skin.get_bind_name(bind_index)
		if bind_name.is_empty():
			continue
		var matching_bones := _matching_name_indices(bone_names, bind_name)
		if matching_bones.size() != 1:
			errors.append("mapped humanoid Skin bind %d name %s must resolve exactly once" % [bind_index, bind_name])
		elif matching_bones[0] != bone_index:
			errors.append(
				"mapped humanoid Skin bind %d name %s resolves to bone %d but numeric index is %d"
				% [bind_index, bind_name, matching_bones[0], bone_index]
			)
	for bone_index: int in skeleton.get_bone_count():
		if not bind_index_by_bone_index.has(bone_index):
			errors.append(
				"mapped humanoid Skin is missing skeleton bone %s at index %d"
				% [skeleton.get_bone_name(bone_index), bone_index]
			)
	return bind_index_by_bone_index

static func _matching_name_indices(
		bone_names: Array[StringName],
		target_name: StringName
	) -> PackedInt32Array:
	var matching_indices := PackedInt32Array()
	for bone_index: int in bone_names.size():
		if bone_names[bone_index] == target_name:
			matching_indices.append(bone_index)
	return matching_indices
~~~

Do not alter validate_rig(), validate_skin(), serialize_skin_binds(), _bone_indices_named(), or any other legacy helper. The pure name-list helper is private to mapped-production validation.

- [ ] **Step 7: Run Task 1 GREEN and regression suites**

Run the Step 5 command. Expected: exit 0, exactly one terminal TEST_SUMMARY: PASS (0 failures), and clean diagnostic scan.

Then run:

~~~powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_production_humanoid_rig_mapping.gd tests/unit/test_humanoid_rig_contract.gd tests/unit/test_skinned_equipment_binding.gd tests/unit/test_body_region_visibility.gd
~~~

Expected: exit 0, exactly one terminal TEST_SUMMARY: PASS (0 failures), no parser/loader/import/script/crash/leak diagnostics.

- [ ] **Step 8: Audit Task 1 diff and commit**

Run git diff --check. Require that git diff --name-only lists only:

~~~text
scripts/presentation/humanoid_rig_contract.gd
tests/unit/test_humanoid_rig_contract.gd
tests/unit/test_production_humanoid_rig_mapping.gd
~~~

Rehash the 77 pre-existing untracked files against the preserved manifest and require zero missing, byte, or SHA errors. Then commit:

~~~powershell
git add scripts/presentation/humanoid_rig_contract.gd tests/unit/test_humanoid_rig_contract.gd tests/unit/test_production_humanoid_rig_mapping.gd
git commit -m "feat: accept complete numeric production skin binds"
~~~

Verify the commit has exactly those three paths and preserve its hash for Task 4.

---

### Task 2: Reproduce and Enforce Body-Specific Production Rest Identity

**Files:**
- Create: tests/fixtures/presentation/production_rig_inspection_rest_fixtures.json
- Create: tests/unit/test_production_humanoid_rest_signature.gd
- Modify: scripts/presentation/humanoid_rig_contract.gd
- Modify: scripts/presentation/humanoid_rig_mapping.gd
- Modify: tests/unit/test_production_humanoid_rig_mapping.gd

**Interfaces:**
- Consumes: the final immutable inspection evidence at C:\Users\Jacob\AppData\Local\Temp\pf-rig-inspection-20260901T034123Z-7f9b59d1\evidence-0003\rig-inspection.json.
- Produces: serialize_production_rest(skeleton) -> String and production_rest_signature(skeleton) -> String; HumanoidRigMapping.source_rest_signature becomes a required lowercase SHA-256 and validate_mapped_rig() compares it to the live 52-bone skeleton.

- [ ] **Step 1: Generate the exact tracked, path-free rest fixture from evidence**

Run this complete extraction once. It copies no GLB and retains no absolute source path:

~~~powershell
$evidencePath = 'C:\Users\Jacob\AppData\Local\Temp\pf-rig-inspection-20260901T034123Z-7f9b59d1\evidence-0003\rig-inspection.json'
$fixturePath = 'tests\fixtures\presentation\production_rig_inspection_rest_fixtures.json'
$evidence = Get-Content -LiteralPath $evidencePath -Raw | ConvertFrom-Json
$fixture = [ordered]@{
    schema_version = 1
    serialization = 'index|name|parent_index|12 fixed-nine-decimal Transform3D components; LF separators; no header; no trailing LF'
    candidates = @($evidence.candidates | ForEach-Object {
        [ordered]@{
            body_preset_id = $_.label
            expected_rest_signature = $_.skeletons[0].rest_signature_sha256
            bones = @($_.skeletons[0].bones | ForEach-Object {
                [ordered]@{
                    index = $_.index
                    name = $_.name
                    parent_index = $_.parent_index
                    local_rest_signature = $_.local_rest.signature
                }
            })
        }
    })
}
New-Item -ItemType Directory -Path (Split-Path -Parent $fixturePath) -Force | Out-Null
$fixture | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $fixturePath -Encoding utf8NoBOM
~~~

Immediately parse the generated file and require: schema_version = 1; exactly two candidates; body_preset_id values masculine then feminine; exactly 52 bones per candidate; indices 0 through 51 in order; no path key anywhere; and the two exact approved signatures from Global Constraints.

- [ ] **Step 2: Write the production-rest RED suite**

Create tests/unit/test_production_humanoid_rest_signature.gd with this complete suite:

~~~gdscript
extends RefCounted

const CONTRACT_PATH := "res://scripts/presentation/humanoid_rig_contract.gd"
const FIXTURE_PATH := "res://tests/fixtures/presentation/production_rig_inspection_rest_fixtures.json"
const EXPECTED := {
	&"masculine": "1ea73d190881c437d8ca6fc10dd7c4f446d2d14523416bcd0731264dad689eda",
	&"feminine": "fad7e1860ef45781179d156654734b6160a7d97df96be43d3eb8c0bc51ea5c85",
}

var _contract: RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var contract_script := load(CONTRACT_PATH) as Script
	TestAssertions.truthy(contract_script != null, "production rest contract loads", failures)
	if contract_script == null:
		return failures
	_contract = contract_script.new() as RefCounted
	TestAssertions.truthy(_contract.has_method(&"serialize_production_rest"), "production rest serializer exists", failures)
	TestAssertions.truthy(_contract.has_method(&"production_rest_signature"), "production rest signature exists", failures)
	if not _contract.has_method(&"serialize_production_rest") or not _contract.has_method(&"production_rest_signature"):
		return failures
	var fixture := _fixture()
	TestAssertions.equal(int(fixture.get("schema_version", 0)), 1, "rest fixture schema is exact", failures)
	var candidates: Array = fixture.get("candidates", [])
	TestAssertions.equal(candidates.size(), 2, "rest fixture contains both body presets", failures)
	for candidate_value: Variant in candidates:
		var candidate := candidate_value as Dictionary
		var body_preset_id := StringName(candidate.get("body_preset_id", ""))
		var skeleton := _skeleton_for(candidate)
		var expected_serialization := _expected_serialization(candidate)
		var actual_serialization := String(_contract.call(&"serialize_production_rest", skeleton))
		TestAssertions.equal(skeleton.get_bone_count(), 52, "%s fixture has 52 bones" % body_preset_id, failures)
		TestAssertions.equal(actual_serialization, expected_serialization, "%s rest serialization matches inspected bytes" % body_preset_id, failures)
		TestAssertions.truthy(not actual_serialization.begins_with("production"), "%s serialization has no header" % body_preset_id, failures)
		TestAssertions.truthy(not actual_serialization.ends_with("\n"), "%s serialization has no trailing newline" % body_preset_id, failures)
		TestAssertions.equal(
			_contract.call(&"production_rest_signature", skeleton),
			EXPECTED[body_preset_id],
			"%s rest signature matches approved inspection" % body_preset_id,
			failures
		)
		skeleton.free()
	TestAssertions.truthy(EXPECTED[&"masculine"] != EXPECTED[&"feminine"], "body presets retain distinct native rest identities", failures)
	return failures

func _fixture() -> Dictionary:
	var file := FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if parsed is Dictionary else {}

func _skeleton_for(candidate: Dictionary) -> Skeleton3D:
	var skeleton := Skeleton3D.new()
	var bones: Array = candidate.get("bones", [])
	for bone_value: Variant in bones:
		var bone := bone_value as Dictionary
		skeleton.add_bone(StringName(bone.get("name", "")))
	for bone_value: Variant in bones:
		var bone := bone_value as Dictionary
		var index := int(bone.get("index", -1))
		skeleton.set_bone_parent(index, int(bone.get("parent_index", -1)))
		skeleton.set_bone_rest(index, _transform_from_signature(String(bone.get("local_rest_signature", ""))))
	return skeleton

func _transform_from_signature(signature: String) -> Transform3D:
	var fields := signature.split(",")
	assert(fields.size() == 12)
	var values := PackedFloat64Array()
	for field: String in fields:
		values.append(field.to_float())
	return Transform3D(
		Basis(
			Vector3(values[0], values[1], values[2]),
			Vector3(values[3], values[4], values[5]),
			Vector3(values[6], values[7], values[8])
		),
		Vector3(values[9], values[10], values[11])
	)

func _expected_serialization(candidate: Dictionary) -> String:
	var lines := PackedStringArray()
	for bone_value: Variant in candidate.get("bones", []):
		var bone := bone_value as Dictionary
		lines.append("%d|%s|%d|%s" % [
			int(bone.get("index", -1)),
			String(bone.get("name", "")),
			int(bone.get("parent_index", -1)),
			String(bone.get("local_rest_signature", "")),
		])
	return "\n".join(lines)
~~~

- [ ] **Step 3: Add body-rest identity RED assertions to mapped validation**

In tests/unit/test_production_humanoid_rig_mapping.gd:

1. Change SHA_A to remain the synthetic source hash.
2. Change _mapping() to set source_rest_signature to SHA_A so HumanoidRigMapping.validate() has a syntactically valid placeholder.
3. Add this helper:

~~~gdscript
func _bind_mapping_to_skeleton(mapping: Resource, skeleton: Skeleton3D) -> void:
	mapping.set(&"source_rest_signature", String(_contract.call(&"production_rest_signature", skeleton)))
~~~

4. Apply `_bind_mapping_to_skeleton()` at these exact points, always after the listed skeleton mutation and before `_skin_for()` or `validate_mapped_rig()`:

| Function/case | Mapping argument | Exact insertion state |
|---|---|---|
| _assert_superset_validation | mapping | immediately after `_superset_skeleton(mapping)` |
| _assert_numeric_bind_resolution | mapping | immediately after `_superset_skeleton(mapping)` |
| _assert_mapped_bone_and_hierarchy_failures, missing bone | missing_bone_mapping | after `_superset_skeleton(_mapping())`; the signature describes the live skeleton, not the semantic name map |
| _assert_mapped_bone_and_hierarchy_failures, wrong ancestor | mapping | after `set_bone_parent(child_index, wrong_parent_index)` |
| _assert_rest_and_skin_failures, non-finite rest | mapping | after `set_bone_rest(head_index, invalid_rest)` |
| _assert_rest_and_skin_failures, missing bind | mapping | immediately after the replacement `_superset_skeleton(mapping)` |
| _assert_rest_and_skin_failures, singular rest | mapping | construct Skin first while all rests are invertible, then set the head rest singular, then bind the mapping to that mutated skeleton before validation |
| _assert_rest_and_skin_failures, missing semantic bind | mapping | immediately after the replacement `_superset_skeleton(mapping)` |

The Skin-pose mutations do not change skeleton rest identity and require no second binding call. These exact insertions prevent a rest-identity error from masking each test's intended failure.

5. Add:

~~~gdscript
func _assert_source_rest_identity(failures: Array[String]) -> void:
	var mapping := _mapping()
	var skeleton := _superset_skeleton(mapping)
	_bind_mapping_to_skeleton(mapping, skeleton)
	var skin := _skin_for(skeleton, &"", false)
	TestAssertions.equal(
		_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, skin),
		PackedStringArray(),
		"matching mapped source rest signature validates",
		failures
	)
	mapping.set(&"source_rest_signature", SHA_A)
	TestAssertions.truthy(
		_contains(_contract.call(&"validate_mapped_rig", _definition, mapping, skeleton, skin), "source rest signature mismatch"),
		"wrong body-specific rest identity rejects",
		failures
	)
	skeleton.free()
~~~

Call _assert_source_rest_identity(failures) from run().

- [ ] **Step 4: Run the Task 2 RED suites**

Run:

~~~powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_production_humanoid_rest_signature.gd tests/unit/test_production_humanoid_rig_mapping.gd
~~~

Expected: nonzero exit and exactly one TEST_SUMMARY: FAIL marker. Failures must identify missing production rest serializer/signature and wrong body-specific rest identity rejection. Fixture loading and 52-bone reconstruction must succeed; parser/loader/script errors invalidate RED.

- [ ] **Step 5: Implement fixed-nine-decimal production rest serialization**

Add these exact static functions to scripts/presentation/humanoid_rig_contract.gd without modifying the legacy six-decimal _serialize_transform() used by canonical and named-Skin signatures:

~~~gdscript
static func production_rest_signature(skeleton: Skeleton3D) -> String:
	if skeleton == null:
		return ""
	return serialize_production_rest(skeleton).sha256_text()

static func serialize_production_rest(skeleton: Skeleton3D) -> String:
	if skeleton == null:
		return ""
	var lines := PackedStringArray()
	for bone_index: int in skeleton.get_bone_count():
		lines.append("%d|%s|%d|%s" % [
			bone_index,
			skeleton.get_bone_name(bone_index),
			skeleton.get_bone_parent(bone_index),
			_serialize_production_transform(skeleton.get_bone_rest(bone_index)),
		])
	return "\n".join(lines)

static func _serialize_production_transform(transform: Transform3D) -> String:
	return ",".join([
		"%.9f" % transform.basis.x.x,
		"%.9f" % transform.basis.x.y,
		"%.9f" % transform.basis.x.z,
		"%.9f" % transform.basis.y.x,
		"%.9f" % transform.basis.y.y,
		"%.9f" % transform.basis.y.z,
		"%.9f" % transform.basis.z.x,
		"%.9f" % transform.basis.z.y,
		"%.9f" % transform.basis.z.z,
		"%.9f" % transform.origin.x,
		"%.9f" % transform.origin.y,
		"%.9f" % transform.origin.z,
	])
~~~

Do not add a version header, field-length prefix, snappedf(), negative-zero normalization, or trailing newline; any of those changes the approved bytes.

- [ ] **Step 6: Enforce live rest identity and SHA-shaped mapping metadata**

In scripts/presentation/humanoid_rig_mapping.gd, replace:

~~~gdscript
	if source_rest_signature.is_empty():
		errors.append("humanoid rig mapping source rest signature is empty")
~~~

with:

~~~gdscript
	if not _is_sha256(source_rest_signature):
		errors.append("humanoid rig mapping source rest signature is invalid")
~~~

In validate_mapped_rig(), after the non-null skeleton and skin gates and before bind resolution, add:

~~~gdscript
	var actual_rest_signature := production_rest_signature(skeleton)
	if mapping.source_rest_signature != actual_rest_signature:
		errors.append(
			"mapped humanoid source rest signature mismatch; expected %s, got %s"
			% [mapping.source_rest_signature, actual_rest_signature]
		)
~~~

The source_skeleton_sha256 remains provenance metadata because a live Skeleton3D cannot reproduce the complete GLB byte hash.

- [ ] **Step 7: Run Task 2 GREEN and all rig regressions**

Run the Step 4 command. Expected: exit 0 and exactly one TEST_SUMMARY: PASS (0 failures).

Then run:

~~~powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_production_humanoid_rest_signature.gd tests/unit/test_production_humanoid_rig_mapping.gd tests/unit/test_humanoid_rig_contract.gd tests/unit/test_skinned_equipment_binding.gd tests/unit/test_body_region_visibility.gd
~~~

Expected: exit 0, exactly one terminal TEST_SUMMARY: PASS (0 failures), and no prohibited diagnostics.

- [ ] **Step 8: Audit Task 2 diff and commit**

Run git diff --check. Require only these five paths relative to Task 1 HEAD:

~~~text
scripts/presentation/humanoid_rig_contract.gd
scripts/presentation/humanoid_rig_mapping.gd
tests/fixtures/presentation/production_rig_inspection_rest_fixtures.json
tests/unit/test_production_humanoid_rest_signature.gd
tests/unit/test_production_humanoid_rig_mapping.gd
~~~

Rehash the 77 protected untracked files, confirm neither GLB hash changed, and confirm no mapping .tres exists. Commit:

~~~powershell
git add scripts/presentation/humanoid_rig_contract.gd scripts/presentation/humanoid_rig_mapping.gd tests/fixtures/presentation/production_rig_inspection_rest_fixtures.json tests/unit/test_production_humanoid_rest_signature.gd tests/unit/test_production_humanoid_rig_mapping.gd
git commit -m "feat: verify body-specific production rig identity"
~~~

Verify the exact five-file commit and preserve its hash.

---

### Task 3: Resolve Exact Body-Specific Mapping Identities Without Production Resources

**Files:**
- Create: scripts/presentation/humanoid_rig_mapping_catalog.gd
- Create: tests/unit/test_humanoid_rig_mapping_catalog.gd

**Interfaces:**
- Consumes: HumanoidRigMapping fields mapping_id, canonical_rig_id, source_skeleton_sha256, and source_rest_signature.
- Produces: stateless HumanoidRigMappingCatalog._init(mapping_by_body_preset) and its sole exposed selection operation resolve(body_preset_id). Identity checks remain a private helper. The catalog stores future resource paths as strings but never loads them during this checkpoint.

- [ ] **Step 1: Write the complete catalog RED suite**

Create tests/unit/test_humanoid_rig_mapping_catalog.gd:

~~~gdscript
extends RefCounted

const CATALOG_PATH := "res://scripts/presentation/humanoid_rig_mapping_catalog.gd"
const MAPPING_PATH := "res://scripts/presentation/humanoid_rig_mapping.gd"
const MASCULINE_ID := &"pf_humanoid_v1_mixamo52_masculine"
const FEMININE_ID := &"pf_humanoid_v1_mixamo52_feminine"
const MASCULINE_SHA := "8f589e35f16f02fe4aa0f45b5f2c85377a41f9ecc188670bf59159518e6cdbe4"
const FEMININE_SHA := "173198e3d044418b9765971e8b698664176c05dadd6a5aaa4ddb8df8d4c08667"
const MASCULINE_REST := "1ea73d190881c437d8ca6fc10dd7c4f446d2d14523416bcd0731264dad689eda"
const FEMININE_REST := "fad7e1860ef45781179d156654734b6160a7d97df96be43d3eb8c0bc51ea5c85"

var _catalog_script: Script
var _mapping_script: Script

func run() -> Array[String]:
	var failures: Array[String] = []
	_catalog_script = load(CATALOG_PATH) as Script
	_mapping_script = load(MAPPING_PATH) as Script
	TestAssertions.truthy(_catalog_script != null, "body-specific mapping catalog loads", failures)
	TestAssertions.truthy(_mapping_script != null, "mapping resource script loads", failures)
	if _catalog_script == null or _mapping_script == null:
		return failures
	var masculine := _mapping(MASCULINE_ID, MASCULINE_SHA, MASCULINE_REST)
	var feminine := _mapping(FEMININE_ID, FEMININE_SHA, FEMININE_REST)
	var injected := {&"masculine": masculine, &"feminine": feminine}
	var catalog := _catalog_script.new(injected) as RefCounted

	TestAssertions.equal(catalog.call(&"resolve", &"masculine"), masculine, "masculine resolves only its exact injected mapping", failures)
	TestAssertions.equal(catalog.call(&"resolve", &"feminine"), feminine, "feminine resolves only its exact injected mapping", failures)

	var active_mapping := masculine
	active_mapping = _activate_if_resolved(catalog, &"unknown", active_mapping)
	TestAssertions.equal(active_mapping, masculine, "failed unknown selection leaves active mapping unchanged", failures)

	var crossed_catalog := _catalog_script.new({&"masculine": feminine, &"feminine": masculine}) as RefCounted
	active_mapping = _activate_if_resolved(crossed_catalog, &"masculine", active_mapping)
	TestAssertions.equal(active_mapping, masculine, "failed cross-body masculine selection leaves active mapping unchanged", failures)
	TestAssertions.equal(crossed_catalog.call(&"resolve", &"feminine"), null, "cross-body feminine selection fails", failures)

	var wrong_canonical := _mapping(MASCULINE_ID, MASCULINE_SHA, MASCULINE_REST)
	wrong_canonical.set(&"canonical_rig_id", &"wrong")
	var wrong_canonical_catalog := _catalog_script.new({&"masculine": wrong_canonical}) as RefCounted
	TestAssertions.equal(wrong_canonical_catalog.call(&"resolve", &"masculine"), null, "wrong canonical identity rejects", failures)

	var wrong_id := _mapping(&"wrong", MASCULINE_SHA, MASCULINE_REST)
	var wrong_id_catalog := _catalog_script.new({&"masculine": wrong_id}) as RefCounted
	TestAssertions.equal(wrong_id_catalog.call(&"resolve", &"masculine"), null, "wrong mapping id rejects", failures)

	var wrong_source := _mapping(MASCULINE_ID, FEMININE_SHA, MASCULINE_REST)
	var wrong_source_catalog := _catalog_script.new({&"masculine": wrong_source}) as RefCounted
	TestAssertions.equal(wrong_source_catalog.call(&"resolve", &"masculine"), null, "wrong source hash rejects", failures)

	var wrong_rest := _mapping(MASCULINE_ID, MASCULINE_SHA, FEMININE_REST)
	var wrong_rest_catalog := _catalog_script.new({&"masculine": wrong_rest}) as RefCounted
	TestAssertions.equal(wrong_rest_catalog.call(&"resolve", &"masculine"), null, "wrong source rest signature rejects", failures)

	injected[&"masculine"] = feminine
	TestAssertions.equal(catalog.call(&"resolve", &"masculine"), masculine, "constructor duplicates injected dictionary", failures)

	var script_constants := _catalog_script.get_script_constant_map()
	var resource_paths := script_constants.get("RESOURCE_PATH_BY_BODY_PRESET", {}) as Dictionary
	TestAssertions.equal(
		resource_paths.get(&"masculine"),
		"res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres",
		"masculine future resource path is exact",
		failures
	)
	TestAssertions.equal(
		resource_paths.get(&"feminine"),
		"res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres",
		"feminine future resource path is exact",
		failures
	)
	return failures

func _mapping(mapping_id: StringName, source_sha: String, rest_signature: String) -> Resource:
	var mapping := _mapping_script.new() as Resource
	mapping.set(&"mapping_id", mapping_id)
	mapping.set(&"canonical_rig_id", &"pf_humanoid_v1")
	mapping.set(&"source_skeleton_sha256", source_sha)
	mapping.set(&"source_rest_signature", rest_signature)
	return mapping

func _activate_if_resolved(catalog: RefCounted, body_preset_id: StringName, active_mapping: Resource) -> Resource:
	var resolved := catalog.call(&"resolve", body_preset_id) as Resource
	return resolved if resolved != null else active_mapping
~~~

- [ ] **Step 2: Run the catalog RED suite**

Run:

~~~powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_humanoid_rig_mapping_catalog.gd
~~~

Expected: nonzero exit and exactly one TEST_SUMMARY: FAIL marker because humanoid_rig_mapping_catalog.gd does not exist. The mapping script must load; any unrelated parser/import failure invalidates RED.

- [ ] **Step 3: Implement the stateless injectable catalog**

Create scripts/presentation/humanoid_rig_mapping_catalog.gd with exactly:

~~~gdscript
class_name HumanoidRigMappingCatalog
extends RefCounted

const BODY_PRESETS: Array[StringName] = [&"masculine", &"feminine"]
const MAPPING_ID_BY_BODY_PRESET := {
	&"masculine": &"pf_humanoid_v1_mixamo52_masculine",
	&"feminine": &"pf_humanoid_v1_mixamo52_feminine",
}
const SOURCE_SHA256_BY_BODY_PRESET := {
	&"masculine": "8f589e35f16f02fe4aa0f45b5f2c85377a41f9ecc188670bf59159518e6cdbe4",
	&"feminine": "173198e3d044418b9765971e8b698664176c05dadd6a5aaa4ddb8df8d4c08667",
}
const REST_SIGNATURE_BY_BODY_PRESET := {
	&"masculine": "1ea73d190881c437d8ca6fc10dd7c4f446d2d14523416bcd0731264dad689eda",
	&"feminine": "fad7e1860ef45781179d156654734b6160a7d97df96be43d3eb8c0bc51ea5c85",
}
const RESOURCE_PATH_BY_BODY_PRESET := {
	&"masculine": "res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres",
	&"feminine": "res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres",
}

var _mapping_by_body_preset: Dictionary

func _init(mapping_by_body_preset: Dictionary = {}) -> void:
	_mapping_by_body_preset = mapping_by_body_preset.duplicate()

func resolve(body_preset_id: StringName) -> HumanoidRigMapping:
	var value: Variant = _mapping_by_body_preset.get(body_preset_id)
	if not value is HumanoidRigMapping:
		return null
	var mapping := value as HumanoidRigMapping
	if not _identity_errors(body_preset_id, mapping).is_empty():
		return null
	return mapping

func _identity_errors(
		body_preset_id: StringName,
		mapping: HumanoidRigMapping
	) -> PackedStringArray:
	var errors := PackedStringArray()
	if body_preset_id not in BODY_PRESETS:
		errors.append("humanoid rig mapping catalog body preset %s is invalid" % body_preset_id)
		return errors
	if mapping == null:
		errors.append("humanoid rig mapping catalog body preset %s mapping is missing" % body_preset_id)
		return errors
	if mapping.mapping_id != MAPPING_ID_BY_BODY_PRESET[body_preset_id]:
		errors.append(
			"humanoid rig mapping catalog body preset %s mapping id must be %s"
			% [body_preset_id, MAPPING_ID_BY_BODY_PRESET[body_preset_id]]
		)
	if mapping.canonical_rig_id != HumanoidRigContract.CANONICAL_RIG_ID:
		errors.append(
			"humanoid rig mapping catalog body preset %s canonical rig id must be %s"
			% [body_preset_id, HumanoidRigContract.CANONICAL_RIG_ID]
		)
	if mapping.source_skeleton_sha256 != SOURCE_SHA256_BY_BODY_PRESET[body_preset_id]:
		errors.append(
			"humanoid rig mapping catalog body preset %s source skeleton hash must be %s"
			% [body_preset_id, SOURCE_SHA256_BY_BODY_PRESET[body_preset_id]]
		)
	if mapping.source_rest_signature != REST_SIGNATURE_BY_BODY_PRESET[body_preset_id]:
		errors.append(
			"humanoid rig mapping catalog body preset %s source rest signature must be %s"
			% [body_preset_id, REST_SIGNATURE_BY_BODY_PRESET[body_preset_id]]
		)
	return errors
~~~

The catalog exposes only resolve(), stores no active selection, does not touch ForgeHumanoidModel, and never loads RESOURCE_PATH_BY_BODY_PRESET in this checkpoint. `_identity_errors()` is private implementation detail. A caller can replace an active visual only after resolve() returns a non-null mapping; the test helper proves failed resolution preserves the caller's prior active mapping.

- [ ] **Step 4: Run catalog GREEN and combined focused regressions**

Run the Step 2 command. Expected: exit 0 and exactly one TEST_SUMMARY: PASS (0 failures).

Then run:

~~~powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_humanoid_rig_mapping_catalog.gd tests/unit/test_production_humanoid_rest_signature.gd tests/unit/test_production_humanoid_rig_mapping.gd tests/unit/test_humanoid_rig_contract.gd tests/unit/test_skinned_equipment_binding.gd tests/unit/test_body_region_visibility.gd
~~~

Expected: exit 0, exactly one terminal TEST_SUMMARY: PASS (0 failures), no prohibited diagnostics.

- [ ] **Step 5: Audit Task 3 diff and commit**

Run git diff --check. Require exactly:

~~~text
scripts/presentation/humanoid_rig_mapping_catalog.gd
tests/unit/test_humanoid_rig_mapping_catalog.gd
~~~

Rehash the 77 protected untracked files and confirm all three forbidden mapping-resource paths remain absent. Commit:

~~~powershell
git add scripts/presentation/humanoid_rig_mapping_catalog.gd tests/unit/test_humanoid_rig_mapping_catalog.gd
git commit -m "feat: resolve body-specific humanoid rig mappings"
~~~

Verify the exact two-file commit and preserve its hash.

---

### Task 4: Qualify the Contract Checkpoint in a Fresh Tracked-Only Project

This plan's Task 4 is verification-only and is unrelated to the original production-character plan's prohibited Task 4 body-derivative work.

**Files:**
- No tracked files created or modified.
- Read-only audit scope: all eight tracked paths listed in the File Responsibility Map.

**Interfaces:**
- Consumes: the three independently committed Task 1-3 deliverables.
- Produces: verification evidence and a stop-gate report only; it does not create a repository artifact, mapping resource, asset, import, or integration commit.

- [ ] **Step 1: Re-run the complete focused checkpoint gate**

Run:

~~~powershell
& $godot --headless --path $project --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_humanoid_rig_mapping_catalog.gd tests/unit/test_production_humanoid_rest_signature.gd tests/unit/test_production_humanoid_rig_mapping.gd tests/unit/test_humanoid_rig_contract.gd tests/unit/test_skinned_equipment_binding.gd tests/unit/test_body_region_visibility.gd
~~~

Require exit 0, exactly one terminal TEST_SUMMARY: PASS (0 failures), stderr free of parser/loader/import/script/crash/segmentation/leak diagnostics, and git diff --check exit 0.

- [ ] **Step 2: Create a fresh tracked-only verification copy outside every repository**

Run exactly once, without deleting it afterward:

~~~powershell
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$suffix = [guid]::NewGuid().ToString('N').Substring(0,8)
$verifyRoot = "C:\Users\Jacob\AppData\Local\Temp\pf-body-rig-contract-$stamp-$suffix"
$trackedProject = Join-Path $verifyRoot 'project'
$archive = Join-Path $verifyRoot 'tracked.zip'
New-Item -ItemType Directory -Path $trackedProject -Force | Out-Null
git archive --format=zip HEAD -o $archive
Expand-Archive -LiteralPath $archive -DestinationPath $trackedProject
New-Item -ItemType Directory -Path (Join-Path $verifyRoot 'appdata') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $verifyRoot 'localappdata') -Force | Out-Null
~~~

Prove the copy is tracked-only by requiring that neither of these original untracked files exists in it:

~~~text
docs/superpowers/plans/2026-08-31-production-character-equipment-replacement.md
scripts/presentation/character_head_visual_definition.gd.uid
~~~

Also require the eight planned tracked paths to exist and all three mapping .tres paths to be absent.

- [ ] **Step 3: Run the full suite directly in the fresh tracked-only copy**

Run:

~~~powershell
$priorAppData = $env:APPDATA
$priorLocalAppData = $env:LOCALAPPDATA
$env:APPDATA = Join-Path $verifyRoot 'appdata'
$env:LOCALAPPDATA = Join-Path $verifyRoot 'localappdata'
try {
    & $godot --headless --path $trackedProject --script res://tests/test_runner.gd
    $fullExit = $LASTEXITCODE
} finally {
    $env:APPDATA = $priorAppData
    $env:LOCALAPPDATA = $priorLocalAppData
}
if ($fullExit -ne 0) { exit $fullExit }
~~~

Require full-suite exit 0 and exactly one terminal marker matching TEST_SUMMARY: PASS followed by one positive suite count. Reject any parser, loader, import, script, crash, segmentation, or leak diagnostic even if the process exits 0. This command deliberately omits `--editor --import`; if the tracked-only run cannot proceed without an explicit Godot asset-import operation, stop and return that as a blocked verification gate rather than expanding this plan.

- [ ] **Step 4: Obtain independent requirements review**

Invoke the requesting-code-review skill and give a fresh reviewer this exact scope:

~~~text
Compare commits after implementationBase ($implementationBase, recorded at
$baselineEvidencePath) to
docs/superpowers/specs/2026-09-01-body-specific-production-rig-mapping-amendment-design.md.
Check every numeric-bind rule, legacy-validator containment, fixed-nine-decimal
rest byte contract, both approved source/rest identities, catalog selection,
no-active-mutation behavior, forbidden .tres absence, and original-plan
non-modification. Return PASS only if every requirement maps to code plus a
trustworthy test; otherwise return FAIL with exact file/line evidence.
Do not edit files.
~~~

If the reviewer returns FAIL or cannot provide file/line evidence, stop and report the finding to Jacob. Do not auto-fix or broaden scope.

- [ ] **Step 5: Obtain independent code-quality review**

Use a different fresh reviewer with this exact scope:

~~~text
Review the same post-implementationBase implementation ($implementationBase,
recorded at $baselineEvidencePath) for deterministic error order,
Godot Skin/Skeleton3D API correctness, duplicate/out-of-range coverage,
name/index precedence, finite/invertible validation, exact serialization bytes,
type/signature consistency, stateless catalog behavior, test isolation, and
legacy regression risk. Return PASS or FAIL with exact file/line evidence.
Do not edit files and do not repeat the requirements review.
~~~

Any FAIL stops the checkpoint. No unplanned corrective commit is authorized by this plan.

- [ ] **Step 6: Audit exact commits and tracked scope**

Require fbc3f9e8c3d9853ffbf8d3c21944f970ac41231b to remain an ancestor of implementationBase. Then require exactly three first-parent commits after implementationBase, in this order:

~~~text
feat: accept complete numeric production skin binds
feat: verify body-specific production rig identity
feat: resolve body-specific humanoid rig mappings
~~~

Require the union of changed paths to be exactly:

~~~text
scripts/presentation/humanoid_rig_contract.gd
scripts/presentation/humanoid_rig_mapping.gd
scripts/presentation/humanoid_rig_mapping_catalog.gd
tests/fixtures/presentation/production_rig_inspection_rest_fixtures.json
tests/unit/test_humanoid_rig_contract.gd
tests/unit/test_humanoid_rig_mapping_catalog.gd
tests/unit/test_production_humanoid_rest_signature.gd
tests/unit/test_production_humanoid_rig_mapping.gd
~~~

Require tracked worktree and index clean, `git diff $implementationBase..HEAD --check` exit 0, the changed-path union from `git diff --name-only $implementationBase..HEAD` to equal the eight paths above, and no merge commit. The approved-design ancestor remains provenance only and is not used as the implementation scope base.

- [ ] **Step 7: Revalidate containment and immutable provenance**

Rehash all 77 preserved untracked files against the existing manifest and require zero missing, added-to-baseline, size, or SHA mismatches. Rehash both immutable GLBs and require their exact Global Constraints hashes. Require:

- main and origin/main remain at the pre-execution values unless Jacob separately approved reconciliation;
- Dawn Bulwark retains its exact pre-execution three modifications;
- the Combat HUD worktree was never used as a write target;
- docs/superpowers/plans/2026-08-31-production-character-equipment-replacement.md remains byte-identical to the preserved manifest;
- the shared, masculine, and feminine mapping .tres files are absent;
- data/presentation/manifests/pf_character_equipment_v2.json and docs/qa/character-model-replacement/body-pair-qualification.md are absent;
- no Task 4, import, asset, Blender, geometry, head, armor, or gameplay-integration path changed.

- [ ] **Step 8: Stop for Jacob's contract-checkpoint approval**

Report branch, worktree, three commit hashes/parents/subjects, exact eight-path union, RED/GREEN evidence, focused and full-suite markers/exits, two independent review results, fixture provenance, immutable hashes, 77-file containment, protected-worktree drift, and absent sentinels.

Do not create another commit. Do not merge or push. Ask Jacob to approve or reject the verified pre-resource contract checkpoint.

---

## Later Two-Resource Write Gate — Explicitly Not Executed by This Plan

Only after Jacob approves Task 4's contract checkpoint may a new plan authorize these exact writes:

| Path | mapping_id | source_skeleton_sha256 | source_rest_signature |
|---|---|---|---|
| data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres | pf_humanoid_v1_mixamo52_masculine | 8f589e35f16f02fe4aa0f45b5f2c85377a41f9ecc188670bf59159518e6cdbe4 | 1ea73d190881c437d8ca6fc10dd7c4f446d2d14523416bcd0731264dad689eda |
| data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres | pf_humanoid_v1_mixamo52_feminine | 173198e3d044418b9765971e8b698664176c05dadd6a5aaa4ddb8df8d4c08667 | fad7e1860ef45781179d156654734b6160a7d97df96be43d3eb8c0bc51ea5c85 |

Both later resources must set canonical_rig_id = pf_humanoid_v1 and use the exact 19-role mapping in this plan. The later plan must first reconcile every singular pf_humanoid_v1_mixamo52.tres reference in docs/superpowers/plans/2026-08-31-production-character-equipment-replacement.md through an explicitly approved documentation change. It must then validate each resource against its own immutable candidate. It may not create a shared resource, mutate a GLB, normalize rests, or begin Task 4 automatically.

## Rollback

- Task 1 rollback: revert only feat: accept complete numeric production skin binds; this restores named-only validate_mapped_rig() while leaving both legacy validators unchanged.
- Task 2 rollback: revert only feat: verify body-specific production rig identity; this removes the fixture, full-skeleton rest serializer, live rest comparison, and SHA-shaped rest metadata while preserving Task 1.
- Task 3 rollback: revert only feat: resolve body-specific humanoid rig mappings; this removes the stateless catalog and its tests while preserving Tasks 1-2.
- If Task 4 verification or either independent review fails, do not rewrite history, delete evidence, or auto-revert. Stop with the exact failing commit and evidence so Jacob can authorize a bounded correction or rollback.
- No rollback operation touches the immutable GLBs or the 77 protected untracked files.
