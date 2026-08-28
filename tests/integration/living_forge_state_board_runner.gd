extends SceneTree

const BOARD_SCENE := preload("res://scenes/dev/living_forge_state_board.tscn")
const CLASS_CARD_SCENE := preload("res://scenes/ui/living_forge/components/forge_class_card.tscn")
const SCREENSHOT_ROOT := "res://docs/validation/screenshots/living-forge-foundation"
const WINDOW_SIZE := Vector2i(1920, 1080)
const REQUIRED_STATES: Array[StringName] = [
	&"focused", &"previewed", &"selected", &"locked", &"compatible",
	&"needs_attention", &"pending", &"disabled", &"success", &"warning", &"error",
]
const EXPECTED_CAPTURE_FILES: Array[String] = [
	"living-forge-state-board-normal.png",
	"living-forge-state-board-compound-states.png",
	"living-forge-state-board-action-states-pressed-proof.png",
	"living-forge-state-board-normal-keyboard-focus.png",
	"living-forge-state-board-normal-controller-focus.png",
	"living-forge-state-board-high-contrast.png",
	"living-forge-state-board-high-contrast-controller-focus.png",
	"living-forge-state-board-class-card-hover-preview.png",
	"living-forge-state-board-normal-mouse-hover.png",
]

var _failures: Array[String] = []
var _capture_evidence := false
var _capture_hashes: Dictionary = {}


func _initialize() -> void:
	_capture_evidence = "--capture-evidence" in OS.get_cmdline_user_args()
	call_deferred(&"_run")


