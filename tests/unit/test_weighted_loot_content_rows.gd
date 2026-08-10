extends RefCounted

const MANIFEST_PATH := "res://tools/weighted_loot_content_rows.gd"
const EXPECTED_LEVELS := [1, 10, 30, 60, 100, 160, 240, 340, 460, 600, 770, 950]
const EXPECTED_TIER_WEIGHTS := [1000.0, 800.0, 640.0, 500.0, 380.0, 280.0, 200.0, 140.0, 90.0, 55.0, 30.0, 15.0]
const EXPECTED_FOCUSED_PREFIX_IDS := [
	&"stout", &"keen", &"wise", &"forceful", &"brutal", &"deadeye", &"arcane", &"tempered",
	&"searing", &"glacial", &"stormcharged", &"profane", &"vital", &"robust", &"plated", &"reinforced",
	&"benevolent", &"commanding", &"potent_weapon", &"duelist", &"farshot", &"spellwoven", &"martial_edge",
	&"pyromantic", &"cryomantic", &"tempestuous", &"voidtouched", &"juggernaut", &"ironclad", &"towerborn",
	&"merciful", &"inspiring",
]
const EXPECTED_FOCUSED_SUFFIX_IDS := [
	&"of_embers", &"of_rime", &"of_reach", &"of_might", &"of_agility", &"of_endurance", &"of_intellect",
	&"of_insight", &"of_presence", &"of_fire_ward", &"of_cold_ward", &"of_lightning_ward", &"of_chaos_ward",
	&"of_precision", &"of_ferocity", &"of_alacrity", &"of_recovery", &"of_velocity", &"of_expansion",
	&"of_the_wind", &"of_gathering", &"of_evasion", &"of_guarding", &"of_deflection", &"of_vigor", &"of_drain",
	&"of_the_duelist", &"of_the_marksman", &"of_the_savant", &"of_the_healer", &"of_martial_haste", &"of_arcane_focus",
]
const EXPECTED_STANDARD_PREFIX_IDS := [
	&"battle_hardened", &"hunter_born", &"spell_forged", &"elemental_fury", &"stormfire", &"winter_storm",
	&"voidflame", &"unyielding_force", &"bloodbound", &"sacred_guard", &"fortified_vitality", &"commanding_presence",
]
const EXPECTED_STANDARD_SUFFIX_IDS := [
	&"of_swiftness", &"of_deadly_precision", &"of_guarded_resolve", &"of_restoration", &"of_exploration",
	&"of_the_pyromancer", &"of_the_cryomancer", &"of_the_stormcaller", &"of_the_occultist", &"of_balanced_form",
	&"of_martial_mastery", &"of_arcane_mastery",
]
const EXPECTED_PREMIUM_PREFIX_IDS := [&"apex_force", &"eternal_bulwark", &"primal_convergence", &"sovereign_magic"]
const EXPECTED_PREMIUM_SUFFIX_IDS := [&"of_perfect_form", &"of_inexorable_time", &"of_boundless_reach", &"of_royal_command"]
const RETAINED_NAMES := {
	&"stout": "Stout", &"keen": "Keen", &"wise": "Wise",
	&"of_embers": "of Embers", &"of_rime": "of Rime", &"of_reach": "of Reach",
}
const CURVE_ENDPOINTS := {
	&"flat_attribute": [Vector2(1.0, 3.0), Vector2(70.0, 90.0), 1.0],
	&"flat_health": [Vector2(5.0, 10.0), Vector2(400.0, 550.0), 0.01],
	&"flat_armor": [Vector2(2.0, 4.0), Vector2(200.0, 280.0), 0.01],
	&"flat_party_influence": [Vector2(1.0, 2.0), Vector2(60.0, 80.0), 1.0],
	&"flat_regeneration": [Vector2(0.5, 1.0), Vector2(25.0, 35.0), 0.01],
	&"flat_ratio": [Vector2(0.01, 0.02), Vector2(0.18, 0.25), 0.001],
	&"flat_crit_multiplier": [Vector2(0.05, 0.10), Vector2(0.80, 1.20), 0.001],
	&"increased_multiplier": [Vector2(0.04, 0.08), Vector2(0.75, 1.00), 0.001],
}
const LEGACY_TIER_BOUNDS := {
	&"stout": [Vector2(1, 3), Vector2(4, 6), Vector2(7, 10)],
	&"keen": [Vector2(1, 3), Vector2(4, 6), Vector2(7, 10)],
	&"wise": [Vector2(1, 3), Vector2(4, 6), Vector2(7, 10)],
	&"of_embers": [Vector2(0.05, 0.10), Vector2(0.11, 0.20), Vector2(0.21, 0.30)],
	&"of_rime": [Vector2(0.05, 0.10), Vector2(0.11, 0.20), Vector2(0.21, 0.30)],
	&"of_reach": [Vector2(0.05, 0.10), Vector2(0.11, 0.20), Vector2(0.21, 0.30)],
}
const KNOWN_HARD_TAGS := [&"", &"weapon", &"one_hand_sword", &"bow", &"caster", &"melee", &"heavy", &"shield", &"tome", &"accessory"]
const KNOWN_AFFINITIES := [&"melee", &"ranged", &"caster"]
const SLOT_PRIORITY := [&"helmet", &"body_armour", &"legs", &"gloves", &"boots", &"amulet", &"ring_left", &"ring_right", &"belt", &"main_hand", &"off_hand"]
const EXPECTED_SLOT_STATS := {
	&"helmet": &"max_health", &"body_armour": &"armor", &"legs": &"move_speed", &"gloves": &"attack_speed",
	&"boots": &"dodge_chance", &"amulet": &"party_influence", &"ring_left": &"crit_chance",
	&"ring_right": &"crit_chance", &"belt": &"health_regeneration",
}
const EXPECTED_PROFILE_ROWS := [
	{"base": &"forge_vanguard_sword", "type": &"physical", "l1": Vector2(7, 11), "l1000": Vector2(260, 390)},
	{"base": &"forge_vanguard_hammer", "type": &"physical", "l1": Vector2(9, 14), "l1000": Vector2(310, 470)},
	{"base": &"sunforged_warhammer", "type": &"physical", "l1": Vector2(12, 18), "l1000": Vector2(380, 570)},
	{"base": &"greenwood_recurve_bow", "type": &"physical", "l1": Vector2(6, 10), "l1000": Vector2(240, 360)},
	{"base": &"siege_greatbow", "type": &"physical", "l1": Vector2(12, 20), "l1000": Vector2(400, 640)},
	{"base": &"nightstep_dagger_main", "type": &"physical", "l1": Vector2(5, 8), "l1000": Vector2(200, 320)},
	{"base": &"nightstep_dagger_off", "type": &"physical", "l1": Vector2(4, 7), "l1000": Vector2(180, 290)},
	{"base": &"emberweave_wand", "type": &"fire", "l1": Vector2(7, 11), "l1000": Vector2(270, 420)},
	{"base": &"grave_covenant_bone_wand", "type": &"chaos", "l1": Vector2(7, 11), "l1000": Vector2(270, 420)},
	{"base": &"rime_scholar_staff", "type": &"cold", "l1": Vector2(10, 16), "l1000": Vector2(350, 540)},
	{"base": &"storm_chaplain_sceptre", "type": &"lightning", "l1": Vector2(8, 13), "l1000": Vector2(300, 470)},
]
const EXPECTED_SUPPORT_BASE_IDS := [
	&"dawn_bulwark_shield", &"forge_vanguard_shield", &"greenwood_light_quiver", &"siege_heavy_quiver",
	&"emberweave_flame_focus", &"grave_covenant_grimoire", &"storm_chaplain_holy_tome",
]
const EXPECTED_SUPPORT_STATS := {
	&"dawn_bulwark_shield": &"block_chance", &"forge_vanguard_shield": &"block_chance",
	&"greenwood_light_quiver": &"ranged_damage", &"siege_heavy_quiver": &"ranged_damage",
	&"emberweave_flame_focus": &"caster_damage", &"grave_covenant_grimoire": &"caster_damage",
	&"storm_chaplain_holy_tome": &"caster_damage",
}

