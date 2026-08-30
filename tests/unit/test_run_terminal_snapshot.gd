extends RefCounted

const PROFILE_ID := "profile-terminal-snapshot001"
const RUN_ID := &"run-terminal-snapshot-001"
const RUN_PLAYER_ID := &"terminal-snapshot-player"
const RUN_SEED := 8808
const LEADER_ID := 1
const EXPECTED_SNAPSHOT_FIELDS: Array[String] = [
	"schema_version", "outcome", "elapsed_seconds", "profile_id", "run_id",
	"run_seed", "run_player_id", "leader_member_id", "members", "resolution_source",
]
const EXPECTED_MEMBER_FIELDS: Array[String] = [
	"member_id", "display_name", "class_id", "class_name", "is_leader", "final_level",
]

func run() -> Array[String]:
	var failures: Array[String] = []
	var member_type := load("res://scripts/run/run_terminal_party_member_snapshot.gd") as Script
	var snapshot_type := load("res://scripts/run/run_terminal_snapshot.gd") as Script
	var result_type := load("res://scripts/run/run_terminal_snapshot_result.gd") as Script
	var builder_type := load("res://scripts/run/run_terminal_snapshot_builder.gd") as Script
	TestAssertions.truthy(member_type != null, "terminal member snapshot type exists", failures)
	TestAssertions.truthy(snapshot_type != null, "terminal snapshot type exists", failures)
	TestAssertions.truthy(result_type != null, "terminal snapshot result type exists", failures)
	TestAssertions.truthy(builder_type != null, "terminal snapshot builder type exists", failures)
	if member_type == null or snapshot_type == null or result_type == null or builder_type == null:
		return failures
	var outcomes := snapshot_type.get_script_constant_map().get("Outcome", {}) as Dictionary
	TestAssertions.equal(outcomes, {"VICTORY": 0, "DEFEAT": 1}, "terminal outcomes are stable and exact", failures)
	_test_member_value_object(member_type, failures)
	_test_capture_and_origin_isolation(builder_type, outcomes, failures)
	_test_twenty_four_members_and_nonfirst_leader(builder_type, outcomes, failures)
	_test_strict_codec(builder_type, snapshot_type, outcomes, failures)
	_test_invalid_capture_truth(builder_type, outcomes, failures)
	return failures

func _test_member_value_object(member_type: Script, failures: Array[String]) -> void:
	var member: Variant = member_type.call(&"create", 7, "Asha", &"fighter", "Fighter", true, 12)
	TestAssertions.truthy(member != null, "valid terminal member snapshot creates", failures)
	if member == null:
		return
	TestAssertions.equal(member.member_id, 7, "member ID is retained", failures)
	TestAssertions.equal(member.display_name, "Asha", "member display name is retained", failures)
	TestAssertions.equal(member.class_id, &"fighter", "member class ID is retained", failures)
	TestAssertions.equal(member.class_name, "Fighter", "member class name is retained", failures)
	TestAssertions.truthy(member.is_leader, "member leader state is retained", failures)
	TestAssertions.equal(member.final_level, 12, "member final level is retained", failures)
	var copied: Variant = member.call(&"copy")
	TestAssertions.truthy(copied != null and copied != member, "member copy has distinct identity", failures)
	TestAssertions.equal(copied.call(&"to_dictionary"), member.call(&"to_dictionary"), "member copy is structurally exact", failures)
	TestAssertions.equal((member.call(&"to_dictionary") as Dictionary).keys(), EXPECTED_MEMBER_FIELDS, "member dictionary has exact ordered fields", failures)
	var invalid_cases: Array[Array] = [
		[0, "Asha", &"fighter", "Fighter", true, 1],
		[1, "", &"fighter", "Fighter", true, 1],
		[1, "Asha", &"", "Fighter", true, 1],
		[1, "Asha", &"fighter", "", true, 1],
		[1, "Asha", &"fighter", "Fighter", true, 0],
	]
	for index: int in invalid_cases.size():
		var values := invalid_cases[index]
		TestAssertions.equal(member_type.callv(&"create", values), null, "invalid member values fail closed %d" % index, failures)

