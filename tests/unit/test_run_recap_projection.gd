extends RefCounted

const ENTRY_PATH := "res://scripts/ui/run_result/run_recap_entry_projection.gd"
const SECTION_PATH := "res://scripts/ui/run_result/run_recap_section_projection.gd"
const PROVIDER_PATH := "res://scripts/ui/run_result/run_recap_provider.gd"
const PROVIDER_RESULT_PATH := "res://scripts/ui/run_result/run_recap_provider_result.gd"
const LOOT_PROVIDER_PATH := "res://scripts/ui/run_result/run_loot_recap_provider.gd"

const PROFILE_ID := "profile-results"
const RUN_ID := &"run-results"
const RUN_SEED := 777
const RUN_PLAYER_ID := &"player-results"
const AUTOMATIC_ID := "run-results-automatic"
const AUTOMATIC_ID_TWO := "run-results-automatic-two"
const SELECTED_ID := "run-results-selected"
const SELECTED_ID_TWO := "run-results-selected-two"
const PROTECTED_ID := "profile-results-protected"
const PROTECTED_ID_TWO := "profile-results-protected-two"

class TestProvider:
	extends RefCounted
	var stable_id: StringName
	var order := 0
	var mode := &"section"
	var kind := 5
	var provider_result_script: Script
	var section_script: Script
	var entry_script: Script

	func _init(id_value: StringName, order_value: int, mode_value: StringName, kind_value: int, result_type: Script, section_type: Script, entry_type: Script) -> void:
		stable_id = id_value
		order = order_value
		mode = mode_value
		kind = kind_value
		provider_result_script = result_type
		section_script = section_type
		entry_script = entry_type

	func provider_id() -> StringName:
		return stable_id

	func display_order() -> int:
		return order

	func project(_snapshot: RunTerminalSnapshot, _resolution: RunResolutionResult) -> Variant:
		if mode == &"mutate":
			_resolution._protected_displaced_item_ids.clear()
			_resolution._profile.profile_id = "forged-by-optional-provider"
			return provider_result_script.call(&"empty")
		if mode == &"observe":
			if _resolution.profile == null or _resolution.profile.profile_id != PROFILE_ID or _resolution.protected_displaced_item_ids.size() != 2:
				return provider_result_script.call(&"failure", "provider received previously mutated resolution")
		if mode == &"empty":
			return provider_result_script.call(&"empty")
		if mode == &"failure":
			return provider_result_script.call(&"failure", "test provider failed exactly")
		if mode == &"invalid":
			return provider_result_script.call(&"success", null)
		var entry: Variant = entry_script.call(&"create", "Recorded extension", "The forge held", "Production-backed test-provider detail")
		var entries: Array = [entry]
		var section: Variant = section_script.call(&"create", stable_id, "TEST RECAP EXTENSION", kind, entries, "One provider-backed entry")
		return provider_result_script.call(&"success", section)

