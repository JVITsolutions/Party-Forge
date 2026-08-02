# Shared Humanoid Locomotion and Facing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the reusable masculine/feminine humanoid and every class derived from it a real walk cycle, movement-direction facing, and deterministic combat-action facing without regressing the Fighter's guard idle or modular sword/shield separation.

**Architecture:** Authored animation data stays in the shared humanoid source and flows through the existing scene builders. `CharacterPresentation` owns visual-only locomotion and facing arbitration; `PartyActor` forwards actual post-collision velocity from `Leader` and `Companion`. Movement never rotates the gameplay actor, collision, navigation, or equipment sockets independently: it rotates only the `CharacterPresentation` root, so attached equipment follows the same animated skeleton while remaining independently equippable scene instances.

**Tech Stack:** Godot 4.7.1, typed GDScript, Godot Resources and TSCN scenes, `AnimationPlayer`, the repository `tests/test_runner.gd` harness, PowerShell, and Git.

## Global Constraints

- Work only in `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\playable-class-presentations` on `feat/playable-class-presentations`.
- Preserve the existing gameplay actor transform, `CharacterBody3D`, capsule collision, navigation, attack executor, fallback mesh, palette isolation, and equipment APIs.
- Model forward is local `-Z`. Cardinal movement must produce these presentation yaws: `-Z = 0`, `+X = -PI / 2`, `+Z = PI`, `-X = PI / 2`.
- Use snap turning for this first pass. Do not add root motion, interpolation, IK, or rotate the actor root.
- Nonzero valid planar velocity selects `walk`; zero velocity selects `idle` and retains the last valid facing.
- During attack, face the supplied live target until that matching action finishes. Store movement updates during the attack and restore the latest locomotion/facing immediately afterward.
- Hit/flinch is transient. Downed state blocks locomotion until revival.
- Invalid/non-finite movement fails closed without changing action or rotation and logs once.
- Never restart the current looping locomotion animation every physics frame.
- Shared/nude scenes must continue to contain no baked weapon or shield. Sword and shield must remain independent resources under `RightHandSocket` and `LeftHandSocket`, must not be descendants of body/arm meshes, and must clear without removing either arm.
- Guard idle and walk must keep both shoulders and elbows out of the neutral A-pose at representative samples.
- Use the non-Mono Godot console executable:

```powershell
$godot = 'C:\Users\Jacob\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe'
$worktree = 'F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\playable-class-presentations'
$env:APPDATA = Join-Path $worktree '.superpowers\test_appdata'
```

- Before tests that load generated/imported assets, warm the hermetic cache with:

```powershell
& $godot --headless --path $worktree --editor --quit-after 1800
```

- Godot import creates `.uid` and `.png.import` sidecars. Inspect them with `git clean -nd -- '*.uid' '*.png.import'`, then remove only those generated sidecars with `git clean -f -- '*.uid' '*.png.import'`. Never clean broader patterns.
- Every task follows RED -> GREEN -> focused verification -> commit. Do not combine implementation tasks in one commit.

---

### Task 1: Author the shared walk cycle and profile contract

**Files:**

- Modify: `scripts/presentation/character_visual_profile.gd`
- Modify: `scripts/presentation/forge_humanoid_model.gd`
- Modify: `tools/build_forge_vanguard_scene.gd`
- Modify: `tools/build_equipment_assets.gd`
- Regenerate: `scenes/characters/presentation/forge_vanguard_body_source.tscn`
- Regenerate: `scenes/characters/presentation/forge_humanoid_model.tscn`
- Regenerate: `scenes/characters/presentation/forge_base_masculine.tscn`
- Regenerate: `scenes/characters/presentation/forge_base_feminine.tscn`
- Regenerate: `data/presentation/profiles/forge_vanguard.tres`
- Regenerate: `data/presentation/profiles/forge_base_masculine.tres`
- Regenerate: `data/presentation/profiles/forge_base_feminine.tres`
- Test: `tests/unit/test_character_visual_data.gd`
- Test: `tests/unit/test_forge_vanguard_animations.gd`
- Test: `tests/unit/test_fighter_modular_assets.gd`

