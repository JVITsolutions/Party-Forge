# Character Pose and Equipment Silhouette Follow-up Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every playable class use a natural, forward-readable runtime stance and make Fighter sword/shield geometry visibly separate from the arms at gameplay scale.

**Architecture:** Preserve the shared rigid-component humanoid, class profiles, stable item scenes, and `CharacterPresentation` adapter. Replace proxy-only pose and equipment checks with measurements of the instantiated pivot hierarchy and visible mesh bounds, then correct the shared authoring values and held-item transforms at their source before deterministically rebuilding generated scenes.

**Tech Stack:** Godot 4.7.1, GDScript, generated `.tscn` resources, repository unit/integration runners, deterministic viewport QA captures.

## Global Constraints

- Preserve both reusable body presets and all nine playable class profiles.
- Preserve stable equipment IDs, slots, item resources, icons, combat events, gameplay wrappers, collision, and fallback behavior.
- The source A-pose is authoring-only; it is never acceptable as a runtime idle or locomotion frame.
- Held equipment remains a separate scene, node, and mesh resource from arm geometry.
- A grip may meet the hand, but visible weapon and shield bodies may not intersect the upper-arm or forearm bounds.
- Do not modify or stage the unrelated main-checkout change in `scenes/game/main.tscn` or generated untracked import sidecars.
- Run Godot with isolated `APPDATA` and `LOCALAPPDATA`; a timeout or silent hang is not a pass.

---

### Task 1: Add real runtime-pose regressions

**Files:**
- Modify: `tests/unit/test_humanoid_animation_quality.gd`
- Modify: `scripts/presentation/forge_humanoid_model.gd`

**Interfaces:**
- Consumes: the existing `forge_humanoid_model.tscn` pivot hierarchy and `AnimationPlayer` actions.
- Produces: `body_part_combined_bounds(part_ids: Array[StringName]) -> AABB` and tests that sample instantiated idle poses rather than comparing only authored track deltas.

- [ ] **Step 1: Write the failing pose tests**

Add helpers that instantiate the model under a temporary `Node3D`, activate each body preset, seek every idle to `0.0`, `0.4`, `0.8`, and `1.2`, then read model-space bounds for torso, upper arms, forearms, and hands. Assert:

```gdscript
const MAX_IDLE_HAND_BEHIND_TORSO := 0.04
const MAX_IDLE_ARM_SPAN_RATIO := 1.75

func _assert_runtime_idle_silhouette(model: ForgeHumanoidModel, player: AnimationPlayer, action_id: StringName, body_id: StringName, failures: Array[String]) -> void:
	for sample_time: float in [0.0, 0.4, 0.8, 1.2]:
		player.play(action_id)
		player.seek(sample_time, true)
		var torso := model.body_part_combined_bounds([&"torso"])
		var hands := model.body_part_combined_bounds([&"left_hand", &"right_hand"])
		var arms := model.body_part_combined_bounds([&"left_upper_arm", &"left_forearm", &"right_upper_arm", &"right_forearm"])
		TestAssertions.truthy(hands.position.z <= torso.end.z + MAX_IDLE_HAND_BEHIND_TORSO, "%s %s keeps hands out from behind torso at %.1f" % [action_id, body_id, sample_time], failures)
		TestAssertions.truthy(arms.size.x <= torso.size.x * MAX_IDLE_ARM_SPAN_RATIO, "%s %s avoids T-pose span at %.1f" % [action_id, body_id, sample_time], failures)
```

Use the model's actual facing axis, confirmed from the QA renderer camera, when selecting the behind/in-front inequality.

- [ ] **Step 2: Run the suite and witness RED**

Run:

```powershell
$env:APPDATA = Join-Path (Get-Location) '.task-data\appdata'
$env:LOCALAPPDATA = Join-Path (Get-Location) '.task-data\localappdata'
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --script res://tests/test_runner.gd
```

Expected: `test_humanoid_animation_quality.gd` reports current Fighter T-pose-like arm span and caster/ranged hands behind the torso. If Godot is silent until the bounded timeout, record the lock as blocked and retry only after the running editor/review processes release it.

- [ ] **Step 3: Add minimal model-space body-part bounds API**

Tag generated body meshes with stable metadata in the builder, then expose only the read-only geometry query needed by tests and future QA:

```gdscript
func body_part_combined_bounds(part_ids: Array[StringName]) -> AABB:
	var combined := AABB()
	var found := false
	for mesh: MeshInstance3D in _all_meshes():
		if not _is_effectively_visible(mesh) or mesh.mesh == null:
			continue
		if StringName(mesh.get_meta(&"body_part", &"")) not in part_ids:
			continue
		var transformed := _transform_from_model(mesh) * mesh.get_aabb()
		combined = transformed if not found else combined.merge(transformed)
		found = true
	return combined
```

- [ ] **Step 4: Run the tests and confirm the regression still fails for pose quality, not missing instrumentation**

Expected: body-part queries return finite nonzero bounds for both presets; only the new stance assertions fail.

