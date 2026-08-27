extends RefCounted

const EVALUATOR_PATH := "res://scripts/world/access/city_access_evaluator.gd"

const HIDDEN := 0
const LOCKED := 1
const AVAILABLE := 2


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_tutorial_matrix_and_profile_immutability(failures)
	_test_repeated_and_reshuffled_profile_arrays(failures)
	_test_every_condition_kind_and_invalid_inputs(failures)
	_test_invalid_public_inputs_fail_closed(failures)
	return failures


func _test_tutorial_matrix_and_profile_immutability(failures: Array[String]) -> void:
	TestAssertions.truthy(FileAccess.file_exists(EVALUATOR_PATH), "City access evaluator script exists", failures)
	if not FileAccess.file_exists(EVALUATOR_PATH):
		return
	var snapshot: Variant = _fixture_snapshot(failures)
	if snapshot == null:
		return
	var not_started := _profile(ProfileState.PrologueState.NOT_STARTED)
	_assert_matrix(snapshot, not_started, {
		&"city.apothecary": [AVAILABLE, &"visible", &"city.apothecary.interior"],
		&"city.coliseum_road": [AVAILABLE, &"visible", &"city.coliseum_road.route"],
		&"city.scholars_archive": [HIDDEN, &"visibility_conditions_failed", &""],
		&"city.inn": [LOCKED, &"availability_conditions_failed", &""],
		&"city.merchant": [LOCKED, &"availability_conditions_failed", &""],
		&"city.warehouse": [LOCKED, &"availability_conditions_failed", &""],
		&"city.smithy": [LOCKED, &"availability_conditions_failed", &""],
	}, "not started", failures)
	var in_progress := _profile(ProfileState.PrologueState.IN_PROGRESS)
	_assert_matrix(snapshot, in_progress, {
		&"city.apothecary": [AVAILABLE, &"visible", &"city.apothecary.interior"],
		&"city.coliseum_road": [AVAILABLE, &"visible", &"city.coliseum_road.route"],
		&"city.scholars_archive": [HIDDEN, &"visibility_conditions_failed", &""],
		&"city.inn": [LOCKED, &"availability_conditions_failed", &""],
		&"city.merchant": [LOCKED, &"availability_conditions_failed", &""],
		&"city.warehouse": [LOCKED, &"availability_conditions_failed", &""],
		&"city.smithy": [LOCKED, &"availability_conditions_failed", &""],
	}, "in progress", failures)
	var completed := _profile(ProfileState.PrologueState.COMPLETED)
	_assert_matrix(snapshot, completed, {
		&"city.apothecary": [AVAILABLE, &"visible", &"city.apothecary.interior"],
		&"city.coliseum_road": [AVAILABLE, &"visible", &"city.coliseum_road.route"],
		&"city.scholars_archive": [AVAILABLE, &"visible", &"city.scholars_archive.interior"],
		&"city.inn": [LOCKED, &"availability_conditions_failed", &""],
		&"city.merchant": [LOCKED, &"availability_conditions_failed", &""],
		&"city.warehouse": [LOCKED, &"availability_conditions_failed", &""],
		&"city.smithy": [LOCKED, &"availability_conditions_failed", &""],
	}, "completed", failures)
	for unlock: String in [&"service:hero_registry", &"service:city_vendors", &"stash", &"service:equipment_upgrading"]:
		var unlocked := _profile(ProfileState.PrologueState.NOT_STARTED, [unlock])
		for location_id: StringName in _gated_location_ids():
			var expected_state: int = AVAILABLE if _unlock_for_location(location_id) == unlock else LOCKED
			var expected_destination: StringName = _destination_for_location(location_id) if expected_state == AVAILABLE else &""
			_assert_projection(snapshot, unlocked, location_id, expected_state, &"visible" if expected_state == AVAILABLE else &"availability_conditions_failed", expected_destination, "%s exposes only its intended building" % unlock, failures)
	var unknown_unlock := _profile(ProfileState.PrologueState.NOT_STARTED, [&"unknown.unlock"])
	for location_id: StringName in _gated_location_ids():
		_assert_projection(snapshot, unknown_unlock, location_id, LOCKED, &"availability_conditions_failed", &"", "unknown unlock exposes no building", failures)


