# Equipment Icon Distinction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the filename-guessed equipment icons with slot-correct, visibly distinct, deterministic flat icons for all 99 canonical base items.

**Architecture:** Add a pure CPU icon renderer that consumes an `EquipmentBaseDefinition`, its registered sheet slot, class-set palette, and item ordinal. The existing command-line generator becomes a thin catalog-driven writer, while unit and standalone validation compare all 99 outputs for correct families, dimensions, alpha bounds, padding, and same-resolution uniqueness.

**Tech Stack:** Godot 4.7.1, typed GDScript, `Image`, `HashingContext`, existing Party Forge equipment resources, PowerShell validation commands.

## Global Constraints

- Work in an isolated Git worktree created from `main`; do not modify or clean the user's unrelated `scenes/game/main.tscn`, currency imports, `.uid` files, or other live-checkout state.
- Keep all 99 equipment IDs, base resources, eligibility rules, slots, 3D scenes, presentation links, and balance data unchanged.
- Keep one transparent 256x256 master and one transparent 128x128 runtime icon per base item at the existing paths.
- Keep the nine existing class palettes and contact-sheet paths.
- Use declared equipment data for slot and handheld family resolution; never infer an equipment slot from an item filename.
- Every different item ID must produce visibly distinct artwork at 128x128; hidden pixels and imperceptible color changes do not qualify.
- Rarity, affix, tier, quality, corruption, and socket treatments remain runtime item-instance/UI layers and are not baked into these base icons.
- Generation must be deterministic and fail closed.

## File Map

- Create `tools/equipment_icon_cpu_renderer.gd`: pure slot/family resolution and CPU drawing for one base item.
- Create `tests/unit/test_equipment_icon_cpu_renderer.gd`: catalog-wide in-memory family, uniqueness, padding, and determinism coverage.
- Modify `tools/render_equipment_icons.gd`: catalog-driven orchestration and file writing only.
- Modify `tests/unit/test_equipment_icons.gd`: all 99 committed master/runtime files, pixel uniqueness, padding, and transparency coverage.
- Create `tests/unit/test_equipment_icon_validator_contract.gd`: standalone validator contract coverage.
- Modify `tools/validate_equipment_icons.gd`: standalone all-set validation with duplicate detection.
- Regenerate `assets/ui/equipment/master/**/*.png`: 99 corrected master icons.
- Regenerate `assets/ui/equipment/runtime/**/*.png`: 99 corrected runtime icons.
- Regenerate `assets/ui/equipment/contact_sheets/*_contact_sheet.png`: nine corrected review sheets.
- Modify `docs/qa/2026-08-01-playable-class-presentation-validation.md`: append the corrective validation evidence without rewriting the prior record.

---

### Task 1: Pure Slot-Driven CPU Icon Renderer

**Files:**
- Create: `tests/unit/test_equipment_icon_cpu_renderer.gd`
- Create: `tools/equipment_icon_cpu_renderer.gd`

**Interfaces:**
- Consumes: `EquipmentBaseDefinition`, `ClassEquipmentRows.slot_for(set_id, item_index)`, a registered class-set ID, and its zero-based item index.
- Produces: `family_for(definition: EquipmentBaseDefinition, registered_slot: StringName) -> StringName`, `identity_variant(item_index: int) -> Vector3i`, and `render(set_id: StringName, definition: EquipmentBaseDefinition, registered_slot: StringName, item_index: int) -> Image`.

- [ ] **Step 1: Write the failing catalog-wide renderer test**

Create `tests/unit/test_equipment_icon_cpu_renderer.gd` with a dynamically loaded renderer so the suite itself loads before the production file exists:

