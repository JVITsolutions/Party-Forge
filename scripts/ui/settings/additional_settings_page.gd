class_name AdditionalSettingsPage
extends MarginContainer

signal city_tree_requested(developer_preview: bool)
signal item_sandbox_requested

const INACTIVE_EXPLANATION := "Developer options are retained but inactive in Player Simulation. Select Developer Mode to use them in the next run."


func _ready() -> void:
	var mode := _mode()
	if mode.item_count == 0:
		mode.add_item("Player Simulation", PartyForgeSettings.Mode.PLAYER_SIMULATION)
		mode.add_item("Developer Mode", PartyForgeSettings.Mode.DEVELOPER_MODE)
	var source := _personal_drop_source()
	if source.item_count == 0:
		source.add_item("Automatic", 0)
		source.add_item("Ordinary Melee", 1)
		source.add_item("Ordinary Specialist", 2)
		source.add_item("Elite", 3)
		source.add_item("Boss", 4)
	if not mode.item_selected.is_connected(_on_mode_changed):
		mode.item_selected.connect(_on_mode_changed)
	if not _party_capacity().value_changed.is_connected(_on_party_capacity_changed):
		_party_capacity().value_changed.connect(_on_party_capacity_changed)
	if not _enemy_density().value_changed.is_connected(_on_enemy_density_changed):
		_enemy_density().value_changed.connect(_on_enemy_density_changed)
	if not _experience_multiplier().value_changed.is_connected(_on_experience_multiplier_changed):
		_experience_multiplier().value_changed.connect(_on_experience_multiplier_changed)
	if not _level_up_card_count().value_changed.is_connected(_on_level_up_card_count_changed):
		_level_up_card_count().value_changed.connect(_on_level_up_card_count_changed)
	if not _personal_drop_multiplier().value_changed.is_connected(_on_personal_drop_multiplier_changed):
		_personal_drop_multiplier().value_changed.connect(_on_personal_drop_multiplier_changed)
	if not _personal_drop_item_level().value_changed.is_connected(_on_personal_drop_item_level_changed):
		_personal_drop_item_level().value_changed.connect(_on_personal_drop_item_level_changed)
	if not _open_city_tree().pressed.is_connected(_on_open_city_tree_pressed):
		_open_city_tree().pressed.connect(_on_open_city_tree_pressed)
	if not _open_item_sandbox().pressed.is_connected(_on_open_item_sandbox_pressed):
		_open_item_sandbox().pressed.connect(_on_open_item_sandbox_pressed)
	_refresh_value_labels()
	_refresh_enabled_state()


func initial_focus() -> Control:
	return _mode()


func bind(settings: PartyForgeSettings) -> void:
	var source := settings if settings != null else PartyForgeSettings.new()
	_mode().selected = source.mode
	_unlock_all().button_pressed = source.unlock_all_implemented_content
	_god_mode().button_pressed = source.god_mode
	_party_capacity().value = source.party_capacity_override
	_enemy_density().value = source.enemy_density_percent
	_experience_multiplier().value = source.experience_multiplier_percent
	_level_up_card_count().value = source.level_up_card_count
	_personal_drop_multiplier().value = source.personal_drop_multiplier_percent
	_force_personal_drops().button_pressed = source.force_personal_drops
	_select_personal_drop_source(source.personal_drop_source_category_override)
	_personal_drop_item_level().value = source.personal_drop_item_level_override
	_show_ground_chest_diagnostics().button_pressed = source.show_ground_chest_diagnostics
	_refresh_value_labels()
	_refresh_enabled_state()


func write_to(settings: PartyForgeSettings) -> void:
	if settings == null:
		return
	settings.mode = _mode().selected as PartyForgeSettings.Mode
	settings.unlock_all_implemented_content = _unlock_all().button_pressed
	settings.god_mode = _god_mode().button_pressed
	settings.party_capacity_override = int(_party_capacity().value)
	settings.enemy_density_percent = int(_enemy_density().value)
	settings.experience_multiplier_percent = int(_experience_multiplier().value)
	settings.level_up_card_count = int(_level_up_card_count().value)
	settings.personal_drop_multiplier_percent = int(_personal_drop_multiplier().value)
	settings.force_personal_drops = _force_personal_drops().button_pressed
	settings.personal_drop_source_category_override = _selected_personal_drop_source()
	settings.personal_drop_item_level_override = int(_personal_drop_item_level().value)
	settings.show_ground_chest_diagnostics = _show_ground_chest_diagnostics().button_pressed


func reset_developer_options() -> void:
	_unlock_all().button_pressed = false
	_god_mode().button_pressed = false
	_party_capacity().value = 4
	_enemy_density().value = 100
	_experience_multiplier().value = 100
	_level_up_card_count().value = 5
	_personal_drop_multiplier().value = 100
	_force_personal_drops().button_pressed = false
	_personal_drop_source().select(_personal_drop_source().get_item_index(0))
	_personal_drop_item_level().value = 0
	_show_ground_chest_diagnostics().button_pressed = false
	_refresh_value_labels()


func _on_mode_changed(_index: int) -> void:
	_refresh_enabled_state()


func _on_party_capacity_changed(value: float) -> void:
	_party_capacity_label().text = "%d" % int(value)


func _on_enemy_density_changed(value: float) -> void:
	_enemy_density_label().text = "%d%%" % int(value)


func _on_experience_multiplier_changed(value: float) -> void:
	_experience_multiplier_label().text = "%d%%" % int(value)


func _on_level_up_card_count_changed(value: float) -> void:
	_level_up_card_count_label().text = "%d" % int(value)


func _on_personal_drop_multiplier_changed(value: float) -> void:
	_personal_drop_multiplier_label().text = "%d%%" % int(value)