func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = WINDOW_SIZE
	var board := BOARD_SCENE.instantiate() as Control
	root.add_child(board)
	await _frames(5)
	_assert(board != null, "state board instantiates")
	if board == null:
		_finish()
		return

	var initial_signature: Array = board.call(&"component_tree_signature")
	_assert(not initial_signature.is_empty(), "component tree signature is non-empty")
	for state: StringName in REQUIRED_STATES:
		var control := board.call(&"state_control", state) as Control
		_assert(control != null and control.is_visible_in_tree(), "%s state is visible" % state)
		if control != null:
			_assert(not String(control.accessibility_description).strip_edges().is_empty(), "%s state has accessibility description" % state)
			if state in [&"focused", &"previewed", &"selected", &"locked", &"compatible", &"needs_attention", &"pending", &"disabled"]:
				_assert_class_geometry(control, state)
				_assert_class_copy_separation(control, state)
			var badge_icon := control.get_node_or_null("Content/Icon") as TextureRect
			if badge_icon != null:
				_assert(badge_icon.material is ShaderMaterial, "%s badge icon is visibly colorized for dark surfaces" % state)
				var badge_shape := control.get_node_or_null("Content/ShapeLayer") as Control
				_assert(badge_shape != null and badge_shape.is_visible_in_tree() and badge_shape.size.x > 0.0 and badge_shape.size.y > 0.0, "%s badge renders real shape geometry" % state)
	for seat_number: int in range(2, 5):
		var seat := board.get_node("Margin/Layout/SeatRow/Seat_%d" % seat_number) as Control
		var future_plate := seat.get_node("Content/FuturePlate") as Control
		var lock_shape := seat.get_node("Content/FuturePlate/Row/LockShape") as Control
		_assert(future_plate.is_visible_in_tree(), "seat %d future plate is visibly rendered" % seat_number)
		_assert(lock_shape.is_visible_in_tree() and lock_shape.size.x > 0.0 and lock_shape.size.y > 0.0, "seat %d renders nonzero lock geometry" % seat_number)
		var coming_soon := seat.get_node("Content/FuturePlate/Row/Availability") as Label
		_assert(not lock_shape.get_global_rect().intersects(coming_soon.get_global_rect()), "seat %d lock geometry does not overlap Coming Soon copy" % seat_number)
		_assert(_shape_aspect_ratio(lock_shape) <= 2.0, "seat %d lock geometry keeps a readable shape aspect" % seat_number)
		_assert(coming_soon.text == "LOCAL CO-OP - COMING SOON", "seat %d retains exact Coming Soon copy" % seat_number)
		_assert_seat_icon_contrast(seat, false)
	for compound_id: StringName in [&"selected_compatible", &"selected_attention", &"focused_selected", &"select_a", &"preview_b"]:
		var compound := board.call(&"compound_control", compound_id) as Control
		_assert(compound != null and compound.is_visible_in_tree(), "%s compound example is visibly rendered" % compound_id)
		if compound != null:
			var state_viewport := board.get_node("Margin/Layout/Scroll") as Control
			_assert(state_viewport.get_global_rect().encloses(compound.get_global_rect()), "%s compound card is fully contained in the 1920x1080 state viewport viewport=%s card=%s" % [compound_id, state_viewport.get_global_rect(), compound.get_global_rect()])
			var playstyle := compound.get_node("Content/Identity/Playstyle") as Label
			_assert(not playstyle.text.strip_edges().is_empty() and playstyle.is_visible_in_tree(), "%s retains authored playstyle visibly" % compound_id)
			_assert_class_copy_separation(compound, compound_id)
	_assert_compound_layers(board)
	_assert_prompt_presentation(board)
	_assert((board.call(&"visible_enabled_controls_without_consumers") as Array).is_empty(), "every visible enabled control has a consumer")

	for action_id: StringName in [&"inspect", &"confirm", &"unavailable"]:
		var action := board.call(&"action_button", action_id) as Button
		_assert(action != null, "%s action exists" % action_id)
		if action != null:
			_assert(action.custom_minimum_size.x >= 48.0 and action.custom_minimum_size.y >= 48.0, "%s action meets 48px target floor" % action_id)
			_assert(fmod(action.custom_minimum_size.x, 8.0) == 0.0 and fmod(action.custom_minimum_size.y, 8.0) == 0.0, "%s action follows 8px grid" % action_id)
	var primary := board.call(&"interaction_action_button", &"primary") as Button
	var pressed_secondary := board.call(&"interaction_action_button", &"secondary_pressed") as Button
	var inert_unavailable := board.call(&"interaction_action_button", &"unavailable") as Button
	_assert(primary != null and not primary.disabled and int(board.call(&"action_count", &"confirm")) == 0, "Primary interaction example starts enabled and unconsumed")
	_assert(pressed_secondary != null and not pressed_secondary.toggle_mode and not pressed_secondary.button_pressed and int(board.call(&"action_count", &"inspect")) == 0, "Secondary interaction example starts in its normal unconsumed state")
	_assert(inert_unavailable != null and inert_unavailable.disabled, "unavailable interaction example is visibly inert")
	await _assert_class_represent_lifecycle()

	board.call(&"apply_theme_variant", false)
	await _frames(3)
	_assert(board.theme == LivingForgeThemeCatalog.resolve(false, 100, 100), "normal board uses authoritative theme")
	_release_focus()
	await _frames(2)
	_assert(root.gui_get_focus_owner() == null, "normal base evidence has no live focus")
	if _capture_evidence:
		await _capture("living-forge-state-board-normal.png")
	var focused_compound := board.call(&"compound_control", &"focused_selected") as Button
	focused_compound.grab_focus()
	await _frames(3)
	_assert(root.gui_get_focus_owner() == focused_compound, "compound evidence uses the actual focused+selected card")
	_assert((focused_compound.get_node("FocusFrame") as Control).is_visible_in_tree() and (focused_compound.get_node("SelectionNotch") as Control).is_visible_in_tree() and (focused_compound.get_node("CompatibilityBadge") as Control).is_visible_in_tree(), "compound evidence visibly retains focus, selection, and compatibility")
	if _capture_evidence:
		await _capture("living-forge-state-board-compound-states.png")
		_assert_named_captures_differ("living-forge-state-board-normal.png", "living-forge-state-board-compound-states.png")
	_release_focus()
	await _frames(2)
	if _capture_evidence:
		board.call(&"set_action_evidence_mode", true)
		await _frames(3)
		_assert(primary.toggle_mode and primary.button_pressed, "Primary action evidence uses the real pressed draw state")
		_assert(pressed_secondary.toggle_mode and pressed_secondary.button_pressed, "Secondary action evidence uses the real pressed inset draw state")
		_assert(inert_unavailable.disabled, "unavailable action evidence remains disabled and inert")
		_assert(primary.text.contains("PRIMARY") and primary.text.contains("PRESSED"), "Primary pressed proof is explicitly labelled")
		_assert(pressed_secondary.text.contains("SECONDARY") and pressed_secondary.text.contains("PRESSED"), "Secondary pressed proof is explicitly labelled")
		_assert(inert_unavailable.text.contains("UNAVAILABLE") and inert_unavailable.text.contains("INERT"), "unavailable inert proof is explicitly labelled")
		await _capture("living-forge-state-board-action-states-pressed-proof.png", _assert_action_state_pixels.bind(primary, pressed_secondary, inert_unavailable))
		board.call(&"set_action_evidence_mode", false)
		await _frames(3)

	var keyboard_focus := board.call(&"action_button", &"inspect") as Button
	keyboard_focus.grab_focus()
	await _frames(2)
	var selected_a := board.call(&"compound_control", &"select_a") as Button
	var selected_a_was_selected := (selected_a.get_node("SelectionNotch") as Control).is_visible_in_tree()
	await _key(KEY_ENTER)
	_assert(root.gui_get_focus_owner() == keyboard_focus, "real keyboard acceptance leaves focus on Inspect State without correction")
	_assert(int(board.call(&"action_count", &"inspect")) == 1, "real keyboard acceptance consumes Inspect exactly once")
	_assert(StringName(board.call(&"active_prompt_mode")) == &"keyboard_mouse", "keyboard focus retains keyboard/mouse prompts")
	_assert(selected_a_was_selected and (selected_a.get_node("SelectionNotch") as Control).is_visible_in_tree(), "keyboard action leaves selected class data unchanged")
	print("LIVING_FORGE_STATE_BOARD_INTERACTION_PASS device=keyboard focus=%s action=inspect count=1" % keyboard_focus.get_path())
	if _capture_evidence:
		await _capture("living-forge-state-board-normal-keyboard-focus.png")

	var controller_focus := board.call(&"action_button", &"confirm") as Button
	await _joy_button(JOY_BUTTON_DPAD_RIGHT)
	_assert(root.gui_get_focus_owner() == controller_focus, "real controller D-pad navigation lands on Confirm Proof without correction")
	_assert(StringName(board.call(&"active_prompt_mode")) == &"controller", "controller observation changes prompt mode")
	_assert(not _object_has_player_assignment(board), "controller prompt switching assigns no player")
	await _joy_button(JOY_BUTTON_A)
	_assert(root.gui_get_focus_owner() == controller_focus, "controller acceptance retains Confirm Proof focus")
	_assert(int(board.call(&"action_count", &"confirm")) == 1, "real controller acceptance consumes Confirm exactly once")
	_assert((selected_a.get_node("SelectionNotch") as Control).is_visible_in_tree(), "controller action leaves selected class data unchanged")
	print("LIVING_FORGE_STATE_BOARD_INTERACTION_PASS device=controller focus=%s action=confirm count=1 prompt=controller" % controller_focus.get_path())
	if _capture_evidence:
		await _capture("living-forge-state-board-normal-controller-focus.png")

	_release_focus()
	board.call(&"apply_theme_variant", true)
	await _frames(3)
	_assert(board.theme == LivingForgeThemeCatalog.resolve(true, 100, 100), "high-contrast board uses authoritative theme")
	_assert((board.call(&"component_tree_signature") as Array) == initial_signature, "high contrast retains the exact component tree")
	var focused_state := board.call(&"state_control", &"focused") as Control
	_assert((focused_state.get_node("FocusFrame") as Control).is_visible_in_tree() and (focused_state.get_node("PreviewIndicator") as Control).is_visible_in_tree(), "authored focused inventory remains visible after unrelated focus lifecycle and contrast switch")
	for seat_number: int in range(2, 5):
		_assert_seat_icon_contrast(board.get_node("Margin/Layout/SeatRow/Seat_%d" % seat_number) as Control, true)
	_assert(root.gui_get_focus_owner() == null, "high-contrast base evidence releases live focus")
	if _capture_evidence:
		await _capture("living-forge-state-board-high-contrast.png")
	keyboard_focus.grab_focus()
	await _frames(2)
	await _joy_button(JOY_BUTTON_DPAD_RIGHT)
	_assert(root.gui_get_focus_owner() == controller_focus, "high-contrast controller evidence uses real D-pad navigation from initial focus")
	_assert(StringName(board.call(&"active_prompt_mode")) == &"controller", "high-contrast controller evidence retains controller prompts")
	if _capture_evidence:
		await _capture("living-forge-state-board-high-contrast-controller-focus.png")
		_assert_named_captures_differ("living-forge-state-board-high-contrast.png", "living-forge-state-board-high-contrast-controller-focus.png")

	board.call(&"apply_theme_variant", false)
	_release_focus()
	var preview_b := board.call(&"compound_control", &"preview_b") as Button
	selected_a.grab_focus()
	await _frames(2)
	var selected_a_before_keyboard := int(board.call(&"selection_count", &"select_a"))
	await _key(KEY_ENTER)
	_assert(root.gui_get_focus_owner() == selected_a, "class keyboard acceptance uses the actual focused selected-A card")
	_assert(int(board.call(&"selection_count", &"select_a")) == selected_a_before_keyboard + 1, "class keyboard acceptance emits exactly once")
	await _joy_button(JOY_BUTTON_DPAD_RIGHT)
	_assert(root.gui_get_focus_owner() == preview_b, "class controller D-pad navigation reaches preview B without correction")
	var preview_b_before_controller := int(board.call(&"selection_count", &"preview_b"))
	await _joy_button(JOY_BUTTON_A)
	_assert(int(board.call(&"selection_count", &"preview_b")) == preview_b_before_controller + 1, "class controller acceptance emits exactly once")
	_assert((selected_a.get_node("SelectionNotch") as Control).is_visible_in_tree(), "class keyboard/controller activation does not mutate committed selected A presentation")
	_release_focus()
	preview_b.call(&"set_previewed", false)
	var preview_b_before_mouse := int(board.call(&"preview_count", &"preview_b"))
	await _mouse_motion(preview_b.get_global_rect().get_center())
	await _frames(3)
	_assert((preview_b.get_node("PreviewIndicator") as Control).is_visible_in_tree(), "class-card mouse hover renders preview geometry")
	_assert(int(board.call(&"preview_count", &"preview_b")) == preview_b_before_mouse + 1, "class mouse hover emits exactly one preview")
	_assert((selected_a.get_node("SelectionNotch") as Control).is_visible_in_tree(), "preview B does not clear committed selection A")
	_assert(not (preview_b.get_node("SelectionNotch") as Control).visible, "preview B does not silently commit")
	if _capture_evidence:
		await _capture("living-forge-state-board-class-card-hover-preview.png")
	var preview_b_before_click := int(board.call(&"selection_count", &"preview_b"))
	await _mouse_click(preview_b.get_global_rect().get_center())
	_assert(int(board.call(&"selection_count", &"preview_b")) == preview_b_before_click + 1, "class mouse click emits exactly one selection")
	_assert((selected_a.get_node("SelectionNotch") as Control).is_visible_in_tree(), "class mouse click does not mutate committed selected A presentation")
	print("LIVING_FORGE_CLASS_INPUT_PASS keyboard=select_a:1 controller=preview_b:1 mouse=preview_b:1 selected_a_unchanged=true")
	var unavailable_before := int(board.call(&"action_count", &"unavailable"))
	await _mouse_click(inert_unavailable.get_global_rect().get_center())
	_assert(int(board.call(&"action_count", &"unavailable")) == unavailable_before, "real mouse click leaves unavailable action inert")
	var mouse_target := board.call(&"action_button", &"inspect") as Button
	var inspect_before_mouse := int(board.call(&"action_count", &"inspect"))
	await _mouse_click(mouse_target.get_global_rect().get_center())
	await _frames(3)
	_assert(int(board.call(&"action_count", &"inspect")) == inspect_before_mouse + 1, "real mouse click consumes Inspect exactly once")
	_assert(StringName(board.call(&"active_prompt_mode")) == &"keyboard_mouse", "mouse click changes prompt mode without changing selected data")
	_assert((selected_a.get_node("SelectionNotch") as Control).is_visible_in_tree(), "mouse action leaves selected class data unchanged")
	_assert(int(board.call(&"action_count", &"inspect")) == 2 and int(board.call(&"action_count", &"confirm")) == 1 and int(board.call(&"action_count", &"unavailable")) == 0, "real input totals contain no duplicate action events and unavailable remains zero")
	print("LIVING_FORGE_STATE_BOARD_INTERACTION_PASS device=mouse action=inspect count=%d prompt=keyboard_mouse" % int(board.call(&"action_count", &"inspect")))
	if _capture_evidence:
		await _capture("living-forge-state-board-normal-mouse-hover.png")

	_assert((board.call(&"visible_enabled_controls_without_consumers") as Array).is_empty(), "no interaction leaves an unconsumed visible enabled control")
	if _capture_evidence:
		_assert_capture_manifest_complete()
		print("LIVING_FORGE_STATE_BOARD_CAPTURE normal=%s high_contrast=%s" % [
			SCREENSHOT_ROOT.path_join("living-forge-state-board-normal.png"),
			SCREENSHOT_ROOT.path_join("living-forge-state-board-high-contrast.png"),
		])
	board.free()
	await _frames(2)
	_finish()


