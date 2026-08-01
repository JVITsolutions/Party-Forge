# Modular Character Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a reusable Godot-native humanoid presentation system and the first Forge Vanguard Fighter model with two body presets, three palettes, PoE 1-style equipment readability, and four in-place animations.

**Architecture:** Existing `CharacterBody3D` scenes remain gameplay-owned wrappers with their capsule collision and direct fallback mesh. An optional typed `CharacterVisualProfile` activates a `CharacterPresentation` adapter, which owns a modular model, per-instance materials, equipment visual channels, and animation playback. The first model is generated reproducibly from Godot primitive meshes; a later Blender-authored GLB can replace its internals behind the same adapter contract.

**Tech Stack:** Godot 4.7.1, typed GDScript, Godot Resources and TSCN scenes, `AnimationPlayer`, StandardMaterial3D, the repository `tests/test_runner.gd` harness, PowerShell, and Git worktrees.

## Global Constraints

- Work from `F:\Projects(root)\Game dev\Projects\party-forge`; never write to `E:\Projects\Test_Game_01` or `.worktrees/playtest-corrections`.
- At execution time, use the `using-git-worktrees` skill and create `.worktrees/modular-fighter-presentation` on branch `feature/modular-fighter-presentation` from the newest safe `main`.
- Before Task 5, require the playtest-corrections branch to be merged or explicitly rebase onto the newest `main`; never overwrite its `party_actor.gd` combat changes.
- Use `F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe` for command-line import and tests.
- Keep the current actor root, groups, collision layer `2`, collision mask `1`, capsule collision, health, attack controller, movement, targeting, and runtime health-bar contract unchanged.
- Keep the direct `MeshInstance3D` as the fallback visual for classes without a valid profile.
- Do not add inventory, item statistics, affixes, sockets, equipment UI, root motion, or a real multi-hit Fighter attack.
- The equipment registry contains exactly `main_hand`, `off_hand`, `helmet`, `body_armour`, `gloves`, `boots`, `belt`, `amulet`, `ring_left`, and `ring_right` in this milestone.
- The required animations are exactly `idle`, `attack_slash`, `attack_combo`, and `hit_flinch`; all remain in place.
- `fighter_cleave` maps only to `attack_slash`; `attack_combo` is preview-only until gameplay has a true multi-hit attack.
- Presentation failures begin with `PARTY_FORGE_PRESENTATION_ERROR` and never stop combat.
- Do not install Blender as part of this plan. Preserve the documented Blender/glTF scale, orientation, socket, and animation-name contract.
- Use test-first development, explicit staged paths, `git diff --check`, and one bounded commit per task.

## Execution Preflight

Run these commands before Task 1:

```powershell
$repo = 'F:\Projects(root)\Game dev\Projects\party-forge'
$worktree = Join-Path $repo '.worktrees\modular-fighter-presentation'
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
git -C $repo status --short
git -C $repo worktree list --porcelain
git -C $repo log -3 --oneline
```

Expected: `main` is clean, commit `4d1f173` or a descendant contains the approved design, and the playtest worktree is listed separately.

After invoking the worktree skill, create or reuse only the named branch/worktree, then record a baseline:

```powershell
& $godot --headless --path $worktree --import
& $godot --headless --path $worktree --script res://tests/test_runner.gd --quit-after 120
git -C $worktree status --short
```

Expected: import exits `0`. Prefer a fully passing suite from the merged playtest baseline. If the playtest branch is not merged and the historical two Rogue range assertions still fail, record their exact messages, continue only through Task 4, and do not claim final completion or begin Task 5.

## File Map

### Typed presentation data

- `scripts/presentation/equipment_slot_catalog.gd`: authoritative ten-slot registry.
- `scripts/presentation/equipment_visual_definition.gd`: one slot's geometry/material/effect readability declaration.
- `scripts/presentation/character_visual_profile.gd`: presentation scene, bodies, palettes, default equipment, and attack-animation mapping.
- `scripts/data/class_definition.gd`: optional visual profile reference and validation bridge.

### Runtime presentation

- `scripts/presentation/character_presentation.gd`: stable adapter used by gameplay wrappers.
- `scripts/presentation/forge_vanguard_model.gd`: Forge Vanguard model implementation behind the adapter.
- `scenes/characters/presentation/character_presentation.tscn`: adapter host instanced by leader and companion.
- `scenes/characters/presentation/forge_vanguard_model.tscn`: generated native low-poly model and animations.
- `tools/build_forge_vanguard_scene.gd`: deterministic source recipe for the native model scene.

### Content

- `data/presentation/equipment/forge_vanguard_*.tres`: ten slot visual definitions.
- `data/presentation/profiles/forge_vanguard.tres`: Fighter presentation profile.
- `data/classes/fighter.tres`: optional profile link.

### Integration and review

- `scenes/characters/leader.tscn`: add adapter host without changing gameplay children.
- `scenes/characters/companion.tscn`: same adapter host contract.
- `scripts/characters/party_actor.gd`: route profile, attack, flash, downed, and revival presentation events.
- `scripts/dev/character_presentation_sandbox.gd`: review controls and deterministic presets.
- `scenes/dev/character_presentation_sandbox.tscn`: two-model high-angle review scene.
- `tests/integration/character_presentation_sandbox_runner.gd`: headless visual-state smoke test.
- `docs/handbook/08-visuals-audio-effects-and-ui.md`: replace the documented direct-mesh limitation with the adapter contract.

### Tests

- `tests/unit/test_character_visual_data.gd`: slot, equipment, profile, and class validation.
- `tests/unit/test_character_presentation.gd`: adapter success, fallback, palette isolation, and bounded errors.
- `tests/fixtures/fake_character_model.gd` and `.tscn`: deterministic adapter fixture.
- `tests/unit/test_forge_vanguard_model.gd`: geometry, bodies, slots, material regions, and dimensions.
- `tests/unit/test_forge_vanguard_animations.gd`: animation names, durations, looping, and root-transform invariants.
- `tests/unit/test_party_actor_presentation.gd`: production Fighter integration and gameplay preservation.
- `tests/unit/test_character_presentation_sandbox.gd`: sandbox scene contract.

