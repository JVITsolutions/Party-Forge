extends RefCounted

const CLASS_CARD_SCENE := "res://scenes/ui/living_forge/components/forge_class_card.tscn"
const SEAT_CARD_SCENE := "res://scenes/ui/living_forge/components/forge_seat_card.tscn"
const STATUS_BADGE_SCENE := "res://scenes/ui/living_forge/components/forge_status_badge.tscn"
const ACTION_BAR_SCENE := "res://scenes/ui/living_forge/components/forge_action_bar.tscn"
const INPUT_PROMPT_SCENE := "res://scenes/ui/living_forge/components/forge_input_prompt.tscn"
const ACTIVE_INPUT_DEVICE_SCRIPT := "res://scripts/ui/input/active_input_device.gd"
const REQUIRED_STATES: Array[StringName] = [
	&"focused", &"previewed", &"selected", &"locked", &"compatible",
	&"needs_attention", &"pending", &"disabled", &"success", &"warning", &"error",
]
const COMING_SOON_COPY := "LOCAL CO-OP - COMING SOON"


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_component_resources_and_semantic_cues(failures)
	_test_class_card_contract(failures)
	_test_class_card_compound_layers_and_lifecycle(failures)
	_test_class_card_intrinsic_and_external_locks(failures)
	_test_future_seats_are_inert(failures)
	_test_active_seat_prompt_context(failures)
	_test_status_badge_shape_and_typography(failures)
	_test_action_bar_emission_contract(failures)
	_test_input_prompt_and_active_device_contracts(failures)
	return failures


func _test_component_resources_and_semantic_cues(failures: Array[String]) -> void:
	for path: String in [CLASS_CARD_SCENE, SEAT_CARD_SCENE, STATUS_BADGE_SCENE, INPUT_PROMPT_SCENE]:
		TestAssertions.truthy(ResourceLoader.exists(path), "%s exists" % path, failures)
		var component := _instantiate(path)
		if component == null:
			continue
		TestAssertions.truthy(component.has_method(&"semantic_state_inventory"), "%s exposes its semantic presentation inventory" % path, failures)
		if component.has_method(&"semantic_state_inventory"):
			var inventory: Dictionary = component.call(&"semantic_state_inventory")
			for state_value: Variant in inventory.keys():
				var state := StringName(state_value)
				var cue: Dictionary = inventory[state_value]
				TestAssertions.truthy(not String(cue.get("text", "")).strip_edges().is_empty(), "%s %s has a text cue" % [path, state], failures)
				TestAssertions.truthy(not String(cue.get("icon", "")).strip_edges().is_empty(), "%s %s has an icon cue" % [path, state], failures)
				TestAssertions.truthy(not String(cue.get("shape", "")).strip_edges().is_empty(), "%s %s has a shape cue" % [path, state], failures)
				TestAssertions.truthy(not String(cue.get("accessibility_description", "")).strip_edges().is_empty(), "%s %s has an accessibility description" % [path, state], failures)
		component.free()
	# Metadata completeness is not visual acceptance. The component/state-board
	# tests below and the rendered integration runner prove actual nodes and geometry.
	TestAssertions.truthy(ResourceLoader.exists(ACTION_BAR_SCENE), "%s exists" % ACTION_BAR_SCENE, failures)


