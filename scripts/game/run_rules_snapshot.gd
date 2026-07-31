class_name RunRulesSnapshot
extends RefCounted

const PRODUCTION_PARTY_CAPACITY := 4

var _developer_mode_active := false
var _unlock_all := false
var _god_mode := false
var _party_capacity := PRODUCTION_PARTY_CAPACITY
var _enemy_density_percent := 100

static func from_settings(settings: PartyForgeSettings) -> RunRulesSnapshot:
	var result := RunRulesSnapshot.new()
	if settings == null:
		push_error("PARTY_FORGE_RUN_RULES_ERROR reason=settings snapshot source is missing")
	var normalized := settings.copy() if settings != null else PartyForgeSettings.new()
	normalized.normalize()
	result._developer_mode_active = normalized.mode == PartyForgeSettings.Mode.DEVELOPER_MODE
	if result._developer_mode_active:
		result._unlock_all = normalized.unlock_all_implemented_content
		result._god_mode = normalized.god_mode
		result._party_capacity = normalized.party_capacity_override
		result._enemy_density_percent = normalized.enemy_density_percent
	return result

func developer_mode_active() -> bool: return _developer_mode_active
func unlock_all_implemented_content() -> bool: return _unlock_all
func god_mode() -> bool: return _god_mode
func party_capacity() -> int: return _party_capacity
func enemy_density_percent() -> int: return _enemy_density_percent
func feature_policy(known_features: Array[StringName] = [], known_unlocks: Array[StringName] = [], unlocked: Array[StringName] = []) -> FeatureAccessPolicy:
	return FeatureAccessPolicy.new(_developer_mode_active, _unlock_all, known_features, known_unlocks, unlocked)
func capacity_policy() -> PartyCapacityPolicy: return PartyCapacityPolicy.new(_party_capacity)
func combat_policy() -> CombatTestPolicy: return CombatTestPolicy.new(_god_mode, _enemy_density_percent, _developer_mode_active, _unlock_all, _party_capacity)