func _test_capture_and_origin_isolation(builder_type: Script, outcomes: Dictionary, failures: Array[String]) -> void:
	for outcome_name: String in ["VICTORY", "DEFEAT"]:
		var fixture := _fixture("capture_%s" % outcome_name.to_lower())
		var context := fixture.context as PlayerRunContext
		var party := fixture.party as PartyManager
		var builder: Variant = builder_type.new()
		var result: Variant = builder.call(&"capture", int(outcomes[outcome_name]), 125.8, context)
		TestAssertions.truthy(result.ok(), "%s terminal truth captures" % outcome_name.to_lower(), failures)
		if result.ok():
			var snapshot: Variant = result.snapshot
			TestAssertions.equal(snapshot.outcome, int(outcomes[outcome_name]), "%s outcome captures exactly" % outcome_name.to_lower(), failures)
			TestAssertions.equal(snapshot.elapsed_seconds, 125.8, "duration captures exactly", failures)
			TestAssertions.equal(snapshot.profile_id, PROFILE_ID, "profile identity captures", failures)
			TestAssertions.equal(snapshot.run_id, RUN_ID, "run identity captures", failures)
			TestAssertions.equal(snapshot.run_seed, RUN_SEED, "run seed captures", failures)
			TestAssertions.equal(snapshot.run_player_id, RUN_PLAYER_ID, "run player identity captures", failures)
			TestAssertions.equal(snapshot.leader_member_id, LEADER_ID, "leader identity captures", failures)
			TestAssertions.equal(snapshot.members.size(), context.party.members.size(), "all ordered members capture", failures)
			TestAssertions.equal(_member_ids(snapshot.members), [1, 2, 3], "member order is exact", failures)
			TestAssertions.equal(_leader_count(snapshot.members), 1, "snapshot contains exactly one leader", failures)
			TestAssertions.equal(snapshot.members[0].display_name, "Asha", "explicit member display name captures", failures)
			TestAssertions.equal(snapshot.members[1].display_name, "Ranger", "blank character name falls back to class display name", failures)
			TestAssertions.equal(snapshot.members[2].final_level, 2, "final level comes from member progression", failures)
			TestAssertions.equal(snapshot.resolution_source.to_dictionary(), RunResolutionSource.from_context(context, LEADER_ID).source.to_dictionary(), "snapshot embeds exact defensive resolution truth", failures)
			var before: Dictionary = snapshot.to_dictionary()
			var escaped_members: Array = snapshot.members
			escaped_members[0]._display_name = "Escaped"
			var escaped_source: RunResolutionSource = snapshot.resolution_source
			escaped_source._party_members[0]["class_id"] = "escaped"
			party.members[0].character_name = "Mutated after capture"
			party.members[0].class_definition.display_name = "Mutated class"
			context._progression_by_member[3].level = 99
			context._item_state.owner_id = "mutated-owner"
			context._profile_id = "mutated-profile"
			context._run_id = &"mutated-run"
			context._run_seed = 999999
			context._run_player_id = &"mutated-player"
			TestAssertions.equal(snapshot.to_dictionary(), before, "snapshot owns all member, progression, and resolution truth", failures)
			context.release_source_refresh_coordinator()
			party.free()
			TestAssertions.equal(snapshot.to_dictionary(), before, "snapshot remains readable after source nodes are freed", failures)
			var escaped_result_snapshot: Variant = result.snapshot
			escaped_result_snapshot._elapsed_seconds = 999.0
			TestAssertions.equal(result.snapshot.to_dictionary(), before, "result exposes a defensive snapshot", failures)
		else:
			context.release_source_refresh_coordinator()
			party.free()

