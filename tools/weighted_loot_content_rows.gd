class_name WeightedLootContentRows
extends RefCounted

const TIER_MINIMUM_LEVELS := [1, 10, 30, 60, 100, 160, 240, 340, 460, 600, 770, 950]
const TIER_WEIGHTS := [1000.0, 800.0, 640.0, 500.0, 380.0, 280.0, 200.0, 140.0, 90.0, 55.0, 30.0, 15.0]
const CURVE_EXPONENT := 1.20

const FOCUSED_PREFIX_IDS := [
	&"stout", &"keen", &"wise", &"forceful", &"brutal", &"deadeye", &"arcane", &"tempered",
	&"searing", &"glacial", &"stormcharged", &"profane", &"vital", &"robust", &"plated", &"reinforced",
	&"benevolent", &"commanding", &"potent_weapon", &"duelist", &"farshot", &"spellwoven", &"martial_edge",
	&"pyromantic", &"cryomantic", &"tempestuous", &"voidtouched", &"juggernaut", &"ironclad", &"towerborn",
	&"merciful", &"inspiring",
]
const FOCUSED_SUFFIX_IDS := [
	&"of_embers", &"of_rime", &"of_reach", &"of_might", &"of_agility", &"of_endurance", &"of_intellect",
	&"of_insight", &"of_presence", &"of_fire_ward", &"of_cold_ward", &"of_lightning_ward", &"of_chaos_ward",
	&"of_precision", &"of_ferocity", &"of_alacrity", &"of_recovery", &"of_velocity", &"of_expansion",
	&"of_the_wind", &"of_gathering", &"of_evasion", &"of_guarding", &"of_deflection", &"of_vigor", &"of_drain",
	&"of_the_duelist", &"of_the_marksman", &"of_the_savant", &"of_the_healer", &"of_martial_haste", &"of_arcane_focus",
]
const STANDARD_PREFIX_IDS := [
	&"battle_hardened", &"hunter_born", &"spell_forged", &"elemental_fury", &"stormfire", &"winter_storm",
	&"voidflame", &"unyielding_force", &"bloodbound", &"sacred_guard", &"fortified_vitality", &"commanding_presence",
]
const STANDARD_SUFFIX_IDS := [
	&"of_swiftness", &"of_deadly_precision", &"of_guarded_resolve", &"of_restoration", &"of_exploration",
	&"of_the_pyromancer", &"of_the_cryomancer", &"of_the_stormcaller", &"of_the_occultist", &"of_balanced_form",
	&"of_martial_mastery", &"of_arcane_mastery",
]
const PREMIUM_PREFIX_IDS := [&"apex_force", &"eternal_bulwark", &"primal_convergence", &"sovereign_magic"]
const PREMIUM_SUFFIX_IDS := [&"of_perfect_form", &"of_inexorable_time", &"of_boundless_reach", &"of_royal_command"]

