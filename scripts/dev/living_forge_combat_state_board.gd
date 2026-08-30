class_name LivingForgeCombatStateBoard
extends Control

const CARD_SCENE := preload("res://scenes/ui/living_forge/components/forge_party_member_card.tscn")
const MARKER_SCENE := preload("res://scenes/ui/living_forge/components/forge_party_member_marker.tscn")
const ALERT_SCENE := preload("res://scenes/ui/living_forge/components/forge_alert_card.tscn")

var _member_projections: Dictionary = {}
var _member_controls: Dictionary = {}
var _alert_controls: Dictionary = {}
var _activation_count := 0
var _inspect_count := 0
var _ledger_count := 0
var _high_contrast := false
var _built := false


func _ready() -> void:
	_ensure_built()


func apply_theme_variant(high_contrast: bool) -> void:
	_ensure_built()
	_high_contrast = high_contrast
	theme = LivingForgeThemeCatalog.resolve(high_contrast, 100, 100)
	(get_node("Background") as ColorRect).color = LivingForgeTokens.color(&"surface_inset", high_contrast)
	(get_node("Margin/Layout/Header/Variant") as Label).text = "HIGH CONTRAST" if high_contrast else "NORMAL CONTRAST"
	for control: Control in _member_controls.values():
		control.call(&"apply_accessibility_variant", high_contrast)
	for control: Control in _alert_controls.values():
		control.call(&"apply_accessibility_variant", high_contrast)


func set_evidence_mode(mode: StringName) -> void:
	_ensure_built()
	var rich := get_node("Margin/Layout/RichSection") as Control
	var compact_alerts := get_node("Margin/Layout/CompactAlertSection") as Control
	match mode:
		&"rich":
			rich.visible = true
			compact_alerts.visible = false
		&"compact_alerts":
			rich.visible = false
			compact_alerts.visible = true
		_:
			rich.visible = true
			compact_alerts.visible = true
	(get_node("Margin/Layout/Header/Mode") as Label).text = "PROOF: %s" % String(mode).replace("_", " ").to_upper()


func member_control(kind: StringName, state: StringName) -> Control:
	_ensure_built()
	return _member_controls.get(_member_key(kind, state)) as Control


func alert_control(state: StringName) -> Control:
	_ensure_built()
	return _alert_controls.get(state) as Control


func member_projection(state: StringName) -> PartyMemberHudProjection:
	_ensure_built()
	var projection := _member_projections.get(state) as PartyMemberHudProjection
	return projection.copy() if projection != null else null


func activation_count() -> int:
	return _activation_count


func inspect_count() -> int:
	return _inspect_count


func ledger_count() -> int:
	return _ledger_count


func component_tree_signature() -> Array[String]:
	_ensure_built()
	var signature: Array[String] = []
	_append_signature(self, signature)
	signature.sort()
	return signature


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	_create_projections()
	_build_members(&"rich", get_node("Margin/Layout/RichSection/RichRow") as HBoxContainer, CARD_SCENE)
	_build_members(&"compact", get_node("Margin/Layout/CompactAlertSection/CompactRow") as HBoxContainer, MARKER_SCENE)
	_build_alerts()
	apply_theme_variant(false)
	set_evidence_mode(&"all")


func _create_projections() -> void:
	_member_projections = {
		&"normal": PartyMemberHudProjection.create(1, "Aria", &"fighter", "Fighter", 7, 3, 90.0, 100.0, true, false, false),
		&"critical": PartyMemberHudProjection.create(2, "Brom", &"mage", "Mage", 4, 2, 25.0, 100.0, false, false, false),
		&"downed": PartyMemberHudProjection.create(3, "Cyra", &"rogue", "Rogue", 5, 2, 0.0, 100.0, false, true, false),
		&"dead": PartyMemberHudProjection.create(4, "Dara", &"bard", "Bard", 6, 4, 0.0, 100.0, false, false, true),
	}


func _build_members(kind: StringName, row: HBoxContainer, scene: PackedScene) -> void:
	for state: StringName in [&"normal", &"critical", &"downed", &"dead"]:
		var control := scene.instantiate() as Control
		control.name = "%s_%s" % [String(kind).capitalize(), String(state).capitalize()]
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL if kind == &"rich" else Control.SIZE_SHRINK_BEGIN
		control.call(&"present", (_member_projections[state] as PartyMemberHudProjection).copy())
		control.connect(&"activated", _on_activated)
		control.connect(&"inspect_requested", _on_inspect_requested)
		control.connect(&"ledger_requested", _on_ledger_requested)
		row.add_child(control)
		_member_controls[_member_key(kind, state)] = control


func _build_alerts() -> void:
	var row := get_node("Margin/Layout/CompactAlertSection/AlertRow") as HBoxContainer
	var projections: Dictionary = {
		&"critical": CombatAlertProjection.create(&"critical:2", 2, &"critical_health", "Brom is critical", "25 of 100 health", CombatAlertProjection.Severity.CRITICAL, true, false),
		&"downed": CombatAlertProjection.create(&"downed:3", 3, &"downed_or_dying", "Cyra is downed", "Needs revival", CombatAlertProjection.Severity.DOWNED, true, true),
		&"dead": CombatAlertProjection.create(&"dead:4", 4, &"downed_or_dying", "Dara is dead", "No longer active", CombatAlertProjection.Severity.DEAD, true, true),
	}
	for state: StringName in [&"critical", &"downed", &"dead"]:
		var alert := ALERT_SCENE.instantiate() as Control
		alert.name = "Alert_%s" % String(state).capitalize()
		alert.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		alert.call(&"present_alert", (projections[state] as CombatAlertProjection).copy())
		alert.connect(&"activated", _on_activated)
		alert.connect(&"inspect_requested", _on_inspect_requested)
		alert.connect(&"ledger_requested", _on_ledger_requested)
		row.add_child(alert)
		_alert_controls[state] = alert


func _member_key(kind: StringName, state: StringName) -> StringName:
	return StringName("%s:%s" % [kind, state])


func _on_activated(_member_id: int) -> void:
	_activation_count += 1


func _on_inspect_requested(_member_id: int) -> void:
	_inspect_count += 1


func _on_ledger_requested(_member_id: int) -> void:
	_ledger_count += 1


func _append_signature(node: Node, output: Array[String]) -> void:
	output.append("%s|%s" % [get_path_to(node), node.get_class()])
	for child: Node in node.get_children():
		_append_signature(child, output)
