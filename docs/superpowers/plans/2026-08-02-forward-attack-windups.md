# Forward Attack Wind-ups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep every primary attack's wind-up out from behind the reusable humanoid body while preserving weapon-specific silhouettes, timings, and modular equipment.

**Architecture:** Strengthen the real runtime-pose regression test so it samples each hand and elbow through the entire attack curve, then correct the shared authored attack keyframes and regenerate the humanoid scene deterministically. Extend hardware visual QA with a close loaded-pose frame and individual joint-depth manifest fields.

**Tech Stack:** Godot 4.7.1, GDScript, Party Forge focused/full test runners, deterministic scene builder, Forward+ visual QA renderer.

## Global Constraints

- Gameplay forward is local `-Z`; positive local `Z` is behind the character.
- Preserve all action IDs, animation durations, event names, event times, attack locks, and gameplay damage behavior.
- Preserve separate modular equipment scenes, slots, and current equipment-arm intersection budgets.
- Test masculine and feminine bodies for all ten primary attacks.
- Sample the complete attack curve in five-percent increments and test each hand separately.
- Do not add runtime IK or hand-edit generated animation tracks in `forge_humanoid_model.tscn`.
- Do not modify or terminate the user-owned main checkout or Godot editor.

---

### Task 1: Prove the full-curve behind-back regression

**Files:**
- Modify: `tests/unit/test_humanoid_animation_quality.gd`

**Interfaces:**
- Consumes: real `ForgeHumanoidModel` transforms and its authored `AnimationPlayer` clips.
- Produces: `_assert_runtime_attack_curve(...)` covering each attack/body/joint/time and diagnostic failures containing measured local `Z`.

- [ ] **Step 1: Replace endpoint-only samples with complete curve and joint paths**

Add elbow paths beside the hand paths and define the per-family depth limits:

```gdscript
const LEFT_ELBOW_PATH := "HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot"
const RIGHT_ELBOW_PATH := "HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot"
const MAX_ATTACK_HAND_BEHIND_Z := 0.18
const MAX_BOW_DRAW_HAND_BEHIND_Z := 0.26
const MAX_ATTACK_ELBOW_BEHIND_Z := 0.14

func _attack_sample_times() -> Array[float]:
	var samples: Array[float] = []
	for index: int in 21:
		samples.append(float(index) / 20.0)
	return samples
```

Replace `_assert_runtime_attack_endpoints` with `_assert_runtime_attack_curve`. At every sample, seek the real animation and call a helper for `left_hand`, `right_hand`, `left_elbow`, and `right_elbow`. Use `MAX_BOW_DRAW_HAND_BEHIND_Z` only for the right hand of `ranger_quick_bow_shot` and `marksman_heavy_bow_shot`; all other hand samples use `MAX_ATTACK_HAND_BEHIND_Z`. Every failure message must include attack ID, body ID, joint label, normalized time, measured `z`, and limit.

- [ ] **Step 2: Run the focused test and witness RED**

Run:

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --path . --script res://tests/focused_test_runner.gd -- res://tests/unit/test_humanoid_animation_quality.gd
```

Expected: exit `1`, `TEST_SUMMARY: FAIL`, with current loaded/interpolated attack samples named in `TEST_FAILURE` output. Confirm the failure is joint depth, not a parser or resource-load error.

- [ ] **Step 3: Commit the witnessed regression test**

```powershell
git add tests/unit/test_humanoid_animation_quality.gd
git commit -m "test: reject behind-back attack windups"
```

### Task 2: Author weapon-specific forward wind-ups

**Files:**
- Modify: `scripts/presentation/humanoid_animation_authoring.gd`
- Modify: `scenes/characters/presentation/forge_humanoid_model.tscn`
- Test: `tests/unit/test_humanoid_animation_quality.gd`
- Test: `tests/unit/test_held_equipment_readability.gd`
- Test: `tests/unit/test_forge_vanguard_animations.gd`

**Interfaces:**
- Consumes: `_attack_pose_data(action_id)` and the existing five phase times `0.0`, `0.28`, `0.52`, `0.76`, `1.0`.
- Produces: forward loaded/release/follow-through poses through `HumanoidAnimationAuthoring.build_attack`, regenerated into the shared humanoid scene.

- [ ] **Step 1: Correct only attack arm keyframes at the authoring source**

Keep the base guard and all torso/leg timing. Replace backward-loaded shoulder/elbow values with class-specific forward chambers:

```gdscript
# Fighter: sword beside weapon shoulder; shield forward.
_set_phases(data, RIGHT_SHOULDER, Vector3(0.38, -0.22, -0.52), Vector3(0.52, 0, 0.58), Vector3(0.26, -0.08, 0.18))
_set_phases(data, RIGHT_ELBOW, Vector3(0.58, 0, -0.24), Vector3(0.24, 0, 0.16), Vector3(0.42, 0, 0.06))
_set_phases(data, LEFT_SHOULDER, Vector3(0.34, -0.08, 0.42), Vector3(0.40, 0, 0.32), Vector3(0.32, -0.04, 0.38))

# Paladin: hammer rises beside/above the shoulder, not behind it.
_set_phases(data, RIGHT_SHOULDER, Vector3(0.52, -0.10, -0.42), Vector3(0.64, 0, 0.16), Vector3(0.32, -0.04, 0.06))
_set_phases(data, RIGHT_ELBOW, Vector3(0.72, 0, -0.16), Vector3(0.30, 0, 0.04), Vector3(0.48, 0, 0.02))

