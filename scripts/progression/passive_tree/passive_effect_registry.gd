class_name PassiveEffectRegistry
extends RefCounted

const ERROR_PREFIX := "PARTY_FORGE_PASSIVE_EFFECT_ERROR"
const SIGNED_64_MIN_AS_FLOAT := -9223372036854775808.0
const SIGNED_64_MAX_EXCLUSIVE_AS_FLOAT := 9223372036854775808.0

const CONTRACTS := {
	&"city_service_unlock": {"operation": &"set", "value_type": TYPE_BOOL, "parameters": ["serviceId"]},
	&"experience_gain": {"operation": &"add_percent", "value_type": TYPE_INT, "parameters": ["scope"]},
	&"feature_unlock": {"operation": &"set", "value_type": TYPE_BOOL, "parameters": ["featureId"]},
	&"mode_unlock": {"operation": &"set", "value_type": TYPE_BOOL, "parameters": ["modeId"]},
	&"party_capacity": {"operation": &"add_flat", "value_type": TYPE_INT, "parameters": ["scope"]},
	&"region_unlock": {"operation": &"set", "value_type": TYPE_BOOL, "parameters": ["regionId"]},
	&"vendor_inventory_slots": {"operation": &"add_flat", "value_type": TYPE_INT, "parameters": ["scope"]},
	&"vendor_reroll_count": {"operation": &"add_flat", "value_type": TYPE_INT, "parameters": ["scope"]},
	&"building_discovery": {"operation": &"set", "value_type": TYPE_BOOL, "parameters": ["buildingId"]},
	&"extraction_capacity": {"operation": &"add_flat", "value_type": TYPE_INT, "parameters": ["scope"]},
	&"inventory_columns": {"operation": &"add_flat", "value_type": TYPE_INT, "parameters": ["scope"]},
	&"stash_tabs": {"operation": &"add_flat", "value_type": TYPE_INT, "parameters": ["scope", "slotsPerTab"]},
	&"tree_discovery": {"operation": &"set", "value_type": TYPE_BOOL, "parameters": ["treeId"]},
}

const PROFILE_SCOPE_EFFECTS: Array[StringName] = [
	&"party_capacity", &"vendor_inventory_slots", &"vendor_reroll_count",
	&"extraction_capacity", &"inventory_columns", &"stash_tabs",
]

const PERMANENT_EFFECTS: Array[StringName] = [
	&"city_service_unlock", &"feature_unlock", &"mode_unlock", &"region_unlock",
	&"building_discovery", &"extraction_capacity", &"inventory_columns",
	&"stash_tabs", &"tree_discovery",
]

func validate(effect: PassiveTreeEffect) -> String:
	if effect == null:
		return "%s effect=null reason=effect must not be null" % ERROR_PREFIX
	if not CONTRACTS.has(effect.effect_id):
		return "%s effect=%s reason=unknown effect ID" % [ERROR_PREFIX, effect.effect_id]
	var contract: Dictionary = CONTRACTS[effect.effect_id]
	if effect.operation != contract["operation"]:
		return "%s effect=%s reason=operation must equal %s" % [ERROR_PREFIX, effect.effect_id, contract["operation"]]
	var expected_type: int = contract["value_type"]
	if expected_type == TYPE_INT and not _is_json_integer(effect.value):
		return "%s effect=%s reason=value must be an integer" % [ERROR_PREFIX, effect.effect_id]
	if expected_type != TYPE_INT and typeof(effect.value) != expected_type:
		var expected_name := "integer" if expected_type == TYPE_INT else "boolean"
		return "%s effect=%s reason=value must be a %s" % [ERROR_PREFIX, effect.effect_id, expected_name]
	var parameter_names: Array = contract["parameters"]
	var shape_error := _validate_parameter_shape(effect.effect_id, effect.parameters, parameter_names)
	if not shape_error.is_empty():
		return shape_error
	if effect.effect_id == &"experience_gain":
		if effect.parameters["scope"] != "all_run_experience":
			return "%s effect=%s parameter=scope reason=scope must equal all_run_experience" % [ERROR_PREFIX, effect.effect_id]
	elif effect.effect_id in PROFILE_SCOPE_EFFECTS:
		if effect.parameters["scope"] != "profile":
			return "%s effect=%s parameter=scope reason=scope must equal profile" % [ERROR_PREFIX, effect.effect_id]
	if effect.effect_id == &"stash_tabs":
		if not _is_json_integer(effect.parameters["slotsPerTab"]) or float(effect.parameters["slotsPerTab"]) <= 0.0:
			return "%s effect=%s parameter=slotsPerTab reason=slotsPerTab must be a positive integer" % [ERROR_PREFIX, effect.effect_id]
	for identifier_key: String in ["serviceId", "featureId", "modeId", "regionId", "buildingId", "treeId"]:
		if effect.parameters.has(identifier_key) and not _is_stable_identifier(effect.parameters[identifier_key]):
			return "%s effect=%s parameter=%s reason=%s must be a non-empty stable lowercase ID" % [ERROR_PREFIX, effect.effect_id, identifier_key, identifier_key]
	return ""

func development_state(effect_id: StringName) -> int:
	return FeatureAccessPolicy.State.COMING_SOON if CONTRACTS.has(effect_id) else FeatureAccessPolicy.State.HIDDEN

func is_permanent(effect: PassiveTreeEffect) -> bool:
	return effect != null and validate(effect).is_empty() and effect.effect_id in PERMANENT_EFFECTS

func unlock_id(effect: PassiveTreeEffect) -> StringName:
	if effect == null or not validate(effect).is_empty():
		return &""
	match effect.effect_id:
		&"feature_unlock":
			return StringName(effect.parameters["featureId"])
		&"mode_unlock":
			return StringName("mode:%s" % effect.parameters["modeId"])
		&"city_service_unlock":
			return StringName("service:%s" % effect.parameters["serviceId"])
		&"region_unlock":
			return StringName("region:%s" % effect.parameters["regionId"])
		_:
			return &""

func _validate_parameter_shape(effect_id: StringName, parameters: Dictionary, expected: Array) -> String:
	if parameters.size() != expected.size():
		return "%s effect=%s reason=parameters must contain exactly {%s}" % [ERROR_PREFIX, effect_id, ",".join(expected)]
	for parameter: String in expected:
		if not parameters.has(parameter):
			return "%s effect=%s parameter=%s reason=parameters must contain exactly {%s}" % [ERROR_PREFIX, effect_id, parameter, ",".join(expected)]
	return ""

func _is_stable_identifier(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var text := value as String
	if text.is_empty() or text != text.strip_edges():
		return false
	for index: int in text.length():
		var code := text.unicode_at(index)
		if not ((code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 45 or code == 95):
			return false
	return text.unicode_at(0) != 45 and text.unicode_at(0) != 95 \
		and text.unicode_at(text.length() - 1) != 45 and text.unicode_at(text.length() - 1) != 95

func _is_json_integer(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) != TYPE_FLOAT:
		return false
	var number := value as float
	return not is_nan(number) and not is_inf(number) and number == floorf(number) \
		and number >= SIGNED_64_MIN_AS_FLOAT and number < SIGNED_64_MAX_EXCLUSIVE_AS_FLOAT
