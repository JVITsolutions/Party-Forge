extends SceneTree

const SANDBOX_PATH := "res://scenes/dev/character_presentation_sandbox.tscn"
const SIDE_IDS: Array[StringName] = [&"Masculine", &"Feminine"]
const BODY_IDS: Array[StringName] = [&"masculine", &"feminine"]
const PALETTE_IDS: Array[StringName] = [&"red", &"blue", &"green"]
const CLIP_IDS: Array[StringName] = [&"idle", &"attack_slash", &"attack_combo", &"hit_flinch"]

func _initialize() -> void:
	var scene := load(SANDBOX_PATH) as PackedScene
	if scene == null:
		_fail("scene missing")
		return
	var sandbox := scene.instantiate() as CharacterPresentationSandbox
	if sandbox == null:
		_fail("scene root is invalid")
		return
	root.add_child(sandbox)
	sandbox._ready()
	for side_id: StringName in SIDE_IDS:
		if not sandbox.set_base_profile(true, side_id) or not sandbox.is_base_profile(side_id):
			_fail("base profile rejected side=%s" % side_id)
			return
		if not sandbox.set_base_profile(false, side_id) or sandbox.is_base_profile(side_id):
			_fail("equipped profile rejected side=%s" % side_id)
			return
		if sandbox.get_equipped_visual_id(&"main_hand", side_id) != &"forge_vanguard_sword":
			_fail("default sword missing side=%s" % side_id)
			return
		if not sandbox.cycle_slot_variant(&"main_hand", 1, side_id) or sandbox.get_equipped_visual_id(&"main_hand", side_id) != &"forge_vanguard_hammer":
			_fail("hammer cycle rejected side=%s" % side_id)
			return
		if not sandbox.cycle_slot_variant(&"main_hand", 1, side_id) or sandbox.get_equipped_visual_id(&"main_hand", side_id) != &"forge_vanguard_sword":
			_fail("sword cycle rejected side=%s" % side_id)
			return
		for body_id: StringName in BODY_IDS:
			if not sandbox.set_body(body_id, side_id):
				_fail("body rejected side=%s body=%s" % [side_id, body_id])
				return
		for palette_id: StringName in PALETTE_IDS:
			if not sandbox.set_palette(palette_id, side_id) or sandbox.get_palette_id(side_id) != palette_id:
				_fail("palette rejected side=%s palette=%s" % [side_id, palette_id])
				return
		for slot_id: StringName in EquipmentSlotCatalog.SLOT_IDS:
			if not sandbox.toggle_slot(slot_id, true, side_id) or not sandbox.toggle_slot(slot_id, false, side_id):
				_fail("slot toggle rejected side=%s slot=%s" % [side_id, slot_id])
				return
		for clip_id: StringName in CLIP_IDS:
			if not sandbox.play_clip(clip_id, side_id):
				_fail("clip rejected side=%s clip=%s" % [side_id, clip_id])
				return
		if not sandbox.trigger_hit(side_id) or not sandbox.set_downed(true, side_id) or not sandbox.set_downed(false, side_id):
			_fail("feedback rejected side=%s" % side_id)
			return
	if not sandbox.set_palette(&"red", &"Masculine") or not sandbox.set_palette(&"blue", &"Feminine"):
		_fail("isolated palette setup rejected")
		return
	if sandbox.get_palette_id(&"Masculine") == sandbox.get_palette_id(&"Feminine"):
		_fail("palette state leaked between models")
		return
	print("PARTY_FORGE_PRESENTATION_SMOKE_OK bodies=2 palettes=3 slots=10 animations=4")
	quit(0)

func _fail(reason: String) -> void:
	push_error("PARTY_FORGE_PRESENTATION_SMOKE_ERROR %s" % reason)
	quit(1)