func run() -> Array[String]:
	var failures: Array[String] = []
	var manifest := load(MANIFEST_PATH) as Script
	TestAssertions.truthy(manifest != null, "weighted loot source manifest exists", failures)
	if manifest == null:
		return failures
	var rows: Array = manifest.call(&"explicit_rows")
	_assert_counts_and_order(rows, failures)
	_assert_exact_effect_matrix(rows, failures)
	_assert_metadata_and_tiers(manifest, rows, failures)
	TestAssertions.equal(manifest.call(&"explicit_rows"), rows, "Task 4 explicit rows remain deterministic", failures)
	var equipment := load("res://data/equipment/core_equipment_catalog.tres") as EquipmentCatalog
	TestAssertions.truthy(equipment != null, "live equipment catalog loads", failures)
	var has_implicit_rows := manifest.has_method(&"implicit_rows")
	var has_weapon_profile_rows := manifest.has_method(&"weapon_profile_rows")
	var has_support_base_ids := manifest.has_method(&"support_base_ids")
	TestAssertions.truthy(has_implicit_rows, "weighted loot source exposes implicit rows", failures)
	TestAssertions.truthy(has_weapon_profile_rows, "weighted loot source exposes weapon profile rows", failures)
	TestAssertions.truthy(has_support_base_ids, "weighted loot source exposes support base ids", failures)
	if equipment != null and has_implicit_rows:
		_assert_implicit_rows(manifest, equipment, failures)
	if equipment != null and has_weapon_profile_rows and has_support_base_ids:
		_assert_weapon_profiles_and_classification(manifest, equipment, failures)
	return failures

