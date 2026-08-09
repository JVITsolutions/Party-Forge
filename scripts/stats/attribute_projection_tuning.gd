class_name AttributeProjectionTuning
extends Resource

@export var melee_damage_per_strength := 0.02
@export var armor_per_strength := 0.25
@export var ranged_damage_per_dexterity := 0.02
@export var attack_speed_per_dexterity := 0.005
@export var dodge_per_dexterity := 0.001
@export var max_health_per_constitution := 3.0
@export var regeneration_per_constitution := 0.05
@export var caster_damage_per_intelligence := 0.02
@export var area_size_per_intelligence := 0.0075
@export var healing_power_per_wisdom := 0.02
@export var cooldown_rate_per_wisdom := 0.005
@export var party_influence_per_charisma := 1.0

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for property: Dictionary in get_property_list():
		var name := StringName(String(property.get("name", "")))
		if not String(name).ends_with("_strength") and not String(name).ends_with("_dexterity") and not String(name).ends_with("_constitution") and not String(name).ends_with("_intelligence") and not String(name).ends_with("_wisdom") and not String(name).ends_with("_charisma"):
			continue
		var value := float(get(name))
		if not is_finite(value) or value < 0.0:
			errors.append("PARTY_FORGE_ATTRIBUTE_PROJECTION_ERROR field=%s reason=coefficient must be finite and nonnegative" % name)
	return errors
