# Playable Class Model and Equipment Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver reusable masculine/feminine Godot-native presentations for all nine playable classes, 99 independently addressable equipment entries with matching icons, and animation-event-synchronized combat execution.

**Architecture:** Extend the existing `CharacterPresentation` boundary instead of changing gameplay-owned actor wrappers. Gameplay-facing `EquipmentBaseDefinition` resources link to `EquipmentVisualDefinition` resources; the shared humanoid instantiates independent item scenes at stable sockets and selects attacks by equipped weapon family. A tokenized `AttackSequenceController` sits between target selection and `AttackExecutor`, allowing damage, projectile, and healing execution exactly once at an authored animation event.

**Tech Stack:** Godot 4.7.1, GDScript, `.tres` resources, packed `.tscn` scenes, `AnimationPlayer` method tracks, `SubViewport` icon rendering, PowerShell, Git.

## Global Constraints

- Work only in the authoritative checkout rooted at `F:\Projects(root)\Game dev\Projects\party-forge`.
- At execution time, use `superpowers:using-git-worktrees`; branch from the then-current `main` only after `feat/profile-persistence-foundation` is integrated or explicitly deferred.
- Preserve the gameplay-owned `CharacterBody3D`, collision shapes, health, attack controllers, groups, movement, fallback capsule visuals, and party behavior.
- Preserve the exact existing masculine and feminine body proportions and the Fighter's low-poly primitive language.
- Use matte materials near roughness `0.78`; keep metal restrained and item colors item-owned, with class color applied only through the wearer-accent channel.
- The sheet slot order is `helmet`, `body_armour`, `legs`, `gloves`, `boots`, `amulet`, `ring_left`, `ring_right`, `belt`, `main_hand`, `off_hand`.
- Produce 87 new class items plus 12 normalized Fighter entries, for exactly 99 catalog entries.
- Every item has a transparent 256x256 master icon and 128x128 runtime icon; runtime rarity and restriction UI is never baked into pixels.
- `AttackDefinition.cooldown` remains start-to-next-start cadence; do not rebalance damage, range, speed, area, tags, or crit data in this presentation milestone.
- A required release/impact event executes combat exactly once; missing, duplicate, or stale events use `PARTY_FORGE_ATTACK_SEQUENCE_ERROR` and never cause early invisible execution.
- Root movement remains enabled unless a future action explicitly declares movement lock. Ordinary hit/flinch feedback does not cancel attacks.
- Do not add locomotion, skeletal retargeting, Blender shape keys, inventory transaction UI, implicit rolls, rarity frames, or equipment-stat resolution.
- Keep both reusable unequipped body scenes as final handoff assets and preserve a later Blender/GLB replacement path.
- Preserve unrelated dirty files, especially `scenes/game/main.tscn` and the existing currency `.png.import` files.

---

## Canonical Content Manifest

The generator and tests use this exact manifest. The item index determines the sheet slot using `EquipmentSlotCatalog.SLOT_IDS`; Frost Mage omits `off_hand`, and Fighter adds the hammer after its eleven default entries.

```gdscript
const SET_ITEM_IDS := {
	&"paladin": [&"dawn_bulwark_crown", &"dawn_bulwark_plate", &"dawn_bulwark_greaves", &"dawn_bulwark_gauntlets", &"dawn_bulwark_sabatons", &"sun_oath_amulet", &"ring_of_vigil", &"ring_of_mercy", &"dawn_bulwark_belt", &"sunforged_warhammer", &"dawn_bulwark_shield"],
	&"ranger": [&"greenwood_hood", &"greenwood_jerkin", &"greenwood_leggings", &"greenwood_gloves", &"greenwood_boots", &"trailmark_amulet", &"hawkeye_band", &"windrunner_band", &"greenwood_belt", &"greenwood_recurve_bow", &"greenwood_light_quiver"],
	&"marksman": [&"siege_archer_cowl", &"siege_archer_coat", &"siege_archer_braced_leggings", &"siege_archer_draw_glove", &"siege_archer_boots", &"farshot_amulet", &"steady_hand_ring", &"long_watch_ring", &"siege_archer_draw_belt", &"siege_greatbow", &"siege_heavy_quiver"],
	&"rogue": [&"nightstep_hood", &"nightstep_leathers", &"nightstep_leggings", &"nightstep_grip_gloves", &"nightstep_soft_boots", &"shadowchain_amulet", &"silent_edge_ring", &"bloodstep_ring", &"nightstep_utility_belt", &"nightstep_dagger_main", &"nightstep_dagger_off"],
	&"mage": [&"emberweave_circlet", &"emberweave_robe", &"emberweave_leggings", &"emberweave_spell_gloves", &"emberweave_shoes", &"emberheart_amulet", &"cinder_ring", &"conflagration_ring", &"emberweave_rune_sash", &"emberweave_wand", &"emberweave_flame_focus"],
	&"frost_mage": [&"rime_scholar_circlet", &"rime_scholar_robe", &"rime_scholar_leggings", &"rime_scholar_gloves", &"rime_scholar_boots", &"winterglass_amulet", &"hoarfrost_ring", &"stillwater_ring", &"rime_scholar_crystal_sash", &"rime_scholar_staff"],
	&"cleric": [&"storm_chaplain_hood", &"storm_chaplain_vestments", &"storm_chaplain_leggings", &"storm_chaplain_prayer_gloves", &"storm_chaplain_boots", &"storm_chaplain_reliquary", &"storm_ring", &"mercy_ring", &"storm_chaplain_belt", &"storm_chaplain_sceptre", &"storm_chaplain_holy_tome"],
	&"warlock": [&"grave_covenant_hood", &"grave_covenant_robe", &"grave_covenant_leggings", &"grave_covenant_ritual_gloves", &"grave_covenant_wrapped_boots", &"grave_covenant_bone_amulet", &"withering_ring", &"pact_ring", &"grave_covenant_chained_sash", &"grave_covenant_bone_wand", &"grave_covenant_grimoire"],
	&"fighter": [&"forge_vanguard_helmet", &"forge_vanguard_armour", &"forge_vanguard_greaves", &"forge_vanguard_gauntlets", &"forge_vanguard_boots", &"forge_vanguard_amulet", &"forge_vanguard_ring_left", &"forge_vanguard_ring_right", &"forge_vanguard_belt", &"forge_vanguard_sword", &"forge_vanguard_shield", &"forge_vanguard_hammer"],
}
```

The class-set totals must remain `11 + 11 + 11 + 11 + 11 + 10 + 11 + 11 = 87`; Fighter contributes `12`.

### Task 1: Equipment Contracts, Eligibility, and Catalog Foundation

**Files:**
- Create: `scripts/equipment/equipment_base_definition.gd`
- Create: `scripts/equipment/equipment_catalog.gd`
- Create: `scripts/equipment/equipment_eligibility.gd`
- Create: `scripts/equipment/equipment_loadout_entry.gd`
- Create: `data/equipment/core_equipment_catalog.tres` (empty validated migration catalog)
- Create: `tools/class_equipment_rows.gd`
- Create: `tests/focused_test_runner.gd`
- Create: `tests/unit/test_equipment_contract.gd`
- Modify: `scripts/presentation/equipment_visual_definition.gd`
- Modify: `scripts/data/game_catalog.gd`

**Interfaces:**
- Consumes: `ClassDefinition.normalized_eligibility_tags() -> Array[StringName]` and the canonical manifest above.
- Produces: `EquipmentBaseDefinition.validate() -> PackedStringArray`, `EquipmentLoadoutEntry.validate() -> PackedStringArray`, `EquipmentCatalog.definition(id) -> EquipmentBaseDefinition`, `EquipmentEligibility.validate_equip(item, class_definition, requested_slot_id, loadout, attributes) -> PackedStringArray`, and expanded `EquipmentVisualDefinition.validate() -> PackedStringArray`.

- [ ] **Step 1: Add a focused runner and a failing equipment-contract suite**

```gdscript
# tests/focused_test_runner.gd
extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var suites := OS.get_cmdline_user_args()
	for suite_path: String in suites:
		var script := load(suite_path) as Script
		if script == null:
			failures.append("%s :: suite failed to load" % suite_path)
			continue
		for failure: String in (script.new() as RefCounted).call(&"run"):
			failures.append("%s :: %s" % [suite_path, failure])
	for failure: String in failures:
		push_error("TEST_FAILURE: %s" % failure)
	print("TEST_SUMMARY: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
```

```gdscript
# tests/unit/test_equipment_contract.gd
extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists("res://scripts/equipment/equipment_base_definition.gd"), "equipment base contract exists", failures)
	TestAssertions.truthy(ResourceLoader.exists("res://scripts/equipment/equipment_eligibility.gd"), "eligibility service exists", failures)
	TestAssertions.equal(ClassEquipmentRows.total_item_count(), 99, "canonical item manifest count", failures)
	var ring := ClassEquipmentRows.make_base(&"ring_of_vigil", &"ring_left")
	TestAssertions.equal(ring.compatible_slot_ids, [&"ring_left", &"ring_right"], "rings fit either ring slot", failures)
	var staff := ClassEquipmentRows.make_base(&"rime_scholar_staff", &"main_hand")
	TestAssertions.equal(staff.reserved_slot_ids, [&"off_hand"], "staff reserves offhand", failures)
	return failures
```

- [ ] **Step 2: Run the focused suite and verify the red state**

Run:

```powershell
$godot = 'C:\Users\Jacob\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe'
& $godot --headless --path . --script res://tests/focused_test_runner.gd -- res://tests/unit/test_equipment_contract.gd
```

Expected: non-zero exit with a missing `ClassEquipmentRows`/equipment contract failure and no production files changed.

- [ ] **Step 3: Implement the item-base, presentation, and eligibility contracts**

```gdscript
# scripts/equipment/equipment_base_definition.gd
class_name EquipmentBaseDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var item_type_id: StringName
@export var compatible_slot_ids: Array[StringName] = []
@export var weight_class_id: StringName = &"accessory"
@export var required_all_tags: Array[StringName] = []
@export var required_any_tags: Array[StringName] = []
@export var excluded_tags: Array[StringName] = []
@export var attribute_requirements: Dictionary = {}
@export var handedness_id: StringName = &"none"
@export var reserved_slot_ids: Array[StringName] = []
@export var compatible_offhand_item_types: Array[StringName] = []
@export var weapon_family_id: StringName
@export var implicit_family_id: StringName
@export var presentation: EquipmentVisualDefinition

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty(): errors.append("equipment base id is empty")
	if display_name.strip_edges().is_empty(): errors.append("equipment %s display name is empty" % id)
	if item_type_id.is_empty(): errors.append("equipment %s item type is empty" % id)
	if weight_class_id not in [&"accessory", &"light", &"medium", &"heavy", &"weapon"]: errors.append("equipment %s weight class %s is invalid" % [id, weight_class_id])
	if compatible_slot_ids.is_empty(): errors.append("equipment %s has no compatible slots" % id)
	for slot_id: StringName in compatible_slot_ids + reserved_slot_ids:
		if not EquipmentSlotCatalog.is_valid(slot_id): errors.append("equipment %s slot %s is invalid" % [id, slot_id])
	if handedness_id not in [&"none", &"one_hand", &"two_hand"]: errors.append("equipment %s handedness %s is invalid" % [id, handedness_id])
	if handedness_id == &"two_hand" and (&"main_hand" not in compatible_slot_ids or &"off_hand" not in reserved_slot_ids): errors.append("equipment %s two-hand reservation is invalid" % id)
	if implicit_family_id.is_empty(): errors.append("equipment %s implicit family hook is empty" % id)
	if presentation == null or presentation.id != id: errors.append("equipment %s presentation link is invalid" % id)
	return errors
```

