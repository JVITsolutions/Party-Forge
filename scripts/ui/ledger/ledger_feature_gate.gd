class_name LedgerFeatureGate
extends RefCounted

var policy: FeatureAccessPolicy
var known_feature_ids: Array[StringName] = []
var known_unlock_ids: Array[StringName] = []

func _init(
	feature_policy: FeatureAccessPolicy,
	supported_features: Array[StringName] = [],
	supported_unlocks: Array[StringName] = []
) -> void:
	policy = feature_policy
	known_feature_ids = supported_features.duplicate()
	known_unlock_ids = supported_unlocks.duplicate()

func resolve(definition: LedgerPageDefinition) -> LedgerPageDefinition.State:
	if definition == null:
		return LedgerPageDefinition.State.HIDDEN
	if not definition.feature_id.is_empty() and definition.feature_id not in known_feature_ids:
		push_error("PARTY_FORGE_LEDGER_ERROR page=%s reason=unknown feature %s" % [definition.id, definition.feature_id])
		return LedgerPageDefinition.State.HIDDEN
	if not definition.unlock_id.is_empty() and definition.unlock_id not in known_unlock_ids:
		push_error("PARTY_FORGE_LEDGER_ERROR page=%s reason=unknown unlock %s" % [definition.id, definition.unlock_id])
		return LedgerPageDefinition.State.HIDDEN
	if policy == null:
		return LedgerPageDefinition.State.HIDDEN
	var resolved := policy.resolve(definition.feature_id, definition.development_state, definition.unlock_id)
	return resolved as LedgerPageDefinition.State
