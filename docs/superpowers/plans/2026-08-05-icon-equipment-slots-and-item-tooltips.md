# Icon Equipment Slots and Item Tooltips Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace numbered text equipment cells with real item icons and provide shared PoE/Last Epoch-style normal, comparison, advanced-affix, pinned, and controller-operable tooltips across the developer sandbox, Armoury, and Warehouse.

**Architecture:** Add a catalog-backed item presentation projector, a shared icon-rendering `StorageSlotButton`, a pure comparison resolver, and a reusable `ItemTooltipPanel` composed from `ItemTooltipCard` views. Existing screens consume these read-only presentation components while all equip, move, swap, drag, persistence, and ownership mutations continue through their current services and signals.

**Tech Stack:** Godot 4.7.1 Mono editor/runtime, typed GDScript, Godot `Control` scenes, the existing custom test runner, headless integration runners, and PowerShell verification commands.

## Global Constraints

- Work only in the isolated `feat/icon-equipment-ui` worktree until the feature is reviewed and ready to integrate.
- Preserve the existing item ownership, storage transaction, extraction, drag/drop, controller pick-up, and controller place behavior.
- Tooltip and slot presentation code must never mutate item ownership directly.
- Occupied cells render icons without slot numbers, item names, item levels, or affix text.
- Normal view hides affix identity, kind, tier, and roll range; Shift/RT reveals them.
- Alt/LT compares against every occupied compatible replacement, including both rings or both valid one-handed weapon candidates.
- Pinning locks only the inspected item; modifier layers remain temporary.
- Y/Triangle pins the focused item when unpinned and unpins the existing card regardless of later grid focus.
- Mouse wheel and scrollbar dragging scroll tooltips; right-stick up/down must retain controller focus while scrolling.
- Player Mode never shows technical item identifiers; Developer Mode may show them in a collapsed technical section.
- Target viewports are exactly 1920x1080, 2560x1440, and 3840x2160; existing 1280x720 coverage remains a compatibility smoke check.
- Rarity must be conveyed by text and frame treatment as well as color.
- Invalid or absent presentation metadata is omitted or represented by an intentional fallback; never fabricate item names or roll ranges.

---

## File and Interface Map

### New production files

- `scripts/ui/storage/item_presentation_projector.gd`: converts an `ItemInstance` plus catalogs and optional class context into one defensive presentation `Dictionary`.
- `scripts/ui/storage/equipment_ui_metrics.gd`: returns deterministic slot/card dimensions for a viewport.
- `scripts/ui/storage/item_rarity_palette.gd`: maps rarity IDs to shared frame/text colors and intensity classes.
- `scripts/ui/storage/item_comparison_resolver.gd`: resolves occupied compatible leader slots and safe numeric modifier deltas.
- `scripts/ui/storage/item_tooltip_card.gd`: renders exactly one inspected or equipped item card.
- `scripts/ui/storage/item_tooltip_panel.gd`: extends `TemporaryHoverPopup`; owns pin state, modifier state, comparison-card composition, placement, and scrolling.
- `scenes/ui/storage/item_tooltip_panel.tscn`: shared tooltip panel scene with pin button, scroll container, card row, and adaptive input hints.

### New tests

- `tests/unit/test_item_presentation_projector.gd`
- `tests/unit/test_storage_slot_button.gd`
- `tests/unit/test_item_comparison_resolver.gd`
- `tests/unit/test_item_tooltip_card.gd`
- `tests/unit/test_item_tooltip_panel.gd`
- `tests/integration/item_tooltip_input_runner.gd`
- `tests/integration/item_tooltip_responsive_runner.gd`

### Existing files changed

- `scripts/ui/storage/profile_storage_projection.gd`
- `scripts/ui/storage/storage_slot_button.gd`
- `scripts/ui/temporary_hover_popup.gd`
- `tools/configure_tooltip_inputs.gd`
- `project.godot`
- `scripts/ui/armoury/armoury_screen.gd`
- `scenes/ui/armoury/armoury_screen.tscn`
- `scripts/ui/warehouse/warehouse_screen.gd`
- `scenes/ui/warehouse/warehouse_screen.tscn`
- `scripts/ui/developer_item_sandbox.gd`
- `scenes/ui/developer_item_sandbox.tscn`
- `scripts/game/main.gd`
- Existing focused screen and integration tests named in their tasks below.

---

### Task 1: Catalog-backed item presentation records

**Files:**
- Create: `scripts/ui/storage/item_presentation_projector.gd`
- Modify: `scripts/ui/storage/profile_storage_projection.gd:18-100`
- Create: `tests/unit/test_item_presentation_projector.gd`
- Modify: `tests/unit/test_profile_storage_projection.gd:4-71`

**Interfaces:**
- Consumes: `ItemInstance`, `EquipmentCatalog`, `ItemFoundationCatalog`, `StatCatalog`, and optional `ClassDefinition`.
- Produces: `ItemPresentationProjector.project(item: ItemInstance, equipment: EquipmentCatalog, foundation: ItemFoundationCatalog, stats: StatCatalog, class_definition: ClassDefinition = null) -> Dictionary`.
- Produces record keys: `instance_id`, `base_definition_id`, `name`, `item_type_id`, `icon_path`, `rarity_id`, `rarity_name`, `item_level`, `compatible_slot_ids`, `handedness_id`, `attribute_requirements`, `required_all_tags`, `required_any_tags`, `excluded_tags`, `requirement_lines`, `equip_warning_lines`, `core_value_lines`, `affixes`, `modifier_totals`, and `item`.
- Each projected affix contains `definition_id`, `display_name`, `affix_kind`, `tier`, and `rolls`; each roll contains `stat_id`, `stat_name`, `operation`, `operation_name`, `value`, `effect_text`, and optional `minimum_roll`, `maximum_roll`, `roll_fraction`.

- [ ] **Step 1: Write the failing projector tests**

Create a fixture using the existing `windrunner_band` base and `stout` tier-2 affix. Assert catalog display names, compatible slots, requirements, readable roll text, real tier bounds `4.0-6.0`, and a `0.5` roll fraction for value `5.0`:

```gdscript
func _test_complete_record(failures: Array[String]) -> void:
	var item := _item_with_stout_roll(5.0)
	var detail := ItemPresentationProjector.project(
		item,
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG,
		GameCatalog.STAT_CATALOG,
	)
	TestAssertions.equal(detail["name"], "Windrunner Band", "base name is authoritative", failures)
	TestAssertions.equal(detail["compatible_slot_ids"], ["ring_left", "ring_right"], "both ring slots project", failures)
	var roll: Dictionary = detail["affixes"][0]["rolls"][0]
	TestAssertions.equal(roll["stat_name"], "Constitution", "stat display name projects", failures)
	TestAssertions.equal(roll["effect_text"], "+5 Constitution", "normal effect is player-readable", failures)
	TestAssertions.equal(roll["minimum_roll"], 4.0, "tier minimum projects", failures)
	TestAssertions.equal(roll["maximum_roll"], 6.0, "tier maximum projects", failures)
	TestAssertions.near(float(roll["roll_fraction"]), 0.5, 0.001, "roll position projects", failures)

func _item_with_stout_roll(value: float) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = "projector-item"
	item.base_definition_id = &"windrunner_band"
	item.rarity_id = &"uncommon"
	item.item_level = 31
	var affix := ItemAffixInstance.new()
	affix.definition_id = &"stout"
	affix.affix_kind = "prefix"
	affix.tier = 2
	var roll := ItemModifierRoll.new()
	roll.stat_id = &"constitution"
	roll.operation = StatModifier.Operation.FLAT
	roll.value = value
	affix.rolls.append(roll)
	item.affixes.append(affix)
	return item
```

Add malformed-definition coverage that asserts absent range keys instead of invented numbers, and class-context coverage that asserts a readable unmet attribute/tag warning.

- [ ] **Step 2: Run the projector test and verify RED**

Run:

```powershell
& $godot --headless --path $project --quit-after 120 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_presentation_projector.gd
```

Expected: non-zero exit because `ItemPresentationProjector` does not exist.

- [ ] **Step 3: Implement `ItemPresentationProjector`**

Use one projector for profile storage and the developer sandbox. The roll projection must use the affix definition, not the instance value, for bounds:

```gdscript
class_name ItemPresentationProjector
extends RefCounted

static func project(
	item: ItemInstance,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	stats: StatCatalog,
	class_definition: ClassDefinition = null,
) -> Dictionary:
	if item == null or equipment == null or foundation == null or stats == null:
		return {}
	var base := equipment.definition(item.base_definition_id)
	var rarity := foundation.rarity(item.rarity_id)
	if base == null or rarity == null:
		return {}
	var affixes: Array[Dictionary] = []
	var totals: Dictionary = {}
	for instance: ItemAffixInstance in item.affixes:
		affixes.append(_project_affix(instance, foundation, stats, totals))
	return {
		"instance_id": item.instance_id,
		"base_definition_id": String(item.base_definition_id),
		"name": base.display_name,
		"item_type_id": String(base.item_type_id),
		"icon_path": _icon_path(base),
		"rarity_id": String(item.rarity_id),
		"rarity_name": rarity.display_name,
		"item_level": item.item_level,
		"compatible_slot_ids": _strings(base.compatible_slot_ids),
		"handedness_id": String(base.handedness_id),
		"attribute_requirements": base.attribute_requirements.duplicate(true),
		"required_all_tags": _strings(base.required_all_tags),
		"required_any_tags": _strings(base.required_any_tags),
		"excluded_tags": _strings(base.excluded_tags),
		"requirement_lines": _requirement_lines(base, stats),
		"equip_warning_lines": _equip_warning_lines(base, class_definition, stats),
		"core_value_lines": PackedStringArray(),
		"affixes": affixes,
		"modifier_totals": totals,
		"item": item.to_dictionary(),
	}
```

For increased/reduced/more/less operations, format fractional values as percentages by multiplying by `100.0`; flat operations retain their native values. Add range keys only when `tier` is inside `minimum_tier...maximum_tier` and both tier arrays contain the index. Compute `roll_fraction` as `0.0` for equal bounds or `clampf((value-minimum)/(maximum-minimum), 0.0, 1.0)` otherwise.

- [ ] **Step 4: Route `ProfileStorageProjection` through the projector**

Extend its constructor without breaking existing three-argument callers:

```gdscript
static func from_profile(
	profile: ProfileState,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
	stats: StatCatalog = GameCatalog.STAT_CATALOG,
	class_definition: ClassDefinition = null,
) -> ProfileStorageProjection:
```

Replace the inline affix/item record construction at lines 60-99 with:

```gdscript
for instance_id: String in registry.ids():
	var detail := ItemPresentationProjector.project(
		registry.item(instance_id), equipment, foundation, stats, class_definition
	)
	if detail.is_empty():
		result.error = "%s field=item_records instance=%s reason=presentation data is unavailable" % [ERROR_PREFIX, instance_id]
		return result
	result._item_records[instance_id] = detail
```

Keep `inspector_text()` temporarily for callers migrated in Tasks 6-8; do not expand it.

- [ ] **Step 5: Run focused projection tests**

Run the two projector suites. Expected: exit `0`, `TEST_SUMMARY: PASS (0 failures)`.

```powershell
& $godot --headless --path $project --quit-after 120 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_presentation_projector.gd tests/unit/test_profile_storage_projection.gd
```

- [ ] **Step 6: Commit Task 1**

```powershell
git add scripts/ui/storage/item_presentation_projector.gd scripts/ui/storage/profile_storage_projection.gd tests/unit/test_item_presentation_projector.gd tests/unit/test_profile_storage_projection.gd
git commit -m "feat: project equipment tooltip data"
```

---

### Task 2: Shared icon slot and responsive visual metrics

**Files:**
- Create: `scripts/ui/storage/equipment_ui_metrics.gd`
- Create: `scripts/ui/storage/item_rarity_palette.gd`
- Modify: `scripts/ui/storage/storage_slot_button.gd:1-32`
- Create: `tests/unit/test_storage_slot_button.gd`