---

### Task 1: Define the Typed Visual-Data Contracts

**Files:**
- Create: `scripts/presentation/equipment_slot_catalog.gd`
- Create: `scripts/presentation/equipment_visual_definition.gd`
- Create: `scripts/presentation/character_visual_profile.gd`
- Modify: `scripts/data/class_definition.gd:6-24,37-49`
- Create: `tests/unit/test_character_visual_data.gd`

**Interfaces:**
- Produces: `EquipmentSlotCatalog.is_valid(slot_id: StringName) -> bool`
- Produces: `EquipmentVisualDefinition.validate() -> PackedStringArray`
- Produces: `CharacterVisualProfile.validate() -> PackedStringArray`
- Produces: `ClassDefinition.visual_profile: CharacterVisualProfile`

- [ ] **Step 1: Write the failing visual-data test**

Create `tests/unit/test_character_visual_data.gd` with a `run()` method that executes these exact assertions:

```gdscript
extends RefCounted

const EXPECTED_SLOTS: Array[StringName] = [
	&"main_hand", &"off_hand", &"helmet", &"body_armour", &"gloves",
	&"boots", &"belt", &"amulet", &"ring_left", &"ring_right",
]

func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.equal(EquipmentSlotCatalog.SLOT_IDS, EXPECTED_SLOTS, "PoE 1 visual slot order", failures)
	for slot_id: StringName in EXPECTED_SLOTS:
		TestAssertions.truthy(EquipmentSlotCatalog.is_valid(slot_id), "registered slot %s" % slot_id, failures)
	TestAssertions.truthy(not EquipmentSlotCatalog.is_valid(&"charm"), "future charm slot is rejected", failures)

	var sword := EquipmentVisualDefinition.new()
	sword.id = &"forge_vanguard_sword"
	sword.slot_id = &"main_hand"
	sword.geometry_key = &"forge_vanguard_sword"
	sword.visual_channels = [&"geometry"]
	TestAssertions.equal(sword.validate(), PackedStringArray(), "valid sword visual", failures)

	var invalid := EquipmentVisualDefinition.new()
	invalid.id = &"invalid_charm"
	invalid.slot_id = &"charm"
	TestAssertions.truthy(invalid.validate().size() >= 2, "invalid slot and empty channels are rejected", failures)

	var profile := CharacterVisualProfile.new()
	profile.id = &"forge_vanguard"
	profile.default_body_preset = &"masculine"
	profile.default_palette_id = &"red"
	profile.palette_colors = {&"red": Color("d94f4f"), &"blue": Color("4f78d9"), &"green": Color("4faf72")}
	profile.default_equipment_visuals = [sword]
	profile.required_animation_names = [&"idle", &"attack_slash", &"attack_combo", &"hit_flinch"]
	profile.attack_animation_by_id = {&"fighter_cleave": &"attack_slash"}
	TestAssertions.truthy(profile.validate().has("profile forge_vanguard presentation scene is missing"), "scene is required", failures)

	var class_definition := ClassDefinition.new()
	class_definition.id = &"test"
	class_definition.display_name = "Test"
	class_definition.traits = [&"martial"]
	class_definition.primary_attack = _valid_attack()
	class_definition.visual_profile = profile
	TestAssertions.truthy(class_definition.validate().any(func(reason: String) -> bool: return "visual profile" in reason), "class forwards profile validation", failures)
	return failures

func _valid_attack() -> AttackDefinition:
	var component := AttackDamageComponent.new()
	component.damage_type_id = &"physical"
	component.base_amount = 1.0
	var attack := AttackDefinition.new()
	attack.id = &"test_attack"
	attack.cooldown = 1.0
	attack.range = 1.0
	attack.damage_components = [component]
	return attack
```

- [ ] **Step 2: Run the suite and verify the contract is absent**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd --quit-after 120
```

Expected: FAIL while parsing or resolving `EquipmentSlotCatalog`, `EquipmentVisualDefinition`, and `CharacterVisualProfile`.

- [ ] **Step 3: Implement the slot registry and typed Resources**

Create `equipment_slot_catalog.gd` with the exact ordered array and membership helper:

```gdscript
class_name EquipmentSlotCatalog
extends RefCounted

const SLOT_IDS: Array[StringName] = [
	&"main_hand", &"off_hand", &"helmet", &"body_armour", &"gloves",
	&"boots", &"belt", &"amulet", &"ring_left", &"ring_right",
]

static func is_valid(slot_id: StringName) -> bool:
	return slot_id in SLOT_IDS
```

Create `equipment_visual_definition.gd`:

```gdscript
class_name EquipmentVisualDefinition
extends Resource

@export var id: StringName
@export var slot_id: StringName
@export var geometry_key: StringName
@export var visual_channels: Array[StringName] = []

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty(): errors.append("equipment visual id is empty")
	if not EquipmentSlotCatalog.is_valid(slot_id): errors.append("equipment visual %s slot %s is invalid" % [id, slot_id])
	if visual_channels.is_empty(): errors.append("equipment visual %s has no visual channels" % id)
	var seen: Dictionary = {}
	for channel: StringName in visual_channels:
		if channel.is_empty() or seen.has(channel): errors.append("equipment visual %s has an empty or duplicate channel" % id)
		seen[channel] = true
	return errors
```

Create `character_visual_profile.gd`:

```gdscript
class_name CharacterVisualProfile
extends Resource

const BODY_PRESETS: Array[StringName] = [&"masculine", &"feminine"]