```gdscript
# scripts/equipment/equipment_loadout_entry.gd
class_name EquipmentLoadoutEntry
extends Resource

@export var slot_id: StringName
@export var item: EquipmentBaseDefinition

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not EquipmentSlotCatalog.is_valid(slot_id): errors.append("loadout slot %s is invalid" % slot_id)
	if item == null: errors.append("loadout slot %s item is missing" % slot_id)
	elif slot_id not in item.compatible_slot_ids: errors.append("loadout item %s does not support slot %s" % [item.id, slot_id])
	return errors
```

```gdscript
# scripts/equipment/equipment_eligibility.gd
class_name EquipmentEligibility
extends RefCounted

static func validate_equip(item: EquipmentBaseDefinition, class_definition: ClassDefinition, requested_slot_id: StringName, loadout: Dictionary = {}, attributes: Dictionary = {}) -> PackedStringArray:
	var errors := PackedStringArray()
	if item == null or class_definition == null:
		errors.append("PARTY_FORGE_EQUIPMENT_ERROR reason=item or class is missing")
		return errors
	if requested_slot_id not in item.compatible_slot_ids:
		errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s slot=%s reason=incompatible slot" % [item.id, requested_slot_id])
	var tags := class_definition.normalized_eligibility_tags()
	if item.item_type_id in [&"helmet", &"body_armour", &"legs", &"gloves", &"boots"] and item.weight_class_id in [&"light", &"medium", &"heavy"]:
		var weight_tag := StringName("armour_%s" % item.weight_class_id)
		if weight_tag not in tags: errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=missing weight capability %s" % [item.id, weight_tag])
	for tag: StringName in item.required_all_tags:
		if tag not in tags: errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=missing tag %s" % [item.id, tag])
	if not item.required_any_tags.is_empty() and not item.required_any_tags.any(func(tag: StringName) -> bool: return tag in tags):
		errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=no compatible archetype tag" % item.id)
	for tag: StringName in item.excluded_tags:
		if tag in tags: errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=excluded tag %s" % [item.id, tag])
	for attribute_id: Variant in item.attribute_requirements:
		if float(attributes.get(attribute_id, 0.0)) < float(item.attribute_requirements[attribute_id]): errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=attribute %s" % [item.id, attribute_id])
	var main_hand := loadout.get(&"main_hand") as EquipmentBaseDefinition
	if requested_slot_id == &"off_hand" and main_hand != null and &"off_hand" in main_hand.reserved_slot_ids and item.item_type_id not in main_hand.compatible_offhand_item_types:
		errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=offhand reserved by %s" % [item.id, main_hand.id])
	if requested_slot_id == &"main_hand" and &"off_hand" in item.reserved_slot_ids:
		var off_hand := loadout.get(&"off_hand") as EquipmentBaseDefinition
		if off_hand != null and off_hand.item_type_id not in item.compatible_offhand_item_types: errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=equipped offhand %s is incompatible" % [item.id, off_hand.id])
	return errors
```

Extend `EquipmentVisualDefinition` with these exact exported properties while retaining `geometry_key` for the Fighter migration:

```gdscript
@export var supported_slot_ids: Array[StringName] = []
@export var presentation_scene: PackedScene
@export var icon_master: Texture2D
@export var icon_runtime: Texture2D
@export var socket_id: StringName
@export var body_preset_ids: Array[StringName] = [&"masculine", &"feminine"]
@export var combat_visible := true
@export var item_colors: Dictionary = {}
@export var wearer_accent_channel: StringName
@export var weapon_animation_family_id: StringName
@export var launch_socket_id: StringName
@export var readability_channels: Array[StringName] = []
```

Validation must require both icon textures, both body presets, valid supported slots, and a scene/socket only when `combat_visible` is true. It must require `id == EquipmentBaseDefinition.id` through the base validation above.

Replace `EquipmentVisualDefinition.validate()` with this complete validation body:

```gdscript
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty(): errors.append("equipment visual id is empty")
	var legacy_embedded := supported_slot_ids.is_empty() and presentation_scene == null and icon_master == null and icon_runtime == null
	if legacy_embedded:
		if not EquipmentSlotCatalog.is_valid(slot_id): errors.append("equipment visual %s slot %s is invalid" % [id, slot_id])
		if geometry_key.is_empty(): errors.append("equipment visual %s geometry key is empty" % id)
		if visual_channels.is_empty(): errors.append("equipment visual %s has no visual channels" % id)
		return errors
	if supported_slot_ids.is_empty(): errors.append("equipment visual %s has no supported slots" % id)
	for supported_slot: StringName in supported_slot_ids:
		if not EquipmentSlotCatalog.is_valid(supported_slot): errors.append("equipment visual %s slot %s is invalid" % [id, supported_slot])
	if slot_id.is_empty(): errors.append("equipment visual %s primary slot is empty" % id)
	elif slot_id not in supported_slot_ids: errors.append("equipment visual %s primary slot is unsupported" % id)
	if body_preset_ids != [&"masculine", &"feminine"]: errors.append("equipment visual %s body presets are incomplete" % id)
	if icon_master == null or icon_runtime == null: errors.append("equipment visual %s icon pair is incomplete" % id)
	if combat_visible and (presentation_scene == null or socket_id.is_empty()): errors.append("equipment visual %s visible scene or socket is missing" % id)
	if readability_channels.is_empty(): errors.append("equipment visual %s readability channels are empty" % id)
	return errors
```

- [ ] **Step 4: Add the catalog and canonical row helper**

`tools/class_equipment_rows.gd` must contain the canonical `SET_ITEM_IDS` constant at the top of this plan and these exact helpers:

```gdscript
class_name ClassEquipmentRows
extends RefCounted

static func total_item_count() -> int:
	var total := 0
	for ids: Array in SET_ITEM_IDS.values(): total += ids.size()
	return total

static func slot_for(set_id: StringName, index: int) -> StringName:
	if set_id == &"fighter" and index == 11: return &"main_hand"
	return EquipmentSlotCatalog.SLOT_IDS[index]

static func compatible_slots(slot_id: StringName) -> Array[StringName]:
	return [&"ring_left", &"ring_right"] if slot_id in [&"ring_left", &"ring_right"] else [slot_id]

static func display_name_for(id: StringName) -> String:
	return String(id).replace("_", " ").capitalize()

static func make_base(id: StringName, slot_id: StringName) -> EquipmentBaseDefinition:
	var value := EquipmentBaseDefinition.new()
	value.id = id; value.display_name = display_name_for(id)
	value.item_type_id = &"ring" if slot_id in [&"ring_left", &"ring_right"] else slot_id
	value.compatible_slot_ids = compatible_slots(slot_id)
	value.handedness_id = &"two_hand" if id == &"rime_scholar_staff" else &"none"
	value.reserved_slot_ids = [&"off_hand"] if id == &"rime_scholar_staff" else []
	return value
```

Create the catalog with this exact public contract:

```gdscript
# scripts/equipment/equipment_catalog.gd
class_name EquipmentCatalog
extends Resource

@export var definitions: Array[EquipmentBaseDefinition] = []

func definition(id: StringName) -> EquipmentBaseDefinition:
	for value: EquipmentBaseDefinition in definitions:
		if value != null and value.id == id: return value
	return null

func size() -> int:
	return definitions.size()

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary = {}
	for value: EquipmentBaseDefinition in definitions:
		if value == null:
			errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=<null> reason=definition missing")
			continue
		if seen.has(value.id): errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=duplicate id" % value.id)
		seen[value.id] = true
		for reason: String in value.validate(): errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=%s" % [value.id, reason])
		if value.presentation != null:
			for reason: String in value.presentation.validate(): errors.append("PARTY_FORGE_EQUIPMENT_ERROR item=%s reason=%s" % [value.id, reason])
	return errors
```

Add `const EQUIPMENT_CATALOG` plus `var equipment_catalog` to `GameCatalog`, and append its errors in `_validate_foundation()`.

Save an empty `EquipmentCatalog` resource at `data/equipment/core_equipment_catalog.tres` in this task. Each asset wave appends generated definitions; Task 10 requires the final count of 99.

- [ ] **Step 5: Run focused and full suites**

Run the focused command from Step 2, then:

```powershell
& $godot --headless --path . --script res://tests/test_runner.gd
```

Expected: focused `TEST_SUMMARY: PASS (0 failures)` and full `TEST_SUMMARY: PASS (73 suites)`.

- [ ] **Step 6: Commit the equipment foundation**

```powershell
git add scripts/equipment scripts/presentation/equipment_visual_definition.gd scripts/data/game_catalog.gd data/equipment/core_equipment_catalog.tres tools/class_equipment_rows.gd tests/focused_test_runner.gd tests/unit/test_equipment_contract.gd
git commit -m "feat: add modular equipment contracts"
```

### Task 2: Shared Humanoid Runtime and Transactional Item Scenes

**Files:**
- Create: `scripts/presentation/forge_humanoid_model.gd`
- Create: `tests/unit/test_forge_humanoid_equipment.gd`
- Modify: `scripts/presentation/character_visual_profile.gd`
- Modify: `scripts/presentation/character_presentation.gd`

**Interfaces:**
- Consumes: `EquipmentBaseDefinition.presentation`, `EquipmentVisualDefinition.presentation_scene`, `socket_id`, `item_colors`, and `weapon_animation_family_id`.
- Produces: `ForgeHumanoidModel.apply_equipment_visual(slot_id, definition) -> bool`, `clear_equipment_visual(slot_id) -> bool`, `equipped_item_id(slot_id) -> StringName`, `equipped_weapon_family() -> StringName`, `socket_global_transform(socket_id) -> Transform3D`, and signal `action_event(action_id, event_name)`.

- [ ] **Step 1: Write the failing transactional-equip suite**

```gdscript
# tests/unit/test_forge_humanoid_equipment.gd
extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var model := ForgeHumanoidModel.new()
	var socket := Node3D.new()
	socket.name = &"MainHandSocket"
	model.add_child(socket)
	(Engine.get_main_loop() as SceneTree).root.add_child(model)
	var first := _visual(&"first_sword", &"main_hand", &"MainHandSocket", _scene_with_mesh())
	var invalid := _visual(&"invalid_sword", &"main_hand", &"MissingSocket", _scene_with_mesh())
	TestAssertions.truthy(model.apply_equipment_visual(&"main_hand", first), "first item equips", failures)
	TestAssertions.equal(model.equipped_item_id(&"main_hand"), &"first_sword", "first item is recorded", failures)
	TestAssertions.truthy(not model.apply_equipment_visual(&"main_hand", invalid), "missing socket rejects equip", failures)
	TestAssertions.equal(model.equipped_item_id(&"main_hand"), &"first_sword", "failed equip preserves old item", failures)
	TestAssertions.truthy(model.clear_equipment_visual(&"main_hand"), "clear succeeds", failures)
	TestAssertions.equal(model.equipped_item_id(&"main_hand"), &"", "clear removes item", failures)
	model.free()
	return failures

func _visual(id: StringName, slot: StringName, socket: StringName, scene: PackedScene) -> EquipmentVisualDefinition:
	var value := EquipmentVisualDefinition.new()
	value.id = id; value.slot_id = slot; value.supported_slot_ids = [slot]
	value.socket_id = socket; value.presentation_scene = scene; value.combat_visible = true
	value.body_preset_ids = [&"masculine", &"feminine"]
	return value

func _scene_with_mesh() -> PackedScene:
	var root := Node3D.new(); root.add_child(MeshInstance3D.new()); root.get_child(0).owner = root
	var scene := PackedScene.new(); scene.pack(root); root.free(); return scene
```