**Interfaces:**
- Consumes: the presentation `Dictionary` produced by Task 1.
- Produces: `EquipmentUiMetrics.for_viewport(size: Vector2) -> Dictionary` with `scale`, `slot_size`, `card_width`, `card_gap`, `edge_margin`, and `maximum_card_height`.
- Produces: `ItemRarityPalette.color_for(rarity_id: StringName) -> Color` and `intensity_for(rarity_id: StringName) -> int`.
- Replaces slot binding with `StorageSlotButton.bind_item(container_id_value: StringName, slot_value: int, item_id_value: String, detail_value: Dictionary, empty_label: String = "") -> void`.
- Produces signals `inspection_started(source: StorageSlotButton)` and `inspection_ended(source: StorageSlotButton)`.
- Produces `detail() -> Dictionary`, `source_id() -> StringName`, `set_selected(active: bool)`, `set_held(active: bool)`, and `set_drop_target(active: bool, valid: bool)`.
- Temporarily preserves the existing `bind(container_id_value, slot_value, item_id_value, label)` adapter until Tasks 6-8 migrate every caller; Task 8 removes the adapter after `rg "\.bind\(" scripts/ui` confirms no storage-slot caller remains.

- [ ] **Step 1: Write failing slot tests**

Assert occupied buttons use `icon`, empty buttons use only the supplied empty label, native tooltip text is disabled, accessibility names retain the item name, focus/mouse inspection emits once per combined lifetime, and held/drop states do not replace the icon:

```gdscript
func _test_occupied_icon_slot(failures: Array[String]) -> void:
	var button := StorageSlotButton.new()
	button.bind_item(&"stash-tab-000", 42, "item-1", {
		"name": "Windrunner Band",
		"icon_path": "res://assets/ui/equipment/runtime/greenwood/windrunner_band_128.png",
		"rarity_id": "uncommon",
	})
	TestAssertions.equal(button.text, "", "occupied slot has no number or name text", failures)
	TestAssertions.truthy(button.icon != null, "occupied slot loads its real icon", failures)
	TestAssertions.equal(button.tooltip_text, "", "native tooltip cannot compete with item card", failures)
	TestAssertions.truthy(button.accessibility_name.contains("Windrunner Band"), "accessible name keeps identity", failures)
```

Add a missing-icon record with a nonexistent `icon_path` and assert it renders a centered `?` fallback, never the item name or storage index. The accessible name must still identify the item and state that its icon is unavailable.

Add metrics assertions for the three target resolutions and 1280x720. Add palette assertions that all functional rarities return distinguishable written intensity classes even when colors happen to be close.

- [ ] **Step 2: Run the slot test and verify RED**

Expected: non-zero exit because `bind_item`, metrics, and palette do not exist.

```powershell
& $godot --headless --path $project --quit-after 120 --script res://tests/focused_test_runner.gd -- tests/unit/test_storage_slot_button.gd
```

- [ ] **Step 3: Implement deterministic metrics and rarity palette**

Use one bounded scale formula:

```gdscript
class_name EquipmentUiMetrics
extends RefCounted

static func for_viewport(size: Vector2) -> Dictionary:
	var scale := clampf(minf(size.x / 1920.0, size.y / 1080.0), 0.82, 1.60)
	return {
		"scale": scale,
		"slot_size": Vector2(78.0, 78.0) * scale,
		"card_width": 340.0 * scale,
		"card_gap": 12.0 * scale,
		"edge_margin": 16.0 * scale,
		"maximum_card_height": minf(720.0 * scale, size.y - 32.0 * scale),
	}
```

Map `common`, `uncommon`, `rare`, `epic`, `legendary`, `mythic`, and `eternal` explicitly in `ItemRarityPalette`; unknown rarities return a neutral fallback and intensity `0`.

- [ ] **Step 4: Upgrade `StorageSlotButton`**

Keep the existing `item_dropped` signal and drag payload exact. Set `expand_icon = true`, center the icon, apply a duplicated `StyleBoxFlat` per state, and load icons only after `ResourceLoader.exists(path)` succeeds. When an occupied item's icon is unavailable, set `text = "?"` with a centered neutral fallback style; do not expose its item name or slot number as rendered text. Track `_mouse_inside` and `_focus_inside` so leaving one input source does not end inspection while the other remains active.

Do not remove the old `bind()` signature in this task. Implement it as a compatibility adapter for screens that have not migrated yet. The adapter deliberately restores the legacy label after shared state is bound so existing screen tests remain green until Tasks 6-8 replace the call:

```gdscript
func bind(container_id_value: StringName, slot_value: int, item_id_value: String, label: String) -> void:
	bind_item(container_id_value, slot_value, item_id_value, {}, label)
	text = label
	accessibility_name = label
```

Tasks 6-8 replace every adapter call with `bind_item()` before the adapter is removed.

The drag preview must use the icon when available:

```gdscript
func _get_drag_data(_position: Vector2) -> Variant:
	if item_id.is_empty():
		return null
	var preview := TextureRect.new()
	preview.texture = icon
	preview.custom_minimum_size = Vector2(64.0, 64.0)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	return {"container_id": String(container_id), "slot": slot, "item_id": item_id}
```

- [ ] **Step 5: Run the slot and existing storage screen unit tests**

Expected: exit `0`, `TEST_SUMMARY: PASS (0 failures)`.

```powershell
& $godot --headless --path $project --quit-after 120 --script res://tests/focused_test_runner.gd -- tests/unit/test_storage_slot_button.gd tests/unit/test_armoury_screen.gd tests/unit/test_warehouse_screen.gd
```

- [ ] **Step 6: Commit Task 2**

```powershell
git add scripts/ui/storage/equipment_ui_metrics.gd scripts/ui/storage/item_rarity_palette.gd scripts/ui/storage/storage_slot_button.gd tests/unit/test_storage_slot_button.gd
git commit -m "feat: render shared icon equipment slots"
```

---

### Task 3: Compatible-slot comparison resolver

**Files:**
- Create: `scripts/ui/storage/item_comparison_resolver.gd`
- Create: `tests/unit/test_item_comparison_resolver.gd`

