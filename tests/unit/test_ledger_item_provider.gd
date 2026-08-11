extends RefCounted

const INVENTORY_ID := &"run-inventory"


func run() -> Array[String]:
	var failures: Array[String] = []
	var probe := LedgerDataProvider.new()
	var required_methods: Array[StringName] = [
		&"inventory_rows", &"equipment_rows", &"item_detail", &"comparison_rows", &"move_or_equip",
	]
	for method_name: StringName in required_methods:
		TestAssertions.truthy(probe.has_method(method_name), "ledger provider exposes %s" % method_name, failures)
	if required_methods.any(func(method_name: StringName) -> bool: return not probe.has_method(method_name)):
		return failures

	_test_owner_rows_details_comparisons_and_mutations(failures)
	_test_disabled_equipment_keeps_detail_and_reasons(failures)
	return failures


func _test_owner_rows_details_comparisons_and_mutations(failures: Array[String]) -> void:
	var fixture := _fixture(&"ledger_owner", "ledger-owner-profile", 9111, true, failures)
	var foreign := _fixture(&"foreign_owner", "foreign-owner-profile", 9222, false, failures)
	var party := fixture.get("party") as PartyManager
	var context := fixture.get("context") as PlayerRunContext
	var catalog := fixture.get("catalog") as GameCatalog
	var ring := fixture.get("ring") as ItemInstance
	var helmet := fixture.get("helmet") as ItemInstance
	var foreign_context := foreign.get("context") as PlayerRunContext
	var foreign_ring := foreign.get("ring") as ItemInstance
	if party == null or context == null or catalog == null or ring == null or helmet == null or foreign_context == null or foreign_ring == null:
		failures.append("ledger owner fixtures must configure")
		_free_fixture(fixture)
		_free_fixture(foreign)
		return

	var provider := LedgerDataProvider.new()
	provider.call(
		&"configure",
		party,
		catalog,
		Callable(),
		Callable(),
		context,
		context,
		catalog.equipment_catalog,
		catalog.item_foundation_catalog,
	)

	var inventory_before: Array[Dictionary] = provider.inventory_rows()
	TestAssertions.equal(inventory_before.size(), 10, "inventory projects every unlocked run slot", failures)
	for slot: int in inventory_before.size():
		TestAssertions.equal(int(inventory_before[slot].get("slot", -1)), slot, "inventory row %d keeps exact slot" % slot, failures)
		TestAssertions.equal(StringName(String(inventory_before[slot].get("container_id", ""))), INVENTORY_ID, "inventory row %d keeps owner container" % slot, failures)
	TestAssertions.equal(String(inventory_before[0].get("item_id", "")), ring.instance_id, "inventory projects the authoritative occupied slot", failures)
	TestAssertions.equal(String(inventory_before[1].get("item_id", "")), "", "equipped item is absent from player-wide inventory", failures)

	var member_one_rows: Array[Dictionary] = provider.equipment_rows(1)
	var member_two_rows: Array[Dictionary] = provider.equipment_rows(2)
	TestAssertions.equal(member_one_rows.map(func(row: Dictionary) -> StringName: return StringName(String(row.get("slot_id", "")))), EquipmentSlotCatalog.SHEET_SLOT_IDS, "equipment follows exact sheet slot order", failures)
	TestAssertions.equal(member_two_rows.map(func(row: Dictionary) -> StringName: return StringName(String(row.get("slot_id", "")))), EquipmentSlotCatalog.SHEET_SLOT_IDS, "every member uses exact sheet slot order", failures)
	var helmet_slot := EquipmentSlotIndex.index_for(&"helmet")
	TestAssertions.equal(String(member_one_rows[helmet_slot].get("item_id", "")), helmet.instance_id, "selected member equipment is member-scoped", failures)
	TestAssertions.equal(String(member_two_rows[helmet_slot].get("item_id", "")), "", "changing member does not leak another member equipment", failures)
	TestAssertions.equal(provider.inventory_rows(), inventory_before, "member equipment selection does not change player-wide inventory", failures)

	var direct_detail := ItemPresentationProjector.project(
		ring,
		catalog.equipment_catalog,
		catalog.item_foundation_catalog,
		GameCatalog.STAT_CATALOG,
		party.member_by_id(1).class_definition,
		catalog.damage_types,
	)
	var projected_detail: Dictionary = provider.item_detail(ring.instance_id, 1)
	TestAssertions.equal(projected_detail, direct_detail, "item detail delegates to the shared item projector", failures)
	TestAssertions.equal(provider.item_detail(foreign_ring.instance_id, 1), {}, "foreign owner item ID never projects detail", failures)
	TestAssertions.equal(provider.comparison_rows(foreign_ring.instance_id, 1), [] as Array[Dictionary], "foreign owner item ID never projects comparison", failures)
	TestAssertions.truthy(not provider.inventory_rows().any(func(row: Dictionary) -> bool: return String(row.get("item_id", "")) == foreign_ring.instance_id), "foreign owner item ID never enters inventory rows", failures)

	var preview := context.preview_equipment_assignment(
		1,
		ring.instance_id,
		&"ring_left",
		catalog.equipment_catalog,
		catalog.item_foundation_catalog,
	)
	TestAssertions.truthy(preview.ok(), "comparison fixture has an accepted production preview", failures)
	if preview.ok():
		var expected_comparison := EquipmentComparisonProjectionService.compare(
			party.stats_for(1),
			preview.resolution().final_stats,
			GameCatalog.STAT_CATALOG,
			provider.combat_estimate_rows(1),
			[],
			context.equipment_activation(1),
			preview.activation(),
			ring.instance_id,
			_item_labels(context, provider, 1),
			_disabled_reasons(preview.activation()),
			catalog.damage_types,
		)
		var projected_comparison: Array[Dictionary] = provider.comparison_rows(ring.instance_id, 1)
		TestAssertions.truthy(not projected_comparison.is_empty(), "comparison projects a real stat delta", failures)
		TestAssertions.equal(projected_comparison, expected_comparison, "comparison delegates to the shared equipment comparison service", failures)
		if not projected_comparison.is_empty():
			projected_comparison[0]["text"] = "escaped"
			TestAssertions.truthy(String(provider.comparison_rows(ring.instance_id, 1)[0].get("text", "")) != "escaped", "comparison rows are defensive nested copies", failures)

	projected_detail["item"]["origin"]["source"] = "escaped"
	TestAssertions.truthy(String(provider.item_detail(ring.instance_id, 1).get("item", {}).get("origin", {}).get("source", "")) != "escaped", "item detail is a defensive nested copy", failures)
	(inventory_before[0].get("detail", {}) as Dictionary)["name"] = "escaped"
	TestAssertions.truthy(String((provider.inventory_rows()[0].get("detail", {}) as Dictionary).get("name", "")) != "escaped", "inventory rows are defensive nested copies", failures)
	(member_one_rows[helmet_slot].get("detail", {}) as Dictionary)["name"] = "escaped"
	TestAssertions.truthy(String((provider.equipment_rows(1)[helmet_slot].get("detail", {}) as Dictionary).get("name", "")) != "escaped", "equipment rows are defensive nested copies", failures)

	var changed: Array[int] = []
	provider.data_changed.connect(func(member_id: int) -> void: changed.append(member_id))
	var foreign_request := ItemTransactionRequest.move(
		"ledger-foreign-move",
		String(foreign_context.run_player_id),
		INVENTORY_ID,
		0,
		foreign_ring.instance_id,
		INVENTORY_ID,
		2,
	)
	var rejected: Dictionary = provider.move_or_equip({"member_id": 1, "transaction": foreign_request})
	TestAssertions.truthy(not bool(rejected.get("accepted", true)), "foreign owner transaction is rejected", failures)
	TestAssertions.equal(changed, [], "rejected transaction emits no ledger data change", failures)

	var move_request := ItemTransactionRequest.move(
		"ledger-owner-move",
		String(context.run_player_id),
		INVENTORY_ID,
		0,
		ring.instance_id,
		INVENTORY_ID,
		2,
	)
	var moved: Dictionary = provider.move_or_equip({"member_id": 2, "transaction": move_request})
	TestAssertions.truthy(bool(moved.get("accepted", false)), "accepted inventory move uses the production transaction boundary", failures)
	TestAssertions.equal(context.run_inventory().item_id_at(2), ring.instance_id, "accepted provider move commits authoritative run inventory", failures)
	TestAssertions.equal(changed, [2], "accepted inventory move emits exactly its selected member after commit", failures)

	changed.clear()
	var equipped: Dictionary = provider.move_or_equip({"member_id": 1, "item_id": ring.instance_id, "slot_id": &"ring_left"})
	TestAssertions.truthy(bool(equipped.get("accepted", false)), "accepted equip uses the production assignment boundary", failures)
	TestAssertions.equal(context.equipment_for(1).item_id_at(EquipmentSlotIndex.index_for(&"ring_left")), ring.instance_id, "accepted provider equip commits authoritative member equipment", failures)
	TestAssertions.equal(changed, [1], "accepted equip emits exactly once after accepted member commit", failures)

	_free_fixture(fixture)
	_free_fixture(foreign)


