# Body-Specific Production Rig Resource Write Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the exact masculine and feminine `HumanoidRigMapping` resources approved by inspection, prove each resource against its immutable 52-bone body candidate, and stop before presentation integration or body qualification.

**Architecture:** The existing stateless `HumanoidRigMappingCatalog` already selects one exact repository-relative path per body preset. This checkpoint makes those two leaf resources real without changing catalog, validator, gameplay, or presentation code. A guarded resource-existence RED precedes both writes; fixture-backed public validation then proves the resource bytes carry the approved identity, semantic mapping, source hash, and body-specific rest signature.

**Tech Stack:** Godot 4.7.1 stable mono, GDScript, Godot text resources (`.tres`), PowerShell, Git, SHA-256 evidence, the existing focused test runner, and the qualified asynchronous process controller/cold-import verification workflow.

## Global Constraints

- Execute only in `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\class-preview-character-model-replacement` on `feat/class-preview-character-model-replacement`; never use authoritative `main` as the write worktree.
- Treat merge commit `5d75bac729fe5a6b4a6e952a1b7dee36a3c28549` as the published contract-checkpoint provenance ancestor. Capture the approved plan commit at execution start as dynamic `resourceWriteBase`; do not encode a self-referential hash in this document.
- Create exactly two mapping resources: `data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres` and `data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres`.
- Never create `data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52.tres`; there is no shared or cross-body fallback.
- Preserve the immutable masculine GLB at SHA-256 `8f589e35f16f02fe4aa0f45b5f2c85377a41f9ecc188670bf59159518e6cdbe4` and the immutable feminine GLB at SHA-256 `173198e3d044418b9765971e8b698664176c05dadd6a5aaa4ddb8df8d4c08667` before and after every write/test gate.
- Preserve `tests/fixtures/presentation/production_rig_inspection_rest_fixtures.json` byte-for-byte at SHA-256 `a0ca9b54b9ea158c4c970cbd36121bfc89fd06d7ed2cff054c032f8e8c21f811`.
- Preserve the distinct approved rest identities: masculine `1ea73d190881c437d8ca6fc10dd7c4f446d2d14523416bcd0731264dad689eda`; feminine `fad7e1860ef45781179d156654734b6160a7d97df96be43d3eb8c0bc51ea5c85`.
- Both resources use canonical rig ID `pf_humanoid_v1` and the same exact 19-role mapping defined below; neither resource may normalize, rewrite, or combine the two native rest poses.
- Do not modify `HumanoidRigContract`, `HumanoidRigMapping`, `HumanoidRigMappingCatalog`, `HumanoidRigMappingLoader`, or `HumanoidRigMappingResolution`; the published pre-resource contract is the consumer of these resources.
- Preserve strict legacy `validate_rig()` and `validate_skin()` behavior. Resource qualification uses public `validate_mapped_rig()` with complete unnamed numeric binds and proves both legacy validators still reject that 52-bone superset.
- `PF_RIG_FACTORY_CONTRACT_PROBE` must be absent before every Godot process. Never rerun `invalid_success`, `invalid_failure`, or `invalid_direct_constructor` probes.
- Keep all evidence and disposable projects under fresh task-owned directories in `C:\Users\Jacob\AppData\Local\Temp`; do not write import/cache evidence into any repository, worktree, or immutable staging directory.
- The authoritative worktree, Dawn Bulwark worktree, Combat HUD worktree, immutable staging inputs, and every preserved evidence root are read-only boundaries. Concurrent non-overlapping Combat HUD drift is recorded, never targeted.
- Do not import either GLB into Party Forge, run Blender or 3D Gen Studio, download assets, modify geometry/rig/weights/UV/materials/textures, qualify body derivatives, create heads/armor/equipment, or begin presentation integration.
- Do not fetch, merge, rebase, push, clean, delete, publish, or integrate this checkpoint. The terminal state is a verified local resource commit awaiting Studio Lead review.
- Stop without retry or improvisation on an untrustworthy RED, parser/loader/import/script/crash/leak diagnostic, unknown generated path, protected hash drift, scope drift, review FAIL, or ambiguous instruction.

---

## File Responsibility Map