func _assert_implicit_rows(manifest: Script, equipment: EquipmentCatalog, failures: Array[String]) -> void:
	var rows: Array = manifest.call(&"implicit_rows", equipment)
	TestAssertions.equal(rows.size(), 99, "exact implicit total", failures)
	var expected_base_ids := _class_equipment_base_ids()
	var live_base_ids: Array[StringName] = []
	for base: EquipmentBaseDefinition in equipment.definitions:
		if base != null: live_base_ids.append(base.id)
	TestAssertions.equal(live_base_ids, expected_base_ids, "live equipment catalog exactly matches the class equipment manifest", failures)
	var actual_base_ids: Array[StringName] = []
	var seen_ids: Dictionary = {}
	var seen_names: Dictionary = {}
	var tempered_bases: Array[StringName] = []
	for row_variant: Variant in rows:
		var row := row_variant as Dictionary
		var base_id: StringName = row.get("base", &"")
		var base := equipment.definition(base_id)
		actual_base_ids.append(base_id)
		TestAssertions.truthy(base != null, "%s implicit assignment references a live base" % base_id, failures)
		if base == null: continue
		var id: StringName = row.get("id", &"")
		var display_name := String(row.get("display_name", ""))
		var expected_id := &"tempered_edge" if base_id == &"forge_vanguard_sword" else StringName("%s_implicit" % base_id)
		var expected_name := "Tempered Edge" if base_id == &"forge_vanguard_sword" else "%s Legacy" % base.display_name
		TestAssertions.equal(id, expected_id, "%s exact base-specific implicit id" % base_id, failures)
		TestAssertions.equal(display_name, expected_name, "%s exact base-specific implicit name" % base_id, failures)
		TestAssertions.truthy(not seen_ids.has(id), "%s implicit id is unique" % id, failures)
		TestAssertions.truthy(not seen_names.has(display_name), "%s implicit display name is unique" % id, failures)
		seen_ids[id] = true
		seen_names[display_name] = true
		if id == &"tempered_edge": tempered_bases.append(base_id)
		TestAssertions.equal(row.get("category", &""), &"implicit", "%s exact implicit category" % id, failures)
		TestAssertions.equal(row.get("base_weight", 0.0), 100.0, "%s exact implicit base weight" % id, failures)
		TestAssertions.equal(row.get("component_scale", 0.0), 1.0, "%s exact implicit component scale" % id, failures)
		TestAssertions.equal(row.get("required_item_tag", &"missing"), &"", "%s has no random-selection eligibility tag" % id, failures)
		TestAssertions.equal(row.get("affinity_tags", [&"unexpected"]), [], "%s has no soft affinity tag" % id, failures)
		var expected_family := StringName("implicit_%s" % base.implicit_family_id)
		TestAssertions.equal(row.get("modifier_family_ids", []), [expected_family], "%s exact implicit family" % id, failures)
		var template_slot := _canonical_slot(base.compatible_slot_ids)
		TestAssertions.equal(row.get("template_slot", &""), template_slot, "%s exact canonical template slot" % id, failures)
		for compatible_slot: StringName in base.compatible_slot_ids:
			TestAssertions.truthy(compatible_slot in SLOT_PRIORITY, "%s compatible slot %s has an implicit template policy" % [id, compatible_slot], failures)
		var expected_stat := _implicit_stat(base_id, template_slot)
		var effects: Array = row.get("effects", [])
		TestAssertions.equal(effects.size(), 1, "%s has exactly one implicit effect" % id, failures)
		if effects.size() == 1:
			var effect := effects[0] as Dictionary
			var expected_operation := _operation_for_stat(expected_stat)
			TestAssertions.equal(effect.get("stat_id", &""), expected_stat, "%s exact implicit stat" % id, failures)
			TestAssertions.truthy(GameCatalog.STAT_CATALOG.definition(expected_stat) != null, "%s implicit stat is live" % id, failures)
			TestAssertions.equal(effect.get("operation", -1), expected_operation, "%s exact implicit operation" % id, failures)
			TestAssertions.equal(effect.get("curve_key", &""), _curve_for(expected_stat, expected_operation), "%s exact implicit curve" % id, failures)
			TestAssertions.equal(effect.get("modifier_family_id", &""), expected_family, "%s effect uses the exact implicit family" % id, failures)
		var expected_path := "res://data/items/affixes/fixtures/tempered_edge.tres" if id == &"tempered_edge" else "res://data/items/affixes/production/implicits/%s.tres" % id
		TestAssertions.equal(row.get("output_path", ""), expected_path, "%s exact implicit output path" % id, failures)
		_assert_implicit_tiers(manifest, row, expected_stat, failures)
	TestAssertions.equal(actual_base_ids, expected_base_ids, "exactly one deterministic implicit assignment per live base", failures)
	TestAssertions.equal(tempered_bases, [&"forge_vanguard_sword"], "tempered_edge is retained only for the Forge Vanguard sword", failures)

func _assert_implicit_tiers(manifest: Script, row: Dictionary, stat_id: StringName, failures: Array[String]) -> void:
	var id: StringName = row["id"]
	var tiers: Array = row.get("tiers", [])
	TestAssertions.equal(tiers.size(), 12, "%s has exactly twelve shared tiers" % id, failures)
	var operation := _operation_for_stat(stat_id)
	var generated: Array = manifest.call(&"tier_rows", _curve_for(stat_id, operation), 1.0)
	for index: int in mini(tiers.size(), 12):
		var tier := tiers[index] as Dictionary
		TestAssertions.equal(tier.get("tier", 0), index + 1, "%s implicit tier number %d" % [id, index + 1], failures)
		TestAssertions.equal(tier.get("minimum_item_level", 0), EXPECTED_LEVELS[index], "%s implicit tier %d exact level" % [id, index + 1], failures)
		TestAssertions.equal(tier.get("base_weight", 0.0), EXPECTED_TIER_WEIGHTS[index], "%s implicit tier %d exact weight" % [id, index + 1], failures)
		var minimums: Array = tier.get("minimum_rolls", [])
		var maximums: Array = tier.get("maximum_rolls", [])
		TestAssertions.equal(minimums.size(), 1, "%s implicit tier %d minimum arity" % [id, index + 1], failures)
		TestAssertions.equal(maximums.size(), 1, "%s implicit tier %d maximum arity" % [id, index + 1], failures)
		if minimums.size() != 1 or maximums.size() != 1: continue
		var expected_bounds := Vector2(generated[index]["minimum"], generated[index]["maximum"])
		if id == &"tempered_edge":
			if index < 3:
				expected_bounds = [Vector2(0.05, 0.10), Vector2(0.11, 0.20), Vector2(0.21, 0.30)][index]
			else:
				var endpoints: Array = CURVE_ENDPOINTS[&"increased_multiplier"]
				var progress := pow((float(EXPECTED_LEVELS[index]) - 30.0) / 970.0, 1.20)
				expected_bounds = Vector2(
					_snap(lerpf(0.30, (endpoints[1] as Vector2).x, progress), float(endpoints[2])),
					_snap(lerpf(0.30, (endpoints[1] as Vector2).y, progress), float(endpoints[2])),
				)
		TestAssertions.equal(Vector2(minimums[0], maximums[0]), expected_bounds, "%s implicit tier %d exact bounds" % [id, index + 1], failures)

