extends RefCounted

const CARD_PATH := "res://scripts/ui/storage/item_tooltip_card.gd"


func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(CARD_PATH), "item tooltip card exists", failures)
	if not ResourceLoader.exists(CARD_PATH):
		return failures
	var card_script: Script = load(CARD_PATH)
	_test_normal_and_advanced_layers(card_script, failures)
	_test_equipped_role_and_deltas(card_script, failures)
	_test_disabled_status_and_accessible_deltas(card_script, failures)
	_test_raw_fallback_rows_use_neutral_color(card_script, failures)
	_test_developer_technical_gate(card_script, failures)
	return failures


func _test_normal_and_advanced_layers(card_script: Script, failures: Array[String]) -> void:
	var card: Control = card_script.new()
	var no_deltas: Array[Dictionary] = []
	card.call("present", _detail(), &"inspected", false, no_deltas, false)
	var normal_text := String(card.call("rendered_text"))
	TestAssertions.truthy(normal_text.contains("Cinder Band"), "normal card shows item name", failures)
	TestAssertions.truthy(normal_text.contains("Rare") and normal_text.contains("Item Level 31"), "normal card shows rarity and item level", failures)
	TestAssertions.truthy(normal_text.contains("Requires Dexterity 12"), "normal card shows requirements", failures)
	TestAssertions.truthy(normal_text.contains("18% increased Fire Damage"), "normal card shows player-readable effect", failures)
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
	TestAssertions.truthy(bool(card.call("advanced_visible")), "advanced query matches rendered layer", failures)
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
	card.free()


func _detail() -> Dictionary:
	return {
		"instance_id": "item-instance-1",
		"base_definition_id": "windrunner_band",
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
		"affixes": [{
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
