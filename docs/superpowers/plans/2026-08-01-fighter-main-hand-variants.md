# Fighter Main-Hand Variants Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve the current Fighter weapon unchanged as an immediately selectable hammer, add and default-equip a distinct sword, and replace the mannequin idle with a combat-ready sword-and-shield guard.

**Architecture:** `CharacterVisualProfile` will allow multiple available definitions per slot while keeping one default per slot and backward-compatible first-match lookup. The generated Forge Vanguard scene will contain separate hammer and sword roots under the right-hand socket; the existing presentation adapter will select one by `geometry_key`. Animation generation will add an explicit guard pose used by idle and every action boundary, and the sandbox will cycle variants through the same profile and adapter APIs future equipment consumers will use.

**Tech Stack:** Godot 4.7.1, GDScript, `.tres` resources, generated `.tscn` scenes, the existing custom RefCounted unit runner, and the headless presentation smoke runner.

## Global Constraints

- Preserve the current hammer mesh size `Vector3(0.09, 0.92, 0.07)`, root position `Vector3(0.03, 0.11, 0)`, material region, socket, and visible shape unchanged.
- Fighter defaults to `forge_vanguard_sword`; both reusable base profiles remain unequipped by default.
- Available equipment permits sword and hammer in `main_hand`; default equipment still permits only one definition per slot.
- Keep idle at `1.6` seconds, slash at `0.55`, combo at `0.9`, and flinch at `0.25`.
- Do not animate the model root or change PartyActor, collision, navigation, combat targeting, damage timing, or attack execution.
- Keep red/blue/green palette isolation, hit flash, downed grayscale, and fallback behavior unchanged.
- Generate equipped and base scenes through their builders; never hand-edit generated `.tscn` output.
- Run scene generation twice and require identical SHA-256 hashes before committing generated scenes.
- Preserve user-owned `scenes/game/main.tscn` and `assets/ui/currency/` changes; never stage them.
- Preserve `C:\Users\Jacob\AppData\Roaming\Godot\app_userdata\Party Forge\party_forge_settings.cfg` and verify `experience_multiplier_percent=300` after every full-suite run.
- Use `F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe` for headless commands.

---

## File Responsibility Map

- `scripts/presentation/character_visual_profile.gd`: profile validation and variant lookup API.
- `data/presentation/equipment/forge_vanguard_hammer.tres`: preserved hammer definition.
- `data/presentation/equipment/forge_vanguard_sword.tres`: stable sword definition pointing at the new sword geometry.
- `data/presentation/profiles/forge_vanguard.tres`: sword default plus sword/hammer availability.
- `data/presentation/profiles/forge_base_masculine.tres`: no defaults, both main-hand variants available.
- `data/presentation/profiles/forge_base_feminine.tres`: no defaults, both main-hand variants available.
- `tools/build_forge_vanguard_scene.gd`: authoritative hammer/sword geometry and guard/action animation generation.
- `tools/build_forge_base_body_scenes.gd`: consumes the equipped source and clears every equipment variant.
- `scenes/characters/presentation/forge_vanguard_model.tscn`: generated equipped scene.
- `scenes/characters/presentation/forge_base_masculine.tscn`: generated neutral masculine scene.
- `scenes/characters/presentation/forge_base_feminine.tscn`: generated neutral feminine scene.
- `scripts/dev/character_presentation_sandbox.gd`: public equip/cycle state and `V` control.
- `scenes/dev/character_presentation_sandbox.tscn`: updated control copy.
- `tests/unit/test_character_visual_data.gd`: variant validation and lookup contracts.
- `tests/unit/test_forge_vanguard_model.gd`: resources, unchanged hammer, distinct sword, and one-visible-item behavior.
- `tests/unit/test_forge_base_bodies.gd`: two main-hand roots hidden in reusable bases.
- `tests/unit/test_forge_vanguard_animations.gd`: combat-ready guard at idle and action boundaries.
- `tests/unit/test_character_presentation_sandbox.gd`: sandbox variant-cycle behavior and controls.
- `tests/integration/character_presentation_sandbox_runner.gd`: end-to-end sword/hammer switching smoke.
- `docs/handbook/08-visuals-audio-effects-and-ui.md`: implemented equipment-variant and guard contract.

---

### Task 1: Support Multiple Available Visuals Per Slot

**Files:**
- Modify: `scripts/presentation/character_visual_profile.gd:13-60`
- Modify: `tests/unit/test_character_visual_data.gd:1-75`
- Create (ignored execution helper): `.superpowers/sdd/run_hermetic_suite.ps1`

**Interfaces:**
- Consumes: `EquipmentVisualDefinition.id`, `.slot_id`, `.geometry_key`, and `.validate()`.
- Produces: `get_available_equipment_visual_by_id(equipment_id: StringName) -> EquipmentVisualDefinition` and `get_available_equipment_visuals_for_slot(slot_id: StringName) -> Array[EquipmentVisualDefinition]`.
- Preserves: `get_available_equipment_visual(slot_id)` returning the first declared match.

- [ ] **Step 1: Create the ignored hermetic full-suite helper and verify the baseline**

Create `.superpowers/sdd/run_hermetic_suite.ps1` with this exact content; do not stage it. Record the implementation branch base in the same ignored directory so the final scope and review commands do not depend on a guessed commit count:

```powershell
New-Item -ItemType Directory -Force .superpowers\sdd | Out-Null
git rev-parse HEAD | Set-Content .superpowers\sdd\fighter-variants-base.txt
```

Then create the helper:

