class_name CombatSandbox
extends Node3D

const BOSS_SCENE := preload("res://scenes/enemies/forge_guardian.tscn")
const SANDBOX_SCENE_PATH := "res://scenes/dev/combat_sandbox.tscn"

var catalog: GameCatalog
var party_manager: PartyManager
var actor_spawner: PartyActorSpawner
var spawn_director: SpawnDirector
var leader: PartyActor
var enemies: Node3D
var effects: Node3D
var boss: Node3D
var combat_rng: CombatRng
var initialized := false
var status_refresh_remaining := 0.0

func _ready() -> void:
    if initialized:
        return
    initialized = true
    party_manager = get_node("PartyManager") as PartyManager
    actor_spawner = get_node("PartyActorSpawner") as PartyActorSpawner
    spawn_director = get_node("SpawnDirector") as SpawnDirector
    leader = get_node("Actors/Leader") as PartyActor
    enemies = get_node("Enemies") as Node3D
    effects = get_node("Effects") as Node3D
    catalog = GameCatalog.load_defaults()
    if not catalog.validate().is_empty():
        push_error("PARTY_FORGE_SANDBOX_CATALOG_INVALID")
        return
    var editor_launch := OS.has_feature("editor") and DisplayServer.get_name() != "headless"
    if cap_override_allowed(editor_launch, scene_file_path):
        party_manager.configure_capacity(PartyCapacityPolicy.new(24))
    party_manager.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    combat_rng = CombatRng.new(1337)
    party_manager.configure_combat(combat_rng, catalog.damage_types)
    leader.configure(party_manager.members[0])
    leader.configure_combat(party_manager, effects)
    leader.position = (get_node("Arena/PlayerSpawn") as Node3D).position
    actor_spawner.initialize(party_manager, get_node("Actors") as Node3D, leader, effects)
    var camera_rig := get_node("LeaderCamera") as Node3D
    camera_rig.set("target", leader)
    spawn_director.configure(1337, leader, null, _spawn_markers(), camera_rig.get_node("Camera3D") as Camera3D, enemies, effects, 1.0, combat_rng, catalog.damage_types)
    _wire_buttons()
    party_manager.member_added.connect(func(_member: PartyMemberState) -> void: refresh_status())
    party_manager.class_rank_changed.connect(func(_class_id: StringName, _rank: int) -> void: refresh_status())
    party_manager.active_traits_changed.connect(func(_tiers: Dictionary) -> void: refresh_status())
    refresh_status()

func _process(delta: float) -> void:
    status_refresh_remaining -= maxf(delta, 0.0)
    if status_refresh_remaining <= 0.0:
        status_refresh_remaining = 0.2
        refresh_status()

func spawn_class(class_id: StringName) -> bool:
    if not initialized:
        _ready()
    var definition := catalog.class_by_id(class_id) if catalog != null else null
    var recruited := party_manager != null and party_manager.recruit(definition)
    refresh_status()
    return recruited

func spawn_enemy(enemy_id: StringName) -> Node3D:
    if not initialized:
        _ready()
    var enemy := spawn_director.spawn_enemy(enemy_id) if spawn_director != null else null
    refresh_status()
    return enemy

func spawn_boss() -> Node3D:
    if not initialized:
        _ready()
    if boss != null and is_instance_valid(boss):
        return boss
    boss = BOSS_SCENE.instantiate() as Node3D
    enemies.add_child(boss)
    boss.call("configure_combat", &"boss", combat_rng, catalog.damage_types)
    boss.position = Vector3(0.0, 0.75, -8.0)
    boss.call("configure_boss", leader, spawn_director, effects)
    refresh_status()
    return boss

func down_selected_companion() -> bool:
    var companions := _companions()
    var selector := get_node("HUD/Panel/Content/SelectedCompanion") as OptionButton
    if companions.is_empty() or selector.selected < 0 or selector.selected >= companions.size():
        return false
    var companion := companions[selector.selected] as PartyActor
    var health := companion.get_node("HealthComponent") as HealthComponent
    health.apply_damage(health.current_health)
    refresh_status()
    return true

func clear_hostiles() -> void:
    for child: Node in enemies.get_children():
        child.queue_free()
    var transient_effects: Array[Node] = []
    if is_inside_tree():
        transient_effects.assign(get_tree().get_nodes_in_group(&"hostile_transient_effects"))
    else:
        for candidate: Node in find_children("*", "", true, false):
            if candidate.is_in_group(&"hostile_transient_effects"):
                transient_effects.append(candidate)
    for effect: Node in transient_effects:
        effect.queue_free()
    boss = null
    refresh_status()

