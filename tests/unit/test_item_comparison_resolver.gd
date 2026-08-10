extends RefCounted

const RESOLVER_PATH := "res://scripts/ui/storage/item_comparison_resolver.gd"


func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(RESOLVER_PATH), "item comparison resolver exists", failures)
	if not ResourceLoader.exists(RESOLVER_PATH):
		return failures
	var resolver: Script = load(RESOLVER_PATH)
	_test_single_candidate(resolver, failures)
	_test_both_ring_candidates(resolver, failures)
	_test_both_one_hand_candidates(resolver, failures)
	_test_empty_and_self_slots_are_skipped(resolver, failures)
	_test_projected_rows_replace_raw_fallback(resolver, failures)
	_test_raw_fallback_operation_matrix_is_neutral_and_accessible(resolver, failures)
	_test_results_are_defensive(resolver, failures)
	return failures


func _test_single_candidate(resolver: Script, failures: Array[String]) -> void:
	var inspected := _detail("new-helmet", ["helmet"], {"constitution|0": 8.0})
	var leader: Array[Dictionary] = [
		{"slot_id": "helmet", "slot": 0, "instance_id": "old-helmet"},
	]
	var candidates: Array = resolver.call("resolve", inspected, leader, {"old-helmet": _detail("old-helmet", ["helmet"], {"constitution|0": 5.0})})
	TestAssertions.equal(candidates.size(), 1, "one occupied compatible slot produces one candidate", failures)
	if candidates.is_empty():
		return
	TestAssertions.equal(candidates[0]["slot_id"], "helmet", "candidate keeps authoritative equipment slot", failures)
	TestAssertions.equal(candidates[0]["delta_lines"], [{
		"stat_id": "constitution",
		"operation": StatModifier.Operation.FLAT,
		"delta": 3.0,
		"direction": 0,
		"raw_direction": 1,
		"text": "- Constitution raw flat roll: 3 higher -- benefit unknown",
		"accessible_text": "Constitution raw flat roll is 3 higher; benefit unknown; neutral comparison",
	}], "flat fallback delta is neutral and readable", failures)


func _test_both_ring_candidates(resolver: Script, failures: Array[String]) -> void:
	var inspected := _detail("new-ring", ["ring_left", "ring_right"], {"constitution|0": 8.0})
	var leader: Array[Dictionary] = [
		{"slot_id": "ring_left", "slot": 8, "instance_id": "left-ring"},
		{"slot_id": "ring_right", "slot": 9, "instance_id": "right-ring"},
	]
	var candidates: Array = resolver.call("resolve", inspected, leader, {
		"left-ring": _detail("left-ring", ["ring_left", "ring_right"], {"constitution|0": 5.0}),
		"right-ring": _detail("right-ring", ["ring_left", "ring_right"], {"constitution|0": 10.0}),
	})
	TestAssertions.equal(candidates.size(), 2, "both equipped rings compare", failures)
	if candidates.size() == 2:
		TestAssertions.equal([candidates[0]["slot_id"], candidates[1]["slot_id"]], ["ring_left", "ring_right"], "ring order is canonical", failures)
		TestAssertions.equal(candidates[1]["delta_lines"][0]["direction"], 0, "smaller inspected raw roll remains benefit-neutral", failures)
		TestAssertions.equal(candidates[1]["delta_lines"][0].get("raw_direction"), -1, "smaller inspected raw roll retains numeric direction", failures)


func _test_both_one_hand_candidates(resolver: Script, failures: Array[String]) -> void:
	var inspected := _detail("new-blade", ["main_hand", "off_hand"], {"fire_damage|1": 0.20})
	var leader: Array[Dictionary] = [
		{"slot_id": "main_hand", "slot": 6, "instance_id": "main-blade"},
		{"slot_id": "off_hand", "slot": 7, "instance_id": "off-blade"},
	]
	var candidates: Array = resolver.call("resolve", inspected, leader, {
		"main-blade": _detail("main-blade", ["main_hand"], {"fire_damage|1": 0.10}),
		"off-blade": _detail("off-blade", ["off_hand"], {"fire_damage|1": 0.25}),
	})
	TestAssertions.equal(candidates.size(), 2, "both valid one-hand replacements compare", failures)
	if candidates.size() == 2:
		TestAssertions.truthy(String(candidates[0]["delta_lines"][0]["text"]).contains("10% higher"), "higher multiplicative raw roll uses percentage points", failures)
		TestAssertions.truthy(String(candidates[1]["delta_lines"][0]["text"]).contains("5% lower"), "lower multiplicative raw roll is readable", failures)


func _test_empty_and_self_slots_are_skipped(resolver: Script, failures: Array[String]) -> void:
	var inspected := _detail("equipped-ring", ["ring_left", "ring_right"], {})
	var leader: Array[Dictionary] = [
		{"slot_id": "ring_left", "slot": 8, "instance_id": "equipped-ring"},
		{"slot_id": "ring_right", "slot": 9, "instance_id": ""},
		{"slot_id": "helmet", "slot": 0, "instance_id": "helmet"},
	]
	var candidates: Array = resolver.call("resolve", inspected, leader, {"equipped-ring": inspected, "helmet": _detail("helmet", ["helmet"], {})})
	TestAssertions.equal(candidates, [], "self, empty, and incompatible slots create no candidates", failures)