```powershell
param([string]$ProjectPath = (Get-Location).Path)
$ErrorActionPreference = "Continue"
$godotExe = "F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe"
$settingsPath = "C:\Users\Jacob\AppData\Roaming\Godot\app_userdata\Party Forge\party_forge_settings.cfg"
$settingsBackup = "$settingsPath.variant-test-$([Guid]::NewGuid().ToString('N')).bak"
$hadSettings = Test-Path -LiteralPath $settingsPath
$suiteOutput = @()
$suiteExit = -1
try {
    if ($hadSettings) { Move-Item -LiteralPath $settingsPath -Destination $settingsBackup }
    $suiteOutput = & $godotExe --headless --path $ProjectPath --script res://tests/test_runner.gd 2>&1
    $suiteExit = $LASTEXITCODE
}
finally {
    if (Test-Path -LiteralPath $settingsPath) { Remove-Item -LiteralPath $settingsPath -Force }
    if ($hadSettings -and (Test-Path -LiteralPath $settingsBackup)) { Move-Item -LiteralPath $settingsBackup -Destination $settingsPath }
}
$suiteOutput | ForEach-Object { $_ }
$xpLine = if (Test-Path -LiteralPath $settingsPath) {
    (Select-String -LiteralPath $settingsPath -Pattern "^experience_multiplier_percent=").Line
} else {
    "<missing>"
}
Write-Output "HERMETIC_TEST_EXIT=$suiteExit"
Write-Output "HERMETIC_SETTINGS=$xpLine"
if ($suiteExit -ne 0 -or $xpLine -ne "experience_multiplier_percent=300") { exit 1 }
exit 0
```

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .superpowers\sdd\run_hermetic_suite.ps1
```

Expected: exit `0`, `TEST_SUMMARY: PASS (72 suites)`, `HERMETIC_TEST_EXIT=0`, and `HERMETIC_SETTINGS=experience_multiplier_percent=300`.

- [ ] **Step 2: Write failing variant validation and lookup tests**

In `tests/unit/test_character_visual_data.gd`, add a hammer definition and replace the old duplicate-slot expectation with these assertions:

```gdscript
var hammer := EquipmentVisualDefinition.new()
hammer.id = &"forge_vanguard_hammer"
hammer.slot_id = &"main_hand"
hammer.geometry_key = &"forge_vanguard_hammer"
hammer.visual_channels = [&"geometry"]
profile.available_equipment_visuals = [sword, hammer]
TestAssertions.truthy(not _errors_contain(profile.validate(), "duplicate available equipment slot"), "multiple available main-hand variants are accepted", failures)
TestAssertions.truthy(profile.has_method(&"get_available_equipment_visual_by_id"), "equipment ID lookup exists", failures)
TestAssertions.truthy(profile.has_method(&"get_available_equipment_visuals_for_slot"), "slot variant lookup exists", failures)
if profile.has_method(&"get_available_equipment_visual_by_id"):
	TestAssertions.equal(profile.call(&"get_available_equipment_visual_by_id", &"forge_vanguard_hammer"), hammer, "hammer resolves by equipment ID", failures)
	TestAssertions.equal(profile.call(&"get_available_equipment_visual_by_id", &"missing_item"), null, "unknown equipment ID returns null", failures)
if profile.has_method(&"get_available_equipment_visuals_for_slot"):
	var main_hand_variants: Array = profile.call(&"get_available_equipment_visuals_for_slot", &"main_hand")
	TestAssertions.equal(main_hand_variants.size(), 2, "main hand exposes sword and hammer", failures)
	TestAssertions.equal(main_hand_variants[0], sword, "legacy first main-hand variant remains sword", failures)
	TestAssertions.equal(main_hand_variants[1], hammer, "second main-hand variant is hammer", failures)
	var charm_variants: Array = profile.call(&"get_available_equipment_visuals_for_slot", &"charm")
	TestAssertions.truthy(charm_variants.is_empty(), "unknown slot returns an empty variant array", failures)

var duplicate_default := CharacterVisualProfile.new()
duplicate_default.id = &"duplicate_default"
duplicate_default.default_palette_id = &"red"
duplicate_default.palette_colors = {&"red": Color.WHITE}
duplicate_default.default_equipment_visuals = [sword, hammer]
TestAssertions.truthy(_errors_contain(duplicate_default.validate(), "duplicate default equipment slot main_hand"), "default equipment still rejects two main-hand items", failures)

var duplicate_id := CharacterVisualProfile.new()
duplicate_id.id = &"duplicate_id"
duplicate_id.default_palette_id = &"red"
duplicate_id.palette_colors = {&"red": Color.WHITE}
var duplicate_id_hammer := EquipmentVisualDefinition.new()
duplicate_id_hammer.id = sword.id
duplicate_id_hammer.slot_id = &"main_hand"
duplicate_id_hammer.geometry_key = hammer.geometry_key
duplicate_id_hammer.visual_channels = [&"geometry"]
duplicate_id.available_equipment_visuals = [sword, duplicate_id_hammer]
TestAssertions.truthy(_errors_contain(duplicate_id.validate(), "duplicate available equipment id forge_vanguard_sword"), "available equipment rejects duplicate IDs", failures)

var duplicate_geometry := CharacterVisualProfile.new()
duplicate_geometry.id = &"duplicate_geometry"
duplicate_geometry.default_palette_id = &"red"
duplicate_geometry.palette_colors = {&"red": Color.WHITE}
var duplicate_geometry_hammer := EquipmentVisualDefinition.new()
duplicate_geometry_hammer.id = hammer.id
duplicate_geometry_hammer.slot_id = &"main_hand"
duplicate_geometry_hammer.geometry_key = sword.geometry_key
duplicate_geometry_hammer.visual_channels = [&"geometry"]
duplicate_geometry.available_equipment_visuals = [sword, duplicate_geometry_hammer]
TestAssertions.truthy(_errors_contain(duplicate_geometry.validate(), "duplicate available geometry key forge_vanguard_sword"), "available equipment rejects duplicate geometry keys", failures)
```

- [ ] **Step 3: Run the suite and verify RED**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .superpowers\sdd\run_hermetic_suite.ps1
```

Expected: exit `1`; failures state that multiple available `main_hand` items are rejected and the two new lookup methods are missing. The settings line must still report `experience_multiplier_percent=300`.

- [ ] **Step 4: Implement the minimal profile variant API and collection-specific validation**

Add these methods to `scripts/presentation/character_visual_profile.gd`:

```gdscript
func get_available_equipment_visual_by_id(equipment_id: StringName) -> EquipmentVisualDefinition:
	for definition: EquipmentVisualDefinition in available_equipment_visuals:
		if definition != null and definition.id == equipment_id:
			return definition
	return null

func get_available_equipment_visuals_for_slot(slot_id: StringName) -> Array[EquipmentVisualDefinition]:
	var matches: Array[EquipmentVisualDefinition] = []
	for definition: EquipmentVisualDefinition in available_equipment_visuals:
		if definition != null and definition.slot_id == slot_id:
			matches.append(definition)
	return matches
```

Replace `_validate_equipment_visuals` with:

```gdscript
func _validate_equipment_visuals(definitions: Array[EquipmentVisualDefinition], collection_name: StringName, errors: PackedStringArray) -> void:
	var equipment_slots: Dictionary = {}
	var equipment_ids: Dictionary = {}
	var geometry_keys: Dictionary = {}
	for definition: EquipmentVisualDefinition in definitions:
		if definition == null:
			errors.append("profile %s has null %s equipment visual" % [id, collection_name])
			continue
		for reason: String in definition.validate():
			errors.append("profile %s %s" % [id, reason])
		if equipment_ids.has(definition.id):
			errors.append("profile %s has duplicate %s equipment id %s" % [id, collection_name, definition.id])
		equipment_ids[definition.id] = true
		if not definition.geometry_key.is_empty() and geometry_keys.has(definition.geometry_key):
			errors.append("profile %s has duplicate %s geometry key %s" % [id, collection_name, definition.geometry_key])
		geometry_keys[definition.geometry_key] = true
		if collection_name == &"default" and equipment_slots.has(definition.slot_id):
			errors.append("profile %s has duplicate default equipment slot %s" % [id, definition.slot_id])
		equipment_slots[definition.slot_id] = true
```

Do not change `get_available_equipment_visual(slot_id)`.

- [ ] **Step 5: Run GREEN verification**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .superpowers\sdd\run_hermetic_suite.ps1
```

Expected: exit `0`, `TEST_SUMMARY: PASS (72 suites)`, and settings restored to `300`.

- [ ] **Step 6: Commit Task 1**

```powershell
git add -- scripts/presentation/character_visual_profile.gd tests/unit/test_character_visual_data.gd
git diff --cached --check
git commit -m "feat: support equipment variants per slot"
```

Expected: one commit containing exactly the profile and its unit test; `.superpowers` remains ignored.

---

### Task 2: Preserve the Hammer and Add a Separate Sword

**Files:**
- Create: `data/presentation/equipment/forge_vanguard_hammer.tres`
- Inspect and preserve unchanged: `data/presentation/equipment/forge_vanguard_sword.tres`
- Modify: `data/presentation/profiles/forge_vanguard.tres`
- Modify: `data/presentation/profiles/forge_base_masculine.tres`
- Modify: `data/presentation/profiles/forge_base_feminine.tres`
- Modify: `tools/build_forge_vanguard_scene.gd:8-210`
- Regenerate: `scenes/characters/presentation/forge_vanguard_model.tscn`
- Regenerate: `scenes/characters/presentation/forge_base_masculine.tscn`
- Regenerate: `scenes/characters/presentation/forge_base_feminine.tscn`
- Modify: `tests/unit/test_forge_vanguard_model.gd`
- Modify: `tests/unit/test_forge_base_bodies.gd`

**Interfaces:**
- Consumes: Task 1 variant lookup/validation and existing `ForgeVanguardModel.apply_equipment_visual(slot_id, definition)`.
- Produces: geometry keys `forge_vanguard_sword` and `forge_vanguard_hammer`, both in `main_hand`; generated roots `SwordVisual` and `HammerVisual`.
- Preserves: the old box mesh exactly under `HammerVisual`.

- [ ] **Step 1: Write failing model, profile, base-body, and swapping tests**

In `tests/unit/test_forge_vanguard_model.gd`, add:

```gdscript
const SWORD_PATH := "res://data/presentation/equipment/forge_vanguard_sword.tres"
const HAMMER_PATH := "res://data/presentation/equipment/forge_vanguard_hammer.tres"
```

Add this call before `model.free()`:

```gdscript
_assert_main_hand_variants(model, profile, failures)
```

Add this helper:

```gdscript
func _assert_main_hand_variants(model: Node3D, profile: CharacterVisualProfile, failures: Array[String]) -> void:
	var sword := load(SWORD_PATH) as EquipmentVisualDefinition
	var hammer := load(HAMMER_PATH) as EquipmentVisualDefinition
	TestAssertions.truthy(sword != null and hammer != null, "sword and hammer definitions load", failures)
	if sword == null or hammer == null:
		return
	var variants := profile.get_available_equipment_visuals_for_slot(&"main_hand")
	TestAssertions.equal(variants.size(), 2, "Fighter profile exposes two main-hand variants", failures)
	TestAssertions.equal(variants[0].id, &"forge_vanguard_sword", "sword remains first main-hand variant", failures)
	TestAssertions.equal(variants[1].id, &"forge_vanguard_hammer", "hammer is the second main-hand variant", failures)
	TestAssertions.equal(profile.default_equipment_visuals[0].id, &"forge_vanguard_sword", "Fighter defaults to sword", failures)
	var hammer_root := _equipment_root_by_visual_id(model, &"forge_vanguard_hammer")
	var sword_root := _equipment_root_by_visual_id(model, &"forge_vanguard_sword")
	TestAssertions.truthy(hammer_root != null and sword_root != null, "separate hammer and sword roots exist", failures)
	if hammer_root == null or sword_root == null:
		return
	var hammer_mesh := hammer_root.get_node_or_null("ReadableChannel") as MeshInstance3D
	TestAssertions.truthy(hammer_mesh != null and hammer_mesh.mesh is BoxMesh, "preserved hammer remains one box mesh", failures)
	if hammer_mesh != null and hammer_mesh.mesh is BoxMesh:
		TestAssertions.equal((hammer_mesh.mesh as BoxMesh).size, Vector3(0.09, 0.92, 0.07), "hammer dimensions are unchanged", failures)
	TestAssertions.equal(hammer_root.position, Vector3(0.03, 0.11, 0), "hammer socket position is unchanged", failures)
	for part_name: StringName in [&"Blade", &"Tip", &"Crossguard", &"Grip", &"Pommel"]:
		TestAssertions.truthy(sword_root.get_node_or_null(NodePath(part_name)) is MeshInstance3D, "sword part exists: %s" % part_name, failures)
	TestAssertions.truthy(model.call(&"apply_equipment_visual", &"main_hand", hammer), "hammer equips", failures)
	TestAssertions.truthy(hammer_root.visible and not sword_root.visible, "equipping hammer hides sword", failures)
	TestAssertions.truthy(model.call(&"apply_equipment_visual", &"main_hand", sword), "sword equips", failures)
	TestAssertions.truthy(sword_root.visible and not hammer_root.visible, "equipping sword hides hammer", failures)