func _test_class_card_contract(failures: Array[String]) -> void:
	var card := _instantiate(CLASS_CARD_SCENE)
	if card == null:
		return
	var data := {
		"class_id": &"fighter",
		"name": "Forge Vanguard",
		"role": "Frontline",
		"playstyle": "Hold the line",
		"selected": true,
		"compatible": true,
		"accessibility_description": "Forge Vanguard class card. Frontline. Selected and compatible.",
	}
	var original := data.duplicate(true)
	TestAssertions.truthy(card.has_method(&"present"), "class card exposes present(data)", failures)
	TestAssertions.truthy(card.has_method(&"set_previewed"), "class card exposes set_previewed(bool)", failures)
	TestAssertions.truthy(card.has_method(&"set_interaction_locked"), "class card exposes set_interaction_locked(bool)", failures)
	if not card.has_method(&"present"):
		card.free()
		return
	card.call(&"present", data)
	TestAssertions.equal(data, original, "class card presentation does not mutate projection input", failures)
	TestAssertions.equal(String((card.get_node("Content/Identity/Name") as Label).text), "Forge Vanguard", "class card presents name", failures)
	TestAssertions.equal(String((card.get_node("Content/Identity/Role") as Label).text), "Frontline", "class card presents role", failures)
	TestAssertions.equal(String((card.get_node("Content/Identity/Playstyle") as Label).text), "Hold the line", "class card presents supplied playstyle", failures)
	TestAssertions.truthy(not String(card.get("accessibility_description")).strip_edges().is_empty(), "class card exposes an accessibility description", failures)

	var preview_ids: Array[StringName] = []
	var selection_ids: Array[StringName] = []
	if card.has_signal(&"preview_requested"):
		card.connect(&"preview_requested", func(class_id: StringName) -> void: preview_ids.append(class_id))
	if card.has_signal(&"selection_requested"):
		card.connect(&"selection_requested", func(class_id: StringName) -> void: selection_ids.append(class_id))
	TestAssertions.truthy(card.has_signal(&"preview_requested"), "class card exposes preview_requested(class_id)", failures)
	TestAssertions.truthy(card.has_signal(&"selection_requested"), "class card exposes selection_requested(class_id)", failures)
	if card.has_method(&"request_preview"):
		card.call(&"request_preview")
	TestAssertions.equal(preview_ids, [&"fighter"], "class card requests exactly one preview without committing selection", failures)
	if card.has_method(&"request_selection"):
		card.call(&"request_selection")
	TestAssertions.equal(selection_ids, [&"fighter"], "class card requests exactly one selection", failures)

	card.call(&"set_interaction_locked", true)
	if card.has_method(&"request_preview"):
		card.call(&"request_preview")
	if card.has_method(&"request_selection"):
		card.call(&"request_selection")
	TestAssertions.equal(preview_ids.size(), 1, "locked class card does not request another preview", failures)
	TestAssertions.equal(selection_ids.size(), 1, "locked class card does not request another selection", failures)
	card.free()