func _test_strict_codec(builder_type: Script, snapshot_type: Script, outcomes: Dictionary, failures: Array[String]) -> void:
	var fixture := _fixture("codec")
	var result: Variant = builder_type.new().call(&"capture", int(outcomes["VICTORY"]), 42.25, fixture.context)
	TestAssertions.truthy(result.ok(), "codec fixture captures", failures)
	if not result.ok():
		_cleanup(fixture)
		return
	var snapshot: Variant = result.snapshot
	var document := snapshot.call(&"to_dictionary") as Dictionary
	TestAssertions.equal(document.keys(), EXPECTED_SNAPSHOT_FIELDS, "snapshot dictionary has exact ordered fields", failures)
	TestAssertions.truthy(not _contains_object(document), "snapshot dictionary contains no nodes, resources, or mutable objects", failures)
	var decoded: Variant = snapshot_type.call(&"from_dictionary", document)
	TestAssertions.truthy(decoded.ok(), "strict snapshot dictionary roundtrip decodes", failures)
	if decoded.ok():
		TestAssertions.equal(decoded.snapshot.to_dictionary(), document, "snapshot roundtrip is structurally exact", failures)
		var escaped: Variant = decoded.snapshot
		escaped._members.clear()
		escaped._resolution_source._leader_core_attributes["strength"] = -999.0
		TestAssertions.equal(decoded.snapshot.to_dictionary(), document, "decoded result remains copy-owned", failures)
	var json_document: Variant = JSON.parse_string(JSON.stringify(document))
	var cold_decoded: Variant = snapshot_type.call(&"from_dictionary", json_document)
	TestAssertions.truthy(cold_decoded.ok(), "snapshot survives an actual JSON cold roundtrip", failures)
	if cold_decoded.ok():
		TestAssertions.equal(cold_decoded.snapshot.to_dictionary(), document, "JSON cold roundtrip preserves exact terminal truth", failures)
	var malformed: Array[Dictionary] = []
	var missing := document.duplicate(true); missing.erase("run_id"); malformed.append(missing)
	var extra := document.duplicate(true); extra["unexpected"] = true; malformed.append(extra)
	var schema := document.duplicate(true); schema["schema_version"] = 2; malformed.append(schema)
	var bad_outcome := document.duplicate(true); bad_outcome["outcome"] = 2; malformed.append(bad_outcome)
	var bad_elapsed := document.duplicate(true); bad_elapsed["elapsed_seconds"] = -0.01; malformed.append(bad_elapsed)
	var string_elapsed := document.duplicate(true); string_elapsed["elapsed_seconds"] = "42.25"; malformed.append(string_elapsed)
	var empty_profile := document.duplicate(true); empty_profile["profile_id"] = ""; malformed.append(empty_profile)
	var duplicate_member := document.duplicate(true); duplicate_member["members"].append((duplicate_member["members"] as Array)[0].duplicate(true)); malformed.append(duplicate_member)
	var member_extra := document.duplicate(true); member_extra["members"][0]["unexpected"] = true; malformed.append(member_extra)
	var member_level := document.duplicate(true); member_level["members"][0]["final_level"] = 0; malformed.append(member_level)
	var member_leader_type := document.duplicate(true); member_leader_type["members"][0]["is_leader"] = 1; malformed.append(member_leader_type)
	var two_leaders := document.duplicate(true); two_leaders["members"][1]["is_leader"] = true; malformed.append(two_leaders)
	var wrong_leader := document.duplicate(true); wrong_leader["leader_member_id"] = 2; malformed.append(wrong_leader)
	var wrong_source_identity := document.duplicate(true); wrong_source_identity["resolution_source"]["run_seed"] = RUN_SEED + 1; malformed.append(wrong_source_identity)
	var wrong_source_profile := document.duplicate(true); wrong_source_profile["resolution_source"]["profile_id"] = "other-profile"; malformed.append(wrong_source_profile)
	var wrong_source_run := document.duplicate(true); wrong_source_run["resolution_source"]["run_id"] = "other-run"; malformed.append(wrong_source_run)
	var wrong_source_player := document.duplicate(true)
	wrong_source_player["resolution_source"]["run_player_id"] = "other-player"
	wrong_source_player["resolution_source"]["item_state"]["owner_id"] = "other-player"
	for container: Dictionary in wrong_source_player["resolution_source"]["item_state"]["containers"] as Array:
		container["owner_id"] = "other-player"
	malformed.append(wrong_source_player)
	var wrong_source_leader := document.duplicate(true); wrong_source_leader["resolution_source"]["leader_member_id"] = 2; wrong_source_leader["resolution_source"]["party_members"][0]["is_leader"] = false; wrong_source_leader["resolution_source"]["party_members"][1]["is_leader"] = true; wrong_source_leader["resolution_source"]["leader_class_id"] = wrong_source_leader["resolution_source"]["party_members"][1]["class_id"]; malformed.append(wrong_source_leader)
	var wrong_source_member := document.duplicate(true); wrong_source_member["resolution_source"]["party_members"][1]["class_id"] = "mage"; malformed.append(wrong_source_member)
	var invalid_ownership := document.duplicate(true); invalid_ownership["resolution_source"]["item_state"]["owner_id"] = "wrong-owner"; malformed.append(invalid_ownership)
	var too_many := document.duplicate(true)
	for member_id: int in range(4, 26):
		var member_copy: Dictionary = (too_many["members"] as Array)[1].duplicate(true)
		member_copy["member_id"] = member_id
		(too_many["members"] as Array).append(member_copy)
		var source_copy: Dictionary = (too_many["resolution_source"]["party_members"] as Array)[1].duplicate(true)
		source_copy["member_id"] = member_id
		(too_many["resolution_source"]["party_members"] as Array).append(source_copy)
	malformed.append(too_many)
	for index: int in malformed.size():
		var rejected: Variant = snapshot_type.call(&"from_dictionary", malformed[index])
		TestAssertions.truthy(not rejected.ok() and not rejected.error.is_empty(), "strict snapshot rejects malformed document %d with readable error" % index, failures)
	TestAssertions.truthy(not snapshot_type.call(&"from_dictionary", null).ok(), "snapshot decoder rejects non-dictionary input", failures)
	_cleanup(fixture)