func run() -> Array[String]:
	var failures: Array[String] = []
	var entry_type := load(ENTRY_PATH) as Script
	var section_type := load(SECTION_PATH) as Script
	var provider_type := load(PROVIDER_PATH) as Script
	var provider_result_type := load(PROVIDER_RESULT_PATH) as Script
	var loot_provider_type := load(LOOT_PROVIDER_PATH) as Script
	TestAssertions.truthy(entry_type != null, "typed recap entry projection exists", failures)
	TestAssertions.truthy(section_type != null, "typed recap section projection exists", failures)
	TestAssertions.truthy(provider_type != null, "typed recap provider interface exists", failures)
	TestAssertions.truthy(provider_result_type != null, "typed recap provider result exists", failures)
	TestAssertions.truthy(loot_provider_type != null, "required first-party loot provider exists", failures)
	if entry_type == null or section_type == null or provider_type == null or provider_result_type == null or loot_provider_type == null:
		return failures

	var entry: Variant = entry_type.call(&"create", "Outcome", "Victory", "Exact terminal event")
	TestAssertions.truthy(entry != null and bool(entry.call(&"valid")), "recap entry accepts complete production truth", failures)
	var entries: Array = [entry]
	var outcome: Variant = section_type.call(&"create", &"outcome", "RUN OUTCOME", 0, entries, "Victory in 01:30")
	TestAssertions.truthy(outcome != null and bool(outcome.call(&"valid")), "outcome section is valid and bounded", failures)
	var escaped_entries: Array = outcome.get("entries")
	escaped_entries.clear()
	TestAssertions.equal(outcome.get("entries").size(), 1, "section entries are defensive", failures)
	var escaped_entry: Variant = outcome.get("entries")[0]
	escaped_entry.set("_value", "Fabricated")
	TestAssertions.equal(String(outcome.get("entries")[0].get("value")), "Victory", "nested recap entries are defensively copied", failures)
	TestAssertions.truthy(not bool(section_type.call(&"create", &"", "Bad", 0, entries, "").call(&"valid")), "blank stable section identity rejects", failures)
	TestAssertions.truthy(not bool(section_type.call(&"create", &"bad", "Bad", 99, entries, "").call(&"valid")), "unknown semantic kind rejects", failures)

	var successful: Variant = provider_result_type.call(&"success", outcome)
	var copied_section: Variant = successful.get("section")
	TestAssertions.truthy(bool(successful.call(&"ok")) and copied_section != outcome, "provider result owns a defensive section", failures)
	var empty: Variant = provider_result_type.call(&"empty")
	TestAssertions.truthy(bool(empty.call(&"is_empty")) and not bool(empty.call(&"ok")), "empty optional provider result is explicit", failures)
	var failed: Variant = provider_result_type.call(&"failure", "stable failure")
	TestAssertions.truthy(not bool(failed.call(&"ok")) and failed.get("error") == "stable failure", "provider failure carries one exact error", failures)

	var fixture := _fixture(3, 3)
	var loot: Variant = loot_provider_type.new().call(&"project", fixture.snapshot, fixture.resolution)
	TestAssertions.truthy(loot != null and bool(loot.call(&"ok")), "first-party loot provider projects accepted typed extraction", failures)
	if loot != null and bool(loot.call(&"ok")):
		var loot_section: Variant = loot.get("section")
		TestAssertions.equal(loot_section.get("section_id"), &"loot", "loot provider owns the reserved loot ID", failures)
		var labels := _entry_labels(loot_section.get("entries"))
		TestAssertions.truthy("Automatic retention" in labels, "automatic retained item is named", failures)
		TestAssertions.truthy("Selected extraction" in labels, "selected extraction is named", failures)
		TestAssertions.truthy("Lost" in labels, "lost item is named without implying recovery", failures)
		TestAssertions.truthy("Protected displaced gear" in labels, "protected gear is named only from accepted typed result", failures)
	return failures

func provider(id_value: StringName, order: int, mode: StringName, kind: int = 5) -> TestProvider:
	return TestProvider.new(id_value, order, mode, kind, load(PROVIDER_RESULT_PATH) as Script, load(SECTION_PATH) as Script, load(ENTRY_PATH) as Script)