func _assert_weapon_profiles_and_classification(manifest: Script, equipment: EquipmentCatalog, failures: Array[String]) -> void:
	var rows: Array = manifest.call(&"weapon_profile_rows")
	var support_ids: Array = manifest.call(&"support_base_ids")
	TestAssertions.equal(rows.size(), 11, "exact weapon profile total", failures)
	TestAssertions.equal(support_ids, EXPECTED_SUPPORT_BASE_IDS, "exact explicit support base ids", failures)
	var profile_base_ids: Array[StringName] = []
	var seen_profile_ids: Dictionary = {}
	for index: int in mini(rows.size(), EXPECTED_PROFILE_ROWS.size()):
		var row := rows[index] as Dictionary
		var expected := EXPECTED_PROFILE_ROWS[index] as Dictionary
		var base_id: StringName = row.get("base", &"")
		var type_id: StringName = row.get("type", &"")
		profile_base_ids.append(base_id)
		TestAssertions.equal(base_id, expected["base"], "weapon profile %d exact base mapping" % index, failures)
		TestAssertions.equal(type_id, expected["type"], "%s exact damage type" % base_id, failures)
		TestAssertions.equal(row.get("l1", Vector2.ZERO), expected["l1"], "%s exact level-1 anchors" % base_id, failures)
		TestAssertions.equal(row.get("l1000", Vector2.ZERO), expected["l1000"], "%s exact level-1000 anchors" % base_id, failures)
		TestAssertions.equal(row.get("id", &""), StringName("weapon_profile_%s" % base_id), "%s deterministic profile id" % base_id, failures)
		TestAssertions.equal(row.get("output_path", ""), "res://data/items/weapon_profiles/%s.tres" % base_id, "%s deterministic profile path" % base_id, failures)
		TestAssertions.equal(row.get("minimum_item_level", 0), 1, "%s exact minimum item level" % base_id, failures)
		TestAssertions.equal(row.get("quality_minimum", 0.0), 0.85, "%s exact minimum quality" % base_id, failures)
		TestAssertions.equal(row.get("quality_maximum", 0.0), 1.00, "%s exact maximum quality" % base_id, failures)
		TestAssertions.equal(row.get("rarity_multipliers", {}), WeaponDamageProfile.RARITY_MULTIPLIERS, "%s uses the shared rarity map" % base_id, failures)
		TestAssertions.truthy(not seen_profile_ids.has(row.get("id", &"")), "%s profile id is unique" % base_id, failures)
		seen_profile_ids[row.get("id", &"")] = true
		TestAssertions.truthy(equipment.definition(base_id) != null, "%s profile base is live" % base_id, failures)
		TestAssertions.truthy(GameCatalog.DAMAGE_TYPES.definition(type_id) != null, "%s profile damage type is live" % base_id, failures)
		var components: Array = row.get("components", [])
		TestAssertions.equal(components.size(), 1, "%s has one explicit damage component" % base_id, failures)
		if components.size() == 1:
			var component := components[0] as Dictionary
			TestAssertions.equal(component.get("damage_type_id", &""), type_id, "%s component exact damage type" % base_id, failures)
			TestAssertions.equal(component.get("minimum_at_level_1", NAN), (expected["l1"] as Vector2).x, "%s component level-1 minimum" % base_id, failures)
			TestAssertions.equal(component.get("maximum_at_level_1", NAN), (expected["l1"] as Vector2).y, "%s component level-1 maximum" % base_id, failures)
			TestAssertions.equal(component.get("minimum_at_level_1000", NAN), (expected["l1000"] as Vector2).x, "%s component level-1000 minimum" % base_id, failures)
			TestAssertions.equal(component.get("maximum_at_level_1000", NAN), (expected["l1000"] as Vector2).y, "%s component level-1000 maximum" % base_id, failures)
	for support_id: StringName in support_ids:
		TestAssertions.truthy(equipment.definition(support_id) != null, "%s support base is live" % support_id, failures)
		TestAssertions.truthy(support_id not in profile_base_ids, "%s support base has no damage profile row" % support_id, failures)
	for base: EquipmentBaseDefinition in equipment.definitions:
		if base == null: continue
		var occupies_weapon_slot := &"main_hand" in base.compatible_slot_ids or &"off_hand" in base.compatible_slot_ids
		var classification_count := int(base.id in profile_base_ids) + int(base.id in support_ids) + int(not occupies_weapon_slot)
		TestAssertions.equal(classification_count, 1, "%s is exactly one of damage-profile, support, or non-weapon" % base.id, failures)

func _class_equipment_base_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for set_id: StringName in ClassEquipmentRows.SET_ITEM_IDS:
		for base_id: StringName in ClassEquipmentRows.SET_ITEM_IDS[set_id]: result.append(base_id)
	return result

func _canonical_slot(compatible_slots: Array[StringName]) -> StringName:
	for slot_id: StringName in SLOT_PRIORITY:
		if slot_id in compatible_slots: return slot_id
	return &""

