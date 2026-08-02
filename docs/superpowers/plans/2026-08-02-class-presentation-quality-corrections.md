# Class Presentation Quality Corrections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Correct A-pose-looking idles, rigid turning, weak grounding, shared-slash attacks, and visually arm-fused equipment for all nine Party Forge classes and both reusable bodies, with automated and rendered verification.

**Architecture:** Preserve `CharacterPresentation` as the gameplay/presentation adapter and `ForgeHumanoidModel` as the shared modular model. Add explicit held-item anchors, deterministic weapon-family animation authoring, model-only grounding, bounded visual turning, adaptive health-bar placement, and a deterministic render QA runner; generated scenes remain checked-in outputs of the existing Godot builders.

**Tech Stack:** Godot 4.7.1, GDScript, `.tscn`/`.tres` resources, headless focused/full test runners, hardware-rendered `SubViewport` QA captures, PowerShell.

## Global Constraints

- Work only in `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\class-presentation-quality` on `fix/class-presentation-quality`.
- Preserve gameplay-owned `PartyActor`, collision, health, targeting, attack timing, exactly-once sequence tokens, fallback capsules, equipment IDs, and icon paths.
- Preserve both `masculine` and `feminine` body preset IDs and all eleven Path of Exile 1-style presentation slots.
- Keep the current Godot-native rigid-component pipeline; Blender/GLB remains a later replacement behind the same contracts.
- Use a task-local `APPDATA` and `LOCALAPPDATA` for every test command so the user's persisted 300% XP setting cannot contaminate tests.
- The pass condition is exit code `0` plus `TEST_SUMMARY: PASS`; do not hard-code the final suite count.
- Set `$godot='F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'` before every command block that invokes Godot.
- Expected negative-case diagnostics may remain only when the runner exits `0`; unexpected parser errors, `TEST_FAILURE`, or visual-QA errors fail the task.
- Production changes require a witnessed failing focused test first.
- Do not stage generated `.uid` or `.png.import` files unless they were already tracked before this branch.

## File Structure

- Create `scripts/presentation/humanoid_animation_authoring.gd`: deterministic pose/action builders and sampling helpers.
- Modify `tools/build_shared_humanoid_scene.gd`: consume authored actions rather than scaling Fighter slash.
- Modify `tools/build_equipment_assets.gd`: generate `ReadabilityAnchor`, `ActionOriginSocket`, and bow `ProjectileLaunchSocket` nodes.
- Modify `tools/build_shared_humanoid_scene.gd`: add the stable `BackSocket` used by visually equipped quivers.
- Modify `tools/build_class_presentation_profiles.gd`: use equipment-local action/launch socket IDs.
- Modify `scripts/presentation/equipment_visual_definition.gd`: validate held-item anchor requirements.
- Modify `scripts/presentation/forge_humanoid_model.gd`: resolve equipment-local sockets, expose bounds/anchor APIs, and calibrate grounding.
- Modify `scripts/presentation/character_presentation.gd`: bounded facing, grounding refresh, contact shadow, and bounds forwarding.
- Modify `scripts/characters/party_actor.gd`, `scripts/characters/leader.gd`, and `scripts/characters/companion.gd`: pass frame delta into presentation turning without changing actor motion.
- Modify `scripts/ui/health_bar_3d.gd`: place the bar above active visible bounds.
- Create `tests/unit/test_held_equipment_readability.gd`: all-class/all-body held-item contracts.
- Create `tests/unit/test_humanoid_animation_quality.gd`: no-A-pose, grounded walk, and distinct action sampling.
- Create `tests/unit/test_character_grounding_and_ui.gd`: floor, shadow, and health-bar contracts.
- Modify `tests/unit/test_character_locomotion_integration.gd`: bounded turn and attack-facing arbitration.
- Create `tests/integration/character_visual_quality_smoke.gd`: all 18 combinations and exact smoke marker.
- Create `tools/render_character_visual_qa.gd`: deterministic multi-angle/state PNG and contact-sheet capture.
- Create `docs/qa/2026-08-02-character-presentation-quality-validation.md`: exact merge-candidate evidence and reviewed output list.

---

### Task 1: Held-Equipment Readability and Equipment-Local Sockets

