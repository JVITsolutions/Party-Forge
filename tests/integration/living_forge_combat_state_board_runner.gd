extends SceneTree

const BOARD_SCENE := "res://scenes/dev/living_forge_combat_state_board.tscn"
const SCREENSHOT_ROOT := "res://docs/validation/screenshots/living-forge-combat-components"
const MANIFEST_NAME := "manifest.json"
const MANIFEST_SCHEMA_VERSION := 2
const WINDOW_SIZE := Vector2i(1920, 1080)
const EXPECTED_CAPTURE_FILES: Array[String] = [
	"living-forge-combat-rich-states-normal.png",
	"living-forge-combat-compact-alerts-normal.png",
	"living-forge-combat-focus-hover-normal.png",
	"living-forge-combat-all-states-high-contrast.png",
]

var _failures: Array[String] = []
var _captured: Dictionary = {}
var _entries: Array[Dictionary] = []
var _started_unix := 0


func _initialize() -> void:
	_started_unix = int(Time.get_unix_time_from_system())
	call_deferred(&"_run")


func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = WINDOW_SIZE
	if not ResourceLoader.exists(BOARD_SCENE):
		_assert(false, "combat-only state-board scene exists")
		_finish()
		return
	var packed := load(BOARD_SCENE) as PackedScene
	var board := packed.instantiate() as Control if packed != null else null
	_assert(board != null, "combat-only state board instantiates")
	if board == null:
		_finish()
		return
	root.add_child(board)
	await _frames(5)
	_assert(board.has_method(&"apply_theme_variant"), "board exposes normal/high-contrast variants")
	_assert(board.has_method(&"set_evidence_mode"), "board exposes bounded evidence modes")
	_assert(board.has_method(&"member_control"), "board exposes rich and compact member states")
	_assert(board.has_method(&"alert_control"), "board exposes all current alert severities")
	_assert(board.has_method(&"component_tree_signature"), "board exposes contrast parity signature")
	if not _failures.is_empty():
		board.free()
		_finish()
		return

	board.call(&"apply_theme_variant", false)
	board.call(&"set_evidence_mode", &"rich")
	await _frames(4)
	_assert_header(board)
	_assert_member_inventory(board, &"rich")
	await _capture(EXPECTED_CAPTURE_FILES[0], "normal rich cards: ready, critical, downed, dead")

	board.call(&"set_evidence_mode", &"compact_alerts")
	await _frames(4)
	_assert_header(board)
	_assert_member_inventory(board, &"compact")
	_assert_alert_inventory(board)
	await _capture(EXPECTED_CAPTURE_FILES[1], "normal compact markers and critical, downed, dead alerts")

	board.call(&"set_evidence_mode", &"interaction")
	_assert_header(board)
	var focused := board.call(&"member_control", &"rich", &"critical") as Button
	var hovered := board.call(&"member_control", &"compact", &"downed") as Button
	_assert(focused != null and hovered != null, "interaction evidence resolves exact member controls")
	if focused != null and hovered != null:
		focused.grab_focus()
		hovered.call(&"_on_mouse_entered")
		await _frames(3)
		_assert(root.gui_get_focus_owner() == focused and focused.has_focus(), "keyboard/controller focus is real and retained")
		_assert((focused.get_node("FocusFrame") as Control).is_visible_in_tree(), "focused rich card renders an explicit outline")
		_assert((hovered.get_node("HoverPlate") as Control).is_visible_in_tree(), "hovered compact marker renders an explicit hover plate")
		var focus_style := (focused.get_node("FocusFrame") as Panel).get_theme_stylebox(&"panel") as StyleBoxFlat
		_assert(focus_style != null and focus_style.border_width_left == 4 and focus_style.border_color == LivingForgeTokens.color(&"focus_outline", false), "live focus uses a 4px cool-steel semantic outline")
		var activation_count := int(board.call(&"activation_count"))
		focused.call(&"present", (board.call(&"member_projection", &"critical") as PartyMemberHudProjection).copy())
		hovered.call(&"present", (board.call(&"member_projection", &"downed") as PartyMemberHudProjection).copy())
		_assert(focused.has_focus() and (hovered.get_node("HoverPlate") as Control).visible, "re-presentation preserves focus and hover")
		_assert(int(board.call(&"activation_count")) == activation_count, "re-presentation emits no activation")
		await _key_accept()
		_assert(int(board.call(&"activation_count")) == activation_count + 1, "keyboard activation is consumed exactly once")
		hovered.grab_focus()
		await _controller_accept()
		_assert(int(board.call(&"activation_count")) == activation_count + 2, "simulated-controller activation is consumed exactly once")
		var mouse_target := board.call(&"alert_control", &"critical") as Button
		if mouse_target != null:
			await _mouse_click(mouse_target.get_global_rect().get_center())
			_assert(int(board.call(&"activation_count")) == activation_count + 3, "mouse activation is consumed exactly once")
		await _mouse_motion(hovered.get_global_rect().get_center())
		focused.grab_focus()
		await _frames(2)
		_assert(root.gui_get_focus_owner() == focused and focused.has_focus(), "interaction capture restores real focus to the rich critical card")
		_assert((hovered.get_node("HoverPlate") as Control).visible and not hovered.has_focus(), "interaction capture keeps real hover distinct on the compact downed marker")
	await _capture(EXPECTED_CAPTURE_FILES[2], "normal keyboard focus and mouse hover proof")

	var normal_signature: Array = board.call(&"component_tree_signature")
	var focus_owner := root.gui_get_focus_owner()
	if focus_owner != null:
		focus_owner.release_focus()
	await _mouse_motion(Vector2(WINDOW_SIZE.x - 4, WINDOW_SIZE.y - 4))
	await _frames(2)
	board.call(&"apply_theme_variant", true)
	board.call(&"set_evidence_mode", &"all")
	await _frames(4)
	_assert_header(board)
	_assert_member_inventory(board, &"rich")
	_assert_member_inventory(board, &"compact")
	_assert_alert_inventory(board)
	_assert_all_visible_controls_above_fold(board)
	var contrast_signature: Array = board.call(&"component_tree_signature")
	_assert(contrast_signature == normal_signature, "normal and high-contrast variants keep semantic component parity")
	await _capture(EXPECTED_CAPTURE_FILES[3], "high contrast rich, compact, and alert parity")

	await _write_and_validate_manifest()
	board.free()
	_finish()


