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
	var source_traits: Array[String] = ["Martial"]
	var source_compatibility := {"summary": "Ready", "nested": {"slot": "main_hand"}}
	var source_seat := RunSetupSeatProjection.active(1, "P1")
	var source_class := RunSetupClassProjection.create(&"fighter", "Fighter", "Frontline", Color.WHITE, source_traits, "Fighter Cleave", RunSetupClassProjection.Compatibility.COMPATIBLE, source_compatibility)
	var seats: Array[RunSetupSeatProjection] = [
		source_seat,
		RunSetupSeatProjection.coming_soon(2),
		RunSetupSeatProjection.coming_soon(3),
		RunSetupSeatProjection.coming_soon(4),
	]
	var classes: Array[RunSetupClassProjection] = [
		source_class,
	]
	var projection := RunSetupLobbyProjection.create(
		seats, classes, &"fighter", &"mage", RunSetupLobbyProjection.State.READY, "Fighter is ready to begin.",
	)
	source_seat.label = "Changed source seat"
	source_seat.state = RunSetupSeatProjection.State.DISCONNECTED
	source_seat.focusable = false
	source_class.display_name = "Changed source class"
	source_class.starting_action_label = "Changed source action"
	source_class.compatibility = RunSetupClassProjection.Compatibility.UNAVAILABLE
	source_class._trait_display_names[0] = "Changed source trait"
	source_class._compatibility_copy["summary"] = "Changed source summary"
	(source_class._compatibility_copy["nested"] as Dictionary)["slot"] = "changed_source"
	source_traits[0] = "Changed construction input"
	source_compatibility["summary"] = "Changed construction input"
	seats[0] = RunSetupSeatProjection.coming_soon(1)
	seats.remove_at(1)
	classes[0] = RunSetupClassProjection.create(&"mage", "Mage", "Backline", Color.BLUE, ["Arcane"], "Mage Bolt", RunSetupClassProjection.Compatibility.UNKNOWN, {"summary": "Changed"})
	classes.remove_at(0)
	var returned_seats := projection.seats
	var returned_classes := projection.classes
	var independent_seats := projection.seats
	var independent_classes := projection.classes
	returned_seats[0].label = "Changed returned seat"
	returned_seats[0].focusable = false
	returned_seats[0] = RunSetupSeatProjection.coming_soon(1)
	returned_seats.remove_at(1)
	returned_classes[0].display_name = "Changed returned class"
	returned_classes[0].starting_action_label = "Changed returned action"
	returned_classes[0].compatibility = RunSetupClassProjection.Compatibility.UNAVAILABLE
	var returned_traits := returned_classes[0].trait_display_names
	var returned_compatibility := returned_classes[0].compatibility_copy
	returned_traits[0] = "Changed returned trait"
	returned_compatibility["summary"] = "Changed returned summary"
	returned_classes[0] = RunSetupClassProjection.create(&"mage", "Mage", "Backline", Color.BLUE, ["Arcane"], "Mage Bolt", RunSetupClassProjection.Compatibility.UNKNOWN, {"summary": "Changed"})
	returned_classes.remove_at(0)
	TestAssertions.equal(projection.seats.size(), 4, "lobby projection contains exactly four seats", failures)
	TestAssertions.equal(projection.seats[0].state, RunSetupSeatProjection.State.ACTIVE, "P1 is the only active seat", failures)
	TestAssertions.truthy(projection.seats[0].focusable, "P1 is focusable", failures)
	for index: int in range(1, projection.seats.size()):
		TestAssertions.equal(projection.seats[index].state, RunSetupSeatProjection.State.COMING_SOON, "seat %d is honestly coming soon" % (index + 1), failures)
		TestAssertions.truthy(not projection.seats[index].focusable, "seat %d is not focusable" % (index + 1), failures)
	TestAssertions.equal(projection.selected_class_id, &"fighter", "selection survives an independent preview", failures)
	TestAssertions.equal(projection.previewed_class_id, &"mage", "preview remains independent from selection", failures)
	TestAssertions.equal(projection.classes[0].display_name, "Fighter", "lobby projection owns source class scalar values", failures)
	TestAssertions.equal(projection.classes[0].starting_action_label, "Fighter Cleave", "lobby projection owns source action values", failures)
	TestAssertions.equal(projection.classes[0].compatibility, RunSetupClassProjection.Compatibility.COMPATIBLE, "lobby projection owns source compatibility state", failures)
	TestAssertions.equal(projection.classes[0].trait_display_names, ["Martial"], "lobby projection owns source trait values", failures)
	TestAssertions.equal(projection.classes[0].compatibility_copy, {"summary": "Ready", "nested": {"slot": "main_hand"}}, "lobby projection deep-copies source compatibility dictionaries", failures)
	TestAssertions.equal(independent_seats.size(), 4, "structurally mutating a returned seat array leaves other copies unchanged", failures)
	TestAssertions.equal(independent_seats[0].label, "P1", "mutating a returned seat scalar leaves other copies unchanged", failures)
	TestAssertions.truthy(independent_seats[0].focusable, "mutating a returned seat flag leaves other copies unchanged", failures)
	TestAssertions.equal(independent_classes.size(), 1, "structurally mutating a returned class array leaves other copies unchanged", failures)
	TestAssertions.equal(independent_classes[0].display_name, "Fighter", "mutating a returned class scalar leaves other copies unchanged", failures)
	TestAssertions.equal(independent_classes[0].starting_action_label, "Fighter Cleave", "mutating a returned class action leaves other copies unchanged", failures)
	TestAssertions.equal(independent_classes[0].compatibility, RunSetupClassProjection.Compatibility.COMPATIBLE, "mutating a returned class state leaves other copies unchanged", failures)
	TestAssertions.equal(independent_classes[0].trait_display_names, ["Martial"], "mutating every returned trait array leaves other copies unchanged", failures)
	TestAssertions.equal(independent_classes[0].compatibility_copy, {"summary": "Ready", "nested": {"slot": "main_hand"}}, "mutating every returned compatibility dictionary leaves other copies unchanged", failures)