- [ ] **Step 1: Write failing profile-contract tests**

Extend `test_character_visual_data.gd` so a valid profile must declare and validate a dedicated walk action. Detect the property dynamically so the RED run is a normal assertion failure instead of a parser/member-access failure:

```gdscript
var property_names: Array[StringName] = []
for property: Dictionary in profile.get_property_list():
	property_names.append(StringName(property[&"name"]))
var exposes_walk := &"walk_action_id" in property_names
TestAssertions.truthy(exposes_walk, "profile exposes a reusable walk action id", failures)
if exposes_walk:
	profile.set(&"idle_action_id", &"idle")
	profile.set(&"walk_action_id", &"walk")
	profile.required_animation_names = [&"idle", &"walk", &"attack_slash", &"attack_combo", &"hit_flinch"]
	TestAssertions.truthy(profile.validate().is_empty(), "profile accepts required idle and walk actions", failures)
	profile.set(&"walk_action_id", &"missing_walk")
	TestAssertions.truthy(
		profile.validate().has("profile forge_vanguard walk animation missing_walk is missing"),
		"profile rejects an undeclared walk action",
		failures
	)
```

Keep any existing expected missing-scene assertion in a separate profile instance so this new positive assertion remains meaningful.

- [ ] **Step 2: Write failing authored-animation tests**

In `test_forge_vanguard_animations.gd`:

```gdscript
const EXPECTED_LENGTHS := {
	&"idle": 1.6,
	&"walk": 0.8,
	&"attack_slash": 0.55,
	&"attack_combo": 0.9,
	&"hit_flinch": 0.25,
}
```

Assert `walk` exists, uses `Animation.LOOP_LINEAR`, and `play_action(&"walk")` does not queue idle. Add walk-specific samples at `0.0`, `0.2`, `0.4`, and `0.6` seconds that prove:

```gdscript
var left_hip_track := walk.find_track(NodePath("HitPivot/BodyPivot/HipsPivot/LeftHipPivot:rotation"), Animation.TYPE_ROTATION_3D)
var right_hip_track := walk.find_track(NodePath("HitPivot/BodyPivot/HipsPivot/RightHipPivot:rotation"), Animation.TYPE_ROTATION_3D)
var left_knee_track := walk.find_track(NodePath("HitPivot/BodyPivot/HipsPivot/LeftHipPivot/LeftKneePivot:rotation"), Animation.TYPE_ROTATION_3D)
var right_knee_track := walk.find_track(NodePath("HitPivot/BodyPivot/HipsPivot/RightHipPivot/RightKneePivot:rotation"), Animation.TYPE_ROTATION_3D)
```

Required assertions:

- all four leg tracks exist;
- left/right hip rotations oppose each other at quarter-cycle;
- knee flexion alternates between legs;
- `BodyPivot` or `HipsPivot` has a small vertical bob track;
- shoulder and elbow tracks exist and are non-neutral at every representative sample, preventing an A-pose flash;
- no animation targets the shared model root transform.

Also extend `test_fighter_modular_assets.gd` to assert all three profiles expose `walk_action_id == &"walk"`, and rerun its existing nude-model/equipment independence checks unchanged.

- [ ] **Step 3: Run the tests to prove RED**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd
```

Expected: nonzero exit with failures mentioning missing `walk_action_id`, missing `walk`, and/or the new walk track contract. Confirm failures are assertion failures, not parse/import failures.

- [ ] **Step 4: Add the profile field and fail-closed validation**

In `character_visual_profile.gd`, place the new export next to `idle_action_id`:

```gdscript
@export var idle_action_id: StringName = &"idle"
@export var walk_action_id: StringName = &"walk"
```

After idle validation, add:

```gdscript
if walk_action_id.is_empty() or not animation_names.has(walk_action_id):
	errors.append("profile %s walk animation %s is missing" % [id, walk_action_id])