- [ ] **Step 2: Verify the suite fails because `ForgeHumanoidModel` is absent**

Run the focused runner with `res://tests/unit/test_forge_humanoid_equipment.gd`.

Expected: non-zero exit and a missing-class parse error.

- [ ] **Step 3: Implement the shared model's transactional item API**

Use this state and replacement order in `forge_humanoid_model.gd`:

```gdscript
class_name ForgeHumanoidModel
extends Node3D

signal action_event(action_id: StringName, event_name: StringName)
signal action_finished(action_id: StringName)

const BODY_PRESETS: Array[StringName] = [&"masculine", &"feminine"]
var body_nodes: Dictionary = {}
var equipped_nodes: Dictionary = {}
var equipped_definitions: Dictionary = {}
var base_materials: Dictionary = {}
var active_action_id: StringName
var _hit_weight := 0.0
var _is_downed := false

func apply_equipment_visual(slot_id: StringName, definition: EquipmentVisualDefinition) -> bool:
	if definition == null or slot_id not in definition.supported_slot_ids or not EquipmentSlotCatalog.is_valid(slot_id): return false
	if not definition.combat_visible:
		_clear_equipped_node(slot_id); equipped_definitions[slot_id] = definition; return true
	if definition.presentation_scene == null: return false
	var candidate_root := definition.presentation_scene.instantiate() as Node3D
	if candidate_root == null: return false
	var staged: Array[Dictionary] = []
	var attachment_nodes: Array[Node3D] = []
	for node: Node in candidate_root.find_children("*", "Node3D", true, false):
		if node.has_meta(&"equipment_socket_id"): attachment_nodes.append(node as Node3D)
	if attachment_nodes.is_empty(): attachment_nodes.append(candidate_root)
	for attachment: Node3D in attachment_nodes:
		var socket_id := StringName(attachment.get_meta(&"equipment_socket_id", definition.socket_id))
		var socket := get_node_or_null(NodePath(String(socket_id))) as Node3D
		if socket == null:
			candidate_root.free()
			return false
		staged.append({&"node": attachment, &"socket": socket})
	_apply_item_colors(candidate_root, definition)
	_clear_equipped_node(slot_id)
	var installed: Array[Node3D] = []
	for part: Dictionary in staged:
		var attachment := part[&"node"] as Node3D
		if attachment != candidate_root: attachment.reparent(part[&"socket"] as Node3D, false)
		else: (part[&"socket"] as Node3D).add_child(attachment)
		installed.append(attachment)
	if candidate_root not in installed: candidate_root.free()
	equipped_nodes[slot_id] = installed
	equipped_definitions[slot_id] = definition
	return true

func clear_equipment_visual(slot_id: StringName) -> bool:
	if not EquipmentSlotCatalog.is_valid(slot_id): return false
	_clear_equipped_node(slot_id); equipped_definitions.erase(slot_id); return true

func equipped_item_id(slot_id: StringName) -> StringName:
	var definition := equipped_definitions.get(slot_id) as EquipmentVisualDefinition
	return definition.id if definition != null else &""

func equipped_weapon_family() -> StringName:
	var main := equipped_definitions.get(&"main_hand") as EquipmentVisualDefinition
	return main.weapon_animation_family_id if main != null else &"unarmed"

func socket_global_transform(socket_id: StringName) -> Transform3D:
	var socket := get_node_or_null(NodePath(String(socket_id))) as Node3D
	return socket.global_transform if socket != null else global_transform

func emit_action_event(event_name: StringName) -> void:
	action_event.emit(active_action_id, event_name)

func _clear_equipped_node(slot_id: StringName) -> void:
	var old_nodes: Array = equipped_nodes.get(slot_id, [])
	for old: Variant in old_nodes:
		if old is Node3D and is_instance_valid(old): (old as Node3D).free()
	equipped_nodes.erase(slot_id)
```

Port body switching, palette isolation, visual bounds, hit weight, and downed coloring from `ForgeVanguardModel`. Apply item colors by duplicating each `StandardMaterial3D` whose `palette_region` matches a key in `definition.item_colors`; apply the actor color only when the region equals `wearer_accent_channel`. An item scene with paired or articulated pieces tags each attachment root with `equipment_socket_id`; this keeps gloves, boots, legs, bows, quivers, and paired daggers on their actual animated limb sockets while one item still owns one packed scene. Connect `AnimationPlayer.animation_finished` to `action_finished`. Leave the current `ForgeVanguardModel` implementation and packed scene unchanged in Task 2; Task 3 migrates the real Fighter scene only after all independent Fighter item scenes exist.

- [ ] **Step 4: Migrate profiles and the adapter from visual arrays to item-base arrays**

Add the new profile arrays while retaining `default_equipment_visuals` and `available_equipment_visuals` as migration-only readers until Task 3 converts the real Fighter profile:

```gdscript
@export var default_equipment: Array[EquipmentLoadoutEntry] = []
@export var available_equipment: Array[EquipmentBaseDefinition] = []
@export var idle_action_id: StringName = &"idle"
```

In `CharacterPresentation.apply_profile()`, validate every entry and call `apply_equipment_visual(entry.slot_id, entry.item.presentation)`. The selected ring side belongs to the loadout entry, never to the ring base. When `default_equipment` is empty, retain the current embedded-geometry loop so Task 2 stays green against the pre-extraction Fighter resource. Task 3 converts the real Fighter profile; Task 10 smoke rejects migration-only arrays in every shipped profile. Do not hide the capsule until all combat-visible defaults and `idle_action_id` succeed. Add:

```gdscript
func equipped_weapon_family() -> StringName:
	return StringName(active_model.call(&"equipped_weapon_family")) if active_model != null else &"unarmed"

func socket_global_transform(socket_id: StringName) -> Transform3D:
	if active_model == null: return global_transform
	var value: Transform3D = active_model.call(&"socket_global_transform", socket_id)
	return value

func play_idle() -> bool:
	return active_profile != null and play_action(active_profile.idle_action_id)
```

- [ ] **Step 5: Verify focused and full suites**

Expected: focused pass and full `TEST_SUMMARY: PASS (74 suites)`; existing Fighter tests may be updated only to use base definitions, with all prior collision, fallback, palette, hit, downed, and revival assertions preserved.

- [ ] **Step 6: Commit the shared humanoid runtime**

```powershell
git add scripts/presentation tests/unit/test_forge_humanoid_equipment.gd tests/unit/test_character_visual_data.gd tests/unit/test_character_presentation.gd tests/unit/test_party_actor_presentation.gd
git commit -m "feat: add shared modular humanoid runtime"
```

### Task 3: Deterministic Asset and Icon Pipeline plus Fighter Normalization

**Files:**
- Create: `tools/build_shared_humanoid_scene.gd`
- Create: `tools/build_equipment_assets.gd`
- Create: `tools/render_equipment_icons.gd`
- Create: `tools/validate_equipment_icons.gd`
- Create: `tests/unit/test_fighter_modular_assets.gd`
- Create: `tests/unit/test_equipment_icons.gd`
- Create: `scenes/characters/presentation/forge_humanoid_model.tscn`
- Create: `scenes/equipment/forge_vanguard/*.tscn` (12 scenes)
- Create: `data/equipment/bases/forge_vanguard/*.tres` (12 bases)
- Create: `data/presentation/equipment/forge_vanguard/*.tres` (12 visuals)
- Create: `assets/ui/equipment/master/forge_vanguard/*_256.png` (12 icons)
- Create: `assets/ui/equipment/runtime/forge_vanguard/*_128.png` (12 icons)
- Modify: `tools/build_forge_vanguard_scene.gd`
- Modify: `tools/build_forge_base_body_scenes.gd`
- Modify: `scripts/presentation/equipment_slot_catalog.gd`
- Modify: `data/presentation/profiles/forge_vanguard.tres`
- Modify: `data/presentation/profiles/forge_base_masculine.tres`
- Modify: `data/presentation/profiles/forge_base_feminine.tres`
- Modify: `scripts/data/game_catalog.gd`
- Modify: `tests/unit/test_character_visual_data.gd`
- Modify: `tests/unit/test_forge_base_bodies.gd`
- Modify: `tests/unit/test_forge_vanguard_animations.gd`
- Modify: `tests/unit/test_forge_vanguard_model.gd`

**Interfaces:**
- Consumes: the current Fighter geometry/animations, `ClassEquipmentRows.SET_ITEM_IDS`, and `ForgeHumanoidModel`.
- Produces: deterministic `--sets=<comma-separated IDs>` asset generation; transparent icon pairs; the shared humanoid scene; and the final reusable `forge_base_masculine.tscn`/`forge_base_feminine.tscn` scenes.

- [ ] **Step 1: Write failing Fighter extraction and icon tests**

```gdscript
# tests/unit/test_fighter_modular_assets.gd
extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.equal(EquipmentSlotCatalog.SLOT_IDS, [&"helmet", &"body_armour", &"legs", &"gloves", &"boots", &"amulet", &"ring_left", &"ring_right", &"belt", &"main_hand", &"off_hand"], "PoE 1 sheet slot order", failures)
	var profile := load("res://data/presentation/profiles/forge_vanguard.tres") as CharacterVisualProfile
	TestAssertions.equal(profile.default_equipment.size(), 11, "Fighter default sheet has eleven items", failures)
	TestAssertions.equal(profile.default_equipment[9].item.id, &"forge_vanguard_sword", "sword remains default", failures)
	TestAssertions.equal(profile.default_equipment[10].item.id, &"forge_vanguard_shield", "shield remains default", failures)
	TestAssertions.equal(profile.available_equipment.size(), 12, "hammer remains an alternative", failures)
	for item: EquipmentBaseDefinition in profile.available_equipment:
		TestAssertions.truthy(item.presentation.presentation_scene != null, "%s has independent scene" % item.id, failures)
	TestAssertions.truthy(ResourceLoader.exists("res://scenes/characters/presentation/forge_base_masculine.tscn"), "masculine base exists", failures)
	TestAssertions.truthy(ResourceLoader.exists("res://scenes/characters/presentation/forge_base_feminine.tscn"), "feminine base exists", failures)
	return failures
```

The icon suite must load each of the 12 visual definitions, assert master width/height `256`, runtime `128`, at least one alpha value below `1.0`, non-empty visible bounds, and eight runtime pixels of transparent padding.

- [ ] **Step 2: Verify both suites fail before extraction**

Run the focused runner with both suite paths. Expected: non-zero exit for missing modular assets/icons.

- [ ] **Step 3: Build the shared humanoid and extract Fighter items without remodeling them**

Refactor the existing body/pivot/animation code into `build_shared_humanoid_scene.gd`. The scene must expose these exact socket paths:

```gdscript
const SOCKET_PATHS := {
	&"helmet": &"HitPivot/BodyPivot/HipsPivot/TorsoPivot/HeadPivot/HelmetSocket",
	&"body_armour": &"HitPivot/BodyPivot/HipsPivot/TorsoPivot/BodyArmourSocket",
	&"legs": &"HitPivot/BodyPivot/HipsPivot/LegsSocket",
	&"gloves": &"HitPivot/BodyPivot/HipsPivot/GlovesSocket",
	&"boots": &"HitPivot/BodyPivot/HipsPivot/BootsSocket",
	&"amulet": &"HitPivot/BodyPivot/HipsPivot/TorsoPivot/AmuletSocket",
	&"belt": &"HitPivot/BodyPivot/HipsPivot/BeltSocket",
	&"main_hand": &"HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot/RightHandSocket",
	&"off_hand": &"HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot/LeftHandSocket",
	&"projectile_launch": &"HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot/RightHandSocket/ProjectileLaunchSocket",
}
```