func _test_class_card_compound_layers_and_lifecycle(failures: Array[String]) -> void:
	var card := _instantiate(CLASS_CARD_SCENE)
	if card == null:
		return
	var layer_paths := [
		"FocusFrame", "PreviewIndicator", "SelectionNotch", "CompatibilityBadge",
		"AttentionBadge", "LockOverlay",
	]
	for path: String in layer_paths:
		TestAssertions.truthy(card.get_node_or_null(path) is Control, "class card owns independent %s layer" % path, failures)
	var shape_paths := [
		"FocusFrame", "PreviewIndicator/Shape", "SelectionNotch/Shape",
		"CompatibilityBadge/Shape", "AttentionBadge/Shape", "LockOverlay/Plate",
	]
	for path: String in shape_paths:
		var shape := card.get_node_or_null(path) as Control
		TestAssertions.truthy(shape != null and shape.custom_minimum_size.x > 0.0 and shape.custom_minimum_size.y > 0.0, "%s is real nonzero visual geometry" % path, failures)
	for layer_path: String in ["PreviewIndicator", "SelectionNotch", "CompatibilityBadge", "AttentionBadge"]:
		var geometry := card.get_node_or_null("%s/Shape/Geometry" % layer_path) as Polygon2D
		var icon := card.get_node_or_null("%s/Icon" % layer_path) as TextureRect
		TestAssertions.truthy(geometry != null and geometry.polygon.size() >= 3, "%s renders authored polygon shape geometry" % layer_path, failures)
		TestAssertions.truthy(icon != null and icon.texture != null and icon.custom_minimum_size.x > 0.0, "%s renders a separate semantic icon" % layer_path, failures)
	card.call(&"present", {
		"class_id": &"fighter",
		"name": "Forge Vanguard",
		"role": "Frontline",
		"selected": true,
		"compatible": true,
		"accessibility_description": "Forge Vanguard. Selected and compatible.",
	})
	var selection := card.get_node_or_null("SelectionNotch") as Control
	var compatibility := card.get_node_or_null("CompatibilityBadge") as Control
	var preview := card.get_node_or_null("PreviewIndicator") as Control
	var focus := card.get_node_or_null("FocusFrame") as Control
	TestAssertions.truthy(selection != null and selection.visible, "selected layer is visible", failures)
	TestAssertions.truthy(compatibility != null and compatibility.visible, "compatible layer is independently visible with selection", failures)
	TestAssertions.truthy(preview != null and not preview.visible, "preview layer starts independently inactive", failures)
	card.call(&"set_previewed", true)
	TestAssertions.truthy(preview != null and preview.visible, "parent-controlled preview layer becomes visible", failures)
	TestAssertions.truthy(selection != null and selection.visible and compatibility != null and compatibility.visible, "preview preserves selected and compatible layers", failures)

	var previews: Array[StringName] = []
	var selections: Array[StringName] = []
	card.connect(&"preview_requested", func(class_id: StringName) -> void: previews.append(class_id))
	card.connect(&"selection_requested", func(class_id: StringName) -> void: selections.append(class_id))
	for lifecycle_method: StringName in [&"_on_focus_entered", &"_on_focus_exited", &"_on_mouse_entered", &"_on_mouse_exited"]:
		TestAssertions.truthy(card.has_method(lifecycle_method), "class card exposes %s lifecycle" % lifecycle_method, failures)
	card.call(&"_on_focus_entered")
	TestAssertions.equal(previews, [&"fighter"], "focus emits one preview request", failures)
	TestAssertions.equal(selections, [], "focus preview never commits selection", failures)
	TestAssertions.truthy(focus != null and focus.visible, "focus entrance shows only the focus frame layer", failures)
	TestAssertions.truthy(selection != null and selection.visible and compatibility != null and compatibility.visible and preview != null and preview.visible, "focus preserves persistent selection compatibility and preview layers", failures)
	if card.has_method(&"_on_focus_exited"):
		card.call(&"_on_focus_exited")
	TestAssertions.truthy(focus != null and not focus.visible, "focus exit removes focus frame", failures)
	TestAssertions.truthy(selection != null and selection.visible and compatibility != null and compatibility.visible and preview != null and preview.visible, "focus exit restores remaining persistent layers", failures)
	card.call(&"set_previewed", false)
	TestAssertions.truthy(preview != null and not preview.visible, "parent-controlled preview can clear independently", failures)
	if card.has_method(&"_on_mouse_entered"):
		card.call(&"_on_mouse_entered")
	TestAssertions.equal(previews, [&"fighter", &"fighter"], "mouse hover emits preview request", failures)
	TestAssertions.equal(selections, [], "mouse hover does not select", failures)
	TestAssertions.truthy(preview != null and preview.visible, "mouse hover shows preview indicator", failures)
	if card.has_method(&"_on_mouse_exited"):
		card.call(&"_on_mouse_exited")
	TestAssertions.truthy(preview != null and not preview.visible and selection != null and selection.visible and compatibility != null and compatibility.visible, "mouse exit removes transient preview only", failures)

	card.call(&"present", {
		"class_id": &"fighter", "name": "Forge Vanguard", "role": "Frontline",
		"selected": true, "needs_attention": true,
	})
	var attention := card.get_node_or_null("AttentionBadge") as Control
	TestAssertions.truthy(selection != null and selection.visible and attention != null and attention.visible, "selected and needs-attention layers remain visible together", failures)
	card.call(&"set_interaction_locked", true)
	var lock_overlay := card.get_node_or_null("LockOverlay") as Control
	TestAssertions.truthy(lock_overlay != null and lock_overlay.visible, "locked overlay is visibly layered", failures)
	TestAssertions.truthy(selection != null and selection.visible and attention != null and attention.visible, "locked overlay does not collapse persistent semantic layers", failures)
	var player_copy := " ".join(_label_texts(card))
	for forbidden: String in ["DOUBLE OUTLINE", "DIAMOND NOTCH", "GOLD NOTCH", "LOCK PLATE", "TEAL CHEVRON", "WARNING TRIANGLE", "BROKEN HEX", "CHECKED HEX"]:
		TestAssertions.truthy(forbidden not in player_copy, "class card does not print shape-name prose: %s" % forbidden, failures)
	card.free()