```gdscript
extends RefCounted

const RENDERER_PATH := "res://tools/equipment_icon_cpu_renderer.gd"
const CATALOG := preload("res://data/equipment/core_equipment_catalog.tres")

func run() -> Array[String]:
	var failures: Array[String] = []
	var renderer_script := load(RENDERER_PATH) as Script
	TestAssertions.truthy(renderer_script != null, "equipment icon CPU renderer exists", failures)
	if renderer_script == null:
		return failures
	var renderer := renderer_script.new() as RefCounted
	TestAssertions.equal(CATALOG.size(), 99, "canonical equipment catalog size", failures)
	var seen_variants: Dictionary = {}
	var seen_hashes: Dictionary = {}
	for set_id: StringName in ClassEquipmentRows.SET_ITEM_IDS:
		seen_variants[set_id] = {}
		var item_ids: Array = ClassEquipmentRows.SET_ITEM_IDS[set_id]
		for index: int in item_ids.size():
			var item_id := item_ids[index] as StringName
			var definition := CATALOG.definition(item_id)
			var slot_id := ClassEquipmentRows.slot_for(set_id, index)
			TestAssertions.truthy(definition != null, "%s definition exists" % item_id, failures)
			if definition == null:
				continue
			var family := StringName(renderer.call(&"family_for", definition, slot_id))
			TestAssertions.truthy(not family.is_empty(), "%s resolves a visual family" % item_id, failures)
			var variant: Vector3i = renderer.call(&"identity_variant", index)
			var variant_key := "%d:%d:%d" % [variant.x, variant.y, variant.z]
			TestAssertions.truthy(not (seen_variants[set_id] as Dictionary).has(variant_key), "%s identity variant is unique within %s" % [item_id, set_id], failures)
			(seen_variants[set_id] as Dictionary)[variant_key] = item_id
			var image := renderer.call(&"render", set_id, definition, slot_id, index) as Image
			_assert_image(image, item_id, failures)
			if image != null:
				var digest := _image_digest(image)
				TestAssertions.truthy(not seen_hashes.has(digest), "%s master pixels differ from %s" % [item_id, seen_hashes.get(digest, &"<none>")], failures)
				seen_hashes[digest] = item_id
	_assert_family(renderer, &"greenwood_jerkin", &"body_armour", failures)
	_assert_family(renderer, &"siege_archer_cowl", &"helmet", failures)
	_assert_family(renderer, &"emberweave_circlet", &"helmet", failures)
	_assert_family(renderer, &"hawkeye_band", &"ring", failures)
	_assert_family(renderer, &"emberweave_rune_sash", &"belt", failures)
	_assert_family(renderer, &"storm_chaplain_reliquary", &"amulet", failures)
	return failures

func _assert_family(renderer: RefCounted, item_id: StringName, expected: StringName, failures: Array[String]) -> void:
	var definition := CATALOG.definition(item_id)
	var slot_id := definition.compatible_slot_ids[0] if definition != null else &""
	TestAssertions.equal(StringName(renderer.call(&"family_for", definition, slot_id)), expected, "%s uses declared family" % item_id, failures)

func _assert_image(image: Image, item_id: StringName, failures: Array[String]) -> void:
	TestAssertions.truthy(image != null, "%s renders" % item_id, failures)
	if image == null:
		return
	TestAssertions.equal(image.get_size(), Vector2i(256, 256), "%s master size" % item_id, failures)
	var bounds := _visible_bounds(image)
	TestAssertions.truthy(bounds.has_area(), "%s has visible pixels" % item_id, failures)
	TestAssertions.truthy(bounds.position.x >= 16 and bounds.position.y >= 16 and bounds.end.x <= 240 and bounds.end.y <= 240, "%s keeps master padding" % item_id, failures)

func _visible_bounds(image: Image) -> Rect2i:
	var result := Rect2i()
	var found := false
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0.01:
				result = Rect2i(x, y, 1, 1) if not found else result.expand(Vector2i(x, y))
				found = true
	return result

func _image_digest(image: Image) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(image.get_data()) != OK:
		return ""
	return context.finish().hex_encode()
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --path . --script res://tests/focused_test_runner.gd -- res://tests/unit/test_equipment_icon_cpu_renderer.gd
```

Expected: exit code 1 with `equipment icon CPU renderer exists` because `tools/equipment_icon_cpu_renderer.gd` does not exist.

- [ ] **Step 3: Implement the pure renderer**

Create `tools/equipment_icon_cpu_renderer.gd`. Keep all drawing in this file; the command-line writer must not duplicate visual rules.