func _test_repeated_and_reshuffled_profile_arrays(failures: Array[String]) -> void:
	if not FileAccess.file_exists(EVALUATOR_PATH):
		return
	var snapshot: Variant = _fixture_snapshot(failures)
	if snapshot == null:
		return
	var ordered := _profile(ProfileState.PrologueState.COMPLETED, [&"service:hero_registry", &"service:city_vendors", &"stash", &"service:equipment_upgrading"])
	ordered.discovered_buildings = [&"city.library", &"city.market"]
	ordered.discovered_trees = [&"tree.city", &"tree.class"]
	var reshuffled := _profile(ProfileState.PrologueState.COMPLETED, [&"stash", &"service:hero_registry", &"stash", &"service:equipment_upgrading", &"service:city_vendors", &"service:hero_registry"])
	reshuffled.discovered_buildings = [&"city.market", &"city.library", &"city.market"]
	reshuffled.discovered_trees = [&"tree.class", &"tree.city", &"tree.city"]
	for location_id: StringName in _fixture_location_ids():
		var ordered_projection: Variant = _evaluate(snapshot, ordered, location_id)
		var reshuffled_projection: Variant = _evaluate(snapshot, reshuffled, location_id)
		TestAssertions.equal(_projection_values(reshuffled_projection), _projection_values(ordered_projection), "repeated and reshuffled arrays preserve %s projection" % location_id, failures)
	_assert_profile_unchanged(snapshot, ordered, "ordered profile", failures)
	_assert_profile_unchanged(snapshot, reshuffled, "reshuffled profile", failures)


func _test_every_condition_kind_and_invalid_inputs(failures: Array[String]) -> void:
	if not FileAccess.file_exists(EVALUATOR_PATH):
		return
	var snapshot: Variant = _snapshot_from_document({
		"format": "party-forge-access-snapshot",
		"version": 1,
		"source": _source(),
		"locations": [
			{"id": "city.all_conditions", "destinationId": "city.all_conditions.interior", "visibleWhen": [{"kind": "discovered_building", "value": "city.library"}], "availableWhen": [{"kind": "discovered_tree", "value": "tree.city"}, {"kind": "permanent_unlock", "value": "service:library"}, {"kind": "prologue_state", "value": "completed"}]},
		],
	}, failures)
	if snapshot == null:
		return
	var profile := _profile(ProfileState.PrologueState.COMPLETED, [&"service:library"])
	profile.discovered_buildings = [&"city.library"]
	profile.discovered_trees = [&"tree.city"]
	_assert_projection(snapshot, profile, &"city.all_conditions", AVAILABLE, &"visible", &"city.all_conditions.interior", "all condition kinds pass together", failures)
	profile.discovered_trees = []
	_assert_projection(snapshot, profile, &"city.all_conditions", LOCKED, &"availability_conditions_failed", &"", "all-of availability fails when a required tree is absent", failures)
	_assert_projection(snapshot, profile, &"city.unknown", HIDDEN, &"unknown_location", &"", "unknown location fails closed", failures)
	_assert_projection(null, profile, &"city.all_conditions", HIDDEN, &"invalid_input", &"", "null snapshot fails closed", failures)
	_assert_projection(snapshot, null, &"city.all_conditions", HIDDEN, &"invalid_input", &"", "null profile fails closed", failures)
	_assert_projection(snapshot, profile, &"", HIDDEN, &"invalid_input", &"", "empty location ID fails closed", failures)
	_assert_profile_unchanged(snapshot, profile, "condition-kind profile", failures)


func _test_invalid_public_inputs_fail_closed(failures: Array[String]) -> void:
	if not FileAccess.file_exists(EVALUATOR_PATH):
		return
	var snapshot: Variant = _fixture_snapshot(failures)
	if snapshot == null:
		return
	var invalid_prologue := _profile(99)
	_assert_projection(snapshot, invalid_prologue, &"city.apothecary", HIDDEN, &"invalid_input", &"", "out-of-range profile prologue fails closed before always conditions", failures)
	for location_id: Variant in [null, 42, "city.apothecary", &""]:
		_assert_dynamic_projection(snapshot, _profile(ProfileState.PrologueState.NOT_STARTED), location_id, HIDDEN, &"invalid_input", &"", "dynamic invalid location ID fails closed", failures)