func _test_class_card_intrinsic_and_external_locks(failures: Array[String]) -> void:
	var card := _instantiate(CLASS_CARD_SCENE)
	if card == null:
		return
	var previews: Array[StringName] = []
	var selections: Array[StringName] = []
	card.connect(&"preview_requested", func(class_id: StringName) -> void: previews.append(class_id))
	card.connect(&"selection_requested", func(class_id: StringName) -> void: selections.append(class_id))
	var scenarios: Array[Dictionary] = [
		{"label": "intrinsically disabled", "data": {"disabled": true}},
		{"label": "authored locked", "data": {"locked": true}},
		{"label": "pending", "data": {"pending": true}},
	]
	for scenario: Dictionary in scenarios:
		var data := {"class_id": &"fighter", "name": "Forge Vanguard", "role": "Frontline"}
		data.merge(scenario["data"] as Dictionary, true)
		card.call(&"present", data)
		card.call(&"set_interaction_locked", true)
		card.call(&"set_interaction_locked", false)
		TestAssertions.truthy(card.disabled, "%s card remains disabled after external lock then unlock" % scenario["label"], failures)
		TestAssertions.truthy((card.get_node("LockOverlay") as Control).visible, "%s card retains its lock overlay after external unlock" % scenario["label"], failures)
		card.call(&"request_preview")
		card.call(&"request_selection")
		card.call(&"_on_focus_entered")
		card.call(&"_on_mouse_entered")
	TestAssertions.equal(previews, [], "non-actionable lock states emit exactly zero previews", failures)
	TestAssertions.equal(selections, [], "non-actionable lock states emit exactly zero selections", failures)

	card.call(&"set_interaction_locked", true)
	card.call(&"present", {"class_id": &"fighter", "name": "Forge Vanguard", "role": "Frontline"})
	TestAssertions.truthy(card.disabled, "repeated present preserves the independent external interaction lock", failures)
	card.call(&"set_interaction_locked", false)
	TestAssertions.truthy(not card.disabled and not (card.get_node("LockOverlay") as Control).visible, "unlock after repeated actionable present clears only the external gate", failures)
	card.call(&"present", {"class_id": &"fighter", "name": "Forge Vanguard", "role": "Frontline", "disabled": true})
	card.call(&"present", {"class_id": &"fighter", "name": "Forge Vanguard", "role": "Frontline"})
	TestAssertions.truthy(not card.disabled, "repeated present clears stale intrinsic disabled/authored locked/pending projection state", failures)
	card.free()