- [ ] **Step 5: Commit the witnessed regression**

```powershell
git add tests/unit/test_humanoid_animation_quality.gd scripts/presentation/forge_humanoid_model.gd tools/build_shared_humanoid_scene.gd
git commit -m "test: measure runtime humanoid stance geometry"
```

### Task 2: Correct shared idle and walk arm authoring

**Files:**
- Modify: `scripts/presentation/humanoid_animation_authoring.gd`
- Regenerate: `scenes/characters/presentation/forge_humanoid_model.tscn`
- Regenerate: `scenes/characters/presentation/forge_base_masculine.tscn`
- Regenerate: `scenes/characters/presentation/forge_base_feminine.tscn`
- Test: `tests/unit/test_humanoid_animation_quality.gd`

**Interfaces:**
- Consumes: Task 1 runtime-bound assertions.
- Produces: compact guarded idles and a walk whose arm tracks begin/end in the corrected Fighter guard.

- [ ] **Step 1: State and test the confirmed authoring hypothesis**

Document beside `_idle_style` that arms extend down the local negative-Y axis, the character faces local negative-Z, negative shoulder-X pushes hands behind the torso, and large mirrored shoulder-Z values spread the arms laterally. Add track-level assertions that idle shoulder-X stays on the forward/neutral side and Fighter shoulder-Z stays below the measured T-pose threshold.

- [ ] **Step 2: Run and witness RED against the existing negative shoulder-X table**

Expected: all class-specific idle styles fail the forward-hand constraint; Fighter also fails the lateral-span constraint.

- [ ] **Step 3: Author minimal compact guards**

Replace the special Fighter pose and `_idle_style` values with small forward shoulder-X, restrained shoulder-Z, and elbow rotations that bend hands inward without crossing the torso. Keep class identity in asymmetry, torso yaw, stance width, and animation timing rather than putting hands behind the back. Update `build_walk` to use the corrected Fighter guard as its arm baseline.

- [ ] **Step 4: Rebuild generated humanoid scenes twice**

Run the repository builder twice with isolated app-data paths and compare tracked output after each run. Expected: the first rebuild changes only generated presentation scenes; the second produces zero diff.

- [ ] **Step 5: Run pose and locomotion suites**

Expected: every class/body/sample passes forward-hand and arm-span assertions, loops remain closed, and walk/attack timing tests stay green.

- [ ] **Step 6: Commit the shared pose correction**

```powershell
git add scripts/presentation/humanoid_animation_authoring.gd scenes/characters/presentation/forge_humanoid_model.tscn scenes/characters/presentation/forge_base_masculine.tscn scenes/characters/presentation/forge_base_feminine.tscn tests/unit/test_humanoid_animation_quality.gd
git commit -m "fix: keep runtime humanoid arms in natural guards"
```

### Task 3: Measure and remove visible equipment-to-arm intersection

**Files:**
- Modify: `scripts/presentation/forge_humanoid_model.gd`
- Modify: `tests/unit/test_held_equipment_readability.gd`
- Modify: `tools/build_equipment_assets.gd`
- Regenerate: `scenes/equipment/forge_vanguard/forge_vanguard_sword.tscn`
- Regenerate: `scenes/equipment/forge_vanguard/forge_vanguard_shield.tscn`
- Regenerate: other held-item scenes only when they fail the same geometry contract.

**Interfaces:**
- Consumes: equipped-node registry, `_equipment_bounds`, body-part metadata, and corrected idle poses.
- Produces: `equipment_arm_intersection_volume(slot_id: StringName) -> float` and `equipment_arm_clearance(slot_id: StringName) -> float` based on visible mesh bounds.

- [ ] **Step 1: Replace the proxy-anchor assertion with visible geometry assertions**

For all nine classes and both body presets, sample idle and attack release, then assert:

```gdscript
const MAX_VISIBLE_INTERSECTION_VOLUME := 0.00001

var overlap := float(model.call(&"equipment_arm_intersection_volume", slot_id))
TestAssertions.truthy(overlap <= MAX_VISIBLE_INTERSECTION_VOLUME, "%s %s %s visible geometry clears the arm (overlap=%.6f)" % [definition.id, body_id, item_id, overlap], failures)
```

Retain the anchor and resource-identity checks as secondary contracts; do not treat them as proof of visual separation.

- [ ] **Step 2: Run and witness RED**

Expected: Fighter sword grip/blade or shield body intersects the forearm AABBs; any other fused bow, staff, wand, focus, tome, or grimoire reports its exact class/body/slot/item/sample.

- [ ] **Step 3: Implement visible-mesh intersection queries**

Compute pairwise `AABB.intersection()` between effective visible equipment meshes and effective visible upper-arm/forearm meshes in model space. Sum only positive three-axis intersection volumes. Exclude the explicit hand/grip region from the arm set so a hand may hold a handle while the forearm remains clear.

- [ ] **Step 4: Correct source attachment transforms**