func _implicit_stat(base_id: StringName, template_slot: StringName) -> StringName:
	if EXPECTED_SUPPORT_STATS.has(base_id): return EXPECTED_SUPPORT_STATS[base_id]
	for row: Dictionary in EXPECTED_PROFILE_ROWS:
		if row["base"] == base_id:
			var definition := GameCatalog.DAMAGE_TYPES.definition(row["type"])
			return definition.offense_stat_id if definition != null else &""
	return EXPECTED_SLOT_STATS.get(template_slot, &"")

func _assert_counts_and_order(rows: Array, failures: Array[String]) -> void:
	TestAssertions.equal(rows.size(), 96, "exact explicit affix total", failures)
	var expected_ids := EXPECTED_FOCUSED_PREFIX_IDS + EXPECTED_FOCUSED_SUFFIX_IDS + EXPECTED_STANDARD_PREFIX_IDS + EXPECTED_STANDARD_SUFFIX_IDS + EXPECTED_PREMIUM_PREFIX_IDS + EXPECTED_PREMIUM_SUFFIX_IDS
	var actual_ids: Array = []
	var seen_ids: Dictionary = {}
	var seen_names: Dictionary = {}
	var category_counts := {&"focused": 0, &"standard_hybrid": 0, &"premium_hybrid": 0}
	var side_counts := {&"prefix": 0, &"suffix": 0}
	for row_variant: Variant in rows:
		var row := row_variant as Dictionary
		var id: StringName = row.get("id", &"")
		var display_name := String(row.get("display_name", "")).strip_edges()
		actual_ids.append(id)
		TestAssertions.truthy(not id.is_empty(), "affix id is nonempty", failures)
		TestAssertions.truthy(not display_name.is_empty(), "%s display name is nonempty" % id, failures)
		TestAssertions.truthy(not seen_ids.has(id), "%s id is unique" % id, failures)
		TestAssertions.truthy(not seen_names.has(display_name), "%s display name is unique" % id, failures)
		seen_ids[id] = true
		seen_names[display_name] = true
		var category: StringName = row.get("category", &"")
		var side: StringName = row.get("side", &"")
		category_counts[category] = int(category_counts.get(category, 0)) + 1
		side_counts[side] = int(side_counts.get(side, 0)) + 1
	TestAssertions.equal(actual_ids, expected_ids, "exact deterministic affix ID order", failures)
	TestAssertions.equal(category_counts, {&"focused": 64, &"standard_hybrid": 24, &"premium_hybrid": 8}, "exact category totals", failures)
	TestAssertions.equal(side_counts, {&"prefix": 48, &"suffix": 48}, "exact prefix/suffix parity", failures)
	for id: StringName in RETAINED_NAMES:
		var row := _row_by_id(rows, id)
		TestAssertions.equal(row.get("display_name", ""), RETAINED_NAMES[id], "%s retains exact fixture name" % id, failures)
		TestAssertions.equal(row.get("side", &""), &"prefix" if id in [&"stout", &"keen", &"wise"] else &"suffix", "%s retains fixture kind" % id, failures)
		TestAssertions.equal(row.get("output_path", ""), "res://data/items/affixes/fixtures/%s.tres" % id, "%s retains fixture path" % id, failures)

func _assert_exact_effect_matrix(rows: Array, failures: Array[String]) -> void:
	var expected := _expected_effect_rows()
	TestAssertions.equal(expected.size(), 96, "test matrix covers every explicit affix", failures)
	for row_variant: Variant in rows:
		var row := row_variant as Dictionary
		var id: StringName = row["id"]
		TestAssertions.truthy(expected.has(id), "%s is in exact effect matrix" % id, failures)
		if not expected.has(id):
			continue
		var expected_effects: Array = expected[id]
		var effects: Array = row.get("effects", [])
		TestAssertions.equal(effects.size(), expected_effects.size(), "%s exact effect count" % id, failures)
		for index: int in mini(effects.size(), expected_effects.size()):
			var effect := effects[index] as Dictionary
			var expected_stat: StringName = expected_effects[index]
			var expected_operation := _expected_operation(id, expected_stat)
			TestAssertions.equal(effect.get("stat_id", &""), expected_stat, "%s effect %d exact stat" % [id, index], failures)
			TestAssertions.truthy(GameCatalog.STAT_CATALOG.definition(expected_stat) != null, "%s effect %d stat is live" % [id, index], failures)
			TestAssertions.equal(effect.get("operation", -1), expected_operation, "%s effect %d exact operation" % [id, index], failures)
			TestAssertions.equal(effect.get("curve_key", &""), _curve_for(expected_stat, expected_operation), "%s effect %d exact curve" % [id, index], failures)
			TestAssertions.equal(effect.get("modifier_family_id", &""), _family_for(expected_stat, expected_operation), "%s effect %d semantic family" % [id, index], failures)
		var expected_tag: StringName = _expected_required_tag(id)
		TestAssertions.equal(row.get("required_item_tag", &""), expected_tag, "%s exact hard eligibility tag" % id, failures)
		TestAssertions.truthy(expected_tag in KNOWN_HARD_TAGS, "%s hard tag is known" % id, failures)
		TestAssertions.truthy(expected_tag.is_empty() or expected_tag in GameCatalog.ITEM_FOUNDATION_CATALOG.known_item_tags, "%s hard tag is in the live foundation vocabulary" % id, failures)
		var families: Array = row.get("modifier_family_ids", [])
		TestAssertions.equal(families.size(), expected_effects.size(), "%s has one conflict family per component" % id, failures)
		for family: StringName in families:
			TestAssertions.truthy(not family.is_empty(), "%s conflict family is nonempty" % id, failures)
		for affinity: StringName in row.get("affinity_tags", []):
			TestAssertions.truthy(affinity in KNOWN_AFFINITIES, "%s affinity %s is live" % [id, affinity], failures)
			TestAssertions.truthy(affinity in GameCatalog.ITEM_FOUNDATION_CATALOG.known_item_tags, "%s affinity %s is in the live foundation vocabulary" % [id, affinity], failures)
		TestAssertions.equal(row.get("affinity_tags", []), _expected_affinities(expected_effects), "%s exact soft affinities" % id, failures)
	_assert_specialized_conflicts(rows, failures)

