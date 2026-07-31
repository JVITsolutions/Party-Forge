class_name AdditionalSettingsPage
extends MarginContainer


func _ready() -> void:
	var mode := _mode()
	if mode.item_count == 0:
		mode.add_item("Player Simulation", PartyForgeSettings.Mode.PLAYER_SIMULATION)
		mode.add_item("Developer Mode", PartyForgeSettings.Mode.DEVELOPER_MODE)
	if not mode.item_selected.is_connected(_on_mode_changed):
		mode.item_selected.connect(_on_mode_changed)
	if not _party_capacity().value_changed.is_connected(_on_party_capacity_changed):
		_party_capacity().value_changed.connect(_on_party_capacity_changed)
	if not _enemy_density().value_changed.is_connected(_on_enemy_density_changed):
		_enemy_density().value_changed.connect(_on_enemy_density_changed)
	_refresh_value_labels()
	_refresh_enabled_state()


func bind(settings: PartyForgeSettings) -> void:
	var source := settings if settings != null else PartyForgeSettings.new()
	_mode().selected = source.mode
	_unlock_all().button_pressed = source.unlock_all_implemented_content
	_god_mode().button_pressed = source.god_mode
	_party_capacity().value = source.party_capacity_override
	_enemy_density().value = source.enemy_density_percent
	_refresh_value_labels()
	_refresh_enabled_state()


func write_to(settings: PartyForgeSettings) -> void:
	if settings == null:
		return
	settings.mode = _mode().selected
	settings.unlock_all_implemented_content = _unlock_all().button_pressed
	settings.god_mode = _god_mode().button_pressed
	settings.party_capacity_override = int(_party_capacity().value)
	settings.enemy_density_percent = int(_enemy_density().value)


func reset_developer_options() -> void:
	_unlock_all().button_pressed = false
	_god_mode().button_pressed = false
	_party_capacity().value = 4
	_enemy_density().value = 100
	_refresh_value_labels()


func _on_mode_changed(_index: int) -> void:
	_refresh_enabled_state()


func _on_party_capacity_changed(value: float) -> void:
	_party_capacity_label().text = "%d" % int(value)


func _on_enemy_density_changed(value: float) -> void:
	_enemy_density_label().text = "%d%%" % int(value)


func _refresh_enabled_state() -> void:
	var enabled := _mode().selected == PartyForgeSettings.Mode.DEVELOPER_MODE
	_unlock_all().disabled = not enabled
	_god_mode().disabled = not enabled
	_party_capacity().editable = enabled
	_enemy_density().editable = enabled


func _refresh_value_labels() -> void:
	_on_party_capacity_changed(_party_capacity().value)
	_on_enemy_density_changed(_enemy_density().value)


func _mode() -> OptionButton:
	return get_node("Layout/Mode") as OptionButton


func _unlock_all() -> CheckButton:
	return get_node("Layout/UnlockAll") as CheckButton


func _god_mode() -> CheckButton:
	return get_node("Layout/GodMode") as CheckButton


func _party_capacity() -> HSlider:
	return get_node("Layout/PartyCapacity/Value") as HSlider


func _party_capacity_label() -> Label:
	return get_node("Layout/PartyCapacity/Label") as Label


func _enemy_density() -> HSlider:
	return get_node("Layout/EnemyDensity/Value") as HSlider


func _enemy_density_label() -> Label:
	return get_node("Layout/EnemyDensity/Label") as Label
