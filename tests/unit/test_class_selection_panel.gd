extends RefCounted

const LOBBY_SCENE_PATH := "res://scenes/ui/run_setup/run_setup_lobby_panel.tscn"
const SELECTOR_SCRIPT_PATH := "res://scripts/ui/class_selection_panel.gd"


func run() -> Array[String]:
	var failures: Array[String] = []
	_test_scene_and_public_seam(failures)
	if not ResourceLoader.exists(LOBBY_SCENE_PATH):
		return failures
	var panel: Variant = (load(LOBBY_SCENE_PATH) as PackedScene).instantiate()
	if panel == null:
		failures.append("lobby scene instantiates as ClassSelectionPanel")
		return failures
	panel.configure(GameCatalog.load_defaults())
	_test_projection_ownership_theme_and_lifecycle(panel, failures)
	_test_active_prompt_contract(panel, failures)
	_test_authoritative_preview_cue_survives_representations(panel, failures)
	_test_preview_selection_and_start_are_orthogonal(panel, failures)
	_test_complete_action_matrix(panel, failures)
	_test_focus_graph_and_pending_recovery(panel, failures)
	_test_preview_focus_and_start_treatment(panel, failures)
	panel.free()
	return failures


func _test_preview_focus_and_start_treatment(panel: Variant, failures: Array[String]) -> void:
	panel.present(_projection(RunSetupLobbyProjection.State.READY, &"fighter", &"fighter", RunSetupClassProjection.Compatibility.COMPATIBLE))
	panel.call(&"apply_viewport_size", Vector2(1920.0, 1080.0))
	var preview := panel.find_child("Preview", true, false) as CharacterEquipmentPreview
	TestAssertions.equal(preview.focus_mode if preview != null else Control.FOCUS_NONE, Control.FOCUS_ALL, "hero preview participates in keyboard/controller focus", failures)
	for class_projection: RunSetupClassProjection in (panel.get("_projection") as RunSetupLobbyProjection).classes:
		var card := panel.selection_focus(class_projection.id) as Button
		card.focus_entered.emit()
		TestAssertions.equal(card.focus_neighbor_right, card.get_path_to(preview), "%s transfers right focus to its own preview" % class_projection.id, failures)
	var frost := panel.selection_focus(&"frost_mage") as ForgeClassCard
	var frost_name := frost.get_node("Content/Identity/Name") as Label
	TestAssertions.truthy(not frost_name.clip_text and frost_name.autowrap_mode != TextServer.AUTOWRAP_OFF, "Frost Mage title wraps without clipping", failures)
	var start := panel.action_focus(&"start") as Button
	TestAssertions.equal(start.theme_type_variation, &"LivingForgeStartButton", "Start Run uses its explicit accessible focus treatment", failures)
	var focus_style := panel.theme.get_stylebox(&"focus", &"LivingForgeStartButton") as StyleBoxFlat
	TestAssertions.truthy(focus_style != null and focus_style.draw_center and focus_style.border_width_left >= 3, "Start Run focus owns a filled background and strong ring", failures)
	TestAssertions.truthy(panel.theme.has_color(&"font_focus_color", &"LivingForgeStartButton"), "Start Run focus owns an explicit foreground", failures)
	_assert_shared_primary_action(start, panel.theme, &"LivingForgeStartButton", "Start Run", failures)


func _assert_shared_primary_action(button: Button, theme: Theme, variation: StringName, label: String, failures: Array[String]) -> void:
	TestAssertions.truthy(not button.has_theme_stylebox_override(&"focus"), "%s has no local focus StyleBox override" % label, failures)
	TestAssertions.truthy(not button.has_theme_color_override(&"font_focus_color"), "%s has no local focus font override" % label, failures)
	TestAssertions.equal(button.get_theme_stylebox(&"focus", variation), theme.get_stylebox(&"focus", variation), "%s resolves the shared focus StyleBox" % label, failures)
	TestAssertions.equal(button.get_theme_color(&"font_focus_color", variation), theme.get_color(&"font_focus_color", variation), "%s resolves the shared focus foreground" % label, failures)


func _test_scene_and_public_seam(failures: Array[String]) -> void:
	TestAssertions.truthy(ResourceLoader.exists(LOBBY_SCENE_PATH), "full-screen lobby scene exists", failures)
	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate() as CanvasLayer
	var panel := hud.get_node_or_null("ClassSelection") as ClassSelectionPanel
	TestAssertions.truthy(panel != null, "stable HUD/ClassSelection seam remains ClassSelectionPanel", failures)
	if panel == null:
		hud.free()
		return
	TestAssertions.equal(panel.scene_file_path, LOBBY_SCENE_PATH, "stable selector seam instances the lobby scene", failures)
	var panel_script := panel.get_script() as Script
	TestAssertions.equal(panel_script.resource_path if panel_script != null else "", SELECTOR_SCRIPT_PATH, "selector keeps its public adapter script", failures)
	for signal_name: StringName in [&"class_preview_requested", &"class_selection_requested", &"start_requested", &"settings_requested", &"armoury_requested", &"back_requested"]:
		TestAssertions.truthy(panel.has_signal(signal_name), "selector exposes %s" % signal_name, failures)
	for method_name: StringName in [&"configure", &"present", &"open", &"close", &"is_open", &"selected_class_id", &"previewed_class_id", &"active_prompt_mode", &"selection_focus", &"action_focus", &"set_pending", &"begin_compatibility_gate", &"end_compatibility_gate", &"show_status", &"clear_status"]:
		TestAssertions.truthy(panel.has_method(method_name), "selector exposes %s" % method_name, failures)
	for node_name: String in ["Backdrop", "Header", "Seats", "ClassRoster", "HeroStage", "Details", "Footer", "InputPrompt", "ActionBar", "Status"]:
		TestAssertions.truthy(panel.find_child(node_name, true, false) != null, "lobby owns %s composition" % node_name, failures)
	var backdrop := panel.find_child("Backdrop", true, false) as ColorRect
	TestAssertions.truthy(backdrop != null and backdrop.color.a >= 0.999, "lobby backdrop is opaque", failures)
	var source := FileAccess.get_file_as_string(SELECTOR_SCRIPT_PATH)
	TestAssertions.truthy(not source.contains("../Margin") and not source.contains("HUD/Margin"), "selector never reaches sideways into run HUD Margin", failures)
	var run_status := hud.get_node("Margin") as Control
	panel.confirm_run_started()
	TestAssertions.truthy(not panel.visible and run_status.visible, "legacy confirmation still closes setup and reveals run HUD through declarative composition", failures)
	hud.free()