func _test_future_seats_are_inert(failures: Array[String]) -> void:
	for seat_number: int in range(2, 5):
		var seat := _instantiate(SEAT_CARD_SCENE)
		if seat == null:
			return
		var projection := {
			"seat_number": seat_number,
			"available": false,
			"accessibility_description": "Player %d. Local co-op coming soon. Unavailable." % seat_number,
		}
		var original := projection.duplicate(true)
		TestAssertions.truthy(seat.has_method(&"present"), "seat card exposes present(data)", failures)
		if seat.has_method(&"present"):
			seat.call(&"present", projection)
		TestAssertions.equal(projection, original, "seat %d presentation does not mutate projection input" % seat_number, failures)
		TestAssertions.equal(seat.focus_mode, Control.FOCUS_NONE, "seat %d is outside the focus loop" % seat_number, failures)
		TestAssertions.equal(seat.mouse_filter, Control.MOUSE_FILTER_IGNORE, "seat %d ignores mouse input" % seat_number, failures)
		var future_plate := seat.get_node_or_null("Content/FuturePlate") as Control
		var lock_shape := seat.get_node_or_null("Content/FuturePlate/Row/LockShape") as Control
		var availability := seat.get_node_or_null("Content/FuturePlate/Row/Availability") as Label
		TestAssertions.truthy(future_plate != null and future_plate.visible, "seat %d has a visible future plate" % seat_number, failures)
		TestAssertions.truthy(lock_shape != null and lock_shape.custom_minimum_size.x > 0.0 and lock_shape.custom_minimum_size.y > 0.0, "seat %d has real lock geometry" % seat_number, failures)
		TestAssertions.equal(availability.text if availability != null else "", COMING_SOON_COPY, "seat %d has exact Coming Soon copy" % seat_number, failures)
		TestAssertions.truthy(seat.has_method(&"apply_accessibility_variant"), "seat %d exposes normal/high-contrast icon treatment" % seat_number, failures)
		for high_contrast: bool in [false, true]:
			seat.theme = LivingForgeThemeCatalog.resolve(high_contrast, 100, 100)
			if seat.has_method(&"apply_accessibility_variant"):
				seat.call(&"apply_accessibility_variant", high_contrast)
			var tint_material := lock_shape.material as ShaderMaterial if lock_shape != null else null
			TestAssertions.truthy(tint_material != null, "seat %d lock icon uses a ShaderMaterial tint in high_contrast=%s" % [seat_number, high_contrast], failures)
			if tint_material != null:
				var expected_tint := LivingForgeTokens.color(&"disabled", high_contrast)
				var actual_tint := tint_material.get_shader_parameter(&"icon_color") as Color
				TestAssertions.equal(actual_tint, expected_tint, "seat %d lock icon resolves the disabled semantic token in high_contrast=%s" % [seat_number, high_contrast], failures)
				var badge_style := future_plate.get_theme_stylebox(&"panel") as StyleBoxFlat if future_plate != null else null
				TestAssertions.truthy(badge_style != null, "seat %d future plate resolves its actual badge surface" % seat_number, failures)
				if badge_style != null:
					TestAssertions.truthy(_contrast_ratio(actual_tint, badge_style.bg_color) >= 3.0, "seat %d lock tint contrasts with its actual badge surface at >=3:1 in high_contrast=%s" % [seat_number, high_contrast], failures)
		if availability != null:
			seat.theme = LivingForgeThemeCatalog.resolve(false, 100, 100)
			TestAssertions.truthy(availability.get_theme_font_size(&"font_size") >= 16, "seat %d Coming Soon copy is player-readable" % seat_number, failures)
		TestAssertions.truthy(not String(seat.get("accessibility_description")).strip_edges().is_empty(), "seat %d has an accessibility description" % seat_number, failures)
		for signal_data: Dictionary in seat.get_signal_list():
			var signal_name := String(signal_data.get("name", "")).to_lower()
			TestAssertions.truthy("join" not in signal_name, "seat %d exposes no fake join signal" % seat_number, failures)
		TestAssertions.truthy(not seat.has_method(&"request_join"), "seat %d exposes no fake join action" % seat_number, failures)
		seat.free()
	var default_seat := _instantiate(SEAT_CARD_SCENE)
	if default_seat != null:
		default_seat.call(&"present", {"seat_number": 2, "available": false})
		var default_description := String(default_seat.accessibility_description).to_lower()
		TestAssertions.truthy(default_description.contains("local co-op") and default_description.contains("coming soon") and default_description.contains("unavailable"), "unavailable seat default accessibility names local co-op Coming Soon and unavailable", failures)
		default_seat.free()


func _test_active_seat_prompt_context(failures: Array[String]) -> void:
	var seat := _instantiate(SEAT_CARD_SCENE)
	if seat == null:
		return
	seat.call(&"present", {
		"seat_number": 1,
		"available": true,
		"profile_name": "Input Qualification",
		"status": "READY",
		"accessibility_description": "Player 1 seat. Input Qualification. Ready.",
	})
	TestAssertions.truthy(seat.has_method(&"present_prompt_device"), "active seat exposes presentation-only prompt device context", failures)
	if seat.has_method(&"present_prompt_device"):
		seat.call(&"present_prompt_device", &"controller", false)
		TestAssertions.equal((seat.get_node("Content/Ready") as Label).text, "READY · PROMPTS: GAMEPAD", "active seat desktop copy identifies gamepad prompts without ownership", failures)
		TestAssertions.truthy(String(seat.accessibility_description).to_lower().contains("current prompt style is gamepad") and String(seat.accessibility_description).contains("No controller is assigned"), "active seat accessibility explains prompt style without controller assignment", failures)
		seat.call(&"present_prompt_device", &"keyboard_mouse", false)
		TestAssertions.equal((seat.get_node("Content/Ready") as Label).text, "READY · PROMPTS: KEYBOARD + MOUSE", "active seat desktop copy identifies keyboard and mouse prompts", failures)
		seat.call(&"present_prompt_device", &"controller", true)
		TestAssertions.truthy((seat.get_node("Content/Ready") as Label).text.contains("GAMEPAD"), "active seat compact copy retains gamepad prompt meaning", failures)
	TestAssertions.equal((seat.get_node("Content/Identity") as Label).text, "Input Qualification", "prompt context preserves active-seat identity", failures)
	TestAssertions.equal(seat.focus_mode, Control.FOCUS_NONE, "active seat prompt context remains outside focus", failures)
	TestAssertions.equal(seat.mouse_filter, Control.MOUSE_FILTER_IGNORE, "active seat prompt context remains pointer inert", failures)
	seat.free()