**Interfaces:**
- Consumes: inspected presentation record, `leader_slots: Array[Dictionary]`, and `item_records: Dictionary`.
- Produces: `ItemComparisonResolver.resolve(inspected: Dictionary, leader_slots: Array[Dictionary], item_records: Dictionary) -> Array[Dictionary]`.
- Each result contains `slot_id`, `item`, and `delta_lines`.
- Each delta line contains `stat_id`, `operation`, `delta`, `direction`, and `text`; positive values use direction `1`, negative `-1`, zero `0`.

- [ ] **Step 1: Write failing resolver tests**

Cover one helmet candidate, both ring candidates in canonical slot order, both one-handed candidates, empty compatible slots, inspected item already equipped, defensive copies, and delta calculation:

```gdscript
func _test_both_ring_candidates(failures: Array[String]) -> void:
	var inspected := _detail("new-ring", ["ring_left", "ring_right"], 8.0)
	var leader := [
		{"slot_id": "ring_left", "slot": 8, "instance_id": "left-ring"},
		{"slot_id": "ring_right", "slot": 9, "instance_id": "right-ring"},
	]
	var candidates := ItemComparisonResolver.resolve(inspected, leader, {
		"left-ring": _detail("left-ring", ["ring_left", "ring_right"], 5.0),
		"right-ring": _detail("right-ring", ["ring_left", "ring_right"], 10.0),
	})
	TestAssertions.equal(candidates.size(), 2, "both equipped rings compare", failures)
	TestAssertions.equal([candidates[0]["slot_id"], candidates[1]["slot_id"]], ["ring_left", "ring_right"], "ring order is canonical", failures)

func _detail(instance_id: String, compatible_slots: Array[String], constitution: float) -> Dictionary:
	return {
		"instance_id": instance_id,
		"compatible_slot_ids": compatible_slots,
		"modifier_totals": {"constitution|0": constitution},
	}
```

- [ ] **Step 2: Run the resolver test and verify RED**

Expected: non-zero exit because `ItemComparisonResolver` does not exist.

- [ ] **Step 3: Implement resolution and safe deltas**

Use `compatible_slot_ids` and occupied leader entries only. Skip the inspected instance ID to avoid comparing an equipped item with itself. Do not cap or silently discard valid candidates.

For deltas, compare matching `modifier_totals` keys. Interpret the delta as `inspected_value - equipped_value`; format flat values natively and multiplicative operations as percentage points. Never aggregate unlike stat IDs or operations.

```gdscript
static func resolve(inspected: Dictionary, leader_slots: Array[Dictionary], item_records: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var compatible: Array = inspected.get("compatible_slot_ids", [])
	for slot_entry: Dictionary in leader_slots:
		if String(slot_entry.get("slot_id", "")) not in compatible:
			continue
		var instance_id := String(slot_entry.get("instance_id", ""))
		if instance_id.is_empty() or instance_id == String(inspected.get("instance_id", "")):
			continue
		var equipped := (item_records.get(instance_id, {}) as Dictionary).duplicate(true)
		if equipped.is_empty():
			continue
		result.append({
			"slot_id": String(slot_entry["slot_id"]),
			"item": equipped,
			"delta_lines": _delta_lines(inspected, equipped),
		})
	return result
```

- [ ] **Step 4: Run resolver tests**

Expected: exit `0`, `TEST_SUMMARY: PASS (0 failures)`.

```powershell
& $godot --headless --path $project --quit-after 120 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_comparison_resolver.gd
```

- [ ] **Step 5: Commit Task 3**

```powershell
git add scripts/ui/storage/item_comparison_resolver.gd tests/unit/test_item_comparison_resolver.gd
git commit -m "feat: resolve equipment comparison candidates"
```

---

### Task 4: One-card normal and advanced item rendering

**Files:**
- Create: `scripts/ui/storage/item_tooltip_card.gd`
- Create: `tests/unit/test_item_tooltip_card.gd`

**Interfaces:**
- Consumes: one Task 1 presentation record and optional Task 3 delta lines.
- Produces: `ItemTooltipCard.present(detail: Dictionary, role: StringName, advanced: bool, delta_lines: Array[Dictionary] = [], developer_mode: bool = false) -> void`.
- Produces query helpers used by tests and the panel: `displayed_instance_id() -> String`, `advanced_visible() -> bool`, `technical_visible() -> bool`, and `rendered_text() -> String`.

- [ ] **Step 1: Write failing card tests**

Assert the normal card contains rarity/name, base type, item level, requirements, normal effect text, and equip warnings while excluding `Of Embers`, `Suffix`, `Tier`, range text, and instance ID. Assert advanced mode reveals identity/kind/tier/range and Developer Mode can reveal the technical section:

```gdscript
card.present(detail, &"inspected", false, [], false)
var normal_text := card.rendered_text()
TestAssertions.truthy(normal_text.contains("+18% Fire Damage"), "normal effect is visible", failures)
TestAssertions.truthy(not normal_text.contains("of Embers"), "normal view hides affix identity", failures)
TestAssertions.truthy(not normal_text.contains("item-instance-1"), "player view hides instance id", failures)

card.present(detail, &"inspected", true, [], true)
var advanced_text := card.rendered_text()
TestAssertions.truthy(advanced_text.contains("of Embers"), "advanced view shows affix identity", failures)
TestAssertions.truthy(advanced_text.contains("Suffix") and advanced_text.contains("Tier 3"), "advanced classification is visible", failures)
TestAssertions.truthy(advanced_text.contains("Range: 15-20%"), "advanced range is visible", failures)
```

- [ ] **Step 2: Run the card test and verify RED**

Expected: non-zero exit because `ItemTooltipCard` does not exist.

- [ ] **Step 3: Implement the card as a focused view**

Build child controls once in `_ready()` and update their text/visibility in `present()`. Required named regions are `Header`, `Classification`, `Requirements`, `CoreValues`, `ImplicitModifiers`, `ExplicitModifiers`, `SpecialModifiers`, `EligibilityWarning`, `ComparisonDeltas`, and `TechnicalDetails`.