func _fixture(member_count: int = 3, lost_count: int = 3, outcome: RunTerminalSnapshot.Outcome = RunTerminalSnapshot.Outcome.VICTORY, member_order: Array[int] = []) -> Dictionary:
	var run_items: Array[ItemInstance] = []
	var automatic := _run_item(AUTOMATIC_ID, 0, &"forge_vanguard_sword")
	var automatic_two := _run_item(AUTOMATIC_ID_TWO, 1, &"forge_vanguard_helmet")
	var selected := _run_item(SELECTED_ID, 2, &"forge_vanguard_hammer")
	var selected_two := _run_item(SELECTED_ID_TWO, 3, &"forge_vanguard_hammer")
	run_items.append(automatic)
	run_items.append(automatic_two)
	run_items.append(selected)
	run_items.append(selected_two)
	var inventory_slots: Dictionary = {0: SELECTED_ID, 1: SELECTED_ID_TWO}
	var eligible: Array[ExtractionSelection] = [
		ExtractionSelection.create(SELECTED_ID, &"run-inventory", 0),
		ExtractionSelection.create(SELECTED_ID_TWO, &"run-inventory", 1),
	]
	var lost_ids: Array[String] = []
	for index: int in lost_count:
		var item_id := "run-results-lost-%02d" % (index + 1)
		run_items.append(_run_item(item_id, index + 4, &"forge_vanguard_hammer"))
		inventory_slots[index + 2] = item_id
		eligible.append(ExtractionSelection.create(item_id, &"run-inventory", index + 2))
		lost_ids.append(item_id)
	var run_state := ItemOwnershipState.create(String(RUN_PLAYER_ID), ItemRegistry.new(run_items), [
		ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, String(RUN_PLAYER_ID), 40, inventory_slots),
		ItemSlotContainer.create(&"run-equipment-001", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, String(RUN_PLAYER_ID), EquipmentSlotIndex.capacity(), {0: AUTOMATIC_ID_TWO, 9: AUTOMATIC_ID}),
	])
	var run_state_error := run_state.validate(GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	assert(run_state_error.is_empty(), run_state_error)

	var source_members: Array[Dictionary] = []
	var terminal_members: Array[RunTerminalPartyMemberSnapshot] = []
	var ordered_ids: Array[int] = member_order.duplicate()
	if ordered_ids.is_empty():
		for member_id: int in range(1, member_count + 1): ordered_ids.append(member_id)
	assert(ordered_ids.size() == member_count)
	for member_id: int in ordered_ids:
		var class_id := &"fighter" if member_id == 1 else &"ranger" if member_id % 2 == 0 else &"mage"
		var class_label := "Fighter" if class_id == &"fighter" else "Ranger" if class_id == &"ranger" else "Mage"
		var display_name := "Zara" if not member_order.is_empty() and member_id == 1 else "Asha" if not member_order.is_empty() and member_id == 2 else "Mira" if not member_order.is_empty() and member_id == 3 else "Member %02d" % member_id
		source_members.append({"member_id": member_id, "class_id": String(class_id), "is_leader": member_id == 1})
		terminal_members.append(RunTerminalPartyMemberSnapshot.create(member_id, display_name, class_id, class_label, member_id == 1, member_id + 6))
	var attributes: Dictionary = {}
	for attribute_id: StringName in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS:
		attributes[String(attribute_id)] = 10.0
	var source_result := RunResolutionSource.from_dictionary({
		"schema_version": RunResolutionSource.SCHEMA_VERSION,
		"profile_id": PROFILE_ID,
		"run_id": String(RUN_ID),
		"run_seed": RUN_SEED,
		"run_player_id": String(RUN_PLAYER_ID),
		"leader_member_id": 1,
		"party_members": source_members,
		"item_state": run_state.to_dictionary(),
		"leader_class_id": "fighter",
		"leader_core_attributes": attributes,
	})
	assert(source_result.ok())
	var snapshot_result := RunTerminalSnapshot.create(outcome, 90.25, PROFILE_ID, RUN_ID, RUN_SEED, RUN_PLAYER_ID, 1, terminal_members, source_result.source)
	assert(snapshot_result.ok())

	var protected := _profile_item(PROTECTED_ID, 50, &"forge_vanguard_helmet")
	var protected_two := _profile_item(PROTECTED_ID_TWO, 51, &"forge_vanguard_sword")
	var profile := ProfileState.new_profile(PROFILE_ID, "Result Truth", 1000)
	profile.inventory_columns = 2
	profile.leader_loadout_class_id = "fighter"
	profile.item_records = ItemRegistry.new([automatic, automatic_two, selected, selected_two, protected, protected_two]).to_dictionary()
	profile.leader_loadout = ItemSlotContainer.create(&"leader-loadout", ItemSlotContainer.PROFILE_LEADER_EQUIPMENT, PROFILE_ID, EquipmentSlotIndex.capacity(), {0: AUTOMATIC_ID_TWO, 9: AUTOMATIC_ID}).to_dictionary()
	profile.stash_tabs = [ItemSlotContainer.create(&"stash-tab-000", ItemSlotContainer.PROFILE_STASH_TAB, PROFILE_ID, 100, {0: SELECTED_ID, 1: SELECTED_ID_TWO}).to_dictionary()]
	profile.terminal_recovery_overflow = ItemSlotContainer.create(ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID, ItemSlotContainer.PROFILE_TERMINAL_RECOVERY_OVERFLOW, PROFILE_ID, EquipmentSlotIndex.capacity(), {0: PROTECTED_ID, 9: PROTECTED_ID_TWO}).to_dictionary()
	var accepted := RunExtractionProjection.create([AUTOMATIC_ID, AUTOMATIC_ID_TWO], eligible, [SELECTED_ID, SELECTED_ID_TWO], lost_ids, 2, [])
	var resolution := RunResolutionResult.success(profile, false, accepted, [PROTECTED_ID, PROTECTED_ID_TWO])
	assert(resolution.ok())
	return {"snapshot": snapshot_result.snapshot, "profile": profile, "resolution": resolution, "lost_ids": lost_ids}

func _run_item(instance_id: String, sequence: int, base_id: StringName) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.base_definition_id = base_id
	item.item_level = 12
	item.rarity_id = &"common"
	item.origin = {"issuer_namespace": "run:%s:%d:%s" % [PROFILE_ID, RUN_SEED, RUN_PLAYER_ID], "seed": RUN_SEED, "sequence": sequence, "source": "result_fixture"}
	return item

func _profile_item(instance_id: String, sequence: int, base_id: StringName) -> ItemInstance:
	var item := _run_item(instance_id, sequence, base_id)
	item.origin = {"issuer_namespace": "profile:%s" % PROFILE_ID, "seed": RUN_SEED, "sequence": sequence, "source": "result_fixture"}
	return item

func _entry_labels(entries: Array) -> Array[String]:
	var result: Array[String] = []
	for entry: Variant in entries:
		result.append(String(entry.get("label")))
	return result