```

Update `build_equipment_assets.gd` so all generated Fighter/base profiles explicitly contain:

```text
idle_action_id = &"idle"
walk_action_id = &"walk"
required_animation_names = [&"idle", &"walk", &"attack_slash", &"attack_combo", &"hit_flinch"]
```

- [ ] **Step 5: Author a reusable in-place walk cycle**

In `build_forge_vanguard_scene.gd`, first include the existing leg pivots in the shared animation system:

```gdscript
func _animated_pivot_ids() -> Array[StringName]:
	return [
		&"hit", &"body", &"torso",
		&"left_shoulder", &"left_elbow", &"right_shoulder", &"right_elbow",
		&"left_hip", &"left_knee", &"right_hip", &"right_knee",
	]
```

Add their exact neutral positions and path mappings:

```gdscript
&"left_hip": Vector3(-0.17, -0.04, 0),
&"left_knee": Vector3(0, -0.38, 0),
&"right_hip": Vector3(0.17, -0.04, 0),
&"right_knee": Vector3(0, -0.38, 0),
```

```gdscript
&"left_hip": return "HitPivot/BodyPivot/HipsPivot/LeftHipPivot"
&"left_knee": return "HitPivot/BodyPivot/HipsPivot/LeftHipPivot/LeftKneePivot"
&"right_hip": return "HitPivot/BodyPivot/HipsPivot/RightHipPivot"
&"right_knee": return "HitPivot/BodyPivot/HipsPivot/RightHipPivot/RightKneePivot"
```

Because `_add_animation` iterates `_animated_pivot_ids`, existing idle/attack/hit animations will gain neutral leg tracks and cannot inherit a stray walk pose.

Then add `walk` through the same `_add_animation` and `_guard_pose` path used by the existing authored animations. Use an in-place, 0.8-second loop with closing pose equal to the opening pose:

```gdscript
_add_animation(library, &"walk", 0.8, true, [
	_guard_pose(0.0,
		{&"body": Vector3(0.0, 0.02, 0.0)},
		{&"left_hip": Vector3(0.42, 0.0, 0.0), &"right_hip": Vector3(-0.42, 0.0, 0.0), &"left_knee": Vector3(0.12, 0.0, 0.0), &"right_knee": Vector3(0.48, 0.0, 0.0), &"left_shoulder": Vector3(0.10, 0.0, -0.08), &"right_shoulder": Vector3(-0.10, 0.0, 0.08)}),
	_guard_pose(0.2,
		{&"body": Vector3(0.0, -0.02, 0.0)},
		{&"left_hip": Vector3.ZERO, &"right_hip": Vector3.ZERO, &"left_knee": Vector3(0.28, 0.0, 0.0), &"right_knee": Vector3(0.20, 0.0, 0.0)}),
	_guard_pose(0.4,
		{&"body": Vector3(0.0, 0.02, 0.0)},
		{&"left_hip": Vector3(-0.42, 0.0, 0.0), &"right_hip": Vector3(0.42, 0.0, 0.0), &"left_knee": Vector3(0.48, 0.0, 0.0), &"right_knee": Vector3(0.12, 0.0, 0.0), &"left_shoulder": Vector3(-0.10, 0.0, -0.08), &"right_shoulder": Vector3(0.10, 0.0, 0.08)}),
	_guard_pose(0.6,
		{&"body": Vector3(0.0, -0.02, 0.0)},
		{&"left_hip": Vector3.ZERO, &"right_hip": Vector3.ZERO, &"left_knee": Vector3(0.20, 0.0, 0.0), &"right_knee": Vector3(0.28, 0.0, 0.0)}),
	_guard_pose(0.8,
		{&"body": Vector3(0.0, 0.02, 0.0)},
		{&"left_hip": Vector3(0.42, 0.0, 0.0), &"right_hip": Vector3(-0.42, 0.0, 0.0), &"left_knee": Vector3(0.12, 0.0, 0.0), &"right_knee": Vector3(0.48, 0.0, 0.0), &"left_shoulder": Vector3(0.10, 0.0, -0.08), &"right_shoulder": Vector3(-0.10, 0.0, 0.08)}),
])
```

Adapt the pivot keys to the builder's exact existing identifiers. Shoulder offsets must be layered on top of `GUARD_ROTATIONS`; elbow rotations must always retain their guard bend. Do not add root translation or forward displacement.

In `forge_humanoid_model.gd`, treat both locomotion loops as persistent actions so walk never queues idle behind itself:

```gdscript
if animation_id not in [&"idle", &"walk"] and player.has_animation(&"idle"):
	player.queue(&"idle")