Use `ItemRarityPalette.color_for()` for header and frame accents. Prefix equipped cards with `"Equipped - %s" % slot_label` via the `role`/delta context supplied by the panel. Use green, red, and neutral colors only for `delta_lines`; ordinary affix lines remain neutral. Implement the technical footer as a `TechnicalToggle` button controlling a `TechnicalDetails` `VBoxContainer`; both controls are hidden when `developer_mode` is false, and the details container begins collapsed when it is true.

- [ ] **Step 4: Run card and projector tests**

Expected: exit `0`, `TEST_SUMMARY: PASS (0 failures)`.

```powershell
& $godot --headless --path $project --quit-after 120 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_tooltip_card.gd tests/unit/test_item_presentation_projector.gd
```

- [ ] **Step 5: Commit Task 4**

```powershell
git add scripts/ui/storage/item_tooltip_card.gd tests/unit/test_item_tooltip_card.gd
git commit -m "feat: render layered item tooltip cards"
```

---

### Task 5: Tooltip panel lifecycle, modifier inputs, placement, and scrolling

**Files:**
- Create: `scripts/ui/storage/item_tooltip_panel.gd`
- Create: `scenes/ui/storage/item_tooltip_panel.tscn`
- Modify: `scripts/ui/temporary_hover_popup.gd:13-120`
- Modify: `tools/configure_tooltip_inputs.gd:1-49`
- Modify: `project.godot` input map
- Create: `tests/unit/test_item_tooltip_panel.gd`
- Create: `tests/integration/item_tooltip_input_runner.gd`

**Interfaces:**
- Consumes: inspected detail, anchor, comparison candidates, and Developer Mode flag.
- Produces: `ItemTooltipPanel.show_item(detail: Dictionary, comparisons: Array[Dictionary], anchor: Control, source_id: StringName, developer_mode: bool = false) -> bool`.
- Produces: `release_item(source_id: StringName)`, `set_compare_active(active: bool)`, `set_advanced_active(active: bool)`, `comparison_active() -> bool`, and `advanced_active() -> bool`.
- Produces test/placement queries `card_count() -> int`, `pin_button_rect() -> Rect2`, and `scrollbar_rect() -> Rect2`.
- Adds input actions `tooltip_compare` and `tooltip_advanced` without removing `tooltip_hold`, `tooltip_pin`, `tooltip_scroll_up`, or `tooltip_scroll_down`.

- [ ] **Step 1: Write failing panel state tests**

Cover temporary source release, Alt hold, pin rejection of a replacement, unpin regardless of later focus, comparison/advanced independence, combined layers, and modifier collapse while pinned:

```gdscript
panel.show_item(inspected, comparisons, anchor, &"inspected", true)
panel.set_compare_active(true)
panel.set_advanced_active(true)
panel.toggle_pin()
panel.release_item(&"inspected")
panel.set_compare_active(false)
panel.set_advanced_active(false)
TestAssertions.truthy(panel.visible and panel.is_pinned(), "main card remains pinned", failures)
TestAssertions.equal(panel.card_count(), 1, "temporary comparison cards collapse", failures)
TestAssertions.truthy(not panel.advanced_active(), "advanced layer collapses", failures)
TestAssertions.truthy(not panel.show_item(other, [], anchor, &"other"), "pinned card rejects replacement", failures)
```

Add a `0.12` second item-tooltip dismissal-grace test: releasing the source keeps the unpinned panel visible during the grace interval, re-presenting the same source cancels dismissal, and expiry dismisses only when the source is inactive, Alt hold is inactive, and the panel is unpinned.

- [ ] **Step 2: Run panel tests and verify RED**

Expected: non-zero exit because the panel and scene do not exist.

- [ ] **Step 3: Add explicit modifier actions**

Update `tools/configure_tooltip_inputs.gd` so it merges:

```gdscript
_set_action(&"tooltip_compare", [_key(KEY_ALT), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
_set_action(&"tooltip_advanced", [_key(KEY_SHIFT), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
```

Add `_key()` and `_axis()` constructors returning configured `InputEvent` objects. Preserve existing actions and use `device = -1` for controller bindings so every local controller can inspect its owned UI later. Run the configuration tool once to update `project.godot`, then inspect the diff to confirm no unrelated input map changes.

- [ ] **Step 4: Implement panel composition and lifecycle**

`ItemTooltipPanel` extends `TemporaryHoverPopup`. Its scene contains:

```text
ItemTooltipPanel
  Layout
    Header
      Context
      Pin
    BodyScroll
      Cards
    InputHints
```

Set `scroll_target_path = "Layout/BodyScroll"` and `pin_button_path = "Layout/Header/Pin"`, reusing `assets/ui/pin_outline.svg` and `assets/ui/pin_filled.svg`.

`show_item()` calls `present_source()`, stores defensive copies, rebuilds one inspected card, and positions the group. `set_compare_active()` adds every supplied comparison card; `set_advanced_active()` rebuilds all visible cards with advanced metadata. Override `_unhandled_input(event)` by calling `super(event)` and then tracking press/release for the two new actions. Do not convert modifier presses into pin state.

Implement `release_item()` with a one-shot `SceneTreeTimer` or owned `Timer` using `DISMISS_GRACE_SECONDS := 0.12`. Capture the released source ID; at expiry call `release_source()` only if that source is still current and has not been re-presented. Alt hold and pin retention remain authoritative in `TemporaryHoverPopup`.

Extend `TemporaryHoverPopup` only where needed to expose `current_source_id() -> StringName`; preserve all existing behavior and tests.

- [ ] **Step 5: Implement responsive placement**

Compute group width as `card_width * card_count + card_gap * (card_count - 1)` from `EquipmentUiMetrics`. Place right of the anchor when it fits, otherwise left, otherwise clamp inside the viewport. Bound height to `maximum_card_height`; the shared `BodyScroll` owns vertical overflow. Never drop a comparison card to make placement fit.

- [ ] **Step 6: Write and run real input integration**

`item_tooltip_input_runner.gd` must push actual `InputEventKey` and `InputEventJoypadMotion` events through a `SubViewport` and assert:

- Alt both retains the released mouse source and enables comparison.
- Shift enables advanced details.
- Alt+Shift shows both.
- LT and RT produce the same states.
- Y pins and later unpins after focus changes.
- Mouse wheel and right-stick scrolling move `BodyScroll`.
- Releasing modifiers removes only their layers.

Run:

```powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/integration/item_tooltip_input_runner.gd
```

Expected: `ITEM_TOOLTIP_INPUT_SUMMARY: PASS` and exit `0`.

- [ ] **Step 7: Run existing temporary-popup regression tests**

```powershell
& $godot --headless --path $project --quit-after 120 --script res://tests/focused_test_runner.gd -- tests/unit/test_temporary_hover_popup.gd tests/unit/test_upgrade_tooltip_ui.gd tests/unit/test_item_tooltip_panel.gd
& $godot --headless --path $project --quit-after 180 --script res://tests/integration/temporary_popup_input_runner.gd
```

Expected: both commands exit `0`; existing upgrade tooltip pin/Alt/scroll behavior is unchanged.

- [ ] **Step 8: Commit Task 5**

```powershell
git add scripts/ui/storage/item_tooltip_panel.gd scenes/ui/storage/item_tooltip_panel.tscn scripts/ui/temporary_hover_popup.gd tools/configure_tooltip_inputs.gd project.godot tests/unit/test_item_tooltip_panel.gd tests/integration/item_tooltip_input_runner.gd
git commit -m "feat: add pinned comparison item tooltips"
```

---

### Task 6: Migrate the Armoury to icon slots and shared tooltips

**Files:**
- Modify: `scripts/ui/armoury/armoury_screen.gd:9-220`
- Modify: `scenes/ui/armoury/armoury_screen.tscn`
- Modify: `scripts/game/main.gd:653-684,896-919,1007-1015`
- Modify: `tests/unit/test_armoury_screen.gd`
- Modify: `tests/integration/armoury_warehouse_responsive_runner.gd`

**Interfaces:**
- `ArmouryScreen.open(storage: ProfileStorageProjection, return_focus: Control = null, developer_mode: bool = false) -> void` stores the mode for refreshes.
- Every created `StorageSlotButton` binds a Task 1 detail record and connects inspection signals to the shared panel.
- `ItemComparisonResolver.resolve()` always receives the storage projection's leader slots and item records.

- [ ] **Step 1: Update Armoury tests first**

Replace assertions for `"slot\nname"` button text and persistent inspector content with assertions that:

- Occupied leader and stash cells have icons and empty `text`.
- Empty equipment cells retain an equipment-type accessibility/empty label.
- Hover/focus opens the shared tooltip.
- A ring in stash produces two comparison candidates when both leader ring slots are occupied.
- Closing Armoury force-dismisses and unpins the tooltip.
- Mouse drag/drop and controller pickup/place signals are unchanged.

- [ ] **Step 2: Run Armoury tests and verify RED**

Expected: focused failures against current text slots and inspector.

- [ ] **Step 3: Replace Armoury binding and inspector rendering**

Instantiate `ItemTooltipPanel` as `Overlay/ItemTooltip` in the scene. Remove the player-facing `Body/Inspector` panel. In `_rebuild_equipment()` and `_rebuild_stash()` call:

```gdscript
var detail := _projection.item(instance_id)
button.bind_item(
	&"leader-loadout",
	int(entry["slot"]),
	instance_id,
	detail,
	String(entry["slot_id"]).capitalize(),
)
_wire_item_inspection(button)
```

For stash cells, use an empty label rather than the storage number. `_wire_item_inspection()` connects `inspection_started` to `_show_item_tooltip` and `inspection_ended` to `release_item`. `_show_item_tooltip` resolves comparisons using `_projection.leader_slots` and `_projection.item_records`.

Remove `_render_inspector()`, `_inspector()`, `_inspector_icon()`, and `_item_label()` after all call sites are removed. Keep `selected_item_detail()` behavior for test/API compatibility.

- [ ] **Step 4: Pass class and Developer Mode context from `main.gd`**

At every storage projection construction in the main-menu UI flow, pass `GameCatalog.STAT_CATALOG` and `catalog.class_by_id(StringName(profile.leader_loadout_class_id))` when available. Pass `saved_settings.mode == PartyForgeSettings.Mode.DEVELOPER_MODE` into `ArmouryScreen.open()`.

Refresh keeps the screen's stored mode and force-dismisses a tooltip if its item no longer exists after a transaction.

- [ ] **Step 5: Run Armoury focused and responsive checks**

```powershell
& $godot --headless --path $project --quit-after 120 --script res://tests/focused_test_runner.gd -- tests/unit/test_armoury_screen.gd tests/unit/test_profile_storage_projection.gd tests/unit/test_storage_slot_button.gd
& $godot --headless --path $project --quit-after 180 --script res://tests/integration/armoury_warehouse_responsive_runner.gd
```

Expected: focused `PASS (0 failures)` and responsive runner `PASS` without regressions to movement or focus.

- [ ] **Step 6: Commit Task 6**

```powershell
git add scripts/ui/armoury/armoury_screen.gd scenes/ui/armoury/armoury_screen.tscn scripts/game/main.gd tests/unit/test_armoury_screen.gd tests/integration/armoury_warehouse_responsive_runner.gd
git commit -m "feat: migrate armoury to icon item tooltips"
```

---

### Task 7: Migrate the Warehouse to icon slots and shared tooltips

**Files:**
- Modify: `scripts/ui/warehouse/warehouse_screen.gd:8-181`
- Modify: `scenes/ui/warehouse/warehouse_screen.tscn`
- Modify: `scripts/game/main.gd:896-919,1007-1015`
- Modify: `tests/unit/test_warehouse_screen.gd`
- Modify: `tests/integration/armoury_warehouse_responsive_runner.gd`

**Interfaces:**
- `WarehouseScreen.open(storage: ProfileStorageProjection, return_focus: Control = null, developer_mode: bool = false) -> void` mirrors Armoury's tooltip context.
- Filter and sort results still retain authoritative `container_id` and `slot`; changing visual order never changes storage location.

