extends RefCounted

const PROFILE_ID := "profile-resolution-preflight001"
const RUN_ID := &"run-resolution-preflight-001"
const RUN_PLAYER_ID := &"resolution-preflight-player"
const RUN_SEED := 7171
const LEADER_ID := 1
const LEADER_HEAD := "item-preflight-leader-head"
const LEADER_HAND := "item-preflight-leader-hand"
const FOLLOWER_ITEM := "item-preflight-follower"
const INVENTORY_ITEM := "item-preflight-inventory"
const PRIOR_HEAD := "item-preflight-prior-head"
const PRIOR_SHIELD := "item-preflight-prior-shield"
const FAILURE_STALE_SELECTION := 1
const FAILURE_RUN_IDENTITY_MISMATCH := 2
const FAILURE_OWNERSHIP_VERIFICATION := 3
const FAILURE_STASH_REDUCIBLE := 5
const FAILURE_STASH_AUTOMATIC_ONLY := 6
const FAILURE_SELECTION_OVER_CAPACITY := 7

func run() -> Array[String]:
	var failures: Array[String] = []
	var source_type := load("res://scripts/extraction/run_resolution_source.gd") as Script
	var evaluator_type := load("res://scripts/extraction/run_resolution_evaluator.gd") as Script
	var preflight_type := load("res://scripts/extraction/run_resolution_preflight_result.gd") as Script
	TestAssertions.truthy(source_type != null, "resolution source type exists", failures)
	TestAssertions.truthy(evaluator_type != null, "shared resolution evaluator type exists", failures)
	TestAssertions.truthy(preflight_type != null, "resolution preflight result type exists", failures)
	if source_type == null or evaluator_type == null or preflight_type == null:
		return failures
	_test_source_strict_roundtrip(source_type, failures)
	_test_preflight_capacity_and_purity(failures)
	_test_failure_matrix(source_type, failures)
	_test_wrapper_source_failure_categories(failures)
	_test_evaluator_candidate_isolation(source_type, evaluator_type, failures)
	return failures

