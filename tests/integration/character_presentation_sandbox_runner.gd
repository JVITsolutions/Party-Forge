extends SceneTree

const CLASS_IDS: Array[StringName] = [&"fighter", &"ranger", &"mage", &"cleric", &"paladin", &"rogue", &"frost_mage", &"warlock", &"marksman"]
const BODY_IDS: Array[StringName] = [&"masculine", &"feminine"]
const EXPECTED_ITEMS := 99
const EXPECTED_ICONS := 198
const EXPECTED_ANIMATIONS := 21
const EXPECTED_PROJECTILES := 6
const EXPECTED_EFFECTS := 5

func _initialize() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var catalog := GameCatalog.load_defaults()
	var catalog_errors := catalog.validate()
	if not catalog_errors.is_empty():
		_fail("class=<catalog> body=<none> slot=<none> item=<none> action=<none> reason=%s" % catalog_errors[0])
		return
	if catalog.equipment_catalog == null or catalog.equipment_catalog.size() != EXPECTED_ITEMS:
		_fail("class=<catalog> body=<none> slot=<none> item=<catalog> action=<none> reason=item_count=%d" % (catalog.equipment_catalog.size() if catalog.equipment_catalog != null else -1))
		return
	var unique_items: Dictionary = {}
	var unique_actions: Dictionary = {}
	var projectile_count := 0
	var effect_count := 0
	for class_id: StringName in CLASS_IDS:
		var definition := catalog.class_by_id(class_id)
		if definition == null or definition.visual_profile == null:
			_fail(_context(class_id, &"<none>", &"<none>", &"<none>", &"<none>", "profile missing"))
			return
		var profile := definition.visual_profile
		for action_id: StringName in profile.required_animation_names:
			unique_actions[action_id] = true
		for attack_visual: AttackPresentationDefinition in profile.attack_presentations:
			if attack_visual == null:
				_fail(_context(class_id, &"<none>", &"<none>", &"<none>", &"<none>", "attack presentation missing"))
				return
			if attack_visual.projectile_scene != null:
				projectile_count += 1
				var projectile_preview := attack_visual.projectile_scene.instantiate()
				if projectile_preview == null:
					_fail(_context(class_id, &"<none>", &"<none>", &"<none>", attack_visual.action_id, "projectile scene rejected"))
					return
				projectile_preview.free()
			if attack_visual.impact_scene != null:
				effect_count += 1
				var effect_preview := attack_visual.impact_scene.instantiate()
				if effect_preview == null:
					_fail(_context(class_id, &"<none>", &"<none>", &"<none>", attack_visual.action_id, "effect scene rejected"))
					return
				effect_preview.free()
		for item: EquipmentBaseDefinition in profile.available_equipment:
			if item == null or item.presentation == null or unique_items.has(item.id):
				_fail(_context(class_id, &"<none>", &"<none>", item.id if item != null else &"<null>", &"<none>", "item link is null or duplicate"))
				return
			unique_items[item.id] = true
			if not _icon_pair_is_valid(item.presentation):
				_fail(_context(class_id, &"<none>", item.presentation.slot_id, item.id, &"<none>", "icon pair invalid"))
				return
		for body_id: StringName in BODY_IDS:
			var presentation := CharacterPresentation.new()
			root.add_child(presentation)
			if not presentation.apply_profile(profile, definition.color) or not presentation.set_body_preset(body_id):
				_fail(_context(class_id, body_id, &"<none>", &"<none>", profile.idle_action_id, "profile or body rejected"))
				return
			if presentation.active_model == null or not presentation.active_model.has_method(&"visual_bounds"):
				_fail(_context(class_id, body_id, &"<none>", &"<none>", profile.idle_action_id, "model bounds API missing"))
				return
			var bounds: AABB = presentation.active_model.call(&"visual_bounds")
			if bounds.size.length_squared() <= 0.0:
				_fail(_context(class_id, body_id, &"<none>", &"<none>", profile.idle_action_id, "visible bounds empty"))
				return
			for entry: EquipmentLoadoutEntry in profile.default_equipment:
				if entry == null or entry.item == null or entry.item.presentation == null:
					_fail(_context(class_id, body_id, entry.slot_id if entry != null else &"<none>", &"<null>", &"<none>", "default item missing"))
					return
				var socket := presentation.active_model.get_node_or_null(NodePath(String(entry.item.presentation.socket_id)))
				if entry.item.presentation.combat_visible and socket == null:
					_fail(_context(class_id, body_id, entry.slot_id, entry.item.id, &"<none>", "socket missing"))
					return
			if not presentation.play_action(profile.idle_action_id) or not presentation.play_action(profile.walk_action_id):
				_fail(_context(class_id, body_id, &"<none>", &"<none>", profile.idle_action_id, "locomotion action rejected"))
				return
			for attack_visual: AttackPresentationDefinition in profile.attack_presentations:
				if not presentation.play_action(attack_visual.action_id):
					_fail(_context(class_id, body_id, &"main_hand", &"<equipped>", attack_visual.action_id, "attack action rejected"))
					return
			presentation.flash_hit()
			if presentation.hit_remaining <= 0.0:
				_fail(_context(class_id, body_id, &"<none>", &"<none>", &"hit_flinch", "hit feedback rejected"))
				return
			presentation.queue_free()
	if unique_items.size() != EXPECTED_ITEMS or unique_actions.size() != EXPECTED_ANIMATIONS or projectile_count != EXPECTED_PROJECTILES or effect_count != EXPECTED_EFFECTS:
		_fail("class=<counts> body=<none> slot=<none> item=%d action=%d reason=projectiles=%d effects=%d" % [unique_items.size(), unique_actions.size(), projectile_count, effect_count])
		return
	var fighter := catalog.class_by_id(&"fighter")
	var hammer := fighter.visual_profile.get_available_equipment_visual_by_id(&"forge_vanguard_hammer")
	if hammer == null:
		_fail(_context(&"fighter", &"masculine", &"main_hand", &"forge_vanguard_hammer", &"attack_slash", "hammer alternative missing"))
		return
	await process_frame
	await process_frame
	print("PARTY_FORGE_PLAYABLE_PRESENTATION_SMOKE_OK classes=9 bodies=2 slots=11 items=99 icons=198 animations=21 projectiles=6 effects=5")
	quit(0)

func _icon_pair_is_valid(visual: EquipmentVisualDefinition) -> bool:
	return visual.icon_master != null and visual.icon_runtime != null and visual.icon_master.get_size() == Vector2(256, 256) and visual.icon_runtime.get_size() == Vector2(128, 128)

func _context(class_id: StringName, body_id: StringName, slot_id: StringName, item_id: StringName, action_id: StringName, reason: String) -> String:
	return "class=%s body=%s slot=%s item=%s action=%s reason=%s" % [class_id, body_id, slot_id, item_id, action_id, reason]

func _fail(reason: String) -> void:
	push_error("PARTY_FORGE_PLAYABLE_PRESENTATION_SMOKE_ERROR %s" % reason)
	quit(1)
