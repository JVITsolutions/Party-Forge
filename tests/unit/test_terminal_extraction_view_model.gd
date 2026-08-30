extends RefCounted

const VIEW_MODEL_PATH := "res://scripts/ui/run_result/terminal_extraction_view_model.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	var view_model_type := load(VIEW_MODEL_PATH) as Script
	TestAssertions.truthy(view_model_type != null, "terminal extraction view model exists", failures)
	if view_model_type == null:
		return failures
	var fixture := _fixture()
	var view_model: Variant = view_model_type.new()
	var policy := RunExtractionPolicy.project_source(fixture.source, fixture.profile, [])
	var projection: Variant = view_model.call(&"build", policy, fixture.source, fixture.profile)
	TestAssertions.truthy(projection != null and projection.valid, "valid source projects picker truth", failures)
	if projection != null:
		TestAssertions.equal(projection.capacity, 1, "capacity remains authoritative", failures)
		TestAssertions.equal(_item_ids(projection.automatic_items), ["item-leader"], "automatic items preserve canonical order", failures)
		TestAssertions.equal(_item_ids(projection.eligible_items), ["item-follower", "item-inventory"], "eligible items preserve canonical order", failures)
		TestAssertions.equal(projection.automatic_count, 1, "automatic count is exact", failures)
		TestAssertions.equal(projection.selected_count, 0, "constrained picker begins without selection", failures)
		TestAssertions.equal(projection.lost_count, 2, "loss count is exact", failures)
		var eligible: Array = projection.eligible_items
		TestAssertions.equal(eligible[0].owner_label, "Ranger · Member 2", "equipped item names exact stable source member", failures)
		TestAssertions.equal(eligible[1].container_label, "Run Inventory", "carried item names source container", failures)
		var source_properties := _property_names(eligible[0])
		for property_name: String in ["owner_member_id", "owner_class_label", "source_container_id", "source_slot", "source_heading", "consequence_label"]:
			TestAssertions.truthy(source_properties.has(property_name), "item projection exposes exact %s" % property_name, failures)
		if source_properties.has("owner_member_id"):
			TestAssertions.equal(int(eligible[0].get("owner_member_id")), 2, "equipped item carries stable member identity", failures)
			TestAssertions.equal(String(eligible[0].get("owner_class_label")), "Ranger", "equipped item carries frozen class display", failures)
			TestAssertions.equal(String(eligible[0].get("source_container_id")), "run-equipment-002", "equipped item carries exact container token", failures)
			TestAssertions.equal(int(eligible[0].get("source_slot")), 7, "equipped item carries exact source slot", failures)
			TestAssertions.truthy(String(eligible[0].get("source_heading")).contains("MEMBER 2") and String(eligible[0].get("source_heading")).contains("RANGER"), "same-class members remain distinguishable in source heading", failures)
			TestAssertions.truthy(not String(eligible[0].get("source_heading")).contains("run-equipment-"), "player-facing source heading omits raw container identity", failures)
			TestAssertions.truthy(String(eligible[0].get("consequence_label")).contains("run-equipment-002") and String(eligible[0].get("consequence_label")).contains("slot 7"), "consequence identity includes exact source", failures)
			TestAssertions.equal(int(eligible[1].get("owner_member_id")), 0, "run inventory is distinct from member equipment", failures)
			TestAssertions.equal(String(eligible[1].get("source_container_id")), "run-inventory", "run inventory carries exact container identity", failures)
			TestAssertions.equal(int(eligible[1].get("source_slot")), 0, "run inventory carries exact slot", failures)
		TestAssertions.truthy(projection.has_method(&"eligible_source_sections"), "projection exposes ordered contiguous source sections", failures)
		if projection.has_method(&"eligible_source_sections"):
			var sections: Array = projection.call(&"eligible_source_sections")
			TestAssertions.equal(sections.size(), 2, "eligible projection has one canonical section per contiguous source", failures)
			if sections.size() == 2:
				TestAssertions.equal(_item_ids(sections[0].items), ["item-follower"], "first source section retains first policy token", failures)
				TestAssertions.equal(_item_ids(sections[1].items), ["item-inventory"], "second source section retains following policy token", failures)
		TestAssertions.equal(eligible[0].name, "Windrunner Band", "catalog-backed name is used", failures)
		TestAssertions.equal(eligible[0].rarity_name, "Common", "catalog-backed rarity is used", failures)
		TestAssertions.truthy(not eligible[0].detail.is_empty(), "item detail is available", failures)
		TestAssertions.equal(eligible[1].comparisons.size(), 1, "compatible leader equipment comparison is catalog-backed and available", failures)
		var escaped: Array = projection.eligible_items
		escaped[0]._name = "Escaped"
		TestAssertions.equal(projection.eligible_items[0].name, "Windrunner Band", "item projections are defensive", failures)
	var cold_result := RunResolutionSource.from_dictionary(JSON.parse_string(JSON.stringify(fixture.source.to_dictionary())))
	TestAssertions.truthy(cold_result.ok(), "cold source roundtrip is valid", failures)
	if cold_result.ok():
		var cold_policy := RunExtractionPolicy.project_source(cold_result.source, fixture.profile.copy(), [])
		var cold_projection: Variant = view_model.call(&"build", cold_policy, cold_result.source, fixture.profile.copy())
		TestAssertions.equal(JSON.stringify(cold_projection.to_dictionary()), JSON.stringify(projection.to_dictionary()), "live and cold picker presentation are byte-equivalent", failures)
	var wrong_profile := fixture.profile.copy() as ProfileState
	wrong_profile.profile_id = "wrong-profile"
	var invalid: Variant = view_model.call(&"build", policy, fixture.source, wrong_profile)
	TestAssertions.truthy(invalid != null and not invalid.valid, "identity mismatch fails closed", failures)
	_cleanup(fixture)
	return failures