- `docs/superpowers/plans/2026-08-31-production-character-equipment-replacement.md` — reconcile exactly four obsolete singular mapping-resource references with the approved two-resource architecture. It is currently one of the 77 protected untracked records, so execution requires an explicit provenance commit and a deterministic 77-to-76 protected-inventory transition.
- `data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres` — immutable identity and 19-role mapping for the inspected masculine production candidate.
- `data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres` — immutable identity and 19-role mapping for the inspected feminine production candidate.
- `tests/unit/test_humanoid_rig_mapping_catalog.gd` — guarded missing-resource RED and exact default `ResourceLoader` success proof for both body-specific paths; injected loader, statelessness, cross-body rejection, and failure-matrix tests remain unchanged.
- `tests/unit/test_production_humanoid_rest_signature.gd` — load each real mapping resource and validate it end to end against the corresponding path-free 52-bone rest fixture and complete unnamed numeric `Skin`.
- `tests/fixtures/presentation/production_rig_inspection_rest_fixtures.json` — read-only reconstruction input; never modified.

## Exact Resource Contract

| Body preset | Resource path | Mapping ID | Source GLB SHA-256 | Rest signature |
|---|---|---|---|---|
| `masculine` | `res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres` | `pf_humanoid_v1_mixamo52_masculine` | `8f589e35f16f02fe4aa0f45b5f2c85377a41f9ecc188670bf59159518e6cdbe4` | `1ea73d190881c437d8ca6fc10dd7c4f446d2d14523416bcd0731264dad689eda` |
| `feminine` | `res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres` | `pf_humanoid_v1_mixamo52_feminine` | `173198e3d044418b9765971e8b698664176c05dadd6a5aaa4ddb8df8d4c08667` | `fad7e1860ef45781179d156654734b6160a7d97df96be43d3eb8c0bc51ea5c85` |

Both resources set `canonical_rig_id = &"pf_humanoid_v1"` and this exact mapping:

```gdscript
const ROLE_TO_BONE := {
	&"hips": &"mixamorig_Hips",
	&"spine": &"mixamorig_Spine",
	&"chest": &"mixamorig_Spine2",
	&"neck": &"mixamorig_Neck",
	&"head": &"mixamorig_Head",
	&"upper_arm_left": &"mixamorig_LeftArm",
	&"lower_arm_left": &"mixamorig_LeftForeArm",
	&"hand_left": &"mixamorig_LeftHand",
	&"upper_arm_right": &"mixamorig_RightArm",
	&"lower_arm_right": &"mixamorig_RightForeArm",
	&"hand_right": &"mixamorig_RightHand",
	&"upper_leg_left": &"mixamorig_LeftUpLeg",
	&"lower_leg_left": &"mixamorig_LeftLeg",
	&"foot_left": &"mixamorig_LeftFoot",
	&"toe_left": &"mixamorig_LeftToeBase",
	&"upper_leg_right": &"mixamorig_RightUpLeg",
	&"lower_leg_right": &"mixamorig_RightLeg",
	&"foot_right": &"mixamorig_RightFoot",
	&"toe_right": &"mixamorig_RightToeBase",
}
```

## Task 0: Capture the Execution Baseline and Reconcile Singular Documentation

**Files:**
- Modify and begin tracking: `docs/superpowers/plans/2026-08-31-production-character-equipment-replacement.md`
- Evidence only: fresh `C:\Users\Jacob\AppData\Local\Temp\pf-rig-resource-write-*`

**Interfaces:**
- Consumes: published merge ancestor `5d75bac729fe5a6b4a6e952a1b7dee36a3c28549`, the approved two-resource design, the current 77-record protected manifest, and this committed plan.
- Produces: dynamic `resourceWriteBase`, one documentation-only reconciliation commit, and a new 76-record protected manifest containing every previously protected path except the now-tracked original plan.

- [ ] **Step 1: Capture a clean dynamic execution baseline**

In a fresh TEMP evidence root, record `git rev-parse HEAD` as `resourceWriteBase`. Require:

```powershell
$project = 'F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\class-preview-character-model-replacement'
$publishedCheckpoint = '5d75bac729fe5a6b4a6e952a1b7dee36a3c28549'
$resourceWriteBase = (git -C $project rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'cannot resolve resourceWriteBase' }
git -C $project merge-base --is-ancestor $publishedCheckpoint $resourceWriteBase
if ($LASTEXITCODE -ne 0) { throw 'published checkpoint is not an ancestor of resourceWriteBase' }
if (-not [string]::IsNullOrEmpty((git -C $project status --porcelain=v1 --untracked-files=no))) {
    throw 'tracked worktree or index is not clean'
}
```