const FOCUSED_PREFIX_EFFECTS := [
	[&"stout", &"constitution", StatModifier.Operation.FLAT, &""],
	[&"keen", &"dexterity", StatModifier.Operation.FLAT, &""],
	[&"wise", &"wisdom", StatModifier.Operation.FLAT, &""],
	[&"forceful", &"damage", StatModifier.Operation.INCREASED, &""],
	[&"brutal", &"melee_damage", StatModifier.Operation.INCREASED, &""],
	[&"deadeye", &"ranged_damage", StatModifier.Operation.INCREASED, &""],
	[&"arcane", &"caster_damage", StatModifier.Operation.INCREASED, &""],
	[&"tempered", &"physical_damage", StatModifier.Operation.INCREASED, &""],
	[&"searing", &"fire_damage", StatModifier.Operation.INCREASED, &""],
	[&"glacial", &"cold_damage", StatModifier.Operation.INCREASED, &""],
	[&"stormcharged", &"lightning_damage", StatModifier.Operation.INCREASED, &""],
	[&"profane", &"chaos_damage", StatModifier.Operation.INCREASED, &""],
	[&"vital", &"max_health", StatModifier.Operation.FLAT, &""],
	[&"robust", &"max_health", StatModifier.Operation.INCREASED, &""],
	[&"plated", &"armor", StatModifier.Operation.FLAT, &""],
	[&"reinforced", &"armor", StatModifier.Operation.INCREASED, &""],
	[&"benevolent", &"healing_power", StatModifier.Operation.INCREASED, &""],
	[&"commanding", &"party_influence", StatModifier.Operation.FLAT, &""],
	[&"potent_weapon", &"damage", StatModifier.Operation.INCREASED, &"weapon"],
	[&"duelist", &"melee_damage", StatModifier.Operation.INCREASED, &"one_hand_sword"],
	[&"farshot", &"ranged_damage", StatModifier.Operation.INCREASED, &"bow"],
	[&"spellwoven", &"caster_damage", StatModifier.Operation.INCREASED, &"caster"],
	[&"martial_edge", &"physical_damage", StatModifier.Operation.INCREASED, &"melee"],
	[&"pyromantic", &"fire_damage", StatModifier.Operation.INCREASED, &"caster"],
	[&"cryomantic", &"cold_damage", StatModifier.Operation.INCREASED, &"caster"],
	[&"tempestuous", &"lightning_damage", StatModifier.Operation.INCREASED, &"caster"],
	[&"voidtouched", &"chaos_damage", StatModifier.Operation.INCREASED, &"caster"],
	[&"juggernaut", &"max_health", StatModifier.Operation.FLAT, &"heavy"],
	[&"ironclad", &"armor", StatModifier.Operation.FLAT, &"heavy"],
	[&"towerborn", &"armor", StatModifier.Operation.INCREASED, &"shield"],
	[&"merciful", &"healing_power", StatModifier.Operation.INCREASED, &"tome"],
	[&"inspiring", &"party_influence", StatModifier.Operation.FLAT, &"accessory"],
]

const FOCUSED_SUFFIX_EFFECTS := [
	[&"of_embers", &"fire_damage", StatModifier.Operation.INCREASED, &""],
	[&"of_rime", &"cold_damage", StatModifier.Operation.INCREASED, &""],
	[&"of_reach", &"attack_range", StatModifier.Operation.INCREASED, &""],
	[&"of_might", &"strength", StatModifier.Operation.FLAT, &""],
	[&"of_agility", &"dexterity", StatModifier.Operation.FLAT, &""],
	[&"of_endurance", &"constitution", StatModifier.Operation.FLAT, &""],
	[&"of_intellect", &"intelligence", StatModifier.Operation.FLAT, &""],
	[&"of_insight", &"wisdom", StatModifier.Operation.FLAT, &""],
	[&"of_presence", &"charisma", StatModifier.Operation.FLAT, &""],
	[&"of_fire_ward", &"fire_resistance", StatModifier.Operation.FLAT, &""],
	[&"of_cold_ward", &"cold_resistance", StatModifier.Operation.FLAT, &""],
	[&"of_lightning_ward", &"lightning_resistance", StatModifier.Operation.FLAT, &""],
	[&"of_chaos_ward", &"chaos_resistance", StatModifier.Operation.FLAT, &""],
	[&"of_precision", &"crit_chance", StatModifier.Operation.FLAT, &""],
	[&"of_ferocity", &"crit_multiplier", StatModifier.Operation.FLAT, &""],
	[&"of_alacrity", &"attack_speed", StatModifier.Operation.INCREASED, &""],
	[&"of_recovery", &"cooldown_rate", StatModifier.Operation.INCREASED, &""],
	[&"of_velocity", &"projectile_speed", StatModifier.Operation.INCREASED, &""],
	[&"of_expansion", &"area_size", StatModifier.Operation.INCREASED, &""],
	[&"of_the_wind", &"move_speed", StatModifier.Operation.INCREASED, &""],
	[&"of_gathering", &"pickup_radius", StatModifier.Operation.INCREASED, &""],
	[&"of_evasion", &"dodge_chance", StatModifier.Operation.FLAT, &""],
	[&"of_guarding", &"block_chance", StatModifier.Operation.FLAT, &""],
	[&"of_deflection", &"block_effectiveness", StatModifier.Operation.FLAT, &""],
	[&"of_vigor", &"health_regeneration", StatModifier.Operation.FLAT, &""],
	[&"of_drain", &"life_steal", StatModifier.Operation.FLAT, &""],
	[&"of_the_duelist", &"strength", StatModifier.Operation.FLAT, &"one_hand_sword"],
	[&"of_the_marksman", &"dexterity", StatModifier.Operation.FLAT, &"bow"],
	[&"of_the_savant", &"intelligence", StatModifier.Operation.FLAT, &"caster"],
	[&"of_the_healer", &"wisdom", StatModifier.Operation.FLAT, &"tome"],
	[&"of_martial_haste", &"attack_speed", StatModifier.Operation.INCREASED, &"melee"],
	[&"of_arcane_focus", &"cooldown_rate", StatModifier.Operation.INCREASED, &"caster"],
]