func _assert_class_represent_lifecycle() -> void:
	var card := CLASS_CARD_SCENE.instantiate() as Button
	root.add_child(card)
	card.position = Vector2(720.0, 360.0)
	var projection := {
		"class_id": &"represent_probe",
		"name": "Re-presentation Probe",
		"role": "Lifecycle",
		"playstyle": "Preserve live interaction layers",
	}
	card.call(&"present", projection)
	var previews: Array[StringName] = []
	var selections: Array[StringName] = []
	card.connect(&"preview_requested", func(class_id: StringName) -> void: previews.append(class_id))
	card.connect(&"selection_requested", func(class_id: StringName) -> void: selections.append(class_id))
	await _mouse_motion(Vector2(1880.0, 1040.0))
	card.call(&"set_previewed", true)
	card.grab_focus()
	await _frames(2)
	var previews_after_focus := previews.size()
	card.call(&"present", projection)
	card.call(&"present", projection)
	_assert(root.gui_get_focus_owner() == card, "repeated present preserves the card's actual engine focus owner")
	_assert((card.get_node("FocusFrame") as Control).is_visible_in_tree(), "repeated present preserves actual focus presentation")
	_assert((card.get_node("PreviewIndicator") as Control).is_visible_in_tree(), "repeated present preserves parent-controlled preview while focused")
	_assert(previews.size() == previews_after_focus, "repeated present emits no spurious preview signal")
	card.release_focus()
	await _frames(2)
	_assert((card.get_node("PreviewIndicator") as Control).is_visible_in_tree(), "parent-controlled preview persists after re-presentation and focus exit")
	card.call(&"set_previewed", false)
	_assert(not (card.get_node("PreviewIndicator") as Control).is_visible_in_tree(), "parent-controlled preview still clears independently after re-presentation")
	var previews_before_hover := previews.size()
	await _mouse_motion(card.get_global_rect().get_center())
	await _frames(2)
	_assert(previews.size() == previews_before_hover + 1, "real mouse entry emits exactly one preview before re-presentation")
	card.call(&"present", projection)
	card.call(&"present", projection)
	_assert((card.get_node("PreviewIndicator") as Control).is_visible_in_tree(), "repeated present preserves the current real hover preview")
	_assert(previews.size() == previews_before_hover + 1, "hover re-presentation emits no duplicate preview signal")
	card.call(&"request_selection")
	_assert(selections == [&"represent_probe"], "re-presented live card remains actionable and selects exactly once")
	await _mouse_motion(Vector2(1880.0, 1040.0))
	await _frames(2)
	_assert(not (card.get_node("PreviewIndicator") as Control).is_visible_in_tree(), "real mouse exit clears preserved hover after re-presentation")
	print("LIVING_FORGE_CLASS_REPRESENT_PASS focus=preserved parent_preview=preserved hover=preserved signals=stable actionable=true")
	card.free()
	await _frames(2)