func _test_disabled_equipment_keeps_detail_and_reasons(failures: Array[String]) -> void:
	var definition_fixture := _install_disabled_sword_definition()
	var fixture := _disabled_fixture(failures)
	var party := fixture.get("party") as PartyManager
	var context := fixture.get("context") as PlayerRunContext
	var catalog := fixture.get("catalog") as GameCatalog
	var item := fixture.get("item") as ItemInstance
	if party != null and context != null and catalog != null and item != null:
		var provider := LedgerDataProvider.new()
		provider.call(&"configure", party, catalog, Callable(), Callable(), context, context, catalog.equipment_catalog, catalog.item_foundation_catalog)
		var row: Dictionary = provider.equipment_rows(1)[EquipmentSlotIndex.index_for(&"main_hand")]
		var detail := row.get("detail", {}) as Dictionary
		TestAssertions.equal(String(row.get("item_id", "")), item.instance_id, "disabled equipped item stays in its visual slot", failures)
		TestAssertions.equal(String(detail.get("name", "")), "Forge Vanguard Sword", "disabled equipped item retains normal projected visual detail", failures)
		TestAssertions.equal(detail.get("is_disabled"), true, "disabled equipped detail exposes inactive state", failures)
		TestAssertions.truthy(not PackedStringArray(detail.get("disabled_requirement_lines", PackedStringArray())).is_empty(), "disabled equipped detail exposes human requirement lines", failures)
		TestAssertions.truthy(not PackedStringArray(detail.get("inactive_reasons", PackedStringArray())).is_empty(), "disabled equipped detail retains authoritative inactive reasons", failures)
	_free_fixture(fixture)
	_restore_definition(definition_fixture)


