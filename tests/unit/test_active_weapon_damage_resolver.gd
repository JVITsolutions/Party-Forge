extends RefCounted

const SNAPSHOT_PATH := "res://scripts/equipment/active_weapon_damage_snapshot.gd"
const RESOLVER_PATH := "res://scripts/equipment/active_weapon_damage_resolver.gd"
const EQUIPMENT_PATH := "res://data/equipment/core_equipment_catalog.tres"
const CONTAINER_ID := &"member-7-equipment"

var _snapshot_script: Script
var _resolver: Script

func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(SNAPSHOT_PATH), "active weapon snapshot script exists", failures)
	TestAssertions.truthy(ResourceLoader.exists(RESOLVER_PATH), "active weapon resolver script exists", failures)
	if not ResourceLoader.exists(SNAPSHOT_PATH) or not ResourceLoader.exists(RESOLVER_PATH):
		return failures
	_snapshot_script = load(SNAPSHOT_PATH) as Script
	_resolver = load(RESOLVER_PATH) as Script
	TestAssertions.truthy(_snapshot_script != null and _snapshot_script.can_instantiate(), "active weapon snapshot script is valid", failures)
	TestAssertions.truthy(_resolver != null and _resolver.can_instantiate(), "active weapon resolver script is valid", failures)
	if _snapshot_script == null or not _snapshot_script.can_instantiate() or _resolver == null or not _resolver.can_instantiate():
		return failures

	var equipment := load(EQUIPMENT_PATH) as EquipmentCatalog
	TestAssertions.truthy(equipment != null, "equipment catalog loads", failures)
	if equipment == null:
		return failures
	_test_valid_main_hand_identity_and_defensive_copies(equipment, failures)
	_test_absent_inactive_and_empty_damage_are_null_success(equipment, failures)
	_test_support_off_hand_and_dual_daggers_use_only_main_hand(equipment, failures)
	_test_malformed_components_are_rejected(equipment, failures)
	_test_invalid_identity_inputs_are_rejected(equipment, failures)
	return failures

func _test_valid_main_hand_identity_and_defensive_copies(equipment: EquipmentCatalog, failures: Array[String]) -> void:
	var physical := ItemBaseDamageComponent.create(&"physical", 7.0, 11.0)
	var fire := ItemBaseDamageComponent.create(&"fire", 2.0, 4.0)
	var item := _item("weapon-main", &"forge_vanguard_sword", [physical, fire])
	var state := _state([item], {EquipmentSlotIndex.index_for(&"main_hand"): item.instance_id})
	var result: Dictionary = _resolver.resolve(7, state.container(CONTAINER_ID), state, _active([item.instance_id]), equipment, 83)
	TestAssertions.equal(String(result.get("error", "missing")), "", "valid active main hand resolves", failures)
	var snapshot: Variant = result.get("snapshot")
	TestAssertions.truthy(snapshot != null, "valid active main hand produces a snapshot", failures)
	if snapshot == null:
		return
	TestAssertions.equal(int(snapshot.get("member_id")), 7, "snapshot owns member identity", failures)
	TestAssertions.equal(String(snapshot.get("item_id")), "weapon-main", "snapshot owns item identity", failures)
	TestAssertions.equal(StringName(snapshot.get("base_id")), &"forge_vanguard_sword", "snapshot owns base identity", failures)
	TestAssertions.equal(int(snapshot.get("revision")), 83, "snapshot owns equipment revision", failures)
	_assert_components(snapshot.get("components") as Array, [
		{"type": &"fire", "minimum": 2.0, "maximum": 4.0},
		{"type": &"physical", "minimum": 7.0, "maximum": 11.0},
	], "valid snapshot", failures)

	var escaped_components := snapshot.get("components") as Array
	(escaped_components[0] as ItemBaseDamageComponent).minimum_damage = 999.0
	escaped_components.clear()
	_assert_components(snapshot.get("components") as Array, [
		{"type": &"fire", "minimum": 2.0, "maximum": 4.0},
		{"type": &"physical", "minimum": 7.0, "maximum": 11.0},
	], "snapshot getter remains defensive", failures)
	var copied: Variant = snapshot.call("copy")
	var copied_components := copied.get("components") as Array
	(copied_components[1] as ItemBaseDamageComponent).maximum_damage = 777.0
	_assert_components(snapshot.get("components") as Array, [
		{"type": &"fire", "minimum": 2.0, "maximum": 4.0},
		{"type": &"physical", "minimum": 7.0, "maximum": 11.0},
	], "snapshot copy cannot mutate original", failures)
	TestAssertions.near(physical.minimum_damage, 7.0, 0.0001, "resolution leaves caller component unchanged", failures)