func _assert_member_inventory(board: Control, kind: StringName) -> void:
	for state: StringName in [&"normal", &"critical", &"downed", &"dead"]:
		var control := board.call(&"member_control", kind, state) as Control
		_assert(control != null and control.is_visible_in_tree(), "%s %s member state is visible" % [kind, state])
		if control == null:
			continue
		var text := control.get_node("Surface/Content/StateCue/StateText") as Label
		var icon := control.get_node("Surface/Content/StateCue/StateIcon") as TextureRect
		var shape := control.get_node("Surface/Content/StateCue/StateShape/Geometry") as Polygon2D
		_assert(not text.text.strip_edges().is_empty(), "%s %s state has visible text" % [kind, state])
		_assert(icon.visible and icon.texture != null, "%s %s state has a visible icon" % [kind, state])
		_assert(shape.visible and shape.polygon.size() >= 3, "%s %s state has non-color shape geometry" % [kind, state])
		_assert(not control.accessibility_name.strip_edges().is_empty(), "%s %s state has an accessibility name" % [kind, state])
		_assert(control.get_global_rect().size.x >= 48.0 and control.get_global_rect().size.y >= 48.0, "%s %s uses a true rendered action rectangle of at least 48px" % [kind, state])
		for signal_name: StringName in [&"activated", &"inspect_requested", &"ledger_requested"]:
			_assert(not control.get_signal_connection_list(signal_name).is_empty(), "%s %s %s intent has a consumer" % [kind, state, signal_name])