func _assert_class_geometry(control: Control, state: StringName) -> void:
	var expected_layers := {
		&"focused": ["FocusFrame", "PreviewIndicator"],
		&"previewed": ["PreviewIndicator"],
		&"selected": ["SelectionNotch"],
		&"locked": ["LockOverlay"],
		&"compatible": ["CompatibilityBadge"],
		&"needs_attention": ["AttentionBadge"],
		&"pending": ["LockOverlay"],
		&"disabled": ["LockOverlay"],
	}
	for layer_path: String in expected_layers[state]:
		var layer := control.get_node_or_null(layer_path) as Control
		_assert(layer != null and layer.is_visible_in_tree(), "%s renders independent %s layer" % [state, layer_path])
		if layer != null:
			_assert(layer.size.x > 0.0 and layer.size.y > 0.0, "%s %s has nonzero rendered geometry" % [state, layer_path])
			_assert(control.get_global_rect().grow(2.0).encloses(layer.get_global_rect()), "%s %s stays contained card=%s layer=%s" % [state, layer_path, control.get_global_rect(), layer.get_global_rect()])
			var shape := layer.get_node_or_null("Shape") as Control
			if shape != null:
				_assert(_shape_aspect_ratio(shape) <= 2.0, "%s %s keeps actual shape geometry instead of a stretched bar" % [state, layer_path])