```

- [ ] **Step 6: Regenerate source, shared, nude, and profile assets**

Run builders in dependency order:

```powershell
& $godot --headless --path $worktree --script res://tools/build_forge_vanguard_scene.gd
& $godot --headless --path $worktree --script res://tools/build_shared_humanoid_scene.gd
& $godot --headless --path $worktree --script res://tools/build_forge_base_body_scenes.gd
& $godot --headless --path $worktree --script res://tools/build_equipment_assets.gd
& $godot --headless --path $worktree --editor --quit-after 1800
```

Expected: every builder exits 0; editor import exits 0; generated profiles include `walk`; generated scenes contain the authored walk animation.

- [ ] **Step 7: Run focused and regression verification**

The repository runner executes every unit suite, so run it and filter the captured output for these suites/contracts:

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd 2>&1 | Tee-Object -FilePath (Join-Path $worktree '.superpowers\task-3b-walk-tests.log')
Select-String -Path (Join-Path $worktree '.superpowers\task-3b-walk-tests.log') -Pattern 'TEST_SUMMARY|TEST_FAILURE|A-pose|independent|walk'
```

Expected: exit 0 and `TEST_SUMMARY: PASS`; no `TEST_FAILURE`. The existing Fighter modular suite must still prove sword/shield separation, independent clearing, nude-model cleanliness, and non-A-pose guard idle.

- [ ] **Step 8: Inspect and clean only generated sidecars**

```powershell
git status --short
git clean -nd -- '*.uid' '*.png.import'
git clean -f -- '*.uid' '*.png.import'
git status --short
```

Expected: only intended scripts, tests, generated `.tscn`/`.tres`, and this task's changes remain.

- [ ] **Step 9: Commit Task 1**

```powershell
git add scripts/presentation/character_visual_profile.gd scripts/presentation/forge_humanoid_model.gd tools/build_forge_vanguard_scene.gd tools/build_equipment_assets.gd scenes/characters/presentation/forge_vanguard_body_source.tscn scenes/characters/presentation/forge_humanoid_model.tscn scenes/characters/presentation/forge_base_masculine.tscn scenes/characters/presentation/forge_base_feminine.tscn data/presentation/profiles/forge_vanguard.tres data/presentation/profiles/forge_base_masculine.tres data/presentation/profiles/forge_base_feminine.tres tests/unit/test_character_visual_data.gd tests/unit/test_forge_vanguard_animations.gd tests/unit/test_fighter_modular_assets.gd
git commit -m "feat: add shared humanoid walk cycle"
```

---

### Task 2: Add presentation locomotion and transient-action arbitration

**Files:**

- Modify: `scripts/presentation/character_presentation.gd`
- Modify: `tests/fixtures/fake_character_model.gd`
- Modify: `tests/unit/test_character_presentation.gd`

- [ ] **Step 1: Expand the fake model for deterministic action completion**

Add the production-compatible signal and playback state:

```gdscript
signal action_finished(action_id: StringName)

var current_action_id: StringName

func play_action(animation_id: StringName) -> bool:
	played.append(animation_id)
	current_action_id = animation_id
	return true

func finish_action(animation_id: StringName) -> void:
	action_finished.emit(animation_id)
```

