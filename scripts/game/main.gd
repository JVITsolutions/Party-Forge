class_name PartyForgeMain
extends Node

const LEADER_SCENE := preload("res://scenes/characters/leader.tscn")
const BOSS_SCENE := preload("res://scenes/enemies/forge_guardian.tscn")
const HEALTH_BAR_SCENE := preload("res://scenes/ui/health_bar_3d.tscn")
const HUDScript := preload("res://scripts/ui/hud.gd")
const LevelUpPanelScript := preload("res://scripts/ui/level_up_panel.gd")
const RunResultPanelScript := preload("res://scripts/ui/run_result_panel.gd")

var party_stats: Dictionary = {
    &"max_health": 0, &"damage": 0, &"move_speed": 0,
    &"attack_speed": 0, &"pickup_radius": 0,
}
var trait_upgrade_ranks: Dictionary = {}
var catalog: GameCatalog
var party_manager: PartyManager
var experience_system: ExperienceSystem
var game_run: GameRun
var spawn_director: SpawnDirector
var party_actor_spawner: PartyActorSpawner
var hud: CanvasLayer
var leader: PartyActor
var boss: Node3D
var run_started := false
var initialized := false

func _ready() -> void:
    if initialized:
        return
    initialized = true
    _cache_nodes()
    catalog = GameCatalog.load_defaults()
    if not _validate_catalog(catalog):
        return
    _wire_static_ui()
    print("PARTY_FORGE_BOOT_OK")
    print("PARTY_FORGE_CLASS_SELECTION_READY")

func select_leader_class(class_id: StringName) -> bool:
    if not initialized:
        _ready()
    if run_started or catalog == null:
        return false
    var definition := catalog.class_by_id(class_id)
    if definition == null:
        push_error(format_resource_error("res://data/classes", "unknown leader class %s" % class_id))
        return false
    party_manager.initialize(definition, catalog.traits)
    leader = LEADER_SCENE.instantiate() as PartyActor
    get_node("Actors").add_child(leader)
    var spawn := get_node("Arena/PlayerSpawn") as Marker3D
    leader.position = spawn.position
    leader.configure(party_manager.members[0])
    leader.configure_combat(party_manager, get_node("Effects"))
    _attach_health_bar(leader)
    party_actor_spawner.initialize(party_manager, get_node("Actors") as Node3D, leader, get_node("Effects"))
    var camera_rig := get_node("LeaderCamera") as LeaderCamera
    camera_rig.target = leader
    var markers := _spawn_markers()
    var camera := camera_rig.get_node("Camera3D") as Camera3D
    spawn_director.configure(1337, leader, experience_system, markers, camera, get_node("Enemies"), get_node("Effects"), _pickup_multiplier())
    spawn_director.process_mode = Node.PROCESS_MODE_INHERIT
    hud.call("configure", game_run, party_manager, experience_system)
    hud.call("set_leader", leader)
    var health := leader.get_node("HealthComponent") as HealthComponent
    if not health.died.is_connected(game_run.leader_defeated): health.died.connect(game_run.leader_defeated)
    if not experience_system.level_ready.is_connected(_on_level_ready): experience_system.level_ready.connect(_on_level_ready)
    if not spawn_director.enemy_spawned.is_connected(_on_enemy_spawned): spawn_director.enemy_spawned.connect(_on_enemy_spawned)
    (get_node("HUD/ClassSelection") as Control).visible = false
    run_started = true
    game_run.start_run()
    return true

func _apply_choice(choice: UpgradeChoice) -> bool:
    if choice == null:
        return false
    var applied := false
    match choice.kind:
        UpgradeChoice.Kind.RECRUIT:
            applied = party_manager.recruit(catalog.class_by_id(choice.target_id))
        UpgradeChoice.Kind.CLASS_RANK:
            applied = party_manager.rank_up(choice.target_id)
        UpgradeChoice.Kind.TRAIT:
            if party_manager.active_tier(choice.target_id) > 0:
                trait_upgrade_ranks[choice.target_id] = int(trait_upgrade_ranks.get(choice.target_id, 0)) + 1
                applied = true
        UpgradeChoice.Kind.PARTY_STAT:
            if party_stats.has(choice.target_id):
                party_stats[choice.target_id] = mini(int(party_stats[choice.target_id]) + 1, 20)
                applied = true
                if choice.target_id == &"pickup_radius":
                    spawn_director.set_pickup_radius_multiplier(_pickup_multiplier())
    if not applied:
        push_error("PARTY_FORGE_INVALID_CHOICE kind=%d target=%s" % [choice.kind, choice.target_id])
        return false
    experience_system.consume_pending_level()
    game_run.resume_run()
    return true

