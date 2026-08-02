extends SceneTree

const MODEL_PATH := "res://scenes/characters/presentation/forge_humanoid_model.tscn"
const ACTION_ORIGIN_SOCKET := &"ActionOriginSocket"
const PROJECTILE_LAUNCH_SOCKET := &"ProjectileLaunchSocket"
const SET_FOLDERS := {
	&"fighter": &"forge_vanguard", &"paladin": &"dawn_bulwark", &"ranger": &"greenwood", &"marksman": &"siege_archer", &"rogue": &"nightstep",
	&"mage": &"emberweave", &"frost_mage": &"rime_scholar", &"cleric": &"storm_chaplain", &"warlock": &"grave_covenant",
}
const PROFILE_IDS := {&"fighter": &"forge_vanguard", &"paladin": &"paladin", &"ranger": &"ranger", &"marksman": &"marksman", &"rogue": &"rogue", &"mage": &"mage", &"frost_mage": &"frost_mage", &"cleric": &"cleric", &"warlock": &"warlock"}
const IDLE_ACTIONS := {&"fighter": &"idle", &"paladin": &"paladin_idle", &"ranger": &"ranger_idle", &"marksman": &"marksman_idle", &"rogue": &"rogue_idle", &"mage": &"mage_idle", &"frost_mage": &"frost_mage_idle", &"cleric": &"cleric_idle", &"warlock": &"warlock_idle"}
const CLASS_COLORS := {
	&"fighter": Color("d94f4f"), &"paladin": Color("e6c85f"), &"ranger": Color("5fbd72"), &"marksman": Color("465d0e"), &"rogue": Color("a95be8"),
	&"mage": Color("9567e8"), &"frost_mage": Color("70c8ff"), &"cleric": Color("f0d15b"), &"warlock": Color("7e4bc4"),
}
const CLASS_ATTACKS := {
	&"fighter": [&"fighter_cleave"], &"paladin": [&"paladin_smite"], &"ranger": [&"ranger_shot"], &"marksman": [&"marksman_heavy_shot"], &"rogue": [&"rogue_flurry"],
	&"mage": [&"mage_burst"], &"frost_mage": [&"frost_shard"], &"cleric": [&"cleric_bolt", &"cleric_heal"], &"warlock": [&"warlock_bolt"],
}
const ATTACKS := {
	&"fighter_cleave": {&"action": &"attack_slash", &"event": &"impact", &"family": &"one_hand_sword", &"duration": 0.55, &"release": 0.28},
	&"paladin_smite": {&"action": &"paladin_hammer_smite", &"event": &"impact", &"family": &"one_hand_hammer", &"duration": 0.86, &"release": 0.58},
	&"ranger_shot": {&"action": &"ranger_quick_bow_shot", &"event": &"release", &"family": &"light_bow", &"duration": 0.42, &"release": 0.18, &"projectile": "res://scenes/combat/presentation/projectiles/ranger_arrow.tscn"},
	&"marksman_heavy_shot": {&"action": &"marksman_heavy_bow_shot", &"event": &"release", &"family": &"greatbow", &"duration": 1.55, &"release": 1.15, &"projectile": "res://scenes/combat/presentation/projectiles/marksman_heavy_arrow.tscn", &"scale": Vector3(1.45, 1.45, 1.45)},
	&"rogue_flurry": {&"action": &"rogue_dagger_flurry", &"event": &"impact", &"family": &"dual_daggers", &"duration": 0.28, &"release": 0.16},
	&"mage_burst": {&"action": &"mage_fire_burst", &"event": &"release", &"family": &"wand", &"duration": 0.76, &"release": 0.46, &"projectile": "res://scenes/combat/presentation/projectiles/mage_fire_orb.tscn", &"impact": "res://scenes/combat/presentation/effects/fire_impact.tscn", &"color": Color("ff7043")},
	&"frost_shard": {&"action": &"frost_staff_shard", &"event": &"release", &"family": &"staff", &"duration": 0.88, &"release": 0.52, &"projectile": "res://scenes/combat/presentation/projectiles/frost_shard.tscn", &"impact": "res://scenes/combat/presentation/effects/frost_impact.tscn", &"color": Color("8ee8ff")},
	&"cleric_bolt": {&"action": &"cleric_lightning_bolt", &"event": &"release", &"family": &"sceptre", &"duration": 0.62, &"release": 0.34, &"projectile": "res://scenes/combat/presentation/projectiles/cleric_lightning_bolt.tscn", &"impact": "res://scenes/combat/presentation/effects/lightning_impact.tscn", &"color": Color("fff08a")},
	&"cleric_heal": {&"action": &"cleric_healing_blessing", &"event": &"release", &"family": &"sceptre", &"duration": 1.08, &"release": 0.72, &"impact": "res://scenes/combat/presentation/effects/healing_blessing.tscn", &"color": Color("fff08a")},
	&"warlock_bolt": {&"action": &"warlock_chaos_bolt", &"event": &"release", &"family": &"wand", &"duration": 1.02, &"release": 0.64, &"projectile": "res://scenes/combat/presentation/projectiles/warlock_chaos_bolt.tscn", &"impact": "res://scenes/combat/presentation/effects/chaos_impact.tscn", &"color": Color("a64de0")},
}

