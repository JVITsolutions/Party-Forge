class_name TargetSelector
extends RefCounted

static func nearest(origin: Vector3, candidates: Array[CombatTarget], maximum_range: float, own_team: int) -> CombatTarget:
    if maximum_range < 0.0:
        return null
    var selected: CombatTarget
    var best_distance_squared := INF
    var maximum_range_squared: float = maximum_range * maximum_range
    for candidate: CombatTarget in candidates:
        if candidate == null or not candidate.is_available or candidate.team_id == own_team:
            continue
        var distance_squared: float = origin.distance_squared_to(candidate.position)
        if distance_squared > maximum_range_squared:
            continue
        if selected == null or distance_squared < best_distance_squared or (distance_squared == best_distance_squared and _precedes(candidate, selected)):
            selected = candidate
            best_distance_squared = distance_squared
    return selected

static func _precedes(candidate: CombatTarget, selected: CombatTarget) -> bool:
    if candidate.position.x != selected.position.x:
        return candidate.position.x < selected.position.x
    if candidate.position.y != selected.position.y:
        return candidate.position.y < selected.position.y
    if candidate.position.z != selected.position.z:
        return candidate.position.z < selected.position.z
    var candidate_actor_id: int = candidate.actor.get_instance_id() if candidate.actor != null else 0
    var selected_actor_id: int = selected.actor.get_instance_id() if selected.actor != null else 0
    if candidate_actor_id != selected_actor_id:
        return candidate_actor_id < selected_actor_id
    return candidate.get_instance_id() < selected.get_instance_id()
