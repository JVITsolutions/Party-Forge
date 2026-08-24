extends RefCounted

const CARD_PATH := "res://scripts/ui/storage/item_tooltip_card.gd"
const ICON_PATH := "res://assets/ui/equipment/runtime/greenwood/windrunner_band_128.png"


func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(CARD_PATH), "item tooltip card exists", failures)
	if not ResourceLoader.exists(CARD_PATH):
		return failures
	var card_script: Script = load(CARD_PATH)
	_test_icon_header_and_decorative_pointer_filters(card_script, failures)
	_test_unavailable_icon_uses_stable_placeholder(card_script, failures)
	_test_normal_and_advanced_layers(card_script, failures)
	_test_critical_definition_formatting(card_script, failures)
	_test_schema_one_empty_damage_has_no_heading(card_script, failures)
	_test_equipped_role_and_deltas(card_script, failures)
	_test_disabled_status_and_accessible_deltas(card_script, failures)
	_test_raw_fallback_rows_use_neutral_color(card_script, failures)
	_test_critical_raw_fallback_uses_whole_percent(card_script, failures)
	_test_developer_technical_gate(card_script, failures)
	return failures


func _test_icon_header_and_decorative_pointer_filters(card_script: Script, failures: Array[String]) -> void:
	var card: Control = card_script.new()
	card.call("present", _detail(), &"inspected", false, [] as Array[Dictionary], false)
	var icon := card.get_node_or_null("Layout/Header/Icon") as TextureRect
	TestAssertions.truthy(icon != null, "shared tooltip card builds an item icon in its header", failures)
	if icon != null:
		TestAssertions.truthy(icon.visible and icon.texture != null, "projected item icon is visible", failures)
		if icon.texture != null:
			TestAssertions.equal(icon.texture.resource_path, ICON_PATH, "tooltip loads only the projected item icon path", failures)
		TestAssertions.truthy(icon.accessibility_name.contains("Cinder Band"), "item icon accessibility text names the item", failures)
		TestAssertions.truthy(icon.custom_minimum_size.x >= 48.0 and icon.custom_minimum_size.y >= 48.0, "item icon preserves a readable 48 by 48 minimum", failures)
		TestAssertions.equal(icon.mouse_filter, Control.MOUSE_FILTER_IGNORE, "item icon does not intercept tooltip pointer input", failures)
	var decorative_labels := card.find_children("*", "Label", true, false)
	TestAssertions.truthy(not decorative_labels.is_empty(), "shared tooltip card exposes decorative labels", failures)
	for node: Node in decorative_labels:
		var label := node as Label
		TestAssertions.equal(label.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s decorative label ignores pointer input" % label.name, failures)
	card.free()


func _test_unavailable_icon_uses_stable_placeholder(card_script: Script, failures: Array[String]) -> void:
	var card: Control = card_script.new()
	var detail := _detail()
	detail["icon_path"] = "res://missing/tooltip-icon.png"
	card.call("present", detail, &"inspected", false, [] as Array[Dictionary], false)
	var icon := card.get_node("Layout/Header/Icon") as TextureRect
	var placeholder := icon.get_node_or_null("Placeholder") as Label
	TestAssertions.truthy(icon.texture == null, "unloadable projected icon is rejected", failures)
	TestAssertions.truthy(placeholder != null and placeholder.visible and placeholder.text == "?", "unavailable item icon uses the established question-mark placeholder", failures)
	TestAssertions.truthy(icon.custom_minimum_size.x >= 48.0 and icon.custom_minimum_size.y >= 48.0, "unavailable item icon does not collapse the header layout", failures)
	TestAssertions.truthy(icon.accessibility_name.contains("Cinder Band") and icon.accessibility_name.contains("unavailable"), "unavailable icon remains accessible by item name and state", failures)
	detail["icon_path"] = ""
	card.call("present", detail, &"inspected", false, [] as Array[Dictionary], false)
	TestAssertions.truthy(placeholder != null and placeholder.visible, "empty projected icon path keeps the established placeholder", failures)
	card.free()


func _test_normal_and_advanced_layers(card_script: Script, failures: Array[String]) -> void:
	var card: Control = card_script.new()
	var no_deltas: Array[Dictionary] = []
	card.call("present", _detail(), &"inspected", false, no_deltas, false)
	var normal_text := String(card.call("rendered_text"))
	TestAssertions.truthy(normal_text.contains("Cinder Band"), "normal card shows item name", failures)
	TestAssertions.truthy(normal_text.contains("Rare") and normal_text.contains("Item Level 31"), "normal card shows rarity and item level", failures)
	TestAssertions.truthy(normal_text.contains("Requires Dexterity 12"), "normal card shows requirements", failures)
	TestAssertions.truthy(normal_text.contains("18% increased Fire Damage"), "normal card shows player-readable effect", failures)
	TestAssertions.truthy(normal_text.contains("Fire Damage: 10.96-21.91") and normal_text.contains("Physical Damage: 32.02-42.7"), "normal card shows each typed base range", failures)
	var base_index := normal_text.find("Fire Damage: 10.96-21.91")
	var implicit_index := normal_text.find("+2 Armour")
	var explicit_index := normal_text.find("18% increased Fire Damage")
	var requirement_index := normal_text.find("Requires Dexterity 12")
	var warning_index := normal_text.find("Ranger requires Dexterity 12 (has 10)")
	TestAssertions.truthy(base_index >= 0 and base_index < implicit_index and implicit_index < explicit_index and explicit_index < requirement_index and requirement_index < warning_index, "normal tooltip order is typed base, implicit, explicit, requirements, warning", failures)
	TestAssertions.truthy(normal_text.contains("Ranger requires Dexterity 12 (has 10)"), "normal card shows equip warning", failures)
	TestAssertions.truthy(not normal_text.contains("of Embers"), "normal card hides affix identity", failures)
	TestAssertions.truthy(not normal_text.contains("Suffix"), "normal card hides affix kind", failures)
	TestAssertions.truthy(not normal_text.contains("Tier 3"), "normal card hides affix tier", failures)
	TestAssertions.truthy(not normal_text.contains("Range:"), "normal card hides roll range", failures)
	TestAssertions.truthy(not normal_text.contains("item-instance-1"), "player card hides instance id", failures)

	card.call("present", _detail(), &"inspected", true, no_deltas, false)
	var advanced_text := String(card.call("rendered_text"))
	TestAssertions.truthy(advanced_text.contains("of Embers"), "advanced card shows affix identity", failures)
	TestAssertions.truthy(advanced_text.contains("Suffix") and advanced_text.contains("Tier 3"), "advanced card shows classification", failures)
	TestAssertions.truthy(advanced_text.contains("Range: 15-20%"), "advanced card shows percentage roll range", failures)
	TestAssertions.truthy(advanced_text.contains("Roll quality: 60%"), "advanced card shows roll position", failures)
	TestAssertions.truthy(advanced_text.contains("Rarity Multiplier: 1.18") and advanced_text.contains("Fire Quality: 92.84%") and advanced_text.contains("Bounds: 10-20") and advanced_text.contains("Exact: 10.96-21.91"), "advanced card explains exact base damage quality and bounds", failures)
	TestAssertions.truthy(not advanced_text.contains("hybrid_profile"), "Player Mode advanced view omits the technical base profile id", failures)
	TestAssertions.truthy(bool(card.call("advanced_visible")), "advanced query matches rendered layer", failures)
	var base_box := card.get_node_or_null("Layout/BaseDamage") as VBoxContainer
	TestAssertions.truthy(base_box != null and base_box.get_child_count() == 2, "hybrid tooltip renders separate typed base rows", failures)
	if base_box != null and base_box.get_child_count() == 2:
		TestAssertions.equal((base_box.get_child(0) as Label).get_theme_color("font_color"), GameCatalog.DAMAGE_TYPES.definition(&"fire").presentation_color, "fire base range uses canonical damage color", failures)
		TestAssertions.equal((base_box.get_child(1) as Label).get_theme_color("font_color"), GameCatalog.DAMAGE_TYPES.definition(&"physical").presentation_color, "physical base range uses canonical damage color", failures)
	card.free()


func _test_critical_definition_formatting(card_script: Script, failures: Array[String]) -> void:
	var detail := _detail()
	detail["affixes"] = [{
		"definition_id": "ring_of_mercy_implicit",
		"display_name": "Ring Of Mercy Legacy",
		"affix_kind": "implicit",
		"tier": 1,
		"rolls": [{
			"stat_id": "crit_chance",
			"stat_name": "Critical Strike Chance",
			"operation": StatModifier.Operation.FLAT,
			"value": 0.0111,
			"formatted_value": "1%",
			"effect_text": "+1% Critical Strike Chance",
			"minimum_roll": 0.01,
			"maximum_roll": 0.02,
			"formatted_minimum_roll": "1%",
			"formatted_maximum_roll": "2%",
			"roll_fraction": 0.11,
		}],
	}]
	var card: Control = card_script.new()
	card.call("present", detail, &"inspected", true, [] as Array[Dictionary], false)
	var text := String(card.call("rendered_text"))
	TestAssertions.truthy(text.contains("+1% Critical Strike Chance"), "critical tooltip uses whole player-facing percentage points", failures)
	TestAssertions.truthy(text.contains("Range: 1%-2%"), "critical tooltip range uses definition-formatted endpoints", failures)
	TestAssertions.truthy("0.0111" not in text and "+0.01" not in text and "0.01-0.02" not in text, "critical tooltip never exposes raw ratio decimals", failures)
	card.free()


func _test_schema_one_empty_damage_has_no_heading(card_script: Script, failures: Array[String]) -> void:
	var card: Control = card_script.new()
	var detail := _detail()
	detail["base_damage_components"] = [] as Array[Dictionary]
	detail["base_damage_lines"] = PackedStringArray()
	detail["base_damage_advanced_lines"] = PackedStringArray()
	detail["base_damage_profile_id"] = ""
	card.call("present", detail, &"inspected", false, [] as Array[Dictionary], false)
	var base_box := card.get_node_or_null("Layout/BaseDamage") as Control
	TestAssertions.truthy(base_box != null and not base_box.visible, "schema-1 empty components hide the entire base damage section", failures)
	TestAssertions.truthy(not String(card.call("rendered_text")).contains("Base Damage"), "schema-1 empty components render no blank base damage heading", failures)
	card.free()

func _test_raw_fallback_rows_use_neutral_color(card_script: Script, failures: Array[String]) -> void:
	var inspected := {
		"instance_id": "new-ring",
		"name": "New Ring",
		"compatible_slot_ids": ["ring_left"],
		"modifier_totals": {
			"damage|2": 0.20,
			"damage|4": 0.05,
		},
	}
	var equipped := {
		"instance_id": "old-ring",
		"name": "Old Ring",
		"compatible_slot_ids": ["ring_left"],
		"modifier_totals": {
			"damage|2": 0.10,
			"damage|4": 0.10,
		},
	}
	var comparisons := ItemComparisonResolver.resolve(
		inspected,
		[{"slot_id": "ring_left", "instance_id": "old-ring"}],
		{"old-ring": equipped},
	)
	var card: Control = card_script.new()
	card.call("present", _detail(), StringName("equipped:ring_left"), false, comparisons[0]["delta_lines"], false)
	var delta_box := card.get_node("Layout/ComparisonDeltas") as VBoxContainer
	TestAssertions.equal(delta_box.get_child_count(), 2, "raw fallback fixture renders both differing operations", failures)
	for child: Label in delta_box.get_children():
		TestAssertions.equal(child.get_theme_color("font_color"), Color(0.78, 0.80, 0.84), "raw fallback uses the neutral comparison color", failures)
		var accessible := child.accessibility_name.to_lower()
		TestAssertions.truthy("benefit unknown" in accessible and "neutral" in accessible, "raw fallback label exposes accessible neutral meaning", failures)
	card.free()


func _test_critical_raw_fallback_uses_whole_percent(card_script: Script, failures: Array[String]) -> void:
	var inspected := {
		"instance_id": "new-ring",
		"name": "New Ring",
		"compatible_slot_ids": ["ring_left"],
		"modifier_totals": {"crit_chance|0": 0.0111},
	}
	var equipped := {
		"instance_id": "old-ring",
		"name": "Old Ring",
		"compatible_slot_ids": ["ring_left"],
		"modifier_totals": {},
	}
	var comparisons := ItemComparisonResolver.resolve(
		inspected,
		[{"slot_id": "ring_left", "instance_id": "old-ring"}],
		{"old-ring": equipped},
	)
	var card: Control = card_script.new()
	card.call("present", _detail(), StringName("equipped:ring_left"), false, comparisons[0]["delta_lines"], false)
	var rendered := String(card.call("rendered_text"))
	TestAssertions.truthy(rendered.contains("Critical Strike Chance item modifier: 1% higher"), "tooltip fallback uses player-facing critical modifier wording", failures)
	TestAssertions.truthy(" raw " not in rendered and " flat " not in rendered, "tooltip critical fallback omits raw and flat jargon", failures)
	TestAssertions.truthy("0.0111" not in rendered and "0.01 higher" not in rendered and "1.11%" not in rendered, "tooltip fallback hides legacy critical decimals", failures)
	card.free()


func _test_equipped_role_and_deltas(card_script: Script, failures: Array[String]) -> void:
	var card: Control = card_script.new()
	var deltas: Array[Dictionary] = [
		{"stat_id": "constitution", "operation": StatModifier.Operation.FLAT, "delta": 3.0, "direction": 1, "text": "+3 Constitution"},
		{"stat_id": "fire_damage", "operation": StatModifier.Operation.INCREASED, "delta": -0.05, "direction": -1, "text": "-5% Fire Damage"},
	]
	card.call("present", _detail(), StringName("equipped:ring_left"), false, deltas, false)
	var text := String(card.call("rendered_text"))
	TestAssertions.truthy(text.contains("Equipped - Ring Left"), "equipped role names replacement slot", failures)
	TestAssertions.truthy(text.contains("+3 Constitution") and text.contains("-5% Fire Damage"), "comparison deltas render", failures)
	TestAssertions.equal(String(card.call("displayed_instance_id")), "item-instance-1", "card query keeps inspected identity", failures)
	card.free()


func _test_disabled_status_and_accessible_deltas(card_script: Script, failures: Array[String]) -> void:
	var card: Control = card_script.new()
	var detail := _detail()
	detail["is_disabled"] = true
	detail["disabled_requirement_lines"] = PackedStringArray([
		"Requires Strength 15 (has 10)",
		"Requires Dexterity 12 (has 8)",
	])
	var deltas: Array[Dictionary] = [
		{"stat_id": "armor", "delta": 2.0, "direction": 1, "text": "▲ +2.0 Armour — improved", "accessible_text": "Armour improved by 2.0"},
		{"stat_id": "move_speed", "delta": -1.0, "direction": -1, "text": "▼ -1.0 Move Speed — reduced", "accessible_text": "Move Speed reduced by 1.0"},
	]
	card.call("present", detail, &"inspected", false, deltas, false)
	var text := String(card.call("rendered_text"))
	TestAssertions.truthy(text.contains("Disabled — requirements not met"), "tooltip announces disabled equipment prominently", failures)
	TestAssertions.truthy(text.contains("Requires Strength 15 (has 10)") and text.contains("Requires Dexterity 12 (has 8)"), "tooltip shows every exact unmet requirement", failures)
	var delta_box := card.get_node("Layout/ComparisonDeltas") as VBoxContainer
	var positive := delta_box.get_child(0) as Label
	var negative := delta_box.get_child(1) as Label
	TestAssertions.truthy(positive.text.begins_with("▲") and negative.text.begins_with("▼"), "comparison rows retain non-color symbols", failures)
	TestAssertions.truthy("improved" in positive.accessibility_name.to_lower() and "reduced" in negative.accessibility_name.to_lower(), "comparison labels expose accessible benefit wording", failures)
	TestAssertions.truthy(positive.get_theme_color("font_color") != negative.get_theme_color("font_color"), "improvements and losses retain distinct colors", failures)
	card.free()


func _test_developer_technical_gate(card_script: Script, failures: Array[String]) -> void:
	var card: Control = card_script.new()
	var no_deltas: Array[Dictionary] = []
	card.call("present", _detail(), &"inspected", false, no_deltas, false)
	card.call("set_technical_expanded", true)
	TestAssertions.truthy(not bool(card.call("technical_visible")), "player mode cannot reveal technical details", failures)
	TestAssertions.truthy(not String(card.call("rendered_text")).contains("item-instance-1"), "player text remains clean", failures)
	card.call("present", _detail(), &"inspected", false, no_deltas, true)
	TestAssertions.truthy(not bool(card.call("technical_visible")), "developer technical details begin collapsed", failures)
	card.call("set_technical_expanded", true)
	TestAssertions.truthy(bool(card.call("technical_visible")), "developer can expand technical details", failures)
	var technical_text := String(card.call("rendered_text"))
	TestAssertions.truthy(technical_text.contains("item-instance-1"), "developer details show instance id", failures)
	TestAssertions.truthy(technical_text.contains("windrunner_band"), "developer details show base id", failures)
	TestAssertions.truthy(technical_text.contains("Base Damage Profile: hybrid_profile"), "developer technical details show the base profile id", failures)
	card.free()


func _detail() -> Dictionary:
	return {
		"instance_id": "item-instance-1",
		"base_definition_id": "windrunner_band",
		"icon_path": ICON_PATH,
		"name": "Cinder Band",
		"item_type_id": "ring",
		"rarity_id": "rare",
		"rarity_name": "Rare",
		"item_level": 31,
		"compatible_slot_ids": ["ring_left", "ring_right"],
		"handedness_id": "none",
		"requirement_lines": PackedStringArray(["Requires Dexterity 12"]),
		"equip_warning_lines": PackedStringArray(["Ranger requires Dexterity 12 (has 10)"]),
		"core_value_lines": PackedStringArray(),
		"base_damage_components": [
			{"damage_type_id": "fire", "display_name": "Fire", "presentation_color": GameCatalog.DAMAGE_TYPES.definition(&"fire").presentation_color, "minimum_damage": 10.96, "maximum_damage": 21.91},
			{"damage_type_id": "physical", "display_name": "Physical", "presentation_color": GameCatalog.DAMAGE_TYPES.definition(&"physical").presentation_color, "minimum_damage": 32.02, "maximum_damage": 42.70},
		],
		"base_damage_lines": PackedStringArray(["Fire Damage: 10.96-21.91", "Physical Damage: 32.02-42.7"]),
		"base_damage_advanced_lines": PackedStringArray(["Rarity Multiplier: 1.18", "Fire Quality: 92.84% | Bounds: 10-20 | Exact: 10.96-21.91"]),
		"base_damage_profile_id": "hybrid_profile",
		"affixes": [{
			"definition_id": "tempered-edge",
			"display_name": "Tempered Edge",
			"affix_kind": "implicit",
			"tier": 2,
			"rolls": [{"effect_text": "+2 Armour"}],
		}, {
			"definition_id": "of-embers",
			"display_name": "of Embers",
			"affix_kind": "suffix",
			"tier": 3,
			"rolls": [{
				"stat_id": "fire_damage",
				"stat_name": "Fire Damage",
				"operation": StatModifier.Operation.INCREASED,
				"operation_name": "Increased",
				"value": 0.18,
				"effect_text": "18% increased Fire Damage",
				"minimum_roll": 0.15,
				"maximum_roll": 0.20,
				"roll_fraction": 0.60,
			}],
		}],
	}