func _equipment_root_by_visual_id(model: Node3D, visual_id: StringName) -> Node3D:
	for node: Node in model.find_children("*", "Node3D", true, false):
		if StringName(node.get_meta(&"equipment_visual_id", &"")) == visual_id:
			return node as Node3D
	return null
```

Update `_assert_invalid_geometry_keys_do_not_change_slot` to locate the sword root by visual ID instead of using the first `main_hand` root.

In `tests/unit/test_forge_base_bodies.gd`, change the available count assertion to `EquipmentSlotCatalog.SLOT_IDS.size() + 1`, replace `_equipment_root` with `_equipment_roots`, and assert every root is hidden:

```gdscript
for slot_id: StringName in EquipmentSlotCatalog.SLOT_IDS:
	var equipment_roots := _equipment_roots(model, slot_id)
	var expected_count := 2 if slot_id == &"main_hand" else 1
	TestAssertions.equal(equipment_roots.size(), expected_count, "%s base scene retains %s variants" % [preset_id, slot_id], failures)
	for equipment_root: Node3D in equipment_roots:
		TestAssertions.truthy(not equipment_root.visible, "%s base scene hides %s variant %s" % [preset_id, slot_id, equipment_root.name], failures)

func _equipment_roots(model: Node3D, slot_id: StringName) -> Array[Node3D]:
	var roots: Array[Node3D] = []
	for node: Node in model.find_children("*", "Node3D", true, false):
		if StringName(node.get_meta(&"equipment_slot", &"")) == slot_id:
			roots.append(node as Node3D)
	return roots
```

- [ ] **Step 2: Run the suite and verify RED**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .superpowers\sdd\run_hermetic_suite.ps1
```

Expected: exit `1`; the hammer resource is missing, profiles expose only one `main_hand`, `HammerVisual`/sword parts do not exist, and bases retain only one main-hand root.

- [ ] **Step 3: Create the hammer resource and add both variants to all profiles**

Create `data/presentation/equipment/forge_vanguard_hammer.tres`:

```text
[gd_resource type="Resource" script_class="EquipmentVisualDefinition" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/presentation/equipment_visual_definition.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"forge_vanguard_hammer"
slot_id = &"main_hand"
geometry_key = &"forge_vanguard_hammer"
visual_channels = [&"geometry"]
```

In each of the three profiles, add the hammer as a new external resource after the sword. Keep `default_equipment_visuals` unchanged. Change `available_equipment_visuals` to place hammer immediately after sword:

```text
[ext_resource type="Resource" path="res://data/presentation/equipment/forge_vanguard_hammer.tres" id="13"]
available_equipment_visuals = [ExtResource("3"), ExtResource("13"), ExtResource("4"), ExtResource("5"), ExtResource("6"), ExtResource("7"), ExtResource("8"), ExtResource("9"), ExtResource("10"), ExtResource("11"), ExtResource("12")]
```

Increment each profile's `load_steps` from `13` to `14`. Leave `forge_vanguard_sword.tres` at its stable path, ID, slot, and geometry key.

- [ ] **Step 4: Generate separate hammer and sword roots without altering the hammer**

In `_initialize`, replace the old sword call with:

```gdscript
_add_hammer(limb_pivots[&"right_hand"])
_add_sword(limb_pivots[&"right_hand"])
```

Add these exact helpers to `tools/build_forge_vanguard_scene.gd`:

```gdscript
func _equipment_root(parent: Node3D, node_name: StringName, slot_id: StringName, visual_id: StringName, position: Vector3, starts_visible: bool) -> Node3D:
	var equipment := Node3D.new()
	equipment.name = node_name
	equipment.position = position
	equipment.visible = starts_visible
	equipment.set_meta(&"equipment_slot", slot_id)
	equipment.set_meta(&"equipment_visual_id", visual_id)
	parent.add_child(equipment)
	return equipment

func _add_hammer(parent: Node3D) -> void:
	var hammer := _equipment_root(parent, &"HammerVisual", &"main_hand", &"forge_vanguard_hammer", Vector3(0.03, 0.11, 0), false)
	_mesh(hammer, &"ReadableChannel", Vector3.ZERO, Vector3(0.09, 0.92, 0.07), &"metal")

func _add_sword(parent: Node3D) -> void:
	var sword := _equipment_root(parent, &"SwordVisual", &"main_hand", &"forge_vanguard_sword", Vector3(0.03, 0.09, 0), true)
	_mesh(sword, &"Blade", Vector3(0, 0.38, 0), Vector3(0.10, 0.68, 0.035), &"metal")
	_sword_tip(sword, Vector3(0, 0.80, 0))
	_mesh(sword, &"Crossguard", Vector3(0, 0.02, 0), Vector3(0.30, 0.055, 0.08), &"metal")
	_mesh(sword, &"Grip", Vector3(0, -0.11, 0), Vector3(0.065, 0.22, 0.065), &"leather")
	_mesh(sword, &"Pommel", Vector3(0, -0.25, 0), Vector3(0.09, 0.08, 0.08), &"metal")

func _sword_tip(parent: Node3D, position: Vector3) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = &"Tip"
	mesh_instance.position = position
	var tip := CylinderMesh.new()
	tip.top_radius = 0.0
	tip.bottom_radius = 0.065
	tip.height = 0.16
	tip.radial_segments = 4
	mesh_instance.mesh = tip
	mesh_instance.material_override = _material(&"metal")
	mesh_instance.set_meta(&"palette_region", &"metal")
	parent.add_child(mesh_instance)
```

