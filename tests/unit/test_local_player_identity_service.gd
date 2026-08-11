extends RefCounted

const PALETTE_PATH := "res://scripts/profile/player_color_palette.gd"
const ASSIGNMENT_PATH := "res://scripts/run/local_player_identity_assignment.gd"
const SERVICE_PATH := "res://scripts/run/local_player_identity_service.gd"


func run() -> Array[String]:
	var failures: Array[String] = []
	var required_paths := [PALETTE_PATH, ASSIGNMENT_PATH, SERVICE_PATH]
	for path: String in required_paths:
		TestAssertions.truthy(ResourceLoader.exists(path), "%s exists" % path.get_file(), failures)
	if not required_paths.all(func(path: String) -> bool: return ResourceLoader.exists(path)):
		return failures
	_test_palette_contract_and_defensive_entries(failures)
	_test_stable_identity_assignment_and_defensive_output(failures)
	_test_duplicate_active_preference_is_rejected_deterministically(failures)
	return failures


func _test_palette_contract_and_defensive_entries(failures: Array[String]) -> void:
	var palette := load(PALETTE_PATH) as Script
	var first := palette.call("entries") as Array
	var ids: Array[StringName] = []
	for entry: Dictionary in first:
		ids.append(StringName(entry.get("id", &"")))
	TestAssertions.equal(
		ids,
		[&"red", &"blue", &"yellow", &"green", &"purple", &"orange", &"cyan", &"white"],
		"palette exposes the fixed color order",
		failures,
	)
	TestAssertions.equal(StringName(palette.get("DEFAULT_ID")), &"red", "red is the default player color", failures)
	TestAssertions.truthy(first.all(func(entry: Dictionary) -> bool:
		return entry.get("id") is StringName and entry.get("color") is Color
	), "palette entries retain runtime StringName ids and Color values", failures)
	(first[0] as Dictionary)["id"] = &"mutated"
	(first[0] as Dictionary)["color"] = Color.BLACK
	first.append({"id": &"extra"})
	var second := palette.call("entries") as Array
	TestAssertions.equal(second.size(), 8, "palette entry array is defensively copied", failures)
	TestAssertions.equal((second[0] as Dictionary)["id"], &"red", "palette entry dictionaries are defensively copied", failures)
	TestAssertions.equal((second[0] as Dictionary)["color"], Color("e45454"), "palette colors cannot be mutated through outward data", failures)


func _test_stable_identity_assignment_and_defensive_output(failures: Array[String]) -> void:
	var service: RefCounted = (load(SERVICE_PATH) as Script).new() as RefCounted
	var contexts: Array = [
		_context(&"player_3", 2, &"yellow", "profile-identity3"),
		_context(&"player_1", 0, &"red", "profile-identity1"),
		_context(&"player_4", 3, &"green", "profile-identity4"),
		_context(&"player_2", 1, &"blue", "profile-identity2"),
	]
	var assigned: Variant = service.call("assign", contexts)
	TestAssertions.truthy(bool(assigned.call("ok")), "unique active preferences assign", failures)
	var identities := assigned.call("identities") as Dictionary
	for player_number: int in range(1, 5):
		var run_player_id := StringName("player_%d" % player_number)
		var identity := identities.get(run_player_id, {}) as Dictionary
		TestAssertions.equal(identity.get("player_number", -1), player_number, "P%d numbering follows player_slot_index" % player_number, failures)
		TestAssertions.truthy(identity.get("color_id") is StringName, "P%d color id remains a StringName" % player_number, failures)
		TestAssertions.truthy(identity.get("color") is Color, "P%d color remains a Color" % player_number, failures)
	TestAssertions.equal((identities[&"player_2"] as Dictionary)["color_id"], &"blue", "assignment uses the profile preference", failures)
	(identities[&"player_1"] as Dictionary)["player_number"] = 99
	identities.erase(&"player_2")
	var second := assigned.call("identities") as Dictionary
	TestAssertions.equal((second[&"player_1"] as Dictionary)["player_number"], 1, "assignment dictionaries are defensively copied", failures)
	TestAssertions.truthy(second.has(&"player_2"), "assignment map is defensively copied", failures)


func _test_duplicate_active_preference_is_rejected_deterministically(failures: Array[String]) -> void:
	var service: RefCounted = (load(SERVICE_PATH) as Script).new() as RefCounted
	var assigned: Variant = service.call("assign", [
		_context(&"player_2", 1, &"red", "profile-identity2"),
		_context(&"player_1", 0, &"red", "profile-identity1"),
	])
	TestAssertions.truthy(not bool(assigned.call("ok")), "duplicate active preference is rejected", failures)
	var error := String(assigned.get("error"))
	TestAssertions.truthy(error.contains("player_2"), "error identifies the joining player", failures)
	TestAssertions.truthy(error.contains("profile-identity2"), "error identifies the joining profile", failures)
	TestAssertions.truthy(error.contains("player_slot_index=1"), "error identifies the joining slot", failures)
	var repeated: Variant = service.call("assign", [
		_context(&"player_2", 1, &"red", "profile-identity2"),
		_context(&"player_1", 0, &"red", "profile-identity1"),
	])
	TestAssertions.equal(String(repeated.get("error")), error, "duplicate rejection is stable", failures)


func _context(run_player_id: StringName, slot: int, color_id: StringName, profile_id: String) -> PlayerRunContext:
	var profile := ProfileState.new_profile(profile_id, "Profile %d" % (slot + 1), 1000 + slot)
	profile.set("preferred_player_color_id", color_id)
	var context := PlayerRunContext.new()
	context.set("_run_player_id", run_player_id)
	context.set("_player_slot_index", slot)
	context.set("_profile_id", profile.profile_id)
	context.set("_profile_snapshot", profile.copy())
	return context
