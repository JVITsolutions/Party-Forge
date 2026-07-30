class_name StatUpgradeEffect
extends UpgradeEffectDefinition

@export var stat_id: StringName
@export var operation := StatModifier.Operation.FLAT
@export var value_per_rank := 0.0
@export var rank_values: Array[float] = []
@export var required_capability_tags: Array[StringName] = []
@export var excluded_capability_tags: Array[StringName] = []
@export var required_action_tags: Array[StringName] = []
@export var excluded_action_tags: Array[StringName] = []
@export var source_label: String

func value_for_rank(rank: int) -> float:
	if rank <= 0:
		return 0.0
	if rank <= rank_values.size():
		return rank_values[rank - 1]
	return value_per_rank