func _test_status_badge_shape_and_typography(failures: Array[String]) -> void:
	var badge := _instantiate(STATUS_BADGE_SCENE)
	if badge == null:
		return
	badge.theme = LivingForgeThemeCatalog.resolve(false, 100, 100)
	badge.call(&"present", {"state": &"warning", "label": "Review Loadout"})
	TestAssertions.equal(badge.theme_type_variation, &"LivingForgeStatusBadge", "badge root uses panel-specific enclosure variation", failures)
	var text := badge.get_node_or_null("Content/Text") as Label
	TestAssertions.truthy(text != null and text.theme_type_variation == &"LivingForgeBadgeLabel", "badge text uses a label-only variation", failures)
	TestAssertions.truthy(text != null and text.get_theme_font_size(&"font_size") >= 16, "badge player copy is at least 16px", failures)
	var shape := badge.get_node_or_null("Content/ShapeLayer") as Control
	TestAssertions.truthy(shape != null and shape.visible and shape.custom_minimum_size.x > 0.0 and shape.custom_minimum_size.y > 0.0, "badge owns visible nonzero shape geometry inside one enclosure", failures)
	var badge_geometry := badge.get_node_or_null("Content/ShapeLayer/Geometry") as Polygon2D
	TestAssertions.truthy(badge_geometry != null and badge_geometry.polygon.size() >= 3, "badge renders authored semantic polygon geometry", failures)
	TestAssertions.truthy("WARNING TRIANGLE" not in text.text and "BROKEN HEX" not in text.text and "CHECKED HEX" not in text.text, "badge removes printed shape-name prose", failures)
	badge.free()


func _test_action_bar_emission_contract(failures: Array[String]) -> void:
	var bar := _instantiate(ACTION_BAR_SCENE)
	if bar == null:
		return
	(Engine.get_main_loop() as SceneTree).root.add_child(bar)
	bar.theme = LivingForgeThemeCatalog.resolve(false, 100, 100)
	var actions: Array[Dictionary] = [
		{"id": &"back", "label": "Back", "enabled": true, "kind": &"secondary", "accessibility_description": "Return to the forge."},
		{"id": &"start", "label": "Start Run", "enabled": true, "kind": &"primary", "accessibility_description": "Start the selected run."},
		{"id": &"blocked", "label": "Unavailable", "enabled": false, "kind": &"unavailable", "reason": "Choose a class first.", "accessibility_description": "Unavailable. Choose a class first."},
	]
	var original := actions.duplicate(true)
	TestAssertions.truthy(bar.has_method(&"present"), "action bar exposes present(actions)", failures)
	TestAssertions.truthy(not bar.has_method(&"semantic_state_inventory"), "action bar exposes no dead cue-string inventory", failures)
	if not bar.has_method(&"present"):
		bar.free()
		return
	bar.call(&"present", actions)
	TestAssertions.equal(actions, original, "action bar presentation does not mutate projection input", failures)
	var emitted: Array[StringName] = []
	TestAssertions.truthy(bar.has_signal(&"action_requested"), "action bar exposes action_requested(action_id)", failures)
	if bar.has_signal(&"action_requested"):
		bar.connect(&"action_requested", func(action_id: StringName) -> void: emitted.append(action_id))
	for action_id: StringName in [&"back", &"start", &"blocked"]:
		var button := bar.call(&"button_for", action_id) as Button if bar.has_method(&"button_for") else null
		TestAssertions.truthy(button != null, "action bar exposes %s button" % action_id, failures)
		if button == null:
			continue
		TestAssertions.truthy(button.custom_minimum_size.x >= 48.0 and button.custom_minimum_size.y >= 48.0, "%s respects the 48px target floor" % action_id, failures)
		TestAssertions.truthy(fmod(button.custom_minimum_size.x, 8.0) == 0.0 and fmod(button.custom_minimum_size.y, 8.0) == 0.0, "%s target follows the 8px grid" % action_id, failures)
		TestAssertions.truthy(button.visible and not String(button.accessibility_description).strip_edges().is_empty(), "%s renders visible accessible output" % action_id, failures)
		if action_id == &"back":
			TestAssertions.equal(button.theme_type_variation, &"LivingForgeSecondaryButton", "back renders the Secondary variation", failures)
			TestAssertions.truthy(button.get_theme_stylebox(&"normal") != null and button.get_theme_stylebox(&"focus") != null and button.get_theme_stylebox(&"pressed") != null, "back resolves normal/focused/pressed rendered styles", failures)
		elif action_id == &"start":
			TestAssertions.equal(button.theme_type_variation, &"LivingForgePrimaryButton", "start renders the Primary variation", failures)
			TestAssertions.truthy(button.get_theme_stylebox(&"normal") != null and button.get_theme_stylebox(&"focus") != null and button.get_theme_stylebox(&"pressed") != null, "start resolves normal/focused/pressed rendered styles", failures)
		else:
			TestAssertions.equal(button.theme_type_variation, &"LivingForgeUnavailableButton", "blocked renders the unavailable variation", failures)
			TestAssertions.truthy(button.disabled and button.get_theme_stylebox(&"disabled") != null, "blocked resolves a visible disabled style and remains inert", failures)
			TestAssertions.equal(button.tooltip_text, "Choose a class first.", "blocked exposes its unavailable reason", failures)
		button.pressed.emit()
	TestAssertions.equal(emitted, [&"back", &"start"], "enabled actions emit exactly once and disabled actions never emit", failures)
	bar.free()