@export var id: StringName
@export var presentation_scene: PackedScene
@export var default_body_preset: StringName = &"masculine"
@export var default_palette_id: StringName = &"red"
@export var palette_colors: Dictionary = {}
@export var default_equipment_visuals: Array[EquipmentVisualDefinition] = []
@export var required_animation_names: Array[StringName] = [&"idle"]
@export var attack_animation_by_id: Dictionary = {}

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("profile id is empty")
	if presentation_scene == null:
		errors.append("profile %s presentation scene is missing" % id)
	if default_body_preset not in BODY_PRESETS:
		errors.append("profile %s body preset %s is invalid" % [id, default_body_preset])
	if not palette_colors.has(default_palette_id):
		errors.append("profile %s default palette %s is missing" % [id, default_palette_id])
	for palette_id: Variant in palette_colors:
		if StringName(palette_id).is_empty() or typeof(palette_colors[palette_id]) != TYPE_COLOR:
			errors.append("profile %s palette %s is invalid" % [id, palette_id])
	var equipment_slots: Dictionary = {}
	for definition: EquipmentVisualDefinition in default_equipment_visuals:
		if definition == null:
			errors.append("profile %s has null equipment visual" % id)
			continue
		for reason: String in definition.validate():
			errors.append("profile %s %s" % [id, reason])
		if equipment_slots.has(definition.slot_id):
			errors.append("profile %s has duplicate equipment slot %s" % [id, definition.slot_id])
		equipment_slots[definition.slot_id] = true
	var animation_names: Dictionary = {}
	for animation_id: StringName in required_animation_names:
		if animation_id.is_empty() or animation_names.has(animation_id):
			errors.append("profile %s has empty or duplicate animation" % id)
		animation_names[animation_id] = true
	if not animation_names.has(&"idle"):
		errors.append("profile %s idle animation is missing" % id)
	for attack_id: Variant in attack_animation_by_id:
		var animation_id := StringName(attack_animation_by_id[attack_id])
		if StringName(attack_id).is_empty() or not animation_names.has(animation_id):
			errors.append("profile %s attack mapping %s -> %s is invalid" % [id, attack_id, animation_id])
	return errors
```

Add this property to `ClassDefinition` after `name_pool`:

```gdscript
@export var visual_profile: CharacterVisualProfile
```

Append to `ClassDefinition.validate()`:

```gdscript
	if visual_profile != null:
		for reason: String in visual_profile.validate():
			errors.append("class %s visual profile %s" % [id, reason])
```

- [ ] **Step 4: Import and run the complete suite**

```powershell
& $godot --headless --path $worktree --editor --quit-after 2
& $godot --headless --path $worktree --script res://tests/test_runner.gd --quit-after 120
```

Expected: all visual-data assertions pass and no pre-existing suite regresses.

- [ ] **Step 5: Commit Task 1**

```powershell
git -C $worktree add -- scripts/presentation/equipment_slot_catalog.gd scripts/presentation/equipment_visual_definition.gd scripts/presentation/character_visual_profile.gd scripts/data/class_definition.gd tests/unit/test_character_visual_data.gd
git -C $worktree diff --cached --check
git -C $worktree commit -m 'feat: define character visual data contracts'
```

---

### Task 2: Add the Stable CharacterPresentation Adapter

**Files:**
- Create: `scripts/presentation/character_presentation.gd`
- Create: `scenes/characters/presentation/character_presentation.tscn`
- Create: `tests/fixtures/fake_character_model.gd`
- Create: `tests/fixtures/fake_character_model.tscn`
- Create: `tests/unit/test_character_presentation.gd`

**Interfaces:**
- Consumes: `CharacterVisualProfile`
- Produces: `apply_profile(profile: CharacterVisualProfile, primary_color: Color) -> bool`
- Produces: `set_body_preset(preset_id: StringName) -> bool`
- Produces: `set_palette(palette_id: StringName, primary_color: Color) -> bool`
- Produces: `apply_equipment_visual(slot_id: StringName, definition: EquipmentVisualDefinition) -> bool`
- Produces: `play_attack(definition: AttackDefinition, target: CombatTarget = null) -> void`
- Produces: `play_action(animation_id: StringName) -> bool`
- Produces: `flash_hit()`, `advance_feedback(delta: float)`, and `set_downed(is_downed: bool)`

- [ ] **Step 1: Write a fake model and failing adapter tests**

The fixture model exposes the same methods the future GLB wrapper will expose and records calls in public fields:

```gdscript
class_name FakeCharacterModel
extends Node3D

var body_preset := &""
var palette_id := &""
var primary_color := Color.WHITE
var equipped: Dictionary = {}
var played: Array[StringName] = []
var downed := false
var hit_weight := 0.0

func set_body_preset(value: StringName) -> bool: body_preset = value; return value in [&"masculine", &"feminine"]
func set_palette(value: StringName, color: Color) -> bool: palette_id = value; primary_color = color; return true
func apply_equipment_visual(slot_id: StringName, definition: EquipmentVisualDefinition) -> bool: equipped[slot_id] = definition.id; return true
func play_action(animation_id: StringName) -> bool: played.append(animation_id); return true
func set_hit_weight(value: float) -> void: hit_weight = value
func set_downed(value: bool) -> void: downed = value
```

`test_character_presentation.gd` must pack or load the fixture scene, build a valid profile, call `apply_profile`, and assert body, palette, equipment, `fighter_cleave -> attack_slash`, hit weight restoration after `advance_feedback(0.11)`, downed forwarding, fallback visibility on invalid profile, and independent model/material state across two adapter instances.

- [ ] **Step 2: Run the suite and verify the adapter is missing**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd --quit-after 120
```

Expected: FAIL because `CharacterPresentation` and its scene do not exist.

- [ ] **Step 3: Implement the adapter with bounded failure logging**

Create `character_presentation.gd` with this state and public flow:

```gdscript
class_name CharacterPresentation
extends Node3D

const HIT_DURATION := 0.1

@export var fallback_mesh_path: NodePath
var active_profile: CharacterVisualProfile
var active_model: Node3D
var active_palette_id: StringName
var hit_remaining := 0.0
var logged_errors: Dictionary = {}

func apply_profile(profile: CharacterVisualProfile, primary_color: Color) -> bool:
	_clear_model()
	active_profile = null
	_set_fallback_visible(true)
	if profile == null:
		return false
	var errors := profile.validate()
	if not errors.is_empty():
		_log_once(&"invalid_profile", "profile=%s operation=apply reason=%s" % [profile.id, errors[0]])
		return false
	active_model = profile.presentation_scene.instantiate() as Node3D
	if active_model == null:
		_log_once(&"invalid_scene", "profile=%s operation=instantiate reason=root is not Node3D" % profile.id)
		return false
	add_child(active_model)
	active_profile = profile
	if not _call_bool(&"set_body_preset", [profile.default_body_preset]): return _fail_active(&"body", "body preset rejected")
	active_palette_id = profile.default_palette_id
	if not _call_bool(&"set_palette", [active_palette_id, primary_color]): return _fail_active(&"palette", "palette rejected")
	for definition: EquipmentVisualDefinition in profile.default_equipment_visuals:
		if not _call_bool(&"apply_equipment_visual", [definition.slot_id, definition]):
			_log_once(StringName("slot_%s" % definition.slot_id), "profile=%s operation=equipment slot=%s reason=visual rejected" % [profile.id, definition.slot_id])
	_set_fallback_visible(false)
	play_action(&"idle")
	return true
```

Implement `_call_bool`, `_clear_model`, `_fail_active`, `_set_fallback_visible`, and `_log_once`. `_log_once` must use `push_error("PARTY_FORGE_PRESENTATION_ERROR %s" % detail)` once per key. `play_attack` looks up `definition.id` in `active_profile.attack_animation_by_id` and otherwise stays in idle. `flash_hit()` sets `hit_remaining = HIT_DURATION`, calls `set_hit_weight(1.0)`, and requests `hit_flinch`. `advance_feedback()` clamps the timer and restores hit weight to `0.0`. `set_downed()` forwards the state.

The three public customization methods validate active state and delegate through `_call_bool`. `set_palette` updates `active_palette_id` only after the model accepts the palette. `apply_equipment_visual` rejects a slot/definition mismatch before calling the model. These methods are the only sandbox and future equipment-system entry points.

Create `character_presentation.tscn` as a `Node3D` root with this script; the actor wrapper supplies `fallback_mesh_path = NodePath("../MeshInstance3D")` when it instances the scene.

- [ ] **Step 4: Run import and tests**

```powershell
& $godot --headless --path $worktree --editor --quit-after 2
& $godot --headless --path $worktree --script res://tests/test_runner.gd --quit-after 120
```

Expected: adapter tests pass; valid fixture calls produce no presentation errors.

- [ ] **Step 5: Commit Task 2**

```powershell
git -C $worktree add -- scripts/presentation/character_presentation.gd scenes/characters/presentation/character_presentation.tscn tests/fixtures/fake_character_model.gd tests/fixtures/fake_character_model.tscn tests/unit/test_character_presentation.gd
git -C $worktree diff --cached --check
git -C $worktree commit -m 'feat: add character presentation adapter'
```

---

### Task 3: Build the Static Forge Vanguard Model and Equipment Layers

**Files:**
- Create: `scripts/presentation/forge_vanguard_model.gd`
- Create: `tools/build_forge_vanguard_scene.gd`
- Generate: `scenes/characters/presentation/forge_vanguard_model.tscn`
- Create: ten `data/presentation/equipment/forge_vanguard_*.tres` files
- Create: `data/presentation/profiles/forge_vanguard.tres`
- Create: `tests/unit/test_forge_vanguard_model.gd`

**Interfaces:**
- Produces: a model root implementing every method consumed by `CharacterPresentation`
- Produces: model metadata `body_preset`, `palette_region`, and `equipment_visual_id`
- Produces: one valid `CharacterVisualProfile` with both bodies and three palettes

- [ ] **Step 1: Write the failing model-contract test**

Load the profile and model scene, then assert:

```gdscript
var profile := load("res://data/presentation/profiles/forge_vanguard.tres") as CharacterVisualProfile
TestAssertions.truthy(profile != null, "Forge Vanguard profile loads", failures)
TestAssertions.equal(profile.palette_colors.keys().size(), 3, "three palettes", failures)
var model := profile.presentation_scene.instantiate() as Node3D
TestAssertions.truthy(model.has_method(&"set_body_preset"), "model implements body API", failures)
TestAssertions.truthy(model.call(&"set_body_preset", &"masculine"), "masculine body resolves", failures)
TestAssertions.truthy(model.call(&"set_body_preset", &"feminine"), "feminine body resolves", failures)
for slot_id: StringName in EquipmentSlotCatalog.SLOT_IDS:
	TestAssertions.truthy(model.call(&"has_equipment_slot", slot_id), "model exposes %s" % slot_id, failures)
var bounds: AABB = model.call(&"visual_bounds") as AABB
TestAssertions.truthy(bounds.size.y >= 1.6 and bounds.size.y <= 1.85, "humanoid height fits actor scale", failures)
TestAssertions.near(bounds.position.y, 0.0, 0.05, "model feet begin at local floor", failures)
model.free()
```

Also assert that each of the ten equipment Resources validates, has the expected slot ID, and declares at least one visual channel.

- [ ] **Step 2: Run the suite and verify the model assets are absent**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd --quit-after 120
```

Expected: FAIL because the profile, model scene, and equipment Resources do not exist.

- [ ] **Step 3: Implement the model script and deterministic scene recipe**

`forge_vanguard_model.gd` must scan descendants once in `_ready()` and cache nodes by metadata. Every public method also calls `_ensure_cache()` so unit tests and editor tooling work before the model enters a SceneTree. Its core selection behavior is:

```gdscript
class_name ForgeVanguardModel
extends Node3D

