extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_class_projection_owns_nested_values(failures)
	_test_lobby_projection_owns_its_values_and_seats(failures)
	return failures

func _test_class_projection_owns_nested_values(failures: Array[String]) -> void:
	var traits := ["Martial", "Vanguard"]
	var compatibility_copy := {"summary": "Ready", "items": [{"slot": "main_hand"}]}
	var projection := RunSetupClassProjection.create(
		&"fighter", "Fighter", "Frontline", Color("cc6633"), traits, "Fighter Cleave",
		RunSetupClassProjection.Compatibility.COMPATIBLE, compatibility_copy,
	)
	traits[0] = "Changed source"
	compatibility_copy["summary"] = "Changed source"
	(compatibility_copy["items"] as Array)[0]["slot"] = "changed_source"
	var returned_traits := projection.trait_display_names
	var returned_copy := projection.compatibility_copy
	returned_traits[0] = "Changed returned"
	returned_copy["summary"] = "Changed returned"
	(returned_copy["items"] as Array)[0]["slot"] = "changed_returned"
	TestAssertions.equal(projection.trait_display_names, ["Martial", "Vanguard"], "class projection owns trait display names", failures)
	TestAssertions.equal(projection.compatibility_copy, {"summary": "Ready", "items": [{"slot": "main_hand"}]}, "class projection owns nested compatibility copy", failures)
	TestAssertions.equal(projection.starting_action_label, "Fighter Cleave", "class projection carries a player-facing starting action label", failures)

func _test_lobby_projection_owns_its_values_and_seats(failures: Array[String]) -> void:
	var seats: Array[RunSetupSeatProjection] = [
		RunSetupSeatProjection.active(1, "P1"),
		RunSetupSeatProjection.coming_soon(2),
		RunSetupSeatProjection.coming_soon(3),
		RunSetupSeatProjection.coming_soon(4),
	]
	var classes: Array[RunSetupClassProjection] = [
		RunSetupClassProjection.create(&"fighter", "Fighter", "Frontline", Color.WHITE, ["Martial"], "Fighter Cleave", RunSetupClassProjection.Compatibility.COMPATIBLE, {"summary": "Ready"}),
	]
	var projection := RunSetupLobbyProjection.create(
		seats, classes, &"fighter", &"mage", RunSetupLobbyProjection.State.READY, "Fighter is ready to begin.",
	)
	seats[0] = RunSetupSeatProjection.coming_soon(1)
	classes[0].compatibility_copy["summary"] = "external mutation attempt"
	var returned_seats := projection.seats
	var returned_classes := projection.classes
	returned_seats[0].label = "Changed returned"
	returned_classes[0].compatibility_copy["summary"] = "Changed returned"
	TestAssertions.equal(projection.seats.size(), 4, "lobby projection contains exactly four seats", failures)
	TestAssertions.equal(projection.seats[0].state, RunSetupSeatProjection.State.ACTIVE, "P1 is the only active seat", failures)
	TestAssertions.truthy(projection.seats[0].focusable, "P1 is focusable", failures)
	for index: int in range(1, projection.seats.size()):
		TestAssertions.equal(projection.seats[index].state, RunSetupSeatProjection.State.COMING_SOON, "seat %d is honestly coming soon" % (index + 1), failures)
		TestAssertions.truthy(not projection.seats[index].focusable, "seat %d is not focusable" % (index + 1), failures)
	TestAssertions.equal(projection.selected_class_id, &"fighter", "selection survives an independent preview", failures)
	TestAssertions.equal(projection.previewed_class_id, &"mage", "preview remains independent from selection", failures)
	TestAssertions.equal(projection.classes[0].compatibility_copy.get("summary"), "Ready", "lobby projection deep-copies class values", failures)