func _assert_class_copy_separation(control: Control, state: StringName) -> void:
	var identity := control.get_node("Content/Identity") as Control
	var visible_layer_texts: Array[Control] = []
	for layer_path: String in ["PreviewIndicator", "SelectionNotch", "CompatibilityBadge", "AttentionBadge"]:
		var layer := control.get_node(layer_path) as Control
		if not layer.visible:
			continue
		var layer_text := layer.get_node("Text") as Control
		visible_layer_texts.append(layer_text)
		_assert(not layer_text.get_global_rect().intersects(identity.get_global_rect()), "%s %s text does not collide with class identity copy identity=%s layer_text=%s" % [state, layer_path, identity.get_global_rect(), layer_text.get_global_rect()])
	for first_index: int in range(visible_layer_texts.size()):
		for second_index: int in range(first_index + 1, visible_layer_texts.size()):
			_assert(not visible_layer_texts[first_index].get_global_rect().intersects(visible_layer_texts[second_index].get_global_rect()), "%s semantic layer texts remain separately readable" % state)


func _shape_aspect_ratio(shape: Control) -> float:
	var shorter := minf(shape.size.x, shape.size.y)
	return INF if shorter <= 0.0 else maxf(shape.size.x, shape.size.y) / shorter


func _assert_compound_layers(board: Control) -> void:
	var selected_compatible := board.call(&"compound_control", &"selected_compatible") as Control
	var selected_attention := board.call(&"compound_control", &"selected_attention") as Control
	var focused_selected := board.call(&"compound_control", &"focused_selected") as Control
	var select_a := board.call(&"compound_control", &"select_a") as Control
	var preview_b := board.call(&"compound_control", &"preview_b") as Control
	_assert((selected_compatible.get_node("SelectionNotch") as Control).is_visible_in_tree() and (selected_compatible.get_node("CompatibilityBadge") as Control).is_visible_in_tree(), "selected+compatible renders both layers")
	_assert((selected_attention.get_node("SelectionNotch") as Control).is_visible_in_tree() and (selected_attention.get_node("AttentionBadge") as Control).is_visible_in_tree(), "selected+attention renders both layers")
	_assert(not (focused_selected.get_node("FocusFrame") as Control).visible and (focused_selected.get_node("SelectionNotch") as Control).is_visible_in_tree() and (focused_selected.get_node("CompatibilityBadge") as Control).is_visible_in_tree(), "focused+selected waits for real live focus while retaining selection and compatibility")
	_assert((select_a.get_node("SelectionNotch") as Control).is_visible_in_tree() and not (select_a.get_node("PreviewIndicator") as Control).visible, "select A remains committed")
	_assert((preview_b.get_node("PreviewIndicator") as Control).is_visible_in_tree() and not (preview_b.get_node("SelectionNotch") as Control).visible, "preview B remains independent")