const HYBRID_EFFECTS := {
	&"battle_hardened": [&"melee_damage", &"armor"],
	&"hunter_born": [&"ranged_damage", &"attack_range"],
	&"spell_forged": [&"caster_damage", &"area_size"],
	&"elemental_fury": [&"fire_damage", &"cold_damage"],
	&"stormfire": [&"fire_damage", &"lightning_damage"],
	&"winter_storm": [&"cold_damage", &"lightning_damage"],
	&"voidflame": [&"chaos_damage", &"fire_damage"],
	&"unyielding_force": [&"damage", &"max_health"],
	&"bloodbound": [&"damage", &"life_steal"],
	&"sacred_guard": [&"healing_power", &"armor"],
	&"fortified_vitality": [&"max_health", &"armor"],
	&"commanding_presence": [&"damage", &"party_influence"],
	&"of_swiftness": [&"attack_speed", &"move_speed"],
	&"of_deadly_precision": [&"crit_chance", &"crit_multiplier"],
	&"of_guarded_resolve": [&"block_chance", &"block_effectiveness"],
	&"of_restoration": [&"health_regeneration", &"cooldown_rate"],
	&"of_exploration": [&"move_speed", &"pickup_radius"],
	&"of_the_pyromancer": [&"fire_damage", &"fire_resistance"],
	&"of_the_cryomancer": [&"cold_damage", &"cold_resistance"],
	&"of_the_stormcaller": [&"lightning_damage", &"lightning_resistance"],
	&"of_the_occultist": [&"chaos_damage", &"chaos_resistance"],
	&"of_balanced_form": [&"dodge_chance", &"block_chance"],
	&"of_martial_mastery": [&"strength", &"dexterity"],
	&"of_arcane_mastery": [&"intelligence", &"wisdom"],
	&"apex_force": [&"damage", &"crit_multiplier"],
	&"eternal_bulwark": [&"max_health", &"armor"],
	&"primal_convergence": [&"physical_damage", &"attack_speed"],
	&"sovereign_magic": [&"caster_damage", &"healing_power"],
	&"of_perfect_form": [&"dodge_chance", &"move_speed"],
	&"of_inexorable_time": [&"attack_speed", &"cooldown_rate"],
	&"of_boundless_reach": [&"attack_range", &"area_size"],
	&"of_royal_command": [&"charisma", &"party_influence"],
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
	&"tempered_edge": [Vector2(0.05, 0.10), Vector2(0.11, 0.20), Vector2(0.21, 0.30)],
}

const RETAINED_NAMES := {
	&"stout": "Stout", &"keen": "Keen", &"wise": "Wise",
	&"of_embers": "of Embers", &"of_rime": "of Rime", &"of_reach": "of Reach",
}

const FLAT_STATS := [
	&"strength", &"dexterity", &"constitution", &"intelligence", &"wisdom", &"charisma", &"max_health", &"armor",
	&"party_influence", &"health_regeneration", &"fire_resistance", &"cold_resistance", &"lightning_resistance",
	&"chaos_resistance", &"crit_chance", &"crit_multiplier", &"dodge_chance", &"block_chance", &"block_effectiveness", &"life_steal",
]
const ATTRIBUTE_STATS := [&"strength", &"dexterity", &"constitution", &"intelligence", &"wisdom", &"charisma"]
const AFFINITY_ORDER := [&"melee", &"ranged", &"caster"]
const AFFINITY_STATS := {
	&"melee": [&"melee_damage", &"strength", &"physical_damage", &"armor", &"block_chance", &"block_effectiveness"],
	&"ranged": [&"ranged_damage", &"dexterity", &"attack_range", &"projectile_speed", &"move_speed", &"dodge_chance"],
	&"caster": [&"caster_damage", &"intelligence", &"wisdom", &"healing_power", &"area_size", &"cooldown_rate", &"fire_damage", &"cold_damage", &"lightning_damage", &"chaos_damage", &"fire_resistance", &"cold_resistance", &"lightning_resistance", &"chaos_resistance"],
}

