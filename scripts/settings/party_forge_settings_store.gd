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
	var version_value: Variant = config.get_value(SECTION, "schema_version", PartyForgeSettings.SCHEMA_VERSION)
	var loaded_version := int(version_value) if typeof(version_value) == TYPE_INT else -1
	if loaded_version != PartyForgeSettings.SCHEMA_VERSION:
		push_error("PARTY_FORGE_SETTINGS_VERSION_ERROR path=%s version=%d supported=%d" % [path, loaded_version, PartyForgeSettings.SCHEMA_VERSION])
		return result
	result.schema_version = loaded_version
	var mode_value: Variant = config.get_value(SECTION, "mode", PartyForgeSettings.Mode.PLAYER_SIMULATION)
	result.mode = int(mode_value) if typeof(mode_value) == TYPE_INT else PartyForgeSettings.Mode.PLAYER_SIMULATION
	var unlock_value: Variant = config.get_value(SECTION, "unlock_all_implemented_content", false)
	result.unlock_all_implemented_content = bool(unlock_value) if typeof(unlock_value) == TYPE_BOOL else false
	var god_value: Variant = config.get_value(SECTION, "god_mode", false)
	result.god_mode = bool(god_value) if typeof(god_value) == TYPE_BOOL else false
	var capacity_value: Variant = config.get_value(SECTION, "party_capacity_override", 4)
	result.party_capacity_override = int(capacity_value) if typeof(capacity_value) == TYPE_INT else 4
	var density_value: Variant = config.get_value(SECTION, "enemy_density_percent", 100)
	result.enemy_density_percent = int(density_value) if typeof(density_value) == TYPE_INT else 100
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
		if had_previous:
			DirAccess.rename_absolute(absolute_backup, absolute_target)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return "PARTY_FORGE_SETTINGS_SAVE_ERROR path=%s code=%d stage=promote" % [path, promote_error]
	if had_previous:
		DirAccess.remove_absolute(absolute_backup)
	return ""

func _promote(temporary: String, target: String) -> Error:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(target))