func _initialize() -> void:
	for attack_id: StringName in ATTACKS:
		if not _write_attack(attack_id, ATTACKS[attack_id]): _fail("attack=%s" % attack_id); return
	for class_id: StringName in PROFILE_IDS:
		if not _write_profile(class_id): _fail("class=%s" % class_id); return
	print("CLASS_PRESENTATION_PROFILE_BUILD_OK classes=%d attacks=%d" % [PROFILE_IDS.size(), ATTACKS.size()])
	quit(0)

func _write_attack(attack_id: StringName, spec: Dictionary) -> bool:
	var ext_lines := "[ext_resource type=\"Script\" path=\"res://scripts/presentation/attack_presentation_definition.gd\" id=\"1\"]\n"
	var projectile_ref := ""
	var impact_ref := ""
	var next_id := 2
	if spec.has(&"projectile"):
		ext_lines += "[ext_resource type=\"PackedScene\" path=\"%s\" id=\"%d\"]\n" % [spec[&"projectile"], next_id]
		projectile_ref = "ExtResource(\"%d\")" % next_id; next_id += 1
	if spec.has(&"impact"):
		ext_lines += "[ext_resource type=\"PackedScene\" path=\"%s\" id=\"%d\"]\n" % [spec[&"impact"], next_id]
		impact_ref = "ExtResource(\"%d\")" % next_id; next_id += 1
	var launch_socket := PROJECTILE_LAUNCH_SOCKET if spec[&"family"] in [&"light_bow", &"greatbow"] else ACTION_ORIGIN_SOCKET
	var body := "[resource]\nscript = ExtResource(\"1\")\nid = &\"%s_visual\"\nattack_id = &\"%s\"\naction_id = &\"%s\"\nrequired_event_name = &\"%s\"\nweapon_animation_family_id = &\"%s\"\nlaunch_socket_id = &\"%s\"\n" % [attack_id, attack_id, spec[&"action"], spec[&"event"], spec[&"family"], launch_socket]
	if not projectile_ref.is_empty(): body += "projectile_scene = %s\n" % projectile_ref
	if spec.has(&"scale"): body += "projectile_scale = %s\n" % _vector_literal(spec[&"scale"])
	if not impact_ref.is_empty(): body += "impact_scene = %s\n" % impact_ref
	body += "impact_color = %s\naction_duration = %s\nrelease_time = %s\n" % [_color_literal(spec.get(&"color", Color.WHITE)), spec[&"duration"], spec[&"release"]]
	var text := "[gd_resource type=\"Resource\" script_class=\"AttackPresentationDefinition\" load_steps=%d format=3]\n\n%s\n%s" % [next_id, ext_lines, body]
	return _write_text("res://data/presentation/attacks/%s.tres" % attack_id, text)