func _assert_metadata_and_tiers(manifest: Script, rows: Array, failures: Array[String]) -> void:
	for row_variant: Variant in rows:
		var row := row_variant as Dictionary
		var id: StringName = row["id"]
		var category: StringName = row["category"]
		var expected_weight := 1000.0 if category == &"focused" and StringName(row.get("required_item_tag", &"")).is_empty() else 500.0
		if category == &"standard_hybrid": expected_weight = 150.0
		if category == &"premium_hybrid": expected_weight = 25.0
		var expected_scale := 1.0 if category == &"focused" else (0.70 if category == &"standard_hybrid" else 0.85)
		TestAssertions.equal(row.get("base_weight", 0.0), expected_weight, "%s exact affix weight band" % id, failures)
		TestAssertions.equal(row.get("component_scale", 0.0), expected_scale, "%s exact component scale" % id, failures)
		var expected_path := "res://data/items/affixes/production/%s/%s.tres" % [category, id]
		if RETAINED_NAMES.has(id): expected_path = "res://data/items/affixes/fixtures/%s.tres" % id
		TestAssertions.equal(row.get("display_name", ""), _expected_name(id), "%s exact deterministic display name" % id, failures)
		TestAssertions.equal(row.get("output_path", ""), expected_path, "%s deterministic output path" % id, failures)
		var tiers: Array = row.get("tiers", [])
		TestAssertions.equal(tiers.size(), 12, "%s has exactly twelve tiers" % id, failures)
		for tier_index: int in mini(tiers.size(), 12):
			var tier := tiers[tier_index] as Dictionary
			TestAssertions.equal(tier.get("tier", 0), tier_index + 1, "%s tier number %d" % [id, tier_index + 1], failures)
			TestAssertions.equal(tier.get("minimum_item_level", 0), EXPECTED_LEVELS[tier_index], "%s tier %d exact item level" % [id, tier_index + 1], failures)
			TestAssertions.equal(tier.get("base_weight", 0.0), EXPECTED_TIER_WEIGHTS[tier_index], "%s tier %d exact weight" % [id, tier_index + 1], failures)
			var minimums: Array = tier.get("minimum_rolls", [])
			var maximums: Array = tier.get("maximum_rolls", [])
			TestAssertions.equal(minimums.size(), (row["effects"] as Array).size(), "%s tier %d minimum roll arity" % [id, tier_index + 1], failures)
			TestAssertions.equal(maximums.size(), (row["effects"] as Array).size(), "%s tier %d maximum roll arity" % [id, tier_index + 1], failures)
			for effect_index: int in mini(minimums.size(), maximums.size()):
				TestAssertions.truthy(float(minimums[effect_index]) <= float(maximums[effect_index]), "%s tier %d effect %d valid range" % [id, tier_index + 1, effect_index], failures)
				if tier_index > 0:
					var previous := tiers[tier_index - 1] as Dictionary
					TestAssertions.truthy(float(minimums[effect_index]) >= float((previous["minimum_rolls"] as Array)[effect_index]), "%s effect %d minima are monotonic" % [id, effect_index], failures)
					TestAssertions.truthy(float(maximums[effect_index]) >= float((previous["maximum_rolls"] as Array)[effect_index]), "%s effect %d maxima are monotonic" % [id, effect_index], failures)
		if LEGACY_TIER_BOUNDS.has(id):
			for tier_index: int in 3:
				var tier := tiers[tier_index] as Dictionary
				var bounds: Vector2 = LEGACY_TIER_BOUNDS[id][tier_index]
				TestAssertions.equal((tier["minimum_rolls"] as Array)[0], bounds.x, "%s legacy tier %d minimum" % [id, tier_index + 1], failures)
				TestAssertions.equal((tier["maximum_rolls"] as Array)[0], bounds.y, "%s legacy tier %d maximum" % [id, tier_index + 1], failures)
	for curve_key: StringName in CURVE_ENDPOINTS:
		for scale: float in [1.0, 0.70, 0.85]:
			_assert_tier_curve(manifest, curve_key, scale, failures)

func _assert_tier_curve(manifest: Script, curve_key: StringName, scale: float, failures: Array[String]) -> void:
	var tiers: Array = manifest.call(&"tier_rows", curve_key, scale)
	TestAssertions.equal(tiers.size(), 12, "%s scale %.2f tier count" % [curve_key, scale], failures)
	var endpoints: Array = CURVE_ENDPOINTS[curve_key]
	for index: int in mini(tiers.size(), 12):
		var tier := tiers[index] as Dictionary
		var progress := pow((float(EXPECTED_LEVELS[index]) - 1.0) / 999.0, 1.20)
		var expected_minimum := _snap(lerpf((endpoints[0] as Vector2).x, (endpoints[1] as Vector2).x, progress) * scale, float(endpoints[2]))
		var expected_maximum := _snap(lerpf((endpoints[0] as Vector2).y, (endpoints[1] as Vector2).y, progress) * scale, float(endpoints[2]))
		TestAssertions.equal(tier.get("minimum", NAN), expected_minimum, "%s scale %.2f tier %d minimum" % [curve_key, scale, index + 1], failures)
		TestAssertions.equal(tier.get("maximum", NAN), expected_maximum, "%s scale %.2f tier %d maximum" % [curve_key, scale, index + 1], failures)