func refresh_status() -> void:
    if party_manager == null:
        return
    (get_node("HUD/Panel/Content/PartySize") as Label).text = "Party Size: %d / %d" % [party_manager.members.size(), party_manager.capacity()]
    (get_node("HUD/Panel/Content/ClassRanks") as Label).text = "Class Ranks: %s" % _class_rank_text()
    (get_node("HUD/Panel/Content/TraitCounts") as Label).text = "Trait Counts: %s" % _trait_count_text()
    (get_node("HUD/Panel/Content/ActiveTiers") as Label).text = "Active Tiers: %s" % _active_tier_text()
    _refresh_companion_selector()

func cap_override_allowed(editor_hint: bool, source_scene_path: String) -> bool:
    return editor_hint and source_scene_path == SANDBOX_SCENE_PATH

func _wire_buttons() -> void:
    var base := "HUD/Panel/Content/Buttons/"
    for class_id: StringName in [&"fighter", &"ranger", &"mage", &"cleric"]:
        var class_button := get_node(base + String(class_id).capitalize()) as Button
        var class_callback := spawn_class.bind(class_id)
        if not class_button.pressed.is_connected(class_callback):
            class_button.pressed.connect(class_callback)
    for enemy_id: StringName in [&"swarmer", &"spitter"]:
        var enemy_button := get_node(base + String(enemy_id).capitalize()) as Button
        var enemy_callback := spawn_enemy.bind(enemy_id)
        if not enemy_button.pressed.is_connected(enemy_callback):
            enemy_button.pressed.connect(enemy_callback)
    var boss_button := get_node(base + "ForgeGuardian") as Button
    if not boss_button.pressed.is_connected(spawn_boss): boss_button.pressed.connect(spawn_boss)
    var down_button := get_node(base + "DownSelectedCompanion") as Button
    if not down_button.pressed.is_connected(down_selected_companion): down_button.pressed.connect(down_selected_companion)
    var clear_button := get_node(base + "ClearHostiles") as Button
    if not clear_button.pressed.is_connected(clear_hostiles): clear_button.pressed.connect(clear_hostiles)

func _spawn_markers() -> Array[Node3D]:
    var markers: Array[Node3D] = []
    for child: Node in get_node("Arena").get_children():
        if child is Node3D and child.is_in_group("enemy_spawn_markers"):
            markers.append(child as Node3D)
    return markers

func _companions() -> Array[Node3D]:
    var companions: Array[Node3D] = []
    if not has_node("Actors"):
        return companions
    for child: Node in get_node("Actors").get_children():
        var actor := child as PartyActor
        if actor != null and actor != leader and actor.member_state != null:
            companions.append(actor)
    return companions

func _refresh_companion_selector() -> void:
    var selector := get_node("HUD/Panel/Content/SelectedCompanion") as OptionButton
    var previous := selector.selected
    selector.clear()
    for actor: Node3D in _companions():
        var party_actor := actor as PartyActor
        selector.add_item("#%d %s" % [party_actor.member_state.member_id, party_actor.member_state.class_definition.display_name])
    selector.disabled = selector.item_count == 0
    if selector.item_count > 0:
        selector.select(clampi(previous, 0, selector.item_count - 1))

func _class_rank_text() -> String:
    var entries: PackedStringArray = []
    var ids: Array = party_manager.class_ranks.keys()
    ids.sort()
    for class_id: StringName in ids:
        entries.append("%s %d" % [String(class_id).capitalize(), party_manager.get_class_rank(class_id)])
    return ", ".join(entries)

func _trait_count_text() -> String:
    var entries: PackedStringArray = []
    for definition: TraitDefinition in catalog.traits:
        var count := party_manager.trait_count(definition.id)
        if count > 0:
            entries.append("%s %d" % [definition.display_name, count])
    return ", ".join(entries) if not entries.is_empty() else "None"

func _active_tier_text() -> String:
    var entries: PackedStringArray = []
    var ids: Array = party_manager.active_tiers.keys()
    ids.sort()
    for trait_id: StringName in ids:
        var definition := catalog.trait_by_id(trait_id)
        entries.append("%s %d" % [definition.display_name if definition != null else String(trait_id), party_manager.active_tier(trait_id)])
    return ", ".join(entries) if not entries.is_empty() else "None"
