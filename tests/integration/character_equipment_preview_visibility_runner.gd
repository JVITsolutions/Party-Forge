extends SceneTree

const PREVIEW_SCENE := preload("res://scenes/ui/ledger/character_equipment_preview.tscn")
const FIGHTER_DEFINITION := preload("res://data/classes/fighter.tres") as ClassDefinition

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_detached_preview_stays_suspended()
	await _test_visible_ancestor_lifecycle()
	_finish()


func _test_detached_preview_stays_suspended() -> void:
	var preview := PREVIEW_SCENE.instantiate() as CharacterEquipmentPreview
	_assert(preview != null, "detached preview instantiates")
	if preview == null:
		return
	var subviewport := preview.get_node("SubViewport") as SubViewport
	_assert(not preview.is_visible_in_tree(), "detached preview has no effective SceneTree visibility")
	_assert(preview.show_class(FIGHTER_DEFINITION), "detached preview accepts the real Fighter class")
	_assert(subviewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "detached valid preview keeps SubViewport updates disabled")
	preview.free()


func _test_visible_ancestor_lifecycle() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var ancestor := Control.new()
	ancestor.name = "CharacterPreviewVisibilityAncestor"
	ancestor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(ancestor)
	var preview := PREVIEW_SCENE.instantiate() as CharacterEquipmentPreview
	ancestor.add_child(preview)
	await process_frame
	await process_frame
	var subviewport := preview.get_node("SubViewport") as SubViewport
	_assert(preview.is_visible_in_tree(), "attached preview is effectively visible")
	_assert(preview.show_class(FIGHTER_DEFINITION), "attached preview accepts the real Fighter class")
	await process_frame
	_assert(subviewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "valid visible preview enables SubViewport updates")
	ancestor.visible = false
	await process_frame
	await process_frame
	_assert(not preview.is_visible_in_tree(), "hidden ancestor removes effective preview visibility")
	_assert(subviewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "hidden ancestor automatically disables SubViewport updates")
	ancestor.visible = true
	await process_frame
	await process_frame
	_assert(preview.is_visible_in_tree(), "shown ancestor restores effective preview visibility")
	_assert(subviewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "shown ancestor automatically re-enables SubViewport updates")
	preview.clear()
	_assert(subviewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "clear disables visible preview updates")
	ancestor.free()
	await process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	for failure: String in _failures:
		push_error("CHARACTER_EQUIPMENT_PREVIEW_VISIBILITY_FAILURE: %s" % failure)
	print("CHARACTER_EQUIPMENT_PREVIEW_VISIBILITY_SUMMARY: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)