**Files:**
- Create: `tests/unit/test_held_equipment_readability.gd`
- Modify: `scripts/presentation/equipment_visual_definition.gd`
- Modify: `scripts/presentation/forge_humanoid_model.gd`
- Modify: `tools/build_equipment_assets.gd`
- Modify: `tools/build_shared_humanoid_scene.gd`
- Modify: `tools/build_class_presentation_profiles.gd`
- Regenerate: `scenes/equipment/**/*.tscn`
- Regenerate: `data/presentation/equipment/**/*.tres`
- Regenerate: `data/presentation/attacks/*.tres`

**Interfaces:**
- Produces: `ForgeHumanoidModel.equipment_anchor_global_transform(slot_id: StringName, anchor_name: StringName) -> Transform3D`
- Produces: `ForgeHumanoidModel.equipment_anchor_clearance(slot_id: StringName, anchor_name: StringName) -> float`
- Produces: `ForgeHumanoidModel.equipment_visible_extent(slot_id: StringName) -> float`
- Produces: `ForgeHumanoidModel.equipped_anchor_names(slot_id: StringName) -> Array[StringName]`
- Produces: required held-item children `ReadabilityAnchor`, `ActionOriginSocket`, and bow-only `ProjectileLaunchSocket`; quivers use `ReadabilityAnchor` on `BackSocket` and are not treated as hand-held.

- [ ] **Step 1: Write the failing all-class held-item test**

Create `test_held_equipment_readability.gd` with these exact invariants:

```gdscript
extends RefCounted

const BODY_IDS: Array[StringName] = [&"masculine", &"feminine"]
const HAND_SLOTS: Array[StringName] = [&"main_hand", &"off_hand"]
const MIN_CLEARANCE := 0.06
const MIN_EXTENT := 0.18

func run() -> Array[String]:
	var failures: Array[String] = []
	var root := Node3D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	var catalog := GameCatalog.load_defaults()
	for definition: ClassDefinition in catalog.classes:
		for body_id: StringName in BODY_IDS:
			var actor := (load("res://scenes/characters/leader.tscn") as PackedScene).instantiate() as PartyActor
			root.add_child(actor)
			actor.configure(PartyMemberState.new(1, definition, true))
			var presentation := actor.get_node("Presentation") as CharacterPresentation
			var model := presentation.active_model as ForgeHumanoidModel
			TestAssertions.truthy(presentation.set_body_preset(body_id), "%s %s body activates" % [definition.id, body_id], failures)
			for slot_id: StringName in HAND_SLOTS:
				var item_id := model.equipped_item_id(slot_id)
				if item_id.is_empty():
					continue
				var anchors := model.equipped_anchor_names(slot_id)
				TestAssertions.truthy(&"ReadabilityAnchor" in anchors, "%s %s %s readability anchor" % [definition.id, body_id, item_id], failures)
				if item_id not in [&"greenwood_light_quiver", &"siege_heavy_quiver"]:
					TestAssertions.truthy(&"ActionOriginSocket" in anchors, "%s %s %s action origin" % [definition.id, body_id, item_id], failures)
				TestAssertions.truthy(model.equipment_anchor_clearance(slot_id, &"ReadabilityAnchor") >= MIN_CLEARANCE, "%s %s %s clears arm silhouette" % [definition.id, body_id, item_id], failures)
				TestAssertions.truthy(model.equipment_visible_extent(slot_id) >= MIN_EXTENT, "%s %s %s extends beyond hand" % [definition.id, body_id, item_id], failures)
				if item_id in [&"greenwood_recurve_bow", &"siege_greatbow"]:
					TestAssertions.truthy(&"ProjectileLaunchSocket" in anchors, "%s launch socket" % item_id, failures)
				if item_id in [&"greenwood_light_quiver", &"siege_heavy_quiver"]:
					TestAssertions.truthy(_attachment_parent_contains(model, slot_id, "BackSocket"), "%s is worn on back" % item_id, failures)
			actor.free()
	root.free()
	return failures

func _attachment_parent_contains(model: ForgeHumanoidModel, slot_id: StringName, expected_name: String) -> bool:
	for attachment: Node3D in model.equipped_nodes.get(slot_id, []):
		var cursor: Node = attachment.get_parent()
		while cursor != null and cursor != model:
			if expected_name in String(cursor.name):
				return true
			cursor = cursor.get_parent()
	return false
```

