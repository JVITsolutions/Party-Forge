class_name ForgeGuardian
extends "res://scripts/enemies/enemy_actor.gd"

signal boss_defeated

const BossActionScheduleScript := preload("res://scripts/enemies/boss_action_schedule.gd")
const DANGER_RING_SCENE := preload("res://scenes/effects/danger_ring.tscn")

const CHARGE_TELEGRAPH := 0.8
const CHARGE_DURATION := 0.65
const CHARGE_SPEED := 15.0
const SHOCKWAVE_TELEGRAPH := 1.0
const SHOCKWAVE_RADIUS := 6.0
const SUMMON_COUNT := 6

enum Phase { NONE, TELEGRAPH, EXECUTE }

var leader: Node3D
var spawn_director: Node
var effects_parent: Node
var schedule: RefCounted = BossActionScheduleScript.new() as RefCounted
var active_action := -1
var action_phase: Phase = Phase.NONE
var action_remaining := 0.0
var charge_target := Vector3.ZERO
var charge_direction := Vector3.ZERO
var pending_hit_areas: Array[Node] = []
var boss_defeat_emitted := false

func configure_boss(target_leader: Node3D, director: Node = null, effect_container: Node = null) -> void:
    leader = target_leader
    spawn_director = director
    effects_parent = effect_container

func _physics_process(delta: float) -> void:
    advance_behavior(delta)

func advance_behavior(delta: float) -> void:
    if is_dead:
        velocity = Vector3.ZERO
        return
    var step_delta := maxf(delta, 0.0)
    var action_delta := step_delta
    var was_idle := active_action < 0
    var recovery_before := float(schedule.get("remaining")) if was_idle else 0.0
    schedule.call("advance", step_delta)
    if was_idle:
        action_delta = maxf(0.0, step_delta - minf(step_delta, recovery_before))
        var next_action := int(schedule.call("take_next"))
        if next_action >= 0:
            _begin_action(next_action)
    var unconsumed := action_delta
    while active_action >= 0 and unconsumed > 0.0:
        var step := minf(unconsumed, action_remaining)
        if active_action == BossActionScheduleScript.Action.CHARGE and action_phase == Phase.EXECUTE:
            _move_charge(step)
        action_remaining = maxf(0.0, action_remaining - step)
        if is_zero_approx(action_remaining):
            action_remaining = 0.0
        unconsumed -= step
        if action_remaining <= 0.0:
            _complete_phase()
        if step <= 0.0:
            break

func defeat() -> void:
    if is_dead:
        return
    _disable_pending_hit_areas()
    active_action = -1
    action_phase = Phase.NONE
    action_remaining = 0.0
    if not boss_defeat_emitted:
        boss_defeat_emitted = true
        boss_defeated.emit()
    super.defeat()

func _begin_action(action: int) -> void:
    active_action = action
    action_phase = Phase.TELEGRAPH
    match active_action:
        BossActionScheduleScript.Action.CHARGE:
            charge_target = _leader_position()
            var origin := global_position if is_inside_tree() else position
            charge_direction = charge_target - origin
            charge_direction.y = 0.0
            charge_direction = charge_direction.normalized()
            action_remaining = CHARGE_TELEGRAPH
        BossActionScheduleScript.Action.SHOCKWAVE:
            action_remaining = SHOCKWAVE_TELEGRAPH
            _create_danger_ring()
        BossActionScheduleScript.Action.SUMMON:
            _summon_swarmers()
            _finish_action()

func _complete_phase() -> void:
    if active_action == BossActionScheduleScript.Action.CHARGE and action_phase == Phase.TELEGRAPH:
        action_phase = Phase.EXECUTE
        action_remaining = CHARGE_DURATION
        return
    if active_action == BossActionScheduleScript.Action.SHOCKWAVE:
        _apply_shockwave()
    _finish_action()

func _finish_action() -> void:
    active_action = -1
    action_phase = Phase.NONE
    action_remaining = 0.0
    velocity = Vector3.ZERO

func _move_charge(delta: float) -> void:
    velocity = charge_direction * CHARGE_SPEED
    var next_position := (global_position if is_inside_tree() else position) + velocity * delta
    if is_inside_tree():
        global_position = next_position
    else:
        position = next_position

func _create_danger_ring() -> void:
    var parent := effects_parent if effects_parent != null and is_instance_valid(effects_parent) else get_parent()
    if parent == null:
        return
    var ring := DANGER_RING_SCENE.instantiate() as Node3D
    parent.add_child(ring)
    if ring.is_inside_tree() and is_inside_tree():
        ring.global_position = global_position
    else:
        ring.position = position
    pending_hit_areas.append(ring)

func _apply_shockwave() -> void:
    var center := global_position if is_inside_tree() else position
    for actor: Node3D in _party_targets():
        var target_position := actor.global_position if actor.is_inside_tree() else actor.position
        if center.distance_squared_to(target_position) <= SHOCKWAVE_RADIUS * SHOCKWAVE_RADIUS and actor.has_method("receive_damage"):
            actor.call("receive_damage", definition.contact_damage)
    _disable_pending_hit_areas()

func _summon_swarmers() -> void:
    if spawn_director == null or not is_instance_valid(spawn_director) or not spawn_director.has_method("spawn_enemy"):
        return
    for index: int in range(SUMMON_COUNT):
        spawn_director.call("spawn_enemy", &"swarmer")

func _disable_pending_hit_areas() -> void:
    for area: Node in pending_hit_areas:
        if area == null or not is_instance_valid(area):
            continue
        area.process_mode = Node.PROCESS_MODE_DISABLED
        if area is Node3D:
            (area as Node3D).visible = false
        var hit_area := area.get_node_or_null("HitArea") as Area3D
        if hit_area != null:
            hit_area.monitoring = false
            hit_area.monitorable = false
        area.queue_free()
    pending_hit_areas.clear()

func _party_targets() -> Array[Node3D]:
    var targets: Array[Node3D] = []
    var seen: Dictionary = {}
    if leader != null and is_instance_valid(leader):
        targets.append(leader)
        seen[leader.get_instance_id()] = true
    if is_inside_tree():
        for node: Node in get_tree().get_nodes_in_group("party_actors"):
            var actor := node as Node3D
            if actor == null or seen.has(actor.get_instance_id()):
                continue
            if actor.has_method("get_combat_target"):
                var target: CombatTarget = actor.call("get_combat_target") as CombatTarget
                if target == null or not target.is_available:
                    continue
            targets.append(actor)
            seen[actor.get_instance_id()] = true
    return targets

func _leader_position() -> Vector3:
    if leader == null or not is_instance_valid(leader):
        return global_position if is_inside_tree() else position
    return leader.global_position if leader.is_inside_tree() else leader.position
