class_name RunRulesSnapshot
extends RefCounted

const PRODUCTION_PARTY_CAPACITY := 4

var _developer_mode_active := false
var _unlock_all := false
var _god_mode := false
var _party_capacity := PRODUCTION_PARTY_CAPACITY
var _enemy_density_percent := 100
var _experience_multiplier_percent := 100
var _level_up_card_count := 5
var _reduced_motion := false
var _personal_drop_multiplier_percent := 100
var _force_personal_drops := false
var _personal_drop_source_category_override: StringName = &""
var _personal_drop_item_level_override := 0
var _show_ground_chest_diagnostics := false

static func from_settings(settings: PartyForgeSettings) -> RunRulesSnapshot:
	var result := RunRulesSnapshot.new()
	if settings == null:
		push_error("PARTY_FORGE_RUN_RULES_ERROR reason=settings snapshot source is missing")
	var normalized := settings.copy() if settings != null else PartyForgeSettings.new()
	normalized.normalize()
	result._developer_mode_active = normalized.mode == PartyForgeSettings.Mode.DEVELOPER_MODE
	result._reduced_motion = normalized.reduced_motion
	if result._developer_mode_active:
		result._unlock_all = normalized.unlock_all_implemented_content
		result._god_mode = normalized.god_mode
		result._party_capacity = normalized.party_capacity_override
		result._enemy_density_percent = normalized.enemy_density_percent
		result._experience_multiplier_percent = normalized.experience_multiplier_percent
		result._level_up_card_count = normalized.level_up_card_count
		result._personal_drop_multiplier_percent = normalized.personal_drop_multiplier_percent
		result._force_personal_drops = normalized.force_personal_drops
		result._personal_drop_source_category_override = normalized.personal_drop_source_category_override
		result._personal_drop_item_level_override = normalized.personal_drop_item_level_override
		result._show_ground_chest_diagnostics = normalized.show_ground_chest_diagnostics
	return result

func developer_mode_active() -> bool: return _developer_mode_active
func unlock_all_implemented_content() -> bool: return _unlock_all
func god_mode() -> bool: return _god_mode
func party_capacity() -> int: return _party_capacity
func enemy_density_percent() -> int: return _enemy_density_percent
func experience_multiplier_percent() -> int: return _experience_multiplier_percent
func level_up_card_count() -> int: return _level_up_card_count
func reduced_motion() -> bool: return _reduced_motion
func personal_drop_multiplier_percent() -> int: return _personal_drop_multiplier_percent
func force_personal_drops() -> bool: return _force_personal_drops
func personal_drop_source_category_override() -> StringName: return _personal_drop_source_category_override
func personal_drop_item_level_override() -> int: return _personal_drop_item_level_override
func show_ground_chest_diagnostics() -> bool: return _show_ground_chest_diagnostics
func feature_policy(known_features: Array[StringName] = [], known_unlocks: Array[StringName] = [], unlocked: Array[StringName] = []) -> FeatureAccessPolicy:
	return FeatureAccessPolicy.new(_developer_mode_active, _unlock_all, known_features, known_unlocks, unlocked)
func capacity_policy() -> PartyCapacityPolicy: return PartyCapacityPolicy.new(_party_capacity)
func combat_policy() -> CombatTestPolicy: return CombatTestPolicy.new(_god_mode, _enemy_density_percent, _developer_mode_active, _unlock_all, _party_capacity)