const BODY_PRESETS: Array[StringName] = [&"masculine", &"feminine"]
var body_nodes: Dictionary = {}
var palette_meshes: Dictionary = {}
var equipment_nodes: Dictionary = {}
var base_material_colors: Dictionary = {}

func set_body_preset(preset_id: StringName) -> bool:
	_ensure_cache()
	if preset_id not in BODY_PRESETS: return false
	for id: StringName in body_nodes:
		for node: Node3D in body_nodes[id]: node.visible = id == preset_id
	return true

func set_palette(palette_id: StringName, primary_color: Color) -> bool:
	_ensure_cache()
	if palette_id not in [&"red", &"blue", &"green"]: return false
	for mesh: MeshInstance3D in palette_meshes.get(&"primary", []):
		_assign_unique_color(mesh, primary_color)
	return true

func apply_equipment_visual(slot_id: StringName, definition: EquipmentVisualDefinition) -> bool:
	_ensure_cache()
	if not EquipmentSlotCatalog.is_valid(slot_id): return false
	for node: Node3D in equipment_nodes.get(slot_id, []):
		node.visible = StringName(node.get_meta(&"equipment_visual_id", &"")) == definition.geometry_key
	return true

func has_equipment_slot(slot_id: StringName) -> bool:
	_ensure_cache()
	return equipment_nodes.has(slot_id)
```

Implement `visual_bounds() -> AABB` by merging each visible `MeshInstance3D` transformed AABB in model-local space. The builder/test contract uses it only for visual scale and floor-origin verification; gameplay collision never reads it.

The deterministic builder must create this pivot hierarchy with model feet at local `y = 0.0`: `HitPivot`, `BodyPivot`, `HipsPivot`, `TorsoPivot`, `HeadPivot`, left/right shoulder, elbow, hand socket, hip, knee, and foot pivots. `CharacterPresentation` later positions the model host at `y = -0.75` below the actor origin.

Use primitive meshes with these readable bounds:

- Total body height: `1.70 m`.
- Shoulder width: masculine `0.82 m`, feminine `0.72 m`.
- Head centre: `y = 1.52 m`; boot sole: `y = 0.0 m`.
- Shield diameter: `0.68 m`; sword total length: `0.92 m`.
- Primary shoulder plates extend the equipped silhouette to approximately `0.96 m`.

Every created MeshInstance3D receives `palette_region` metadata (`primary`, `metal`, `brass`, `leather`, or `skin`). Body alternatives receive `body_preset`. Equipment roots receive `equipment_slot` and `equipment_visual_id`. Rings and amulet use small emission/emblem meshes rather than literal high-detail jewelry.

Run the builder with:

```powershell
& $godot --headless --path $worktree --script res://tools/build_forge_vanguard_scene.gd
```

Expected: `FORGE_VANGUARD_BUILD_OK path=res://scenes/characters/presentation/forge_vanguard_model.tscn` and exit `0`.

- [ ] **Step 4: Author the ten equipment Resources and profile**

Create exactly these IDs and channels:

```text
forge_vanguard_sword      main_hand   [geometry]
forge_vanguard_shield     off_hand    [geometry]
forge_vanguard_helmet     helmet      [geometry, silhouette]
forge_vanguard_armour     body_armour [geometry, silhouette, palette]
forge_vanguard_gauntlets  gloves      [geometry, palette]
forge_vanguard_boots      boots       [geometry, palette]
forge_vanguard_belt       belt        [geometry, palette]
forge_vanguard_amulet     amulet      [emission, emblem]
forge_vanguard_ring_left  ring_left   [emission]
forge_vanguard_ring_right ring_right  [emission]
```

The profile defaults to masculine/red, requires all four animation names, equips sword through belt, exposes jewelry definitions for sandbox toggles, and contains `{&"fighter_cleave": &"attack_slash"}` as its only attack mapping.

- [ ] **Step 5: Import and run tests**

```powershell
& $godot --headless --path $worktree --import
& $godot --headless --path $worktree --script res://tests/test_runner.gd --quit-after 120
```

Expected: model/resource tests pass, scene parses, and the complete suite has no new failure.

- [ ] **Step 6: Commit Task 3**

```powershell
git -C $worktree add -- scripts/presentation/forge_vanguard_model.gd tools/build_forge_vanguard_scene.gd scenes/characters/presentation/forge_vanguard_model.tscn data/presentation tests/unit/test_forge_vanguard_model.gd
git -C $worktree diff --cached --check
git -C $worktree commit -m 'feat: build modular Forge Vanguard model'
```

---

### Task 4: Add the Four In-Place Animations

**Files:**
- Modify: `tools/build_forge_vanguard_scene.gd`
- Regenerate: `scenes/characters/presentation/forge_vanguard_model.tscn`
- Modify: `scripts/presentation/forge_vanguard_model.gd`
- Create: `tests/unit/test_forge_vanguard_animations.gd`

**Interfaces:**
- Produces: `play_action(animation_id: StringName) -> bool`
- Produces: `set_hit_weight(value: float) -> void`
- Produces: AnimationLibrary entries `idle`, `attack_slash`, `attack_combo`, `hit_flinch`

- [ ] **Step 1: Write failing animation metadata and root-invariance tests**

The new test loads `AnimationPlayer` from the generated scene and asserts exact names, approximate lengths with `0.02` tolerance, idle looping, action clips not looping, and no track targeting the model root's `position`, `rotation`, `transform`, or `global_transform`.

```gdscript
var expected := {&"idle": 1.6, &"attack_slash": 0.55, &"attack_combo": 0.9, &"hit_flinch": 0.25}
for animation_id: StringName in expected:
	TestAssertions.truthy(player.has_animation(animation_id), "animation exists: %s" % animation_id, failures)
	if player.has_animation(animation_id):
		var animation := player.get_animation(animation_id)
		TestAssertions.near(animation.length, expected[animation_id], 0.02, "%s duration" % animation_id, failures)
		TestAssertions.equal(animation.loop_mode == Animation.LOOP_LINEAR, animation_id == &"idle", "%s loop contract" % animation_id, failures)
```

