class_name GameSettingsPage
extends MarginContainer


func initial_focus() -> Control:
	return _reduced_motion()


func bind(settings: PartyForgeSettings) -> void:
	_reduced_motion().button_pressed = settings.reduced_motion if settings != null else false


func write_to(settings: PartyForgeSettings) -> void:
	if settings != null:
		settings.reduced_motion = _reduced_motion().button_pressed


func _reduced_motion() -> CheckButton:
	return get_node("Layout/ReducedMotion") as CheckButton
