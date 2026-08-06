extends RefCounted

const PROJECTOR_PATH := "res://scripts/ui/storage/item_presentation_projector.gd"


func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.truthy(ResourceLoader.exists(PROJECTOR_PATH), "item presentation projector exists", failures)
	if not ResourceLoader.exists(PROJECTOR_PATH):
		return failures
	var projector: Script = load(PROJECTOR_PATH)
	_test_complete_record(projector, failures)
	_test_missing_affix_omits_bounds(projector, failures)
	_test_class_warning(projector, failures)
	return failures


func _test_complete_record(projector: Script, failures: Array[String]) -> void:
	var detail: Dictionary = projector.call(
		"project",
		_item_with_stout_roll(5.0),
		GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG,
		GameCatalog.STAT_CATALOG,
	)
	TestAssertions.equal(detail.get("name"), "Windrunner Band", "base name is authoritative", failures)
	TestAssertions.equal(detail.get("compatible_slot_ids"), ["ring_left", "ring_right"], "both ring slots project", failures)
	var affixes: Array = detail.get("affixes", [])
	TestAssertions.equal(affixes.size(), 1, "one affix projects", failures)
	if affixes.is_empty():
		return
	var rolls: Array = (affixes[0] as Dictionary).get("rolls", [])
	TestAssertions.equal(rolls.size(), 1, "one modifier roll projects", failures)
	if rolls.is_empty():
		return
	var roll := rolls[0] as Dictionary
	TestAssertions.equal(roll.get("stat_name"), "Constitution", "stat display name projects", failures)
	TestAssertions.equal(roll.get("effect_text"), "+5 Constitution", "normal effect is player-readable", failures)
	TestAssertions.equal(roll.get("minimum_roll"), 4.0, "tier minimum projects", failures)
	TestAssertions.equal(roll.get("maximum_roll"), 6.0, "tier maximum projects", failures)
	TestAssertions.near(float(roll.get("roll_fraction", -1.0)), 0.5, 0.001, "roll position projects", failures)
	TestAssertions.equal(detail.get("modifier_totals"), {"constitution|0": 5.0}, "comparable modifier totals project", failures)


func _test_missing_affix_omits_bounds(projector: Script, failures: Array[String]) -> void:
	var item := _item_with_stout_roll(5.0)
	item.affixes[0].definition_id = &"missing-affix"
	var detail: Dictionary = projector.call(
		"project", item, GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG, GameCatalog.STAT_CATALOG,
	)
	var roll := (detail["affixes"][0]["rolls"][0] as Dictionary)
	TestAssertions.truthy(not roll.has("minimum_roll"), "missing definition omits minimum bound", failures)
	TestAssertions.truthy(not roll.has("maximum_roll"), "missing definition omits maximum bound", failures)
	TestAssertions.truthy(not roll.has("roll_fraction"), "missing definition omits roll position", failures)


func _test_class_warning(projector: Script, failures: Array[String]) -> void:
	var item := ItemInstance.new()
	item.instance_id = "restricted-item"
	item.base_definition_id = &"dawn_bulwark_crown"
	item.rarity_id = &"common"
	item.item_level = 12
	var ranger := load("res://data/classes/ranger.tres") as ClassDefinition
	var detail: Dictionary = projector.call(
		"project", item, GameCatalog.EQUIPMENT_CATALOG,
		GameCatalog.ITEM_FOUNDATION_CATALOG, GameCatalog.STAT_CATALOG, ranger,
	)
	var requirements := PackedStringArray(detail.get("requirement_lines", PackedStringArray()))
	var warnings := PackedStringArray(detail.get("equip_warning_lines", PackedStringArray()))
	TestAssertions.truthy("Requires all: Martial, Vanguard" in requirements, "tag requirements are player-readable", failures)
	TestAssertions.truthy("Ranger lacks required tag: Vanguard" in warnings, "unmet class tag is explicit", failures)


func _item_with_stout_roll(value: float) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = "projector-item"
	item.base_definition_id = &"windrunner_band"
	item.rarity_id = &"uncommon"
	item.item_level = 31
	var affix := ItemAffixInstance.new()
	affix.definition_id = &"stout"
	affix.affix_kind = "prefix"
	affix.tier = 2
	var roll := ItemModifierRoll.new()
	roll.stat_id = &"constitution"
	roll.operation = StatModifier.Operation.FLAT
	roll.value = value
	affix.rolls.append(roll)
	item.affixes.append(affix)
	return item