- [ ] **Step 2: Write failing locomotion/facing tests**

Add focused helpers and cases to `test_character_presentation.gd`. Build each case with `_valid_profile()` declaring `walk_action_id = &"walk"` and `required_animation_names` including walk.

Add `signal action_finished(action_id: StringName)` to the existing `MissingHitWeightModel` and `MissingDownedModel` fixtures too. Their tests must continue to fail for the intended missing method, not for the newly required signal.

Required tests:

```gdscript
TestAssertions.truthy(presentation.update_locomotion(Vector3(0.0, 0.0, -3.0)), "forward locomotion applies", failures)
TestAssertions.equal(model.played.back(), &"walk", "movement starts walk", failures)
TestAssertions.near(presentation.rotation.y, 0.0, 0.001, "-Z faces model forward", failures)

presentation.update_locomotion(Vector3(3.0, 0.0, 0.0))
TestAssertions.near(presentation.rotation.y, -PI / 2.0, 0.001, "+X faces right", failures)

presentation.update_locomotion(Vector3(0.0, 0.0, 3.0))
TestAssertions.near(absf(presentation.rotation.y), PI, 0.001, "+Z faces backward", failures)

presentation.update_locomotion(Vector3(-3.0, 0.0, 0.0))
TestAssertions.near(presentation.rotation.y, PI / 2.0, 0.001, "-X faces left", failures)
```

Also assert:

- `Vector3.ZERO` switches once to idle and preserves the last yaw;
- repeated same-state calls do not append duplicate `walk`/`idle` requests;
- Y velocity is ignored;
- NaN/INF velocity returns `false`, preserves action/yaw, and records only one error key;
- `play_attack(definition, target)` faces target and locks that yaw;
- movement received during attack is stored but does not change yaw or interrupt attack;
- a stale/nonmatching `action_finished` signal does not release the lock;
- the matching completion immediately applies the latest stored movement direction and resumes walk/idle;
- hit/flinch temporarily blocks locomotion changes and matching completion restores locomotion;
- downed blocks locomotion and revival restores the latest valid locomotion state.

Create target fixtures with a live `Node3D` actor and `CombatTarget.new(actor, actor.global_position, team_id)`. Include a freed/unavailable target test: attack should keep current facing rather than throw.

- [ ] **Step 3: Run the suite to prove RED**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd
```

Expected: nonzero exit because `update_locomotion` and transient arbitration do not yet exist.

- [ ] **Step 4: Add presentation state and connect action completion**

Add state near the existing feedback fields:

```gdscript
const MOVEMENT_EPSILON_SQUARED := 0.0001

var latest_planar_velocity := Vector3.ZERO
var last_movement_direction := Vector3.FORWARD
var locomotion_action_id: StringName = &""
var transient_action_id: StringName = &""
var transient_locked := false
var downed_locked := false
```

After instantiating and validating `active_model`, connect its existing signal if available:

```gdscript
if active_model.has_signal(&"action_finished"):
	active_model.connect(&"action_finished", _on_model_action_finished)
else:
	return _fail_active(&"action_finished", "required model signal is missing")
```

Add `&"action_finished"` to the model contract as a required signal check, separate from `REQUIRED_MODEL_METHODS`. Reset all new state in `_clear_model()` and initialize `locomotion_action_id` when `play_idle()` succeeds during profile application.

- [ ] **Step 5: Implement fail-closed locomotion and cardinal facing**

Implement:

```gdscript
func update_locomotion(world_velocity: Vector3) -> bool:
	if not world_velocity.is_finite():
		_log_once(&"invalid_locomotion_velocity", "profile=%s operation=locomotion reason=velocity is not finite" % _profile_id())
		return false
	latest_planar_velocity = Vector3(world_velocity.x, 0.0, world_velocity.z)
	if transient_locked or downed_locked:
		return true
	_apply_latest_locomotion()
	return true