func _test_twenty_four_members_and_nonfirst_leader(builder_type: Script, outcomes: Dictionary, failures: Array[String]) -> void:
	var fixture := _large_fixture(24, 13)
	var context := fixture.context as PlayerRunContext
	var before_profile := context.profile_snapshot.to_dictionary()
	var before_items := context.item_state().to_dictionary()
	var result: Variant = builder_type.new().call(&"capture", int(outcomes["DEFEAT"]), 0.0, context)
	TestAssertions.truthy(result.ok(), "twenty-four-member terminal truth with nonfirst leader captures", failures)
	if result.ok():
		var snapshot: Variant = result.snapshot
		TestAssertions.equal(snapshot.members.size(), 24, "terminal capture never truncates the supported party maximum", failures)
		TestAssertions.equal(_member_ids(snapshot.members), range(1, 25), "twenty-four members preserve exact party order", failures)
		TestAssertions.equal(snapshot.leader_member_id, 13, "leader identity is discovered rather than assumed first", failures)
		TestAssertions.truthy(not snapshot.members[0].is_leader and snapshot.members[12].is_leader, "member leader flags preserve nonfirst leader truth", failures)
		TestAssertions.equal(snapshot.resolution_source.leader_member_id, 13, "resolution source agrees with nonfirst leader", failures)
	TestAssertions.equal(context.profile_snapshot.to_dictionary(), before_profile, "capture leaves the profile snapshot unchanged", failures)
	TestAssertions.equal(context.item_state().to_dictionary(), before_items, "capture leaves live item ownership unchanged", failures)
	_cleanup(fixture)