func _assert_prompt_presentation(board: Control) -> void:
	for prompt: Control in board.get("_prompts") as Array[Control]:
		var displayed := (prompt.get_node("Content/Label") as Label).text
		var raw := String(prompt.get("raw_binding_label"))
		_assert(displayed.contains(" — ") and not displayed.contains("Joypad Button"), "%s uses compact prompt copy" % prompt.name)
		_assert(not raw.is_empty() and prompt.tooltip_text.contains(raw) and String(prompt.accessibility_description).contains(raw), "%s retains raw formatter detail in metadata" % prompt.name)


func _assert_seat_icon_contrast(seat: Control, high_contrast: bool) -> void:
	var future_plate := seat.get_node("Content/FuturePlate") as Control
	var lock_icon := seat.get_node("Content/FuturePlate/Row/LockShape") as TextureRect
	var tint_material := lock_icon.material as ShaderMaterial
	_assert(tint_material != null, "%s Coming Soon lock icon uses a ShaderMaterial tint in high_contrast=%s" % [seat.name, high_contrast])
	if tint_material == null:
		return
	var expected_tint := LivingForgeTokens.color(&"disabled", high_contrast)
	var actual_tint := tint_material.get_shader_parameter(&"icon_color") as Color
	_assert(actual_tint == expected_tint, "%s Coming Soon lock icon resolves the disabled semantic token in high_contrast=%s" % [seat.name, high_contrast])
	var badge_style := future_plate.get_theme_stylebox(&"panel") as StyleBoxFlat
	_assert(badge_style != null, "%s Coming Soon plate resolves its actual badge surface" % seat.name)
	if badge_style != null:
		_assert(_contrast_ratio(actual_tint, badge_style.bg_color) >= 3.0, "%s Coming Soon lock tint contrasts with its actual badge surface at >=3:1 in high_contrast=%s" % [seat.name, high_contrast])


func _key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	root.push_input(release, true)
	await process_frame