Refactor `_add_equipment` to create its root through `_equipment_root`:

```gdscript
var equipment := _equipment_root(parent, _equipment_node_name(slot_id), slot_id, visual_id, position, starts_visible)
```

Remove its duplicated root construction lines. Other slots remain unchanged.

- [ ] **Step 5: Regenerate equipped and base scenes twice and prove determinism**

Run:

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --path . --script res://tools/build_forge_vanguard_scene.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $godot --headless --path . --script res://tools/build_forge_base_body_scenes.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$first = Get-FileHash scenes/characters/presentation/forge_vanguard_model.tscn,scenes/characters/presentation/forge_base_masculine.tscn,scenes/characters/presentation/forge_base_feminine.tscn -Algorithm SHA256
& $godot --headless --path . --script res://tools/build_forge_vanguard_scene.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $godot --headless --path . --script res://tools/build_forge_base_body_scenes.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$second = Get-FileHash scenes/characters/presentation/forge_vanguard_model.tscn,scenes/characters/presentation/forge_base_masculine.tscn,scenes/characters/presentation/forge_base_feminine.tscn -Algorithm SHA256
for ($i = 0; $i -lt $first.Count; $i++) {
    if ($first[$i].Hash -ne $second[$i].Hash) { throw "Non-deterministic scene: $($first[$i].Path)" }
    Write-Output "DETERMINISTIC $($first[$i].Hash) $($first[$i].Path)"
}
```

Expected: both builders exit `0`; all three paths print `DETERMINISTIC` with matching hashes.

- [ ] **Step 6: Run GREEN verification**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .superpowers\sdd\run_hermetic_suite.ps1
```

Expected: exit `0`, `TEST_SUMMARY: PASS (72 suites)`, hammer dimensions/transform preserved, sword/hammer swapping passes, bases hide both variants, and settings remain `300`.

- [ ] **Step 7: Commit Task 2**

```powershell
git add -- data/presentation/equipment/forge_vanguard_hammer.tres data/presentation/profiles/forge_vanguard.tres data/presentation/profiles/forge_base_masculine.tres data/presentation/profiles/forge_base_feminine.tres tools/build_forge_vanguard_scene.gd scenes/characters/presentation/forge_vanguard_model.tscn scenes/characters/presentation/forge_base_masculine.tscn scenes/characters/presentation/forge_base_feminine.tscn tests/unit/test_forge_vanguard_model.gd tests/unit/test_forge_base_bodies.gd
git diff --cached --check
git commit -m "feat: add Fighter sword and preserve hammer"
```

Expected: the commit contains the new hammer definition, separate generated weapon roots, three updated profiles/scenes, generator changes, and focused tests only.

---

### Task 3: Replace the Mannequin Idle With a Combat-Ready Guard

**Files:**
- Modify: `tools/build_forge_vanguard_scene.gd:32-124`
- Regenerate: `scenes/characters/presentation/forge_vanguard_model.tscn`
- Regenerate: `scenes/characters/presentation/forge_base_masculine.tscn`
- Regenerate: `scenes/characters/presentation/forge_base_feminine.tscn`
- Modify: `tests/unit/test_forge_vanguard_animations.gd`

**Interfaces:**
- Consumes: existing animation IDs, durations, animated pivot paths, and both main-hand roots from Task 2.
- Produces: one explicit guard rotation dictionary used at every idle key and at the first/final key of slash, combo, and flinch.
- Preserves: action peak poses, root-motion prohibition, durations, queue-to-idle behavior, and combat timing.

- [ ] **Step 1: Write failing exact guard-boundary tests**

In `tests/unit/test_forge_vanguard_animations.gd`, add:

```gdscript
const EXPECTED_GUARD_ROTATIONS := {
	&"left_shoulder": Vector3(-0.28, -0.05, -0.55),
	&"left_elbow": Vector3(0.10, 0.0, -0.65),
	&"right_shoulder": Vector3(-0.18, -0.16, 0.34),
	&"right_elbow": Vector3(0.10, 0.0, 0.38),
}
const PIVOT_PATHS := {
	&"left_shoulder": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot",
	&"left_elbow": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/LeftShoulderPivot/LeftElbowPivot",
	&"right_shoulder": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot",
	&"right_elbow": "HitPivot/BodyPivot/HipsPivot/TorsoPivot/RightShoulderPivot/RightElbowPivot",
}
```

Call `_assert_guard_contract(player, failures)` after animation metadata, then add:

```gdscript
func _assert_guard_contract(player: AnimationPlayer, failures: Array[String]) -> void:
	for animation_id: StringName in EXPECTED_LENGTHS:
		var animation := player.get_animation(animation_id)
		for pivot_id: StringName in EXPECTED_GUARD_ROTATIONS:
			var expected := Quaternion.from_euler(EXPECTED_GUARD_ROTATIONS[pivot_id] as Vector3)
			var start := _sample_rotation(animation, String(PIVOT_PATHS[pivot_id]), 0.0)
			var finish := _sample_rotation(animation, String(PIVOT_PATHS[pivot_id]), animation.length)
			TestAssertions.truthy(start.is_equal_approx(expected), "%s begins in guard at %s" % [animation_id, pivot_id], failures)
			TestAssertions.truthy(finish.is_equal_approx(expected), "%s recovers to guard at %s" % [animation_id, pivot_id], failures)

func _sample_rotation(animation: Animation, node_path: String, time: float) -> Quaternion:
	var track_path := NodePath("%s:rotation" % node_path)
	var track_index := animation.find_track(track_path, Animation.TYPE_ROTATION_3D)
	if track_index < 0:
		return Quaternion.IDENTITY
	return animation.rotation_track_interpolate(track_index, time)
```

