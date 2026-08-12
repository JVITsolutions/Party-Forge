class_name HUD
extends CanvasLayer

var game_run: Node
var party_manager: PartyManager
var experience_system: ExperienceSystem
var leader: PartyActor
var boss: Node3D
var boss_banner_remaining := 0.0
var loot_status_remaining := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func configure(run: Node, party: PartyManager, experience: ExperienceSystem) -> void:
	game_run = run
	party_manager = party
	experience_system = experience

func set_leader(actor: PartyActor) -> void:
	leader = actor

func set_boss(actor: Node3D) -> void:
	boss = actor
	(get_node("Margin/Status/BossHealth") as Control).visible = actor != null

func show_boss_banner() -> void:
	var banner := get_node("BossBanner") as Control
	banner.visible = true
	boss_banner_remaining = 2.0

func show_loot_status(message: String, duration := 2.5) -> void:
	var label := get_node("LootStatus") as Label
	label.text = message
	label.visible = not message.strip_edges().is_empty()
	loot_status_remaining = maxf(duration, 0.0)

func _process(delta: float) -> void:
	_refresh_status()
	if boss_banner_remaining > 0.0:
		boss_banner_remaining = maxf(0.0, boss_banner_remaining - maxf(delta, 0.0))
		if boss_banner_remaining <= 0.0:
			(get_node("BossBanner") as Control).visible = false
	if loot_status_remaining > 0.0:
		loot_status_remaining = maxf(0.0, loot_status_remaining - maxf(delta, 0.0))
		if loot_status_remaining <= 0.0:
			(get_node("LootStatus") as Control).visible = false

func _refresh_status() -> void:
	if leader != null and is_instance_valid(leader):
		var health := leader.get_node_or_null("HealthComponent") as HealthComponent
		if health != null:
			(get_node("Margin/Status/LeaderHealth") as ProgressBar).max_value = health.max_health
			(get_node("Margin/Status/LeaderHealth") as ProgressBar).value = health.current_health
	if experience_system != null:
		var xp := get_node("Margin/Status/Experience") as ProgressBar
		xp.max_value = maxi(experience_system.experience_for_next_level(), 1)
		xp.value = experience_system.experience
	if game_run != null:
		(get_node("Margin/Status/RunTime") as Label).text = _format_time(float(game_run.call("elapsed_time")))
	_refresh_party()
	_refresh_boss()

func _refresh_party() -> void:
	if party_manager == null:
		return
	for index: int in range(4):
		var label := get_node("Margin/Status/PartyEntries/Party%d" % (index + 1)) as Label
		if index < party_manager.members.size():
			var member: PartyMemberState = party_manager.members[index]
			label.text = "%s  Rank %d" % [member.class_definition.display_name, party_manager.get_class_rank(member.class_definition.id)]
			label.modulate = member.class_definition.color
		else:
			label.text = "—"
			label.modulate = Color(0.5, 0.5, 0.5)
	var traits: PackedStringArray = []
	for trait_id: Variant in party_manager.active_tiers:
		traits.append("%s %d" % [trait_id, int(party_manager.active_tiers[trait_id])])
	(get_node("Margin/Status/ActiveTraits") as Label).text = "Traits: " + (", ".join(traits) if not traits.is_empty() else "None")

func _refresh_boss() -> void:
	var bar := get_node("Margin/Status/BossHealth") as ProgressBar
	if boss == null or not is_instance_valid(boss):
		bar.visible = false
		return
	bar.visible = true
	bar.max_value = float(boss.get("definition").max_health)
	bar.value = float(boss.get("current_health"))

func _format_time(seconds: float) -> String:
	var total := maxi(floori(seconds), 0)
	var minutes := floori(total / 60.0)
	return "%02d:%02d" % [minutes, total % 60]