func _assert_matrix(snapshot: Variant, profile: ProfileState, expected: Dictionary, label: String, failures: Array[String]) -> void:
	for location_id: StringName in _fixture_location_ids():
		var row: Array = expected[location_id]
		_assert_projection(snapshot, profile, location_id, row[0], row[1], row[2], "%s %s" % [label, location_id], failures)
	_assert_profile_unchanged(snapshot, profile, "%s matrix" % label, failures)


func _assert_projection(snapshot: Variant, profile: Variant, location_id: StringName, expected_state: int, expected_reason: StringName, expected_destination: StringName, label: String, failures: Array[String]) -> void:
	var projection: Variant = _evaluate(snapshot, profile, location_id)
	if projection == null:
		failures.append("%s returns a projection" % label)
		return
	TestAssertions.equal(projection.state, expected_state, "%s state" % label, failures)
	TestAssertions.equal(projection.reason_id, expected_reason, "%s reason ID" % label, failures)
	TestAssertions.equal(projection.destination_id, expected_destination, "%s destination" % label, failures)
	TestAssertions.equal(projection.location_id, location_id, "%s location ID" % label, failures)
	var before_projection := _projection_values(projection)
	projection.location_id = &"city.mutated"
	projection.state = HIDDEN
	projection.reason_id = &"mutated"
	projection.destination_id = &"city.mutated.destination"
	projection.diagnostic = "mutated"
	TestAssertions.equal(_projection_values(projection), before_projection, "%s projection is read only" % label, failures)
	if expected_state != AVAILABLE:
		TestAssertions.equal(projection.destination_id, &"", "%s does not expose a destination", failures)
	if expected_reason in [&"unknown_location", &"invalid_input"]:
		TestAssertions.truthy(not String(projection.diagnostic).is_empty(), "%s includes a diagnostic", failures)


func _assert_dynamic_projection(snapshot: Variant, profile: Variant, location_id: Variant, expected_state: int, expected_reason: StringName, expected_destination: StringName, label: String, failures: Array[String]) -> void:
	var projection: Variant = _evaluate(snapshot, profile, location_id)
	if projection == null:
		failures.append("%s returns a projection" % label)
		return
	TestAssertions.equal(projection.state, expected_state, "%s state" % label, failures)
	TestAssertions.equal(projection.reason_id, expected_reason, "%s reason ID" % label, failures)
	TestAssertions.equal(projection.destination_id, expected_destination, "%s destination" % label, failures)


func _assert_profile_unchanged(snapshot: Variant, profile: ProfileState, label: String, failures: Array[String]) -> void:
	var before_dictionary := profile.to_dictionary()
	var before_bytes := ProfileCodec.encode(profile).to_utf8_buffer()
	var before_snapshot := _snapshot_values(snapshot)
	var before_snapshot_bytes := CityAccessSnapshotCodec.encode_document(_snapshot_document(snapshot))
	for location_id: StringName in _fixture_location_ids():
		_evaluate(snapshot, profile, location_id)
		_evaluate(snapshot, profile, location_id)
	TestAssertions.equal(profile.to_dictionary(), before_dictionary, "%s evaluation leaves profile dictionary unchanged" % label, failures)
	TestAssertions.equal(ProfileCodec.encode(profile).to_utf8_buffer(), before_bytes, "%s evaluation leaves encoded profile bytes unchanged" % label, failures)
	TestAssertions.equal(_snapshot_values(snapshot), before_snapshot, "%s evaluation leaves snapshot unchanged" % label, failures)
	TestAssertions.equal(CityAccessSnapshotCodec.encode_document(_snapshot_document(snapshot)), before_snapshot_bytes, "%s evaluation leaves canonical snapshot bytes unchanged" % label, failures)


func _evaluate(snapshot: Variant, profile: Variant, location_id: Variant) -> Variant:
	var evaluator: Variant = load(EVALUATOR_PATH)
	return evaluator.call("evaluate", snapshot, profile, location_id) if evaluator != null else null