static func explicit_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	_append_focused_rows(rows, FOCUSED_PREFIX_EFFECTS, &"prefix")
	_append_focused_rows(rows, FOCUSED_SUFFIX_EFFECTS, &"suffix")
	_append_hybrid_rows(rows, STANDARD_PREFIX_IDS, &"standard_hybrid", &"prefix", 150.0, 0.70)
	_append_hybrid_rows(rows, STANDARD_SUFFIX_IDS, &"standard_hybrid", &"suffix", 150.0, 0.70)
	_append_hybrid_rows(rows, PREMIUM_PREFIX_IDS, &"premium_hybrid", &"prefix", 25.0, 0.85)
	_append_hybrid_rows(rows, PREMIUM_SUFFIX_IDS, &"premium_hybrid", &"suffix", 25.0, 0.85)
	return rows

static func tier_rows(curve_key: StringName, component_scale: float) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not CURVE_ENDPOINTS.has(curve_key) or not is_finite(component_scale) or component_scale <= 0.0:
		return rows
	var endpoints: Array = CURVE_ENDPOINTS[curve_key]
	var level_one: Vector2 = endpoints[0]
	var level_thousand: Vector2 = endpoints[1]
	var snap_step: float = endpoints[2]
	for index: int in TIER_MINIMUM_LEVELS.size():
		var level: int = TIER_MINIMUM_LEVELS[index]
		var progress := pow((float(level) - 1.0) / 999.0, CURVE_EXPONENT)
		rows.append({
			"tier": index + 1,
			"minimum_item_level": level,
			"base_weight": TIER_WEIGHTS[index],
			"minimum": snappedf(lerpf(level_one.x, level_thousand.x, progress) * component_scale, snap_step),
			"maximum": snappedf(lerpf(level_one.y, level_thousand.y, progress) * component_scale, snap_step),
		})
	return rows

static func _append_focused_rows(rows: Array[Dictionary], source_rows: Array, side: StringName) -> void:
	for source_variant: Variant in source_rows:
		var source: Array = source_variant
		var id: StringName = source[0]
		var stat_id: StringName = source[1]
		var operation: int = source[2]
		var required_item_tag: StringName = source[3]
		var effects: Array[Dictionary] = [_effect(stat_id, operation, 1.0)]
		rows.append(_row(
			id, &"focused", side, 1000.0 if required_item_tag.is_empty() else 500.0,
			1.0, required_item_tag, effects
		))

static func _append_hybrid_rows(
	rows: Array[Dictionary], ids: Array, category: StringName, side: StringName, base_weight: float, component_scale: float
) -> void:
	for id_variant: Variant in ids:
		var id: StringName = id_variant
		var effects: Array[Dictionary] = []
		for stat_variant: Variant in HYBRID_EFFECTS[id]:
			var stat_id: StringName = stat_variant
			effects.append(_effect(stat_id, _hybrid_operation(stat_id), component_scale))
		rows.append(_row(id, category, side, base_weight, component_scale, &"", effects))

static func _row(
	id: StringName,
	category: StringName,
	side: StringName,
	base_weight: float,
	component_scale: float,
	required_item_tag: StringName,
	effects: Array[Dictionary]
) -> Dictionary:
	var modifier_family_ids: Array[StringName] = []
	var stat_ids: Array[StringName] = []
	for effect: Dictionary in effects:
		modifier_family_ids.append(effect["modifier_family_id"])
		stat_ids.append(effect["stat_id"])
	return {
		"id": id,
		"display_name": _display_name(id),
		"category": category,
		"side": side,
		"base_weight": base_weight,
		"component_scale": component_scale,
		"required_item_tag": required_item_tag,
		"affinity_tags": _affinity_tags(stat_ids),
		"modifier_family_ids": modifier_family_ids,
		"effects": effects,
		"tiers": _combined_tiers(id, effects),
		"output_path": _output_path(id, category),
	}