```gdscript
class_name EquipmentIconCpuRenderer
extends RefCounted

const SLOT_FAMILIES := {
	&"helmet": &"helmet", &"body_armour": &"body_armour", &"legs": &"legs",
	&"gloves": &"gloves", &"boots": &"boots", &"amulet": &"amulet",
	&"ring_left": &"ring", &"ring_right": &"ring", &"belt": &"belt",
}
const HANDHELD_FAMILIES := {
	&"bow": &"bow", &"staff": &"staff", &"wand": &"wand", &"sceptre": &"sceptre",
	&"tome": &"tome", &"grimoire": &"tome", &"focus": &"focus", &"quiver": &"quiver",
	&"shield": &"shield", &"dagger": &"dagger", &"warhammer": &"hammer",
}
const ID_OVERRIDES := {
	&"forge_vanguard_sword": &"sword",
	&"forge_vanguard_shield": &"shield",
	&"forge_vanguard_hammer": &"hammer",
}
const PALETTES := {
	&"fighter": [Color("d94f4f"), Color("303a47"), Color("4a3426"), Color("b68b3a")],
	&"paladin": [Color("e0b94f"), Color("d7dce2"), Color("553c28"), Color("fff0a1")],
	&"ranger": [Color("4f7a4d"), Color("59636a"), Color("5a3f28"), Color("83b86a")],
	&"marksman": [Color("59613b"), Color("4b5157"), Color("493b2a"), Color("a89d5b")],
	&"rogue": [Color("5a426e"), Color("657080"), Color("282127"), Color("a773c2")],
	&"mage": [Color("7c4d9e"), Color("61556c"), Color("4b334f"), Color("ff7043")],
	&"frost_mage": [Color("4f7f9e"), Color("6b8292"), Color("374e5c"), Color("8ee8ff")],
	&"cleric": [Color("d8c36a"), Color("69727a"), Color("66563d"), Color("fff08a")],
	&"warlock": [Color("513663"), Color("41404a"), Color("302431"), Color("8c45c9")],
}

func family_for(definition: EquipmentBaseDefinition, registered_slot: StringName) -> StringName:
	if definition == null or not EquipmentSlotCatalog.is_valid(registered_slot):
		return &""
	if ID_OVERRIDES.has(definition.id):
		return ID_OVERRIDES[definition.id] as StringName
	if SLOT_FAMILIES.has(registered_slot):
		return SLOT_FAMILIES[registered_slot] as StringName
	if registered_slot in [&"main_hand", &"off_hand"]:
		return HANDHELD_FAMILIES.get(definition.item_type_id, &"weapon") as StringName
	return &""

func identity_variant(item_index: int) -> Vector3i:
	return Vector3i(item_index % 4, item_index / 4, item_index % 2)

func render(set_id: StringName, definition: EquipmentBaseDefinition, registered_slot: StringName, item_index: int) -> Image:
	if definition == null or not PALETTES.has(set_id):
		return null
	var family := family_for(definition, registered_slot)
	if family.is_empty():
		return null
	var image := Image.create_empty(256, 256, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var palette: Array = PALETTES[set_id]
	var primary := palette[0] as Color
	var metal := palette[1] as Color
	var leather := palette[2] as Color
	var accent := palette[3] as Color
	_draw_circle(image, Vector2i(132, 140), 70, Color(0.03, 0.04, 0.06, 0.55))
	_draw_family(image, family, primary, metal, leather, accent)
	_draw_identity_treatment(image, identity_variant(item_index), primary, metal, accent)
	return image
```

Use this exhaustive family drawing method so every value returned by `family_for` has an explicit silhouette:

```gdscript
func _draw_family(image: Image, family: StringName, primary: Color, metal: Color, leather: Color, accent: Color) -> void:
	match family:
		&"helmet":
			image.fill_rect(Rect2i(77, 63, 102, 128), metal)
			image.fill_rect(Rect2i(92, 86, 72, 68), Color(0.03, 0.04, 0.06, 1))
			image.fill_rect(Rect2i(102, 57, 52, 18), accent)
		&"body_armour":
			image.fill_rect(Rect2i(72, 68, 112, 132), leather)
			image.fill_rect(Rect2i(55, 70, 45, 55), metal)
			image.fill_rect(Rect2i(156, 70, 45, 55), metal)
			image.fill_rect(Rect2i(83, 80, 90, 92), primary)
			image.fill_rect(Rect2i(91, 92, 74, 15), accent)
		&"legs":
			image.fill_rect(Rect2i(76, 52, 45, 148), leather)
			image.fill_rect(Rect2i(135, 52, 45, 148), leather)
			image.fill_rect(Rect2i(76, 95, 104, 18), primary)
		&"gloves":
			image.fill_rect(Rect2i(84, 82, 90, 114), leather)
			image.fill_rect(Rect2i(70, 72, 22, 77), primary)
			image.fill_rect(Rect2i(164, 72, 22, 77), primary)
		&"boots":
			image.fill_rect(Rect2i(67, 62, 50, 128), leather)
			image.fill_rect(Rect2i(139, 62, 50, 128), leather)
			image.fill_rect(Rect2i(49, 166, 68, 32), primary)
			image.fill_rect(Rect2i(139, 166, 68, 32), primary)
		&"amulet":
			_draw_circle_outline(image, Vector2i(128, 111), 62, metal, 10)
			_draw_circle(image, Vector2i(128, 172), 28, accent)
		&"ring":
			_draw_circle_outline(image, Vector2i(128, 128), 58, metal, 25)
			_draw_circle(image, Vector2i(128, 65), 18, accent)
		&"belt":
			image.fill_rect(Rect2i(43, 112, 170, 37), leather)
			image.fill_rect(Rect2i(106, 102, 48, 57), accent)
			image.fill_rect(Rect2i(118, 113, 24, 35), Color(0.03, 0.04, 0.06, 1))
		&"sword", &"weapon":
			_draw_line(image, Vector2i(78, 204), Vector2i(162, 62), leather, 12)
			_draw_line(image, Vector2i(151, 84), Vector2i(194, 45), metal, 18)
			image.fill_rect(Rect2i(62, 188, 76, 13), accent)
		&"dagger":
			_draw_line(image, Vector2i(88, 191), Vector2i(151, 87), leather, 14)
			_draw_line(image, Vector2i(144, 98), Vector2i(185, 56), metal, 20)
			image.fill_rect(Rect2i(68, 179, 60, 14), accent)
		&"hammer":
			_draw_line(image, Vector2i(78, 204), Vector2i(162, 62), leather, 12)
			image.fill_rect(Rect2i(112, 42, 92, 48), metal)
			image.fill_rect(Rect2i(146, 48, 18, 36), accent)
		&"bow":
			_draw_line(image, Vector2i(79, 190), Vector2i(79, 68), leather, 11)
			_draw_line(image, Vector2i(79, 68), Vector2i(145, 46), leather, 11)
			_draw_line(image, Vector2i(79, 190), Vector2i(145, 212), leather, 11)
			_draw_line(image, Vector2i(145, 46), Vector2i(145, 212), accent, 4)
			_draw_line(image, Vector2i(75, 129), Vector2i(199, 129), metal, 8)
		&"staff":
			_draw_line(image, Vector2i(91, 210), Vector2i(157, 56), leather, 12)
			_draw_circle(image, Vector2i(163, 51), 24, accent)
			_draw_circle_outline(image, Vector2i(163, 51), 31, metal, 7)
		&"wand":
			_draw_line(image, Vector2i(78, 201), Vector2i(164, 70), leather, 12)
			_draw_circle(image, Vector2i(174, 57), 22, accent)
		&"sceptre":
			_draw_line(image, Vector2i(85, 205), Vector2i(151, 70), metal, 14)
			image.fill_rect(Rect2i(124, 47, 80, 24), accent)
			_draw_circle(image, Vector2i(164, 42), 16, accent)
		&"focus":
			_draw_circle(image, Vector2i(128, 125), 53, accent)
			_draw_circle_outline(image, Vector2i(128, 125), 70, metal, 9)
		&"tome":
			image.fill_rect(Rect2i(67, 57, 122, 151), leather)
			image.fill_rect(Rect2i(78, 69, 100, 128), primary)
			image.fill_rect(Rect2i(119, 69, 13, 128), metal)
			image.fill_rect(Rect2i(95, 119, 67, 14), accent)
		&"shield":
			image.fill_rect(Rect2i(65, 49, 126, 148), metal)
			image.fill_rect(Rect2i(78, 61, 100, 123), primary)
			image.fill_rect(Rect2i(119, 66, 18, 110), accent)
			image.fill_rect(Rect2i(82, 111, 92, 18), accent)
		&"quiver":
			image.fill_rect(Rect2i(91, 78, 75, 126), leather)
			image.fill_rect(Rect2i(86, 72, 85, 20), primary)
			for x: int in [101, 128, 155]:
				_draw_line(image, Vector2i(x, 92), Vector2i(x, 42), metal, 5)
```

The identity method must use all three fields and keep its geometry visible after downsampling:

```gdscript
func _draw_identity_treatment(image: Image, variant: Vector3i, primary: Color, metal: Color, accent: Color) -> void:
	var center := Vector2i(96 + variant.x * 18, 150 + variant.y * 14)
	var color := accent if variant.z == 0 else primary.lightened(0.20)
	match variant.x:
		0: _draw_circle(image, center, 8, color)
		1:
			image.fill_rect(Rect2i(center - Vector2i(8, 8), Vector2i(16, 16)), color)
		2:
			_draw_line(image, center - Vector2i(9, 9), center + Vector2i(9, 9), color, 6)
			_draw_line(image, center + Vector2i(9, -9), center + Vector2i(-9, 9), metal, 4)
		3:
			_draw_circle_outline(image, center, 10, color, 5)
			_draw_circle(image, center, 3, metal)
```