- [ ] **Step 2: Run RED**

```powershell
$env:APPDATA=(Resolve-Path '.superpowers').Path+'\task1-red-appdata'
$env:LOCALAPPDATA=$env:APPDATA
& $godot --headless --path . --script res://tests/focused_test_runner.gd -- res://tests/unit/test_held_equipment_readability.gd
```

Expected: nonzero exit with missing `equipped_anchor_names`, `equipment_anchor_clearance`, or missing anchor failures.

- [ ] **Step 3: Add held-item validation fields and APIs**

Add to `EquipmentVisualDefinition`:

```gdscript
@export var readability_anchor_name: StringName
@export var action_origin_socket_name: StringName
@export var projectile_launch_socket_name: StringName
@export var attachment_role_id: StringName = &"wearable"

func is_held_item() -> bool:
	return combat_visible and attachment_role_id == &"held"
```

In `validate()`, accept only `wearable`, `held`, or `back` attachment roles. Require nonempty readability and action names for held items, require projectile launch only when a held item's `weapon_animation_family_id in [&"light_bow", &"greatbow"]`, and require a readability anchor for `back` items. Generate quivers with role `back`, bows/weapons/shields/foci/books with role `held`, and armour/accessories with role `wearable`.

Add `ForgeHumanoidModel` APIs that search only the installed nodes for the requested slot, calculate anchor transforms through `_transform_from_model`, calculate equipment AABBs from the installed meshes, and calculate clearance as the shortest distance from the anchor to the combined effective arm AABB. Return `-1.0` for missing/invalid data.

- [ ] **Step 4: Generate anchors at explicit item locations**

In `_add_wearable_geometry`, after held geometry is created, add:

```gdscript
func _add_held_item_anchors(root: Node3D, item_id: StringName) -> void:
	var readability := Node3D.new()
	readability.name = &"ReadabilityAnchor"
	readability.position = _readability_anchor_position(item_id)
	root.add_child(readability)
	var action_origin := Node3D.new()
	action_origin.name = &"ActionOriginSocket"
	action_origin.position = _action_origin_position(item_id)
	root.add_child(action_origin)
	if item_id in [&"greenwood_recurve_bow", &"siege_greatbow"]:
		var launch := Node3D.new()
		launch.name = &"ProjectileLaunchSocket"
		launch.position = Vector3(0.0, 0.0, -0.18 if item_id == &"greenwood_recurve_bow" else -0.24)
		launch.rotation = Vector3(0.0, PI, 0.0)
		root.add_child(launch)
```

Start from the geometry-local readability anchors and tune only toward a real visible surface when the all-body clearance test proves the marker is still inside an animated arm silhouette. The verified positions are: sword `(0, 0.62, 0)`, Fighter/Paladin shields `(0.34, 0.55, 0.18)`, hammer `(0, 0.77, 0)`, Ranger bow `(0, 0.68, 0.03)`, greatbow `(0, 0.72, 0.03)`, daggers `(0, 0.68, 0)`, wand `(0, 0.68, 0)`, focus `(0, 0.08, -0.24)`, staff `(0, 1.05, 0)`, sceptre `(0, 0.72, 0)`, tome/grimoire `(0.19, 0.40, -0.17)`, and quivers `(0, 0.35, 0)`. Move tome/grimoire geometry outward by `-0.08` on local Z so the marker remains on the visible book instead of becoming a test-only point. Add `BackSocket` at `HitPivot/BodyPivot/HipsPivot/TorsoPivot/BackSocket` with local position `(0, 0.12, 0.24)` and make both quiver attachment metadata paths target it.

Change attack profile generation to store `launch_socket_id = &"ProjectileLaunchSocket"`. Update `socket_global_transform()` so simple names resolve first inside equipped main-hand nodes, then off-hand nodes, then the shared model hierarchy.

- [ ] **Step 5: Regenerate and run GREEN**

```powershell
& $godot --headless --path . --script res://tools/build_equipment_assets.gd -- --sets=all
& $godot --headless --path . --script res://tools/build_class_presentation_profiles.gd
& $godot --headless --path . --script res://tests/focused_test_runner.gd -- res://tests/unit/test_held_equipment_readability.gd res://tests/unit/test_playable_class_presentations.gd res://tests/unit/test_specialized_combat_presentation.gd
```