func _test_source_strict_roundtrip(source_type: Script, failures: Array[String]) -> void:
	var fixture := _fixture("source", 1, [], 3)
	var captured: Variant = source_type.call(&"from_context", fixture.context, LEADER_ID)
	TestAssertions.truthy(captured.ok(), "live resolution source captures", failures)
	if captured.ok():
		var source: Variant = captured.source
		TestAssertions.equal(source.profile_id, PROFILE_ID, "source captures profile identity", failures)
		TestAssertions.equal(source.run_id, RUN_ID, "source captures run identity", failures)
		TestAssertions.equal(source.run_seed, RUN_SEED, "source captures run seed", failures)
		TestAssertions.equal(source.run_player_id, RUN_PLAYER_ID, "source captures run player identity", failures)
		TestAssertions.equal(source.leader_member_id, LEADER_ID, "source captures leader identity", failures)
		TestAssertions.equal(source.party_members, [
			{"member_id": 1, "class_id": "fighter", "is_leader": true},
			{"member_id": 2, "class_id": "ranger", "is_leader": false},
		], "source captures ordered unique party rows", failures)
		TestAssertions.equal(source.leader_class_id, &"fighter", "source captures leader class", failures)
		for attribute_id: StringName in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
			TestAssertions.truthy(source.leader_core_attributes.has(String(attribute_id)), "source captures core attribute %s" % attribute_id, failures)
		var document: Dictionary = source.to_dictionary()
		TestAssertions.truthy(not _contains_object(document), "source dictionary contains no nodes or resources", failures)
		var decoded: Variant = source_type.call(&"from_dictionary", document)
		TestAssertions.truthy(decoded.ok(), "strict source dictionary roundtrip decodes", failures)
		if decoded.ok():
			TestAssertions.equal(decoded.source.to_dictionary(), document, "source roundtrip is structurally exact", failures)
			var escaped_rows: Array[Dictionary] = decoded.source.party_members
			escaped_rows[0]["class_id"] = "escaped"
			var escaped_attributes: Dictionary = decoded.source.leader_core_attributes
			escaped_attributes["strength"] = -999.0
			var escaped_state: ItemOwnershipState = decoded.source.item_state
			escaped_state.owner_id = "escaped"
			TestAssertions.equal(decoded.source.party_members[0]["class_id"], "fighter", "source party rows are defensive", failures)
			TestAssertions.truthy(float(decoded.source.leader_core_attributes["strength"]) >= 0.0, "source core attributes are defensive", failures)
			TestAssertions.equal(decoded.source.item_state.owner_id, String(RUN_PLAYER_ID), "source ownership is defensive", failures)
		var malformed: Array[Dictionary] = []
		var missing := document.duplicate(true); missing.erase("run_id"); malformed.append(missing)
		var extra := document.duplicate(true); extra["unexpected"] = true; malformed.append(extra)
		var wrong_type := document.duplicate(true); wrong_type["run_seed"] = "7171"; malformed.append(wrong_type)
		var nonpositive := document.duplicate(true); nonpositive["leader_member_id"] = 0; malformed.append(nonpositive)
		var duplicate_member := document.duplicate(true); duplicate_member["party_members"].append((duplicate_member["party_members"] as Array)[0].duplicate(true)); malformed.append(duplicate_member)
		var two_leaders := document.duplicate(true); two_leaders["party_members"][1]["is_leader"] = true; malformed.append(two_leaders)
		var wrong_class := document.duplicate(true); wrong_class["leader_class_id"] = "ranger"; malformed.append(wrong_class)
		var missing_attribute := document.duplicate(true); missing_attribute["leader_core_attributes"].erase(String(ClassGrowthDefinition.CORE_ATTRIBUTE_IDS[0])); malformed.append(missing_attribute)
		var wrong_owner := document.duplicate(true); wrong_owner["item_state"]["owner_id"] = "wrong-owner"; malformed.append(wrong_owner)
		for index: int in malformed.size():
			TestAssertions.truthy(not source_type.call(&"from_dictionary", malformed[index]).ok(), "strict source rejects malformed document %d" % index, failures)
	_cleanup(fixture)

func _test_wrapper_source_failure_categories(failures: Array[String]) -> void:
	var identity := _fixture("wrapper_identity_failure", 0, [], 1)
	(identity.context as PlayerRunContext)._profile_snapshot.resumable_run = {}
	var identity_request := _request("wrapper-identity-failure", [])
	var identity_service := RunResolutionService.new(ProfileMutationService.new(identity.store))
	var identity_preflight := identity_service.preflight(identity.profile, identity.context, identity_request)
	var identity_resolve := identity_service.resolve(PROFILE_ID, identity.context, identity_request, identity.root)
	TestAssertions.equal(identity_preflight.failure_category, FAILURE_RUN_IDENTITY_MISMATCH, "missing strict durable bootstrap is typed as saved-run identity mismatch", failures)
	TestAssertions.equal(identity_resolve.failure_category, identity_preflight.failure_category, "wrapper strict-bootstrap identity category has preflight/resolve parity", failures)
	TestAssertions.truthy(not identity_preflight.player_reason.contains("field=") and identity_preflight.player_reason.contains("saved run"), "wrapper identity copy is player-safe", failures)
	_cleanup(identity)

	var ownership := _fixture("wrapper_ownership_failure", 0, [], 1)
	(ownership.context as PlayerRunContext)._item_state._erase_item(INVENTORY_ITEM)
	var ownership_request := _request("wrapper-ownership-failure", [])
	var ownership_service := RunResolutionService.new(ProfileMutationService.new(ownership.store))
	var ownership_preflight := ownership_service.preflight(ownership.profile, ownership.context, ownership_request)
	var ownership_resolve := ownership_service.resolve(PROFILE_ID, ownership.context, ownership_request, ownership.root)
	TestAssertions.equal(ownership_preflight.failure_category, FAILURE_OWNERSHIP_VERIFICATION, "invalid ownership with matching owner has typed ownership failure", failures)
	TestAssertions.equal(ownership_resolve.failure_category, ownership_preflight.failure_category, "wrapper ownership category has preflight/resolve parity", failures)
	TestAssertions.truthy(ownership_preflight.player_reason.contains("Nothing was moved") and not ownership_preflight.player_reason.contains("PARTY_FORGE"), "wrapper ownership copy is player-safe", failures)
	_cleanup(ownership)