Add the drawing primitives to the same file:

```gdscript
func _draw_line(image: Image, from: Vector2i, to: Vector2i, color: Color, width: int) -> void:
	var steps := maxi(abs(to.x - from.x), abs(to.y - from.y))
	for index: int in steps + 1:
		var point := Vector2(from).lerp(Vector2(to), float(index) / maxf(1.0, steps))
		_draw_circle(image, Vector2i(point), maxi(1, width / 2), color)

func _draw_circle(image: Image, center: Vector2i, radius: int, color: Color) -> void:
	for y: int in range(-radius, radius + 1):
		for x: int in range(-radius, radius + 1):
			if x * x + y * y <= radius * radius:
				var point := center + Vector2i(x, y)
				if point.x >= 0 and point.y >= 0 and point.x < image.get_width() and point.y < image.get_height():
					image.set_pixelv(point, color)

func _draw_circle_outline(image: Image, center: Vector2i, radius: int, color: Color, width: int) -> void:
	var inner := maxi(0, radius - width)
	for y: int in range(-radius, radius + 1):
		for x: int in range(-radius, radius + 1):
			var distance := x * x + y * y
			if distance <= radius * radius and distance >= inner * inner:
				var point := center + Vector2i(x, y)
				if point.x >= 0 and point.y >= 0 and point.x < image.get_width() and point.y < image.get_height():
					image.set_pixelv(point, color)
```

- [ ] **Step 4: Run the focused test and verify GREEN**

Run the Step 2 command again.

Expected: `TEST_SUMMARY: PASS (0 failures)`, exit code 0, with all 99 in-memory images unique.

- [ ] **Step 5: Commit the renderer contract**

```powershell
git add -- tools/equipment_icon_cpu_renderer.gd tests/unit/test_equipment_icon_cpu_renderer.gd
git diff --cached --check
git commit -m "feat: add slot-driven equipment icon renderer"
```

---

### Task 2: Catalog-Driven Writer and Corrected Asset Set

**Files:**
- Modify: `tests/unit/test_equipment_icons.gd`
- Modify: `tools/render_equipment_icons.gd`
- Regenerate: `assets/ui/equipment/master/**/*.png`
- Regenerate: `assets/ui/equipment/runtime/**/*.png`
- Regenerate: `assets/ui/equipment/contact_sheets/*_contact_sheet.png`

**Interfaces:**
- Consumes: `EquipmentIconCpuRenderer.render(...)` from Task 1 and `data/equipment/core_equipment_catalog.tres`.
- Produces: the existing 198 icon paths and nine contact-sheet paths with corrected pixels.

- [ ] **Step 1: Expand the committed-asset test to all 99 items and add duplicate rejection**

Replace the Fighter-only loop in `tests/unit/test_equipment_icons.gd` with a catalog/manifest loop. Load raw PNGs with `Image.load` so the test does not depend on editor-generated `.import` sidecars. Maintain one hash dictionary for masters and one for runtime icons:

```gdscript
const SET_FOLDERS := {
	&"fighter": &"forge_vanguard", &"paladin": &"dawn_bulwark", &"ranger": &"greenwood",
	&"marksman": &"siege_archer", &"rogue": &"nightstep", &"mage": &"emberweave",
	&"frost_mage": &"rime_scholar", &"cleric": &"storm_chaplain", &"warlock": &"grave_covenant",
}

func run() -> Array[String]:
	var failures: Array[String] = []
	var hashes := {256: {}, 128: {}}
	for set_id: StringName in ClassEquipmentRows.SET_ITEM_IDS:
		var folder := StringName(SET_FOLDERS[set_id])
		for item_id: StringName in ClassEquipmentRows.SET_ITEM_IDS[set_id]:
			for size: int in [256, 128]:
				var kind := "master" if size == 256 else "runtime"
				var path := "res://assets/ui/equipment/%s/%s/%s_%d.png" % [kind, folder, item_id, size]
				var image := Image.new()
				TestAssertions.equal(image.load(ProjectSettings.globalize_path(path)), OK, "%s %s icon loads" % [item_id, kind], failures)
				if image.is_empty():
					continue
				_assert_icon(image, size, item_id, kind, failures)
				var digest := _image_digest(image)
				TestAssertions.truthy(not (hashes[size] as Dictionary).has(digest), "%s %s pixels differ from %s" % [item_id, kind, (hashes[size] as Dictionary).get(digest, &"<none>")], failures)
				(hashes[size] as Dictionary)[digest] = item_id
	return failures

func _image_digest(image: Image) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(image.get_data()) != OK:
		return ""
	return context.finish().hex_encode()
```