- [ ] **Step 2: Run the suite and verify RED**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .superpowers\sdd\run_hermetic_suite.ps1
```

Expected: exit `1`; every clip currently begins and ends with identity arm rotations instead of the expected combat guard. Settings still restore to `300`.

- [ ] **Step 3: Add an explicit guard-pose constructor and use it at boundaries**

Add to `tools/build_forge_vanguard_scene.gd`:

```gdscript
const GUARD_ROTATIONS := {
	&"left_shoulder": Vector3(-0.28, -0.05, -0.55),
	&"left_elbow": Vector3(0.10, 0.0, -0.65),
	&"right_shoulder": Vector3(-0.18, -0.16, 0.34),
	&"right_elbow": Vector3(0.10, 0.0, 0.38),
}

func _guard_pose(time: float, position_overrides: Dictionary = {}, rotation_offsets: Dictionary = {}) -> Dictionary:
	var rotations := GUARD_ROTATIONS.duplicate()
	for pivot_id: Variant in rotation_offsets:
		rotations[pivot_id] = (rotations.get(pivot_id, Vector3.ZERO) as Vector3) + (rotation_offsets[pivot_id] as Vector3)
	return _pose(time, position_overrides, rotations)
```

Use `_guard_pose` for all five idle keys. The breathing offsets must be:

```gdscript
_guard_pose(0.00),
_guard_pose(0.40, {&"body": Vector3(0, 0.018, 0), &"torso": Vector3(0, 0.238, 0)}, {&"left_shoulder": Vector3(0, 0, -0.025), &"right_shoulder": Vector3(0, 0, 0.025)}),
_guard_pose(0.80, {&"body": Vector3(-0.025, 0.008, 0), &"torso": Vector3(0, 0.226, 0)}, {&"left_shoulder": Vector3(0, 0, -0.04), &"right_elbow": Vector3(0, 0, 0.04)}),
_guard_pose(1.20, {&"body": Vector3(0, -0.010, 0), &"torso": Vector3(0, 0.210, 0)}, {&"left_elbow": Vector3(0, 0, -0.03), &"right_shoulder": Vector3(0, 0, 0.02)}),
_guard_pose(1.60),
```

For `attack_slash`, `attack_combo`, and `hit_flinch`, replace only the first and final `_pose(...)` calls with `_guard_pose(...)`. Keep every intermediate attack/flinch peak call unchanged.

- [ ] **Step 4: Regenerate all three scenes twice and verify deterministic hashes**

Run:

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --path . --script res://tools/build_forge_vanguard_scene.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $godot --headless --path . --script res://tools/build_forge_base_body_scenes.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$first = Get-FileHash scenes/characters/presentation/forge_vanguard_model.tscn,scenes/characters/presentation/forge_base_masculine.tscn,scenes/characters/presentation/forge_base_feminine.tscn -Algorithm SHA256
& $godot --headless --path . --script res://tools/build_forge_vanguard_scene.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $godot --headless --path . --script res://tools/build_forge_base_body_scenes.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$second = Get-FileHash scenes/characters/presentation/forge_vanguard_model.tscn,scenes/characters/presentation/forge_base_masculine.tscn,scenes/characters/presentation/forge_base_feminine.tscn -Algorithm SHA256
for ($i = 0; $i -lt $first.Count; $i++) {
    if ($first[$i].Hash -ne $second[$i].Hash) { throw "Non-deterministic scene: $($first[$i].Path)" }
    Write-Output "DETERMINISTIC $($first[$i].Hash) $($first[$i].Path)"
}
```

Expected: both builders exit `0`; all three scene hashes match between passes.

- [ ] **Step 5: Run GREEN verification**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .superpowers\sdd\run_hermetic_suite.ps1
```

Expected: exit `0`, `TEST_SUMMARY: PASS (72 suites)`, all four clips begin/end at guard, durations remain exact, no model-root track appears, and settings remain `300`.

- [ ] **Step 6: Commit Task 3**

```powershell
git add -- tools/build_forge_vanguard_scene.gd scenes/characters/presentation/forge_vanguard_model.tscn scenes/characters/presentation/forge_base_masculine.tscn scenes/characters/presentation/forge_base_feminine.tscn tests/unit/test_forge_vanguard_animations.gd
git diff --cached --check
git commit -m "feat: pose Fighter in combat-ready guard"
```

Expected: one generator/test commit plus deterministic scene output; no gameplay files.

---

### Task 4: Cycle Sword and Hammer Through the Sandbox API

**Files:**
- Modify: `scripts/dev/character_presentation_sandbox.gd`
- Modify: `scenes/dev/character_presentation_sandbox.tscn`
- Modify: `tests/unit/test_character_presentation_sandbox.gd`
- Modify: `tests/integration/character_presentation_sandbox_runner.gd`

**Interfaces:**
- Consumes: Task 1 `get_available_equipment_visual_by_id` and `get_available_equipment_visuals_for_slot`; existing `CharacterPresentation.apply_equipment_visual`.
- Produces: `equip_variant(equipment_id, side_id) -> bool`, `cycle_slot_variant(slot_id, direction, side_id) -> bool`, and `get_equipped_visual_id(slot_id, side_id) -> StringName`.
- Preserves: Q/E slot selection, Space visibility toggle, profile switching, and per-side state isolation.

- [ ] **Step 1: Write failing sandbox API and smoke tests**

In `tests/unit/test_character_presentation_sandbox.gd`, include `cycle_slot_variant`, `equip_variant`, and `get_equipped_visual_id` in the public API assertion, require `V Cycle Variant` in the instruction label, and add:

```gdscript
TestAssertions.equal(sandbox.call(&"get_equipped_visual_id", &"main_hand", &"Masculine"), &"forge_vanguard_sword", "Fighter sandbox starts with sword", failures)
TestAssertions.truthy(bool(sandbox.call(&"cycle_slot_variant", &"main_hand", 1, &"Masculine")), "sandbox cycles sword to hammer", failures)
TestAssertions.equal(sandbox.call(&"get_equipped_visual_id", &"main_hand", &"Masculine"), &"forge_vanguard_hammer", "hammer becomes equipped", failures)
TestAssertions.truthy(bool(sandbox.call(&"cycle_slot_variant", &"main_hand", 1, &"Masculine")), "sandbox wraps hammer to sword", failures)
TestAssertions.equal(sandbox.call(&"get_equipped_visual_id", &"main_hand", &"Masculine"), &"forge_vanguard_sword", "variant cycling wraps to sword", failures)
TestAssertions.equal(sandbox.call(&"get_equipped_visual_id", &"main_hand", &"Feminine"), &"forge_vanguard_sword", "masculine variant cycling does not leak to feminine", failures)
TestAssertions.truthy(not bool(sandbox.call(&"equip_variant", &"missing_item", &"Masculine")), "unknown equipment ID is rejected", failures)
```

In `tests/integration/character_presentation_sandbox_runner.gd`, before the clip loop for each side, add:

```gdscript
if sandbox.get_equipped_visual_id(&"main_hand", side_id) != &"forge_vanguard_sword":
	_fail("default sword missing side=%s" % side_id)
	return