# Bow attacks: bow hand remains forward; draw hand reaches beside the face.
_set_phases(data, RIGHT_SHOULDER, Vector3(0.30, -0.18, -0.34), Vector3(0.24, -0.08, -0.16), Vector3(0.28, -0.12, -0.22))
_set_phases(data, LEFT_SHOULDER, Vector3(0.62, 0, 0.52), Vector3(0.40, 0, 0.24), Vector3(0.46, 0, 0.30))
```

Apply the same rule deliberately to Rogue, Mage, Frost Mage, both Cleric attacks, and Warlock: loaded shoulder/elbow `x` rotations remain forward-positive; lateral `z` and torso yaw preserve distinct silhouettes. Do not copy the Fighter curve across classes.

- [ ] **Step 2: Regenerate the shared scene**

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --path . --script res://tools/build_shared_humanoid_scene.gd
```

Expected: exit `0`, builder success marker, and changes limited to the authored source plus generated shared humanoid scene.

- [ ] **Step 3: Run focused GREEN tests**

```powershell
& $godot --headless --path . --script res://tests/focused_test_runner.gd -- `
  res://tests/unit/test_humanoid_animation_quality.gd `
  res://tests/unit/test_held_equipment_readability.gd `
  res://tests/unit/test_forge_vanguard_animations.gd
```

Expected: exit `0`, `TEST_SUMMARY: PASS (0 failures)`. If any curve exceeds its limit, adjust only that attack's authored joint values and repeat this step.

- [ ] **Step 4: Prove deterministic regeneration**

Hash `scripts/presentation/humanoid_animation_authoring.gd` and `scenes/characters/presentation/forge_humanoid_model.tscn`, rerun the builder, and compare hashes. Expected: no second-run drift.

- [ ] **Step 5: Commit the forward wind-ups**

```powershell
git add scripts/presentation/humanoid_animation_authoring.gd scenes/characters/presentation/forge_humanoid_model.tscn
git commit -m "fix: keep attack windups in front of characters"
```

### Task 3: Make loaded-pose visual QA fail closed

**Files:**
- Modify: `tools/render_character_visual_qa.gd`
- Modify: `tests/unit/test_character_visual_qa_contract.gd`
- Modify: `docs/qa/character-presentation-quality/**`

**Interfaces:**
- Consumes: each class/body primary animation and runtime joint transforms.
- Produces: 20 frames per class/body, an `attack_loaded_close` frame, and manifest fields `left_hand_z`, `right_hand_z`, `left_elbow_z`, and `right_elbow_z`.

- [ ] **Step 1: Strengthen the renderer contract test and witness RED**

Require `const SAMPLE_COUNT := 20`, the string `attack_loaded_close`, and all four individual joint-depth manifest keys. Run the focused contract test and expect exit `1` because the renderer still provides 19 samples and averaged hand state only.

- [ ] **Step 2: Add the close loaded sample and individual metrics**

Set `SAMPLE_COUNT` to `20`. Insert this close sample immediately before `attack_release_close`:

```gdscript
_sample(&"attack_loaded_close", attack_action, attack_length * 0.28, -PI / 4.0, false, false, false, 2.5),
```

Extend `_silhouette_metrics` to resolve both elbows and return individual local `z` values alongside the existing compatibility fields. Copy those values into each manifest row.

- [ ] **Step 3: Run the visual contract GREEN**

```powershell
& $godot --headless --path . --script res://tests/focused_test_runner.gd -- res://tests/unit/test_character_visual_qa_contract.gd
```

Expected: exit `0`, `TEST_SUMMARY: PASS (0 failures)`.

- [ ] **Step 4: Render hardware QA and inspect the result**

```powershell
& $godot --path . --script res://tools/render_character_visual_qa.gd
```

Expected marker: `PARTY_FORGE_CHARACTER_VISUAL_QA_OK classes=9 bodies=2 views=4 state_samples=20`. Review both Fighter body variants' loaded/release close frames and all 18 contact sheets. Confirm sword, shield, hammer, bows, daggers, staves, wand/focus, sceptre/reliquary, and wand/grimoire wind-ups do not begin behind the back.

- [ ] **Step 5: Validate the manifest and commit visual evidence**

Require `360` rows (`9 x 2 x 20`), no loaded/interpolated pose beyond the test limits, valid PNG dimensions, and nonblank contact sheets.

```powershell
git add tools/render_character_visual_qa.gd tests/unit/test_character_visual_qa_contract.gd docs/qa/character-presentation-quality
git commit -m "test: expose loaded attack poses in visual QA"
```

### Task 4: Verify and integrate the exact candidate

**Files:**
- Create: `docs/qa/2026-08-02-forward-attack-windups-validation.md`

**Interfaces:**
- Consumes: the exact feature-branch HEAD from Tasks 1-3.
- Produces: recorded import, unit, smoke, determinism, render, manifest, and merge-preservation evidence.

- [ ] **Step 1: Run fresh verification**

Run a fresh isolated `--import`, the complete `res://tests/test_runner.gd`, playable-presentation smoke, locomotion smoke, visual smoke, deterministic shared-humanoid builder, hardware renderer, and `git diff --check`. Require exit `0`, `TEST_SUMMARY: PASS`, exact smoke markers, no second-run builder drift, 360 manifest rows, and visually accepted sheets.

- [ ] **Step 2: Record and commit exact evidence**

Document commit hashes, commands, exit codes, suite count, smoke markers, manifest extrema, red/green counts, reviewed frames, and any deferred live-play feel check.

```powershell
git add docs/qa/2026-08-02-forward-attack-windups-validation.md
git commit -m "docs: record forward attack windup verification"
```

- [ ] **Step 3: Preserve main-checkout work and merge locally**

Before merge, compare feature-changed paths with dirty main paths and require zero overlap. Hash every dirty tracked main file before and after the fast-forward merge. Merge only if the exact candidate is verified and all unrelated hashes remain identical.