func _test_input_prompt_and_active_device_contracts(failures: Array[String]) -> void:
	var prompt := _instantiate(INPUT_PROMPT_SCENE)
	if prompt != null:
		var action_id := &"living_forge_select"
		if InputMap.has_action(action_id):
			InputMap.erase_action(action_id)
		InputMap.add_action(action_id)
		var key := InputEventKey.new()
		key.physical_keycode = KEY_ENTER
		InputMap.action_add_event(action_id, key)
		var joy := InputEventJoypadButton.new()
		joy.button_index = JOY_BUTTON_A
		InputMap.action_add_event(action_id, joy)
		var keyboard_label := InputBindingFormatter.events_for_device(InputMap.action_get_events(action_id), false)
		var controller_label := InputBindingFormatter.events_for_device(InputMap.action_get_events(action_id), true)
		TestAssertions.truthy(prompt.has_method(&"present"), "input prompt exposes present(action_id, device_kind, label)", failures)
		TestAssertions.truthy(prompt.has_method(&"present_contextual"), "input prompt extends presentation with contextual player copy", failures)
		TestAssertions.truthy(prompt.has_method(&"label_for_action"), "input prompt resolves labels from InputMap", failures)
		TestAssertions.equal(prompt.focus_mode, Control.FOCUS_NONE, "input prompt is outside the focus graph", failures)
		TestAssertions.equal(prompt.mouse_filter, Control.MOUSE_FILTER_IGNORE, "input prompt ignores pointer input", failures)
		if prompt.has_method(&"label_for_action"):
			TestAssertions.equal(prompt.call(&"label_for_action", action_id, &"keyboard_mouse"), keyboard_label, "keyboard prompt uses InputBindingFormatter.events_for_device", failures)
			TestAssertions.equal(prompt.call(&"label_for_action", action_id, &"controller"), controller_label, "controller prompt uses InputBindingFormatter.events_for_device", failures)
		if prompt.has_method(&"present"):
			prompt.call(&"present", action_id, &"controller", controller_label)
			TestAssertions.equal(prompt.get("raw_binding_label"), controller_label, "input prompt retains full raw formatter source", failures)
			TestAssertions.equal((prompt.get_node("Content/Label") as Label).text, "A — Select", "controller prompt presents compact couch-readable copy", failures)
			TestAssertions.truthy(prompt.tooltip_text.contains(controller_label) and String(prompt.accessibility_description).contains(controller_label), "raw controller formatter detail remains in tooltip and accessibility copy", failures)
			prompt.call(&"present", action_id, &"keyboard_mouse", keyboard_label)
			TestAssertions.equal((prompt.get_node("Content/Label") as Label).text, "Enter — Select", "keyboard prompt presents a stable concise binding", failures)
			prompt.theme = LivingForgeThemeCatalog.resolve(false, 100, 100)
			TestAssertions.truthy((prompt.get_node("Content/Label") as Label).get_theme_font_size(&"font_size") >= 16, "prompt copy is player-readable", failures)
		if prompt.has_method(&"present_contextual"):
			prompt.call(&"present_contextual", &"ui_accept", &"controller", "A", "Start Run")
			TestAssertions.equal((prompt.get_node("Content/Label") as Label).text, "A — Start Run", "contextual prompt presents the supplied lobby action without changing binding authority", failures)
		TestAssertions.truthy(not String(prompt.get("accessibility_description")).strip_edges().is_empty(), "input prompt has an accessibility description", failures)
		InputMap.erase_action(action_id)
		prompt.free()

	TestAssertions.truthy(ResourceLoader.exists(ACTIVE_INPUT_DEVICE_SCRIPT), "active input device tracker exists", failures)
	if not ResourceLoader.exists(ACTIVE_INPUT_DEVICE_SCRIPT):
		return
	var tracker_script := load(ACTIVE_INPUT_DEVICE_SCRIPT) as Script
	var tracker: Object = tracker_script.new()
	TestAssertions.truthy(tracker.has_method(&"observe"), "active input device exposes observe(event)", failures)
	TestAssertions.truthy(not tracker.has_method(&"assign_player"), "active input device cannot assign a player", failures)
	TestAssertions.truthy(not _has_property(tracker, &"player_id") and not _has_property(tracker, &"player_index"), "active input device stores no player assignment", failures)
	var keyboard := InputEventKey.new()
	keyboard.physical_keycode = KEY_SPACE
	keyboard.pressed = true
	var controller := InputEventJoypadButton.new()
	controller.device = 3
	controller.button_index = JOY_BUTTON_A
	controller.pressed = true
	TestAssertions.equal(tracker.call(&"observe", keyboard), false, "initial keyboard observation leaves prompt mode unchanged", failures)
	TestAssertions.equal(tracker.call(&"observe", controller), true, "controller observation changes prompt mode", failures)
	TestAssertions.equal(StringName(tracker.get("device_kind")), &"controller", "tracker reports controller prompt mode", failures)
	TestAssertions.equal(tracker.call(&"observe", controller), false, "same device observation does not report a change", failures)
	TestAssertions.equal(tracker.call(&"observe", keyboard), true, "keyboard observation changes prompt mode back", failures)
	TestAssertions.equal(StringName(tracker.get("device_kind")), &"keyboard_mouse", "tracker reports keyboard and mouse prompt mode", failures)
	tracker = null


func _instantiate(path: String) -> Control:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	return packed.instantiate() as Control


func _has_property(object: Object, property_name: StringName) -> bool:
	return object.get_property_list().any(func(property: Dictionary) -> bool: return StringName(property.get("name", &"")) == property_name)


func _label_texts(root: Node) -> Array[String]:
	var result: Array[String] = []
	for node: Node in root.find_children("*", "Label", true, false):
		result.append((node as Label).text)
	return result


func _contrast_ratio(first: Color, second: Color) -> float:
	var brighter := maxf(_relative_luminance(first), _relative_luminance(second))
	var darker := minf(_relative_luminance(first), _relative_luminance(second))
	return (brighter + 0.05) / (darker + 0.05)


func _relative_luminance(value: Color) -> float:
	var red := value.r / 12.92 if value.r <= 0.04045 else pow((value.r + 0.055) / 1.055, 2.4)
	var green := value.g / 12.92 if value.g <= 0.04045 else pow((value.g + 0.055) / 1.055, 2.4)
	var blue := value.b / 12.92 if value.b <= 0.04045 else pow((value.b + 0.055) / 1.055, 2.4)
	return 0.2126 * red + 0.7152 * green + 0.0722 * blue
