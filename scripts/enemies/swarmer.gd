class_name Swarmer
extends "res://scripts/enemies/enemy_actor.gd"

var contact_cooldowns: Dictionary = {}
var rat_presentation: Node
var last_presentation_health := 0.0

func _ready() -> void:
    super._ready()
    rat_presentation = get_node_or_null("RatPresentation")
    var health := _health_component()
    if health != null:
        last_presentation_health = health.current_health
        if not health.health_changed.is_connected(_on_swarmer_health_changed):
            health.health_changed.connect(_on_swarmer_health_changed)

func _physics_process(delta: float) -> void:
    advance_behavior(delta)

func advance_behavior(delta: float, candidates: Array[Node3D] = []) -> void:
    if is_dead or definition == null:
        velocity = Vector3.ZERO
        _play_locomotion()
        return
    _advance_contact_cooldowns(delta)
    var target := nearest_living_party_actor(candidates)
    if target == null:
        velocity = Vector3.ZERO
        _play_locomotion()
        return
    var origin := global_position if is_inside_tree() else position
    var target_position := target.global_position if target.is_inside_tree() else target.position
    var offset := target_position - origin
    offset.y = 0.0
    velocity = offset.normalized() * definition.move_speed if not offset.is_zero_approx() else Vector3.ZERO
    if not velocity.is_zero_approx():
        rotation.y = atan2(velocity.x, velocity.z)
    var contact_range := attack_geometry(&"swarmer_contact").range
    if contact_range > 0.0 and offset.length() <= contact_range:
        _try_contact_attack(target)
    _move_for_delta(delta)
    _play_locomotion()

func _try_contact_attack(target: Node3D) -> void:
    var target_id := target.get_instance_id()
    if float(contact_cooldowns.get(target_id, 0.0)) > 0.0:
        return
    if not target.has_method("get_combat_adapter"):
        return
    var packet := prepare_attack(&"swarmer_contact")
    if packet == null or not packet.valid:
        return
    var target_adapter := target.call("get_combat_adapter", packet.action_tags) as CombatantAdapter
    var result := resolve_attack(packet, target_adapter)
    if result != null and result.valid:
        if rat_presentation != null:
            rat_presentation.play_attack()
        var attack := definition.attack_by_id(&"swarmer_contact")
        contact_cooldowns[target_id] = attack.cooldown if attack != null else 0.0

func _advance_contact_cooldowns(delta: float) -> void:
    for target_id: Variant in contact_cooldowns.keys():
        var remaining := maxf(float(contact_cooldowns[target_id]) - maxf(delta, 0.0), 0.0)
        if remaining <= 0.0:
            contact_cooldowns.erase(target_id)
        else:
            contact_cooldowns[target_id] = remaining

func defeat() -> void:
    if defeat_handled:
        return
    defeat_handled = true
    velocity = Vector3.ZERO
    var health := _health_component()
    if health != null and not health.is_dead:
        health.kill()
    var drop_position := global_position if is_inside_tree() else position
    _drop_reward_once(drop_position)
    enemy_defeated.emit(definition, drop_position)
    var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
    if collision != null:
        collision.disabled = true
    var duration: float = float(rat_presentation.play_death()) if rat_presentation != null else 0.0
    if duration <= 0.0 or not is_inside_tree():
        queue_free()
        return
    await get_tree().create_timer(duration).timeout
    if is_instance_valid(self):
        queue_free()

func _play_locomotion() -> void:
    if rat_presentation != null:
        rat_presentation.play_locomotion(not velocity.is_zero_approx())

func _on_swarmer_health_changed(current: float, _maximum: float) -> void:
    if current < last_presentation_health and not is_dead and rat_presentation != null:
        rat_presentation.play_hit()
    last_presentation_health = current