static func format_resource_error(path: String, reason: String) -> String:
    return "PARTY_FORGE_RESOURCE_ERROR path=%s reason=%s" % [path, reason]

func _cache_nodes() -> void:
    party_manager = get_node("PartyManager") as PartyManager
    experience_system = get_node("ExperienceSystem") as ExperienceSystem
    game_run = get_node("GameRun") as GameRun
    spawn_director = get_node("SpawnDirector") as SpawnDirector
    party_actor_spawner = get_node("PartyActorSpawner") as PartyActorSpawner
    hud = get_node("HUD") as CanvasLayer

func _validate_catalog(target_catalog: GameCatalog) -> bool:
    var errors := target_catalog.validate()
    for reason: String in errors:
        push_error(format_resource_error("res://data", reason))
    return errors.is_empty()

func _wire_static_ui() -> void:
    var class_ids: Array[StringName] = [&"fighter", &"ranger", &"mage", &"cleric"]
    for class_id: StringName in class_ids:
        var button := get_node("HUD/ClassSelection/Content/%s" % String(class_id).capitalize()) as Button
        var callback := select_leader_class.bind(class_id)
        if not button.pressed.is_connected(callback): button.pressed.connect(callback)
    var level_panel := get_node("HUD/LevelUpPanel") as Control
    if not level_panel.is_connected("choice_selected", _apply_choice): level_panel.connect("choice_selected", _apply_choice)
    var result := get_node("HUD/RunResultPanel") as Control
    if not result.is_connected("restart_requested", _restart): result.connect("restart_requested", _restart)
    if not result.is_connected("quit_requested", _quit): result.connect("quit_requested", _quit)
    if not game_run.boss_requested.is_connected(_spawn_boss): game_run.boss_requested.connect(_spawn_boss)
    if not game_run.victory.is_connected(_show_victory): game_run.victory.connect(_show_victory)
    if not game_run.defeat.is_connected(_show_defeat): game_run.defeat.connect(_show_defeat)

func _on_level_ready(_level: int) -> void:
    if not run_started:
        return
    game_run.begin_level_up()
    var seed := experience_system.level * 1009 + party_manager.members.size()
    var choices := LevelUpChoiceService.generate(party_manager, catalog, seed)
    get_node("HUD/LevelUpPanel").call("show_choices", choices, party_manager)

func _spawn_boss() -> void:
    if boss != null and is_instance_valid(boss):
        return
    boss = BOSS_SCENE.instantiate() as Node3D
    get_node("Enemies").add_child(boss)
    var markers := _spawn_markers()
    boss.position = markers[0].global_position if not markers.is_empty() else Vector3(12.0, 0.75, 0.0)
    boss.call("configure_boss", leader, spawn_director, get_node("Effects"))
    boss.connect("boss_defeated", game_run.boss_defeated)
    hud.call("set_boss", boss)
    hud.call("show_boss_banner")

func _on_enemy_spawned(_enemy_id: StringName, enemy: Node3D) -> void:
    _attach_health_bar(enemy)

func _attach_health_bar(actor: Node3D) -> void:
    if actor == null or actor.get_node_or_null("HealthBar3D") != null:
        return
    var health := actor.get_node_or_null("HealthComponent") as HealthComponent
    if health == null:
        return
    var bar := HEALTH_BAR_SCENE.instantiate() as Node3D
    actor.add_child(bar)
    bar.call("configure", health)

func _spawn_markers() -> Array[Node3D]:
    var markers: Array[Node3D] = []
    for child: Node in get_node("Arena").get_children():
        if child is Node3D and child.is_in_group("enemy_spawn_markers"):
            markers.append(child as Node3D)
    return markers

func _pickup_multiplier() -> float:
    return 1.0 + float(party_stats[&"pickup_radius"]) * 0.2

func _show_victory() -> void:
    get_node("HUD/RunResultPanel").call("show_result", true)

func _show_defeat() -> void:
    get_node("HUD/RunResultPanel").call("show_result", false)

func _restart() -> void:
    get_tree().paused = false
    get_tree().reload_current_scene()

func _quit() -> void:
    get_tree().quit()