func _assert_header(board: Control) -> void:
	var title := board.get_node("Margin/Layout/Header/Title") as Label
	var mode := board.get_node("Margin/Layout/Header/Mode") as Label
	var variant := board.get_node("Margin/Layout/Header/Variant") as Label
	_assert(title.is_visible_in_tree() and title.get_global_rect().size.x >= 720.0 and title.get_global_rect().size.y >= 32.0, "state-board header title remains visibly rendered")
	_assert(not title.get_global_rect().intersects(mode.get_global_rect()) and not mode.get_global_rect().intersects(variant.get_global_rect()), "state-board header labels do not overlap")


func _assert_alert_inventory(board: Control) -> void:
	for state: StringName in [&"critical", &"downed", &"dead"]:
		var alert := board.call(&"alert_control", state) as Control
		_assert(alert != null and alert.is_visible_in_tree(), "%s alert is visible" % state)
		if alert == null:
			continue
		_assert(not (alert.get_node("Surface/StateText") as Label).text.strip_edges().is_empty(), "%s alert has visible severity text" % state)
		_assert((alert.get_node("Surface/StateIcon") as TextureRect).texture != null, "%s alert has a visible severity icon" % state)
		_assert((alert.get_node("Surface/StateShape/Geometry") as Polygon2D).polygon.size() >= 3, "%s alert has non-color shape geometry" % state)
		_assert(alert.get_global_rect().size.x >= 48.0 and alert.get_global_rect().size.y >= 48.0, "%s alert uses a true rendered action rectangle of at least 48px" % state)
		for signal_name: StringName in [&"activated", &"inspect_requested", &"ledger_requested"]:
			_assert(not alert.get_signal_connection_list(signal_name).is_empty(), "%s alert %s intent has a consumer" % [state, signal_name])


func _assert_all_visible_controls_above_fold(board: Control) -> void:
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(WINDOW_SIZE))
	var controls: Array[Control] = []
	for kind: StringName in [&"rich", &"compact"]:
		for state: StringName in [&"normal", &"critical", &"downed", &"dead"]:
			var member := board.call(&"member_control", kind, state) as Control
			if member != null and member.is_visible_in_tree():
				controls.append(member)
	for state: StringName in [&"critical", &"downed", &"dead"]:
		var alert := board.call(&"alert_control", state) as Control
		if alert != null and alert.is_visible_in_tree():
			controls.append(alert)
	for control: Control in controls:
		_assert(viewport_rect.encloses(control.get_global_rect()), "%s is fully contained above the 1920x1080 fold" % control.get_path())
	for left_index: int in controls.size():
		for right_index: int in range(left_index + 1, controls.size()):
			_assert(not controls[left_index].get_global_rect().intersects(controls[right_index].get_global_rect()), "%s does not overlap %s" % [controls[left_index].get_path(), controls[right_index].get_path()])


func _key_accept() -> void:
	var press := InputEventKey.new()
	press.keycode = KEY_ENTER
	press.physical_keycode = KEY_ENTER
	press.pressed = true
	root.push_input(press, true)
	await process_frame
	var release := press.duplicate() as InputEventKey
	release.pressed = false
	root.push_input(release, true)
	await process_frame


func _controller_accept() -> void:
	var press := InputEventJoypadButton.new()
	press.device = 2
	press.button_index = JOY_BUTTON_A
	press.pressed = true
	root.push_input(press, true)
	await process_frame
	var release := press.duplicate() as InputEventJoypadButton
	release.pressed = false
	root.push_input(release, true)
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


