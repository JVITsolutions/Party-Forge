class_name FormationMath
extends RefCounted

const MAX_SEPARATION := 1.5
const ARRIVAL_DISTANCE_SQUARED := 0.01

static func desired_velocity(role: ClassDefinition.Role, actor_position: Vector3, leader_position: Vector3, threat_position: Vector3, preferred_distance: float, tether_distance: float, separation: Vector3, speed: float) -> Vector3:
    var actor := Vector3(actor_position.x, 0.0, actor_position.z)
    var leader := Vector3(leader_position.x, 0.0, leader_position.z)
    var threat := Vector3(threat_position.x, 0.0, threat_position.z)
    var desired_point := leader
    if actor.distance_to(leader) <= tether_distance:
        var away_from_threat := (leader - threat).normalized()
        if away_from_threat.is_zero_approx():
            away_from_threat = Vector3.BACK
        match role:
            ClassDefinition.Role.FRONTLINE:
                desired_point = leader - away_from_threat * minf(preferred_distance, 3.0)
            ClassDefinition.Role.MIDLINE:
                desired_point = threat + away_from_threat * preferred_distance
            ClassDefinition.Role.BACKLINE:
                desired_point = threat + away_from_threat * preferred_distance
            ClassDefinition.Role.SUPPORT:
                desired_point = leader + away_from_threat * minf(preferred_distance, 4.0)

    var desired := desired_point - actor
    var planar_separation := Vector3(separation.x, 0.0, separation.z).limit_length(MAX_SEPARATION)
    desired += planar_separation
    desired.y = 0.0
    if desired.length_squared() < ARRIVAL_DISTANCE_SQUARED:
        return Vector3.ZERO
    return desired.normalized() * speed
