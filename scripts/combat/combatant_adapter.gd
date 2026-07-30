class_name CombatantAdapter
extends RefCounted

var actor: Node3D
var combatant_id: StringName
var team_id := 0
var available := true
var health: HealthComponent
var stats: ResolvedStatSnapshot
var incoming_provider: Callable

func _init(actor_value: Node3D = null, id_value: StringName = &"", team_value: int = 0, health_value: HealthComponent = null, stats_value: ResolvedStatSnapshot = null, available_value: bool = true, incoming_value: Callable = Callable()) -> void:
	actor = actor_value
	combatant_id = id_value
	team_id = team_value
	health = health_value
	stats = stats_value
	available = available_value
	incoming_provider = incoming_value

func stat_value(stat_id: StringName, fallback: float = 0.0) -> float:
	return stats.value(stat_id, fallback) if stats != null else fallback

func incoming_damage_multiplier(packet: DamagePacket) -> float:
	if incoming_provider.is_valid(): return maxf(0.0, float(incoming_provider.call(packet)))
	return 1.0
