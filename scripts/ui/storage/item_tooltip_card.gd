class_name ItemTooltipCard
extends PanelContainer

const RARITY_PALETTE := preload("res://scripts/ui/storage/item_rarity_palette.gd")

var _detail: Dictionary = {}
var _advanced := false
var _developer_mode := false
var _built := false
var _layout: VBoxContainer
var _role_label: Label
var _icon: TextureRect
var _icon_placeholder: Label
var _title_label: Label
var _rarity_label: Label
var _classification_label: Label
var _base_damage_box: VBoxContainer
var _requirements_label: Label
var _disabled_label: Label
var _core_values_label: Label
var _implicit_label: Label
var _explicit_label: Label
var _special_label: Label
var _warning_label: Label
var _base_damage_advanced_label: Label
var _delta_box: VBoxContainer
var _technical_toggle: Button
var _technical_details: VBoxContainer


func _ready() -> void:
	_ensure_built()


func present(
	detail: Dictionary,
	role: StringName,
	advanced: bool,
	delta_lines: Array[Dictionary] = [],
	developer_mode: bool = false,
) -> void:
	_ensure_built()
	_detail = detail.duplicate(true)
	_advanced = advanced
	_developer_mode = developer_mode
	_role_label.text = _role_text(role)
	_role_label.visible = not _role_label.text.is_empty()
	_title_label.text = String(_detail.get("name", "Unknown Item"))
	_set_icon()
	_rarity_label.text = String(_detail.get("rarity_name", "Unknown Rarity"))
	var rarity_color := RARITY_PALETTE.color_for(StringName(String(_detail.get("rarity_id", ""))))
	_title_label.add_theme_color_override("font_color", rarity_color)
	_rarity_label.add_theme_color_override("font_color", rarity_color)
	add_theme_stylebox_override("panel", _panel_style(rarity_color))
	_set_label(_classification_label, _classification_lines())
	_set_base_damage()
	_set_label(_core_values_label, _string_lines(_detail.get("core_value_lines", [])))
	var modifiers := _modifier_lines()
	_set_label(_implicit_label, modifiers["implicit"])
	_set_label(_explicit_label, modifiers["explicit"])
	_set_label(_special_label, modifiers["special"])
	_set_label(_requirements_label, _string_lines(_detail.get("requirement_lines", [])))
	var disabled_lines := PackedStringArray()
	if bool(_detail.get("is_disabled", false)):
		disabled_lines.append("Disabled — requirements not met")
		disabled_lines.append_array(_string_lines(_detail.get("disabled_requirement_lines", [])))
	_set_label(_disabled_label, disabled_lines)
	_disabled_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.26))
	_set_label(_warning_label, _string_lines(_detail.get("equip_warning_lines", [])))
	_warning_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.34))
	_set_label(_base_damage_advanced_label, _string_lines(_detail.get("base_damage_advanced_lines", [])) if _advanced else PackedStringArray())
	_set_delta_lines(delta_lines)
	_technical_toggle.visible = _developer_mode
	_technical_toggle.button_pressed = false
	_technical_details.visible = false
	_build_technical_details()


func displayed_instance_id() -> String:
	return String(_detail.get("instance_id", ""))


func advanced_visible() -> bool:
	return _advanced


func technical_visible() -> bool:
	return _developer_mode and _technical_details.visible


func set_technical_expanded(active: bool) -> void:
	_ensure_built()
	_technical_toggle.button_pressed = active and _developer_mode
	_technical_details.visible = active and _developer_mode