func _test_preflight_capacity_and_purity(failures: Array[String]) -> void:
	var cases: Array[Dictionary] = [
		{"label": "ordinary", "capacity": 1, "unlocks": [], "stash": 3, "prior": false, "selections": [ExtractionSelection.create(INVENTORY_ITEM, &"run-inventory", 0)], "ok": true, "mandatory": 0, "ordinary": 1, "required": 1, "available": 3, "automatic_only": false},
		{"label": "all-fit", "capacity": 1, "unlocks": [], "stash": 1, "prior": false, "selections": [ExtractionSelection.create(INVENTORY_ITEM, &"run-inventory", 0)], "ok": true, "mandatory": 0, "ordinary": 1, "required": 1, "available": 1, "automatic_only": false},
		{"label": "constrained", "capacity": 1, "unlocks": [], "stash": 0, "prior": false, "selections": [ExtractionSelection.create(INVENTORY_ITEM, &"run-inventory", 0)], "ok": false, "mandatory": 0, "ordinary": 1, "required": 1, "available": 0, "automatic_only": false},
		{"label": "zero", "capacity": 0, "unlocks": [], "stash": 0, "prior": false, "selections": [], "ok": true, "mandatory": 0, "ordinary": 0, "required": 0, "available": 0, "automatic_only": false},
		{"label": "automatic", "capacity": 1, "unlocks": [RunExtractionPolicy.AUTOMATIC_LEADER_UNLOCK], "stash": 3, "prior": true, "selections": [ExtractionSelection.create(FOLLOWER_ITEM, &"run-equipment-002", 7)], "ok": true, "mandatory": 2, "ordinary": 1, "required": 3, "available": 3, "automatic_only": false},
		{"label": "automatic-only", "capacity": 0, "unlocks": [RunExtractionPolicy.AUTOMATIC_LEADER_UNLOCK], "stash": 1, "prior": true, "selections": [], "ok": false, "mandatory": 2, "ordinary": 0, "required": 2, "available": 1, "automatic_only": true},
		{"label": "over-capacity", "capacity": 0, "unlocks": [], "stash": 3, "prior": false, "selections": [ExtractionSelection.create(INVENTORY_ITEM, &"run-inventory", 0)], "ok": false, "mandatory": 0, "ordinary": 1, "required": 1, "available": 3, "automatic_only": false},
	]
	for test_case: Dictionary in cases:
		var fixture := _fixture(test_case.label, test_case.capacity, test_case.unlocks, test_case.stash)
		if test_case.prior:
			_seed_prior_loadout(fixture)
			fixture.profile = (fixture.store as ProfileStore).load_profile(PROFILE_ID, fixture.root).profile
		var profile := fixture.profile as ProfileState
		var before_profile := JSON.stringify(profile.to_dictionary())
		var before_context := JSON.stringify((fixture.context as PlayerRunContext).item_state().to_dictionary())
		var path := (fixture.store as ProfileStore).profile_path(PROFILE_ID, fixture.root)
		var before_bytes := FileAccess.get_file_as_bytes(path)
		var service := RunResolutionService.new(ProfileMutationService.new(fixture.store))
		var request := _request("preflight-%s" % test_case.label, _typed_selections(test_case.selections))
		var request_before := JSON.stringify(request.canonical_document())
		var source_before := JSON.stringify(RunResolutionSource.from_context(fixture.context, LEADER_ID).source.to_dictionary())
		var result: Variant = service.call(&"preflight", profile, fixture.context, request)
		TestAssertions.equal(result.ok(), test_case.ok, "%s preflight disposition is exact" % test_case.label, failures)
		TestAssertions.equal(result.mandatory_stash_slots, test_case.mandatory, "%s mandatory count is exact" % test_case.label, failures)
		TestAssertions.equal(result.ordinary_stash_slots, test_case.ordinary, "%s ordinary count is exact" % test_case.label, failures)
		TestAssertions.equal(result.required_stash_slots, result.mandatory_stash_slots + result.ordinary_stash_slots, "%s required count is auditable" % test_case.label, failures)
		TestAssertions.equal(result.required_stash_slots, test_case.required, "%s required count is exact" % test_case.label, failures)
		TestAssertions.equal(result.available_stash_slots, test_case.available, "%s available count is exact" % test_case.label, failures)
		TestAssertions.equal(result.automatic_only_blocked, test_case.automatic_only, "%s automatic-only classification is exact" % test_case.label, failures)
		TestAssertions.truthy(result.mandatory_stash_slots_known and result.ordinary_stash_slots_known and result.required_stash_slots_known and result.available_stash_slots_known, "%s successful/count-capacity result exposes known counts" % test_case.label, failures)
		if test_case.label == "constrained":
			TestAssertions.equal(result.failure_category, FAILURE_STASH_REDUCIBLE, "reducible shortage has a typed category", failures)
			TestAssertions.truthy(result.player_reason.contains("1 required") and result.player_reason.contains("0 available") and result.player_reason.contains("Deselect at least 1"), "reducible shortage player copy includes auditable action", failures)
		elif test_case.label == "automatic-only":
			TestAssertions.equal(result.failure_category, FAILURE_STASH_AUTOMATIC_ONLY, "mandatory shortage has a typed category", failures)
			TestAssertions.truthy(result.player_reason.contains("2") and result.player_reason.contains("1") and result.player_reason.contains("cannot fix"), "automatic-only player copy explains deselection cannot fix it", failures)
		elif test_case.label == "over-capacity":
			TestAssertions.equal(result.failure_category, FAILURE_SELECTION_OVER_CAPACITY, "extraction over-capacity has a typed category", failures)
		if not result.player_reason.is_empty():
			TestAssertions.truthy(not result.player_reason.contains("PARTY_FORGE") and not result.player_reason.contains("field="), "%s player copy contains no internal diagnostic tokens" % test_case.label, failures)
		TestAssertions.equal(JSON.stringify(profile.to_dictionary()), before_profile, "%s preflight preserves profile document" % test_case.label, failures)
		TestAssertions.equal(JSON.stringify((fixture.context as PlayerRunContext).item_state().to_dictionary()), before_context, "%s preflight preserves context document" % test_case.label, failures)
		TestAssertions.equal(FileAccess.get_file_as_bytes(path), before_bytes, "%s preflight performs no store write" % test_case.label, failures)
		TestAssertions.equal(JSON.stringify(request.canonical_document()), request_before, "%s preflight preserves request selections exactly" % test_case.label, failures)
		TestAssertions.equal(JSON.stringify(RunResolutionSource.from_context(fixture.context, LEADER_ID).source.to_dictionary()), source_before, "%s preflight preserves strict source bytes" % test_case.label, failures)
		if result.extraction != null:
			var extraction_document: Dictionary = result.extraction.to_dictionary()
			var escaped: RunExtractionProjection = result.extraction
			escaped._selected_item_ids.clear()
			TestAssertions.equal(result.extraction.to_dictionary(), extraction_document, "%s extraction is copy-owned" % test_case.label, failures)
		var resolved := service.resolve(PROFILE_ID, fixture.context, request, fixture.root)
		TestAssertions.equal(resolved.ok(), result.ok(), "%s preflight/resolve disposition parity is exact" % test_case.label, failures)
		TestAssertions.equal(resolved.failure_category, result.failure_category, "%s preflight/resolve typed category parity is exact" % test_case.label, failures)
		if resolved.ok():
			TestAssertions.equal(resolved.accepted_extraction.to_dictionary(), result.extraction.to_dictionary(), "%s accepted preflight/resolve extraction parity is exact" % test_case.label, failures)
		_cleanup(fixture)