func _test_active_prompt_contract(panel: Variant, failures: Array[String]) -> void:
	var prompts: Array[Node] = panel.find_children("*", "ForgeInputPrompt", true, false)
	TestAssertions.equal(prompts.size(), 1, "Play lobby owns exactly one passive input prompt", failures)
	var prompt := prompts[0] as ForgeInputPrompt if not prompts.is_empty() else null
	if prompt != null:
		TestAssertions.equal(prompt.focus_mode, Control.FOCUS_NONE, "lobby prompt is outside the focus graph", failures)
		TestAssertions.equal(prompt.mouse_filter, Control.MOUSE_FILTER_IGNORE, "lobby prompt ignores pointer input", failures)
	TestAssertions.truthy(panel.get("_input_tracker") is ActiveInputDevice, "Play lobby owns exactly one ActiveInputDevice tracker", failures)
	TestAssertions.equal(panel.active_prompt_mode() if panel.has_method(&"active_prompt_mode") else &"missing", &"keyboard_mouse", "Play lobby reports its read-only initial prompt mode", failures)

	var no_selection := _projection(RunSetupLobbyProjection.State.NO_SELECTION, &"", &"fighter", RunSetupClassProjection.Compatibility.UNKNOWN)
	panel.present(no_selection)
	var no_selection_actions := _enabled_action_ids(panel)
	if prompt != null:
		TestAssertions.truthy((prompt.get_node("Content/Label") as Label).text.ends_with("Select Class"), "no-selection prompt contextualizes ui_accept as Select Class", failures)
	var ready := _projection(RunSetupLobbyProjection.State.READY, &"fighter", &"mage", RunSetupClassProjection.Compatibility.COMPATIBLE)
	ready.set_meta(&"armoury_available", true)
	panel.present(ready)
	var ready_actions := _enabled_action_ids(panel)
	if prompt != null:
		TestAssertions.truthy((prompt.get_node("Content/Label") as Label).text.ends_with("Start Run"), "ready selected lobby contextualizes ui_accept as Start Run", failures)
	var checking := _projection(RunSetupLobbyProjection.State.CHECKING, &"fighter", &"mage", RunSetupClassProjection.Compatibility.COMPATIBLE)
	checking.set_meta(&"armoury_available", true)
	panel.present(checking)
	if prompt != null:
		TestAssertions.truthy((prompt.get_node("Content/Label") as Label).text.ends_with("Confirm"), "non-authoritative lobby state falls back to Confirm", failures)
	TestAssertions.equal(no_selection_actions, [&"back", &"settings", &"select"] as Array[StringName], "prompt rendering preserves no-selection action authority", failures)
	TestAssertions.equal(ready_actions, [&"back", &"settings", &"armoury", &"select", &"start"] as Array[StringName], "prompt rendering preserves ready action authority", failures)

	var seats := panel.find_child("Seats", true, false) as GridContainer
	if seats != null and seats.get_child_count() == 4:
		var active_ready := ((seats.get_child(0) as Control).get_node("Content/Ready") as Label).text
		TestAssertions.truthy(active_ready.contains("PROMPTS:") and active_ready.contains("KEYBOARD"), "P1 alone displays current keyboard/mouse prompt context", failures)
		for index: int in range(1, 4):
			var seat := seats.get_child(index) as Control
			TestAssertions.equal((seat.get_node("Content/FuturePlate/Row/Availability") as Label).text, "LOCAL CO-OP - COMING SOON", "future seat %d remains exact and inert" % (index + 1), failures)


