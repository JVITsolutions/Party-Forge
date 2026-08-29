class_name ForgeActionBar
extends HBoxContainer

signal action_requested(action_id: StringName)

var _buttons: Dictionary = {}


func present(actions: Array) -> void:
	for child: Node in get_children():
		child.free()
	_buttons.clear()
	for action_value: Variant in actions:
		var action := (action_value as Dictionary).duplicate(true)
		var action_id := StringName(action.get("id", &""))
		if action_id == &"":
			continue
		var button := Button.new()
		button.name = "Action_%s" % action_id
		button.text = String(action.get("label", action_id.capitalize()))
		button.custom_minimum_size = Vector2(160.0, 48.0)
		button.focus_mode = Control.FOCUS_ALL
		button.disabled = not bool(action.get("enabled", true))
		button.accessibility_description = String(action.get("accessibility_description", button.text))
		button.tooltip_text = String(action.get("reason", ""))
		button.set_meta(&"action_id", action_id)
		button.set_meta(&"action_enabled", not button.disabled)
		button.theme_type_variation = _variation_for(StringName(action.get("kind", &"secondary")), button.disabled)
		button.pressed.connect(_on_button_pressed.bind(action_id, button))
		add_child(button)
		_buttons[action_id] = button


func button_for(action_id: StringName) -> Button:
	return _buttons.get(action_id) as Button


func _on_button_pressed(action_id: StringName, button: Button) -> void:
	if button == null or button.disabled or not bool(button.get_meta(&"action_enabled", false)):
		return
	action_requested.emit(action_id)


func _variation_for(kind: StringName, disabled: bool) -> StringName:
	if disabled or kind == &"unavailable":
		return &"LivingForgeUnavailableButton"
	if kind == &"primary":
		return &"LivingForgePrimaryButton"
	if kind == &"destructive":
		return &"LivingForgeDestructiveButton"
	return &"LivingForgeSecondaryButton"