`build_equipment_assets.gd -- --sets=fighter` must recreate the sword, shield, hammer, armour, helmet, gauntlets, boots, belt, amulet, and ring shapes from their existing generator functions, add Forge Vanguard greaves using the existing leather/metal leg proportions, and save each root as an independent packed scene. The default sheet is the first 11 canonical Fighter IDs; the hammer is available but absent from defaults.

- [ ] **Step 4: Implement deterministic icon rendering**

`render_equipment_icons.gd` must use a `SubViewport` with `transparent_bg = true`, orthographic camera, fixed three-light rig, per-item-type camera presets, and `UPDATE_ONCE`. Save the viewport image at 256x256 and resize a duplicate to 128x128 with `Image.INTERPOLATE_LANCZOS`. Use `await RenderingServer.frame_post_draw` before capture. Normalize image metadata by writing only PNG pixels; do not encode timestamps in filenames or contact sheets.

```gdscript
func _save_pair(item_id: StringName, set_id: StringName, image: Image) -> Error:
	var master_path := "res://assets/ui/equipment/master/%s/%s_256.png" % [set_id, item_id]
	var runtime_path := "res://assets/ui/equipment/runtime/%s/%s_128.png" % [set_id, item_id]
	var error := image.save_png(ProjectSettings.globalize_path(master_path))
	if error != OK: return error
	var runtime := image.duplicate(); runtime.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	return runtime.save_png(ProjectSettings.globalize_path(runtime_path))
```

- [ ] **Step 5: Generate Fighter assets, reimport, and validate determinism**

```powershell
& $godot --headless --path . --script res://tools/build_shared_humanoid_scene.gd
& $godot --headless --path . --script res://tools/build_equipment_assets.gd -- --sets=fighter
& $godot --headless --path . --editor --quit-after 3
& $godot --headless --path . --script res://tools/render_equipment_icons.gd -- --sets=fighter
& $godot --headless --path . --editor --quit-after 3
& $godot --headless --path . --script res://tools/build_equipment_assets.gd -- --sets=fighter
& $godot --headless --path . --script res://tools/validate_equipment_icons.gd -- --sets=fighter
git diff --exit-code -- assets/ui/equipment/master/forge_vanguard assets/ui/equipment/runtime/forge_vanguard
```

Run the renderer a second time immediately before `git diff --exit-code`. Expected markers: `FORGE_HUMANOID_BUILD_OK`, `EQUIPMENT_ASSET_BUILD_OK sets=1 items=12`, `EQUIPMENT_ICON_RENDER_OK items=12`, `EQUIPMENT_ICON_VALIDATION_OK items=12`, and a clean icon diff after the second render.

- [ ] **Step 6: Rebuild the two reusable unequipped bodies and run regression suites**

Run `build_forge_base_body_scenes.gd`, both focused suites, then the full suite. Expected: both body files contain no equipped item nodes; Fighter remains red sword/shield at runtime; hammer is selectable; all 76 suites pass.

- [ ] **Step 7: Commit normalized Fighter assets and tooling**

```powershell
git add tools scripts/data/game_catalog.gd scripts/presentation/equipment_slot_catalog.gd scenes/characters/presentation scenes/equipment/forge_vanguard data/equipment/bases/forge_vanguard data/presentation/equipment/forge_vanguard data/presentation/profiles/forge_vanguard.tres data/presentation/profiles/forge_base_masculine.tres data/presentation/profiles/forge_base_feminine.tres assets/ui/equipment tests/unit/test_fighter_modular_assets.gd tests/unit/test_equipment_icons.gd tests/unit/test_character_visual_data.gd tests/unit/test_forge_base_bodies.gd tests/unit/test_forge_vanguard_animations.gd tests/unit/test_forge_vanguard_model.gd
git commit -m "feat: normalize Fighter modular equipment assets"
```

### Task 4: Animation-Event Attack Sequence Foundation

**Files:**
- Create: `scripts/presentation/attack_presentation_definition.gd`
- Create: `scripts/combat/attack_sequence_controller.gd`
- Create: `data/presentation/attacks/fighter_cleave.tres`
- Create: `tests/unit/test_attack_sequence_controller.gd`
- Modify: `scripts/presentation/character_visual_profile.gd`
- Modify: `scripts/presentation/character_presentation.gd`
- Modify: `scripts/presentation/forge_humanoid_model.gd`
- Modify: `scripts/combat/attack_executor.gd`
- Modify: `tools/build_shared_humanoid_scene.gd`
- Modify: `data/presentation/profiles/forge_vanguard.tres`
- Modify: `tests/unit/test_attack_execution.gd`
- Modify: `tests/unit/test_party_actor_presentation.gd`

**Interfaces:**
- Consumes: `AttackController.attack_ready(definition, target)`, `AttackDefinition.cooldown`, `CombatModifiers.cooldown_rate_multiplier`, and `CharacterPresentation` action events.
- Produces: `AttackSequenceController.request(definition, target, presentation_definition, playback_rate, range_multiplier) -> int`, `advance(delta)`, `cancel(reason)`, and exactly-once calls to `AttackExecutor.execute(definition, target, presentation_definition)`.

- [ ] **Step 1: Write the failing exactly-once sequence suite**

The suite uses probes and must assert all seven cases in one run: no execution before release, one execution at release, duplicate rejected, stale token rejected, invalidated target canceled without retarget, downed actor cannot release, and missing event at action finish reports `PARTY_FORGE_ATTACK_SEQUENCE_ERROR`.

```gdscript
class ExecutorProbe extends Node:
	var calls := 0
	func execute(_definition: AttackDefinition, _target: CombatTarget, _presentation: AttackPresentationDefinition = null) -> void: calls += 1

class PresentationProbe extends Node:
	signal attack_event(token: int, action_id: StringName, event_name: StringName)
	signal attack_finished(token: int, action_id: StringName)
	var last_rate := 0.0
	func start_attack(_definition: AttackDefinition, _target: CombatTarget, _presentation: AttackPresentationDefinition, token: int, playback_rate: float) -> bool:
		last_rate = playback_rate; return token > 0
```

Use a real `PartyActor`/`HealthComponent` target fixture for revalidation. Capture Godot errors with the established test error-capture helper used elsewhere in `tests/unit`.

- [ ] **Step 2: Verify the new suite fails before sequencing exists**

Expected: non-zero focused run because `AttackSequenceController` and `AttackPresentationDefinition` do not exist.

- [ ] **Step 3: Add the separate attack-presentation resource**

```gdscript
class_name AttackPresentationDefinition
extends Resource

@export var id: StringName
@export var attack_id: StringName
@export var action_id: StringName
@export var required_event_name: StringName = &"release"
@export var weapon_animation_family_id: StringName
@export var launch_socket_id: StringName
@export var projectile_scene: PackedScene
@export var projectile_rotation_degrees: Vector3
@export var projectile_scale := Vector3.ONE
@export var impact_scene: PackedScene
@export var impact_color := Color.WHITE
@export var action_duration := 1.0
@export var release_time := 0.5

func validate(attack: AttackDefinition) -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty() or attack_id.is_empty() or action_id.is_empty() or required_event_name not in [&"release", &"impact"]: errors.append("attack presentation identity is invalid")
	if attack == null or attack.id != attack_id: errors.append("attack presentation %s attack link is invalid" % id)
	if action_duration <= 0.0 or release_time < 0.0 or release_time > action_duration: errors.append("attack presentation %s timing is invalid" % id)
	if attack != null and action_duration > attack.cooldown: errors.append("attack presentation %s phases exceed cooldown" % id)
	return errors
```

Add the typed array and weapon-family lookup to `CharacterVisualProfile`:

```gdscript
@export var attack_presentations: Array[AttackPresentationDefinition] = []

func resolve_attack_presentation(attack_id: StringName, weapon_family_id: StringName) -> AttackPresentationDefinition:
	for value: AttackPresentationDefinition in attack_presentations:
		if value != null and value.attack_id == attack_id and value.weapon_animation_family_id == weapon_family_id: return value
	for value: AttackPresentationDefinition in attack_presentations:
		if value != null and value.attack_id == attack_id and value.weapon_animation_family_id.is_empty(): return value
	return null
```

- [ ] **Step 4: Implement the tokenized sequence controller**

The controller owns monotonically increasing tokens, retains the same target actor, subscribes to presentation events, and calls the executor only after a matching event. Its event handler must use this order:

```gdscript
func _on_attack_event(token: int, action_id: StringName, event_name: StringName) -> void:
	if token != active_token:
		_sequence_error(token, action_id, "stale event")
		return
	if released:
		_sequence_error(token, action_id, "duplicate event")
		return
	if active_presentation == null or event_name != active_presentation.required_event_name:
		return
	var refreshed := _revalidate_locked_target()
	if refreshed == null:
		cancel("target invalid at release")
		return
	if _owner_is_downed():
		cancel("owner downed at release")
		return
	released = true
	executor.call(&"execute", active_definition, refreshed, active_presentation)
```

`_revalidate_locked_target()` must query only `locked_target.actor.get_combat_target()`, confirm the actor identity and opposing/same team rules for damage/heal, then check current distance with `ResolvedAttackGeometry`. It must never call `TargetSelector`.

On `attack_finished`, cancel with `missing required event <name>` if `released` is false; otherwise clear the active sequence. `advance(delta)` tracks only unpaused actor time and provides a fail-closed duration backstop. `cancel(reason)` invalidates the current token before returning idle.

Bridge token-free model events through `CharacterPresentation`, where the active gameplay sequence token is known:

```gdscript
signal attack_event(token: int, action_id: StringName, event_name: StringName)
signal attack_finished(token: int, action_id: StringName)
var active_sequence_token := 0

func resolve_attack_presentation(definition: AttackDefinition) -> AttackPresentationDefinition:
	if active_profile == null or definition == null: return null
	return active_profile.resolve_attack_presentation(definition.id, equipped_weapon_family())

func start_attack(definition: AttackDefinition, _target: CombatTarget, presentation: AttackPresentationDefinition, token: int, playback_rate: float) -> bool:
	if active_model == null or definition == null or presentation == null or token <= 0 or playback_rate <= 0.0: return false
	active_sequence_token = token
	return bool(active_model.call(&"play_action", presentation.action_id, playback_rate))

func _on_model_action_event(action_id: StringName, event_name: StringName) -> void:
	attack_event.emit(active_sequence_token, action_id, event_name)

func _on_model_action_finished(action_id: StringName) -> void:
	attack_finished.emit(active_sequence_token, action_id)
```

Connect both model signals immediately after API validation. `ForgeHumanoidModel.play_action(action_id, playback_rate)` sets `AnimationPlayer.speed_scale = playback_rate`, stores `active_action_id`, and plays the action. Its finish callback resets speed to `1.0`, emits `action_finished`, and returns to the profile's idle only after the sequence controller accepts completion.

Implement the controller with these complete state transitions around the event handler above:

```gdscript
class_name AttackSequenceController
extends Node

var owner_actor: PartyActor
var presentation: CharacterPresentation
var executor: Node
var active_definition: AttackDefinition
var active_presentation: AttackPresentationDefinition
var locked_target: CombatTarget
var active_token := 0
var next_token := 1
var released := false
var elapsed_scaled := 0.0
var locked_range_multiplier := 1.0

func configure(actor: PartyActor, visual: CharacterPresentation, attack_executor: Node) -> void:
	owner_actor = actor; presentation = visual; executor = attack_executor
	if presentation != null and not presentation.attack_event.is_connected(_on_attack_event): presentation.attack_event.connect(_on_attack_event)
	if presentation != null and not presentation.attack_finished.is_connected(_on_attack_finished): presentation.attack_finished.connect(_on_attack_finished)

func request(definition: AttackDefinition, target: CombatTarget, visual: AttackPresentationDefinition, playback_rate: float, range_multiplier: float) -> int:
	if is_busy() or definition == null or target == null or visual == null or playback_rate <= 0.0: return 0
	if not visual.validate(definition).is_empty():
		_sequence_error(0, visual.action_id, visual.validate(definition)[0]); return 0
	active_token = next_token; next_token += 1
	active_definition = definition; active_presentation = visual; locked_target = target
	released = false; elapsed_scaled = 0.0; locked_range_multiplier = range_multiplier
	if not presentation.start_attack(definition, target, visual, active_token, playback_rate):
		cancel("action failed to start"); return 0
	return active_token

func advance(delta: float) -> void:
	if not is_busy(): return
	elapsed_scaled += maxf(delta, 0.0) * presentation.action_playback_rate()
	if elapsed_scaled > active_presentation.action_duration + 0.05:
		cancel("missing required event %s" % active_presentation.required_event_name)

func is_busy() -> bool:
	return active_token > 0

func cancel(reason: String) -> void:
	if is_busy(): _sequence_error(active_token, active_presentation.action_id if active_presentation != null else &"<missing>", reason)
	active_token = 0; active_definition = null; active_presentation = null; locked_target = null
	released = false; elapsed_scaled = 0.0
	if presentation != null: presentation.play_idle()

func _on_attack_finished(token: int, action_id: StringName) -> void:
	if token != active_token: _sequence_error(token, action_id, "stale finish"); return
	if not released: cancel("missing required event %s" % active_presentation.required_event_name); return
	active_token = 0; active_definition = null; active_presentation = null; locked_target = null
	released = false; elapsed_scaled = 0.0
	if presentation != null: presentation.play_idle()

func _revalidate_locked_target() -> CombatTarget:
	if owner_actor == null or locked_target == null or locked_target.actor == null or not is_instance_valid(locked_target.actor) or not locked_target.actor.has_method(&"get_combat_target"): return null
	var current := locked_target.actor.call(&"get_combat_target") as CombatTarget
	if current == null or current.actor != locked_target.actor or not current.is_available: return null
	var expects_ally := active_definition.kind == AttackDefinition.Kind.HEAL
	if (current.team_id == owner_actor.team_id) != expects_ally: return null
	var origin := owner_actor.global_position if owner_actor.is_inside_tree() else owner_actor.position
	var maximum_range := active_definition.range * locked_range_multiplier
	return current if origin.distance_squared_to(current.position) <= maximum_range * maximum_range else null

func _owner_is_downed() -> bool:
	var health := owner_actor.get_node_or_null("HealthComponent") as HealthComponent if owner_actor != null else null
	return health == null or health.is_downed or health.is_dead

func _sequence_error(token: int, action_id: StringName, reason: String) -> void:
	var attack_id := active_definition.id if active_definition != null else &"<missing>"
	push_error("PARTY_FORGE_ATTACK_SEQUENCE_ERROR attack=%s action=%s token=%d reason=%s" % [attack_id, action_id, token, reason])
```

`CharacterPresentation.action_playback_rate() -> float` returns the active model `AnimationPlayer.speed_scale`, clamped above zero. `PartyActor._process()` already stops during pause, so neither controller time nor animation time advances while the tree is paused.

- [ ] **Step 5: Author the Fighter sequence fixture and non-interrupting feedback layer**

Create `fighter_cleave.tres` with `action_id = &"attack_slash"`, `required_event_name = &"impact"`, `weapon_animation_family_id = &"one_hand_sword"`, `action_duration = 0.55`, and `release_time = 0.28`; link it from the Forge Vanguard profile. Add a method track to `attack_slash` calling `emit_action_event(&"impact")` at `0.28`. Use a separate `FeedbackAnimationPlayer` for `hit_flinch` so hit feedback never replaces the active action animation. Add `play_feedback(animation_id) -> bool` to the model API and change `CharacterPresentation.flash_hit()` to call `play_feedback(&"hit_flinch")` after applying hit weight; it must not call `play_action()`.

Do not rewire `PartyActor` in this foundation task. Its existing direct execution remains active while eight classes still lack profiles. Task 9 performs the single runtime cutover after every class has valid equipment, action, projectile/effect, and profile data; this keeps each intermediate commit playable and testable.

- [ ] **Step 6: Make AttackExecutor accept presentation context without changing damage math**

Change the signature to:

```gdscript
func execute(definition: AttackDefinition, target: CombatTarget, presentation: AttackPresentationDefinition = null) -> void:
```

Pass `presentation` only to projectile/effect construction. Melee damage, prepared packets, range/area modifiers, crit, heal power, and target rules remain unchanged.

- [ ] **Step 7: Verify synchronization and real downstream effects**

Run the sequence suite against the real Fighter presentation and executor, then attack-execution and party-presentation suites, then the full suite. Expected inside the sequence fixture: no target health change before `0.28`, exactly one change at the impact event, duplicate/stale rejection, and speed-scaled playback. Existing actor combat remains unchanged until Task 9. Full result: `TEST_SUMMARY: PASS (77 suites)`.

- [ ] **Step 8: Commit foundational synchronization**

```powershell
git add scripts/presentation scripts/combat/attack_sequence_controller.gd scripts/combat/attack_executor.gd tools/build_shared_humanoid_scene.gd data/presentation/attacks/fighter_cleave.tres data/presentation/profiles/forge_vanguard.tres tests/unit/test_attack_sequence_controller.gd tests/unit/test_attack_execution.gd tests/unit/test_party_actor_presentation.gd
git commit -m "feat: add animation event sequence foundation"
```

### Task 5: Specialized Projectile, Impact, and Healing Presentation

**Files:**
- Create: `tools/build_combat_presentation_scenes.gd`
- Create: `scripts/combat/presentation_effect.gd`
- Create: `scenes/combat/presentation/projectiles/ranger_arrow.tscn`
- Create: `scenes/combat/presentation/projectiles/marksman_heavy_arrow.tscn`
- Create: `scenes/combat/presentation/projectiles/mage_fire_orb.tscn`
- Create: `scenes/combat/presentation/projectiles/frost_shard.tscn`
- Create: `scenes/combat/presentation/projectiles/cleric_lightning_bolt.tscn`
- Create: `scenes/combat/presentation/projectiles/warlock_chaos_bolt.tscn`
- Create: `scenes/combat/presentation/effects/fire_impact.tscn`
- Create: `scenes/combat/presentation/effects/frost_impact.tscn`
- Create: `scenes/combat/presentation/effects/lightning_impact.tscn`
- Create: `scenes/combat/presentation/effects/healing_blessing.tscn`
- Create: `scenes/combat/presentation/effects/chaos_impact.tscn`
- Create: `tests/unit/test_specialized_combat_presentation.gd`
- Modify: `scripts/combat/attack_executor.gd`
- Modify: `scripts/combat/projectile.gd`

**Interfaces:**
- Consumes: `AttackPresentationDefinition.projectile_scene`, `projectile_scale`, `launch_socket_id`, `impact_scene`, and `impact_color` after a valid sequence release.
- Produces: projectile launch at `CharacterPresentation.socket_global_transform()`, typed impact scenes, and generic `projectile.tscn` fallback only after release.

- [ ] **Step 1: Write the failing specialized-presentation suite**

```gdscript
# tests/unit/test_specialized_combat_presentation.gd
extends RefCounted

const PROJECTILES := {
	&"ranger_shot": ["res://scenes/combat/presentation/projectiles/ranger_arrow.tscn", Vector3.ONE],
	&"marksman_heavy_shot": ["res://scenes/combat/presentation/projectiles/marksman_heavy_arrow.tscn", Vector3(1.45, 1.45, 1.45)],
	&"mage_burst": ["res://scenes/combat/presentation/projectiles/mage_fire_orb.tscn", Vector3.ONE],
	&"frost_shard": ["res://scenes/combat/presentation/projectiles/frost_shard.tscn", Vector3.ONE],
	&"cleric_bolt": ["res://scenes/combat/presentation/projectiles/cleric_lightning_bolt.tscn", Vector3.ONE],
	&"warlock_bolt": ["res://scenes/combat/presentation/projectiles/warlock_chaos_bolt.tscn", Vector3.ONE],
}

func run() -> Array[String]:
	var failures: Array[String] = []
	for attack_id: StringName in PROJECTILES:
		var path: String = PROJECTILES[attack_id][0]
		TestAssertions.truthy(ResourceLoader.exists(path), "%s specialized projectile exists" % attack_id, failures)
		var scene := load(path) as PackedScene
		var node := scene.instantiate() as Node3D if scene != null else null
		TestAssertions.truthy(node != null and node.has_method(&"configure"), "%s projectile obeys runtime API" % attack_id, failures)
		if node != null: node.free()
	return failures
```

Add integration assertions to the suite using an executor probe root: Ranger spawns scale `Vector3.ONE`; Marksman spawns `Vector3(1.45, 1.45, 1.45)`; launch position matches a deliberately offset `ProjectileLaunchSocket`; an invalid packed scene emits `PARTY_FORGE_PROJECTILE_PRESENTATION_ERROR` and instantiates the generic projectile.

- [ ] **Step 2: Verify the suite fails for missing specialized scenes**

Run the focused suite. Expected: non-zero exit with six missing projectile assertions.

- [ ] **Step 3: Build exact low-poly projectile/effect recipes**

`build_combat_presentation_scenes.gd` must generate these recipes:

```gdscript
const PROJECTILE_RECIPES := {
	&"ranger_arrow": {&"shape": &"arrow", &"length": 0.90, &"radius": 0.025, &"color": Color("b9a06c")},
	&"marksman_heavy_arrow": {&"shape": &"arrow", &"length": 1.35, &"radius": 0.045, &"color": Color("88734f")},
	&"mage_fire_orb": {&"shape": &"orb", &"radius": 0.18, &"color": Color("ff6b35"), &"emission": 1.4},
	&"frost_shard": {&"shape": &"shard", &"length": 0.62, &"radius": 0.11, &"color": Color("8ee8ff"), &"emission": 1.0},
	&"cleric_lightning_bolt": {&"shape": &"bolt", &"length": 0.72, &"radius": 0.06, &"color": Color("fff08a"), &"emission": 1.5},
	&"warlock_chaos_bolt": {&"shape": &"orb", &"radius": 0.22, &"color": Color("8c45c9"), &"emission": 1.2},
}
const EFFECT_RECIPES := {
	&"fire_impact": {&"color": Color("ff6b35"), &"radius": 0.70, &"duration": 0.32},
	&"frost_impact": {&"color": Color("8ee8ff"), &"radius": 0.85, &"duration": 0.38},
	&"lightning_impact": {&"color": Color("fff08a"), &"radius": 0.55, &"duration": 0.24},
	&"healing_blessing": {&"color": Color("ffe891"), &"radius": 0.80, &"duration": 0.45},
	&"chaos_impact": {&"color": Color("8c45c9"), &"radius": 0.72, &"duration": 0.50},
}
```

