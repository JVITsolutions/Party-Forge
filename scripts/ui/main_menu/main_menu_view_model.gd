class_name MainMenuViewModel
extends RefCounted

const ROUTE_PROFILES: StringName = &"profiles"
const ROUTE_PROLOGUE_START: StringName = &"prologue_start"
const ROUTE_PROLOGUE_RESUME: StringName = &"prologue_resume"
const ROUTE_RUN_SETUP: StringName = &"run_setup"
const ROUTE_CITY_TREE: StringName = &"city_tree"
const ROUTE_DEVELOPER_QUICK_START: StringName = &"developer_quick_start"
const ROUTE_SETTINGS: StringName = &"settings"
const ROUTE_QUIT: StringName = &"quit"

const CITY_TREE_ID := "party-forge-city-v1"

static func build(profile: Variant, settings: Variant, city_tree_available: Variant) -> MainMenuProjection:
	var result := _safe_projection()
	var supplied_settings := settings as PartyForgeSettings if settings is PartyForgeSettings else null
	var settings_valid := _settings_are_valid(supplied_settings)
	result.reduced_motion = settings_valid and supplied_settings.reduced_motion

	var supplied_profile := profile as ProfileState if profile is ProfileState else null
	if not _profile_is_valid(supplied_profile):
		return result

	result.active_profile_text = "Active Profile: %s" % supplied_profile.display_name.strip_edges()
	match supplied_profile.prologue_state:
		ProfileState.PrologueState.NOT_STARTED:
			result.primary_label = "Play"
			result.primary_route_id = ROUTE_PROLOGUE_START
			result.status_text = "Begin your journey."
		ProfileState.PrologueState.IN_PROGRESS:
			result.primary_label = "Continue"
			result.primary_route_id = ROUTE_PROLOGUE_RESUME
			result.status_text = "Continue your journey."
		ProfileState.PrologueState.COMPLETED:
			result.primary_label = "Begin Run"
			result.primary_route_id = ROUTE_RUN_SETUP
			result.status_text = "Ready for your next run."

	var developer_mode := settings_valid and supplied_settings.mode == PartyForgeSettings.Mode.DEVELOPER_MODE
	var durable_city_access := (
		supplied_profile.prologue_state == ProfileState.PrologueState.COMPLETED
		and CITY_TREE_ID in supplied_profile.discovered_trees
	)
	result.city_tree_visible = developer_mode or durable_city_access
	result.city_tree_enabled = result.city_tree_visible and city_tree_available is bool and city_tree_available
	result.city_tree_label = "Developer City Preview" if developer_mode else "City Passive Tree"
	result.developer_quick_start_visible = developer_mode
	result.developer_quick_start_enabled = developer_mode
	if result.city_tree_visible and not result.city_tree_enabled:
		result.status_text = "City services are temporarily unavailable."
	return result

static func _safe_projection() -> MainMenuProjection:
	var result := MainMenuProjection.new()
	result.primary_label = "Play"
	result.primary_visible = true
	result.primary_enabled = true
	result.primary_route_id = ROUTE_PROFILES
	result.city_tree_label = "City Passive Tree"
	result.city_tree_route_id = ROUTE_CITY_TREE
	result.developer_quick_start_label = "Developer Quick Start"
	result.developer_quick_start_route_id = ROUTE_DEVELOPER_QUICK_START
	result.settings_label = "Settings"
	result.settings_visible = true
	result.settings_enabled = true
	result.settings_route_id = ROUTE_SETTINGS
	result.quit_label = "Quit"
	result.quit_visible = true
	result.quit_enabled = true
	result.quit_route_id = ROUTE_QUIT
	result.active_profile_text = "No active profile"
	result.status_text = "Create or choose a profile to play."
	return result

static func _profile_is_valid(profile: ProfileState) -> bool:
	return (
		profile != null
		and profile.schema_version == ProfileState.SCHEMA_VERSION
		and not profile.profile_id.strip_edges().is_empty()
		and not profile.display_name.strip_edges().is_empty()
		and profile.prologue_state in [
			ProfileState.PrologueState.NOT_STARTED,
			ProfileState.PrologueState.IN_PROGRESS,
			ProfileState.PrologueState.COMPLETED,
		]
	)

static func _settings_are_valid(settings: PartyForgeSettings) -> bool:
	return (
		settings != null
		and settings.schema_version == PartyForgeSettings.SCHEMA_VERSION
		and settings.mode in [
			PartyForgeSettings.Mode.PLAYER_SIMULATION,
			PartyForgeSettings.Mode.DEVELOPER_MODE,
		]
	)
