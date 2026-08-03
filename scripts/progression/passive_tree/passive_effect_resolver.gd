class_name PassiveEffectResolver
extends RefCounted

const SIGNED_64_MIN := -9223372036854775807 - 1
const SIGNED_64_MAX := 9223372036854775807
const EXPLICIT_SCOPES: Array[StringName] = [
	&"personal", &"owned_characters", &"party", &"world", &"profile", &"all_run_experience",
]

var _registry: PassiveEffectRegistry

func _init(registry: PassiveEffectRegistry) -> void:
	_registry = registry

func resolve(tree: PassiveTreeDefinition, allocated_ids: Array[StringName]) -> PassiveEffectResolution:
	if tree == null or _registry == null:
		return PassiveEffectResolution.new()
	var flat_values: Dictionary = {}
	var percent_values: Dictionary = {}
	var set_members: Dictionary = {}
	var permanent_unlocks: Dictionary = {}
	var buildings: Dictionary = {}
	var trees: Dictionary = {}
	var stash_contract_counts: Dictionary = {}
	var feature_states: Dictionary = {}

	for allocated_id: StringName in _canonical_allocations(allocated_ids):
		var tree_node := tree.node(allocated_id)
		if tree_node == null:
			continue
		var effects: Array[PassiveTreeEffect] = []
		effects.assign(tree_node.effects)
		effects.sort_custom(func(left: PassiveTreeEffect, right: PassiveTreeEffect) -> bool:
			return _effect_sort_key(left) < _effect_sort_key(right)
		)
		for effect: PassiveTreeEffect in effects:
			if not _registry.validate(effect).is_empty():
				continue
			match effect.operation:
				&"add_flat":
					_resolve_flat(effect, flat_values, stash_contract_counts)
				&"add_percent":
					_resolve_numeric(effect, percent_values)
				&"set":
					_resolve_set(effect, set_members, permanent_unlocks, buildings, trees, feature_states)

	return PassiveEffectResolution.new(
		_nested_values(flat_values),
		_nested_values(percent_values),
		_set_values(set_members),
		_sorted_ids(permanent_unlocks),
		_sorted_ids(buildings),
		_sorted_ids(trees),
		_stash_contracts(stash_contract_counts),
		feature_states,
	)

func _resolve_flat(effect: PassiveTreeEffect, values: Dictionary, stash_contract_counts: Dictionary) -> void:
	var scope := _validated_scope(effect)
	if scope.is_empty():
		return
	var value := int(effect.value)
	var key := _numeric_key(effect.effect_id, scope)
	var current := int(values.get(key, 0))
	if effect.effect_id != &"stash_tabs":
		if _can_add(current, value):
			values[key] = current + value
		return
	var slots_per_tab := int(effect.parameters["slotsPerTab"])
	var contract_key := "%s|%d" % [scope, slots_per_tab]
	var current_contract_count := int(stash_contract_counts.get(contract_key, 0))
	if not _can_add(current, value) or not _can_add(current_contract_count, value):
		return
	values[key] = current + value
	stash_contract_counts[contract_key] = current_contract_count + value

func _resolve_numeric(effect: PassiveTreeEffect, values: Dictionary) -> void:
	var scope := _validated_scope(effect)
	if scope.is_empty():
		return
	var key := _numeric_key(effect.effect_id, scope)
	var current := int(values.get(key, 0))
	var value := int(effect.value)
	if _can_add(current, value):
		values[key] = current + value

func _resolve_set(
	effect: PassiveTreeEffect,
	set_members: Dictionary,
	permanent_unlocks: Dictionary,
	buildings: Dictionary,
	trees: Dictionary,
	feature_states: Dictionary,
) -> void:
	if effect.value != true:
		return
	var value := _set_value(effect)
	if value.is_empty():
		return
	var effect_members := set_members.get_or_add(effect.effect_id, {}) as Dictionary
	effect_members[value] = true
	var unlock_id := _registry.unlock_id(effect)
	if not unlock_id.is_empty():
		if _registry.is_permanent(effect):
			permanent_unlocks[unlock_id] = true
		feature_states[unlock_id] = _registry.development_state(effect.effect_id)
	match effect.effect_id:
		&"building_discovery": buildings[value] = true
		&"tree_discovery": trees[value] = true

