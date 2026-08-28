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
	_test_preview_selection_and_start_are_orthogonal(panel, failures)
	_test_complete_action_matrix(panel, failures)
	_test_focus_graph_and_pending_recovery(panel, failures)
	panel.free()
	return failures


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
	for method_name: StringName in [&"configure", &"present", &"open", &"close", &"is_open", &"selected_class_id", &"previewed_class_id", &"selection_focus", &"action_focus", &"set_pending", &"begin_compatibility_gate", &"end_compatibility_gate", &"show_status", &"clear_status"]:
		TestAssertions.truthy(panel.has_method(method_name), "selector exposes %s" % method_name, failures)
	for node_name: String in ["Backdrop", "Header", "Seats", "ClassRoster", "HeroStage", "Details", "ActionBar", "Status"]:
		TestAssertions.truthy(panel.find_child(node_name, true, false) != null, "lobby owns %s composition" % node_name, failures)
	var backdrop := panel.find_child("Backdrop", true, false) as ColorRect
	TestAssertions.truthy(backdrop != null and backdrop.color.a >= 0.999, "lobby backdrop is opaque", failures)
	var source := FileAccess.get_file_as_string(SELECTOR_SCRIPT_PATH)
	TestAssertions.truthy(not source.contains("../Margin") and not source.contains("HUD/Margin"), "selector never reaches sideways into run HUD Margin", failures)
	var run_status := hud.get_node("Margin") as Control
	panel.confirm_run_started()
	TestAssertions.truthy(not panel.visible and run_status.visible, "legacy confirmation still closes setup and reveals run HUD through declarative composition", failures)
	hud.free()


func _test_projection_ownership_theme_and_lifecycle(panel: Variant, failures: Array[String]) -> void:
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
	projection.selected_class_id = &"mage"
	projection.previewed_class_id = &"mage"
	projection.status_copy = "Mutated outside the lobby"
	TestAssertions.equal(panel.selected_class_id(), &"fighter", "present takes a defensive selected-class copy", failures)
	TestAssertions.equal(panel.previewed_class_id(), &"fighter", "present takes a defensive preview copy", failures)
	TestAssertions.truthy(not (panel.find_child("Status", true, false) as Label).text.contains("Mutated outside"), "present takes a defensive status copy", failures)
	TestAssertions.equal(panel.theme, LivingForgeThemeCatalog.resolve(true, 110, 125), "projection accessibility metadata selects the owned Living Forge theme", failures)
	TestAssertions.truthy(bool((panel.selection_focus(&"fighter") as ForgeClassCard).get("_high_contrast")), "high-contrast presentation reaches reused class-card semantic cues", failures)
	var preview := panel.find_child("Preview", true, false) as CharacterEquipmentPreview
	TestAssertions.truthy(preview != null, "lobby reuses the shared character preview", failures)
	panel.open()
	TestAssertions.truthy(panel.is_open(), "open reveals the lobby", failures)
	panel.close()
	TestAssertions.truthy(not panel.is_open(), "close hides the lobby", failures)
	if preview != null:
		var viewport := preview.get_node("SubViewport") as SubViewport
		TestAssertions.equal(viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED, "close disables the shared preview SubViewport", failures)
	panel.open()


func _test_preview_selection_and_start_are_orthogonal(panel: Variant, failures: Array[String]) -> void:
	var previews: Array[StringName] = []
	var selections: Array[StringName] = []
	var starts: Array[StringName] = []
	panel.class_preview_requested.connect(func(class_id: StringName) -> void: previews.append(class_id))
	panel.class_selection_requested.connect(func(class_id: StringName) -> void: selections.append(class_id))
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

	var back_count: Array[int] = [0]
	var settings_count: Array[int] = [0]
	var armoury_ids: Array[StringName] = []
	panel.back_requested.connect(func() -> void: back_count[0] += 1)
	panel.settings_requested.connect(func() -> void: settings_count[0] += 1)
	panel.armoury_requested.connect(func(class_id: StringName) -> void: armoury_ids.append(class_id))
	(panel.action_focus(&"back") as Button).pressed.emit()
	(panel.action_focus(&"settings") as Button).pressed.emit()
	(panel.action_focus(&"armoury") as Button).pressed.emit()
	TestAssertions.equal(back_count[0], 1, "Back action emits once", failures)
	TestAssertions.equal(settings_count[0], 1, "Settings action emits once", failures)
	TestAssertions.equal(armoury_ids, [&"fighter"] as Array[StringName], "Armoury action emits the exact selected class", failures)


func _test_focus_graph_and_pending_recovery(panel: Variant, failures: Array[String]) -> void:
	panel.present(_projection(RunSetupLobbyProjection.State.READY, &"fighter", &"mage", RunSetupClassProjection.Compatibility.COMPATIBLE))
	panel.open()
	TestAssertions.equal(panel.get("_pending_initial_focus"), panel.selection_focus(&"fighter"), "retained selected class owns initial focus", failures)
	panel.present(_projection(RunSetupLobbyProjection.State.NO_SELECTION, &"", &"mage", RunSetupClassProjection.Compatibility.UNKNOWN))
	panel.open()
	TestAssertions.equal(panel.get("_pending_initial_focus"), panel.selection_focus(&"mage"), "no selection initially focuses first selectable preview card", failures)

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
	TestAssertions.equal(first.focus_neighbor_right, first.get_path_to(second), "desktop directional focus moves right one class", failures)
	TestAssertions.equal(first.focus_neighbor_bottom, first.get_path_to(fourth), "desktop directional focus moves down one three-column row", failures)
	panel.call(&"apply_viewport_size", Vector2(1280.0, 720.0))
	var third := panel.selection_focus(&"mage") as Button
	TestAssertions.equal(first.focus_neighbor_bottom, first.get_path_to(third), "compact directional focus moves down one two-column row", failures)

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