func _test_invalid_capture_truth(builder_type: Script, outcomes: Dictionary, failures: Array[String]) -> void:
	var builder: Variant = builder_type.new()
	var valid_outcome := int(outcomes["VICTORY"])
	var invalid_calls: Array[Dictionary] = [
		{"label": "null context", "outcome": valid_outcome, "elapsed": 1.0, "context": null, "field": "context"},
		{"label": "invalid outcome", "outcome": 2, "elapsed": 1.0, "context": _fixture("invalid_outcome"), "field": "outcome"},
		{"label": "negative duration", "outcome": valid_outcome, "elapsed": -1.0, "context": _fixture("negative_duration"), "field": "elapsed_seconds"},
		{"label": "nonfinite duration", "outcome": valid_outcome, "elapsed": NAN, "context": _fixture("nonfinite_duration"), "field": "elapsed_seconds"},
	]
	for test_case: Dictionary in invalid_calls:
		var context_value: Variant = test_case.context
		var context: Variant = context_value.context if context_value is Dictionary else context_value
		var rejected: Variant = builder.call(&"capture", test_case.outcome, test_case.elapsed, context)
		TestAssertions.truthy(not rejected.ok() and rejected.error.contains(test_case.field), "%s fails with readable field" % test_case.label, failures)
		if context_value is Dictionary:
			_cleanup(context_value)

	var mutations: Array[Dictionary] = [
		{"label": "missing progression", "field": "members[1].final_level", "apply": func(fixture: Dictionary) -> void: (fixture.context as PlayerRunContext)._progression_by_member.erase(2)},
		{"label": "mismatched progression", "field": "members[1].final_level", "apply": func(fixture: Dictionary) -> void: (fixture.context as PlayerRunContext)._progression_by_member[2].member_id = 99},
		{"label": "nonpositive member", "field": "members[1].member_id", "apply": func(fixture: Dictionary) -> void: (fixture.party as PartyManager).members[1].member_id = 0},
		{"label": "duplicate member", "field": "members[1].member_id", "apply": func(fixture: Dictionary) -> void: (fixture.party as PartyManager).members[1].member_id = 1},
		{"label": "missing class", "field": "members[1].class", "apply": func(fixture: Dictionary) -> void: (fixture.party as PartyManager).members[1].class_definition = null},
		{"label": "empty class ID", "field": "members[1].class_id", "apply": func(fixture: Dictionary) -> void: (fixture.party as PartyManager).members[1].class_definition.id = &""},
		{"label": "empty class name", "field": "members[1].class_name", "apply": func(fixture: Dictionary) -> void: (fixture.party as PartyManager).members[1].class_definition.display_name = ""},
		{"label": "no leader", "field": "leader", "apply": func(fixture: Dictionary) -> void: (fixture.party as PartyManager).members[0].is_leader = false},
		{"label": "two leaders", "field": "leader", "apply": func(fixture: Dictionary) -> void: (fixture.party as PartyManager).members[1].is_leader = true},
		{"label": "invalid ownership", "field": "item_state", "apply": func(fixture: Dictionary) -> void: (fixture.context as PlayerRunContext)._item_state.owner_id = "wrong-owner"},
		{"label": "empty profile identity", "field": "profile_id", "apply": func(fixture: Dictionary) -> void: (fixture.context as PlayerRunContext)._profile_id = ""},
		{"label": "empty run identity", "field": "run_id", "apply": func(fixture: Dictionary) -> void: (fixture.context as PlayerRunContext)._run_id = &""},
		{"label": "invalid seed identity", "field": "run_seed", "apply": func(fixture: Dictionary) -> void: (fixture.context as PlayerRunContext)._run_seed = 0},
		{"label": "empty player identity", "field": "run_player_id", "apply": func(fixture: Dictionary) -> void: (fixture.context as PlayerRunContext)._run_player_id = &""},
	]
	for test_case: Dictionary in mutations:
		var fixture := _fixture("invalid_%s" % String(test_case.label).replace(" ", "_"))
		(test_case.apply as Callable).call(fixture)
		var rejected: Variant = builder.call(&"capture", valid_outcome, 1.0, fixture.context)
		TestAssertions.truthy(not rejected.ok(), "%s invalid core truth fails closed" % test_case.label, failures)
		TestAssertions.truthy(rejected.error.contains(test_case.field), "%s identifies the exact invalid field and never skips the member" % test_case.label, failures)
		_cleanup(fixture)