func _fixture(owner: StringName, profile_id: String, seed: int, equip_helmet: bool, failures: Array[String]) -> Dictionary:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	party.recruit(catalog.class_by_id(&"ranger"))
	var profile := ProfileState.new_profile(profile_id, String(owner), 1000)
	profile.inventory_columns = 2
	var context := PlayerRunContext.new()
	var errors := context.configure(owner, 0, profile, seed, party, 100)
	TestAssertions.equal(errors, PackedStringArray(), "%s run context configures" % owner, failures)
	if not errors.is_empty():
		return {"party": party, "catalog": catalog}
	var ring := _item(context, 0, "%s-ring" % owner, &"windrunner_band", true)
	var helmet := _item(context, 1, "%s-helmet" % owner, &"dawn_bulwark_crown", false)
	for placement: Dictionary in [
		{"item": ring, "slot": 0, "transaction": "%s-create-ring" % owner},
		{"item": helmet, "slot": 1, "transaction": "%s-create-helmet" % owner},
	]:
		var item := placement["item"] as ItemInstance
		var result := context.apply_item_transaction(
			ItemTransactionRequest.create(String(placement["transaction"]), String(owner), INVENTORY_ID, int(placement["slot"]), item),
			catalog.equipment_catalog,
			catalog.item_foundation_catalog,
		)
		TestAssertions.truthy(result.ok(), "%s fixture item enters owner inventory" % item.instance_id, failures)
	if equip_helmet:
		TestAssertions.truthy(context.assign_equipment(1, helmet.instance_id, &"helmet", catalog.equipment_catalog, catalog.item_foundation_catalog).ok(), "fixture helmet equips through production boundary", failures)
	return {"party": party, "context": context, "catalog": catalog, "ring": ring, "helmet": helmet}