func _assert_specialized_conflicts(rows: Array, failures: Array[String]) -> void:
	for row_variant: Variant in rows:
		var row := row_variant as Dictionary
		if row["category"] != &"focused" or StringName(row["required_item_tag"]).is_empty():
			continue
		for effect_variant: Variant in row["effects"]:
			var effect := effect_variant as Dictionary
			var broad := _broad_row_for(rows, effect["stat_id"], effect["operation"])
			TestAssertions.truthy(not broad.is_empty(), "%s specialized effect has broad equivalent" % row["id"], failures)
			if not broad.is_empty():
				TestAssertions.truthy(effect["modifier_family_id"] in broad["modifier_family_ids"], "%s conflicts with broad %s" % [row["id"], broad["id"]], failures)

func _broad_row_for(rows: Array, stat_id: StringName, operation: int) -> Dictionary:
	for row_variant: Variant in rows:
		var row := row_variant as Dictionary
		if row["category"] != &"focused" or not StringName(row["required_item_tag"]).is_empty(): continue
		for effect_variant: Variant in row["effects"]:
			var effect := effect_variant as Dictionary
			if effect["stat_id"] == stat_id and effect["operation"] == operation: return row
	return {}

func _row_by_id(rows: Array, id: StringName) -> Dictionary:
	for row_variant: Variant in rows:
		var row := row_variant as Dictionary
		if row.get("id", &"") == id: return row
	return {}

func _expected_effect_rows() -> Dictionary:
	var result := {
		&"stout": [&"constitution"], &"keen": [&"dexterity"], &"wise": [&"wisdom"], &"forceful": [&"damage"],
		&"brutal": [&"melee_damage"], &"deadeye": [&"ranged_damage"], &"arcane": [&"caster_damage"], &"tempered": [&"physical_damage"],
		&"searing": [&"fire_damage"], &"glacial": [&"cold_damage"], &"stormcharged": [&"lightning_damage"], &"profane": [&"chaos_damage"],
		&"vital": [&"max_health"], &"robust": [&"max_health"], &"plated": [&"armor"], &"reinforced": [&"armor"],
		&"benevolent": [&"healing_power"], &"commanding": [&"party_influence"], &"potent_weapon": [&"damage"], &"duelist": [&"melee_damage"],
		&"farshot": [&"ranged_damage"], &"spellwoven": [&"caster_damage"], &"martial_edge": [&"physical_damage"], &"pyromantic": [&"fire_damage"],
		&"cryomantic": [&"cold_damage"], &"tempestuous": [&"lightning_damage"], &"voidtouched": [&"chaos_damage"], &"juggernaut": [&"max_health"],
		&"ironclad": [&"armor"], &"towerborn": [&"armor"], &"merciful": [&"healing_power"], &"inspiring": [&"party_influence"],
		&"of_embers": [&"fire_damage"], &"of_rime": [&"cold_damage"], &"of_reach": [&"attack_range"], &"of_might": [&"strength"],
		&"of_agility": [&"dexterity"], &"of_endurance": [&"constitution"], &"of_intellect": [&"intelligence"], &"of_insight": [&"wisdom"],
		&"of_presence": [&"charisma"], &"of_fire_ward": [&"fire_resistance"], &"of_cold_ward": [&"cold_resistance"],
		&"of_lightning_ward": [&"lightning_resistance"], &"of_chaos_ward": [&"chaos_resistance"], &"of_precision": [&"crit_chance"],
		&"of_ferocity": [&"crit_multiplier"], &"of_alacrity": [&"attack_speed"], &"of_recovery": [&"cooldown_rate"],
		&"of_velocity": [&"projectile_speed"], &"of_expansion": [&"area_size"], &"of_the_wind": [&"move_speed"],
		&"of_gathering": [&"pickup_radius"], &"of_evasion": [&"dodge_chance"], &"of_guarding": [&"block_chance"],
		&"of_deflection": [&"block_effectiveness"], &"of_vigor": [&"health_regeneration"], &"of_drain": [&"life_steal"],
		&"of_the_duelist": [&"strength"], &"of_the_marksman": [&"dexterity"], &"of_the_savant": [&"intelligence"],
		&"of_the_healer": [&"wisdom"], &"of_martial_haste": [&"attack_speed"], &"of_arcane_focus": [&"cooldown_rate"],
	}
	result.merge({
		&"battle_hardened": [&"melee_damage", &"armor"], &"hunter_born": [&"ranged_damage", &"attack_range"],
		&"spell_forged": [&"caster_damage", &"area_size"], &"elemental_fury": [&"fire_damage", &"cold_damage"],
		&"stormfire": [&"fire_damage", &"lightning_damage"], &"winter_storm": [&"cold_damage", &"lightning_damage"],
		&"voidflame": [&"chaos_damage", &"fire_damage"], &"unyielding_force": [&"damage", &"max_health"],
		&"bloodbound": [&"damage", &"life_steal"], &"sacred_guard": [&"healing_power", &"armor"],
		&"fortified_vitality": [&"max_health", &"armor"], &"commanding_presence": [&"damage", &"party_influence"],
		&"of_swiftness": [&"attack_speed", &"move_speed"], &"of_deadly_precision": [&"crit_chance", &"crit_multiplier"],
		&"of_guarded_resolve": [&"block_chance", &"block_effectiveness"], &"of_restoration": [&"health_regeneration", &"cooldown_rate"],
		&"of_exploration": [&"move_speed", &"pickup_radius"], &"of_the_pyromancer": [&"fire_damage", &"fire_resistance"],
		&"of_the_cryomancer": [&"cold_damage", &"cold_resistance"], &"of_the_stormcaller": [&"lightning_damage", &"lightning_resistance"],
		&"of_the_occultist": [&"chaos_damage", &"chaos_resistance"], &"of_balanced_form": [&"dodge_chance", &"block_chance"],
		&"of_martial_mastery": [&"strength", &"dexterity"], &"of_arcane_mastery": [&"intelligence", &"wisdom"],
		&"apex_force": [&"damage", &"crit_multiplier"], &"eternal_bulwark": [&"max_health", &"armor"],
		&"primal_convergence": [&"physical_damage", &"attack_speed"], &"sovereign_magic": [&"caster_damage", &"healing_power"],
		&"of_perfect_form": [&"dodge_chance", &"move_speed"], &"of_inexorable_time": [&"attack_speed", &"cooldown_rate"],
		&"of_boundless_reach": [&"attack_range", &"area_size"], &"of_royal_command": [&"charisma", &"party_influence"],
	})
	return result