func rendered_text() -> String:
	_ensure_built()
	var lines := PackedStringArray()
	_collect_visible_text(self, true, lines)
	return "\n".join(lines)


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	custom_minimum_size = Vector2(340.0, 0.0)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_layout = VBoxContainer.new()
	_layout.name = "Layout"
	_layout.add_theme_constant_override("separation", 7)
	add_child(_layout)
	_role_label = _add_label("Role", 16)
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 10)
	_layout.add_child(header)
	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.custom_minimum_size = Vector2(56.0, 56.0)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_icon)
	_icon_placeholder = Label.new()
	_icon_placeholder.name = "Placeholder"
	_icon_placeholder.text = "?"
	_icon_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon_placeholder.add_theme_font_size_override("font_size", 28)
	_icon_placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.add_child(_icon_placeholder)
	var header_text := VBoxContainer.new()
	header_text.name = "Text"
	header_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_text.add_theme_constant_override("separation", 2)
	header.add_child(header_text)
	_title_label = _add_label("Title", 22, header_text)
	_rarity_label = _add_label("Rarity", 15, header_text)
	_classification_label = _add_label("Classification", 14, header_text)
	_base_damage_box = VBoxContainer.new()
	_base_damage_box.name = "BaseDamage"
	_base_damage_box.add_theme_constant_override("separation", 2)
	_layout.add_child(_base_damage_box)
	_core_values_label = _add_label("CoreValues", 15)
	_implicit_label = _add_label("ImplicitModifiers", 14)
	_explicit_label = _add_label("ExplicitModifiers", 14)
	_special_label = _add_label("SpecialModifiers", 14)
	_requirements_label = _add_label("Requirements", 14)
	_disabled_label = _add_label("DisabledStatus", 15)
	_warning_label = _add_label("EligibilityWarning", 14)
	_base_damage_advanced_label = _add_label("BaseDamageAdvanced", 13)
	_delta_box = VBoxContainer.new()
	_delta_box.name = "ComparisonDeltas"
	_delta_box.add_theme_constant_override("separation", 3)
	_layout.add_child(_delta_box)
	_technical_toggle = Button.new()
	_technical_toggle.name = "TechnicalToggle"
	_technical_toggle.text = "Technical Details"
	_technical_toggle.toggle_mode = true
	_technical_toggle.visible = false
	_technical_toggle.pressed.connect(_on_technical_toggled)
	_layout.add_child(_technical_toggle)
	_technical_details = VBoxContainer.new()
	_technical_details.name = "TechnicalDetails"
	_technical_details.visible = false
	_layout.add_child(_technical_details)


func _add_label(node_name: String, font_size: int, parent: Container = _layout) -> Label:
	var label := Label.new()
	label.name = node_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _set_icon() -> void:
	var item_name := String(_detail.get("name", "Unknown Item"))
	var path := String(_detail.get("icon_path", ""))
	_icon.texture = load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null
	_icon_placeholder.visible = _icon.texture == null
	_icon.accessibility_name = "%s item icon%s" % [item_name, ", icon unavailable" if _icon.texture == null else ""]


func _role_text(role: StringName) -> String:
	var value := String(role)
	if not value.begins_with("equipped:"):
		return ""
	return "Equipped - %s" % value.trim_prefix("equipped:").replace("_", " ").capitalize()


func _classification_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	var item_type := String(_detail.get("item_type_id", ""))
	if not item_type.is_empty():
		lines.append(item_type.replace("_", " ").capitalize())
	lines.append("Item Level %d" % int(_detail.get("item_level", 0)))
	var handedness := String(_detail.get("handedness_id", ""))
	if not handedness.is_empty() and handedness != "none":
		lines.append(handedness.replace("_", " ").capitalize())
	var slots := _string_lines(_detail.get("compatible_slot_ids", []))
	if not slots.is_empty():
		var labels := PackedStringArray()
		for slot_id: String in slots:
			labels.append(slot_id.replace("_", " ").capitalize())
		lines.append("Slots: %s" % ", ".join(labels))
	return lines


func _modifier_lines() -> Dictionary:
	var result := {
		"implicit": PackedStringArray(),
		"explicit": PackedStringArray(),
		"special": PackedStringArray(),
	}
	var affixes: Variant = _detail.get("affixes", [])
	if not affixes is Array:
		return result
	for value: Variant in affixes as Array:
		if not value is Dictionary:
			continue
		var affix := value as Dictionary
		var kind := String(affix.get("affix_kind", "special"))
		var section := "implicit" if kind == "implicit" else "explicit" if kind in ["prefix", "suffix"] else "special"
		var rolls: Variant = affix.get("rolls", [])
		if not rolls is Array:
			continue
		for roll_value: Variant in rolls as Array:
			if not roll_value is Dictionary:
				continue
			var roll := roll_value as Dictionary
			var line := String(roll.get("effect_text", ""))
			if _advanced:
				line += _advanced_suffix(affix, roll)
			var section_lines := result[section] as PackedStringArray
			section_lines.append(line)
			result[section] = section_lines
	return result


func _set_base_damage() -> void:
	for child: Node in _base_damage_box.get_children():
		child.free()
	var lines := _string_lines(_detail.get("base_damage_lines", []))
	var components: Variant = _detail.get("base_damage_components", [])
	_base_damage_box.visible = not lines.is_empty()
	for index: int in lines.size():
		var component := (components as Array)[index] as Dictionary if components is Array and index < (components as Array).size() and (components as Array)[index] is Dictionary else {}
		var label := Label.new()
		label.name = "Component_%s" % String(component.get("damage_type_id", index))
		label.text = "%s%s" % ["Base Damage\n" if index == 0 else "", lines[index]]
		label.accessibility_name = "Base damage, %s" % lines[index]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 15)
		var color: Variant = component.get("presentation_color")
		if color is Color:
			label.add_theme_color_override("font_color", color as Color)
		_base_damage_box.add_child(label)