Also require local `main`, `refs/remotes/origin/main`, and live `refs/heads/main` to equal `5d75bac729fe5a6b4a6e952a1b7dee36a3c28549`; the branch to be `feat/class-preview-character-model-replacement`; all 77 protected records to match manifest SHA-256 `9f7d8b800e27f94d2bc1f7798a88c9bda73c65d0429c3c072bbe00daeafbe2bd`; the original untracked plan to match SHA-256 `047dc28ce0c851227b80f9f63ec9abd2a0b060fd144a0041e03a1748ceedb00d`; the approved body-specific design to match SHA-256 `e8a9eba54b410cecd98161cfa2f3032fa9390a697e6a286995e1c394f28e2c87`; the approved pre-resource contract plan to match SHA-256 `c7f179ba3c90ef974f1f04afed3afdd388e5bc5d62f455e3bb68ab9a21463440`; the fixture and both GLBs to match Global Constraints; the three mapping-resource paths to be absent; the probe to be absent; and Dawn Bulwark/Combat HUD to remain separate. Write these facts and hashes to canonical JSON before editing.

- [ ] **Step 2: Replace exactly four singular references**

Apply exactly these documentation replacements in `docs/superpowers/plans/2026-08-31-production-character-equipment-replacement.md`:

```markdown
# Replace the single file-responsibility bullet with these two bullets:
- `data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres`: source/runtime mapping for the exact inspected masculine production skeleton.
- `data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres`: source/runtime mapping for the exact inspected feminine production skeleton.

# Replace the single later-create bullet with these two bullets:
- Later create after the body-specific mapping-resource gate: `data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres`
- Later create after the body-specific mapping-resource gate: `data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres`

# Replace the singular approval paragraph with this paragraph:
Before generating either body-specific mapping resource, require Studio Lead approval under Jacob's delegated routine-gate authority for the exact two-resource write. The inspected source rigs contain 52 Mixamo bones, and each mapping resource must use the exact approved bone names, hierarchy, rests, Skin-bind behavior, source GLB SHA-256, and body-specific rest signature. Never guess from generic Mixamo conventions, combine the bodies into one resource, or normalize their distinct native rests.

# Replace the single Task 7 create bullet with these two bullets:
- Create: `data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres`
- Create: `data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres`
```

Do not change any other sentence, file, or protected record.

- [ ] **Step 3: Audit the reconciliation and protected-inventory transition**

Run:

```powershell
$singular = @(rg -n --fixed-strings 'pf_humanoid_v1_mixamo52.tres' "$project\docs\superpowers\plans\2026-08-31-production-character-equipment-replacement.md")
$singularExit = $LASTEXITCODE
if ($singularExit -notin 0, 1) { throw "rg failed with exit $singularExit" }
if ($singular.Count -ne 0) { throw 'obsolete singular mapping-resource reference remains' }
```

Require the path to be the sole task-owned change, its pre-edit hash to match the Task 0 evidence, and the other 76 protected untracked records to remain byte-identical. Generate a no-index diff between the preserved pre-edit copy and the live file for exact review; the staged `git diff --cached --check` in Step 4 is the authoritative whitespace gate because this path is not tracked before staging. Generate a new canonical 76-record manifest and record the exact removed-from-untracked path; do not describe it as deleted.

- [ ] **Step 4: Commit only the reconciled original plan**

```powershell
git -C $project add -- docs/superpowers/plans/2026-08-31-production-character-equipment-replacement.md
git -C $project diff --cached --check
git -C $project commit -m 'docs: reconcile body-specific rig resource paths'
```

Expected: one commit whose parent is `resourceWriteBase`, whose only path is `docs/superpowers/plans/2026-08-31-production-character-equipment-replacement.md`, and whose subject is exact. Require tracked/index clean and exactly 76 remaining protected untracked records matching the new manifest. Stop for Studio Lead review before Task 1; this documentation transition is consequential because it begins tracking a formerly protected plan.

## Task 1: Write and Qualify Both Body-Specific Mapping Resources

**Files:**
- Create: `data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres`
- Create: `data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres`
- Modify: `tests/unit/test_humanoid_rig_mapping_catalog.gd`
- Modify: `tests/unit/test_production_humanoid_rest_signature.gd`

**Interfaces:**
- Consumes: `HumanoidRigMapping` exported properties; `HumanoidRigMappingCatalog.resolve(body_preset_id: StringName, loader: MappingLoader = null) -> RefCounted`; `HumanoidRigContract.validate_mapped_rig(definition, mapping, skeleton, skin) -> PackedStringArray`; the immutable two-candidate fixture.
- Produces: two loadable `HumanoidRigMapping` resources selected by the existing catalog, with no shared resource or production-code change.

- [ ] **Step 1: Add a guarded two-resource existence RED**

In `tests/unit/test_humanoid_rig_mapping_catalog.gd`, immediately after the catalog and mapping scripts load successfully and before any catalog behavior assertion, add:

```gdscript
	var masculine_resource_exists := ResourceLoader.exists(MASCULINE_PATH)
	var feminine_resource_exists := ResourceLoader.exists(FEMININE_PATH)
	TestAssertions.truthy(masculine_resource_exists, "masculine production mapping resource exists", failures)
	TestAssertions.truthy(feminine_resource_exists, "feminine production mapping resource exists", failures)
	if not masculine_resource_exists or not feminine_resource_exists:
		return failures
```

Do not call `load()` while either path is absent. Do not edit either resource path, any production script, or the rest-signature test before RED.

- [ ] **Step 2: Run the catalog RED once**

Run with `PF_RIG_FACTORY_CONTRACT_PROBE` absent:

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_humanoid_rig_mapping_catalog.gd
```

Trustworthy RED requires native nonzero exit, exactly one terminal `TEST_SUMMARY: FAIL (2 failures)`, exactly these failures in order, and zero parser/loader/import/script-compile/crash/fatal/segmentation/object-leak/RID-leak diagnostics:

```text
masculine production mapping resource exists
feminine production mapping resource exists
```

The guard must return before `ResourceLoader.load`, so a loader diagnostic makes this RED untrustworthy. Preserve command, environment, stdout, stderr, native exit, marker scan, test hash, absent resource proof, fixture/GLB hashes, and containment in TEMP. Stop without writing resources if any trust condition differs.

- [ ] **Step 3: Create the masculine resource exactly**

Create `data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres` with exactly:

```text
[gd_resource type="Resource" script_class="HumanoidRigMapping" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/presentation/humanoid_rig_mapping.gd" id="1"]

[resource]
script = ExtResource("1")
mapping_id = &"pf_humanoid_v1_mixamo52_masculine"
canonical_rig_id = &"pf_humanoid_v1"
role_to_bone = {
&"hips": &"mixamorig_Hips",
&"spine": &"mixamorig_Spine",
&"chest": &"mixamorig_Spine2",
&"neck": &"mixamorig_Neck",
&"head": &"mixamorig_Head",
&"upper_arm_left": &"mixamorig_LeftArm",
&"lower_arm_left": &"mixamorig_LeftForeArm",
&"hand_left": &"mixamorig_LeftHand",
&"upper_arm_right": &"mixamorig_RightArm",
&"lower_arm_right": &"mixamorig_RightForeArm",
&"hand_right": &"mixamorig_RightHand",
&"upper_leg_left": &"mixamorig_LeftUpLeg",
&"lower_leg_left": &"mixamorig_LeftLeg",
&"foot_left": &"mixamorig_LeftFoot",
&"toe_left": &"mixamorig_LeftToeBase",
&"upper_leg_right": &"mixamorig_RightUpLeg",
&"lower_leg_right": &"mixamorig_RightLeg",
&"foot_right": &"mixamorig_RightFoot",
&"toe_right": &"mixamorig_RightToeBase"
}
source_skeleton_sha256 = "8f589e35f16f02fe4aa0f45b5f2c85377a41f9ecc188670bf59159518e6cdbe4"
source_rest_signature = "1ea73d190881c437d8ca6fc10dd7c4f446d2d14523416bcd0731264dad689eda"
```

- [ ] **Step 4: Create the feminine resource exactly**

Create `data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres` with exactly:

```text
[gd_resource type="Resource" script_class="HumanoidRigMapping" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/presentation/humanoid_rig_mapping.gd" id="1"]

[resource]
script = ExtResource("1")
mapping_id = &"pf_humanoid_v1_mixamo52_feminine"
canonical_rig_id = &"pf_humanoid_v1"
role_to_bone = {
&"hips": &"mixamorig_Hips",
&"spine": &"mixamorig_Spine",
&"chest": &"mixamorig_Spine2",
&"neck": &"mixamorig_Neck",
&"head": &"mixamorig_Head",
&"upper_arm_left": &"mixamorig_LeftArm",
&"lower_arm_left": &"mixamorig_LeftForeArm",
&"hand_left": &"mixamorig_LeftHand",
&"upper_arm_right": &"mixamorig_RightArm",
&"lower_arm_right": &"mixamorig_RightForeArm",
&"hand_right": &"mixamorig_RightHand",
&"upper_leg_left": &"mixamorig_LeftUpLeg",
&"lower_leg_left": &"mixamorig_LeftLeg",
&"foot_left": &"mixamorig_LeftFoot",
&"toe_left": &"mixamorig_LeftToeBase",
&"upper_leg_right": &"mixamorig_RightUpLeg",
&"lower_leg_right": &"mixamorig_RightLeg",
&"foot_right": &"mixamorig_RightFoot",
&"toe_right": &"mixamorig_RightToeBase"
}
source_skeleton_sha256 = "173198e3d044418b9765971e8b698664176c05dadd6a5aaa4ddb8df8d4c08667"
source_rest_signature = "fad7e1860ef45781179d156654734b6160a7d97df96be43d3eb8c0bc51ea5c85"
```

- [ ] **Step 5: Replace the obsolete default-loader missing assertion with exact two-body success assertions**

In `tests/unit/test_humanoid_rig_mapping_catalog.gd`, delete only the `default_missing_result` assertion block and insert:

```gdscript
	_assert_default_resource_resolution(
		catalog,
		&"masculine",
		MASCULINE_PATH,
		MASCULINE_ID,
		MASCULINE_SHA,
		MASCULINE_REST,
		failures
	)
	_assert_default_resource_resolution(
		catalog,
		&"feminine",
		FEMININE_PATH,
		FEMININE_ID,
		FEMININE_SHA,
		FEMININE_REST,
		failures
	)
```

Add this helper before `_mapping`:

```gdscript
func _assert_default_resource_resolution(
	catalog: RefCounted,
	preset: StringName,
	expected_path: String,
	expected_mapping_id: StringName,
	expected_source_sha: String,
	expected_rest_signature: String,
	failures: Array[String]
) -> void:
	var result := catalog.call(&"resolve", preset) as RefCounted
	TestAssertions.truthy(result != null, "%s default resource returns a result" % preset, failures)
	if result == null:
		return
	TestAssertions.truthy(bool(result.call(&"is_success")), "%s default resource resolves successfully" % preset, failures)
	TestAssertions.equal(result.call(&"get_requested_body_preset"), preset, "%s default result keeps preset" % preset, failures)
	TestAssertions.equal(result.call(&"get_selected_resource_path"), expected_path, "%s default result keeps exact path" % preset, failures)
	TestAssertions.equal(result.call(&"get_failure_categories"), [] as Array[StringName], "%s default result has no failure categories" % preset, failures)
	TestAssertions.equal(result.call(&"get_error_messages"), PackedStringArray(), "%s default result has no error messages" % preset, failures)
	var mapping := result.call(&"get_mapping") as Resource
	TestAssertions.truthy(mapping != null, "%s default result returns mapping" % preset, failures)
	if mapping == null:
		return
	TestAssertions.equal(mapping.get(&"mapping_id"), expected_mapping_id, "%s default mapping id is exact" % preset, failures)
	TestAssertions.equal(mapping.get(&"canonical_rig_id"), &"pf_humanoid_v1", "%s default canonical id is exact" % preset, failures)
	TestAssertions.equal(mapping.get(&"source_skeleton_sha256"), expected_source_sha, "%s default source hash is exact" % preset, failures)
	TestAssertions.equal(mapping.get(&"source_rest_signature"), expected_rest_signature, "%s default rest signature is exact" % preset, failures)
```

Do not change the injected missing/load/type/identity/cross-body/stateless tests. They remain the fail-closed contract even after real resources exist.

- [ ] **Step 6: Bind public candidate qualification to the real resources**

In `tests/unit/test_production_humanoid_rest_signature.gd`, replace `MAPPING_PATH` with:

```gdscript
const RESOURCE_PATH_BY_PRESET := {
	&"masculine": "res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres",
	&"feminine": "res://data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres",
}
```

Delete `var _mapping_script: Script`. Replace the mapping-script existence/load section in `run()` with:

```gdscript
	var definition_exists := ResourceLoader.exists(DEFINITION_PATH)
	TestAssertions.truthy(definition_exists, "canonical definition exists for public qualification", failures)
	var all_mapping_resources_exist := true
	for preset: StringName in RESOURCE_PATH_BY_PRESET:
		var exists := ResourceLoader.exists(String(RESOURCE_PATH_BY_PRESET[preset]))
		TestAssertions.truthy(exists, "%s mapping resource exists for public qualification" % preset, failures)
		all_mapping_resources_exist = all_mapping_resources_exist and exists
	if not definition_exists or not all_mapping_resources_exist:
		return failures
	_definition = load(DEFINITION_PATH) as Resource
	TestAssertions.truthy(_definition != null, "canonical definition loads for public qualification", failures)
	if _definition == null:
		return failures
```

In `_assert_public_candidate_validation`, replace the dynamic mapping construction with:

```gdscript
	var mapping_path := String(RESOURCE_PATH_BY_PRESET[preset])
	var mapping := load(mapping_path) as Resource
	TestAssertions.truthy(mapping != null, "%s body-specific mapping resource loads" % preset, failures)
	if mapping == null:
		skeleton.free()
		return
	TestAssertions.equal(mapping.get(&"mapping_id"), MAPPING_ID_BY_PRESET[preset], "%s mapping id matches approved identity" % preset, failures)
	TestAssertions.equal(mapping.get(&"canonical_rig_id"), &"pf_humanoid_v1", "%s canonical mapping id is exact" % preset, failures)
	TestAssertions.equal(mapping.get(&"role_to_bone"), ROLE_TO_BONE, "%s resource carries the exact 19-role mapping" % preset, failures)
	TestAssertions.equal((mapping.get(&"role_to_bone") as Dictionary).size(), 19, "%s resource mapping has exactly 19 roles" % preset, failures)
	TestAssertions.equal(mapping.get(&"source_skeleton_sha256"), SOURCE_SHA_BY_PRESET[preset], "%s resource source hash is exact" % preset, failures)
	TestAssertions.equal(mapping.get(&"source_rest_signature"), EXPECTED[preset], "%s resource rest identity is exact" % preset, failures)
	TestAssertions.equal(mapping.call(&"validate", _definition), PackedStringArray(), "%s resource validates against the canonical definition" % preset, failures)
```

Keep the existing 52-bone/52-bind assertions, unnamed numeric bind checks, public `validate_mapped_rig()` success, strict legacy failures, 51-bind exact-final-bone rejection, serialization, and distinct-rest assertions byte-identical outside this replacement.

- [ ] **Step 7: Run focused GREEN**

Run once:

```powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- `
  tests/unit/test_humanoid_rig_mapping_catalog.gd `
  tests/unit/test_production_humanoid_rest_signature.gd `
  tests/unit/test_production_humanoid_rig_mapping.gd `
  tests/unit/test_humanoid_rig_contract.gd `
  tests/unit/test_skinned_equipment_binding.gd `
  tests/unit/test_body_region_visibility.gd
```

Require native exit `0`, exactly one terminal `TEST_SUMMARY: PASS (0 failures)`, zero `TEST_FAILURE`, zero prohibited diagnostics, both default catalog results successful, both real resources validated against their corresponding 52-bone candidate, and both legacy boundaries still rejecting the superset.

- [ ] **Step 8: Audit exact scope and commit atomically**

Require the fixture and both GLBs unchanged, the shared resource absent, all 76 protected untracked records exact, no production-script diff, and this exact four-path task scope:

```text
data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres
data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres
tests/unit/test_humanoid_rig_mapping_catalog.gd
tests/unit/test_production_humanoid_rest_signature.gd
```

Then:

```powershell
git -C $project diff --check
git -C $project add -- `
  data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres `
  data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres `
  tests/unit/test_humanoid_rig_mapping_catalog.gd `
  tests/unit/test_production_humanoid_rest_signature.gd
git -C $project diff --cached --check
git -C $project commit -m 'feat: add body-specific humanoid rig mappings'
```

Expected: one atomic four-path commit whose parent is the Task 0 documentation commit. Do not commit one body without the other.

## Task 2: Fresh Verification and Independent Review

**Files:**
- Read-only: all implementation paths and protected inputs
- Evidence only: one fresh TEMP root containing tracked archive, disposable project, controller logs, inventories, classifications, diagnostic manifests, and review briefs/results

**Interfaces:**
- Consumes: `resourceWriteBase`, the Task 0 documentation commit, the Task 1 four-path resource/test commit, accepted asynchronous controller SHA-256 `46b171f14c852bdb05984bf289e19d1ea9091d7ae2892561b22963b5f20ae1aa`, and the accepted post-merge full-suite reference stderr SHA-256 `41a37df48366199a6323be3f6e2d4b16122fbd3e2b8d6f04b3fcf5279c2e24d6`.
- Produces: a fresh-from-tracked cold-import qualification, a full-suite verdict, exact diagnostic-family comparison, two sequential read-only PASS reviews, and final containment evidence.

- [ ] **Step 1: Audit history and path unions**

Require exactly two first-parent commits after `resourceWriteBase`, in order:

```text
docs: reconcile body-specific rig resource paths
feat: add body-specific humanoid rig mappings
```

Require zero merges after `resourceWriteBase`; the implementation commit must contain exactly the four Task 1 paths; the complete two-commit union must contain exactly those four paths plus `docs/superpowers/plans/2026-08-31-production-character-equipment-replacement.md`. Run `git diff --check resourceWriteBase..HEAD` and require clean tracked/index state.

- [ ] **Step 2: Create one immutable tracked archive**

Use `git archive --format=zip --output=<fresh-temp>\tracked.zip HEAD`. Hash it, validate every entry is relative/traversal-free, expand into one new disposable project, prove no `.godot` exists, and record a complete pre-import inventory/hash manifest. Do not reuse the published pre-resource archive because the resources are new tracked files.

- [ ] **Step 3: Cold import exactly once**

With fresh empty import `APPDATA`/`LOCALAPPDATA`, invoke the qualified asynchronous controller with this exact argument vector and 720000 ms bound:

```text
--headless
--editor
--import
--quit
--path
<disposable-project>
```

Require native exit `0`, no timeout/controller failure, and no prohibited diagnostic. Classify the post-import delta using the accepted deterministic classes only:

- `.godot/**` generated state;
- source-adjacent `.gd.uid` only when the exact sibling `.gd` existed pre-import;
- source-adjacent `.png.import` only when the exact sibling `.png` existed pre-import, `source_file` equals that sibling's `res://` path, every normalized target is strictly under `res://.godot/imported/`, and every target exists.

Reject existing-file byte changes/deletions, traversal/external references, unapproved source-adjacent metadata, or authoritative-worktree writes. Run a separate read-only classifier verifier. Do not run a second import.

- [ ] **Step 4: Run the complete suite exactly once**

With a different fresh empty suite `APPDATA`/`LOCALAPPDATA`, invoke the same controller with:

```text
--headless
--path
<disposable-project>
--script
res://tests/test_runner.gd
```

Require native exit `0`, exactly one positive terminal `TEST_SUMMARY: PASS (<positive suite count> suites)`, zero FAIL markers, zero `TEST_FAILURE`, and zero prohibited parser/loader/import/script-compile/crash/fatal/segmentation/object-leak/RID-leak families. Reinventory the disposable project and require every pre-import source byte unchanged and no new source-adjacent class outside the import allowlist.

- [ ] **Step 5: Compare diagnostics mechanically**

Rehash the immutable post-merge reference stderr at:

```text
C:\Users\Jacob\AppData\Local\Temp\pf-rig-postmerge-focused-retry-20260901T165816Z-1ec7a24c\suite.stderr.txt
```

Require SHA-256 `41a37df48366199a6323be3f6e2d4b16122fbd3e2b8d6f04b3fcf5279c2e24d6`. Use the qualified normalizer and comparator contract already accepted for Task D: normalize only approved volatile paths/profile IDs/GUIDs/hashes/line numbers/standalone numbers; preserve severity, reason text, backtrace flag, and first frame. `INTENTIONAL_NEW_FAMILY_BY_LABEL` remains empty. Require byte-identical ordinal family manifests, zero added/removed/count-different family, and `unmatched_count = 0`; aggregate counts alone do not pass. Run a separate verifier that does not invoke/import the normalizer.

- [ ] **Step 6: Obtain a fresh requirements review**

Dispatch one fresh read-only reviewer. Give it `resourceWriteBase`, both commit hashes, the documentation commit as provenance, exact four-path implementation scope, approved design/amendment, fixture, immutable source hashes, RED/GREEN evidence, archive/import/full-suite evidence, and this brief:

```text
Return PASS or FAIL with exact file:line evidence. Verify that both exact resources exist; each uses the correct unique mapping ID, canonical ID, source SHA-256, body-specific rest signature, and exact 19-role mapping; no shared/cross-body fallback exists; the real default catalog loader selects the exact body path; both real resources pass public mapped-rig validation against their corresponding 52-bone unnamed-numeric-bind fixture; strict legacy validators still reject the superset; fixture and GLBs remain immutable; and no presentation/body/art scope is included. Audit the documentation reconciliation as provenance, not product behavior. Do not edit.
```

Stop on FAIL or inadequate evidence. Do not dispatch the second reviewer.

- [ ] **Step 7: Obtain a distinct code-quality review**

Only after requirements PASS, dispatch a different fresh read-only reviewer with the same commit/evidence separation and this brief:

```text
Return PASS or FAIL with exact file:line evidence. Review deterministic .tres syntax and serialization, exact property types, dictionary completeness/uniqueness, test trustworthiness, guarded absence behavior, default ResourceLoader coverage, fixture-backed public validation, legacy containment, absence of duplicated mutable production logic, and atomic rollback. Confirm no shared resource, production-script change, hidden loader fallback, source mutation, or unreviewed scope. Do not repeat the requirements review and do not edit.
```

Stop on FAIL or inadequate evidence. Do not repair under this plan.

- [ ] **Step 8: Perform final containment**

Require:

- tracked/index clean at the two-commit resource checkpoint;
- the new 76-record protected manifest exact;
- fixture SHA-256 `a0ca9b54b9ea158c4c970cbd36121bfc89fd06d7ed2cff054c032f8e8c21f811`;
- both immutable GLB hashes exact;
- shared mapping resource absent;
- both body-specific resources present and tracked;
- Dawn Bulwark unchanged from its captured three-modification baseline;
- Combat HUD never targeted and any concurrent drift recorded read-only;
- authoritative `main`, `refs/remotes/origin/main`, and live remote still at the pre-execution published checkpoint unless a separately authorized integration occurred; this plan authorizes none;
- every new evidence manifest internally rehashes with zero missing/length/hash mismatch.

## Task 3: Mandatory Pre-Integration Stop

**Files:** None.

**Interfaces:**
- Consumes: both review verdicts and Task 2 final containment.
- Produces: Studio Lead checkpoint report and an explicit approval request for the next phase.

- [ ] **Step 1: Report the verified resource checkpoint**

Report branch/worktree, `resourceWriteBase`, both commits/parents/subjects, exact five-path complete union and four-path implementation union, resource file hashes and property values, RED/GREEN/full-suite markers/exits, archive/import/classification/diagnostic evidence, both review verdicts, fixture/GLB/protected hashes, Dawn/HUD status, and rollback boundaries.

- [ ] **Step 2: Stop**

Do not integrate, merge, push, clean, create a shared mapping, import GLBs, qualify bodies, begin presentation transactions, or start Dawn Bulwark production. The next phase requires a new Studio Lead decision.

## Rollback

- Before Task 0 commit: restore only the task-owned original-plan edit from the captured pre-edit bytes; no protected path may be cleaned or broadly reset.
- After Task 0 commit but before Task 1 commit: revert the documentation commit with a normal `git revert` only under separate authorization; do not rewrite history.
- After Task 1 commit: a separately authorized normal revert of the resource commit atomically removes both `.tres` files and both test changes. Never delete only one body resource or hand-edit immutable history.
- TEMP evidence is append-only and preserved. Disposable imports may not be deleted under this plan.

## Requirement-to-Task Traceability

| Approved requirement | Plan coverage |
|---|---|
| Two exact resource paths/IDs | Exact Resource Contract; Task 1 Steps 3-5 |
| Exact source hashes and distinct rest signatures | Global Constraints; Task 1 Steps 3-6 |
| Same exact 19-role semantic mapping | Exact Resource Contract; Task 1 Steps 3, 4, 6 |
| Real default path selection, no shared/cross-body fallback | Task 1 Steps 1, 5, 7; Task 2 reviews |
| Public 52-bone/unnamed-numeric-bind validation for both bodies | Task 1 Step 6 |
| Legacy validator containment | Task 1 Steps 6-7 |
| Singular original-plan reconciliation | Task 0 Steps 2-4 |
| Fixture/GLB/protected provenance | Global Constraints; Tasks 0-3 |
| Fresh-from-tracked verification after new resources | Task 2 Steps 2-5 |
| Independent requirements and quality reviews | Task 2 Steps 6-7 |
| No source mutation/shared rest/presentation/art work | Global Constraints; Task 3 |
| Mandatory approval stop | Task 3 |

## Plan Self-Review Checklist

- [ ] Every approved amendment requirement maps to an exact task above.
- [ ] All resource paths, mapping IDs, source hashes, rest signatures, role keys, and bone names match the approved design exactly.
- [ ] The initial RED cannot emit a missing-resource loader diagnostic because it returns before `load()`.
- [ ] The post-resource catalog test preserves injected fail-closed coverage while changing only the obsolete default missing-resource expectation.
- [ ] The fixture is read-only and both public candidate validations consume the real resources.
- [ ] No production script, gameplay ID, presentation transaction, active visual, body derivative, head, armor, equipment, or art path is in scope.
- [ ] The original untracked plan's transition into tracked history is explicit; the protected inventory changes deterministically from 77 to 76 rather than being silently described as unchanged.
- [ ] Exactly two execution commits follow dynamic `resourceWriteBase`; implementation scope is four paths and complete scope is five paths.
- [ ] PowerShell no-match handling accepts `rg` exit `1` only when the captured match array is empty.
- [ ] Code fences are balanced; commands and types are internally consistent.
- [ ] Incomplete-requirement/red-flag scan, stale singular-reference scan, and `git diff --check` pass before the plan commit.