Expected: exit `0`, focused PASS, 18 body/class combinations checked, and no missing-anchor errors.

- [ ] **Step 6: Commit**

```powershell
git add scripts/presentation/equipment_visual_definition.gd scripts/presentation/forge_humanoid_model.gd tools/build_equipment_assets.gd tools/build_shared_humanoid_scene.gd tools/build_class_presentation_profiles.gd scenes/equipment scenes/characters/presentation/forge_humanoid_model.tscn data/presentation/equipment data/presentation/attacks tests/unit/test_held_equipment_readability.gd
git commit -m "fix: enforce readable held equipment anchors"
```

---

### Task 2: Purpose-Built Weapon-Family Actions

**Files:**
- Create: `scripts/presentation/humanoid_animation_authoring.gd`
- Create: `tests/unit/test_humanoid_animation_quality.gd`
- Modify: `tools/build_shared_humanoid_scene.gd`
- Regenerate: `scenes/characters/presentation/forge_humanoid_model.tscn`

**Interfaces:**
- Produces: `HumanoidAnimationAuthoring.build_idle(action_id: StringName) -> Animation`
- Produces: `HumanoidAnimationAuthoring.build_walk(action_id: StringName) -> Animation`
- Produces: `HumanoidAnimationAuthoring.build_attack(action_id: StringName, event_name: StringName) -> Animation`
- Produces: `HumanoidAnimationAuthoring.sample_pose(animation: Animation, time: float) -> Dictionary`

- [ ] **Step 1: Write failing animation-quality tests**

The new suite loads the real humanoid scene and requires:

```gdscript
const IDLES := [&"idle", &"paladin_idle", &"ranger_idle", &"marksman_idle", &"rogue_idle", &"mage_idle", &"frost_mage_idle", &"cleric_idle", &"warlock_idle"]
const ATTACKS := [&"attack_slash", &"paladin_hammer_smite", &"ranger_quick_bow_shot", &"marksman_heavy_bow_shot", &"rogue_dagger_flurry", &"mage_fire_burst", &"frost_staff_shard", &"cleric_lightning_bolt", &"cleric_healing_blessing", &"warlock_chaos_bolt"]

for idle_id: StringName in IDLES:
	_assert_idle_is_guarded(player.get_animation(idle_id), idle_id, failures)
for attack_id: StringName in ATTACKS:
	_assert_attack_has_phases(player.get_animation(attack_id), attack_id, failures)
for index: int in range(1, ATTACKS.size()):
	TestAssertions.truthy(_track_signature(player.get_animation(ATTACKS[index])) != _track_signature(player.get_animation(&"attack_slash")), "%s is not scaled Fighter slash" % ATTACKS[index], failures)
```

`_assert_idle_is_guarded` samples `0`, `25%`, `50%`, `75%`, and `100%`, requires non-identity shoulder/elbow rotations at every sample, requires torso/hips variation of at least `0.015` radians or units, and requires first/last transforms within `0.001`.

`_assert_attack_has_phases` requires at least four distinct pose times; the method event must occur after the first pose and before the last pose; torso plus at least one hip and one arm must change by at least `0.08` radians.

- [ ] **Step 2: Run RED**

Expected failures: existing non-Fighter attacks have signatures derived from `attack_slash`, and some idle/attack phase requirements fail.

- [ ] **Step 3: Implement deterministic authoring**

Implement `HumanoidAnimationAuthoring` around these exact normalized phase times: `0.0` anticipation start, `0.28` loaded anticipation, `0.52` release/impact, `0.76` follow-through, `1.0` recovered pose. Scale them by the existing action durations and keep the existing event times from `build_class_presentation_profiles.gd`.

Use this per-family motion table in Euler radians at the loaded/release/follow-through phases:

| Action | Torso Y | Right shoulder X/Z | Right elbow X/Z | Left shoulder X/Z | Hips/knees |
|---|---:|---:|---:|---:|---|
| Sword | `-0.28/0.34/-0.18` | `-0.85,-0.35 / 0.35,0.70 / 0.10,0.22` | `-0.55,-0.30 / -0.18,0.18 / -0.35,0.08` | `-0.30,0.44 / -0.38,0.34 / -0.26,0.40` | left hip `0.18`, right knee `0.24` at impact |
| Hammer | `-0.16/0.18/-0.10` | `-1.15,-0.20 / 0.48,0.18 / 0.20,0.08` | `-0.72,-0.14 / -0.22,0.04 / -0.44,0.02` | shield guard `-0.36,0.40` | both knees `0.30`, hips down `0.06` at impact |
| Light bow | `0.34/0.18/0.06` | bow arm `-0.42,-0.18` | `-0.18,-0.08` | draw arm `-0.74,0.58` | rear hip `-0.12`, front knee `0.12` |
| Greatbow | `0.42/0.22/0.08` | bow arm `-0.55,-0.22` | `-0.26,-0.10` | draw arm `-1.02,0.72` | hips down `0.08`, knees `0.24/0.18` |
| Daggers | `-0.30/0.32/-0.22` | `-0.62,-0.42 / 0.18,0.50 / -0.38,-0.20` | alternating `-0.44/+0.22` | mirrored | hips `+/-0.22`, knees `0.16` |
| Wand/focus | `-0.22/0.16/-0.08` | wand `-0.54,-0.30 / -0.08,0.36 / -0.24,0.10` | `-0.42/-0.18/-0.30` | focus `-0.38,0.42` | front knee `0.12` |
| Staff | `0.18/-0.12/-0.04` | both shoulders `-0.62,+/-0.30` | both elbows `-0.52,+/-0.18` | same | hips down `0.05`, knees `0.16` |
| Sceptre/tome | `-0.18/0.14/-0.06` | sceptre `-0.58,-0.22 / -0.06,0.30 / -0.22,0.08` | `-0.40/-0.16/-0.28` | tome guard `-0.44,0.38` | front knee `0.10` |
| Healing blessing | `0.0/0.0/0.0` | both shoulders `-0.82,+/-0.48` | both elbows `-0.36,+/-0.22` | same | hips down `0.04`, both knees `0.10` |
| Occult | `0.26/-0.20/-0.12` | wand `-0.74,-0.34 / 0.06,0.40 / -0.28,0.14` | `-0.56/-0.22/-0.38` | grimoire `-0.52,0.36` | rear hip `-0.14`, front knee `0.14` |

Build each action from its own pose table; do not duplicate and time-scale an existing attack. Preserve exact action names and method-event names.

- [ ] **Step 4: Replace scaled-action generation and run GREEN**

Run the scene builder, the new suite, attack-sequence suite, playable-class suite, and full suite with isolated app data. Expected: focused and full PASS; event timing remains valid.

- [ ] **Step 5: Commit**

```powershell
git add scripts/presentation/humanoid_animation_authoring.gd tools/build_shared_humanoid_scene.gd scenes/characters/presentation/forge_humanoid_model.tscn tests/unit/test_humanoid_animation_quality.gd
git commit -m "fix: author distinct class combat animations"
```

---

### Task 3: Grounded Idle and Walk Without Runtime A-Pose

**Files:**
- Modify: `scripts/presentation/humanoid_animation_authoring.gd`
- Modify: `tools/build_shared_humanoid_scene.gd`
- Modify: `tests/unit/test_humanoid_animation_quality.gd`
- Regenerate: `scenes/characters/presentation/forge_humanoid_model.tscn`

**Interfaces:**
- Produces: a shared `walk` with foot-pivot tracks and class idle loops that never sample the source A-pose.

- [ ] **Step 1: Extend the test with grounded-foot assertions**

Sample `walk` at `0.0`, `0.2`, `0.4`, `0.6`, and `0.8` seconds. Require both foot pivots to have tracks; hip rotations must alternate signs; knee rotations must vary by at least `0.12` radians; and at support samples `0.0` and `0.4`, one foot's model-space lowest point must be within `0.015` of the lower foot at time zero.

- [ ] **Step 2: Run RED**

Expected: current walk has no `LeftFootPivot` or `RightFootPivot` tracks and fails support-phase grounding.

- [ ] **Step 3: Implement the walk and guarded idles**

Author a `0.8` second loop with phases:

| Time | Left hip X | Left knee X | Left foot X | Right hip X | Right knee X | Right foot X | Body Y |
|---:|---:|---:|---:|---:|---:|---:|---:|
| `0.0` | `0.42` | `0.12` | `-0.08` | `-0.42` | `0.36` | `0.18` | `0.00` |
| `0.2` | `0.08` | `0.30` | `-0.16` | `-0.08` | `0.18` | `0.08` | `-0.025` |
| `0.4` | `-0.42` | `0.36` | `0.18` | `0.42` | `0.12` | `-0.08` | `0.00` |
| `0.6` | `-0.08` | `0.18` | `0.08` | `0.08` | `0.30` | `-0.16` | `-0.025` |
| `0.8` | same as `0.0` | | | | | | `0.00` |

Counter-rotate torso Y by `+0.08, 0, -0.08, 0, +0.08`; keep elbows bent throughout. Heavy/caster/ranged idle offsets remain separate actions but reuse the same five loop times.

- [ ] **Step 4: Regenerate and run GREEN**

Run the new animation suite, locomotion suite, presentation sandbox smoke, and full suite. Expected: all PASS and no A-pose assertion.

- [ ] **Step 5: Commit**

```powershell
git add scripts/presentation/humanoid_animation_authoring.gd tools/build_shared_humanoid_scene.gd scenes/characters/presentation/forge_humanoid_model.tscn tests/unit/test_humanoid_animation_quality.gd
git commit -m "fix: ground shared humanoid idle and walk"
```

---

### Task 4: Bounded Turning, Ground Calibration, and Contact Shadow

**Files:**
- Modify: `scripts/presentation/forge_humanoid_model.gd`
- Modify: `scripts/presentation/character_presentation.gd`
- Modify: `scripts/characters/party_actor.gd`
- Modify: `scripts/characters/leader.gd`
- Modify: `scripts/characters/companion.gd`
- Modify: `tests/unit/test_character_locomotion_integration.gd`
- Create: `tests/unit/test_character_grounding_and_ui.gd`
- Modify: `tests/integration/character_locomotion_smoke.gd`

**Interfaces:**
- Produces: `CharacterPresentation.advance_visual(delta: float) -> void`
- Produces: `CharacterPresentation.refresh_grounding() -> bool`
- Produces: `CharacterPresentation.visual_bounds() -> AABB`
- Produces: `ForgeHumanoidModel.refresh_grounding() -> bool`
- Produces: `ForgeHumanoidModel.ground_gap() -> float`

- [ ] **Step 1: Rewrite facing assertions to require interpolation**

Update the locomotion test so a rightward request sets `target_yaw == -PI / 2`, leaves the actor root unchanged, and after `advance_visual(0.05)` moves visual yaw by no more than `0.5` radians. Repeated advancement must converge within `0.001`. Add a wraparound case from `PI - 0.05` to `-PI + 0.05` and require the short arc.

Add grounding tests for all 18 class/body combinations: `abs(model.ground_gap()) <= 0.01`; clear and re-equip boots and check again; require a child named `ContactShadow` with `0.002 <= position.y <= 0.01`; require no collision node below the shadow.

- [ ] **Step 2: Run RED**

Expected: instantaneous-yaw assertions fail, grounding/shadow APIs are missing.

- [ ] **Step 3: Implement bounded facing**

Add:

```gdscript
const LOCOMOTION_TURN_RATE := 10.0
const COMBAT_TURN_RATE := 16.0
var target_yaw := 0.0

func advance_visual(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	var rate := COMBAT_TURN_RATE if transient_locked else LOCOMOTION_TURN_RATE
	rotation.y = rotate_toward(rotation.y, target_yaw, rate * delta)

func _face_direction(direction: Vector3) -> void:
	var planar := Vector3(direction.x, 0.0, direction.z)
	if planar.length_squared() <= MOVEMENT_EPSILON_SQUARED:
		return
	target_yaw = wrapf(atan2(-planar.x, -planar.z), -PI, PI)
```

`PartyActor.update_presentation_locomotion(delta := 0.0)` passes velocity and advances the presentation once. Leader and companion pass `_physics_process(delta)` after `move_and_slide()` and pass zero velocity on stationary branches.