func _fixture(label: String) -> Dictionary:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	assert(party.recruit(catalog.class_by_id(&"ranger")))
	assert(party.recruit(catalog.class_by_id(&"mage")))
	for member: PartyMemberState in party.members:
		member.class_definition = member.class_definition.duplicate(true) as ClassDefinition
	party.members[0].character_name = "Asha"
	party.members[1].character_name = ""
	party.members[2].character_name = "Mira"
	var state := ItemOwnershipState.create(String(RUN_PLAYER_ID), ItemRegistry.new([]), [
		ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, String(RUN_PLAYER_ID), 10, {}),
		ItemSlotContainer.create(&"run-equipment-001", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, String(RUN_PLAYER_ID), EquipmentSlotIndex.capacity(), {}),
		ItemSlotContainer.create(&"run-equipment-002", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, String(RUN_PLAYER_ID), EquipmentSlotIndex.capacity(), {}),
		ItemSlotContainer.create(&"run-equipment-003", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, String(RUN_PLAYER_ID), EquipmentSlotIndex.capacity(), {}),
	])
	assert(state.validate(GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG).is_empty())
	var bootstrap := RunItemBootstrap.create(RUN_ID, RUN_SEED, RUN_PLAYER_ID, LEADER_ID, state, &"fighter")
	var profile := ProfileState.new_profile(PROFILE_ID, "Terminal Snapshot Tester", 1000)
	profile.inventory_columns = 2
	profile.resumable_run = ResumableRunItemCodec.encode(bootstrap)
	var context := PlayerRunContext.new()
	assert(context.configure(RUN_PLAYER_ID, 0, profile, RUN_SEED, party, 100, bootstrap).is_empty())
	assert(context.award_experience(3, 20).ok())
	return {"label": label, "party": party, "context": context, "profile": profile}

func _large_fixture(member_count: int, leader_member_id: int) -> Dictionary:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.configure_capacity(PartyCapacityPolicy.new(member_count))
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	for member_id: int in range(2, member_count + 1):
		assert(party.recruit(catalog.class_by_id(&"ranger")))
	for member: PartyMemberState in party.members:
		member.is_leader = member.member_id == leader_member_id
		member.character_name = "Member %02d" % member.member_id
	var containers: Array[ItemSlotContainer] = [
		ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, String(RUN_PLAYER_ID), 10, {}),
	]
	for member_id: int in range(1, member_count + 1):
		containers.append(ItemSlotContainer.create(
			StringName("run-equipment-%03d" % member_id),
			ItemSlotContainer.RUN_MEMBER_EQUIPMENT,
			String(RUN_PLAYER_ID),
			EquipmentSlotIndex.capacity(),
			{},
		))
	var state := ItemOwnershipState.create(String(RUN_PLAYER_ID), ItemRegistry.new([]), containers)
	assert(state.validate(GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG).is_empty())
	var leader := party.member_by_id(leader_member_id)
	var bootstrap := RunItemBootstrap.create(RUN_ID, RUN_SEED, RUN_PLAYER_ID, leader_member_id, state, leader.class_definition.id)
	var profile := ProfileState.new_profile(PROFILE_ID, "Terminal Snapshot Large Tester", 1000)
	profile.inventory_columns = 2
	profile.resumable_run = ResumableRunItemCodec.encode(bootstrap)
	var context := PlayerRunContext.new()
	assert(context.configure(RUN_PLAYER_ID, 0, profile, RUN_SEED, party, 100, bootstrap).is_empty())
	return {"label": "large", "party": party, "context": context, "profile": profile}

func _cleanup(fixture: Dictionary) -> void:
	var context := fixture.context as PlayerRunContext
	if context != null:
		context.release_source_refresh_coordinator()
	var party := fixture.party as PartyManager
	if is_instance_valid(party):
		party.free()

func _member_ids(members: Array) -> Array[int]:
	var result: Array[int] = []
	for member: Variant in members:
		result.append(int(member.member_id))
	return result

func _leader_count(members: Array) -> int:
	var count := 0
	for member: Variant in members:
		if member.is_leader:
			count += 1
	return count

func _contains_object(value: Variant) -> bool:
	if value is Object:
		return true
	if value is Array:
		for child: Variant in value as Array:
			if _contains_object(child):
				return true
	if value is Dictionary:
		for key: Variant in value as Dictionary:
			if _contains_object(key) or _contains_object((value as Dictionary)[key]):
				return true
	return false
