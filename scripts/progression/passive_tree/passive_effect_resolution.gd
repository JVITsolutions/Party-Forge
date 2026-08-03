class_name PassiveEffectResolution
extends RefCounted

var _flat_values: Dictionary = {}
var _percent_values: Dictionary = {}
var _set_values: Dictionary = {}
var _permanent_unlock_ids: Array[StringName] = []
var _building_discoveries: Array[StringName] = []
var _tree_discoveries: Array[StringName] = []
var _stash_tab_contracts: Array[Dictionary] = []
var _feature_states: Dictionary = {}

func _init(
	p_flat_values: Dictionary = {},
	p_percent_values: Dictionary = {},
	p_set_values: Dictionary = {},
	p_permanent_unlock_ids: Array[StringName] = [],
	p_building_discoveries: Array[StringName] = [],
	p_tree_discoveries: Array[StringName] = [],
	p_stash_tab_contracts: Array[Dictionary] = [],
	p_feature_states: Dictionary = {},
) -> void:
	_flat_values = p_flat_values.duplicate(true)
	_percent_values = p_percent_values.duplicate(true)
	_set_values = p_set_values.duplicate(true)
	_permanent_unlock_ids.assign(p_permanent_unlock_ids)
	_building_discoveries.assign(p_building_discoveries)
	_tree_discoveries.assign(p_tree_discoveries)
	for contract: Dictionary in p_stash_tab_contracts:
		_stash_tab_contracts.append(contract.duplicate(true))
	_feature_states = p_feature_states.duplicate(true)

func flat_value(effect_id: StringName, scope: StringName) -> int:
	var scoped := _flat_values.get(effect_id, {}) as Dictionary
	return int(scoped.get(scope, 0))

func flat_values() -> Dictionary:
	return _flat_values.duplicate(true)

func percent_value(effect_id: StringName, scope: StringName) -> int:
	var scoped := _percent_values.get(effect_id, {}) as Dictionary
	return int(scoped.get(scope, 0))

func percent_values() -> Dictionary:
	return _percent_values.duplicate(true)

func set_values(effect_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_set_values.get(effect_id, []))
	return result

func has_set_value(effect_id: StringName, value: StringName) -> bool:
	return value in (_set_values.get(effect_id, []) as Array)

func permanent_unlock_ids() -> Array[StringName]:
	return _permanent_unlock_ids.duplicate()

func building_discoveries() -> Array[StringName]:
	return _building_discoveries.duplicate()

func tree_discoveries() -> Array[StringName]:
	return _tree_discoveries.duplicate()

func stash_tab_contracts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for contract: Dictionary in _stash_tab_contracts:
		result.append(contract.duplicate(true))
	return result

func feature_state(feature_id: StringName) -> int:
	return int(_feature_states.get(feature_id, FeatureAccessPolicy.State.HIDDEN))

func feature_states() -> Dictionary:
	return _feature_states.duplicate(true)
