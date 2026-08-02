extends SceneTree

const BODY_IDS: Array[StringName] = [&"masculine", &"feminine"]
const HELD_SLOTS: Array[StringName] = [&"main_hand", &"off_hand"]
const LEADER_SCENE := preload("res://scenes/characters/leader.tscn")
const HEALTH_BAR_SCENE := preload("res://scenes/ui/health_bar_3d.tscn")
const RENDER_TOOL_PATH := "res://tools/render_character_visual_qa.gd"
const MANIFEST_PATH := "res://docs/qa/character-presentation-quality/manifest.json"

func _initialize() -> void:
	var root_3d := Node3D.new()
	root.add_child(root_3d)
	var combination_count := 0
	for definition: ClassDefinition in GameCatalog.load_defaults().classes:
		for body_id: StringName in BODY_IDS:
			if not _validate_combination(root_3d, definition, body_id):
				return
			combination_count += 1
	if not FileAccess.file_exists(RENDER_TOOL_PATH):
		_fail(&"all", &"all", &"render", &"", "render tool missing")
		return
	if not FileAccess.file_exists(MANIFEST_PATH):
		_fail(&"all", &"all", &"render", &"", "render manifest missing")
		return
	print("PARTY_FORGE_CHARACTER_VISUAL_QA_SMOKE_OK classes=9 bodies=2 combinations=%d grounding=18 shadows=18 bars=18 equipment=18 actions=18 projectiles=1" % combination_count)
	root_3d.free()
	quit(0)

func _validate_combination(parent: Node3D, definition: ClassDefinition, body_id: StringName) -> bool:
	var actor := LEADER_SCENE.instantiate() as PartyActor
	parent.add_child(actor)
	actor.configure(PartyMemberState.new(1, definition, true))
	var presentation := actor.get_node_or_null("Presentation") as CharacterPresentation
	var model := presentation.active_model as ForgeHumanoidModel if presentation != null else null
	if presentation == null or model == null or not presentation.set_body_preset(body_id):
		_fail(definition.id, body_id, &"setup", &"", "real presentation or body unavailable")
		return false
	if not presentation.refresh_grounding() or absf(model.ground_gap()) > 0.01:
		_fail(definition.id, body_id, &"idle", &"", "visible model is not grounded")
		return false
	var shadow := presentation.get_node_or_null("ContactShadow") as MeshInstance3D
	if shadow == null or shadow.position.y < 0.002 or shadow.position.y > 0.01 or not presentation.find_children("*", "CollisionShape3D", true, false).is_empty():
		_fail(definition.id, body_id, &"idle", &"", "contact shadow contract failed")
		return false
	var bar := HEALTH_BAR_SCENE.instantiate() as HealthBar3D
	actor.add_child(bar)
	bar.configure(actor.get_node("HealthComponent") as HealthComponent)
	var bounds := presentation.visual_bounds()
	if bar.position.y < bounds.position.y + bounds.size.y + 0.12:
		_fail(definition.id, body_id, &"idle", &"", "health bar overlaps visible bounds")
		return false
	var player := model.get_node_or_null("AnimationPlayer") as AnimationPlayer
	for action_id: StringName in definition.visual_profile.required_animation_names:
		if player == null or not player.has_animation(action_id):
			_fail(definition.id, body_id, action_id, &"", "required authored action missing")
			return false
	for slot_id: StringName in HELD_SLOTS:
		var item_id := model.equipped_item_id(slot_id)
		if item_id.is_empty():
			continue
		var anchors: Array[StringName] = []
		anchors.assign(model.equipped_anchor_names(slot_id))
		if &"ReadabilityAnchor" not in anchors or model.equipment_anchor_clearance(slot_id, &"ReadabilityAnchor") < 0.06:
			_fail(definition.id, body_id, &"idle", item_id, "held item collapses into arm silhouette")
			return false
		if &"ProjectileLaunchSocket" in anchors:
			var launch := model.equipment_anchor_global_transform(slot_id, &"ProjectileLaunchSocket")
			if not launch.origin.is_finite():
				_fail(definition.id, body_id, &"attack", item_id, "projectile launch socket is invalid")
				return false
	actor.free()
	return true

func _fail(class_id: StringName, body_id: StringName, action_id: StringName, item_id: StringName, reason: String) -> void:
	push_error("PARTY_FORGE_CHARACTER_VISUAL_QA_ERROR class=%s body=%s action=%s item=%s reason=%s" % [class_id, body_id, action_id, item_id, reason])
	quit(1)