func _write_profile(class_id: StringName) -> bool:
	var folder := String(SET_FOLDERS[class_id])
	var item_ids: Array = ClassEquipmentRows.SET_ITEM_IDS[class_id]
	var default_count := 10 if class_id == &"frost_mage" else 11
	var ext_lines := "[ext_resource type=\"Script\" path=\"res://scripts/presentation/character_visual_profile.gd\" id=\"1\"]\n[ext_resource type=\"Script\" path=\"res://scripts/equipment/equipment_loadout_entry.gd\" id=\"2\"]\n[ext_resource type=\"PackedScene\" path=\"%s\" id=\"3\"]\n" % MODEL_PATH
	var item_ref_ids: Array[int] = []
	var next_id := 4
	for item_id: StringName in item_ids:
		ext_lines += "[ext_resource type=\"Resource\" path=\"res://data/equipment/bases/%s/%s.tres\" id=\"%d\"]\n" % [folder, item_id, next_id]
		item_ref_ids.append(next_id); next_id += 1
	var attack_ref_ids: Array[int] = []
	for attack_id: StringName in CLASS_ATTACKS[class_id]:
		ext_lines += "[ext_resource type=\"Resource\" path=\"res://data/presentation/attacks/%s.tres\" id=\"%d\"]\n" % [attack_id, next_id]
		attack_ref_ids.append(next_id); next_id += 1
	var subresources := ""
	var entry_refs: PackedStringArray = []
	for index: int in default_count:
		var slot_id := ClassEquipmentRows.slot_for(class_id, index)
		subresources += "\n[sub_resource type=\"Resource\" id=\"Entry%d\"]\nscript = ExtResource(\"2\")\nslot_id = &\"%s\"\nitem = ExtResource(\"%d\")\n" % [index, slot_id, item_ref_ids[index]]
		entry_refs.append("SubResource(\"Entry%d\")" % index)
	var available_refs: PackedStringArray = []
	for ref_id: int in item_ref_ids: available_refs.append("ExtResource(\"%d\")" % ref_id)
	var presentation_refs: PackedStringArray = []
	for ref_id: int in attack_ref_ids: presentation_refs.append("ExtResource(\"%d\")" % ref_id)
	var required: Array = [&"idle", &"walk", &"hit_flinch"]
	if IDLE_ACTIONS[class_id] not in required: required.append(IDLE_ACTIONS[class_id])
	var animation_pairs: PackedStringArray = []
	for attack_id: StringName in CLASS_ATTACKS[class_id]:
		var action_id: StringName = ATTACKS[attack_id][&"action"]
		if action_id not in required: required.append(action_id)
		animation_pairs.append("&\"%s\": &\"%s\"" % [attack_id, action_id])
	var palette_id := &"red" if class_id == &"fighter" else &"class"
	var palette_colors := "{&\"class\": %s}" % _color_literal(CLASS_COLORS[class_id])
	if class_id == &"fighter":
		palette_colors = "{&\"red\": %s, &\"blue\": %s, &\"green\": %s}" % [_color_literal(Color("d94f4f")), _color_literal(Color("4f78d9")), _color_literal(Color("4faf72"))]
	var body := "[resource]\nscript = ExtResource(\"1\")\nid = &\"%s\"\npresentation_scene = ExtResource(\"3\")\ndefault_body_preset = &\"masculine\"\ndefault_palette_id = &\"%s\"\npalette_colors = %s\ndefault_equipment = [%s]\navailable_equipment = [%s]\nidle_action_id = &\"%s\"\nwalk_action_id = &\"walk\"\nrequired_animation_names = %s\nattack_animation_by_id = {%s}\nattack_presentations = [%s]\n" % [PROFILE_IDS[class_id], palette_id, palette_colors, ", ".join(entry_refs), ", ".join(available_refs), IDLE_ACTIONS[class_id], _string_name_array(required), ", ".join(animation_pairs), ", ".join(presentation_refs)]
	var text := "[gd_resource type=\"Resource\" script_class=\"CharacterVisualProfile\" load_steps=%d format=3]\n\n%s%s\n%s" % [next_id + default_count, ext_lines, subresources, body]
	return _write_text("res://data/presentation/profiles/%s.tres" % PROFILE_IDS[class_id], text)

func _string_name_array(values: Array) -> String:
	var parts: PackedStringArray = []
	for value: Variant in values: parts.append("&\"%s\"" % StringName(value))
	return "[%s]" % ", ".join(parts)

func _color_literal(color: Color) -> String:
	return "Color(%s, %s, %s, %s)" % [color.r, color.g, color.b, color.a]

func _vector_literal(value: Vector3) -> String:
	return "Vector3(%s, %s, %s)" % [value.x, value.y, value.z]

func _write_text(path: String, text: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(text)
	return file.get_error() == OK

func _fail(reason: String) -> void:
	push_error("CLASS_PRESENTATION_PROFILE_BUILD_ERROR %s" % reason)
	quit(1)