- [ ] **Step 2: Run the suite and verify animation names are absent**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd --quit-after 120
```

Expected: FAIL on the four missing animations.

- [ ] **Step 3: Add deterministic tracks and playback**

Extend the builder with helpers that add `TYPE_POSITION_3D` and `TYPE_ROTATION_3D` tracks only to named pivots. Use these key moments:

```text
idle:         0.00 neutral, 0.40 inhale/up, 0.80 weight left, 1.20 inhale/down, 1.60 neutral
attack_slash: 0.00 guard, 0.12 wind-up right, 0.28 broad left cleave, 0.42 recovery, 0.55 guard
attack_combo: 0.00 guard, 0.14 sword wind-up, 0.30 slash, 0.48 recover, 0.62 shield wind-up, 0.74 shield thrust, 0.90 guard
hit_flinch:   0.00 neutral, 0.07 recoil back, 0.15 shield/shoulder response, 0.25 neutral
```

Animate `BodyPivot`, `TorsoPivot`, shoulders, elbows, and `HitPivot`; never animate the scene root. `play_action()` rejects unknown IDs, starts the requested clip, and queues `idle` after non-looping clips. `set_hit_weight()` modulates a separate material emission/tint response without changing the actor transform.

- [ ] **Step 4: Regenerate, import, and test**

```powershell
& $godot --headless --path $worktree --script res://tools/build_forge_vanguard_scene.gd
& $godot --headless --path $worktree --editor --quit-after 2
& $godot --headless --path $worktree --script res://tests/test_runner.gd --quit-after 120
```

Expected: four animation tests pass and `fighter_cleave` remains mapped only to the slash.

- [ ] **Step 5: Commit Task 4**

```powershell
git -C $worktree add -- tools/build_forge_vanguard_scene.gd scenes/characters/presentation/forge_vanguard_model.tscn scripts/presentation/forge_vanguard_model.gd tests/unit/test_forge_vanguard_animations.gd
git -C $worktree diff --cached --check
git -C $worktree commit -m 'feat: animate the Forge Vanguard'
```

---

### Task 5: Integrate Fighter Presentation Without Changing Combat

**Files:**
- Modify: `data/classes/fighter.tres`
- Modify: `scenes/characters/leader.tscn`
- Modify: `scenes/characters/companion.tscn`
- Modify: `scripts/characters/party_actor.gd:24-40,197-212,245-286`
- Modify: `tests/unit/test_leader_movement.gd:69-85`
- Create: `tests/unit/test_party_actor_presentation.gd`

**Interfaces:**
- Consumes: `ClassDefinition.visual_profile` and `CharacterPresentation`
- Preserves: all current `PartyActor` combat methods and signal paths
- Produces: Fighter profile activation, slash trigger, hit/flinch, downed, revival, and capsule fallback

- [ ] **Step 1: Enforce the parallel-branch integration gate**

```powershell
git -C $repo status --short
git -C $worktree status --short
git -C $worktree rebase main
$playtestBranch = 'refs/heads/feature/playtest-corrections'
git -C $repo show-ref --verify --quiet $playtestBranch
if ($LASTEXITCODE -eq 0) {
  git -C $repo merge-base --is-ancestor $playtestBranch main
  if ($LASTEXITCODE -ne 0) { throw 'playtest-corrections is not merged into main; defer PartyActor integration' }
}
git -C $worktree diff main...HEAD -- scripts/characters/party_actor.gd
```

Expected: worktree is rebased, the playtest branch is either absent or already contained by `main`, and no unresolved conflict exists.

- [ ] **Step 2: Write failing production-integration tests**

`test_party_actor_presentation.gd` must instantiate both leader and companion scenes and assert:

- The direct fallback mesh and `CharacterPresentation` child both exist.
- Fighter configuration activates Forge Vanguard and hides the fallback.
- Ranger configuration leaves the fallback visible because Ranger has no profile.
- Leader collision shape remains capsule radius `0.45`, height `1.5`; companion remains radius `0.4`, height `1.4`.
- Fighter `AttackController.attack_ready` requests `attack_slash` once while `AttackExecutor` still receives the existing attack.
- `attack_combo` is not requested by `fighter_cleave`.
- Damage starts actor `damage_flash_remaining`, requests `hit_flinch`, and restores the red palette.
- Downed and revived signals forward presentation state.
- Two Fighters can use red and blue instance-local palettes without recoloring each other.

- [ ] **Step 3: Run tests and verify production actors still lack presentation wiring**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd --quit-after 120
```

Expected: FAIL because actor scenes do not yet own the adapter and Fighter does not link the profile.

- [ ] **Step 4: Add adapter hosts and Fighter profile linkage**

Instance `character_presentation.tscn` as direct child `Presentation` in both actor scenes and set `fallback_mesh_path = NodePath("../MeshInstance3D")`. Do not rename or remove any existing node.

Add the Forge Vanguard profile as an `ext_resource` in `fighter.tres` and set:

```text
visual_profile = ExtResource("<forge_vanguard_profile_id>")
```

- [ ] **Step 5: Route PartyActor visual events through the adapter**

Add a typed helper:

```gdscript
func _presentation() -> CharacterPresentation:
	return get_node_or_null("Presentation") as CharacterPresentation
```

During `configure`, call `presentation.apply_profile(definition.visual_profile, definition.color)` when the adapter exists. Keep `_set_visual_color` as the fallback-mesh path when activation returns false.

In `_ensure_combat_runtime`, keep the existing executor connection and add one presentation connection to the primary controller:

```gdscript
var visual_attack := Callable(self, "_on_visual_attack_ready")
if primary != null and not primary.attack_ready.is_connected(visual_attack):
	primary.attack_ready.connect(visual_attack)
```

Implement `_on_visual_attack_ready(definition: AttackDefinition, target: CombatTarget)` to call `presentation.play_attack(definition, target)` only. Do not delay, cancel, or call `AttackExecutor` from this method.