func _test_projection_ownership_theme_and_lifecycle(panel: Variant, failures: Array[String]) -> void:
	var source_definitions: Array[ClassDefinition] = []
	var source_definition: ClassDefinition
	for loaded_definition: ClassDefinition in GameCatalog.load_defaults().classes:
		var owned_fixture := loaded_definition.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as ClassDefinition
		source_definitions.append(owned_fixture)
		if owned_fixture.id == &"fighter":
			source_definition = owned_fixture
	var source_definition_name := source_definition.display_name
	var source_definition_color := source_definition.color
	panel.configure(source_definitions)
	var default_projection := _projection(RunSetupLobbyProjection.State.READY, &"fighter", &"fighter", RunSetupClassProjection.Compatibility.COMPATIBLE)
	panel.present(default_projection)
	TestAssertions.equal(panel.theme, LivingForgeThemeCatalog.resolve(false, 100, 100), "missing accessibility metadata defaults to normal contrast and 100 percent scales", failures)
	TestAssertions.truthy(not bool((panel.find_child("Preview", true, false) as CharacterEquipmentPreview).get("_reduced_motion")), "missing motion metadata defaults to standard motion", failures)
	TestAssertions.truthy((panel.action_focus(&"armoury") as Button).disabled, "missing route metadata defaults Armoury unavailable", failures)
	var projection := _projection(RunSetupLobbyProjection.State.READY, &"fighter", &"fighter", RunSetupClassProjection.Compatibility.COMPATIBLE)
	projection.set_meta(&"high_contrast", true)
	projection.set_meta(&"ui_scale_percent", 110)
	projection.set_meta(&"text_scale_percent", 125)
	projection.set_meta(&"reduced_motion", true)
	projection.set_meta(&"armoury_available", true)
	panel.present(projection)
	var source_seat := (projection.get("_seats") as Array)[0] as RunSetupSeatProjection
	var source_class := (projection.get("_classes") as Array)[0] as RunSetupClassProjection
	var retained_projection := panel.get("_projection") as RunSetupLobbyProjection
	var retained_seat := (retained_projection.get("_seats") as Array)[0] as RunSetupSeatProjection
	var retained_class := (retained_projection.get("_classes") as Array)[0] as RunSetupClassProjection
	var retained_name := (panel.selection_focus(&"fighter").get_node("Content/Identity/Name") as Label).text
	var retained_detail := (panel.find_child("ClassName", true, false) as Label).text
	var source_compatibility_copy := source_class.get("_compatibility_copy") as Dictionary
	source_seat.label = "Mutated source seat"
	source_seat.state = RunSetupSeatProjection.State.DISCONNECTED
	source_class.display_name = "Mutated source class"
	source_class.color = Color.MAGENTA
	(source_class.get("_trait_display_names") as Array).append("Mutated trait")
	source_compatibility_copy[&"nested"] = {&"mutated": true}
	projection.selected_class_id = &"mage"
	projection.previewed_class_id = &"mage"
	projection.status_copy = "Mutated outside the lobby"
	projection.set_meta(&"high_contrast", false)
	source_definition.display_name = "Mutated catalog class"
	source_definition.color = Color.LIME
	source_definition.base_stat_overrides[&"nested"] = {&"mutated": true}
	source_definition.visual_profile.palette_colors[&"review_mutation"] = Color.MAGENTA
	panel.open()
	TestAssertions.equal(panel.selected_class_id(), &"fighter", "present takes a defensive selected-class copy", failures)
	TestAssertions.equal(panel.previewed_class_id(), &"fighter", "present takes a defensive preview copy", failures)
	TestAssertions.truthy(not (panel.find_child("Status", true, false) as Label).text.contains("Mutated outside"), "present takes a defensive status copy", failures)
	TestAssertions.equal((panel.selection_focus(&"fighter").get_node("Content/Identity/Name") as Label).text, retained_name, "nested source class mutation cannot change retained card copy", failures)
	TestAssertions.equal((panel.find_child("ClassName", true, false) as Label).text, retained_detail, "nested source class mutation cannot change retained details copy", failures)
	TestAssertions.equal(((panel.find_child("Seat_1", true, false) as ForgeSeatCard).get_node("Content/Identity") as Label).text, "P1", "nested source seat mutation cannot change retained seat copy", failures)
	TestAssertions.truthy(retained_seat != source_seat and retained_class != source_class, "panel retains no source projection domain references", failures)
	TestAssertions.truthy(not is_same(retained_class.get("_compatibility_copy"), source_compatibility_copy), "panel deep-copies nested projection dictionaries", failures)
	TestAssertions.equal(panel.theme, LivingForgeThemeCatalog.resolve(true, 110, 125), "projection accessibility metadata selects the owned Living Forge theme", failures)
	TestAssertions.truthy(bool((panel.selection_focus(&"fighter") as ForgeClassCard).get("_high_contrast")), "high-contrast presentation reaches reused class-card semantic cues", failures)
	var preview := panel.find_child("Preview", true, false) as CharacterEquipmentPreview
	TestAssertions.truthy(preview != null, "lobby reuses the shared character preview", failures)
	var configured_definition := (panel.get("_definitions_by_id") as Dictionary).get(&"fighter") as ClassDefinition
	TestAssertions.truthy(configured_definition != source_definition, "configure retains no source catalog definition reference", failures)
	TestAssertions.truthy(configured_definition.visual_profile != source_definition.visual_profile, "configure retains no source visual-profile reference", failures)
	TestAssertions.truthy(configured_definition.primary_attack != source_definition.primary_attack, "configure retains no source attack-definition reference", failures)
	TestAssertions.truthy(configured_definition.growth_definition != source_definition.growth_definition, "configure retains no source growth-definition reference", failures)
	TestAssertions.truthy(configured_definition.name_pool != source_definition.name_pool, "configure retains no source name-pool reference", failures)
	TestAssertions.equal(configured_definition.display_name, source_definition_name, "catalog scalar mutation cannot change configured preview definition", failures)
	TestAssertions.equal(configured_definition.color, source_definition_color, "catalog color mutation cannot change configured preview definition", failures)
	TestAssertions.truthy(not configured_definition.base_stat_overrides.has(&"nested"), "catalog nested dictionary mutation cannot change configured preview definition", failures)
	TestAssertions.truthy(not configured_definition.visual_profile.palette_colors.has(&"review_mutation"), "nested external visual-profile mutation cannot change configured preview definition", failures)
	var preview_signature: Variant = preview.get("_active_signature")
	TestAssertions.truthy(preview_signature != null and preview_signature.get("class_definition") == configured_definition, "shared preview is configured from the owned catalog definition", failures)
	panel.open()
	TestAssertions.truthy(panel.is_open(), "open reveals the lobby", failures)
	panel.close()
	TestAssertions.truthy(not panel.is_open(), "close hides the lobby", failures)
	if preview != null:
		var viewport := preview.get_node("SubViewport") as SubViewport
		TestAssertions.equal(viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED, "close disables the shared preview SubViewport", failures)
	panel.open()