func _advanced_suffix(affix: Dictionary, roll: Dictionary) -> String:
	var parts := PackedStringArray()
	var display_name := String(affix.get("display_name", "")).strip_edges()
	if not display_name.is_empty():
		parts.append(display_name)
	var kind := String(affix.get("affix_kind", "")).strip_edges()
	if not kind.is_empty():
		parts.append(kind.capitalize())
	var tier := int(affix.get("tier", 0))
	if tier > 0:
		parts.append("Tier %d" % tier)
	if roll.has("minimum_roll") and roll.has("maximum_roll"):
		parts.append("Range: %s" % _range_text(roll))
	if roll.has("roll_fraction"):
		parts.append("Roll quality: %s%%" % _number(float(roll["roll_fraction"]) * 100.0))
	return "\n%s" % " | ".join(parts) if not parts.is_empty() else ""


func _range_text(roll: Dictionary) -> String:
	var minimum := float(roll.get("minimum_roll", 0.0))
	var maximum := float(roll.get("maximum_roll", 0.0))
	var operation := int(roll.get("operation", StatModifier.Operation.FLAT))
	if operation == StatModifier.Operation.FLAT:
		return "%s-%s" % [_number(minimum), _number(maximum)]
	return "%s-%s%%" % [_number(minimum * 100.0), _number(maximum * 100.0)]


func _set_delta_lines(lines: Array[Dictionary]) -> void:
	for child: Node in _delta_box.get_children():
		child.free()
	_delta_box.visible = not lines.is_empty()
	for line: Dictionary in lines:
		var label := Label.new()
		label.text = String(line.get("text", ""))
		label.accessibility_name = String(line.get("accessible_text", label.text))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var direction := int(line.get("direction", 0))
		label.add_theme_color_override("font_color", Color(0.34, 0.92, 0.48) if direction > 0 else Color(1.0, 0.38, 0.34) if direction < 0 else Color(0.78, 0.80, 0.84))
		_delta_box.add_child(label)


func _build_technical_details() -> void:
	for child: Node in _technical_details.get_children():
		child.free()
	_add_technical_line("Instance ID", _detail.get("instance_id", ""))
	_add_technical_line("Base ID", _detail.get("base_definition_id", ""))
	_add_technical_line("Container", _detail.get("container_id", ""))
	_add_technical_line("Slot", _detail.get("slot", ""))
	_add_technical_line("Base Damage Profile", _detail.get("base_damage_profile_id", ""))


func _add_technical_line(field_name: String, field_value: Variant) -> void:
	var value := str(field_value)
	if value.is_empty():
		return
	var label := Label.new()
	label.text = "%s: %s" % [field_name, value]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_technical_details.add_child(label)


func _set_label(label: Label, lines: PackedStringArray) -> void:
	label.text = "\n".join(lines)
	label.visible = not lines.is_empty()


func _string_lines(value: Variant) -> PackedStringArray:
	var result := PackedStringArray()
	if value is PackedStringArray:
		return (value as PackedStringArray).duplicate()
	if value is Array:
		for entry: Variant in value as Array:
			result.append(String(entry))
	return result


func _on_technical_toggled() -> void:
	set_technical_expanded(_technical_toggle.button_pressed)


func _collect_visible_text(node: Node, ancestors_visible: bool, lines: PackedStringArray) -> void:
	var control := node as Control
	var visible_here := ancestors_visible and (control == null or control.visible)
	if not visible_here:
		return
	if node is Label:
		var label_text := (node as Label).text.strip_edges()
		if not label_text.is_empty():
			lines.append(label_text)
	elif node is Button:
		var button_text := (node as Button).text.strip_edges()
		if not button_text.is_empty():
			lines.append(button_text)
	for child: Node in node.get_children():
		_collect_visible_text(child, visible_here, lines)


func _panel_style(rarity_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.032, 0.048, 0.0)
	style.border_color = rarity_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.content_margin_left = 14.0
	style.content_margin_top = 12.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 12.0
	return style


func _number(value: float) -> String:
	var rounded := roundf(value)
	if is_equal_approx(value, rounded):
		return str(int(rounded))
	return ("%.2f" % value).trim_suffix("0").trim_suffix(".")