func _test_absent_inactive_and_empty_damage_are_null_success(equipment: EquipmentCatalog, failures: Array[String]) -> void:
	var empty_state := _state([], {})
	_assert_null_success(_resolver.resolve(7, empty_state.container(CONTAINER_ID), empty_state, _active([]), equipment, 84), "empty main hand", failures)

	var inactive := _item("weapon-inactive", &"forge_vanguard_sword", [ItemBaseDamageComponent.create(&"physical", 4.0, 8.0)])
	var inactive_state := _state([inactive], {EquipmentSlotIndex.index_for(&"main_hand"): inactive.instance_id})
	_assert_null_success(_resolver.resolve(7, inactive_state.container(CONTAINER_ID), inactive_state, _active([]), equipment, 85), "disabled main hand", failures)

	var migrated_schema_one := _item("weapon-schema-one", &"forge_vanguard_sword", [])
	var migrated_state := _state([migrated_schema_one], {EquipmentSlotIndex.index_for(&"main_hand"): migrated_schema_one.instance_id})
	_assert_null_success(_resolver.resolve(7, migrated_state.container(CONTAINER_ID), migrated_state, _active([migrated_schema_one.instance_id]), equipment, 86), "schema-one migrated empty range", failures)

func _test_support_off_hand_and_dual_daggers_use_only_main_hand(equipment: EquipmentCatalog, failures: Array[String]) -> void:
	var support := _item("support-off", &"forge_vanguard_shield", [])
	var support_state := _state([support], {EquipmentSlotIndex.index_for(&"off_hand"): support.instance_id})
	_assert_null_success(_resolver.resolve(7, support_state.container(CONTAINER_ID), support_state, _active([support.instance_id]), equipment, 87), "support off hand", failures)

	var main := _item("dagger-main", &"nightstep_dagger_main", [ItemBaseDamageComponent.create(&"physical", 5.0, 9.0)])
	var off := _item("dagger-off", &"nightstep_dagger_off", [ItemBaseDamageComponent.create(&"chaos", 100.0, 200.0)])
	var dual_state := _state([off, main], {
		EquipmentSlotIndex.index_for(&"main_hand"): main.instance_id,
		EquipmentSlotIndex.index_for(&"off_hand"): off.instance_id,
	})
	var dual: Dictionary = _resolver.resolve(7, dual_state.container(CONTAINER_ID), dual_state, _active([off.instance_id, main.instance_id]), equipment, 88)
	TestAssertions.equal(String(dual.get("error", "missing")), "", "dual daggers resolve", failures)
	var snapshot: Variant = dual.get("snapshot")
	TestAssertions.truthy(snapshot != null, "dual daggers produce main-hand snapshot", failures)
	if snapshot != null:
		TestAssertions.equal(String(snapshot.get("item_id")), "dagger-main", "dual daggers select only main-hand identity", failures)
		_assert_components(snapshot.get("components") as Array, [
			{"type": &"physical", "minimum": 5.0, "maximum": 9.0},
		], "dual dagger main-hand ranges", failures)