func _disabled_fixture(failures: Array[String]) -> Dictionary:
	var owner := &"ledger_disabled_owner"
	var profile_id := "ledger-disabled-profile"
	var seed := 9333
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var item := _decoded_item(owner, profile_id, seed, 0, "ledger-disabled-sword", &"forge_vanguard_sword", false)
	var state := ItemOwnershipState.create(String(owner), ItemRegistry.new([item]), [
		ItemSlotContainer.create(INVENTORY_ID, ItemSlotContainer.RUN_INVENTORY, String(owner), 5),
		ItemSlotContainer.create(&"run-equipment-001", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, String(owner), EquipmentSlotIndex.capacity(), {
			EquipmentSlotIndex.index_for(&"main_hand"): item.instance_id,
		}),
	])
	var bootstrap := RunItemBootstrap.create(&"ledger-disabled-run", seed, owner, 1, state)
	var profile := ProfileState.new_profile(profile_id, "Ledger Disabled", 1000)
	profile.inventory_columns = 1
	profile.resumable_run = ResumableRunItemCodec.encode(bootstrap)
	var context := PlayerRunContext.new()
	var errors := context.configure(owner, 0, profile, seed, party, 100, bootstrap)
	TestAssertions.equal(errors, PackedStringArray(), "disabled equipped fixture configures", failures)
	return {"party": party, "context": context, "catalog": catalog, "item": item}


func _item(context: PlayerRunContext, sequence: int, instance_id: String, base_id: StringName, with_roll: bool) -> ItemInstance:
	return _decoded_item(context.run_player_id, context.profile_id, context.run_seed, sequence, instance_id, base_id, with_roll)


func _decoded_item(owner: StringName, profile_id: String, seed: int, sequence: int, instance_id: String, base_id: StringName, with_roll: bool) -> ItemInstance:
	var affixes: Array = []
	if with_roll:
		affixes.append({
			"definition_id": "stout",
			"affix_kind": "prefix",
			"tier": 1,
			"rolls": [{
				"stat_id": "constitution",
				"operation": StatModifier.Operation.FLAT,
				"value": 3.0,
				"required_tags": [],
			}],
		})
	var decoded := ItemInstanceCodec.decode({
		"schema_version": ItemInstance.SCHEMA_VERSION,
		"instance_id": instance_id,
		"base_definition_id": String(base_id),
		"base_damage_components": [],
		"item_level": 12,
		"rarity_id": "common",
		"affixes": affixes,
		"origin": {
			"issuer_namespace": "run:%s:%d:%s" % [profile_id, seed, owner],
			"seed": seed + sequence,
			"sequence": sequence,
			"source": "ledger-provider-test",
		},
	}, GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	assert(decoded.ok())
	return decoded.item


func _item_labels(context: PlayerRunContext, provider: LedgerDataProvider, member_id: int) -> Dictionary:
	var result: Dictionary = {}
	var state := context.item_state()
	for item_id: String in state.registry().ids():
		result[item_id] = String(provider.item_detail(item_id, member_id).get("name", item_id))
	return result


func _disabled_reasons(activation: EquipmentActivationResult) -> Dictionary:
	var result: Dictionary = {}
	if activation == null:
		return result
	for item_id: String in activation.active_item_ids:
		result[item_id] = PackedStringArray()
	return result


func _install_disabled_sword_definition() -> Dictionary:
	var equipment := GameCatalog.EQUIPMENT_CATALOG
	for index: int in equipment.definitions.size():
		var definition := equipment.definitions[index]
		if definition != null and definition.id == &"forge_vanguard_sword":
			var replacement := definition.duplicate(true) as EquipmentBaseDefinition
			replacement.attribute_requirements = {&"strength": 999.0}
			equipment.definitions[index] = replacement
			return {"catalog": equipment, "index": index, "original": definition}
	assert(false, "forge vanguard sword definition exists")
	return {}


func _restore_definition(fixture: Dictionary) -> void:
	if fixture.has("catalog"):
		(fixture["catalog"] as EquipmentCatalog).definitions[int(fixture["index"])] = fixture["original"] as EquipmentBaseDefinition


func _free_fixture(fixture: Dictionary) -> void:
	var party := fixture.get("party") as PartyManager
	if party != null and is_instance_valid(party):
		party.free()