func _set_value(effect: PassiveTreeEffect) -> StringName:
	var unlock_id := _registry.unlock_id(effect)
	if not unlock_id.is_empty():
		return unlock_id
	match effect.effect_id:
		&"building_discovery": return StringName(effect.parameters["buildingId"])
		&"tree_discovery": return StringName(effect.parameters["treeId"])
		_: return &""

func _validated_scope(effect: PassiveTreeEffect) -> StringName:
	if not effect.parameters.has("scope") or typeof(effect.parameters["scope"]) != TYPE_STRING:
		return &""
	var scope := StringName(effect.parameters["scope"])
	return scope if scope in EXPLICIT_SCOPES else &""

func _canonical_allocations(allocated_ids: Array[StringName]) -> Array[StringName]:
	var seen: Dictionary = {}
	var lexical_ids: Array[String] = []
	for allocated_id: StringName in allocated_ids:
		var text := String(allocated_id)
		if seen.has(text):
			continue
		seen[text] = true
		lexical_ids.append(text)
	lexical_ids.sort()
	var result: Array[StringName] = []
	for text: String in lexical_ids:
		result.append(StringName(text))
	return result

func _effect_sort_key(effect: PassiveTreeEffect) -> String:
	if effect == null:
		return ""
	var parameter_keys: Array[String] = []
	for key: Variant in effect.parameters.keys():
		parameter_keys.append(String(key))
	parameter_keys.sort()
	var canonical_parameters: Array[String] = []
	for key: String in parameter_keys:
		var value: Variant = effect.parameters[key]
		canonical_parameters.append("%s=%d:%s" % [key, typeof(value), str(value)])
	return "%s|%s|operation=%s|value=%d:%s" % [
		effect.effect_id,
		"|".join(canonical_parameters),
		effect.operation,
		typeof(effect.value),
		str(effect.value),
	]

func _numeric_key(effect_id: StringName, scope: StringName) -> String:
	return "%s|%s" % [effect_id, scope]

func _can_add(current: int, value: int) -> bool:
	if value > 0:
		return current <= SIGNED_64_MAX - value
	if value < 0:
		return current >= SIGNED_64_MIN - value
	return true

func _nested_values(values: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var keys: Array[String] = []
	for key: Variant in values.keys():
		keys.append(String(key))
	keys.sort()
	for key: String in keys:
		var separator := key.find("|")
		var effect_id := StringName(key.left(separator))
		var scope := StringName(key.substr(separator + 1))
		var scoped := result.get_or_add(effect_id, {}) as Dictionary
		scoped[scope] = values[key]
	return result

func _set_values(set_members: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var effect_ids: Array[String] = []
	for effect_id: Variant in set_members.keys():
		effect_ids.append(String(effect_id))
	effect_ids.sort()
	for effect_id_text: String in effect_ids:
		var effect_id := StringName(effect_id_text)
		result[effect_id] = _sorted_ids(set_members[effect_id] as Dictionary)
	return result

func _sorted_ids(members: Dictionary) -> Array[StringName]:
	var texts: Array[String] = []
	for member: Variant in members.keys():
		texts.append(String(member))
	texts.sort()
	var result: Array[StringName] = []
	for text: String in texts:
		result.append(StringName(text))
	return result

func _stash_contracts(counts: Dictionary) -> Array[Dictionary]:
	var keys: Array[String] = []
	for key: Variant in counts.keys():
		keys.append(String(key))
	keys.sort()
	var result: Array[Dictionary] = []
	for key: String in keys:
		var separator := key.rfind("|")
		result.append({
			"count": counts[key],
			"scope": StringName(key.left(separator)),
			"slotsPerTab": int(key.substr(separator + 1)),
		})
	return result