- [ ] **Step 1: Update Warehouse tests first**

Assert occupied results show icons without slot/name text; empty storage cells are neutral; sorted/filtered cards still retain the exact source slot; tooltip comparisons use the leader loadout; bulk selection, mouse drop, controller movement, tab changes, and search remain functional.

- [ ] **Step 2: Run Warehouse tests and verify RED**

Expected: failures against current numbered cards and persistent inspector.

- [ ] **Step 3: Migrate Warehouse rendering**

Add `Overlay/ItemTooltip`, remove `Body/Inspector`, bind each result with its presentation detail, and connect inspection signals. Keep `_selected_item_id` only where bulk/category behavior still needs it; remove `_render_inspector()`, `_inspector()`, and `_inspector_icon()`.

The filtered list entry must preserve its real slot:

```gdscript
button.bind_item(
	StringName(tab["container_id"]),
	int(detail["slot"]),
	String(detail.get("instance_id", "")),
	_projection.item(String(detail.get("instance_id", ""))),
)
```

Use the same comparison resolver and tooltip panel as Armoury; do not create Warehouse-specific tooltip formatting.

- [ ] **Step 4: Pass Developer Mode and verify transaction refresh**

Update `main.gd` Warehouse `open()` call with the saved mode. Ensure `_reload_storage_projection()` refreshes both screens with the enriched shared projection and each screen dismisses a tooltip whose source item moved or disappeared.

- [ ] **Step 5: Run Warehouse and combined responsive checks**

```powershell
& $godot --headless --path $project --quit-after 120 --script res://tests/focused_test_runner.gd -- tests/unit/test_warehouse_screen.gd tests/unit/test_armoury_screen.gd tests/unit/test_storage_slot_button.gd
& $godot --headless --path $project --quit-after 180 --script res://tests/integration/armoury_warehouse_responsive_runner.gd
```

Expected: focused and integration commands exit `0`.

- [ ] **Step 6: Commit Task 7**

```powershell
git add scripts/ui/warehouse/warehouse_screen.gd scenes/ui/warehouse/warehouse_screen.tscn scripts/game/main.gd tests/unit/test_warehouse_screen.gd tests/integration/armoury_warehouse_responsive_runner.gd
git commit -m "feat: migrate warehouse to icon item tooltips"
```

---

### Task 8: Migrate the developer item sandbox without losing manipulation tools

**Files:**
- Modify: `scripts/ui/developer_item_sandbox.gd:7-566`
- Modify: `scenes/ui/developer_item_sandbox.tscn`
- Modify: `tests/unit/test_developer_item_sandbox.gd`
- Modify: `tests/integration/developer_item_sandbox_runner.gd`
- Modify: `tests/integration/task9_developer_item_sandbox_focus_runner.gd`

**Interfaces:**
- `SandboxSlotButton` extends `StorageSlotButton` and overrides only sandbox-specific drag lifecycle methods.
- Developer sandbox item details come from `ItemPresentationProjector.project(...)` with `developer_mode = true` in the tooltip.
- Existing Save, Reload, Integrity Scan, Reset, First Empty Inventory, and First Empty Stash actions remain unchanged.

- [ ] **Step 1: Update sandbox tests first**

Replace slot text assertions with icon/accessibility assertions. Add checks that:

- Five inventory and one hundred stash cells still exist.
- Occupied cells use the correct authored icon.
- No occupied cell contains the storage index or item name as rendered text.
- Focus and hover open the shared card.
- The technical section is available because the sandbox is always Developer Mode.
- Held, valid target, invalid target, selected, drag success, drag cancellation, controller pickup/place, save/reload, and integrity behavior are unchanged.

- [ ] **Step 2: Run sandbox tests and verify RED**

Expected: failures against current `"slot\nname"` rendering and inspector panel.

- [ ] **Step 3: Rebase `SandboxSlotButton` on the shared slot**

Change the nested class declaration to:

```gdscript
class SandboxSlotButton extends StorageSlotButton:
	var sandbox: DeveloperItemSandbox

	func _get_drag_data(at_position: Vector2) -> Variant:
		return sandbox._begin_mouse_drag(self) if sandbox != null else super(at_position)

	func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
		return sandbox._can_drop_on(self, data) if sandbox != null else super(at_position, data)

	func _drop_data(at_position: Vector2, data: Variant) -> void:
		if sandbox != null:
			sandbox._drop_on(self, data)
		else:
			super(at_position, data)
```

Retain the existing drag-end notification so failed drags clear held state correctly.

- [ ] **Step 4: Replace sandbox text synchronization with presentation binding**

In `_refresh_projection()`, project each live `ItemInstance` and call `bind_item()`. In `_sync_slot_affordances()`, call `set_selected()`, `set_held()`, and `set_drop_target()` rather than changing `text`, `tooltip_text`, or whole-button `modulate`.

Remove `EMPTY_INSPECTOR`, `_inspector_text()`, `_display_name_for()`, `_inspector()`, and the Inspector panel. Add the shared tooltip panel as `Overlay/ItemTooltip`; show it with zero comparison candidates because the sandbox has no leader loadout. Preserve selected container/slot fields for action buttons and transfer logic.

After all three screens use `bind_item()`, run `rg -n "\.bind\(" scripts/ui` and remove the temporary `StorageSlotButton.bind()` adapter only when the search confirms there are no remaining storage-slot calls. Keep unrelated `bind()` methods untouched.

- [ ] **Step 5: Run all sandbox checks**

```powershell
& $godot --headless --path $project --quit-after 120 --script res://tests/focused_test_runner.gd -- tests/unit/test_developer_item_sandbox.gd tests/unit/test_developer_item_sandbox_state.gd tests/unit/test_storage_slot_button.gd
& $godot --headless --path $project --quit-after 180 --script res://tests/integration/developer_item_sandbox_runner.gd
& $godot --headless --path $project --quit-after 180 --script res://tests/integration/task9_developer_item_sandbox_focus_runner.gd
```

Expected markers: `ITEM_SANDBOX_UI_SUMMARY: PASS` and `TASK9_SANDBOX_FOCUS_SUMMARY: PASS (0 failures)`.