func _mouse_motion(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	motion.relative = position - root.get_mouse_position()
	root.push_input(motion, true)
	await process_frame


func _capture(file_name: String, state: String) -> void:
	await _frames(4)
	var absolute_root := ProjectSettings.globalize_path(SCREENSHOT_ROOT)
	_assert(DirAccess.make_dir_recursive_absolute(absolute_root) == OK, "combat evidence directory is available")
	var image := root.get_texture().get_image()
	_assert(image != null and not image.is_empty(), "%s returns rendered pixels" % file_name)
	if image == null or image.is_empty():
		return
	_assert(image.get_size() == WINDOW_SIZE, "%s is rendered at 1920x1080" % file_name)
	_assert(_image_is_nonblank(image), "%s is a nonblank rendered frame" % file_name)
	var absolute_path := absolute_root.path_join(file_name)
	_assert(image.save_png(absolute_path) == OK, "%s saves" % file_name)
	if not FileAccess.file_exists(absolute_path):
		return
	var hash := _sha256(FileAccess.get_file_as_bytes(absolute_path))
	_assert(hash.length() == 64, "%s has a SHA-256" % file_name)
	_captured[file_name] = hash
	_entries.append({"file": file_name, "sha256": hash, "width": image.get_width(), "height": image.get_height(), "state": state})


func _write_and_validate_manifest() -> void:
	var expected_sorted := EXPECTED_CAPTURE_FILES.duplicate()
	expected_sorted.sort()
	var actual_sorted: Array[String] = []
	for file_name: Variant in _captured.keys():
		actual_sorted.append(String(file_name))
	actual_sorted.sort()
	_assert(actual_sorted == expected_sorted, "current run captures all four exact PNG names")
	var unique_hashes: Dictionary = {}
	for hash: Variant in _captured.values():
		unique_hashes[String(hash)] = true
	_assert(unique_hashes.size() == EXPECTED_CAPTURE_FILES.size(), "all four combat captures have unique hashes")
	var manifest := {
		"schema_version": MANIFEST_SCHEMA_VERSION,
		"run_id": "%d-%d" % [OS.get_process_id(), _started_unix],
		"captured_at_utc": Time.get_datetime_string_from_system(true, true),
		"source_head": _source_head(),
		"source_tree_fingerprint": _source_tree_fingerprint(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"window_mode": "windowed",
		"entries": _entries,
	}
	var manifest_path := ProjectSettings.globalize_path(SCREENSHOT_ROOT.path_join(MANIFEST_NAME))
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	_assert(file != null, "schema-2 manifest opens for writing")
	if file != null:
		file.store_string(JSON.stringify(manifest, "  ") + "\n")
		file.close()
	_assert_no_extra_pngs()
	var parsed_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var parsed := parsed_value as Dictionary if parsed_value is Dictionary else {}
	_assert(int(parsed.get("schema_version", 0)) == MANIFEST_SCHEMA_VERSION, "manifest parses as schema 2")
	var fingerprint := parsed.get("source_tree_fingerprint", {}) as Dictionary
	var current_fingerprint := _source_tree_fingerprint()
	_assert(
		String(fingerprint.get("sha256", "")) == String(current_fingerprint.get("sha256", ""))
		and int(fingerprint.get("path_count", -1)) == int(current_fingerprint.get("path_count", -2))
		and JSON.stringify(fingerprint.get("inputs", [])) == JSON.stringify(current_fingerprint.get("inputs", [])),
		"manifest fingerprint matches current Task 3 source inputs",
	)
	var manifest_files: Array[String] = []
	for entry: Dictionary in parsed.get("entries", [] as Array):
		var name := String(entry.get("file", ""))
		manifest_files.append(name)
		var path := ProjectSettings.globalize_path(SCREENSHOT_ROOT.path_join(name))
		_assert(FileAccess.file_exists(path), "manifest file exists: %s" % name)
		if FileAccess.file_exists(path):
			_assert(_sha256(FileAccess.get_file_as_bytes(path)) == String(entry.get("sha256", "")), "manifest hash matches current bytes: %s" % name)
			_assert(int(FileAccess.get_modified_time(path)) >= _started_unix, "manifest rejects stale evidence: %s" % name)
	manifest_files.sort()
	_assert(manifest_files == expected_sorted, "manifest contains exactly the four required entries")


func _assert_no_extra_pngs() -> void:
	var directory := DirAccess.open(SCREENSHOT_ROOT)
	_assert(directory != null, "combat evidence directory opens")
	if directory == null:
		return
	var actual: Array[String] = []
	for file_name: String in directory.get_files():
		if file_name.get_extension().to_lower() == "png":
			actual.append(file_name)
	actual.sort()
	var expected := EXPECTED_CAPTURE_FILES.duplicate()
	expected.sort()
	_assert(actual == expected, "combat evidence directory contains no missing or extra PNGs")


func _source_head() -> String:
	var output: Array = []
	var exit_code := OS.execute("git", PackedStringArray(["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "HEAD"]), output, true)
	_assert(exit_code == 0 and not output.is_empty(), "source HEAD resolves for manifest")
	return String(output[0]).strip_edges() if exit_code == 0 and not output.is_empty() else "unresolved"


func _source_tree_fingerprint() -> Dictionary:
	var output: Array = []
	var repository_root := ProjectSettings.globalize_path("res://")
	var exit_code := OS.execute("git", PackedStringArray(["-C", repository_root, "status", "--porcelain=v1", "--untracked-files=all"]), output, true)
	_assert(exit_code == 0, "source-tree status resolves for manifest fingerprint")
	var records: Array[Dictionary] = []
	for raw_line: String in String("".join(output)).split("\n", false):
		if raw_line.length() < 4:
			continue
		var status_code := raw_line.substr(0, 2)
		var relative_path := raw_line.substr(3).strip_edges().replace("\\", "/")
		if " -> " in relative_path:
			relative_path = relative_path.get_slice(" -> ", 1)
		if relative_path.begins_with("docs/validation/screenshots/living-forge-combat-components/") or relative_path == ".superpowers/sdd/task-3-report.md":
			continue
		var absolute_path := repository_root.path_join(relative_path)
		if FileAccess.file_exists(absolute_path):
			records.append({"status": status_code, "path": relative_path, "sha256": _sha256(FileAccess.get_file_as_bytes(absolute_path))})
	records.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left.path) < String(right.path))
	var context := HashingContext.new()
	_assert(context.start(HashingContext.HASH_SHA256) == OK, "source-tree fingerprint SHA-256 initializes")
	for record: Dictionary in records:
		var status := String(record.status)
		var path := String(record.path)
		var file_hash := String(record.sha256)
		var canonical := "%d:%s%d:%s%d:%s\n" % [status.length(), status, path.length(), path, file_hash.length(), file_hash]
		_assert(context.update(canonical.to_utf8_buffer()) == OK, "source-tree fingerprint hashes %s" % path)
	var fingerprint := context.finish().hex_encode()
	_assert(not records.is_empty() and fingerprint.length() == 64, "source-tree fingerprint covers nonempty Task 3 inputs")
	return {
		"algorithm": "sha256",
		"method": "Sort git status --porcelain tracked/untracked Task 3 inputs; exclude generated combat evidence and Task 3 report; hash length-prefixed status/path/file-SHA records.",
		"path_count": records.size(),
		"sha256": fingerprint,
		"inputs": records,
	}


func _image_is_nonblank(image: Image) -> bool:
	var first := image.get_pixel(0, 0)
	for y: int in range(0, image.get_height(), maxi(1, image.get_height() / 24)):
		for x: int in range(0, image.get_width(), maxi(1, image.get_width() / 24)):
			var sample := image.get_pixel(x, y)
			if absf(sample.r - first.r) + absf(sample.g - first.g) + absf(sample.b - first.b) + absf(sample.a - first.a) > 0.025:
				return true
	return false


func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(bytes) != OK:
		return ""
	return context.finish().hex_encode()


func _frames(count: int) -> void:
	for _index: int in count:
		await process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("LIVING_FORGE_COMBAT_STATE_BOARD_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error("LIVING_FORGE_COMBAT_STATE_BOARD_FAILURE: %s" % failure)
	print("LIVING_FORGE_COMBAT_STATE_BOARD_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)