func _test_failure_matrix(source_type: Script, failures: Array[String]) -> void:
	var fixture := _fixture("failures", 1, [], 2)
	var service := RunResolutionService.new(ProfileMutationService.new(fixture.store))
	var profile := fixture.profile as ProfileState
	var context := fixture.context as PlayerRunContext
	var cases: Array[Dictionary] = [
		{"label": "stale", "request": _request("preflight-stale", [ExtractionSelection.create(INVENTORY_ITEM, &"run-inventory", 1)]), "category": FAILURE_STALE_SELECTION, "player": "Review the extraction selection again"},
		{"label": "identity", "request": RunResolutionRequest.create("preflight-identity", PROFILE_ID, &"wrong-run", RUN_SEED, RUN_PLAYER_ID, LEADER_ID, []), "category": FAILURE_RUN_IDENTITY_MISMATCH, "player": "saved run"},
	]
	for test_case: Dictionary in cases:
		var before_profile := JSON.stringify(profile.to_dictionary())
		var before_context := JSON.stringify(context.item_state().to_dictionary())
		var result: Variant = service.call(&"preflight", profile, context, test_case.request)
		TestAssertions.truthy(not result.ok() and not result.error.is_empty(), "%s preflight retains an internal diagnostic" % test_case.label, failures)
		TestAssertions.equal(result.failure_category, test_case.category, "%s preflight exposes its typed category" % test_case.label, failures)
		TestAssertions.truthy(result.player_reason.contains(test_case.player), "%s preflight has distinct player copy" % test_case.label, failures)
		TestAssertions.truthy(not result.player_reason.contains("PARTY_FORGE") and not result.player_reason.contains("field="), "%s player copy hides raw diagnostics" % test_case.label, failures)
		if test_case.label == "stale":
			TestAssertions.truthy(result.mandatory_stash_slots_known and result.available_stash_slots_known, "stale selection retains safely known mandatory and available counts", failures)
			TestAssertions.truthy(not result.ordinary_stash_slots_known and not result.required_stash_slots_known, "stale selection explicitly marks selection-dependent counts unavailable", failures)
		TestAssertions.equal(JSON.stringify(profile.to_dictionary()), before_profile, "%s failure preserves profile" % test_case.label, failures)
		TestAssertions.equal(JSON.stringify(context.item_state().to_dictionary()), before_context, "%s failure preserves context" % test_case.label, failures)
		var resolved := service.resolve(PROFILE_ID, context, test_case.request, fixture.root)
		TestAssertions.equal(resolved.ok(), result.ok(), "%s rejected preflight/resolve disposition parity is exact" % test_case.label, failures)
		TestAssertions.equal(resolved.failure_category, result.failure_category, "%s rejected preflight/resolve category parity is exact" % test_case.label, failures)
	var source_result: Variant = source_type.call(&"from_context", context, LEADER_ID)
	TestAssertions.truthy(source_result.ok(), "ownership failure source captures before corruption", failures)
	if source_result.ok():
		var document: Dictionary = source_result.source.to_dictionary()
		document["item_state"]["owner_id"] = "wrong-owner"
		TestAssertions.truthy(not source_type.call(&"from_dictionary", document).ok(), "strict source rejects mismatched ownership", failures)

	context._item_state.owner_id = "wrong-owner"
	var ownership: Variant = service.call(&"preflight", profile, context, _request("preflight-ownership", []))
	TestAssertions.equal(ownership.failure_category, FAILURE_OWNERSHIP_VERIFICATION, "profile ownership rejection has a typed category diagnostic=%s" % ownership.error, failures)
	TestAssertions.truthy(ownership.player_reason.contains("Nothing was moved") and not ownership.player_reason.contains("field="), "ownership player copy promises atomic no-move behavior", failures)
	var ownership_resolve := service.resolve(PROFILE_ID, context, _request("preflight-ownership", []), fixture.root)
	TestAssertions.equal(ownership_resolve.failure_category, ownership.failure_category, "ownership preflight/resolve category parity is exact", failures)
	_cleanup(fixture)