- [ ] **Step 6: Commit Task 8**

```powershell
git add scripts/ui/developer_item_sandbox.gd scenes/ui/developer_item_sandbox.tscn tests/unit/test_developer_item_sandbox.gd tests/integration/developer_item_sandbox_runner.gd tests/integration/task9_developer_item_sandbox_focus_runner.gd
git commit -m "feat: migrate developer sandbox to icon items"
```

---

### Task 9: Responsive acceptance, regression evidence, and handoff

**Files:**
- Create: `tests/integration/item_tooltip_responsive_runner.gd`
- Modify: `tests/integration/armoury_warehouse_responsive_runner.gd`
- Create: `docs/verification/2026-08-05-icon-equipment-slots-and-item-tooltips.md`

**Interfaces:**
- Produces exact marker `ITEM_TOOLTIP_RESPONSIVE_SUMMARY: PASS (3 sizes)`.
- Verification document records commands, exits, markers, duration, and any accepted baseline diagnostics.

- [ ] **Step 1: Add the responsive runner**

For each exact target size, instantiate the tooltip under a `SubViewport`, anchor it near all four edges, and exercise zero, one, and two comparison candidates in normal, advanced, and combined modes. Assert:

```gdscript
const TARGET_SIZES: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

_assert(viewport_rect.encloses(tooltip.get_global_rect()), "tooltip remains inside viewport")
_assert(tooltip.card_count() == expected_cards, "all comparison candidates remain visible")
_assert(tooltip.pin_button_rect().end.x <= tooltip.get_global_rect().end.x, "pin remains reachable")
_assert(tooltip.scrollbar_rect().end.y <= tooltip.get_global_rect().end.y, "scrollbar remains reachable")
```

Also render 1280x720 once as a compatibility smoke check; do not include it in the exact three-size acceptance count.

- [ ] **Step 2: Run focused storage/UI suites**

```powershell
& $godot --headless --path $project --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_presentation_projector.gd tests/unit/test_profile_storage_projection.gd tests/unit/test_storage_slot_button.gd tests/unit/test_item_comparison_resolver.gd tests/unit/test_item_tooltip_card.gd tests/unit/test_item_tooltip_panel.gd tests/unit/test_temporary_hover_popup.gd tests/unit/test_armoury_screen.gd tests/unit/test_warehouse_screen.gd tests/unit/test_developer_item_sandbox.gd
```

Expected: exit `0`, `TEST_SUMMARY: PASS (0 failures)`.

- [ ] **Step 3: Run integration acceptance**

Run each command separately and retain separate logs:

```powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/integration/item_tooltip_input_runner.gd
& $godot --headless --path $project --quit-after 180 --script res://tests/integration/item_tooltip_responsive_runner.gd
& $godot --headless --path $project --quit-after 180 --script res://tests/integration/armoury_warehouse_responsive_runner.gd
& $godot --headless --path $project --quit-after 180 --script res://tests/integration/developer_item_sandbox_runner.gd
& $godot --headless --path $project --quit-after 180 --script res://tests/integration/task9_developer_item_sandbox_focus_runner.gd
& $godot --headless --path $project --quit-after 180 --script res://tests/integration/temporary_popup_input_runner.gd
```

Expected: every command exits `0` with its exact PASS marker.

- [ ] **Step 4: Run cold import and full suite with hermetic user directories**

Use fresh worktree-local `APPDATA` and `LOCALAPPDATA` roots. Do not use the live Party Forge profile directory.

```powershell
$verificationRoot = Join-Path $project '.superpowers\sdd\icon-equipment-ui-final'
$env:APPDATA = Join-Path $verificationRoot 'appdata'
$env:LOCALAPPDATA = Join-Path $verificationRoot 'localappdata'
& $godot --headless --path $project --import
& $godot --headless --path $project --quit-after 420 --script res://tests/test_runner.gd
```

Expected: import exit `0` with zero `SCRIPT ERROR`, `Parse Error`, `No loader found`, or `Failed to load` matches; full suite exit `0` with exactly one `TEST_SUMMARY: PASS (149 suites)` marker and zero `TEST_FAILURE` lines. Confirm the live `tests/unit/*.gd` count is also exactly `149`: the verified baseline is `144`, and this plan adds exactly five unit-suite files.

- [ ] **Step 5: Run startup smoke**

```powershell
& $godot --headless --path $project --quit-after 10
```

Expected: exit `0`, one `PARTY_FORGE_BOOT_OK`, one `PARTY_FORGE_CLASS_SELECTION_READY`, and no parse/script/loader failure.

- [ ] **Step 6: Inspect and clean only verification-created sidecars**

Preview untracked `.gd.uid` files before removing them. Remove only sidecars created by the cold import in this feature worktree; do not touch tracked files or unrelated user changes. Re-run `git status --short` and `git diff --check`.

- [ ] **Step 7: Write verification evidence**

Record:

- Feature branch and final commit IDs.
- Godot executable version/path.
- Hermetic user-data roots.
- Every focused/integration/import/full-suite/startup command.
- Exit codes, exact PASS markers, durations, and error scans.
- Rendered inspection results at 1080p, 1440p, and 4K.
- Confirmation that both ring candidates remain visible.
- Confirmation that Player Mode hides technical identifiers.
- Confirmation that existing movement/ownership behavior remains unchanged.

- [ ] **Step 8: Commit Task 9**

```powershell
git add tests/integration/item_tooltip_responsive_runner.gd tests/integration/armoury_warehouse_responsive_runner.gd docs/verification/2026-08-05-icon-equipment-slots-and-item-tooltips.md
git commit -m "test: verify icon equipment tooltip flow"
```

- [ ] **Step 9: Final branch review**

Run:

```powershell
git status --short
git diff --check main...HEAD
git log --oneline --decorate main..HEAD
```

Expected: clean status, no whitespace errors, and one intentional commit per completed task. Review the final diff against every acceptance criterion in `docs/superpowers/specs/2026-08-05-icon-equipment-slots-and-item-tooltips-design.md` before offering merge/integration options.