func _test_projected_rows_replace_raw_fallback(resolver: Script, failures: Array[String]) -> void:
	var supports_projection := false
	for method: Dictionary in resolver.get_script_method_list():
		if String(method.get("name", "")) == "resolve" and int((method.get("args", []) as Array).size()) >= 4:
			supports_projection = true
	TestAssertions.truthy(supports_projection, "resolver accepts projected rows by slot", failures)
	if not supports_projection:
		return
	var inspected := _detail("new-ring", ["ring_left", "ring_right"], {"constitution|0": 8.0})
	var leader: Array[Dictionary] = [
		{"slot_id": "ring_left", "slot": 8, "instance_id": "left-ring"},
		{"slot_id": "ring_right", "slot": 9, "instance_id": "right-ring"},
	]
	var records := {
		"left-ring": _detail("left-ring", ["ring_left", "ring_right"], {"constitution|0": 5.0}),
		"right-ring": _detail("right-ring", ["ring_left", "ring_right"], {"constitution|0": 6.0}),
	}
	var projected := {
		"ring_left": [{"stat_id": "max_health", "delta": 9.0, "direction": 1, "text": "▲ +9.0 Maximum Health — improved", "accessible_text": "Maximum Health improved by 9.0"}],
		"ring_right": [],
	}
	var candidates: Array = resolver.call("resolve", inspected, leader, records, projected)
	TestAssertions.equal(candidates[0]["delta_lines"], projected["ring_left"], "projected final-stat rows replace raw-roll deltas", failures)
	TestAssertions.equal(candidates[1]["delta_lines"], [], "an explicit empty projection does not fall back to raw rolls", failures)
	var fallback: Array = resolver.call("resolve", inspected, leader, records)
	TestAssertions.equal(fallback[0]["delta_lines"][0]["stat_id"], "constitution", "raw-roll deltas remain when no projection exists", failures)

func _test_raw_fallback_operation_matrix_is_neutral_and_accessible(resolver: Script, failures: Array[String]) -> void:
	var operation_names := {
		StatModifier.Operation.FLAT: "flat",
		StatModifier.Operation.INCREASED: "increased",
		StatModifier.Operation.REDUCED: "reduced",
		StatModifier.Operation.MORE: "more",
		StatModifier.Operation.LESS: "less",
	}
	for operation: int in operation_names:
		for raw_direction: int in [-1, 1]:
			var lower := 5.0 if operation == StatModifier.Operation.FLAT else 0.05
			var higher := 8.0 if operation == StatModifier.Operation.FLAT else 0.08
			var inspected_value := higher if raw_direction > 0 else lower
			var equipped_value := lower if raw_direction > 0 else higher
			var key := "damage|%d" % operation
			var inspected := _detail("new", ["helmet"], {key: inspected_value})
			var equipped := _detail("old", ["helmet"], {key: equipped_value})
			var leader: Array[Dictionary] = [{"slot_id": "helmet", "instance_id": "old"}]
			var rows: Array = resolver.call("resolve", inspected, leader, {"old": equipped})
			var line := rows[0]["delta_lines"][0] as Dictionary
			var direction_word := "higher" if raw_direction > 0 else "lower"
			TestAssertions.equal(line.get("direction"), 0, "%s %s fallback is benefit-neutral" % [operation_names[operation], direction_word], failures)
			TestAssertions.equal(line.get("raw_direction"), raw_direction, "%s %s fallback retains raw numeric direction" % [operation_names[operation], direction_word], failures)
			TestAssertions.truthy(String(line.get("text", "")).contains("raw %s roll" % operation_names[operation]) and String(line.get("text", "")).contains(direction_word), "%s %s fallback names raw operation and direction" % [operation_names[operation], direction_word], failures)
			var accessible := String(line.get("accessible_text", "")).to_lower()
			TestAssertions.truthy(direction_word in accessible and "benefit unknown" in accessible and "neutral" in accessible, "%s %s fallback exposes accessible neutral meaning" % [operation_names[operation], direction_word], failures)


func _test_results_are_defensive(resolver: Script, failures: Array[String]) -> void:
	var equipped := _detail("old-ring", ["ring_left", "ring_right"], {"constitution|0": 5.0})
	var records := {"old-ring": equipped}
	var leader: Array[Dictionary] = [
		{"slot_id": "ring_left", "slot": 8, "instance_id": "old-ring"},
	]
	var candidates: Array = resolver.call("resolve", _detail("new-ring", ["ring_left", "ring_right"], {"constitution|0": 7.0}), leader, records)
	(candidates[0]["item"] as Dictionary)["name"] = "Escaped"
	TestAssertions.equal(records["old-ring"]["name"], "old-ring", "candidate item is a defensive copy", failures)


func _detail(instance_id: String, compatible_slots: Array[String], totals: Dictionary) -> Dictionary:
	return {
		"instance_id": instance_id,
		"name": instance_id,
		"compatible_slot_ids": compatible_slots,
		"modifier_totals": totals,
	}