func _apply_latest_locomotion() -> void:
	if active_profile == null or active_model == null:
		return
	var moving := latest_planar_velocity.length_squared() > MOVEMENT_EPSILON_SQUARED
	if moving:
		last_movement_direction = latest_planar_velocity.normalized()
		_face_direction(last_movement_direction)
	var requested := active_profile.walk_action_id if moving else active_profile.idle_action_id
	if requested == locomotion_action_id:
		return
	if play_action(requested):
		locomotion_action_id = requested

func _face_direction(direction: Vector3) -> void:
	var planar := Vector3(direction.x, 0.0, direction.z)
	if planar.length_squared() <= MOVEMENT_EPSILON_SQUARED:
		return
	rotation.y = atan2(-planar.x, -planar.z)
```

The exact atan2 expression must satisfy all four cardinal tests. Do not set the actor's rotation and do not touch X/Z presentation rotation.

- [ ] **Step 6: Arbitrate attack, hit/flinch, and downed state**

Refactor `play_attack` to:

1. resolve the mapped action;
2. face `_target.position - global_position` only if `_target.is_available`, `is_instance_valid(_target.actor)`, and the planar difference is nonzero;
3. start a transient lock only when `play_action(animation_id)` succeeds;
4. leave the current locomotion state intact if the action fails.

Use helpers:

```gdscript
func _begin_transient(animation_id: StringName) -> bool:
	if not play_action(animation_id):
		return false
	transient_action_id = animation_id
	transient_locked = true
	return true

func _on_model_action_finished(animation_id: StringName) -> void:
	if not transient_locked or animation_id != transient_action_id:
		return
	transient_locked = false
	transient_action_id = &""
	locomotion_action_id = &""
	if not downed_locked:
		_apply_latest_locomotion()
```

Make `flash_hit()` call `_begin_transient(&"hit_flinch")`. In `set_downed(true)`, set `downed_locked = true` before forwarding to the model. In `set_downed(false)`, clear it, reset `locomotion_action_id`, and call `_apply_latest_locomotion()`. A downed transition supersedes any pending transient lock.

- [ ] **Step 7: Run focused/full regression verification**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd 2>&1 | Tee-Object -FilePath (Join-Path $worktree '.superpowers\task-3b-arbitration-tests.log')
Select-String -Path (Join-Path $worktree '.superpowers\task-3b-arbitration-tests.log') -Pattern 'TEST_SUMMARY|TEST_FAILURE|locomotion|attack|downed'
```

Expected: exit 0, `TEST_SUMMARY: PASS`, no `TEST_FAILURE`. Confirm existing Fighter attack executor and hit/down/revival presentation assertions still pass.

- [ ] **Step 8: Clean generated sidecars and commit Task 2**

```powershell
git clean -nd -- '*.uid' '*.png.import'
git clean -f -- '*.uid' '*.png.import'
git status --short
git add scripts/presentation/character_presentation.gd tests/fixtures/fake_character_model.gd tests/unit/test_character_presentation.gd
git commit -m "feat: arbitrate character locomotion and facing"
```

---

### Task 3: Wire actual movement velocity and add end-to-end safeguards

**Files:**

- Modify: `scripts/characters/party_actor.gd`
- Modify: `scripts/characters/leader.gd`
- Modify: `scripts/characters/companion.gd`
- Modify: `tests/unit/test_leader_movement.gd`
- Modify: `tests/unit/test_party_actor_presentation.gd`
- Create: `tests/unit/test_character_locomotion_integration.gd`
- Create: `tests/integration/character_locomotion_smoke.gd`

- [ ] **Step 1: Write failing actor-bridge tests**

In `test_party_actor_presentation.gd`, extend `PresentationProbe`:

```gdscript
var locomotion_requests: Array[Vector3] = []

func update_locomotion(world_velocity: Vector3) -> bool:
	locomotion_requests.append(world_velocity)
	return true
```

