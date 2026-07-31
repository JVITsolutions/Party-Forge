class_name HealingSelector
extends RefCounted

@warning_ignore("shadowed_global_identifier")
static func most_injured(living_party: Array[CombatTarget], range: float, origin: Vector3) -> CombatTarget:
    if range < 0.0:
        return null
    var selected: CombatTarget = null
    var greatest_missing_fraction := 0.0
    var best_distance_squared := INF
    var maximum_range_squared: float = range * range
    for candidate: CombatTarget in living_party:
        if candidate == null or not candidate.is_available or candidate.actor == null:
            continue
        var health := _health(candidate.actor)
        if health == null or health.is_downed or health.is_dead or health.max_health <= 0.0:
            continue
        var missing_fraction: float = 1.0 - health.current_health / health.max_health
        if missing_fraction <= 0.0:
            continue
        var distance_squared: float = origin.distance_squared_to(candidate.position)
        if distance_squared > maximum_range_squared:
            continue
        if selected == null or missing_fraction > greatest_missing_fraction or (is_equal_approx(missing_fraction, greatest_missing_fraction) and distance_squared < best_distance_squared):
            selected = candidate
            greatest_missing_fraction = missing_fraction
            best_distance_squared = distance_squared
    return selected

static func _health(actor: Node3D) -> HealthComponent:
    return actor.get_node_or_null("HealthComponent") as HealthComponent
