class_name PartyForgeSettingsStore
extends RefCounted

const DEFAULT_PATH := "user://party_forge_settings.cfg"
const SECTION := "settings"
var _promote_file: Callable

func _init(promote_file: Callable = Callable()) -> void:
	_promote_file = promote_file

func load_settings(path: String = DEFAULT_PATH) -> PartyForgeSettings:
	var result := PartyForgeSettings.new()
	var config := ConfigFile.new()
	var load_error := config.load(path)
	if load_error == ERR_FILE_NOT_FOUND:
		return result
	if load_error != OK:
		push_error("PARTY_FORGE_SETTINGS_LOAD_ERROR path=%s code=%d" % [path, load_error])
		return result
	var has_explicit_schema_version := config.has_section_key(SECTION, "schema_version")
	var version_value: Variant = config.get_value(SECTION, "schema_version", 1)
	var loaded_version := int(version_value) if typeof(version_value) == TYPE_INT else -1
	if loaded_version not in PartyForgeSettings.SUPPORTED_SCHEMA_VERSIONS:
		push_error("PARTY_FORGE_SETTINGS_VERSION_ERROR path=%s version=%d supported=%d" % [path, loaded_version, PartyForgeSettings.SCHEMA_VERSION])
		return result
	result.schema_version = PartyForgeSettings.SCHEMA_VERSION
	var mode_value: Variant = config.get_value(SECTION, "mode", PartyForgeSettings.Mode.PLAYER_SIMULATION)
	result.mode = int(mode_value) as PartyForgeSettings.Mode if typeof(mode_value) == TYPE_INT else PartyForgeSettings.Mode.PLAYER_SIMULATION
	var unlock_value: Variant = config.get_value(SECTION, "unlock_all_implemented_content", false)
	result.unlock_all_implemented_content = bool(unlock_value) if typeof(unlock_value) == TYPE_BOOL else false
	var god_value: Variant = config.get_value(SECTION, "god_mode", false)
	result.god_mode = bool(god_value) if typeof(god_value) == TYPE_BOOL else false
	var capacity_value: Variant = config.get_value(SECTION, "party_capacity_override", 4)
	result.party_capacity_override = int(capacity_value) if typeof(capacity_value) == TYPE_INT else 4
	var density_value: Variant = config.get_value(SECTION, "enemy_density_percent", 100)
	result.enemy_density_percent = int(density_value) if typeof(density_value) == TYPE_INT else 100
	var xp_value: Variant = config.get_value(SECTION, "experience_multiplier_percent", 100)
	result.experience_multiplier_percent = int(xp_value) if typeof(xp_value) == TYPE_INT else 100
	var cards_value: Variant = config.get_value(SECTION, "level_up_card_count", 5)
	result.level_up_card_count = int(cards_value) if typeof(cards_value) == TYPE_INT else 5
	var reduced_motion_value: Variant = config.get_value(SECTION, "reduced_motion", false)
	result.reduced_motion = bool(reduced_motion_value) if typeof(reduced_motion_value) == TYPE_BOOL else false
	var high_contrast_value: Variant = config.get_value(SECTION, "high_contrast", false)
	result.high_contrast = bool(high_contrast_value) if typeof(high_contrast_value) == TYPE_BOOL else false
	var ui_scale_value: Variant = config.get_value(SECTION, "ui_scale_percent", 100)
	result.ui_scale_percent = int(ui_scale_value) if typeof(ui_scale_value) == TYPE_INT else 100
	var text_scale_value: Variant = config.get_value(SECTION, "text_scale_percent", 100)
	result.text_scale_percent = int(text_scale_value) if typeof(text_scale_value) == TYPE_INT else 100
	if loaded_version >= 2:
		var hud_opacity_value: Variant = config.get_value(SECTION, "character_hud_background_opacity_percent", PartyForgeSettings.DEFAULT_CHARACTER_HUD_BACKGROUND_OPACITY_PERCENT)
		result.character_hud_background_opacity_percent = int(hud_opacity_value) if typeof(hud_opacity_value) == TYPE_INT else PartyForgeSettings.DEFAULT_CHARACTER_HUD_BACKGROUND_OPACITY_PERCENT
	if has_explicit_schema_version and loaded_version == 3:
		var party_collapsed_value: Variant = config.get_value(SECTION, "hud_party_collapsed", false)
		var alerts_collapsed_value: Variant = config.get_value(SECTION, "hud_alerts_collapsed", false)
		result.hud_party_collapsed = bool(party_collapsed_value) if typeof(party_collapsed_value) == TYPE_BOOL else false
		result.hud_alerts_collapsed = bool(alerts_collapsed_value) if typeof(alerts_collapsed_value) == TYPE_BOOL else false
	var drop_multiplier_value: Variant = config.get_value(SECTION, "personal_drop_multiplier_percent", 100)
	result.personal_drop_multiplier_percent = int(drop_multiplier_value) if typeof(drop_multiplier_value) == TYPE_INT else 100
	var force_drops_value: Variant = config.get_value(SECTION, "force_personal_drops", false)
	result.force_personal_drops = bool(force_drops_value) if typeof(force_drops_value) == TYPE_BOOL else false
	var source_override_value: Variant = config.get_value(SECTION, "personal_drop_source_category_override", &"")
	result.personal_drop_source_category_override = StringName(source_override_value) if typeof(source_override_value) in [TYPE_STRING, TYPE_STRING_NAME] else &""
	var item_level_override_value: Variant = config.get_value(SECTION, "personal_drop_item_level_override", 0)
	result.personal_drop_item_level_override = int(item_level_override_value) if typeof(item_level_override_value) == TYPE_INT else 0
	var diagnostics_value: Variant = config.get_value(SECTION, "show_ground_chest_diagnostics", false)
	result.show_ground_chest_diagnostics = bool(diagnostics_value) if typeof(diagnostics_value) == TYPE_BOOL else false
	var city_access_snapshot_value: Variant = config.get_value(SECTION, "use_city_access_snapshot", false)
	result.use_city_access_snapshot = bool(city_access_snapshot_value) if typeof(city_access_snapshot_value) == TYPE_BOOL else false
	result.normalize()
	return result