For health signals, call `flash_hit`, `set_downed(true)`, and `set_downed(false)` when presentation is active; retain current fallback color behavior otherwise. Call `presentation.advance_feedback(delta)` from `_advance_visual_feedback` so hit material restoration stays synchronized with the existing `0.1` second actor timer.

- [ ] **Step 6: Update the existing actor scene contract and run all tests**

Extend `test_leader_movement.gd` to require both `MeshInstance3D` and `Presentation`; preserve every collision and component assertion.

```powershell
& $godot --headless --path $worktree --import
& $godot --headless --path $worktree --script res://tests/test_runner.gd --quit-after 120
```

Expected: full PASS. No Rogue baseline failures are acceptable after the required playtest merge gate.

- [ ] **Step 7: Commit Task 5**

```powershell
git -C $worktree add -- data/classes/fighter.tres scenes/characters/leader.tscn scenes/characters/companion.tscn scripts/characters/party_actor.gd tests/unit/test_leader_movement.gd tests/unit/test_party_actor_presentation.gd
git -C $worktree diff --cached --check
git -C $worktree commit -m 'feat: integrate Fighter character presentation'
```

---

### Task 6: Add the Presentation Review Sandbox

**Files:**
- Create: `tools/build_forge_base_body_scenes.gd`
- Generate: `scenes/characters/presentation/forge_base_masculine.tscn`
- Generate: `scenes/characters/presentation/forge_base_feminine.tscn`
- Create: `data/presentation/profiles/forge_base_masculine.tres`
- Create: `data/presentation/profiles/forge_base_feminine.tres`
- Create: `tests/unit/test_forge_base_bodies.gd`
- Create: `scripts/dev/character_presentation_sandbox.gd`
- Create: `scenes/dev/character_presentation_sandbox.tscn`
- Create: `tests/unit/test_character_presentation_sandbox.gd`
- Create: `tests/integration/character_presentation_sandbox_runner.gd`

**Interfaces:**
- Produces: separately openable masculine and feminine unequipped base-body scenes using the exact Forge Vanguard pivot contract
- Produces: valid base-body profiles with empty default equipment and all ten visuals available for later class-specific layering
- Produces: `set_body(preset_id)`, `set_palette(palette_id)`, `toggle_slot(slot_id, enabled)`, `play_clip(animation_id)`, and `trigger_hit()` review controls
- Produces: success marker `PARTY_FORGE_PRESENTATION_SMOKE_OK`

- [ ] **Step 1: Package the two reusable unequipped base bodies test-first**

Write a failing test for `forge_base_masculine.tscn`, `forge_base_feminine.tscn`, and their matching profiles. Each scene must load directly in Godot, retain the same named shared pivots and public model API as `forge_vanguard_model.tscn`, select only its named body preset, show no equipment root by default, remain floor-aligned at the established actor scale, and preserve neutral stylized mannequin coverage without explicit anatomy. Each profile must validate with an empty `default_equipment_visuals`, expose all ten `available_equipment_visuals`, and select the matching preset.

Implement `tools/build_forge_base_body_scenes.gd` by instantiating the deterministic Forge Vanguard model, selecting the requested body preset, hiding every equipment root, packing the result, and applying the same stable-output normalization used by the main builder. These are reusable Godot model files, not screenshots or sandbox-only fixtures: another class task must be able to open either scene/profile and layer Ranger, Mage, Gunslinger, or other class equipment onto the unchanged pivot contract.

Run the base-body generator twice and require identical hashes for both output scenes before proceeding.

- [ ] **Step 2: Write failing sandbox scene and API tests**

The unit test requires a scene root scripted as `CharacterPresentationSandbox`, nodes `Models/Masculine`, `Models/Feminine`, `FallbackCapsule`, `CameraRig/Camera3D`, `DirectionalLight3D`, `Floor`, and `UI/Instructions`. It calls each review method and confirms two models maintain different palette IDs.