Add a test for a public/protected bridge method on `PartyActor`:

```gdscript
actor.velocity = Vector3(2.0, 0.0, -1.0)
actor.update_presentation_locomotion()
TestAssertions.equal(probe.locomotion_requests, [Vector3(2.0, 0.0, -1.0)], "actor forwards actual velocity", failures)
```

In `test_leader_movement.gd`, statically assert the leader and companion scripts call `update_presentation_locomotion()` after `move_and_slide()` and on stationary/downed early returns. This guards the exact integration points even when Input/navigation are hard to drive in a unit test.

- [ ] **Step 2: Write the failing integration suite**

Create `test_character_locomotion_integration.gd` that instantiates a configured Fighter leader and directly exercises the bridge with actual `velocity` values. Assert:

- forward/right/back/left velocities rotate only `Presentation`, never the `PartyActor` root;
- movement selects `walk` and zero velocity returns to the bent guard idle;
- equipment remains attached to the correct hand sockets through all cardinal turns;
- the sword and shield nodes remain distinct from every arm/body mesh;
- clearing the sword preserves the right arm and shield; clearing the shield preserves the left arm;
- an attack target overrides movement facing until `action_finished`, then the latest movement direction wins;
- downed velocity cannot start walk, and revival applies the stored state.

Use the real `forge_vanguard` profile and real `ForgeHumanoidModel`; do not use the fake model for this integration suite.

- [ ] **Step 3: Run tests to prove RED**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd
```

Expected: nonzero exit because the `PartyActor` bridge and movement call sites do not exist.

- [ ] **Step 4: Add the shared PartyActor bridge**

In `party_actor.gd`:

```gdscript
func update_presentation_locomotion() -> void:
	var presentation := _presentation()
	if presentation != null and presentation.active_profile != null:
		presentation.update_locomotion(velocity)
```

This method only forwards current velocity. It must not derive input direction, change the actor transform, or couple movement to a specific class/profile.

- [ ] **Step 5: Forward post-slide and stationary velocity from both controllers**

In `leader.gd`:

```gdscript
if get_tree().paused or (health != null and (health.is_downed or health.is_dead)):
	velocity = Vector3.ZERO
	update_presentation_locomotion()
	return
var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
velocity = LeaderMovement.velocity(input_vector, move_speed)
move_and_slide()
update_presentation_locomotion()
```

In `companion.gd`, call `update_presentation_locomotion()` after every assignment of stationary `Vector3.ZERO` before returning, and once immediately after `move_and_slide()`. The forwarded value must be the actual `CharacterBody3D.velocity` after collision response, not the desired pre-slide vector.

- [ ] **Step 6: Run the full unit suite**

```powershell
& $godot --headless --path $worktree --editor --quit-after 1800
& $godot --headless --path $worktree --script res://tests/test_runner.gd 2>&1 | Tee-Object -FilePath (Join-Path $worktree '.superpowers\task-3b-full-tests.log')
```

Expected: exit 0 and `TEST_SUMMARY: PASS` with one more suite than the pre-task baseline; no parser, import, leak, or `TEST_FAILURE` messages.

- [ ] **Step 7: Add a deterministic smoke runner**

Create `tests/integration/character_locomotion_smoke.gd` as a `SceneTree` script. It must instantiate the real configured Fighter leader, apply each cardinal/zero velocity through `update_presentation_locomotion()`, exercise attack completion and equipment clearing, and fail with `push_error`/exit 1 on any mismatch. On success print exactly:

```text
PARTY_FORGE_LOCOMOTION_SMOKE_OK directions=4 walk=1 idle=1 attack_lock=1 equipment_independent=1
```

Run it:

```powershell
& $godot --headless --path $worktree --script res://tests/integration/character_locomotion_smoke.gd
```

Expected: exit 0 and the exact smoke marker.

- [ ] **Step 8: Perform live visual QA**

Launch the existing playable main/sandbox with hardware rendering. Do not use `--headless` for this check because dummy rendering cannot visually validate a walk cycle:

```powershell
Start-Process -FilePath $godot.Replace('_console.exe', '.exe') -ArgumentList @('--path', $worktree, '--windowed', '--resolution', '1280x720')
```

In the running game verify and record evidence for:

1. Fighter starts in bent guard idle, never neutral A-pose.
2. Continuous movement loops walk without visible restarts.
3. Releasing movement returns to guard idle and retains facing.
4. Four cardinal directions visibly turn the model correctly.
5. Fighter faces an attack target until the slash finishes, then resumes movement facing.
6. Sword and shield follow their animated hand sockets but visibly remain distinct objects; neither replaces or duplicates an arm.
7. Down/revival does not leave the model frozen in A-pose or walking.

Do not report this step passed without an actual rendered observation. If live control is unavailable, report this step deferred while retaining the automated smoke evidence.

- [ ] **Step 9: Run final regression gates and clean sidecars**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd
& $godot --headless --path $worktree --script res://tests/integration/character_locomotion_smoke.gd
git clean -nd -- '*.uid' '*.png.import'
git clean -f -- '*.uid' '*.png.import'
git status --short
git diff --check
```