func _test_authoritative_preview_cue_survives_representations(panel: Variant, failures: Array[String]) -> void:
	panel.present(_projection(RunSetupLobbyProjection.State.READY, &"fighter", &"fighter", RunSetupClassProjection.Compatibility.COMPATIBLE))
	var fighter := panel.selection_focus(&"fighter") as ForgeClassCard
	var mage := panel.selection_focus(&"mage") as ForgeClassCard
	# A parked pointer and a later focus transition are both legitimate production inputs.
	mage.mouse_entered.emit()
	fighter.focus_entered.emit()
	var high_contrast := _projection(RunSetupLobbyProjection.State.READY, &"fighter", &"fighter", RunSetupClassProjection.Compatibility.COMPATIBLE)
	high_contrast.set_meta(&"high_contrast", true)
	panel.present(high_contrast)
	_assert_preview_authority(panel, "high-contrast re-presentation", failures)
	var safe_error := _projection(RunSetupLobbyProjection.State.ERROR, &"fighter", &"fighter", RunSetupClassProjection.Compatibility.COMPATIBLE)
	panel.present(safe_error)
	_assert_preview_authority(panel, "safe-error re-presentation", failures)
	mage.mouse_exited.emit()


func _assert_preview_authority(panel: Variant, label: String, failures: Array[String]) -> void:
	var preview_id: StringName = panel.previewed_class_id()
	var visible_ids: Array[StringName] = []
	var roster := panel.find_child("Grid", true, false) as GridContainer
	for child: Node in roster.get_children():
		var card := child as ForgeClassCard
		if card != null and (card.get_node("PreviewIndicator") as Control).visible:
			visible_ids.append(card.class_id)
	TestAssertions.equal(visible_ids, [preview_id] as Array[StringName], "%s exposes exactly one Preview cue on the authoritative class" % label, failures)
	var authoritative_card := panel.selection_focus(preview_id) as ForgeClassCard
	var authoritative_name := (authoritative_card.get_node("Content/Identity/Name") as Label).text if authoritative_card != null else ""
	TestAssertions.equal((panel.find_child("ClassName", true, false) as Label).text, authoritative_name, "%s details match preview authority" % label, failures)
	var preview := panel.find_child("Preview", true, false) as CharacterEquipmentPreview
	var signature: Variant = preview.get("_active_signature") if preview != null else null
	var definition: ClassDefinition = signature.get("class_definition") as ClassDefinition if signature != null else null
	TestAssertions.equal(definition.id if definition != null else &"", preview_id, "%s hero matches preview authority" % label, failures)


func _test_preview_selection_and_start_are_orthogonal(panel: Variant, failures: Array[String]) -> void:
	var previews: Array[StringName] = []
	var selections: Array[StringName] = []
	var legacy_selections: Array[StringName] = []
	var starts: Array[StringName] = []
	panel.class_preview_requested.connect(func(class_id: StringName) -> void: previews.append(class_id))
	panel.class_selection_requested.connect(func(class_id: StringName) -> void: selections.append(class_id))
	panel.class_selected.connect(func(class_id: StringName) -> void: legacy_selections.append(class_id))
	panel.start_requested.connect(func(class_id: StringName) -> void: starts.append(class_id))
	panel.present(_projection(RunSetupLobbyProjection.State.NO_SELECTION, &"", &"fighter", RunSetupClassProjection.Compatibility.UNKNOWN))
	var fighter := panel.selection_focus(&"fighter") as ForgeClassCard
	var mage := panel.selection_focus(&"mage") as ForgeClassCard
	fighter.mouse_entered.emit()
	mage.focus_entered.emit()
	TestAssertions.equal(previews, [&"fighter", &"mage"] as Array[StringName], "mouse hover and focus each emit exact preview intent", failures)
	TestAssertions.equal(selections, [] as Array[StringName], "preview never selects a class", failures)
	fighter.request_selection()
	TestAssertions.equal(selections, [&"fighter"] as Array[StringName], "class activation emits exact selection intent", failures)
	TestAssertions.equal(legacy_selections, [&"fighter"] as Array[StringName], "class activation emits exact legacy compatibility identity once", failures)
	TestAssertions.equal(selections.size(), legacy_selections.size(), "new selection authority and legacy alias each emit once without duplication", failures)
	TestAssertions.equal(starts, [] as Array[StringName], "class activation never starts a run", failures)

	panel.present(_projection(RunSetupLobbyProjection.State.READY, &"fighter", &"fighter", RunSetupClassProjection.Compatibility.COMPATIBLE))
	mage = panel.selection_focus(&"mage") as ForgeClassCard
	mage.request_preview()
	TestAssertions.equal(panel.selected_class_id(), &"fighter", "preview B preserves selected class A", failures)
	TestAssertions.equal(panel.previewed_class_id(), &"mage", "preview B updates only preview identity", failures)
	TestAssertions.truthy((fighter.get_node("SelectionNotch") as Control).visible, "selected styling remains on A", failures)
	TestAssertions.truthy(not (mage.get_node("SelectionNotch") as Control).visible, "preview B does not gain selected styling", failures)
	var start := panel.action_focus(&"start") as Button
	TestAssertions.truthy(start != null and not start.disabled, "Ready selected A keeps Start enabled while previewing B", failures)
	start.pressed.emit()
	TestAssertions.equal(starts, [&"fighter"] as Array[StringName], "Start emits exact selected class A, never preview B", failures)
	TestAssertions.equal(selections, [&"fighter"] as Array[StringName], "Start is separate from selection", failures)
	TestAssertions.equal(legacy_selections, [&"fighter"] as Array[StringName], "Start never emits the legacy selection alias", failures)