func _test_evaluator_candidate_isolation(source_type: Script, evaluator_type: Script, failures: Array[String]) -> void:
	var fixture := _fixture("evaluator", 1, [], 2)
	var source_result: Variant = source_type.call(&"from_context", fixture.context, LEADER_ID)
	TestAssertions.truthy(source_result.ok(), "evaluator source captures", failures)
	if source_result.ok():
		var candidate := (fixture.profile as ProfileState).copy()
		var authoritative_before := JSON.stringify((fixture.profile as ProfileState).to_dictionary())
		var evaluation: Variant = evaluator_type.call(&"evaluate", candidate, source_result.source, _request("evaluate-direct", [ExtractionSelection.create(INVENTORY_ITEM, &"run-inventory", 0)]))
		TestAssertions.truthy(evaluation.ok(), "shared evaluator accepts valid candidate", failures)
		TestAssertions.equal(candidate.resumable_run, {}, "evaluator mutates only the caller-owned candidate", failures)
		TestAssertions.equal(JSON.stringify((fixture.profile as ProfileState).to_dictionary()), authoritative_before, "evaluator preserves authoritative profile input", failures)
		TestAssertions.truthy(not evaluation.get_property_list().any(func(property: Dictionary) -> bool: return property.name == "candidate"), "evaluation exposes no mutable candidate", failures)
	_cleanup(fixture)