Projectile roots use the existing `projectile.gd` runtime. Effect roots use `presentation_effect.gd`, which duplicates its material per instance, applies the supplied color, expands from `0.35` to `1.0`, fades alpha to zero, and frees itself at the authored duration.

- [ ] **Step 4: Launch from the declared socket and forward impact presentation**

In `AttackExecutor._spawn_projectile()`, select `presentation.projectile_scene` when it instantiates as `Node3D`; otherwise report:

```gdscript
push_error("PARTY_FORGE_PROJECTILE_PRESENTATION_ERROR attack=%s presentation=%s reason=specialized scene failed; generic fallback used" % [definition.id, presentation.id if presentation != null else &"<missing>"])
```

Use `owner_actor.get_node_or_null("Presentation").socket_global_transform(presentation.launch_socket_id)` for the initial transform and apply rotation/scale after positioning. Extend `Projectile.configure()` with `impact_scene: PackedScene`, `impact_color: Color`, and `visual_scale: Vector3`; instantiate the impact scene only when the projectile resolves or expires at a valid impact point. For heals, select `presentation.impact_scene` instead of `HEAL_EFFECT_SCENE`, with the existing scene as fallback.

- [ ] **Step 5: Generate and validate specialized scenes**

```powershell
& $godot --headless --path . --script res://tools/build_combat_presentation_scenes.gd
& $godot --headless --path . --editor --quit-after 3
& $godot --headless --path . --script res://tests/focused_test_runner.gd -- res://tests/unit/test_specialized_combat_presentation.gd res://tests/unit/test_attack_execution.gd
& $godot --headless --path . --script res://tests/test_runner.gd
```

Expected: `COMBAT_PRESENTATION_BUILD_OK projectiles=6 effects=5`, focused pass, and full `TEST_SUMMARY: PASS (78 suites)`.

- [ ] **Step 6: Commit specialized combat presentation**

```powershell
git add tools/build_combat_presentation_scenes.gd scripts/combat scenes/combat/presentation tests/unit/test_specialized_combat_presentation.gd tests/unit/test_attack_execution.gd
git commit -m "feat: add specialized class combat effects"
```

### Task 6: Paladin and Rogue Equipment plus Melee Actions

**Files:**
- Create: `scenes/equipment/dawn_bulwark/*.tscn` (11 scenes)
- Create: `scenes/equipment/nightstep/*.tscn` (11 scenes)
- Create: `data/equipment/bases/dawn_bulwark/*.tres` (11 bases)
- Create: `data/equipment/bases/nightstep/*.tres` (11 bases)
- Create: `data/presentation/equipment/dawn_bulwark/*.tres` (11 visuals)
- Create: `data/presentation/equipment/nightstep/*.tres` (11 visuals)
- Create: `assets/ui/equipment/master/dawn_bulwark/*_256.png`
- Create: `assets/ui/equipment/master/nightstep/*_256.png`
- Create: `assets/ui/equipment/runtime/dawn_bulwark/*_128.png`
- Create: `assets/ui/equipment/runtime/nightstep/*_128.png`
- Create: `tests/unit/test_heavy_melee_equipment_content.gd`
- Modify: `tools/build_equipment_assets.gd`
- Modify: `tools/build_shared_humanoid_scene.gd`
- Modify: `data/equipment/core_equipment_catalog.tres`

**Interfaces:**
- Consumes: modular item generator, shared sockets, equipment eligibility, synchronized impact events.
- Produces: 22 item entries, `paladin_idle`, `rogue_idle`, `paladin_hammer_smite` impact action, and `rogue_dagger_flurry` impact action.

- [ ] **Step 1: Add failing manifest, fit, eligibility, and action tests**

The suite must assert exact 11-item IDs for both sets, both body presets, every visible item's socket, Paladin heavy/vanguard rules, Rogue light/skirmisher rules, hammer/shield and dual-dagger family tags, action presence, event times, and bounds inside `AABB(Vector3(-1.25, 0.0, -0.85), Vector3(2.5, 2.7, 1.7))`.

```gdscript
TestAssertions.equal(_ids_for_set(&"paladin"), ClassEquipmentRows.SET_ITEM_IDS[&"paladin"], "Paladin manifest", failures)
TestAssertions.equal(_ids_for_set(&"rogue"), ClassEquipmentRows.SET_ITEM_IDS[&"rogue"], "Rogue manifest", failures)
TestAssertions.truthy(_action_has_event(&"paladin_hammer_smite", &"impact", 0.58), "Paladin impact timing", failures)
TestAssertions.truthy(_action_has_event(&"rogue_dagger_flurry", &"impact", 0.16), "Rogue impact timing", failures)
```

- [ ] **Step 2: Verify the heavy/melee suite fails before assets exist**

Expected: non-zero focused run with missing 22-item content and actions.

- [ ] **Step 3: Add exact set style and equipment-rule data**

```gdscript
const SET_STYLES := {
	&"paladin": {&"folder": &"dawn_bulwark", &"primary": Color("e6c85f"), &"metal": Color("4c5666"), &"leather": Color("5b402b"), &"accent": Color("ffe38a"), &"emissive": Color("ffd86b"), &"armour_shape": &"heavy_plate"},
	&"rogue": {&"folder": &"nightstep", &"primary": Color("554263"), &"metal": Color("30343d"), &"leather": Color("28222d"), &"accent": Color("a95be8"), &"emissive": Color("c46cff"), &"armour_shape": &"light_leather"},
}
const WEAPON_RULES := {
	&"sunforged_warhammer": {&"item_type": &"warhammer", &"family": &"one_hand_hammer", &"required_all": [&"martial", &"one_hand_hammer"], &"handedness": &"one_hand"},
	&"dawn_bulwark_shield": {&"item_type": &"shield", &"family": &"shield", &"required_all": [&"martial", &"shield"]},
	&"nightstep_dagger_main": {&"item_type": &"dagger", &"family": &"dual_daggers", &"required_all": [&"dagger", &"dual_wield"], &"handedness": &"one_hand"},
	&"nightstep_dagger_off": {&"item_type": &"dagger", &"family": &"dual_daggers", &"required_all": [&"dagger", &"dual_wield"], &"handedness": &"one_hand"},
}
```

Heavy armour requires `martial` plus `vanguard`; Rogue armour requires `martial` plus `skirmisher`. Amulets, rings, and belts have empty class-tag requirements. Every item uses its own ID-derived geometry key and independently saved scene.

- [ ] **Step 4: Author the Paladin and Rogue actions in the shared animation library**

Use looping `paladin_idle` with a planted shield-forward posture and looping `rogue_idle` with a compressed ready posture. Use `paladin_hammer_smite` duration `0.86`, impact `0.58`, with a broad overhead windup and planted shield arm. Use `rogue_dagger_flurry` duration `0.28`, impact `0.16`, with alternating shoulders, forward torso compression, and both daggers returning to guard. Both attacks start/end on their class idle pose, contain one required method event, and never animate the model root.

- [ ] **Step 5: Generate, render, re-link, and test both sets**

```powershell
& $godot --headless --path . --script res://tools/build_equipment_assets.gd -- --sets=paladin,rogue
& $godot --headless --path . --script res://tools/build_shared_humanoid_scene.gd
& $godot --headless --path . --editor --quit-after 3
& $godot --headless --path . --script res://tools/render_equipment_icons.gd -- --sets=paladin,rogue
& $godot --headless --path . --editor --quit-after 3
& $godot --headless --path . --script res://tools/build_equipment_assets.gd -- --sets=paladin,rogue
& $godot --headless --path . --script res://tools/validate_equipment_icons.gd -- --sets=paladin,rogue
& $godot --headless --path . --script res://tests/focused_test_runner.gd -- res://tests/unit/test_heavy_melee_equipment_content.gd
& $godot --headless --path . --script res://tests/test_runner.gd
```

Expected: `items=22`, `icons=22`, focused pass, full `TEST_SUMMARY: PASS (79 suites)`.

- [ ] **Step 6: Commit the heavy and melee wave**

```powershell
git add tools scenes/equipment/dawn_bulwark scenes/equipment/nightstep data/equipment data/presentation/equipment/dawn_bulwark data/presentation/equipment/nightstep assets/ui/equipment tests/unit/test_heavy_melee_equipment_content.gd
git commit -m "feat: add Paladin and Rogue presentation sets"
```

### Task 7: Ranger and Marksman Equipment, Bow Actions, and Arrow Scale

**Files:**
- Create: `scenes/equipment/greenwood/*.tscn` (11 scenes)
- Create: `scenes/equipment/siege_archer/*.tscn` (11 scenes)
- Create: `data/equipment/bases/greenwood/*.tres` (11 bases)
- Create: `data/equipment/bases/siege_archer/*.tres` (11 bases)
- Create: `data/presentation/equipment/greenwood/*.tres` (11 visuals)
- Create: `data/presentation/equipment/siege_archer/*.tres` (11 visuals)
- Create: `assets/ui/equipment/master/greenwood/*_256.png`
- Create: `assets/ui/equipment/master/siege_archer/*_256.png`
- Create: `assets/ui/equipment/runtime/greenwood/*_128.png`
- Create: `assets/ui/equipment/runtime/siege_archer/*_128.png`
- Create: `tests/unit/test_ranged_equipment_content.gd`
- Modify: `tools/build_equipment_assets.gd`
- Modify: `tools/build_shared_humanoid_scene.gd`
- Modify: `data/equipment/core_equipment_catalog.tres`

**Interfaces:**
- Consumes: bow/quiver offhand exception, standard/heavy arrow scenes, synchronized release.
- Produces: 22 ranged items, `ranger_idle`, `marksman_idle`, `ranger_quick_bow_shot`, and `marksman_heavy_bow_shot` with visibly different timing, scale, stance, and recoil.

- [ ] **Step 1: Write failing cross-eligibility and bow-action tests**

The suite must prove: both exact 11-item manifests; Ranger and Marksman can equip both armour sets; Ranger accepts the recurve/light quiver; Marksman accepts the greatbow/heavy quiver; Ranger rejects the greatbow without `greatbow`; both bows reserve offhand yet accept item type `quiver`; no shield coexists; and release times are `0.18` for Ranger and `1.15` for Marksman.

```gdscript
TestAssertions.truthy(EquipmentEligibility.validate_equip(greenwood_jerkin, marksman, &"body_armour").is_empty(), "Marksman may wear Greenwood armour", failures)
TestAssertions.truthy(EquipmentEligibility.validate_equip(siege_coat, ranger, &"body_armour").is_empty(), "Ranger may wear Siege armour", failures)
TestAssertions.truthy(not EquipmentEligibility.validate_equip(greatbow, ranger, &"main_hand").is_empty(), "Ranger rejects greatbow", failures)
TestAssertions.near(_release_time(&"ranger_quick_bow_shot"), 0.18, 0.01, "Ranger fast release", failures)
TestAssertions.near(_release_time(&"marksman_heavy_bow_shot"), 1.15, 0.01, "Marksman slow release", failures)
```

- [ ] **Step 2: Verify the ranged suite fails before content exists**

Expected: non-zero focused run with missing content and action assertions.

- [ ] **Step 3: Add exact ranged style and weapon rules**

