extends RefCounted

const SANDBOX_PATH := "res://scenes/dev/character_presentation_sandbox.tscn"
const REQUIRED_NODES := [
	"Models/Masculine",
	"Models/Feminine",
	"FallbackCapsule",
	"CameraRig/Camera3D",
	"DirectionalLight3D",
	"Floor",
	"UI/Instructions",
	"UI/ClassSelector",
	"UI/BodySelector",
	"UI/SlotSelector",
	"UI/Diagnostics",
]

func run() -> Array[String]:
	var failures: Array[String] = []
	var scene := load(SANDBOX_PATH) as PackedScene
	TestAssertions.truthy(scene != null, "presentation sandbox scene loads", failures)
	if scene == null:
		return failures
	var sandbox := scene.instantiate() as Node3D
	var has_review_api := sandbox != null and sandbox.get_script() != null and sandbox.has_method(&"set_class") and sandbox.has_method(&"get_class_id") and sandbox.has_method(&"set_body") and sandbox.has_method(&"set_palette") and sandbox.has_method(&"toggle_slot") and sandbox.has_method(&"play_clip") and sandbox.has_method(&"play_primary") and sandbox.has_method(&"preview_specialized_effect") and sandbox.has_method(&"trigger_hit") and sandbox.has_method(&"cycle_slot_variant") and sandbox.has_method(&"equip_variant") and sandbox.has_method(&"get_equipped_visual_id")
	TestAssertions.truthy(has_review_api, "presentation sandbox exposes review API", failures)
	if sandbox == null or not has_review_api:
		return failures
	for node_path: String in REQUIRED_NODES:
		TestAssertions.truthy(sandbox.get_node_or_null(node_path) != null, "presentation sandbox node exists: %s" % node_path, failures)
	var instructions := sandbox.get_node_or_null("UI/Instructions") as Label
	TestAssertions.truthy(instructions != null and "1/2 Body" in instructions.text and "Space Toggle Selected Slot" in instructions.text and "V Cycle Variant" in instructions.text, "presentation sandbox lists controls", failures)
	(Engine.get_main_loop() as SceneTree).root.add_child(sandbox)
	sandbox.call(&"_process", 0.0)
	TestAssertions.equal((sandbox.get_node("UI/ClassSelector") as OptionButton).item_count, 9, "sandbox has nine class selectors", failures)
	TestAssertions.equal((sandbox.get_node("UI/BodySelector") as OptionButton).item_count, 2, "sandbox has two body selectors", failures)
	TestAssertions.equal((sandbox.get_node("UI/SlotSelector") as OptionButton).item_count, 11, "sandbox has eleven slot selectors", failures)
	for class_id: StringName in [&"fighter", &"ranger", &"mage", &"cleric", &"paladin", &"rogue", &"frost_mage", &"warlock", &"marksman"]:
		TestAssertions.truthy(bool(sandbox.call(&"set_class", class_id, &"Masculine")), "sandbox selects %s" % class_id, failures)
		TestAssertions.equal(sandbox.call(&"get_class_id", &"Masculine"), class_id, "sandbox records %s" % class_id, failures)
		TestAssertions.truthy(bool(sandbox.call(&"play_primary", &"Masculine")), "sandbox plays %s primary" % class_id, failures)
		TestAssertions.truthy(bool(sandbox.call(&"preview_specialized_effect", &"Masculine")), "sandbox previews %s effect" % class_id, failures)
	TestAssertions.truthy(bool(sandbox.call(&"set_class", &"fighter", &"Masculine")), "sandbox restores Fighter", failures)
	var diagnostics := sandbox.get_node("UI/Diagnostics") as Label
	TestAssertions.truthy("class=fighter" in diagnostics.text and "body=" in diagnostics.text and "slot=" in diagnostics.text and "item=" in diagnostics.text and "action=" in diagnostics.text, "sandbox diagnostics expose review IDs", failures)
	TestAssertions.truthy(sandbox.has_method(&"_process"), "presentation sandbox advances feedback during frame updates", failures)
	if not sandbox.has_method(&"_process"):
		sandbox.free()
		return failures
	TestAssertions.equal(sandbox.call(&"get_palette_id", &"Masculine"), &"red", "sandbox initializes masculine with red palette", failures)
	TestAssertions.equal(sandbox.call(&"get_palette_id", &"Feminine"), &"blue", "sandbox initializes feminine with blue palette", failures)
	var masculine_presentation := sandbox.get_node_or_null("Models/Masculine") as CharacterPresentation
	var feminine_presentation := sandbox.get_node_or_null("Models/Feminine") as CharacterPresentation
	var masculine_base_color := _primary_color(masculine_presentation)
	var feminine_base_color := _primary_color(feminine_presentation)
	TestAssertions.truthy(bool(sandbox.call(&"trigger_hit", &"Masculine")), "sandbox triggers masculine hit feedback", failures)
	TestAssertions.near(masculine_presentation.hit_remaining if masculine_presentation != null else 0.0, 0.1, 0.001, "masculine hit feedback starts", failures)
	TestAssertions.truthy(_primary_color(masculine_presentation) != masculine_base_color, "masculine hit feedback tints the base palette", failures)
	sandbox.call(&"_process", 0.11)
	TestAssertions.near(masculine_presentation.hit_remaining if masculine_presentation != null else -1.0, 0.0, 0.001, "sandbox frame update clears masculine hit feedback", failures)
	TestAssertions.equal(_primary_color(masculine_presentation), masculine_base_color, "masculine base palette returns after frame update", failures)
	TestAssertions.near(feminine_presentation.hit_remaining if feminine_presentation != null else -1.0, 0.0, 0.001, "masculine recovery does not start feminine feedback", failures)
	TestAssertions.equal(_primary_color(feminine_presentation), feminine_base_color, "masculine recovery does not tint feminine palette", failures)
	TestAssertions.truthy(bool(sandbox.call(&"trigger_hit", &"Feminine")), "sandbox triggers feminine hit feedback", failures)
	TestAssertions.truthy(_primary_color(feminine_presentation) != feminine_base_color, "feminine hit feedback tints the base palette", failures)
	sandbox.call(&"_process", 0.11)
	TestAssertions.near(feminine_presentation.hit_remaining if feminine_presentation != null else -1.0, 0.0, 0.001, "sandbox frame update clears feminine hit feedback", failures)
	TestAssertions.equal(_primary_color(feminine_presentation), feminine_base_color, "feminine base palette returns after frame update", failures)
	TestAssertions.near(masculine_presentation.hit_remaining if masculine_presentation != null else -1.0, 0.0, 0.001, "feminine recovery keeps masculine feedback clear", failures)
	TestAssertions.equal(sandbox.call(&"get_equipped_visual_id", &"main_hand", &"Masculine"), &"forge_vanguard_sword", "Fighter sandbox starts with sword", failures)
	TestAssertions.truthy(bool(sandbox.call(&"cycle_slot_variant", &"main_hand", 1, &"Masculine")), "sandbox cycles sword to hammer", failures)
	TestAssertions.equal(sandbox.call(&"get_equipped_visual_id", &"main_hand", &"Masculine"), &"forge_vanguard_hammer", "hammer becomes equipped", failures)
	TestAssertions.truthy(bool(sandbox.call(&"cycle_slot_variant", &"main_hand", 1, &"Masculine")), "sandbox wraps hammer to sword", failures)
	TestAssertions.equal(sandbox.call(&"get_equipped_visual_id", &"main_hand", &"Masculine"), &"forge_vanguard_sword", "variant cycling wraps to sword", failures)
	TestAssertions.equal(sandbox.call(&"get_equipped_visual_id", &"main_hand", &"Feminine"), &"forge_vanguard_sword", "masculine variant cycling does not leak to feminine", failures)
	TestAssertions.truthy(not bool(sandbox.call(&"equip_variant", &"missing_item", &"Masculine")), "unknown equipment ID is rejected", failures)
	TestAssertions.truthy(bool(sandbox.call(&"set_base_profile", true, &"Feminine")), "sandbox selects feminine base profile", failures)
	TestAssertions.equal(sandbox.call(&"get_palette_id", &"Feminine"), &"blue", "feminine base profile retains blue palette", failures)
	TestAssertions.truthy(bool(sandbox.call(&"set_base_profile", false, &"Feminine")), "sandbox restores feminine equipped profile", failures)
	TestAssertions.equal(sandbox.call(&"get_palette_id", &"Feminine"), &"blue", "feminine equipped profile retains blue palette", failures)
	TestAssertions.truthy(bool(sandbox.call(&"set_body", &"masculine", &"Masculine")), "sandbox selects masculine body", failures)
	TestAssertions.truthy(bool(sandbox.call(&"set_body", &"feminine", &"Feminine")), "sandbox selects feminine body", failures)
	TestAssertions.truthy(bool(sandbox.call(&"set_palette", &"red", &"Masculine")), "sandbox selects red palette", failures)
	TestAssertions.truthy(bool(sandbox.call(&"set_palette", &"blue", &"Feminine")), "sandbox selects blue palette", failures)
	TestAssertions.equal(sandbox.call(&"get_palette_id", &"Masculine"), &"red", "masculine palette remains local", failures)
	TestAssertions.equal(sandbox.call(&"get_palette_id", &"Feminine"), &"blue", "feminine palette remains local", failures)
	TestAssertions.truthy(bool(sandbox.call(&"toggle_slot", &"amulet", true, &"Masculine")), "sandbox enables an available slot", failures)
	TestAssertions.truthy(bool(sandbox.call(&"toggle_slot", &"amulet", false, &"Masculine")), "sandbox clears an available slot", failures)
	for clip_id: StringName in [&"idle", &"attack_slash", &"attack_combo", &"hit_flinch"]:
		TestAssertions.truthy(bool(sandbox.call(&"play_clip", clip_id, &"Masculine")), "sandbox plays %s" % clip_id, failures)
	TestAssertions.truthy(bool(sandbox.call(&"trigger_hit", &"Feminine")), "sandbox triggers hit feedback", failures)
	sandbox.free()
	return failures

func _primary_color(presentation: CharacterPresentation) -> Color:
	if presentation == null or presentation.active_model == null:
		return Color()
	for node: Node in presentation.active_model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if StringName(mesh.get_meta(&"palette_region", &"")) != &"primary":
			continue
		var material := mesh.material_override as StandardMaterial3D
		if material != null:
			return material.albedo_color
	return Color()