static func _effect(stat_id: StringName, operation: int, component_scale: float) -> Dictionary:
	return {
		"stat_id": stat_id,
		"operation": operation,
		"modifier_family_id": _family_id(stat_id, operation),
		"curve_key": _curve_key(stat_id, operation),
		"component_scale": component_scale,
	}

static func _combined_tiers(id: StringName, effects: Array[Dictionary]) -> Array[Dictionary]:
	var component_tiers: Array = []
	for effect: Dictionary in effects:
		component_tiers.append(tier_rows(effect["curve_key"], effect["component_scale"]))
	var result: Array[Dictionary] = []
	for tier_index: int in TIER_MINIMUM_LEVELS.size():
		var minimum_rolls: Array[float] = []
		var maximum_rolls: Array[float] = []
		for effect_index: int in effects.size():
			var bounds := _component_bounds(id, effects[effect_index], component_tiers[effect_index], tier_index)
			minimum_rolls.append(bounds.x)
			maximum_rolls.append(bounds.y)
		result.append({
			"tier": tier_index + 1,
			"minimum_item_level": TIER_MINIMUM_LEVELS[tier_index],
			"base_weight": TIER_WEIGHTS[tier_index],
			"minimum_rolls": minimum_rolls,
			"maximum_rolls": maximum_rolls,
		})
	return result

static func _component_bounds(id: StringName, effect: Dictionary, tiers: Array, tier_index: int) -> Vector2:
	if not LEGACY_TIER_BOUNDS.has(id):
		return Vector2(tiers[tier_index]["minimum"], tiers[tier_index]["maximum"])
	var legacy_bounds: Array = LEGACY_TIER_BOUNDS[id]
	if tier_index < legacy_bounds.size():
		return legacy_bounds[tier_index]
	var curve_key: StringName = effect["curve_key"]
	var endpoints: Array = CURVE_ENDPOINTS[curve_key]
	var legacy_maximum: float = (legacy_bounds[legacy_bounds.size() - 1] as Vector2).y
	var level: int = TIER_MINIMUM_LEVELS[tier_index]
	var progress := pow((float(level) - 30.0) / 970.0, CURVE_EXPONENT)
	var snap_step: float = endpoints[2]
	var component_scale: float = effect["component_scale"]
	return Vector2(
		snappedf(lerpf(legacy_maximum, (endpoints[1] as Vector2).x * component_scale, progress), snap_step),
		snappedf(lerpf(legacy_maximum, (endpoints[1] as Vector2).y * component_scale, progress), snap_step)
	)

static func _hybrid_operation(stat_id: StringName) -> int:
	return StatModifier.Operation.FLAT if stat_id in FLAT_STATS else StatModifier.Operation.INCREASED

static func _curve_key(stat_id: StringName, operation: int) -> StringName:
	if operation == StatModifier.Operation.INCREASED:
		return &"increased_multiplier"
	if stat_id in ATTRIBUTE_STATS:
		return &"flat_attribute"
	if stat_id == &"max_health":
		return &"flat_health"
	if stat_id == &"armor":
		return &"flat_armor"
	if stat_id == &"party_influence":
		return &"flat_party_influence"
	if stat_id == &"health_regeneration":
		return &"flat_regeneration"
	if stat_id == &"crit_multiplier":
		return &"flat_crit_multiplier"
	return &"flat_ratio"

static func _family_id(stat_id: StringName, operation: int) -> StringName:
	return StringName("%s_%s" % [stat_id, "flat" if operation == StatModifier.Operation.FLAT else "increased"])

static func _affinity_tags(stats: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for affinity: StringName in AFFINITY_ORDER:
		for stat_id: StringName in stats:
			if stat_id in AFFINITY_STATS[affinity]:
				result.append(affinity)
				break
	return result

static func _display_name(id: StringName) -> String:
	if RETAINED_NAMES.has(id):
		return RETAINED_NAMES[id]
	var source := String(id)
	if source.begins_with("of_"):
		return "of %s" % source.trim_prefix("of_").replace("_", " ").capitalize()
	return source.replace("_", " ").capitalize()

static func _output_path(id: StringName, category: StringName) -> String:
	if RETAINED_NAMES.has(id):
		return "res://data/items/affixes/fixtures/%s.tres" % id
	return "res://data/items/affixes/production/%s/%s.tres" % [category, id]