func _test_malformed_components_are_rejected(equipment: EquipmentCatalog, failures: Array[String]) -> void:
	var malformed_cases: Array[Dictionary] = [
		{
			"label": "null component",
			"components": [null],
			"fragment": "component=0 reason=component is missing",
		},
		{
			"label": "unknown damage type",
			"components": [ItemBaseDamageComponent.create(&"void", 1.0, 2.0)],
			"fragment": "component=0 type=void PARTY_FORGE_ITEM_BASE_DAMAGE_ERROR field=damage_type_id reason=unknown damage type void",
		},
		{
			"label": "inverted range",
			"components": [ItemBaseDamageComponent.create(&"physical", 3.0, 2.0)],
			"fragment": "component=0 type=physical PARTY_FORGE_ITEM_BASE_DAMAGE_ERROR field=minimum_damage reason=must be less than or equal to maximum_damage",
		},
		{
			"label": "duplicate damage type",
			"components": [
				ItemBaseDamageComponent.create(&"fire", 1.0, 2.0),
				ItemBaseDamageComponent.create(&"fire", 3.0, 4.0),
			],
			"fragment": "component=1 type=fire reason=duplicate damage type fire",
		},
	]
	for case: Dictionary in malformed_cases:
		var item := _item("malformed-%s" % String(case["label"]).replace(" ", "-"), &"forge_vanguard_sword", case["components"] as Array)
		var state := _state([item], {EquipmentSlotIndex.index_for(&"main_hand"): item.instance_id})
		var result: Dictionary = _resolver.resolve(7, state.container(CONTAINER_ID), state, _active([item.instance_id]), equipment, 89)
		var error := String(result.get("error", ""))
		TestAssertions.truthy(not error.is_empty(), "%s is rejected" % case["label"], failures)
		TestAssertions.truthy(error.contains(String(case["fragment"])), "%s preserves stable validation context" % case["label"], failures)
		TestAssertions.equal(result.get("snapshot"), null, "%s exposes no partial snapshot" % case["label"], failures)

func _test_invalid_identity_inputs_are_rejected(equipment: EquipmentCatalog, failures: Array[String]) -> void:
	var item := _item("identity-main", &"forge_vanguard_sword", [ItemBaseDamageComponent.create(&"physical", 1.0, 2.0)])
	var state := _state([item], {EquipmentSlotIndex.index_for(&"main_hand"): item.instance_id})
	var container := state.container(CONTAINER_ID)
	var invalid_member: Dictionary = _resolver.resolve(0, container, state, _active([item.instance_id]), equipment, 90)
	TestAssertions.equal(String(invalid_member.get("error", "")), "PARTY_FORGE_ACTIVE_WEAPON_DAMAGE_ERROR member=0 reason=member id must be positive", "invalid member has stable failure", failures)
	var invalid_revision: Dictionary = _resolver.resolve(7, container, state, _active([item.instance_id]), equipment, -1)
	TestAssertions.equal(String(invalid_revision.get("error", "")), "PARTY_FORGE_ACTIVE_WEAPON_DAMAGE_ERROR member=7 reason=revision must be nonnegative", "invalid revision has stable failure", failures)

func _assert_null_success(result: Dictionary, label: String, failures: Array[String]) -> void:
	TestAssertions.equal(String(result.get("error", "missing")), "", "%s resolves without error" % label, failures)
	TestAssertions.equal(result.get("snapshot"), null, "%s contributes no snapshot" % label, failures)

func _active(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values:
		result.append(String(value))
	return result

func _assert_components(actual: Array, expected: Array[Dictionary], label: String, failures: Array[String]) -> void:
	TestAssertions.equal(actual.size(), expected.size(), "%s component count" % label, failures)
	for index: int in mini(actual.size(), expected.size()):
		var component := actual[index] as ItemBaseDamageComponent
		TestAssertions.truthy(component != null, "%s component %d exists" % [label, index], failures)
		if component == null:
			continue
		TestAssertions.equal(component.damage_type_id, expected[index]["type"], "%s component %d type" % [label, index], failures)
		TestAssertions.near(component.minimum_damage, float(expected[index]["minimum"]), 0.0001, "%s component %d minimum" % [label, index], failures)
		TestAssertions.near(component.maximum_damage, float(expected[index]["maximum"]), 0.0001, "%s component %d maximum" % [label, index], failures)

func _item(instance_id: String, base_id: StringName, components: Array) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.base_definition_id = base_id
	item.item_level = 1
	item.rarity_id = &"common"
	for component: Variant in components:
		item.base_damage_components.append(component as ItemBaseDamageComponent)
	item.origin = {"issuer_namespace": "active-weapon:test", "seed": 707, "sequence": 1, "source": "task_7"}
	return item

func _state(items: Array[ItemInstance], slots: Dictionary) -> ItemOwnershipState:
	var container := ItemSlotContainer.create(
		CONTAINER_ID,
		ItemSlotContainer.RUN_MEMBER_EQUIPMENT,
		"run-player-7",
		EquipmentSlotIndex.capacity(),
		slots,
	)
	return ItemOwnershipState.create("run-player-7", ItemRegistry.new(items), [container])