Move the Fighter sword grip to the hand endpoint with its blade angled away from the forearm. Move the shield forward on local Z and outward on local X so its plate has a visible gap from the forearm while the grip remains near the hand. Apply similarly minimal source-transform changes to other failing held items; do not rebuild weapon designs or change IDs.

- [ ] **Step 5: Regenerate equipment scenes twice and verify determinism**

Expected: only failing held-item scene transforms and their source scene change on the first run; the second run produces zero diff.

- [ ] **Step 6: Run equipment, unequip, body-switch, projectile, and combat-event tests**

Expected: zero visible arm intersection, one attachment per slot, opposite items and both arms survive unequip, both body presets work, and launch/action sockets remain valid.

- [ ] **Step 7: Commit equipment separation**

```powershell
git add scripts/presentation/forge_humanoid_model.gd tests/unit/test_held_equipment_readability.gd tools/build_equipment_assets.gd scenes/equipment
git commit -m "fix: separate held equipment from arm silhouettes"
```

### Task 4: Make gameplay-scale visual QA fail the reported defects

**Files:**
- Modify: `tools/render_character_visual_qa.gd`
- Create: `tests/unit/test_character_visual_qa_contract.gd`
- Regenerate: `docs/qa/character-presentation-quality/`

**Interfaces:**
- Consumes: actual class profiles, active equipment, runtime animations, body bounds, and intersection metrics.
- Produces: close gameplay-camera captures and metadata that show arms, hands, grips, and equipment clearly enough for review.

- [ ] **Step 1: Add failing QA-contract expectations**

Require each class/body contact sheet to contain labeled close views for idle front, idle three-quarter, idle side, held-item close-up, and attack release. Require metadata fields for `hand_behind_torso`, `arm_span_ratio`, and `equipment_arm_overlap` at each relevant sample.

- [ ] **Step 2: Run and witness RED against the current renderer**

Expected: current renderer lacks the close-up capture and geometry metrics.

- [ ] **Step 3: Add deterministic close gameplay-camera captures**

Frame the torso, arms, hands, and held items at the same azimuth/elevation relationship as the real gameplay camera, while increasing resolution enough to distinguish hand, grip, forearm, blade, and shield gap. Keep existing full-body grounding and animation phase frames.

- [ ] **Step 4: Render all 18 class/body combinations**

Expected: no blank frames, missing actions, missing equipment, non-finite metrics, behind-back idle flags, T-pose span flags, or equipment overlap flags.

- [ ] **Step 5: Perform strict human visual review**

Reject any sheet where a weapon could be mistaken for an arm, a shield could be mistaken for a shoulder block, both arms sit behind the torso, or idle reads as a display pose. Record reviewed paths and any rejection reason; numeric green checks do not override an obvious bad silhouette.

- [ ] **Step 6: Commit the strengthened visual gate and accepted evidence**

```powershell
git add tools/render_character_visual_qa.gd tests/unit/test_character_visual_qa_contract.gd docs/qa/character-presentation-quality
git commit -m "test: enforce gameplay-scale character silhouettes"
```

### Task 5: Verify the exact merge candidate and integrate safely

**Files:**
- Modify: `docs/qa/2026-08-02-character-pose-silhouette-followup-validation.md`

**Interfaces:**
- Consumes: Tasks 1-4 and the exact feature-branch HEAD.
- Produces: recorded verification evidence and a fast-forward merge that preserves unrelated main-checkout work.

- [ ] **Step 1: Ensure Godot is able to start cleanly**

Do not continue while a new headless `--path` run is silent. Confirm stale review processes are gone or coordinate closing/restarting the open editor; do not terminate user-owned processes without authorization.

- [ ] **Step 2: Run the full unit suite with isolated app data**

Expected: `TEST_SUMMARY: PASS` with the current suite count and no timeout.

- [ ] **Step 3: Run locomotion, presentation, combat, and visual QA smoke runners**

Expected: every focused runner prints its success marker and exits `0`.

- [ ] **Step 4: Run deterministic humanoid and equipment builders twice**

Expected: zero tracked drift on the second run.

- [ ] **Step 5: Re-render and inspect Fighter masculine/feminine plus every class idle sheet**

Expected: Fighter sword/shield read as separate held objects; no class has both arms behind its back; no idle reads as A/T pose.

- [ ] **Step 6: Record validation evidence**

Write exact commit, commands, exit codes, suite counts, smoke markers, render counts, reviewed paths, and any deferred live-play check. Never label a blocked editor run as passed.

- [ ] **Step 7: Commit validation**

```powershell
git add docs/qa/2026-08-02-character-pose-silhouette-followup-validation.md
git commit -m "docs: record character silhouette follow-up verification"
```

- [ ] **Step 8: Recheck main and fast-forward only if verification is green**

Confirm the hash of `scenes/game/main.tscn` and all unrelated dirty/untracked files are unchanged, then fast-forward `main` to the verified feature commit. If main advanced, rebase/merge safely and rerun the exact candidate verification before integration.