Change `_assert_icon` to accept `Image` instead of `Texture2D`; keep the existing size, transparency, non-empty bounds, and runtime-padding assertions.

- [ ] **Step 2: Run the asset test and verify RED against the current duplicates**

```powershell
& $godot --headless --path . --script res://tests/focused_test_runner.gd -- res://tests/unit/test_equipment_icons.gd
```

Expected: exit code 1 with duplicate-pixel failures including at least one of the Ranger bands or misclassified garment groups.

- [ ] **Step 3: Convert the command-line writer to catalog-driven rendering**

In `tools/render_equipment_icons.gd`:

```gdscript
const CATALOG := preload("res://data/equipment/core_equipment_catalog.tres")
const RENDERER_SCRIPT := preload("res://tools/equipment_icon_cpu_renderer.gd")
```

Create one renderer before the loops. For each manifest index, resolve the definition and registered slot, reject missing/incompatible data, then render:

```gdscript
var renderer := RENDERER_SCRIPT.new() as RefCounted
for set_id: StringName in requested_sets:
	var folder := SET_FOLDERS[set_id] as StringName
	var item_ids: Array = ClassEquipmentRows.SET_ITEM_IDS[set_id]
	for index: int in item_ids.size():
		var item_id := item_ids[index] as StringName
		var definition := CATALOG.definition(item_id)
		var slot_id := ClassEquipmentRows.slot_for(set_id, index)
		if definition == null:
			_fail("item=%s definition missing" % item_id); return
		if slot_id not in definition.compatible_slot_ids:
			_fail("item=%s registered slot=%s is incompatible" % [item_id, slot_id]); return
		var image := renderer.call(&"render", set_id, definition, slot_id, index) as Image
		if image == null or image.get_size() != Vector2i(256, 256) or not _visible_bounds(image).has_area():
			_fail("item=%s render invalid" % item_id); return
		if _save_pair(item_id, folder, image) != OK:
			_fail("item=%s save failed" % item_id); return
		item_count += 1
```

Delete `_render_cpu_icon`, `_camera_kind`, `_item_bounds`, drawing primitives, and unused camera constants from the orchestration script. Retain `_requested_sets`, `_visible_bounds`, `_save_pair`, and `_fail`.

- [ ] **Step 4: Regenerate all icon pairs and contact sheets**

```powershell
$iconAppData = Join-Path (Resolve-Path '.superpowers\sdd') 'equipment-icon-fix-appdata'
New-Item -ItemType Directory -Force -Path $iconAppData | Out-Null
$previousAppData = $env:APPDATA
$env:APPDATA = $iconAppData
try {
    & $godot --headless --path . --script res://tools/render_equipment_icons.gd -- --sets=all
    if ($LASTEXITCODE -ne 0) { throw "icon render failed with $LASTEXITCODE" }
    & $godot --headless --path . --script res://tools/build_equipment_contact_sheets.gd
    if ($LASTEXITCODE -ne 0) { throw "contact sheet build failed with $LASTEXITCODE" }
} finally {
    $env:APPDATA = $previousAppData
}
```

Expected markers: `EQUIPMENT_ICON_RENDER_OK sets=9 items=99` and `EQUIPMENT_CONTACT_SHEET_BUILD_OK sets=9 items=99`.

- [ ] **Step 5: Run both focused icon suites and verify GREEN**

```powershell
& $godot --headless --path . --script res://tests/focused_test_runner.gd -- res://tests/unit/test_equipment_icon_cpu_renderer.gd res://tests/unit/test_equipment_icons.gd
```

Expected: `TEST_SUMMARY: PASS (0 failures)`, exit code 0.

- [ ] **Step 6: Commit writer, tests, and generated assets**

```powershell
git add -- tools/render_equipment_icons.gd tests/unit/test_equipment_icons.gd assets/ui/equipment/master assets/ui/equipment/runtime assets/ui/equipment/contact_sheets
git diff --cached --check
git commit -m "fix: make every equipment icon distinct"
```