func _test_complete_action_matrix(panel: Variant, failures: Array[String]) -> void:
	var matrix := [
		[RunSetupLobbyProjection.State.NO_SELECTION, &"", RunSetupClassProjection.Compatibility.UNKNOWN, true, true, true, true, false],
		[RunSetupLobbyProjection.State.CHECKING, &"fighter", RunSetupClassProjection.Compatibility.UNKNOWN, true, false, false, false, false],
		[RunSetupLobbyProjection.State.READY, &"fighter", RunSetupClassProjection.Compatibility.COMPATIBLE, true, true, true, true, true],
		[RunSetupLobbyProjection.State.NEEDS_ATTENTION, &"fighter", RunSetupClassProjection.Compatibility.NEEDS_ATTENTION, true, true, true, true, true],
		[RunSetupLobbyProjection.State.UNAVAILABLE, &"fighter", RunSetupClassProjection.Compatibility.UNAVAILABLE, true, true, true, false, false],
		[RunSetupLobbyProjection.State.STARTING, &"fighter", RunSetupClassProjection.Compatibility.COMPATIBLE, false, false, false, false, false],
		[RunSetupLobbyProjection.State.ERROR, &"fighter", RunSetupClassProjection.Compatibility.UNKNOWN, true, true, true, true, false],
	]
	var preview_ids: Array[StringName] = []
	var selection_ids: Array[StringName] = []
	var legacy_selection_ids: Array[StringName] = []
	var start_ids: Array[StringName] = []
	var back_count: Array[int] = [0]
	var settings_count: Array[int] = [0]
	var armoury_ids: Array[StringName] = []
	panel.class_preview_requested.connect(func(class_id: StringName) -> void: preview_ids.append(class_id))
	panel.class_selection_requested.connect(func(class_id: StringName) -> void: selection_ids.append(class_id))
	panel.class_selected.connect(func(class_id: StringName) -> void: legacy_selection_ids.append(class_id))
	panel.start_requested.connect(func(class_id: StringName) -> void: start_ids.append(class_id))
	panel.back_requested.connect(func() -> void: back_count[0] += 1)
	panel.settings_requested.connect(func() -> void: settings_count[0] += 1)
	panel.armoury_requested.connect(func(class_id: StringName) -> void: armoury_ids.append(class_id))
	for row: Array in matrix:
		var projection := _projection(row[0], row[1], &"fighter", row[2])
		projection.set_meta(&"armoury_available", true)
		panel.present(projection)
		var state_name: String = RunSetupLobbyProjection.State.keys()[row[0]]
		TestAssertions.equal(not (panel.action_focus(&"back") as Button).disabled, row[3], "%s Back matrix state" % state_name, failures)
		TestAssertions.equal(not (panel.action_focus(&"settings") as Button).disabled, row[4], "%s Settings matrix state" % state_name, failures)
		TestAssertions.equal(not (panel.action_focus(&"armoury") as Button).disabled, row[5], "%s Armoury matrix state" % state_name, failures)
		TestAssertions.equal(not (panel.action_focus(&"select") as Button).disabled, row[6], "%s Select matrix state" % state_name, failures)
		TestAssertions.equal(not (panel.action_focus(&"start") as Button).disabled, row[7], "%s Start matrix state" % state_name, failures)
		var previews_before := preview_ids.size()
		var selections_before := selection_ids.size()
		var legacy_before := legacy_selection_ids.size()
		var starts_before := start_ids.size()
		(panel.selection_focus(&"mage") as ForgeClassCard).request_preview()
		var preview_allowed: bool = row[0] != RunSetupLobbyProjection.State.STARTING
		TestAssertions.equal(preview_ids.size() - previews_before, 1 if preview_allowed else 0, "%s class preview emission count" % state_name, failures)
		if preview_allowed:
			TestAssertions.equal(preview_ids.back(), &"mage", "%s class preview emits exact Mage identity" % state_name, failures)
		(panel.selection_focus(&"mage") as ForgeClassCard).request_selection()
		var activation_allowed: bool = row[0] in [RunSetupLobbyProjection.State.NO_SELECTION, RunSetupLobbyProjection.State.READY, RunSetupLobbyProjection.State.NEEDS_ATTENTION, RunSetupLobbyProjection.State.UNAVAILABLE, RunSetupLobbyProjection.State.ERROR]
		TestAssertions.equal(selection_ids.size() - selections_before, 1 if activation_allowed else 0, "%s class activation authority count" % state_name, failures)
		TestAssertions.equal(legacy_selection_ids.size() - legacy_before, 1 if activation_allowed else 0, "%s legacy class activation alias count" % state_name, failures)
		if activation_allowed:
			TestAssertions.equal(selection_ids.back(), &"mage", "%s class activation emits exact Mage identity" % state_name, failures)
			TestAssertions.equal(legacy_selection_ids.back(), &"mage", "%s legacy activation emits exact Mage identity" % state_name, failures)
		var select_selections_before := selection_ids.size()
		var select_legacy_before := legacy_selection_ids.size()
		(panel.action_focus(&"select") as Button).pressed.emit()
		TestAssertions.equal(selection_ids.size() - select_selections_before, 1 if activation_allowed else 0, "%s Select action emission count" % state_name, failures)
		TestAssertions.equal(legacy_selection_ids.size() - select_legacy_before, 1 if activation_allowed else 0, "%s Select legacy alias emission count" % state_name, failures)
		if activation_allowed:
			TestAssertions.equal(selection_ids.back(), &"mage", "%s Select action emits exact preview identity" % state_name, failures)
			TestAssertions.equal(legacy_selection_ids.back(), &"mage", "%s Select legacy alias emits exact preview identity" % state_name, failures)
		var selections_before_start := selection_ids.size()
		var legacy_before_start := legacy_selection_ids.size()
		(panel.action_focus(&"start") as Button).pressed.emit()
		TestAssertions.equal(start_ids.size() - starts_before, 1 if bool(row[7]) else 0, "%s Start emission count" % state_name, failures)
		if bool(row[7]):
			TestAssertions.equal(start_ids.back(), row[1], "%s Start emits exact selected identity" % state_name, failures)
		TestAssertions.equal(selection_ids.size(), selections_before_start, "%s Start never duplicates new selection authority" % state_name, failures)
		TestAssertions.equal(legacy_selection_ids.size(), legacy_before_start, "%s Start never duplicates legacy selection authority" % state_name, failures)
		var backs_before := back_count[0]
		var settings_before := settings_count[0]
		var armoury_before := armoury_ids.size()
		(panel.action_focus(&"back") as Button).pressed.emit()
		(panel.action_focus(&"settings") as Button).pressed.emit()
		(panel.action_focus(&"armoury") as Button).pressed.emit()
		TestAssertions.equal(back_count[0] - backs_before, 1 if bool(row[3]) else 0, "%s Back behavioral authority count" % state_name, failures)
		TestAssertions.equal(settings_count[0] - settings_before, 1 if bool(row[4]) else 0, "%s Settings behavioral authority count" % state_name, failures)
		TestAssertions.equal(armoury_ids.size() - armoury_before, 1 if bool(row[5]) else 0, "%s Armoury behavioral authority count" % state_name, failures)
		if bool(row[5]):
			TestAssertions.equal(armoury_ids.back(), row[1] if not StringName(row[1]).is_empty() else &"mage", "%s Armoury emits the exact selected-or-preview identity" % state_name, failures)

	for state: RunSetupLobbyProjection.State in [RunSetupLobbyProjection.State.NO_SELECTION, RunSetupLobbyProjection.State.CHECKING, RunSetupLobbyProjection.State.UNAVAILABLE, RunSetupLobbyProjection.State.STARTING, RunSetupLobbyProjection.State.ERROR]:
		var selected_id := &"" if state == RunSetupLobbyProjection.State.NO_SELECTION else &"fighter"
		var projection := _projection(state, selected_id, &"fighter", RunSetupClassProjection.Compatibility.UNKNOWN)
		projection.set_meta(&"armoury_available", true)
		panel.present(projection)
		TestAssertions.truthy((panel.action_focus(&"start") as Button).disabled, "%s disables Start" % RunSetupLobbyProjection.State.keys()[state], failures)
	var contradictory := _projection(RunSetupLobbyProjection.State.READY, &"fighter", &"fighter", RunSetupClassProjection.Compatibility.UNKNOWN)
	panel.present(contradictory)
	TestAssertions.truthy((panel.action_focus(&"start") as Button).disabled, "unknown selected compatibility disables Start even in a contradictory Ready projection", failures)

	var unavailable := _projection(RunSetupLobbyProjection.State.UNAVAILABLE, &"fighter", &"fighter", RunSetupClassProjection.Compatibility.UNAVAILABLE)
	unavailable.set_meta(&"armoury_available", true)
	panel.present(unavailable)
	var requested: Array[StringName] = []
	panel.class_selection_requested.connect(func(class_id: StringName) -> void: requested.append(class_id))
	(panel.selection_focus(&"fighter") as ForgeClassCard).request_selection()
	TestAssertions.equal(requested, [] as Array[StringName], "Unavailable selected class cannot be reselected", failures)
	(panel.selection_focus(&"mage") as ForgeClassCard).request_preview()
	TestAssertions.truthy(not (panel.action_focus(&"select") as Button).disabled, "Unavailable allows selecting a different selectable class", failures)
	(panel.action_focus(&"select") as Button).pressed.emit()
	TestAssertions.equal(requested, [&"mage"] as Array[StringName], "Unavailable Select emits only the alternate class", failures)

	var starting_cancel := _projection(RunSetupLobbyProjection.State.STARTING, &"fighter", &"fighter", RunSetupClassProjection.Compatibility.COMPATIBLE)
	starting_cancel.set_meta(&"safe_cancellation_available", true)
	panel.present(starting_cancel)
	TestAssertions.truthy(not (panel.action_focus(&"back") as Button).disabled, "Starting exposes Back only for authoritative safe cancellation", failures)
	TestAssertions.truthy((panel.action_focus(&"settings") as Button).disabled, "safe cancellation never enables unrelated Settings authority", failures)

	var prompt_projection := _projection(RunSetupLobbyProjection.State.READY, &"fighter", &"fighter", RunSetupClassProjection.Compatibility.COMPATIBLE)
	prompt_projection.set_meta(&"armoury_available", true)
	prompt_projection.set_meta(&"prompt_mode", &"controller")
	panel.present(prompt_projection)
	var controller_matrix := _enabled_action_ids(panel)
	prompt_projection.set_meta(&"prompt_mode", &"keyboard_mouse")
	panel.present(prompt_projection)
	TestAssertions.equal(_enabled_action_ids(panel), controller_matrix, "prompt-mode changes never alter action authority", failures)