func _joy_button(button_index: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button_index
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	var release := event.duplicate() as InputEventJoypadButton
	release.pressed = false
	root.push_input(release, true)
	await process_frame


func _mouse_motion(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	motion.relative = position - root.get_mouse_position()
	root.push_input(motion, true)
	await process_frame


func _mouse_click(position: Vector2) -> void:
	await _mouse_motion(position)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = position
	press.global_position = position
	press.pressed = true
	root.push_input(press, true)
	await process_frame
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release, true)
	await process_frame


func _release_focus() -> void:
	var focus_owner := root.gui_get_focus_owner()
	if focus_owner != null:
		focus_owner.release_focus()


func _capture(file_name: String, content_assertion: Callable = Callable()) -> void:
	await _frames(3)
	var absolute_root := ProjectSettings.globalize_path(SCREENSHOT_ROOT)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_root)
	_assert(directory_error == OK, "screenshot directory is available")
	var image := root.get_texture().get_image()
	_assert(image != null and not image.is_empty(), "%s renderer returns pixels" % file_name)
	if image == null or image.is_empty():
		return
	_assert(image.get_size() == WINDOW_SIZE, "%s is rendered at 1920x1080" % file_name)
	_assert(_image_is_nonblank(image), "%s is a genuinely rendered nonblank frame" % file_name)
	if content_assertion.is_valid():
		content_assertion.call(image)
	_capture_hashes[file_name] = _image_hash(image)
	_assert(image.save_png(absolute_root.path_join(file_name)) == OK, "%s saves" % file_name)


func _assert_named_captures_differ(first: String, second: String) -> void:
	_assert(_capture_hashes.has(first) and _capture_hashes.has(second), "%s and %s both have captured pixel signatures" % [first, second])
	if _capture_hashes.has(first) and _capture_hashes.has(second):
		_assert(_capture_hashes[first] != _capture_hashes[second], "%s and %s contain distinct named-state pixels" % [first, second])


func _assert_capture_manifest_complete() -> void:
	_assert(_capture_hashes.size() == EXPECTED_CAPTURE_FILES.size(), "capture run produces exactly nine named pixel signatures")
	var unique_hashes: Dictionary = {}
	for file_name: String in EXPECTED_CAPTURE_FILES:
		_assert(_capture_hashes.has(file_name), "capture manifest contains required file %s" % file_name)
		if _capture_hashes.has(file_name):
			var signature := String(_capture_hashes[file_name])
			_assert(not signature.is_empty(), "%s has a nonempty captured pixel signature" % file_name)
			unique_hashes[signature] = true
	_assert(unique_hashes.size() == EXPECTED_CAPTURE_FILES.size(), "all nine named capture hashes are globally unique with no static alias")
	var directory := DirAccess.open(SCREENSHOT_ROOT)
	_assert(directory != null, "capture manifest directory opens")
	if directory == null:
		return
	var actual_files: Array[String] = []
	for file_name: String in directory.get_files():
		if file_name.get_extension().to_lower() == "png":
			actual_files.append(file_name)
	actual_files.sort()
	var expected_files := EXPECTED_CAPTURE_FILES.duplicate()
	expected_files.sort()
	_assert(actual_files == expected_files, "capture directory contains exactly the nine expected PNG filenames")


func _image_hash(image: Image) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(image.get_data()) != OK:
		return ""
	return context.finish().hex_encode()


func _assert_action_state_pixels(image: Image, primary: Button, secondary: Button, unavailable: Button) -> void:
	var controls := [primary, secondary, unavailable]
	var slots: Array[StringName] = [&"pressed", &"pressed", &"disabled"]
	var names := ["Primary pressed", "Secondary pressed", "Unavailable inert"]
	var statistics: Array[Dictionary] = []
	for index: int in range(controls.size()):
		var button := controls[index] as Button
		var rect := button.get_global_rect()
		var style := button.get_theme_stylebox(slots[index]) as StyleBoxFlat
		_assert(rect.size.x >= 48.0 and rect.size.y >= 48.0, "%s action-state pixel region has rendered target geometry" % names[index])
		_assert(style != null, "%s action-state proof resolves its authoritative Theme StyleBox" % names[index])
		var stats := _image_region_statistics(image, rect)
		statistics.append(stats)
		_assert(int(stats.get("sample_count", 0)) >= 100, "%s action-state proof samples a bounded rendered region" % names[index])
		_assert(int(stats.get("color_buckets", 0)) >= 6, "%s action-state region contains meaningful color diversity instead of a black frame" % names[index])
		_assert(int(stats.get("visible_samples", 0)) >= 20, "%s action-state region contains visible non-background pixels" % names[index])
		_assert(float(stats.get("mean_luminance", 0.0)) > 0.02, "%s action-state region has meaningful luminance" % names[index])
		if style != null:
			var observed := stats.get("mean_color", Color.BLACK) as Color
			_assert(_color_distance(observed, style.bg_color) < 0.32, "%s captured pixels remain consistent with the exact Theme state StyleBox" % names[index])
	var primary_stats := statistics[0]
	var secondary_stats := statistics[1]
	var unavailable_stats := statistics[2]
	_assert(float(primary_stats.get("mean_luminance", 0.0)) > float(secondary_stats.get("mean_luminance", 0.0)) + 0.08, "Primary pressed fill is visibly distinct from Secondary pressed inset fill")
	_assert(_color_distance(secondary_stats.get("mean_color", Color.BLACK), unavailable_stats.get("mean_color", Color.BLACK)) > 0.01, "Secondary pressed and unavailable inert regions are visibly distinguishable")