---

### Task 3: Standalone Fail-Closed Validation and Determinism Gate

**Files:**
- Modify: `tools/validate_equipment_icons.gd`

**Interfaces:**
- Consumes: all 198 corrected PNGs, the core catalog, the registered manifest, and `EquipmentIconCpuRenderer.family_for(...)`.
- Produces: `EQUIPMENT_ICON_VALIDATION_OK sets=9 items=99 unique_master=99 unique_runtime=99` or a nonzero actionable failure.

- [ ] **Step 1: Add a failing validator-process test**

Create `tests/unit/test_equipment_icon_validator_contract.gd` that reads `tools/validate_equipment_icons.gd` as text and asserts the validator contains the catalog, family resolver, and duplicate-hash gates:

```gdscript
extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var source := FileAccess.get_file_as_string("res://tools/validate_equipment_icons.gd")
	TestAssertions.truthy("core_equipment_catalog.tres" in source, "validator uses canonical catalog", failures)
	TestAssertions.truthy("family_for" in source, "validator checks declared visual family", failures)
	TestAssertions.truthy("HashingContext.HASH_SHA256" in source, "validator rejects duplicate pixels", failures)
	TestAssertions.truthy("unique_master" in source and "unique_runtime" in source, "validator reports uniqueness totals", failures)
	return failures
```

- [ ] **Step 2: Run the contract test and verify RED**

```powershell
& $godot --headless --path . --script res://tests/focused_test_runner.gd -- res://tests/unit/test_equipment_icon_validator_contract.gd
```

Expected: exit code 1 because the current standalone validator has no catalog family or duplicate-hash gates.

- [ ] **Step 3: Strengthen `tools/validate_equipment_icons.gd`**

Load the core catalog and renderer. Pass `set_id`, item index, and two shared hash dictionaries into `_validate`. Before reading images, resolve the definition, registered slot, and non-empty family. For each size, hash `image.get_data()` and reject a hash already owned by another ID:

```gdscript
var digest := _image_digest(image)
var owner := (seen_hashes[size] as Dictionary).get(digest, &"") as StringName
if not owner.is_empty() and owner != id:
	push_error("EQUIPMENT_ICON_VALIDATION_ERROR item=%s duplicate_of=%s size=%d" % [id, owner, size])
	return false
(seen_hashes[size] as Dictionary)[digest] = id
```

Use this validator helper:

```gdscript
func _image_digest(image: Image) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(image.get_data()) != OK:
		return ""
	return context.finish().hex_encode()
```

Print the exact success marker:

```gdscript
print("EQUIPMENT_ICON_VALIDATION_OK sets=%d items=%d unique_master=%d unique_runtime=%d" % [requested_sets.size(), item_count, (seen_hashes[256] as Dictionary).size(), (seen_hashes[128] as Dictionary).size()])
```

- [ ] **Step 4: Run the contract and standalone validators**

```powershell
& $godot --headless --path . --script res://tests/focused_test_runner.gd -- res://tests/unit/test_equipment_icon_validator_contract.gd
& $godot --headless --path . --script res://tools/validate_equipment_icons.gd -- --sets=all
```

Expected: focused test pass; standalone marker reports 9 sets, 99 items, 99 unique masters, and 99 unique runtime images.

- [ ] **Step 5: Verify two complete regenerations are byte-deterministic**

```powershell
function Get-EquipmentPngHashes {
    Get-ChildItem -LiteralPath 'assets/ui/equipment' -Recurse -Filter '*.png' |
        Sort-Object FullName |
        ForEach-Object { "{0} {1}" -f $_.FullName.Substring((Get-Location).Path.Length + 1), (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash }
}
$before = Get-EquipmentPngHashes
& $godot --headless --path . --script res://tools/render_equipment_icons.gd -- --sets=all
if ($LASTEXITCODE -ne 0) { throw "second icon render failed" }
& $godot --headless --path . --script res://tools/build_equipment_contact_sheets.gd
if ($LASTEXITCODE -ne 0) { throw "second contact build failed" }
$after = Get-EquipmentPngHashes
$difference = Compare-Object $before $after
if ($difference) { $difference | Format-Table; throw 'equipment PNG regeneration is not deterministic' }
Write-Output 'EQUIPMENT_ICON_DETERMINISM_OK files=207'
```

Expected: `EQUIPMENT_ICON_DETERMINISM_OK files=207`.

- [ ] **Step 6: Commit the standalone gate**