func _test_focus_graph_and_pending_recovery(panel: Variant, failures: Array[String]) -> void:
	panel.present(_projection(RunSetupLobbyProjection.State.READY, &"fighter", &"mage", RunSetupClassProjection.Compatibility.COMPATIBLE))
	panel.open()
	TestAssertions.equal(panel.get("_pending_initial_focus"), panel.selection_focus(&"fighter"), "retained selected class owns initial focus", failures)
	panel.present(_projection(RunSetupLobbyProjection.State.NO_SELECTION, &"", &"mage", RunSetupClassProjection.Compatibility.UNKNOWN))
	panel.open()
	TestAssertions.equal(panel.get("_pending_initial_focus"), panel.selection_focus(&"fighter"), "no selection initially focuses first projected selectable roster card", failures)

	var ready := _projection(RunSetupLobbyProjection.State.READY, &"fighter", &"fighter", RunSetupClassProjection.Compatibility.COMPATIBLE)
	ready.set_meta(&"armoury_available", true)
	panel.present(ready)
	var ordered: Array[Button] = []
	for class_projection: RunSetupClassProjection in (panel.get("_projection") as RunSetupLobbyProjection).classes:
		ordered.append(panel.selection_focus(class_projection.id) as Button)
	for action_id: StringName in [&"back", &"settings", &"armoury", &"select", &"start"]:
		ordered.append(panel.action_focus(action_id) as Button)
	for index: int in ordered.size():
		var current := ordered[index]
		var next := ordered[(index + 1) % ordered.size()]
		var previous := ordered[posmod(index - 1, ordered.size())]
		TestAssertions.equal(current.focus_next, current.get_path_to(next), "%s has exact forward Tab order" % current.name, failures)
		TestAssertions.equal(current.focus_previous, current.get_path_to(previous), "%s has exact reverse Tab order" % current.name, failures)
	var first := panel.selection_focus(&"fighter") as Button
	var second := panel.selection_focus(&"ranger") as Button
	var fourth := panel.selection_focus(&"cleric") as Button
	var hero_preview := panel.find_child("Preview", true, false) as CharacterEquipmentPreview
	TestAssertions.equal(first.focus_neighbor_right, first.get_path_to(hero_preview), "desktop directional focus transfers the class to its hero preview", failures)
	TestAssertions.equal(first.focus_neighbor_bottom, first.get_path_to(fourth), "desktop directional focus moves down one three-column row", failures)
	var desktop_cards: Array[Button] = ordered.slice(0, (panel.get("_projection") as RunSetupLobbyProjection).classes.size())
	var desktop_actions: Array[Button] = ordered.slice(desktop_cards.size())
	for index: int in desktop_actions.size():
		var expected_card_index := clampi(desktop_cards.size() - desktop_actions.size() + index, 0, desktop_cards.size() - 1)
		TestAssertions.equal(desktop_actions[index].focus_neighbor_top, desktop_actions[index].get_path_to(desktop_cards[expected_card_index]), "%s desktop directional focus returns to its exact grid neighbor" % desktop_actions[index].name, failures)
		TestAssertions.equal(desktop_actions[index].focus_neighbor_bottom, desktop_actions[index].get_path_to(desktop_actions[index]), "%s desktop bottom boundary is deterministic" % desktop_actions[index].name, failures)
	for index: int in desktop_cards.size():
		for property_name: StringName in [&"focus_neighbor_left", &"focus_neighbor_right", &"focus_neighbor_top", &"focus_neighbor_bottom"]:
			TestAssertions.truthy(not NodePath(desktop_cards[index].get(property_name)).is_empty(), "%s desktop %s boundary is explicit" % [desktop_cards[index].name, property_name], failures)
		if index + 3 >= desktop_cards.size():
			var expected_action := desktop_actions[mini(index % 3, desktop_actions.size() - 1)]
			TestAssertions.equal(desktop_cards[index].focus_neighbor_bottom, desktop_cards[index].get_path_to(expected_action), "%s desktop directional focus enters the exact action neighbor" % desktop_cards[index].name, failures)
	TestAssertions.equal(desktop_cards[0].focus_neighbor_left, desktop_cards[0].get_path_to(desktop_cards[0]), "desktop left boundary cannot escape the lobby", failures)
	TestAssertions.equal(desktop_cards[0].focus_neighbor_top, desktop_cards[0].get_path_to(desktop_cards[0]), "desktop top boundary cannot escape the lobby", failures)
	TestAssertions.equal(desktop_actions[0].focus_neighbor_left, desktop_actions[0].get_path_to(desktop_actions[0]), "desktop action left boundary cannot escape the lobby", failures)
	TestAssertions.equal(desktop_actions.back().focus_neighbor_right, desktop_actions.back().get_path_to(desktop_actions.back()), "desktop action right boundary cannot escape the lobby", failures)
	panel.call(&"apply_viewport_size", Vector2(1280.0, 720.0))
	var third := panel.selection_focus(&"mage") as Button
	TestAssertions.equal(first.focus_neighbor_bottom, first.get_path_to(third), "compact directional focus moves down one two-column row", failures)
	var compact_cards: Array[Button] = []
	for class_projection: RunSetupClassProjection in (panel.get("_projection") as RunSetupLobbyProjection).classes:
		compact_cards.append(panel.selection_focus(class_projection.id) as Button)
	var compact_actions: Array[Button] = []
	for action_id: StringName in [&"back", &"settings", &"armoury", &"select", &"start"]:
		compact_actions.append(panel.action_focus(action_id) as Button)
	for index: int in compact_actions.size():
		var expected_card_index := clampi(compact_cards.size() - compact_actions.size() + index, 0, compact_cards.size() - 1)
		TestAssertions.equal(compact_actions[index].focus_neighbor_top, compact_actions[index].get_path_to(compact_cards[expected_card_index]), "%s directional focus returns to its exact grid neighbor" % compact_actions[index].name, failures)
		TestAssertions.equal(compact_actions[index].focus_neighbor_bottom, compact_actions[index].get_path_to(compact_actions[index]), "%s compact bottom boundary is deterministic" % compact_actions[index].name, failures)
	for index: int in compact_cards.size():
		for property_name: StringName in [&"focus_neighbor_left", &"focus_neighbor_right", &"focus_neighbor_top", &"focus_neighbor_bottom"]:
			TestAssertions.truthy(not NodePath(compact_cards[index].get(property_name)).is_empty(), "%s compact %s boundary is explicit" % [compact_cards[index].name, property_name], failures)
		if index + 2 >= compact_cards.size():
			var expected_action := compact_actions[mini(index % 2, compact_actions.size() - 1)]
			TestAssertions.equal(compact_cards[index].focus_neighbor_bottom, compact_cards[index].get_path_to(expected_action), "%s directional focus enters the exact action neighbor" % compact_cards[index].name, failures)
	TestAssertions.equal(compact_cards[0].focus_neighbor_left, compact_cards[0].get_path_to(compact_cards[0]), "compact left boundary cannot escape the lobby", failures)
	TestAssertions.equal(compact_cards[0].focus_neighbor_top, compact_cards[0].get_path_to(compact_cards[0]), "compact top boundary cannot escape the lobby", failures)
	TestAssertions.equal(compact_actions[0].focus_neighbor_left, compact_actions[0].get_path_to(compact_actions[0]), "compact action left boundary cannot escape the lobby", failures)
	TestAssertions.equal(compact_actions.back().focus_neighbor_right, compact_actions.back().get_path_to(compact_actions.back()), "compact action right boundary cannot escape the lobby", failures)

	var seats := panel.find_child("Seats", true, false) as GridContainer
	for seat: Control in seats.get_children():
		TestAssertions.equal(seat.focus_mode, Control.FOCUS_NONE, "%s is unreachable" % seat.name, failures)
		TestAssertions.equal(seat.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s ignores pointer input" % seat.name, failures)

	var starts: Array[StringName] = []
	panel.start_requested.connect(func(class_id: StringName) -> void: starts.append(class_id))
	var start := panel.action_focus(&"start") as Button
	panel.set_pending(RunSetupLobbyProjection.State.STARTING, start)
	start.pressed.emit()
	start.pressed.emit()
	TestAssertions.equal(starts, [] as Array[StringName], "Starting rejects duplicate activation", failures)
	TestAssertions.equal(panel.get("_pending_initial_focus"), start, "Starting retains the initiating Start focus", failures)
	panel.present(_projection(RunSetupLobbyProjection.State.ERROR, &"fighter", &"fighter", RunSetupClassProjection.Compatibility.UNKNOWN))
	TestAssertions.equal(panel.get("_pending_initial_focus"), start, "failure restores initiating Start focus", failures)
	TestAssertions.truthy(not (panel.action_focus(&"back") as Button).disabled, "failure restores a stable navigable state", failures)

	var mage := panel.selection_focus(&"mage") as Control
	TestAssertions.equal(panel.begin_compatibility_gate(&"mage", mage), mage, "compatibility gate retains explicit class origin", failures)
	TestAssertions.truthy(panel.compatibility_gate_active(), "compatibility gate enters Checking", failures)
	panel.end_compatibility_gate(true)
	TestAssertions.truthy(not panel.compatibility_gate_active(), "compatibility gate terminates", failures)
	TestAssertions.equal(panel.get("_pending_initial_focus"), mage, "compatibility failure/exit restores class origin", failures)
	panel.begin_compatibility_gate(&"mage", mage)
	panel.end_compatibility_gate(false)
	TestAssertions.truthy(not panel.compatibility_gate_active(), "non-restoring compatibility gate also terminates", failures)
	TestAssertions.equal(panel.get("_pending_initial_focus"), null, "non-restoring compatibility gate clears pending focus without restoration", failures)


func _projection(
	state: RunSetupLobbyProjection.State,
	selected_id: StringName,
	previewed_id: StringName,
	selected_compatibility: RunSetupClassProjection.Compatibility,
) -> RunSetupLobbyProjection:
	var catalog := GameCatalog.load_defaults()
	var classes: Array[RunSetupClassProjection] = []
	for definition: ClassDefinition in catalog.classes:
		classes.append(RunSetupClassProjection.create(
			definition.id,
			definition.display_name,
			_role_label(definition.role),
			definition.color,
			[],
			String(definition.primary_attack.id).capitalize(),
			selected_compatibility if definition.id == selected_id else RunSetupClassProjection.Compatibility.UNKNOWN,
			{},
		))
	return RunSetupLobbyProjection.create(
		[RunSetupSeatProjection.active(1, "P1"), RunSetupSeatProjection.coming_soon(2), RunSetupSeatProjection.coming_soon(3), RunSetupSeatProjection.coming_soon(4)],
		classes,
		selected_id,
		previewed_id,
		state,
		"Lobby state: %s" % RunSetupLobbyProjection.State.keys()[state],
	)


func _role_label(role: ClassDefinition.Role) -> String:
	return ClassDefinition.Role.keys()[role].capitalize()


func _enabled_action_ids(panel: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	for action_id: StringName in [&"back", &"settings", &"armoury", &"select", &"start"]:
		if not (panel.action_focus(action_id) as Button).disabled:
			result.append(action_id)
	return result
