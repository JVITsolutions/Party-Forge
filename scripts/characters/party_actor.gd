class_name PartyActor
extends CharacterBody3D

const PARTY_TEAM_ID := 1
const REVIVE_DELAY := 8.0
const REVIVE_HEALTH_FRACTION := 0.5

@export var team_id: int = PARTY_TEAM_ID
@export var move_speed: float = 6.0

var member_state: PartyMemberState

func _ready() -> void:
    _refresh_team_group()

func configure(member_state: PartyMemberState) -> void:
    self.member_state = member_state
    if member_state == null or member_state.class_definition == null:
        return
    var definition: ClassDefinition = member_state.class_definition
    move_speed = definition.move_speed
    var health: HealthComponent = _health_component()
    if health != null:
        health.configure(definition.max_health, definition.armor, member_state.is_leader, REVIVE_DELAY, REVIVE_HEALTH_FRACTION)
    var attack: AttackController = _attack_controller()
    if attack != null:
        attack.configure(definition.primary_attack, team_id)
    var mesh: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D
    if mesh != null:
        var material: StandardMaterial3D = mesh.material_override as StandardMaterial3D
        if material != null:
            material = material.duplicate() as StandardMaterial3D
            material.albedo_color = definition.color
            mesh.material_override = material
    _refresh_team_group()

func receive_damage(amount: float) -> float:
    var health: HealthComponent = _health_component()
    if health == null:
        return 0.0
    return health.take_damage(amount)

func get_combat_target() -> CombatTarget:
    var target_position: Vector3 = global_position if is_inside_tree() else position
    var target := CombatTarget.new(self, target_position, team_id)
    var health: HealthComponent = _health_component()
    target.is_available = health == null or (not health.is_downed and not health.is_dead)
    return target

func _health_component() -> HealthComponent:
    return get_node_or_null("HealthComponent") as HealthComponent

func _attack_controller() -> AttackController:
    return get_node_or_null("AttackController") as AttackController

func _refresh_team_group() -> void:
    remove_from_group("party_actors")
    remove_from_group("hostile_actors")
    add_to_group("party_actors" if team_id == PARTY_TEAM_ID else "hostile_actors")