Expected: unit suite PASS, exact locomotion smoke marker, clean diff check, and only intended Task 3 files staged/unstaged.

- [ ] **Step 10: Commit Task 3**

```powershell
git add scripts/characters/party_actor.gd scripts/characters/leader.gd scripts/characters/companion.gd tests/unit/test_leader_movement.gd tests/unit/test_party_actor_presentation.gd tests/unit/test_character_locomotion_integration.gd tests/integration/character_locomotion_smoke.gd
git commit -m "feat: wire party locomotion facing"
```

---

### Task 4: Final independent review and handoff

**Files:**

- Review: all files changed since `9b8cc5d`
- Update if needed: `.superpowers/sdd/progress.md` (local ignored ledger only)

- [ ] **Step 1: Request an independent spec/code review**

Reviewer must compare the implementation against:

- `docs/superpowers/specs/2026-08-01-shared-humanoid-locomotion-facing-design.md`
- this implementation plan;
- the user's explicit requirements: real walk, no A-pose fallback, movement-direction facing, attack target lock, and separate arms/weapons/shield;
- the reusable-body/class pipeline constraint.

Review the complete diff:

```powershell
git diff --stat 9b8cc5d..HEAD
git diff 9b8cc5d..HEAD
```

Critical/Important findings must be fixed with new RED tests and separate fix commits, then re-reviewed.

- [ ] **Step 2: Run final clean-room verification**

Use the hermetic APPDATA, warm imports, run the entire unit suite, run the locomotion smoke, then inspect status:

```powershell
$env:APPDATA = Join-Path $worktree '.superpowers\test_appdata'
& $godot --headless --path $worktree --editor --quit-after 1800
& $godot --headless --path $worktree --script res://tests/test_runner.gd
& $godot --headless --path $worktree --script res://tests/integration/character_locomotion_smoke.gd
git clean -nd -- '*.uid' '*.png.import'
git clean -f -- '*.uid' '*.png.import'
git diff --check
git status --short
```

Expected: all processes exit 0, `TEST_SUMMARY: PASS`, exact `PARTY_FORGE_LOCOMOTION_SMOKE_OK ...` marker, no whitespace errors, and a clean worktree.

- [ ] **Step 3: Record the handoff**

Record commit IDs, suite count, smoke marker, live-QA status/evidence, reviewer disposition, and any explicitly deferred visual issue in `.superpowers/sdd/progress.md`. Do not claim live QA if only headless automation ran.

The handoff must state that this movement contract is now shared by the reusable masculine/feminine humanoid; later Ranger, Mage, Gunslinger, and other class equipment/animation sets should reuse the same presentation bridge while supplying their own authored locomotion style through profile action mappings.