```powershell
git add -- tools/validate_equipment_icons.gd tests/unit/test_equipment_icon_validator_contract.gd
git diff --cached --check
git commit -m "test: reject duplicate equipment icon artwork"
```

---

### Task 4: Visual Review, Integration Gates, and Evidence

**Files:**
- Modify: `docs/qa/2026-08-01-playable-class-presentation-validation.md`

**Interfaces:**
- Consumes: corrected assets and validation tools from Tasks 1-3.
- Produces: reviewed contact sheets, green Godot gates, and an appended QA evidence record.

- [ ] **Step 1: Inspect all nine contact sheets at original resolution**

Open each `assets/ui/equipment/contact_sheets/*_contact_sheet.png` with the image-viewing tool. Record pass/fail for correct slot silhouette, distinct items within each set, palette coherence, runtime-size readability, padding, centering, clipping, and visual noise. If any sheet fails, return to Task 1's family drawing or identity treatment and repeat Tasks 2-3 before continuing.

- [ ] **Step 2: Run a clean Godot import scan for resource-backed presentation tests**

```powershell
$verifyAppData = Join-Path (Resolve-Path '.superpowers\sdd') 'equipment-icon-verify-appdata'
New-Item -ItemType Directory -Force -Path $verifyAppData | Out-Null
$previousAppData = $env:APPDATA
$env:APPDATA = $verifyAppData
try {
    & $godot --headless --editor --path . --quit-after 2
    if ($LASTEXITCODE -ne 0) { throw "Godot import scan failed with $LASTEXITCODE" }
} finally {
    $env:APPDATA = $previousAppData
}
```

Expected: exit code 0 with no `SCRIPT ERROR` or failed resource imports.

- [ ] **Step 3: Run presentation, locomotion, and full-suite gates**

```powershell
& $godot --headless --path . --script res://tests/integration/character_presentation_sandbox_runner.gd
& $godot --headless --path . --script res://tests/integration/character_locomotion_smoke.gd
& $godot --headless --path . --script res://tests/test_runner.gd
```

Expected markers:

```text
PARTY_FORGE_PLAYABLE_PRESENTATION_SMOKE_OK classes=9 bodies=2 slots=11 items=99 icons=198 animations=21 projectiles=6 effects=5
PARTY_FORGE_LOCOMOTION_SMOKE_OK directions=4 walk=1 idle=1 attack_lock=1 equipment_independent=1
TEST_SUMMARY: PASS (92 suites)
```

The suite total becomes 92 after adding the two new unit suites. Treat any timeout, missing marker, `SCRIPT ERROR`, `TEST_FAILURE`, or nonzero exit as a failure.

- [ ] **Step 4: Append corrective evidence to the QA record**

Add a `## 2026-08-02 icon distinction correction` section to `docs/qa/2026-08-01-playable-class-presentation-validation.md` containing:

```markdown
## 2026-08-02 icon distinction correction

- Replaced filename-guessed slot silhouettes with catalog/slot-driven families.
- Regenerated 99 transparent masters, 99 transparent runtime icons, and nine contact sheets.
- Verified 99 unique master pixel hashes and 99 unique runtime pixel hashes.
- Verified deterministic regeneration across all 207 PNG outputs.
- Reviewed all nine contact sheets at original resolution for slot readability, distinction, padding, and class palette coherence.
- Re-ran presentation, locomotion, standalone icon, and full-suite gates with no new errors.
- Preserved the 99 resources as canonical base items; rarity and affix treatments remain runtime item-instance layers.
```

Replace the final bullet's general gate wording with the exact observed success markers and suite count from Step 3.

- [ ] **Step 5: Confirm only intended files differ and remove audit-only sidecars**

Run `git status --short`. Verify no `.import`, `.uid`, `.godot`, APPDATA, or unrelated scene files are staged. In the isolated worktree only, resolve every untracked `assets/ui/equipment/**/*.import` path and verify it is beneath the worktree's `assets/ui/equipment` directory before removing those import sidecars. Do not remove any file from the live main checkout.

- [ ] **Step 6: Commit the evidence record**

```powershell
git add -- docs/qa/2026-08-01-playable-class-presentation-validation.md
git diff --cached --check
git commit -m "docs: record distinct equipment icon validation"
```

- [ ] **Step 7: Final branch verification**

```powershell
git status --short
git log --oneline -4
```

Expected: clean isolated worktree and four focused commits: renderer contract, corrected asset set, standalone duplicate gate, and QA evidence.