func _fixture() -> Dictionary:
	var catalog := GameCatalog.load_defaults()
	var items: Array[ItemInstance] = [
		_item("item-leader", 0, &"forge_vanguard_sword"),
		_item("item-follower", 1, &"windrunner_band"),
		_item("item-inventory", 2, &"forge_vanguard_sword"),
	]
	var state := ItemOwnershipState.create("terminal-player", ItemRegistry.new(items), [
		ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, "terminal-player", 8, {0: "item-inventory"}),
		ItemSlotContainer.create(&"run-equipment-001", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, "terminal-player", EquipmentSlotIndex.capacity(), {9: "item-leader"}),
		ItemSlotContainer.create(&"run-equipment-002", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, "terminal-player", EquipmentSlotIndex.capacity(), {7: "item-follower"}),
	])
	var attributes: Dictionary = {}
	for attribute_id: StringName in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
		attributes[String(attribute_id)] = 10.0
	var source_result := RunResolutionSource.from_dictionary({
		"schema_version": 1, "profile_id": "terminal-profile", "run_id": "terminal-run",
		"run_seed": 9001, "run_player_id": "terminal-player", "leader_member_id": 1,
		"party_members": [
			{"member_id": 1, "class_id": "fighter", "is_leader": true},
			{"member_id": 2, "class_id": "ranger", "is_leader": false},
		],
		"item_state": state.to_dictionary(), "leader_class_id": "fighter", "leader_core_attributes": attributes,
	})
	assert(source_result.ok())
	var profile := ProfileState.new_profile("terminal-profile", "Terminal Tester", 1000)
	profile.extraction_capacity = 1
	profile.permanent_feature_unlocks = ["leader_loadout_extraction"]
	return {"catalog": catalog, "source": source_result.source, "profile": profile}

func _item(instance_id: String, sequence: int, base_id: StringName) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.base_definition_id = base_id
	item.item_level = 20
	item.rarity_id = &"common"
	item.affixes = []
	item.origin = {"issuer_namespace": "run:terminal-profile:9001:terminal-player", "seed": 9001, "sequence": sequence, "source": "terminal_picker_test"}
	return item

func _item_ids(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values:
		result.append(String(value.item_id))
	return result

func _property_names(value: Object) -> Array[String]:
	var result: Array[String] = []
	for property: Dictionary in value.get_property_list():
		result.append(String(property.get("name", "")))
	return result

func _cleanup(_fixture: Dictionary) -> void:
	pass
