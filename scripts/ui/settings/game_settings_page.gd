class_name GameSettingsPage
extends MarginContainer


func _ready() -> void:
	_populate_scale_options()
	if not _hud_background_opacity().value_changed.is_connected(_on_hud_background_opacity_changed):
		_hud_background_opacity().value_changed.connect(_on_hud_background_opacity_changed)
	_update_hud_background_opacity_readout(_hud_background_opacity().value)


func initial_focus() -> Control:
	return _reduced_motion()


func bind(settings: PartyForgeSettings) -> void:
	_populate_scale_options()
	_reduced_motion().button_pressed = settings.reduced_motion if settings != null else false
	_high_contrast().button_pressed = settings.high_contrast if settings != null else false
	_hud_background_opacity().value = settings.character_hud_background_opacity_percent if settings != null else PartyForgeSettings.DEFAULT_CHARACTER_HUD_BACKGROUND_OPACITY_PERCENT
	_update_hud_background_opacity_readout(_hud_background_opacity().value)
	_select_scale(_ui_scale(), settings.ui_scale_percent if settings != null else 100)
	_select_scale(_text_scale(), settings.text_scale_percent if settings != null else 100)


func write_to(settings: PartyForgeSettings) -> void:
	if settings != null:
		settings.reduced_motion = _reduced_motion().button_pressed
		settings.high_contrast = _high_contrast().button_pressed
		settings.character_hud_background_opacity_percent = roundi(_hud_background_opacity().value)
		settings.ui_scale_percent = _ui_scale().get_item_id(_ui_scale().selected)
		settings.text_scale_percent = _text_scale().get_item_id(_text_scale().selected)


func _reduced_motion() -> CheckButton:
	return get_node("Layout/ReducedMotion") as CheckButton


func _high_contrast() -> CheckButton:
	return get_node("Layout/HighContrast") as CheckButton


func _hud_background_opacity() -> HSlider:
	return get_node("Layout/HudBackgroundOpacity/Value") as HSlider


func _hud_background_opacity_readout() -> Label:
	return get_node("Layout/HudBackgroundOpacity/Current") as Label


func _ui_scale() -> OptionButton:
	return get_node("Layout/UIScale") as OptionButton


func _text_scale() -> OptionButton:
	return get_node("Layout/TextScale") as OptionButton


func _populate_scale_options() -> void:
	for scale: OptionButton in [_ui_scale(), _text_scale()]:
		if scale.item_count != PartyForgeSettings.UI_SCALE_OPTIONS.size():
			scale.clear()
			for option: int in PartyForgeSettings.UI_SCALE_OPTIONS:
				scale.add_item("%d%%" % option, option)


func _select_scale(scale: OptionButton, value: int) -> void:
	var index := scale.get_item_index(value)
	scale.select(index if index >= 0 else scale.get_item_index(100))


func _on_hud_background_opacity_changed(value: float) -> void:
	_update_hud_background_opacity_readout(value)


func _update_hud_background_opacity_readout(value: float) -> void:
	_hud_background_opacity_readout().text = "%d%%" % roundi(value)