```gdscript
const RANGED_SET_STYLES := {
	&"ranger": {&"folder": &"greenwood", &"primary": Color("4f7a4d"), &"metal": Color("59636a"), &"leather": Color("5a3f28"), &"accent": Color("83b86a"), &"armour_shape": &"mobile_leather"},
	&"marksman": {&"folder": &"siege_archer", &"primary": Color("59613b"), &"metal": Color("4b5157"), &"leather": Color("493b2a"), &"accent": Color("a89d5b"), &"armour_shape": &"braced_leather"},
}
const RANGED_WEAPON_RULES := {
	&"greenwood_recurve_bow": {&"item_type": &"bow", &"family": &"light_bow", &"required_all": [&"ranged", &"bow_light_medium"], &"handedness": &"two_hand", &"reserved": [&"off_hand"], &"compatible_offhand": [&"quiver"]},
	&"greenwood_light_quiver": {&"item_type": &"quiver", &"family": &"light_bow", &"required_all": [&"ranged", &"bow_light_medium"]},
	&"siege_greatbow": {&"item_type": &"bow", &"family": &"greatbow", &"required_all": [&"ranged", &"greatbow"], &"handedness": &"two_hand", &"reserved": [&"off_hand"], &"compatible_offhand": [&"quiver"]},
	&"siege_heavy_quiver": {&"item_type": &"quiver", &"family": &"greatbow", &"required_all": [&"ranged", &"greatbow"]},
}
```

Both armour sets use `required_all_tags = [&"ranged"]`; Greenwood weights are light, Siege coat/leggings are medium, and accessories remain universal.

- [ ] **Step 4: Author distinct ranged actions**

`ranger_idle` is a narrow, mobile bow-ready loop; `marksman_idle` is a wide, planted brace loop. `ranger_quick_bow_shot`: duration `0.42`, release `0.18`, narrow mobile stance, quick draw, low recoil. `marksman_heavy_bow_shot`: duration `1.55`, release `1.15`, widened planted stance, long two-arm draw, torso brace, and visible recoil. Both method events are `release`; the standard arrow uses scale `Vector3.ONE`, heavy arrow uses `Vector3(1.45, 1.45, 1.45)`.

- [ ] **Step 5: Generate, render, re-link, and test the ranged wave**

Run the Task 6 command sequence with `--sets=ranger,marksman` and the ranged suite. Expected: 22 scenes, 44 icons, both bow/quiver loadouts valid, Ranger greatbow rejection, full `TEST_SUMMARY: PASS (80 suites)`.

- [ ] **Step 6: Commit ranged equipment and actions**

```powershell
git add tools scenes/equipment/greenwood scenes/equipment/siege_archer data/equipment data/presentation/equipment/greenwood data/presentation/equipment/siege_archer assets/ui/equipment tests/unit/test_ranged_equipment_content.gd
git commit -m "feat: add Ranger and Marksman presentation sets"
```

### Task 8: Mage, Frost Mage, Cleric, and Warlock Equipment and Actions

**Files:**
- Create: `scenes/equipment/emberweave/*.tscn` (11 scenes)
- Create: `scenes/equipment/rime_scholar/*.tscn` (10 scenes)
- Create: `scenes/equipment/storm_chaplain/*.tscn` (11 scenes)
- Create: `scenes/equipment/grave_covenant/*.tscn` (11 scenes)
- Create: matching 43 base resources under `data/equipment/bases/`
- Create: matching 43 visual resources under `data/presentation/equipment/`
- Create: matching 86 icon files under `assets/ui/equipment/master/` and `assets/ui/equipment/runtime/`
- Create: `tests/unit/test_caster_equipment_content.gd`
- Modify: `tools/build_equipment_assets.gd`
- Modify: `tools/build_shared_humanoid_scene.gd`
- Modify: `data/equipment/core_equipment_catalog.tres`

**Interfaces:**
- Consumes: caster eligibility, two-hand reservation, specialized spell/effect scenes, synchronized release/impact.
- Produces: 43 item entries, five synchronized attacks (Mage fire, Frost shard, Cleric lightning, Cleric heal, Warlock chaos), and four readable caster idles.

- [ ] **Step 1: Write the failing caster content/action suite**

Assert the exact four manifests and counts `11`, `10`, `11`, `11`; all default items equip on both bodies; the Frost staff reserves offhand and has no default offhand item; Mage uses wand/focus; Cleric uses sceptre/tome; Warlock uses occult wand/grimoire; and action mappings select the correct specialized scenes.

```gdscript
const EXPECTED_ACTIONS := {
	&"mage_fire_burst": [&"release", 0.46],
	&"frost_staff_shard": [&"release", 0.52],
	&"cleric_lightning_bolt": [&"release", 0.34],
	&"cleric_healing_blessing": [&"release", 0.72],
	&"warlock_chaos_bolt": [&"release", 0.64],
}
```

- [ ] **Step 2: Verify the caster suite fails before content exists**

Expected: non-zero focused run with 43 missing items/actions.

- [ ] **Step 3: Add exact caster style and weapon rules**

```gdscript
const CASTER_SET_STYLES := {
	&"mage": {&"folder": &"emberweave", &"primary": Color("7c4d9e"), &"metal": Color("61556c"), &"leather": Color("4b334f"), &"accent": Color("ff7043"), &"emissive": Color("ff5b2e"), &"armour_shape": &"light_robe"},
	&"frost_mage": {&"folder": &"rime_scholar", &"primary": Color("4f7f9e"), &"metal": Color("6b8292"), &"leather": Color("374e5c"), &"accent": Color("8ee8ff"), &"emissive": Color("8ee8ff"), &"armour_shape": &"light_robe"},
	&"cleric": {&"folder": &"storm_chaplain", &"primary": Color("d8c36a"), &"metal": Color("69727a"), &"leather": Color("66563d"), &"accent": Color("fff08a"), &"emissive": Color("fff08a"), &"armour_shape": &"reinforced_vestment"},
	&"warlock": {&"folder": &"grave_covenant", &"primary": Color("513663"), &"metal": Color("41404a"), &"leather": Color("302431"), &"accent": Color("8c45c9"), &"emissive": Color("a64de0"), &"armour_shape": &"occult_robe"},
}
const CASTER_WEAPON_RULES := {
	&"emberweave_wand": [&"wand", &"caster_wand"], &"emberweave_flame_focus": [&"focus", &"caster_focus"],
	&"rime_scholar_staff": [&"staff", &"caster_staff"],
	&"storm_chaplain_sceptre": [&"sceptre", &"divine_sceptre"], &"storm_chaplain_holy_tome": [&"tome", &"divine_tome"],
	&"grave_covenant_bone_wand": [&"wand", &"occult_wand"], &"grave_covenant_grimoire": [&"grimoire", &"occult_grimoire"],
}
```

Set the Frost staff to `two_hand`, reserve `off_hand`, and allow no exception. Cleric vestments are medium caster/support; all other caster armour is light. Accessories have no archetype restriction.

- [ ] **Step 4: Author caster idles and action events**

Mage uses an open focus-hand idle and outward fire release. Frost Mage uses a centered two-hand staff idle and sharp staff thrust. Cleric uses a calm raised-tome idle; lightning releases at `0.34`, healing at `0.72`. Warlock compresses inward, releases one-handed at `0.64`, and lingers in recoil. Each action ends inside its attack cooldown and returns to its class idle. Hit/flinch remains on the feedback player.

- [ ] **Step 5: Generate, render, re-link, and test caster content**

Run the Task 6 command sequence with `--sets=mage,frost_mage,cleric,warlock` and the caster suite. Expected: 43 scenes, 86 icons, correct two-hand reservation, specialized mappings, and full `TEST_SUMMARY: PASS (81 suites)`.

- [ ] **Step 6: Commit caster equipment and actions**

```powershell
git add tools scenes/equipment/emberweave scenes/equipment/rime_scholar scenes/equipment/storm_chaplain scenes/equipment/grave_covenant data/equipment data/presentation/equipment assets/ui/equipment tests/unit/test_caster_equipment_content.gd
git commit -m "feat: add caster presentation sets"
```

### Task 9: Class Profiles, Capability Tags, and Actual Gameplay Wiring

**Files:**
- Create: `tools/build_class_presentation_profiles.gd`
- Create: `data/presentation/profiles/paladin.tres`
- Create: `data/presentation/profiles/ranger.tres`
- Create: `data/presentation/profiles/marksman.tres`
- Create: `data/presentation/profiles/rogue.tres`
- Create: `data/presentation/profiles/mage.tres`
- Create: `data/presentation/profiles/frost_mage.tres`
- Create: `data/presentation/profiles/cleric.tres`
- Create: `data/presentation/profiles/warlock.tres`
- Create: `data/presentation/attacks/*.tres` (10 current attack mappings, including Fighter and Cleric heal)
- Create: `tests/unit/test_playable_class_presentations.gd`
- Modify: all nine `data/classes/*.tres`
- Modify: `scripts/data/class_definition.gd`
- Modify: `scripts/characters/party_actor.gd`
- Modify: `tests/unit/test_game_catalog.gd`
- Modify: `tests/unit/test_attack_execution.gd`

**Interfaces:**
- Consumes: all generated bases/visuals, shared humanoid/actions, current class/attack resources.
- Produces: one valid non-fallback profile per class, default loadout, weapon-family attack mapping, and eligibility capabilities.

- [ ] **Step 1: Write the failing nine-class gameplay presentation suite**

Instantiate both `leader.tscn` and `companion.tscn` for each `GameCatalog.CLASS_PATHS` definition. Assert `active_profile`, hidden fallback, shared humanoid scene, 11 occupied sheet slots except Frost's reserved offhand, both body switches, idle/action/hit feedback, unchanged collision radius/height and actor groups, and a real synchronized attack/heal affecting the locked target only after release.

```gdscript
const PROFILE_IDS := {
	&"fighter": &"forge_vanguard", &"paladin": &"paladin", &"ranger": &"ranger", &"marksman": &"marksman", &"rogue": &"rogue",
	&"mage": &"mage", &"frost_mage": &"frost_mage", &"cleric": &"cleric", &"warlock": &"warlock",
}
```

- [ ] **Step 2: Verify the suite fails because eight classes still use fallback capsules**

Expected: non-zero focused run with eight profile activation failures.

- [ ] **Step 3: Add exact capability tags without changing current combat tags**

Append these presentation/equipment capabilities to each class resource:

```gdscript
const EQUIPMENT_CAPABILITIES := {
	&"fighter": [&"armour_heavy", &"one_hand_sword", &"shield"],
	&"paladin": [&"armour_heavy", &"one_hand_hammer", &"shield"],
	&"ranger": [&"armour_light", &"armour_medium", &"bow_light_medium"],
	&"marksman": [&"armour_light", &"armour_medium", &"bow_light_medium", &"greatbow"],
	&"rogue": [&"armour_light", &"dagger", &"dual_wield"],
	&"mage": [&"armour_light", &"caster_wand", &"caster_focus"],
	&"frost_mage": [&"armour_light", &"caster_staff"],
	&"cleric": [&"armour_light", &"armour_medium", &"divine_sceptre", &"divine_tome"],
	&"warlock": [&"armour_light", &"occult_wand", &"occult_grimoire"],
}
```

Do not remove existing tags. Update `ClassDefinition.validate()` to reject invalid starter loadouts through `EquipmentEligibility`, including offhand reservation.

- [ ] **Step 4: Generate profiles and presentation mappings**

All profiles reference `forge_humanoid_model.tscn`, default to `masculine`, include both body IDs, use the first 11 canonical items except Frost's 10, and map:

```gdscript
const IDLE_ACTIONS := {
	&"fighter": &"idle", &"paladin": &"paladin_idle", &"ranger": &"ranger_idle", &"marksman": &"marksman_idle", &"rogue": &"rogue_idle",
	&"mage": &"mage_idle", &"frost_mage": &"frost_mage_idle", &"cleric": &"cleric_idle", &"warlock": &"warlock_idle",
}
const ATTACK_ACTIONS := {
	&"fighter_cleave": [&"attack_slash", &"impact"],
	&"paladin_smite": [&"paladin_hammer_smite", &"impact"],
	&"ranger_shot": [&"ranger_quick_bow_shot", &"release"],
	&"marksman_heavy_shot": [&"marksman_heavy_bow_shot", &"release"],
	&"rogue_flurry": [&"rogue_dagger_flurry", &"impact"],
	&"mage_burst": [&"mage_fire_burst", &"release"],
	&"frost_shard": [&"frost_staff_shard", &"release"],
	&"cleric_bolt": [&"cleric_lightning_bolt", &"release"],
	&"cleric_heal": [&"cleric_healing_blessing", &"release"],
	&"warlock_bolt": [&"warlock_chaos_bolt", &"release"],
}
```

Each mapping references the specialized projectile/impact scenes from Task 5 and uses the action duration/release time authored in Tasks 4, 6, 7, and 8.

- [ ] **Step 5: Cut actual PartyActor execution over to the sequence controller**

In `_ensure_combat_runtime()`, disconnect `AttackController.attack_ready` from both `AttackExecutor.execute` and `_on_visual_attack_ready`. Create/configure one `AttackSequenceController` child and connect primary and support `attack_ready` to `_on_attack_requested`. Gate both primary and support selection on `not attack_sequence_controller.is_busy()`. Advance the sequence from `advance_combat()` using the same unpaused `delta` passed to cooldowns.

```gdscript
func _on_attack_requested(definition: AttackDefinition, target: CombatTarget) -> void:
	var presentation := _presentation()
	var attack_visual := presentation.resolve_attack_presentation(definition) if presentation != null else null
	if attack_visual == null:
		push_error("PARTY_FORGE_ATTACK_SEQUENCE_ERROR attack=%s action=<missing> token=0 reason=presentation missing" % definition.id)
		return
	var modifiers := CombatModifiersScript.resolve(member_state, party_manager)
	attack_sequence_controller.request(definition, target, attack_visual, float(modifiers.get("cooldown_rate_multiplier")), float(modifiers.get("range_multiplier")))
```

Remove the immediate executor and `_on_visual_attack_ready` signal connections completely. No class may retain a direct-execution bypass after this commit.

- [ ] **Step 6: Generate, import, and verify live actor wiring**

```powershell
& $godot --headless --path . --script res://tools/build_class_presentation_profiles.gd
& $godot --headless --path . --editor --quit-after 3
& $godot --headless --path . --script res://tests/focused_test_runner.gd -- res://tests/unit/test_playable_class_presentations.gd res://tests/unit/test_attack_execution.gd res://tests/unit/test_game_catalog.gd
& $godot --headless --path . --script res://tests/test_runner.gd
```

Expected: `CLASS_PRESENTATION_PROFILE_BUILD_OK classes=9 attacks=10`, all nine leader/companion variants avoid fallback, live attacks/heal synchronize, full `TEST_SUMMARY: PASS (82 suites)`.

- [ ] **Step 7: Commit class profiles and gameplay wiring**

```powershell
git add tools/build_class_presentation_profiles.gd data/presentation/profiles data/presentation/attacks data/classes scripts/data/class_definition.gd scripts/characters/party_actor.gd tests/unit/test_playable_class_presentations.gd tests/unit/test_game_catalog.gd tests/unit/test_attack_execution.gd
git commit -m "feat: wire playable class presentations"
```

### Task 10: Presentation Sandbox, Contact Sheets, and Fail-Closed Smoke

**Files:**
- Create: `tools/build_equipment_contact_sheets.gd`
- Create: `assets/ui/equipment/contact_sheets/*.png` (9 sheets)
- Modify: `scenes/dev/character_presentation_sandbox.tscn`
- Modify: `scripts/dev/character_presentation_sandbox.gd`
- Modify: `tests/unit/test_character_presentation_sandbox.gd`
- Modify: `tests/integration/character_presentation_sandbox_runner.gd`

**Interfaces:**
- Consumes: nine profiles, two body presets, 99 items, all actions/effects, 198 icon outputs.
- Produces: interactive nine-class/body/action/equipment review and marker `PARTY_FORGE_PLAYABLE_PRESENTATION_SMOKE_OK classes=9 bodies=2 slots=11 items=99 icons=198 animations=21 projectiles=6 effects=5`.

- [ ] **Step 1: Write the failing sandbox/smoke contract suite**

Assert nine class selectors, masculine/feminine selector, all 11 slot selectors, Fighter hammer option, idle/attack/hit controls, specialized effect preview, and a diagnostics label showing class/body/item/action IDs. Assert the existing integration runner's success marker contains the exact counts above.

- [ ] **Step 2: Verify the suite fails against the current Fighter-only sandbox**

Expected: non-zero focused run with missing class/body controls and smoke script.

- [ ] **Step 3: Expand the sandbox without changing runtime actor scenes**

Use `GameCatalog.load_defaults()` as the class source. Selection calls `CharacterPresentation.apply_profile()`, `set_body_preset()`, and the equipment APIs; action preview calls the same profile resolution used by `PartyActor`. The sandbox may instantiate review-only actor copies but must not modify `leader.tscn`, `companion.tscn`, or `main.tscn`.

- [ ] **Step 4: Generate deterministic contact sheets**

Create a transparent 512x384 image per set, with four 128x128 columns and enough rows for all items. Copy each runtime icon into its canonical manifest index. File names are `<set_folder>_contact_sheet.png`; unused cells remain transparent. Rerunning the tool must produce no diff.

```powershell
& $godot --headless --path . --script res://tools/build_equipment_contact_sheets.gd
git diff --exit-code -- assets/ui/equipment/contact_sheets
```

- [ ] **Step 5: Implement fail-closed presentation smoke**

Expand `tests/integration/character_presentation_sandbox_runner.gd` to load the real catalog, validate all resources, instantiate every class with both bodies, equip every legal default, select Fighter hammer, verify sockets/bounds/icons/actions, instantiate each specialized scene, and print the exact success marker only when no error exists. Any mismatch prints `PARTY_FORGE_PLAYABLE_PRESENTATION_SMOKE_ERROR` with class/body/slot/item/action IDs and exits `1`.

- [ ] **Step 6: Run sandbox, smoke, icon, and full automated checks**

```powershell
& $godot --headless --path . --script res://tests/focused_test_runner.gd -- res://tests/unit/test_character_presentation_sandbox.gd
& $godot --headless --path . --script res://tests/integration/character_presentation_sandbox_runner.gd
& $godot --headless --path . --script res://tools/validate_equipment_icons.gd -- --sets=all
& $godot --headless --path . --script res://tests/test_runner.gd
```

Expected: exact smoke marker, `EQUIPMENT_ICON_VALIDATION_OK items=99`, and full `TEST_SUMMARY: PASS (82 suites)`.

- [ ] **Step 7: Commit review tooling and contact sheets**

```powershell
git add tools scenes/dev scripts/dev assets/ui/equipment/contact_sheets tests/unit/test_character_presentation_sandbox.gd tests/integration/character_presentation_sandbox_runner.gd
git commit -m "test: add playable class presentation review tools"
```

### Task 11: Recorded Visual QA, Blender Handoff, and Final Verification

**Files:**
- Create: `docs/qa/2026-08-01-playable-class-presentation-validation.md`
- Create: `docs/art/party-forge-character-blender-handoff.md`
- Modify: `README.md`
- Modify: `docs/superpowers/specs/2026-08-01-playable-class-model-equipment-expansion-design.md`

**Interfaces:**
- Consumes: the complete implementation and all recorded commands.
- Produces: reproducible QA evidence, reusable nude-body/equipped-file paths, socket/action/event contract for future class and Blender threads, and a clean implementation handoff.

- [ ] **Step 1: Run a clean regeneration check**

Run every builder in dependency order: shared humanoid, combat presentation, all equipment sets, icon import/render/import/re-link, profiles, base bodies, contact sheets. Run each deterministic builder a second time and require `git diff --exit-code` for generated files before accepting intentional first-run changes.

- [ ] **Step 2: Run all automated and smoke checks from a clean Godot process**

```powershell
& $godot --headless --path . --editor --quit-after 3
& $godot --headless --path . --script res://tests/test_runner.gd
& $godot --headless --path . --script res://tests/integration/character_presentation_sandbox_runner.gd
& $godot --headless --path . --script res://tools/validate_equipment_icons.gd -- --sets=all
```

Record the actual suite count rather than assuming `82` if another integrated branch legitimately adds suites. A timeout is not a pass.

- [ ] **Step 3: Perform the manual visual matrix and record evidence**

Open the sandbox and review Fighter plus eight new classes at gameplay camera distance, masculine lineup then feminine lineup, in front/three-quarter/side/rear views. For every class, play idle, primary, hit/flinch; also play Cleric heal and Fighter hammer alternative. Record clipping, socket, scale, palette, event-timing, arrow-size, and effect findings. Correct any defect in the owning earlier task file, rerun its focused suite, then rerun the full smoke.

- [ ] **Step 4: Document reusable files and the later Blender contract**

The Blender handoff must name:

```text
scenes/characters/presentation/forge_base_masculine.tscn
scenes/characters/presentation/forge_base_feminine.tscn
scenes/characters/presentation/forge_humanoid_model.tscn
scenes/equipment/<set>/<item_id>.tscn
data/equipment/bases/<set>/<item_id>.tres
data/presentation/equipment/<set>/<item_id>.tres
assets/ui/equipment/master/<set>/<item_id>_256.png
assets/ui/equipment/runtime/<set>/<item_id>_128.png
```

Document that GLB replacements must preserve scene roots, meters/scale, forward axis, both body-fit presets, socket IDs, item IDs, material channel names, weapon family, launch socket, action IDs, event names, bounds, and icon regeneration behavior.

- [ ] **Step 5: Inspect final Git scope and request code review**

```powershell
git status --short
git diff --stat main...HEAD
git log --oneline main..HEAD
```

Confirm no pre-existing `main.tscn` or currency import changes entered the branch. Use `superpowers:requesting-code-review`, resolve correctness findings, and rerun affected focused/full checks.

- [ ] **Step 6: Commit documentation and evidence**

```powershell
git add README.md docs/qa/2026-08-01-playable-class-presentation-validation.md docs/art/party-forge-character-blender-handoff.md docs/superpowers/specs/2026-08-01-playable-class-model-equipment-expansion-design.md
git commit -m "docs: record playable class presentation validation"
```

## Completion Gate

Do not report completion unless all of the following are recorded in the QA document:

- Exactly 99 unique equipment bases and 99 linked presentation resources.
- Exactly 198 tracked item icons with valid dimensions, alpha, visible content, and padding.
- Nine valid class profiles, two functioning body presets, eleven sheet slots, and two reusable unequipped body scenes.
- Ranger/Marksman armour exchange, Ranger greatbow rejection, Frost staff reservation, and bow/quiver exception.
- Fighter red sword/shield default and preserved hammer alternative.
- No damage, projectile, or healing before release; exactly one execution after release.
- Ranger/Marksman draw and arrow-scale distinction.
- Specialized fire, frost, lightning, heal, chaos, standard-arrow, and heavy-arrow presentation with generic fallback after release.
- Actual leader/companion gameplay presentation, collision, groups, hit/flinch, downed/revive, fallback, palette, and damage/heal regression checks.
- Deterministic asset/icon/contact-sheet regeneration, full automated pass, fail-closed presentation smoke, and manual visual matrix.