func _image_region_statistics(image: Image, global_rect: Rect2) -> Dictionary:
	var start_x := clampi(int(floor(global_rect.position.x)), 0, image.get_width() - 1)
	var start_y := clampi(int(floor(global_rect.position.y)), 0, image.get_height() - 1)
	var end_x := clampi(int(ceil(global_rect.end.x)), start_x + 1, image.get_width())
	var end_y := clampi(int(ceil(global_rect.end.y)), start_y + 1, image.get_height())
	var buckets: Dictionary = {}
	var sample_count := 0
	var visible_samples := 0
	var luminance_total := 0.0
	var color_total := Vector3.ZERO
	for y: int in range(start_y, end_y, 4):
		for x: int in range(start_x, end_x, 4):
			var color := image.get_pixel(x, y)
			var luminance := color.get_luminance()
			buckets[Vector3i(roundi(color.r * 31.0), roundi(color.g * 31.0), roundi(color.b * 31.0))] = true
			sample_count += 1
			luminance_total += luminance
			color_total += Vector3(color.r, color.g, color.b)
			if color.a > 0.9 and luminance > 0.06:
				visible_samples += 1
	var divisor := maxf(float(sample_count), 1.0)
	var mean := color_total / divisor
	return {
		"sample_count": sample_count,
		"visible_samples": visible_samples,
		"color_buckets": buckets.size(),
		"mean_luminance": luminance_total / divisor,
		"mean_color": Color(mean.x, mean.y, mean.z, 1.0),
	}


func _color_distance(first: Color, second: Color) -> float:
	return Vector3(first.r - second.r, first.g - second.g, first.b - second.b).length()


func _contrast_ratio(first: Color, second: Color) -> float:
	var brighter := maxf(_relative_luminance(first), _relative_luminance(second))
	var darker := minf(_relative_luminance(first), _relative_luminance(second))
	return (brighter + 0.05) / (darker + 0.05)


func _relative_luminance(value: Color) -> float:
	var red := value.r / 12.92 if value.r <= 0.04045 else pow((value.r + 0.055) / 1.055, 2.4)
	var green := value.g / 12.92 if value.g <= 0.04045 else pow((value.g + 0.055) / 1.055, 2.4)
	var blue := value.b / 12.92 if value.b <= 0.04045 else pow((value.b + 0.055) / 1.055, 2.4)
	return 0.2126 * red + 0.7152 * green + 0.0722 * blue


func _image_is_nonblank(image: Image) -> bool:
	var sampled_colors: Dictionary = {}
	var opaque_samples := 0
	var step_x := maxi(image.get_width() / 24, 1)
	var step_y := maxi(image.get_height() / 14, 1)
	for y: int in range(0, image.get_height(), step_y):
		for x: int in range(0, image.get_width(), step_x):
			var color := image.get_pixel(x, y)
			sampled_colors[color] = true
			if color.a > 0.9:
				opaque_samples += 1
	return sampled_colors.size() >= 8 and opaque_samples >= 100


func _object_has_player_assignment(object: Object) -> bool:
	if object.has_method(&"assign_player"):
		return true
	return object.get_property_list().any(func(property: Dictionary) -> bool:
		var name := StringName(property.get("name", &""))
		return name == &"player_id" or name == &"player_index"
	)


func _frames(count: int) -> void:
	for _index: int in range(count):
		await process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("LIVING_FORGE_STATE_BOARD_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("LIVING_FORGE_STATE_BOARD_FAILURE: %s" % failure)
	print("LIVING_FORGE_STATE_BOARD_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)