func _fixture(label: String, capacity: int, unlocks: Array, stash_capacity: int) -> Dictionary:
	var root := "user://tests/run_resolution_preflight/%s" % label
	ProfileTestSupport.remove_tree(root)
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	assert(party.recruit(catalog.class_by_id(&"ranger")))
	var items := {LEADER_HEAD: _run_item(LEADER_HEAD, 0, &"forge_vanguard_helmet"), LEADER_HAND: _run_item(LEADER_HAND, 1, &"forge_vanguard_sword"), FOLLOWER_ITEM: _run_item(FOLLOWER_ITEM, 2, &"windrunner_band"), INVENTORY_ITEM: _run_item(INVENTORY_ITEM, 3, &"forge_vanguard_sword")}
	var run_state := ItemOwnershipState.create(String(RUN_PLAYER_ID), ItemRegistry.new([items[LEADER_HEAD], items[LEADER_HAND], items[FOLLOWER_ITEM], items[INVENTORY_ITEM]]), [
		ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, String(RUN_PLAYER_ID), 10, {0: INVENTORY_ITEM}),
		ItemSlotContainer.create(&"run-equipment-001", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, String(RUN_PLAYER_ID), EquipmentSlotIndex.capacity(), {0: LEADER_HEAD, 9: LEADER_HAND}),
		ItemSlotContainer.create(&"run-equipment-002", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, String(RUN_PLAYER_ID), EquipmentSlotIndex.capacity(), {7: FOLLOWER_ITEM}),
	])
	assert(run_state.validate(GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG).is_empty())
	var bootstrap := RunItemBootstrap.create(RUN_ID, RUN_SEED, RUN_PLAYER_ID, LEADER_ID, run_state, &"fighter")
	var profile := ProfileState.new_profile(PROFILE_ID, "Resolution Preflight Tester", 1000)
	profile.inventory_columns = 2
	profile.extraction_capacity = capacity
	for unlock: Variant in unlocks: profile.permanent_feature_unlocks.append(String(unlock))
	profile.resumable_run = ResumableRunItemCodec.encode(bootstrap)
	var stored_items: Array[ItemInstance] = []
	var stored_slots: Dictionary = {}
	for slot: int in range(100 - stash_capacity):
		var filler := _profile_item("item-preflight-filler-%03d" % slot, 100 + slot, &"forge_vanguard_sword")
		stored_items.append(filler)
		stored_slots[slot] = filler.instance_id
	profile.item_records = ItemRegistry.new(stored_items).to_dictionary()
	profile.stash_tabs = [ItemSlotContainer.create(&"stash-tab-000", ItemSlotContainer.PROFILE_STASH_TAB, PROFILE_ID, 100, stored_slots).to_dictionary()]
	var store := ProfileStore.new()
	assert(store.save_profile(profile, root).is_empty())
	var context := PlayerRunContext.new()
	assert(context.configure(RUN_PLAYER_ID, 0, profile, RUN_SEED, party, 100, bootstrap).is_empty())
	return {"root": root, "store": store, "profile": profile, "context": context, "party": party}