- [ ] **Step 3: Run the suite and verify the sandbox is absent**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd --quit-after 120
```

Expected: FAIL because the sandbox scene and script do not exist.

- [ ] **Step 4: Build the review scene**

Use a `Node3D` root, a neutral floor, directional light, and the production high-angle framing (`Camera3D` position near `Vector3(0, 6.5, 6.0)`, rotation near `Vector3(-0.87, 0, 0)`, FOV `52`). Place masculine/red and feminine/blue Forge Vanguards side by side, with one capsule behind them for silhouette comparison. The sandbox must also be able to switch each side between its unequipped base profile and equipped Forge Vanguard profile so the base files can be visually reviewed without changing production state.

The UI instructions must list:

```text
1/2 Body   R/B/G Palette   I Idle   A Slash   C Combo   H Hit
Q/E Cycle Slot   Space Toggle Selected Slot
```

Input handling calls the public review methods; it does not alter input-map settings or production run state.

- [ ] **Step 5: Add the headless smoke runner**

The runner loads the scene, calls `_ready`, exercises both bodies, all three palettes, all ten slot toggles, all four clips, hit feedback, downed, and revival, then prints exactly:

```gdscript
print("PARTY_FORGE_PRESENTATION_SMOKE_OK bodies=2 palettes=3 slots=10 animations=4")
quit(0)
```

Any missing scene, rejected operation, or invalid state must call `push_error("PARTY_FORGE_PRESENTATION_SMOKE_ERROR ...")` and `quit(1)`.

- [ ] **Step 6: Run unit and integration verification**

```powershell
& $godot --headless --path $worktree --script res://tools/build_forge_base_body_scenes.gd
& $godot --headless --path $worktree --editor --quit-after 2
& $godot --headless --path $worktree --script res://tests/test_runner.gd --quit-after 120
& $godot --headless --path $worktree --script res://tests/integration/character_presentation_sandbox_runner.gd --quit-after 30
```

Expected: full unit PASS and the exact smoke success marker.

- [ ] **Step 7: Commit Task 6**

```powershell
git -C $worktree add -- tools/build_forge_base_body_scenes.gd scenes/characters/presentation/forge_base_masculine.tscn scenes/characters/presentation/forge_base_feminine.tscn data/presentation/profiles/forge_base_masculine.tres data/presentation/profiles/forge_base_feminine.tres tests/unit/test_forge_base_bodies.gd scripts/dev/character_presentation_sandbox.gd scenes/dev/character_presentation_sandbox.tscn tests/unit/test_character_presentation_sandbox.gd tests/integration/character_presentation_sandbox_runner.gd
git -C $worktree diff --cached --check
git -C $worktree commit -m 'feat: add character presentation sandbox'
```

---

### Task 7: Update the Handbook and Capture Completion Evidence

**Files:**
- Modify: `docs/handbook/08-visuals-audio-effects-and-ui.md`
- Verify: all files from Tasks 1-6

**Interfaces:**
- Documents: adapter boundary, fallback behavior, equipment visual channels, native generator, and Blender replacement path

- [ ] **Step 1: Update the handbook from the implemented truth**

Replace the current limitation about direct `MeshInstance3D`-only presentation with the implemented adapter flow. Document exact resource paths, including the separate masculine and feminine unequipped base-body scenes/profiles, the ten slots, the rule that every equipped item changes at least one visual channel, material duplication, the sandbox launch path, and the later Blender/glTF socket/animation contract. Record that the first draft is generated in-project and has no external art-license dependency. Keep the original warnings about gameplay wrapper ownership and collision separation.

Name the deferred Blender paths exactly `assets/models/characters/source/party_forge_humanoid.blend` and `assets/models/characters/party_forge_humanoid.glb`. Reiterate one metre per Godot unit, Y-up, feet at source origin, normalized forward orientation below the gameplay root, shared humanoid armature, semantic sockets, and exact animation-name preservation.

- [ ] **Step 2: Run the bounded final command matrix and save console evidence**

```powershell
$evidence = Join-Path $worktree 'docs\validation\evidence'
New-Item -ItemType Directory -Force -Path $evidence | Out-Null
& $godot --headless --path $worktree --import 2>&1 | Tee-Object -FilePath (Join-Path $evidence '2026-07-31-forge-vanguard-import.log')
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
& $godot --headless --path $worktree --script res://tests/test_runner.gd --quit-after 120 2>&1 | Tee-Object -FilePath (Join-Path $evidence '2026-07-31-forge-vanguard-tests.log')
if ($LASTEXITCODE -ne 0) { throw 'unit suite failed' }
& $godot --headless --path $worktree --script res://tests/integration/character_presentation_sandbox_runner.gd --quit-after 30 2>&1 | Tee-Object -FilePath (Join-Path $evidence '2026-07-31-forge-vanguard-smoke.log')
if ($LASTEXITCODE -ne 0) { throw 'presentation smoke failed' }
git -C $worktree diff --check
git -C $worktree status --short
```

Expected: import exit `0`, `TEST_SUMMARY: PASS`, smoke success marker, clean diff check, and only intentional handbook/evidence changes uncommitted.

- [ ] **Step 3: Perform live Godot visual QA without mutating the other task's worktree**

Open `res://scenes/dev/character_presentation_sandbox.tscn` in the connected Godot editor or a separately launched editor pointed at this worktree. Capture and inspect:

- High-angle view with masculine/red, feminine/blue, and capsule comparison.
- Close view showing sword, shield, helmet, body armour, gloves, boots, belt, and jewelry readability channels.
- Red/blue palette isolation on simultaneous instances.
- Idle, slash, combo, and flinch playback.
- Hit flash restoration, downed gray, and revival color.

Then read editor and game logs with details. Expected: no new parser, import, runtime, or `PARTY_FORGE_PRESENTATION_ERROR` entries during valid interactions.

- [ ] **Step 4: Review final scope and commit documentation/evidence**

```powershell
rg -n -i 'TO[D]O|TB[D]|FI[X]ME|X[X]X|implement lat[e]r|fill in detai[l]s' scripts/presentation scripts/dev/character_presentation_sandbox.gd tests/unit/test_character_* tests/unit/test_forge_vanguard_* tests/integration/character_presentation_sandbox_runner.gd docs/handbook/08-visuals-audio-effects-and-ui.md
git -C $worktree diff --stat main...HEAD
git -C $worktree diff --name-only main...HEAD | Sort-Object
git -C $worktree add -- docs/handbook/08-visuals-audio-effects-and-ui.md docs/validation/evidence/2026-07-31-forge-vanguard-import.log docs/validation/evidence/2026-07-31-forge-vanguard-tests.log docs/validation/evidence/2026-07-31-forge-vanguard-smoke.log
git -C $worktree diff --cached --check
git -C $worktree commit -m 'docs: record Forge Vanguard validation'
git -C $worktree status --short
```

Expected: scan returns no unfinished markers, changed paths remain within this plan, the final commit succeeds, and the worktree is clean.

## Completion Gate

Do not report completion until all of these are simultaneously true:

- Both body presets and all three palettes are visible and verified.
- Separate masculine and feminine unequipped base-body scenes and profiles are directly reusable and verified with no visible equipment.
- All ten equipment slots produce a declared readability channel.
- `idle`, `attack_slash`, `attack_combo`, and `hit_flinch` exist with the specified in-place durations.
- Fighter uses the Forge Vanguard profile; classes without profiles still render the fallback capsule.
- Fighter cleave triggers only the slash and combat damage timing is unchanged.
- Hit flash is instance-local and restores the correct palette.
- Actor collision and gameplay node contracts are unchanged.
- Import, full suite, integration smoke, diff check, and Godot logs are clean.
- The implementation contains no changes from `.worktrees/playtest-corrections` except commits already merged into its base.
- The Blender replacement contract remains documented and no Blender installation was performed.
