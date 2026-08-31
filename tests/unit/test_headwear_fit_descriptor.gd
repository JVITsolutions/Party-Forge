extends RefCounted

const DESCRIPTOR_SCRIPT_PATH := "res://scripts/presentation/headwear_fit_descriptor.gd"


func run() -> Array[String]:
	var failures: Array[String] = []
	var script := load(DESCRIPTOR_SCRIPT_PATH) as Script
	TestAssertions.truthy(script != null, "headwear fit descriptor loads", failures)
	if script == null:
		return failures
	var constants := script.get_script_constant_map()
	TestAssertions.equal(constants.get("CATEGORIES"), [&"full_helmet", &"open_helmet", &"circlet"], "headwear categories are closed", failures)

	var full_helmet: Resource = script.new()
	full_helmet.set(&"category", &"full_helmet")
	full_helmet.set(&"compatible_envelope_ids", Array([&"standard_masculine"], TYPE_STRING_NAME, "", null))
	full_helmet.set(&"hide_head_region_ids", Array([&"scalp", &"hair", &"ears"], TYPE_STRING_NAME, "", null))
	TestAssertions.equal(full_helmet.call(&"validate"), PackedStringArray(), "full helmet may hide ordinary hair without a safe variant", failures)

	var open_helmet: Resource = script.new()
	open_helmet.set(&"category", &"open_helmet")
	open_helmet.set(&"compatible_envelope_ids", Array([&"standard_masculine"], TYPE_STRING_NAME, "", null))
	open_helmet.set(&"hide_head_region_ids", Array([&"hair"], TYPE_STRING_NAME, "", null))
	TestAssertions.truthy(_contains(open_helmet.call(&"validate"), "helmet-safe hair id"), "open helmet requires deterministic safe hair", failures)
	open_helmet.set(&"helmet_safe_hair_id", &"paladin_short_hair_helmet")
	TestAssertions.equal(open_helmet.call(&"validate"), PackedStringArray(), "open helmet accepts safe hair", failures)

	var circlet: Resource = script.new()
	circlet.set(&"category", &"circlet")
	circlet.set(&"compatible_envelope_ids", Array([&"standard_feminine"], TYPE_STRING_NAME, "", null))
	TestAssertions.equal(circlet.call(&"validate"), PackedStringArray(), "circlet may preserve ordinary hair", failures)

	for case: Dictionary in [
		{"category": &"unknown", "envelopes": Array([&"standard"], TYPE_STRING_NAME, "", null), "regions": Array([], TYPE_STRING_NAME, "", null), "fragment": "category", "label": "unknown category"},
		{"category": &"full_helmet", "envelopes": Array([], TYPE_STRING_NAME, "", null), "regions": Array([], TYPE_STRING_NAME, "", null), "fragment": "envelopes are empty", "label": "empty envelopes"},
		{"category": &"full_helmet", "envelopes": Array([&"standard", &"standard"], TYPE_STRING_NAME, "", null), "regions": Array([], TYPE_STRING_NAME, "", null), "fragment": "duplicate envelope", "label": "duplicate envelopes"},
		{"category": &"full_helmet", "envelopes": Array([&"standard"], TYPE_STRING_NAME, "", null), "regions": Array([&"hair", &"hair"], TYPE_STRING_NAME, "", null), "fragment": "duplicate hidden region", "label": "duplicate hidden regions"},
	]:
		var invalid: Resource = script.new()
		invalid.set(&"category", case["category"])
		invalid.set(&"compatible_envelope_ids", case["envelopes"])
		invalid.set(&"hide_head_region_ids", case["regions"])
		TestAssertions.truthy(_contains(invalid.call(&"validate"), case["fragment"]), case["label"], failures)
	return failures


func _contains(errors: PackedStringArray, fragment: String) -> bool:
	for error: String in errors:
		if fragment in error:
			return true
	return false