func _fixture_snapshot(failures: Array[String]) -> Variant:
	return _snapshot_from_document({
		"format": "party-forge-access-snapshot",
		"version": 1,
		"source": _source(),
		"locations": [
			{"id": "city.apothecary", "destinationId": "city.apothecary.interior", "visibleWhen": [{"kind": "always", "value": ""}], "availableWhen": [{"kind": "always", "value": ""}]},
			{"id": "city.coliseum_road", "destinationId": "city.coliseum_road.route", "visibleWhen": [{"kind": "always", "value": ""}], "availableWhen": [{"kind": "always", "value": ""}]},
			{"id": "city.scholars_archive", "destinationId": "city.scholars_archive.interior", "visibleWhen": [{"kind": "prologue_state", "value": "completed"}], "availableWhen": [{"kind": "prologue_state", "value": "completed"}]},
			{"id": "city.inn", "destinationId": "city.inn.interior", "visibleWhen": [{"kind": "always", "value": ""}], "availableWhen": [{"kind": "permanent_unlock", "value": "service:hero_registry"}]},
			{"id": "city.merchant", "destinationId": "city.merchant.interior", "visibleWhen": [{"kind": "always", "value": ""}], "availableWhen": [{"kind": "permanent_unlock", "value": "service:city_vendors"}]},
			{"id": "city.warehouse", "destinationId": "city.warehouse.interior", "visibleWhen": [{"kind": "always", "value": ""}], "availableWhen": [{"kind": "permanent_unlock", "value": "stash"}]},
			{"id": "city.smithy", "destinationId": "city.smithy.interior", "visibleWhen": [{"kind": "always", "value": ""}], "availableWhen": [{"kind": "permanent_unlock", "value": "service:equipment_upgrading"}]},
		],
	}, failures)


func _snapshot_from_document(document: Dictionary, failures: Array[String]) -> Variant:
	var result := CityAccessSnapshotLoader.load_bytes(JSON.stringify(document).to_utf8_buffer())
	TestAssertions.truthy(result.ok(), "evaluator fixture snapshot loads", failures)
	return result.snapshot if result.ok() else null


func _profile(prologue_state: int, unlocks: Array[String] = []) -> ProfileState:
	var profile := ProfileState.new_profile("city-access-evaluator-profile", "Evaluator", 1)
	profile.prologue_state = prologue_state
	profile.permanent_feature_unlocks = unlocks.duplicate()
	return profile


func _source() -> Dictionary:
	return {"adapter": "latticewright-runtime-v3-city-access", "format": "latticewright-progression", "formatVersion": 3, "sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"}


func _fixture_location_ids() -> Array[StringName]:
	return [&"city.apothecary", &"city.coliseum_road", &"city.scholars_archive", &"city.inn", &"city.merchant", &"city.warehouse", &"city.smithy"]


func _gated_location_ids() -> Array[StringName]:
	return [&"city.inn", &"city.merchant", &"city.warehouse", &"city.smithy"]


func _unlock_for_location(location_id: StringName) -> StringName:
	return {&"city.inn": &"service:hero_registry", &"city.merchant": &"service:city_vendors", &"city.warehouse": &"stash", &"city.smithy": &"service:equipment_upgrading"}[location_id]


func _destination_for_location(location_id: StringName) -> StringName:
	return {&"city.inn": &"city.inn.interior", &"city.merchant": &"city.merchant.interior", &"city.warehouse": &"city.warehouse.interior", &"city.smithy": &"city.smithy.interior"}[location_id]


func _projection_values(projection: Variant) -> Array:
	return [projection.location_id, projection.state, projection.reason_id, projection.destination_id, projection.diagnostic]


func _snapshot_values(snapshot: Variant) -> Array:
	var values: Array = []
	for location: CityAccessLocation in snapshot.locations:
		var visible: Array = []
		for condition: CityAccessCondition in location.visible_when:
			visible.append([condition.kind, condition.value])
		var available: Array = []
		for condition: CityAccessCondition in location.available_when:
			available.append([condition.kind, condition.value])
		values.append([location.id, location.destination_id, visible, available])
	return values


func _snapshot_document(snapshot: Variant) -> Dictionary:
	var locations: Array = []
	for location: CityAccessLocation in snapshot.locations:
		var visible: Array = []
		for condition: CityAccessCondition in location.visible_when:
			visible.append({"kind": String(condition.kind), "value": condition.value})
		var available: Array = []
		for condition: CityAccessCondition in location.available_when:
			available.append({"kind": String(condition.kind), "value": condition.value})
		locations.append({"id": String(location.id), "destinationId": String(location.destination_id), "visibleWhen": visible, "availableWhen": available})
	return {
		"format": "party-forge-access-snapshot",
		"version": 1,
		"source": {"adapter": String(snapshot.adapter), "format": String(snapshot.source_format), "formatVersion": snapshot.source_format_version, "sha256": snapshot.source_sha256},
		"locations": locations,
	}