- [ ] **Step 4: Implement model-only grounding and shadow**

Use the `ForgeHumanoidModel` root transform as the dedicated grounding transform; it is not animated and preserves every existing `HitPivot/...` path. `refresh_grounding()` resets the model root Y to zero, measures current effective visible bounds, assigns `position.y = -bounds.position.y`, remeasures the gap, and rejects non-finite offsets. Repeated refreshes must be idempotent within `0.001`.

Create `ContactShadow` under `CharacterPresentation` as a flattened `CylinderMesh` radius `0.34`, height `0.008`, with transparent dark material `Color(0.02, 0.02, 0.025, 0.42)`, shadows disabled, and `position.y = 0.006`. Refresh grounding after profile application, body changes, boot/leg equip, and boot/leg clear.

- [ ] **Step 5: Run GREEN**

Run the grounding suite, locomotion suite/smoke, party-actor presentation suite, and full suite. Expected: PASS with exact updated locomotion smoke marker including `smooth_turn=1 grounding=18 shadow=18`.

- [ ] **Step 6: Commit**

Stage only the listed production/test/generated model paths and commit `fix: ground and smoothly turn character presentations`.

---

### Task 5: Health-Bar Clearance and Non-Destructive Hit Feedback

**Files:**
- Modify: `scripts/ui/health_bar_3d.gd`
- Modify: `scripts/presentation/forge_humanoid_model.gd`
- Modify: `tests/unit/test_character_grounding_and_ui.gd`
- Modify: `tests/unit/test_main_wiring.gd`

**Interfaces:**
- Produces: `HealthBar3D.refresh_presentation_anchor() -> void`
- Consumes: `CharacterPresentation.visual_bounds() -> AABB`

- [ ] **Step 1: Add failing bar and material-feedback assertions**

Instantiate every class leader, attach the real bar scene, configure it, and require `bar.position.y >= bounds.position.y + bounds.size.y + 0.12`, where `bounds := presentation.visual_bounds()`. Equip each default helmet and refresh; repeat both bodies. During `set_hit_weight(1.0)`, require every mesh color luminance difference from its base color to remain below `0.55` and saturation to remain above `0.10` for originally colored materials.

- [ ] **Step 2: Run RED**

Expected: fixed bar height intersects one or more model bounds; current full-white lerp violates the palette-preservation assertion.

- [ ] **Step 3: Implement adaptive placement and capped flash**

`HealthBar3D.configure()` calls:

```gdscript
func refresh_presentation_anchor() -> void:
	var actor := get_parent()
	var presentation := actor.get_node_or_null("Presentation") as CharacterPresentation if actor != null else null
	if presentation == null or presentation.active_model == null:
		position.y = 1.35
		return
	var bounds := presentation.visual_bounds()
	position.y = maxf(1.35, bounds.position.y + bounds.size.y + 0.12)
```

Change hit feedback from `base.lerp(Color.WHITE, _hit_weight * 0.7)` to `base.lightened(_hit_weight * 0.35)` and cap emission energy at `0.45`.

- [ ] **Step 4: Run GREEN and commit**

Run focused grounding/UI, main wiring, party presentation, and full suites with isolated app data. Commit `fix: preserve character readability under health and hit UI`.

---

### Task 6: Deterministic All-Class Visual QA Captures

**Files:**
- Create: `tools/render_character_visual_qa.gd`
- Create: `tests/integration/character_visual_quality_smoke.gd`
- Create generated evidence directory: `docs/qa/character-presentation-quality/`

**Interfaces:**
- Produces: `PARTY_FORGE_CHARACTER_VISUAL_QA_OK classes=9 bodies=2 views=4 state_samples=17`
- Produces: PNG contact sheets and `manifest.json` containing class, body, action, sample time, equipment, gap, and clearance.

- [ ] **Step 1: Write the failing smoke runner**

The runner instantiates every class/body, validates ground gap, contact shadow, bar clearance, held-item clearance, required actions, and projectile socket resolution. It exits `1` with `PARTY_FORGE_CHARACTER_VISUAL_QA_ERROR class=... body=... action=... item=... reason=...` on first failure and prints the exact OK marker only after all 18 combinations.

- [ ] **Step 2: Run RED**