func _on_personal_drop_item_level_changed(value: float) -> void:
	_personal_drop_item_level_label().text = "Automatic" if int(value) == 0 else "%d" % int(value)


func _on_open_city_tree_pressed() -> void:
	if _mode().selected == PartyForgeSettings.Mode.DEVELOPER_MODE and not _open_city_tree().disabled:
		city_tree_requested.emit(true)


func _on_open_item_sandbox_pressed() -> void:
	if _mode().selected == PartyForgeSettings.Mode.DEVELOPER_MODE and not _open_item_sandbox().disabled:
		item_sandbox_requested.emit()


func _refresh_enabled_state() -> void:
	var enabled := _mode().selected == PartyForgeSettings.Mode.DEVELOPER_MODE
	_unlock_all().disabled = not enabled
	_god_mode().disabled = not enabled
	_party_capacity().editable = enabled
	_enemy_density().editable = enabled
	_experience_multiplier().editable = enabled
	_level_up_card_count().editable = enabled
	_personal_drop_multiplier().editable = enabled
	_force_personal_drops().disabled = not enabled
	_personal_drop_source().disabled = not enabled
	_personal_drop_item_level().editable = enabled
	_show_ground_chest_diagnostics().disabled = not enabled
	_open_city_tree().disabled = not enabled
	_open_item_sandbox().disabled = not enabled
	_inactive_status().visible = not enabled
	for control: Control in [_unlock_all(), _god_mode(), _party_capacity(), _enemy_density(), _experience_multiplier(), _level_up_card_count(), _personal_drop_multiplier(), _force_personal_drops(), _personal_drop_source(), _personal_drop_item_level(), _show_ground_chest_diagnostics(), _open_city_tree(), _open_item_sandbox()]:
		control.tooltip_text = "" if enabled else INACTIVE_EXPLANATION
	_configure_focus_order(enabled)


func _refresh_value_labels() -> void:
	_on_party_capacity_changed(_party_capacity().value)
	_on_enemy_density_changed(_enemy_density().value)
	_on_experience_multiplier_changed(_experience_multiplier().value)
	_on_level_up_card_count_changed(_level_up_card_count().value)
	_on_personal_drop_multiplier_changed(_personal_drop_multiplier().value)
	_on_personal_drop_item_level_changed(_personal_drop_item_level().value)


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


func _experience_multiplier() -> HSlider:
	return get_node("Layout/ExperienceMultiplier/Value") as HSlider


func _experience_multiplier_label() -> Label:
	return get_node("Layout/ExperienceMultiplier/Label") as Label


func _level_up_card_count() -> HSlider:
	return get_node("Layout/LevelUpCardCount/Value") as HSlider


func _level_up_card_count_label() -> Label:
	return get_node("Layout/LevelUpCardCount/Label") as Label


func _inactive_status() -> Label:
	return get_node("Layout/InactiveStatus") as Label


func _personal_drop_multiplier() -> HSlider:
	return get_node("Layout/PersonalDropMultiplier/Value") as HSlider


func _personal_drop_multiplier_label() -> Label:
	return get_node("Layout/PersonalDropMultiplier/Label") as Label


func _force_personal_drops() -> CheckButton:
	return get_node("Layout/ForcePersonalDrops") as CheckButton


func _personal_drop_source() -> OptionButton:
	return get_node("Layout/PersonalDropSourceCategory") as OptionButton


func _personal_drop_item_level() -> HSlider:
	return get_node("Layout/PersonalDropItemLevel/Value") as HSlider


func _personal_drop_item_level_label() -> Label:
	return get_node("Layout/PersonalDropItemLevel/Label") as Label


func _show_ground_chest_diagnostics() -> CheckButton:
	return get_node("Layout/ShowGroundChestDiagnostics") as CheckButton


func _select_personal_drop_source(source_category: StringName) -> void:
	var item_id := 0
	match source_category:
		&"ordinary_melee": item_id = 1
		&"ordinary_specialist": item_id = 2
		&"elite": item_id = 3
		&"boss": item_id = 4
	_personal_drop_source().select(_personal_drop_source().get_item_index(item_id))


func _selected_personal_drop_source() -> StringName:
	match _personal_drop_source().get_selected_id():
		1: return &"ordinary_melee"
		2: return &"ordinary_specialist"
		3: return &"elite"
		4: return &"boss"
		_: return &""


func _open_city_tree() -> Button:
	return get_node("Layout/OpenCityPassiveTree") as Button


func _open_item_sandbox() -> Button:
	return get_node("Layout/OpenDeveloperItemSandbox") as Button


func _configure_focus_order(developer_mode_enabled: bool) -> void:
	var order: Array[Control] = [_mode()]
	if developer_mode_enabled:
		order.append_array([_unlock_all(), _god_mode(), _party_capacity(), _enemy_density(), _experience_multiplier(), _level_up_card_count(), _personal_drop_multiplier(), _force_personal_drops(), _personal_drop_source(), _personal_drop_item_level(), _show_ground_chest_diagnostics(), _open_city_tree(), _open_item_sandbox()])
	else:
		order.append(_inactive_status())
	order.append_array([
		get_node("Layout/ResetDeveloperOptions") as Control,
		get_node("Layout/ApplyAndReturn") as Control,
		get_node("Layout/Cancel") as Control,
	])
	for index: int in range(order.size()):
		var control := order[index]
		var next := order[(index + 1) % order.size()]
		var previous := order[posmod(index - 1, order.size())]
		control.focus_mode = Control.FOCUS_ALL
		control.focus_next = control.get_path_to(next)
		control.focus_previous = control.get_path_to(previous)
		control.focus_neighbor_bottom = control.get_path_to(next)
		control.focus_neighbor_top = control.get_path_to(previous)