func save_settings(settings: PartyForgeSettings, path: String = DEFAULT_PATH) -> String:
	if settings == null:
		return "PARTY_FORGE_SETTINGS_SAVE_ERROR path=%s reason=settings is null" % path
	var normalized := settings.copy()
	normalized.normalize()
	var config := ConfigFile.new()
	config.set_value(SECTION, "schema_version", PartyForgeSettings.SCHEMA_VERSION)
	config.set_value(SECTION, "mode", normalized.mode)
	config.set_value(SECTION, "unlock_all_implemented_content", normalized.unlock_all_implemented_content)
	config.set_value(SECTION, "god_mode", normalized.god_mode)
	config.set_value(SECTION, "party_capacity_override", normalized.party_capacity_override)
	config.set_value(SECTION, "enemy_density_percent", normalized.enemy_density_percent)
	config.set_value(SECTION, "experience_multiplier_percent", normalized.experience_multiplier_percent)
	config.set_value(SECTION, "level_up_card_count", normalized.level_up_card_count)
	config.set_value(SECTION, "reduced_motion", normalized.reduced_motion)
	config.set_value(SECTION, "high_contrast", normalized.high_contrast)
	config.set_value(SECTION, "ui_scale_percent", normalized.ui_scale_percent)
	config.set_value(SECTION, "text_scale_percent", normalized.text_scale_percent)
	config.set_value(SECTION, "character_hud_background_opacity_percent", normalized.character_hud_background_opacity_percent)
	config.set_value(SECTION, "hud_party_collapsed", normalized.hud_party_collapsed)
	config.set_value(SECTION, "hud_alerts_collapsed", normalized.hud_alerts_collapsed)
	config.set_value(SECTION, "personal_drop_multiplier_percent", normalized.personal_drop_multiplier_percent)
	config.set_value(SECTION, "force_personal_drops", normalized.force_personal_drops)
	config.set_value(SECTION, "personal_drop_source_category_override", normalized.personal_drop_source_category_override)
	config.set_value(SECTION, "personal_drop_item_level_override", normalized.personal_drop_item_level_override)
	config.set_value(SECTION, "show_ground_chest_diagnostics", normalized.show_ground_chest_diagnostics)
	config.set_value(SECTION, "use_city_access_snapshot", normalized.use_city_access_snapshot)
	var temporary := "%s.tmp" % path
	var backup := "%s.bak" % path
	var save_error := config.save(temporary)
	if save_error != OK:
		return "PARTY_FORGE_SETTINGS_SAVE_ERROR path=%s code=%d" % [path, save_error]
	var absolute_target := ProjectSettings.globalize_path(path)
	var absolute_backup := ProjectSettings.globalize_path(backup)
	var had_previous := FileAccess.file_exists(path)
	if had_previous:
		DirAccess.remove_absolute(absolute_backup)
		var backup_error := DirAccess.rename_absolute(absolute_target, absolute_backup)
		if backup_error != OK:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
			return "PARTY_FORGE_SETTINGS_SAVE_ERROR path=%s code=%d stage=backup" % [path, backup_error]
	var promote_error: Error = _promote_file.call(temporary, path) if _promote_file.is_valid() else _promote(temporary, path)
	if promote_error != OK:
		var restore_error: Error = OK
		if had_previous:
			restore_error = DirAccess.rename_absolute(absolute_backup, absolute_target)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		if restore_error != OK:
			return "PARTY_FORGE_SETTINGS_SAVE_ERROR path=%s code=%d stage=restore promote_code=%d backup=%s" % [path, restore_error, promote_error, backup]
		return "PARTY_FORGE_SETTINGS_SAVE_ERROR path=%s code=%d stage=promote" % [path, promote_error]
	if had_previous:
		DirAccess.remove_absolute(absolute_backup)
	return ""

func _promote(temporary: String, target: String) -> Error:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(target))