func _expected_required_tag(id: StringName) -> StringName:
	var tags := {
		&"potent_weapon": &"weapon", &"duelist": &"one_hand_sword", &"farshot": &"bow", &"spellwoven": &"caster",
		&"martial_edge": &"melee", &"pyromantic": &"caster", &"cryomantic": &"caster", &"tempestuous": &"caster",
		&"voidtouched": &"caster", &"juggernaut": &"heavy", &"ironclad": &"heavy", &"towerborn": &"shield",
		&"merciful": &"tome", &"inspiring": &"accessory", &"of_the_duelist": &"one_hand_sword", &"of_the_marksman": &"bow",
		&"of_the_savant": &"caster", &"of_the_healer": &"tome", &"of_martial_haste": &"melee", &"of_arcane_focus": &"caster",
	}
	return tags.get(id, &"")

func _operation_for_stat(stat_id: StringName) -> int:
	return StatModifier.Operation.FLAT if stat_id in [
		&"strength", &"dexterity", &"constitution", &"intelligence", &"wisdom", &"charisma", &"max_health", &"armor",
		&"party_influence", &"health_regeneration", &"fire_resistance", &"cold_resistance", &"lightning_resistance",
		&"chaos_resistance", &"crit_chance", &"crit_multiplier", &"dodge_chance", &"block_chance", &"block_effectiveness", &"life_steal",
	] else StatModifier.Operation.INCREASED

func _expected_operation(id: StringName, stat_id: StringName) -> int:
	if id in EXPECTED_FOCUSED_PREFIX_IDS + EXPECTED_FOCUSED_SUFFIX_IDS:
		return StatModifier.Operation.FLAT if id in [
			&"stout", &"keen", &"wise", &"vital", &"plated", &"commanding", &"juggernaut", &"ironclad", &"inspiring",
			&"of_might", &"of_agility", &"of_endurance", &"of_intellect", &"of_insight", &"of_presence", &"of_fire_ward",
			&"of_cold_ward", &"of_lightning_ward", &"of_chaos_ward", &"of_precision", &"of_ferocity", &"of_evasion",
			&"of_guarding", &"of_deflection", &"of_vigor", &"of_drain", &"of_the_duelist", &"of_the_marksman",
			&"of_the_savant", &"of_the_healer",
		] else StatModifier.Operation.INCREASED
	return _operation_for_stat(stat_id)

func _expected_name(id: StringName) -> String:
	if RETAINED_NAMES.has(id): return RETAINED_NAMES[id]
	var source := String(id)
	if source.begins_with("of_"): return "of %s" % source.trim_prefix("of_").replace("_", " ").capitalize()
	return source.replace("_", " ").capitalize()

func _curve_for(stat_id: StringName, operation: int) -> StringName:
	if operation == StatModifier.Operation.INCREASED: return &"increased_multiplier"
	if stat_id in [&"strength", &"dexterity", &"constitution", &"intelligence", &"wisdom", &"charisma"]: return &"flat_attribute"
	if stat_id == &"max_health": return &"flat_health"
	if stat_id == &"armor": return &"flat_armor"
	if stat_id == &"party_influence": return &"flat_party_influence"
	if stat_id == &"health_regeneration": return &"flat_regeneration"
	if stat_id == &"crit_multiplier": return &"flat_crit_multiplier"
	return &"flat_ratio"

func _family_for(stat_id: StringName, operation: int) -> StringName:
	return StringName("%s_%s" % [stat_id, "flat" if operation == StatModifier.Operation.FLAT else "increased"])

func _expected_affinities(stats: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	var groups := {
		&"melee": [&"melee_damage", &"strength", &"physical_damage", &"armor", &"block_chance", &"block_effectiveness"],
		&"ranged": [&"ranged_damage", &"dexterity", &"attack_range", &"projectile_speed", &"move_speed", &"dodge_chance"],
		&"caster": [&"caster_damage", &"intelligence", &"wisdom", &"healing_power", &"area_size", &"cooldown_rate", &"fire_damage", &"cold_damage", &"lightning_damage", &"chaos_damage", &"fire_resistance", &"cold_resistance", &"lightning_resistance", &"chaos_resistance"],
	}
	for affinity: StringName in KNOWN_AFFINITIES:
		for stat: StringName in stats:
			if stat in groups[affinity]:
				result.append(affinity)
				break
	return result

func _snap(value: float, step: float) -> float:
	return snappedf(value, step)