Expected: runner fails because the render tool/output manifest does not exist.

- [ ] **Step 3: Implement the renderer**

Use one `SubViewport` at `768x768`, transparent background, MSAA 4x, an orthographic `Camera3D` matching the gameplay elevation, one directional light, ambient environment, and a floor plane with a contrasting side-view floor line. For each class/body capture exactly 17 state samples: idle front/three-quarter/side/rear (4), walk at `0.0/0.2/0.4/0.6` (4), attack at phase start/loaded/release/follow-through/recovery (5), hit (1), hands equipped/cleared (2), and grounding side view (1). The ranged attack release sample must expose the projectile-launch alignment overlay. Restore equipment after comparison captures.

Await `RenderingServer.frame_post_draw` before reading `viewport.get_texture().get_image()`. Save each PNG under `docs/qa/character-presentation-quality/<class>/<body>/`. Build contact sheets with `Image.blit_rect`; reject blank images when visible alpha bounds are empty or cover fewer than 2% of pixels. Write manifest JSON using `JSON.stringify(rows, "  ")`.

- [ ] **Step 4: Run GREEN and inspect images**

Run the smoke headlessly, then run the renderer with hardware rendering:

```powershell
& $godot --headless --path . --script res://tests/integration/character_visual_quality_smoke.gd
& $godot --path . --script res://tools/render_character_visual_qa.gd
```

Open every generated contact sheet with the local image viewer. Reject any A-pose appearance, hovering, foot sliding, equipment/arm silhouette collapse, clipping, bar overlap, blank/cropped frame, or mismatched projectile origin. Record review results in the validation document; do not convert semantic review into a false pixel-only pass.

- [ ] **Step 5: Commit**

Commit renderer, smoke runner, manifest, and reviewed contact sheets as `test: add rendered character presentation quality gate`.

---

### Task 7: Exact Merge-Candidate Verification and Integration

**Files:**
- Create: `docs/qa/2026-08-02-character-presentation-quality-validation.md`
- Review: every branch diff and generated artifact from Tasks 1-6.

- [ ] **Step 1: Rebuild deterministically**

Hash tracked generated character/equipment scenes, run all builders, hash again, rerun builders, and require the second/third hashes to match. Any first/second drift must be reviewed and staged only when it is intended source output.

- [ ] **Step 2: Run complete verification with clean app data**

```powershell
$verifyRoot=(Resolve-Path '.superpowers').Path+'\final-appdata'
New-Item -ItemType Directory -Force -Path $verifyRoot | Out-Null
$env:APPDATA=$verifyRoot
$env:LOCALAPPDATA=$verifyRoot
& $godot --headless --path . --editor --quit
& $godot --headless --path . --script res://tests/test_runner.gd
& $godot --headless --path . --script res://tests/integration/character_presentation_sandbox_runner.gd
& $godot --headless --path . --script res://tests/integration/character_locomotion_smoke.gd
& $godot --headless --path . --script res://tests/integration/character_visual_quality_smoke.gd
& $godot --headless --path . --script res://tools/validate_equipment_icons.gd -- --sets=all
& $godot --path . --script res://tools/render_character_visual_qa.gd
git diff --check
```

Require every command to exit `0`, full `TEST_SUMMARY: PASS`, exact smoke markers, `EQUIPMENT_ICON_VALIDATION_OK`, no unexpected parser/test/visual-QA errors, deterministic output, and reviewed nonblank contact sheets.

- [ ] **Step 3: Record evidence and inspect branch scope**

The validation document records exact commit, command, exit code, marker, generated sheet paths, and semantic review results. Compare main's pre-existing `scenes/game/main.tscn` hash/diff and status before any merge; prove they are unchanged.

- [ ] **Step 4: Commit validation evidence**

```powershell
git add docs/qa/2026-08-02-character-presentation-quality-validation.md
git commit -m "docs: record character presentation quality verification"
```

- [ ] **Step 5: Review and merge only after approval**

Use the finishing-development-branch workflow. Perform an independent branch review, fix Critical/Important findings through new RED/GREEN cycles, rerun the exact merge-candidate verification, then merge locally only if every gate passes. Preserve all unrelated main-checkout changes and report any deferred human gameplay observation separately from automated/rendered proof.