func _seed_prior_loadout(fixture: Dictionary) -> void:
	var profile := (fixture.store as ProfileStore).load_profile(PROFILE_ID, fixture.root).profile
	var decoded := ItemRegistry._decode(profile.item_records, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	var stored: Array[ItemInstance] = []
	for instance_id: String in (decoded.value as ItemRegistry).ids(): stored.append((decoded.value as ItemRegistry).item(instance_id))
	stored.append(_profile_item(PRIOR_HEAD, 20, &"forge_vanguard_helmet"))
	stored.append(_profile_item(PRIOR_SHIELD, 21, &"forge_vanguard_shield"))
	profile.item_records = ItemRegistry.new(stored).to_dictionary()
	profile.leader_loadout = ItemSlotContainer.create(&"leader-loadout", ItemSlotContainer.PROFILE_LEADER_EQUIPMENT, PROFILE_ID, EquipmentSlotIndex.capacity(), {0: PRIOR_HEAD, 10: PRIOR_SHIELD}).to_dictionary()
	profile.leader_loadout_class_id = "fighter"
	assert((fixture.store as ProfileStore).save_profile(profile, fixture.root).is_empty())

func _request(transaction_id: String, selections: Array[ExtractionSelection]) -> RunResolutionRequest:
	return RunResolutionRequest.create(transaction_id, PROFILE_ID, RUN_ID, RUN_SEED, RUN_PLAYER_ID, LEADER_ID, selections)

func _typed_selections(values: Array) -> Array[ExtractionSelection]:
	var result: Array[ExtractionSelection] = []
	for value: Variant in values: result.append(value as ExtractionSelection)
	return result

func _run_item(instance_id: String, sequence: int, base_definition_id: StringName) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id; item.base_definition_id = base_definition_id; item.item_level = 28; item.rarity_id = &"common"; item.affixes = []
	item.origin = {"issuer_namespace": "run:%s:%d:%s" % [PROFILE_ID, RUN_SEED, RUN_PLAYER_ID], "seed": RUN_SEED, "sequence": sequence, "source": "run_resolution_preflight_test"}
	return item

func _profile_item(instance_id: String, sequence: int, base_definition_id: StringName) -> ItemInstance:
	var item := _run_item(instance_id, sequence, base_definition_id); item.origin["issuer_namespace"] = "profile:%s" % PROFILE_ID; return item

func _contains_object(value: Variant) -> bool:
	if value is Object: return true
	if value is Array:
		for child: Variant in value as Array:
			if _contains_object(child): return true
	if value is Dictionary:
		for key: Variant in value as Dictionary:
			if _contains_object(key) or _contains_object((value as Dictionary)[key]): return true
	return false

func _cleanup(fixture: Dictionary) -> void:
	(fixture.party as PartyManager).free()
	ProfileTestSupport.remove_tree(fixture.root)