if not sandbox.cycle_slot_variant(&"main_hand", 1, side_id) or sandbox.get_equipped_visual_id(&"main_hand", side_id) != &"forge_vanguard_hammer":
	_fail("hammer cycle rejected side=%s" % side_id)
	return
if not sandbox.cycle_slot_variant(&"main_hand", 1, side_id) or sandbox.get_equipped_visual_id(&"main_hand", side_id) != &"forge_vanguard_sword":
	_fail("sword cycle rejected side=%s" % side_id)
	return
```

Keep the exact success marker `PARTY_FORGE_PRESENTATION_SMOKE_OK bodies=2 palettes=3 slots=10 animations=4`.

- [ ] **Step 2: Run unit and smoke verification to prove RED**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .superpowers\sdd\run_hermetic_suite.ps1
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --script res://tests/integration/character_presentation_sandbox_runner.gd
```

Expected: both commands exit `1` because the new sandbox methods and `V` control do not exist. Settings restore to `300` after the suite.

- [ ] **Step 3: Implement per-side variant state and public cycle operations**

Add to `scripts/dev/character_presentation_sandbox.gd`:

```gdscript
var _equipped_visual_id: Dictionary = {}

func equip_variant(equipment_id: StringName, side_id: StringName = selected_side_id) -> bool:
	_initialize_profiles()
	var presentation := _presentation(side_id)
	if presentation == null or presentation.active_profile == null:
		return false
	var definition := presentation.active_profile.get_available_equipment_visual_by_id(equipment_id)
	if definition == null or not presentation.apply_equipment_visual(definition.slot_id, definition):
		return false
	_equipped_visual_id[_slot_key(side_id, definition.slot_id)] = definition.id
	_slot_enabled[_slot_key(side_id, definition.slot_id)] = true
	return true

func cycle_slot_variant(slot_id: StringName, direction: int = 1, side_id: StringName = selected_side_id) -> bool:
	_initialize_profiles()
	var presentation := _presentation(side_id)
	if presentation == null or presentation.active_profile == null:
		return false
	var variants := presentation.active_profile.get_available_equipment_visuals_for_slot(slot_id)
	if variants.is_empty():
		return false
	var current_id := get_equipped_visual_id(slot_id, side_id)
	var current_index := -1
	for index: int in variants.size():
		if variants[index].id == current_id:
			current_index = index
			break
	var next_index := posmod(current_index + direction, variants.size())
	return equip_variant(variants[next_index].id, side_id)

func get_equipped_visual_id(slot_id: StringName, side_id: StringName = selected_side_id) -> StringName:
	_initialize_profiles()
	return StringName(_equipped_visual_id.get(_slot_key(side_id, slot_id), &""))
```

In `toggle_slot`, when enabling, first resolve the stored ID; otherwise use the legacy first variant:

```gdscript
var stored_id := get_equipped_visual_id(slot_id, side_id)
var definition := presentation.active_profile.get_available_equipment_visual_by_id(stored_id) if not stored_id.is_empty() else presentation.active_profile.get_available_equipment_visual(slot_id)
success = definition != null and presentation.apply_equipment_visual(slot_id, definition)
if success:
	_equipped_visual_id[_slot_key(side_id, slot_id)] = definition.id
```

In `_apply_profile_mode`, clear `_equipped_visual_id` for all ten slots and set it from every non-null default definition. In `_unhandled_key_input`, add:

```gdscript
KEY_V:
	var slot_id: StringName = EquipmentSlotCatalog.SLOT_IDS[selected_slot_index]
	cycle_slot_variant(slot_id, 1)
```

- [ ] **Step 4: Update sandbox control copy**

Change `scenes/dev/character_presentation_sandbox.tscn` instruction text to:

```text
1/2 Body   R/B/G Palette   I Idle   A Slash   C Combo   H Hit
Q/E Cycle Slot   Space Toggle Selected Slot   V Cycle Variant
M Toggle Base/Equipped Profile
```

