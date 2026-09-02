extends SceneTree

const VIEWPORT_SIZES: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

var _failures: Array[String] = []
var _profile_root := ""


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_profile_root = "user://tests/passive_tree_responsive_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ProfileTestSupport.remove_tree(_profile_root)
	var manager := ProfileManager.new(ProfileStore.new(), ProfileIndexStore.new(), func() -> String: return "responsive-passive-profile")
	_assert(manager.bootstrap(_profile_root).is_empty(), "responsive profile manager bootstraps")
	var created := manager.create_profile("Responsive Passive Profile", 1000)
	_assert(created.ok(), "responsive profile is created")
	if not created.ok():
		_finish(null)
		return
	var profile_id := created.profile.profile_id
	var profile_mutations := ProfileMutationService.new(ProfileStore.new())
	_assert(ProfileTestSupport.commit_city_victory(profile_id, "responsive-first-victory", _profile_root).ok(), "responsive profile commits first-victory City discovery")
	_assert(profile_mutations.grant_passive_points(profile_id, "responsive-grant", 5, _profile_root).ok(), "responsive profile receives points")
	_assert(manager.refresh_profile(profile_id).is_empty(), "responsive manager refreshes its profile")
	var loaded := PassiveTreeCatalog.load_defaults()
	_assert(loaded.ok(), "responsive runner loads the committed City tree")
	if not loaded.ok():
		_finish(null)
		return

	var effects := PassiveEffectRegistry.new()
	var requirements := PassiveRequirementRegistry.new()
	var progression := PassiveTreeProgressionService.new(effects, requirements)
	var resolver := PassiveEffectResolver.new(effects)
	var mutations := PassiveTreeMutationService.new(profile_mutations, progression, resolver)
	var view_model := PassiveTreeViewModel.new(progression, resolver, effects, requirements)
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.size = VIEWPORT_SIZES[0]
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var screen := (load("res://scenes/ui/passive_tree/passive_tree_screen.tscn") as PackedScene).instantiate() as PassiveTreeScreen
	viewport.add_child(screen)
	await _frames(2)
	screen.configure(loaded.tree, manager, mutations, view_model, true, _profile_root)
	screen.open()
	await _frames(3)

	var overlay := screen.get_node("Overlay") as Control
	var frame := screen.get_node("Overlay/Frame") as Control
	var canvas := screen.get_node("Overlay/Frame/Layout/Body/Canvas") as PassiveTreeCanvas
	var detail := screen.get_node("Overlay/Frame/Layout/Body/DetailScroll") as ScrollContainer
	var points := screen.get_node("Overlay/Frame/Layout/Header/Points") as Label
	var confirmation := screen.get_node("Overlay/Confirmation") as Control
	var confirm_button := screen.get_node("Overlay/Confirmation/Content/Buttons/ConfirmButton") as Button
	var cancel_button := screen.get_node("Overlay/Confirmation/Content/Buttons/CancelButton") as Button
	var allocate_button := screen.get_node("Overlay/Frame/Layout/Body/DetailScroll/DetailBody/Actions/AllocateButton") as Button
	var detail_sections := screen.get_node("Overlay/Frame/Layout/Body/DetailScroll/DetailBody/DetailSections") as Label

	for viewport_size: Vector2i in VIEWPORT_SIZES:
		var before_failure_count := _failures.size()
		viewport.size = viewport_size
		await _frames(3)
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
		_assert_rect(overlay.get_global_rect(), viewport_rect, "overlay", viewport_size)
		_assert_contained(viewport_rect, frame, "frame", viewport_size)
		_assert_contained(frame.get_global_rect(), canvas, "canvas", viewport_size)
		_assert_contained(frame.get_global_rect(), detail, "detail", viewport_size)
		_assert_contained(frame.get_global_rect(), points, "Passive Points header", viewport_size)
		_assert(canvas.size.x >= 560.0 and canvas.size.y >= 420.0, "canvas retains usable minimum geometry at %dx%d" % [viewport_size.x, viewport_size.y])
		_assert(detail.size.x >= 340.0 and detail.size.y >= 420.0, "detail retains usable minimum geometry at %dx%d" % [viewport_size.x, viewport_size.y])

		canvas.set_zoom(1.0)
		canvas.set_pan(Vector2.ZERO)
		_assert(canvas.select_node(&"city-heart"), "root is selectable at %dx%d" % [viewport_size.x, viewport_size.y])
		for step: int in range(4):
			_assert(canvas.select_connected(Vector2.UP), "linked navigation step %d reaches the far branch at %dx%d" % [step + 1, viewport_size.x, viewport_size.y])
		_assert(canvas.selected_node_id() == &"hero-registry", "linked navigation reaches hero-registry at %dx%d" % [viewport_size.x, viewport_size.y])
		var far_control := canvas.node_control(&"hero-registry")
		var far_view := canvas.node_view(&"hero-registry")
		canvas.set_pan(-far_view.position * canvas.zoom_value())
		await _frames(2)
		_assert(_encloses(canvas.get_global_rect(), far_control.get_global_rect()), "canvas pan brings the far selected node into view at %dx%d" % [viewport_size.x, viewport_size.y])
		_assert(detail_sections.text.contains("Coming Soon") and detail_sections.text.contains("Developer Preview"), "future-node disclosure remains readable at %dx%d" % [viewport_size.x, viewport_size.y])

		canvas.select_node(&"equipment-registry")
		_assert(detail_sections.text.contains("Cost") and detail_sections.text.contains("Refund Policy"), "selected detail disclosures remain readable at %dx%d" % [viewport_size.x, viewport_size.y])
		_assert(detail_sections.text.contains("Unlock Feature: equipment_inventory.") and not detail_sections.text.contains("Coming Soon"), "implemented Equipment Registry disclosure remains readable at %dx%d" % [viewport_size.x, viewport_size.y])
		allocate_button.pressed.emit()
		await _frames(2)
		_assert(confirmation.visible and confirmation.is_visible_in_tree(), "confirmation is visible at %dx%d" % [viewport_size.x, viewport_size.y])
		_assert_contained(viewport_rect, confirmation, "confirmation", viewport_size)
		_assert_contained(confirmation.get_global_rect(), confirm_button, "Confirm button", viewport_size)
		_assert_contained(confirmation.get_global_rect(), cancel_button, "Cancel button", viewport_size)
		_assert(confirm_button.focus_mode != Control.FOCUS_NONE and cancel_button.focus_mode != Control.FOCUS_NONE, "confirmation actions remain reachable at %dx%d" % [viewport_size.x, viewport_size.y])
		cancel_button.pressed.emit()
		await process_frame
		if _failures.size() == before_failure_count:
			print("PASSIVE_TREE_RESPONSIVE_SIZE_PASS size=%dx%d" % [viewport_size.x, viewport_size.y])

	screen.close()
	await _finish(viewport)


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame


func _assert_contained(outer: Rect2, control: Control, label: String, viewport_size: Vector2i) -> void:
	_assert(control.visible and control.is_visible_in_tree(), "%s is visible at %dx%d" % [label, viewport_size.x, viewport_size.y])
	_assert(control.size.x > 0.0 and control.size.y > 0.0, "%s has positive geometry at %dx%d" % [label, viewport_size.x, viewport_size.y])
	_assert(_encloses(outer, control.get_global_rect()), "%s is contained at %dx%d" % [label, viewport_size.x, viewport_size.y])


func _assert_rect(actual: Rect2, expected: Rect2, label: String, viewport_size: Vector2i) -> void:
	_assert(actual.position.distance_to(expected.position) <= 1.0 and actual.size.distance_to(expected.size) <= 1.0, "%s matches the real viewport at %dx%d" % [label, viewport_size.x, viewport_size.y])


func _encloses(outer: Rect2, inner: Rect2) -> bool:
	return outer.grow(1.0).encloses(inner)


func _finish(viewport: SubViewport) -> void:
	paused = false
	if viewport != null and is_instance_valid(viewport):
		viewport.free()
	ProfileTestSupport.remove_tree(_profile_root)
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_profile_root)):
		_failures.append("disposable responsive profile root was not removed")
	if _failures.is_empty():
		print("PASSIVE_TREE_RESPONSIVE_SUMMARY: PASS (%d sizes)" % VIEWPORT_SIZES.size())
		quit(0)
		return
	for failure: String in _failures:
		push_error("PASSIVE_TREE_RESPONSIVE_FAILURE: %s" % failure)
	print("PASSIVE_TREE_RESPONSIVE_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
