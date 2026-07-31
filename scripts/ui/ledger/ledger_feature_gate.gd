class_name LedgerFeatureGate
extends RefCounted

var expose_developer_preview := false
var known_feature_ids: Array[StringName] = []
var known_unlock_ids: Array[StringName] = []

func _init(
	developer_access := false,
	supported_features: Array[StringName] = [],
	supported_unlocks: Array[StringName] = []
) -> void:
	expose_developer_preview = developer_access
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
	if definition.development_state == LedgerPageDefinition.State.DEVELOPER_PREVIEW:
		return LedgerPageDefinition.State.AVAILABLE if expose_developer_preview else LedgerPageDefinition.State.HIDDEN
	return definition.development_state