- [ ] **Step 5: Run GREEN unit and smoke verification**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .superpowers\sdd\run_hermetic_suite.ps1
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --script res://tests/integration/character_presentation_sandbox_runner.gd
```

Expected: suite exit `0` with `PASS (72 suites)`; smoke exit `0` with the exact success marker; settings remain `300`.

- [ ] **Step 6: Commit Task 4**

```powershell
git add -- scripts/dev/character_presentation_sandbox.gd scenes/dev/character_presentation_sandbox.tscn tests/unit/test_character_presentation_sandbox.gd tests/integration/character_presentation_sandbox_runner.gd
git diff --cached --check
git commit -m "feat: preview main-hand variants in sandbox"
```

Expected: one sandbox/test commit; no model, gameplay, or input-map file outside the sandbox.

---

### Task 5: Document and Validate the Finished Presentation

**Files:**
- Modify: `docs/handbook/08-visuals-audio-effects-and-ui.md:54-68`
- Create (ignored QA artifacts only): `.superpowers/sdd/fighter_sword_guard.png`, `.superpowers/sdd/fighter_hammer_guard.png`, `.superpowers/sdd/fighter_sword_slash.png`

**Interfaces:**
- Consumes: completed profile, model, animation, and sandbox contracts from Tasks 1-4.
- Produces: handbook documentation and fresh verification evidence; no runtime API.

- [ ] **Step 1: Update the handbook with the implemented variant contract**

In `docs/handbook/08-visuals-audio-effects-and-ui.md`, document all of the following exact facts:

```markdown
`main_hand` currently exposes two visual definitions: `forge_vanguard_sword` and `forge_vanguard_hammer`. The Fighter equips sword first by default; the preserved hammer remains selectable without altering its original box geometry. Available profile equipment may contain multiple definitions for one slot, while default equipment remains one item per slot. Consumers should use equipment-ID lookup for an exact item or slot-variant lookup for cycling.

The sandbox `V` control cycles the selected slot's available variants through `CharacterPresentation.apply_equipment_visual`; it does not toggle model nodes directly. The Fighter idle is a combat-ready guard with shield raised and the main-hand item carried forward/down. Slash, combo, and flinch retain their original durations and recover to the same guard without model-root motion or gameplay timing changes.
```

Keep the existing PoE1 ten-slot list, Blender/GLB handoff contract, collision ownership, and palette-isolation warnings.

- [ ] **Step 2: Run a fresh headless import and inspect for new script/resource errors**

Run from the isolated worktree, with no second Godot editor open on that worktree:

```powershell
$output = & 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --editor --path . --quit 2>&1
$code = $LASTEXITCODE
$output | ForEach-Object { $_ }
Write-Output "IMPORT_EXIT=$code"
if ($code -ne 0 -or ($output -match 'SCRIPT ERROR:|Parse Error|PARTY_FORGE_PRESENTATION_ERROR')) { exit 1 }
```

Expected: `IMPORT_EXIT=0` and no new parse, resource, or presentation error. Remove only UID sidecars generated by this import that were untracked before the command.

- [ ] **Step 3: Run the final hermetic suite and smoke**

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .superpowers\sdd\run_hermetic_suite.ps1
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --script res://tests/integration/character_presentation_sandbox_runner.gd
```

Expected: `TEST_SUMMARY: PASS (72 suites)`, smoke success marker exactly `PARTY_FORGE_PRESENTATION_SMOKE_OK bodies=2 palettes=3 slots=10 animations=4`, both exit codes `0`, and XP settings restored to `300`.

- [ ] **Step 4: Perform live Godot visual QA**

Open `res://scenes/dev/character_presentation_sandbox.tscn` in an isolated Godot editor and run the current scene with autosave disabled. From the normal high-angle sandbox camera, capture and verify:

1. Default red masculine and blue feminine Fighters show an unmistakable sword plus raised shield in guard.
2. Pressing `V` with `main_hand` selected swaps sword to the unchanged hammer; a second `V` returns to sword.
3. Variant changes remain local to the selected side.
4. `A`, `C`, and `H` show slash, combo, and flinch, then visibly recover to the same guard without an A-pose snap.
5. Base masculine and feminine profiles remain neutral and unequipped.
6. Hit flash, downed grayscale, revival, and red/blue palette isolation remain correct.

Save screenshots only under `.superpowers/sdd/` with the three names listed in this task. Read current game and editor logs with details; accept no new `PARTY_FORGE_PRESENTATION_ERROR`, invalid method call, parser error, or resource load error. Stop and quit only the isolated editor session.

- [ ] **Step 5: Verify scope and commit the handbook**

```powershell
$base = (Get-Content -LiteralPath .superpowers\sdd\fighter-variants-base.txt -Raw).Trim()
git diff --check
git status --short
git diff --name-only "$base..HEAD"
git add -- docs/handbook/08-visuals-audio-effects-and-ui.md
git diff --cached --check
git commit -m "docs: document Fighter weapon variants"
```

Expected: runtime commits touch only the files declared in Tasks 1-4; the final commit contains only the handbook. User-owned `scenes/game/main.tscn`, `assets/ui/currency/`, generated untracked UIDs, `.godot`, and `.superpowers` artifacts are not staged.

- [ ] **Step 6: Request final whole-branch review**

Generate a review package across the exact recorded implementation range:

```powershell
$base = (Get-Content -LiteralPath .superpowers\sdd\fighter-variants-base.txt -Raw).Trim()
& 'C:\Program Files\Git\bin\bash.exe' 'C:/Users/Jacob/.codex/skills/subagent-driven-development/scripts/review-package' $base HEAD
```

Expected: the command prints the ignored `.superpowers/sdd/review-<base7>..<head7>.diff` path. Give that exact package to a fresh reviewer and ask them to verify spec coverage, exact hammer preservation, sword readability, one-visible-item behavior, guard/action recovery, deterministic generated scenes, sandbox API use, test quality, documentation fidelity, and absence of gameplay/collision changes. Fix all Critical and Important findings test-first, regenerate/reverify when required, generate a new package for the updated `HEAD`, and repeat review until approved.

Expected: final review reports no Critical or Important findings and explicitly approves the branch.

---

## Plan Self-Review Record

- Spec coverage: every goal, non-goal, compatibility rule, sandbox control, guard requirement, testing requirement, and live-QA requirement in `docs/superpowers/specs/2026-08-01-fighter-main-hand-variants-design.md` maps to Tasks 1-5.
- Placeholder scan: no `TBD`, `TODO`, “implement later,” or undefined implementation step remains.
- Type consistency: `get_available_equipment_visual_by_id`, `get_available_equipment_visuals_for_slot`, `equip_variant`, `cycle_slot_variant`, and `get_equipped_visual_id` use the same signatures in producers, consumers, and tests.
- Scope: profile schema, presentation data/model, generated animation, sandbox, tests, and handbook form one testable presentation change; inventory UI and gameplay remain excluded.
