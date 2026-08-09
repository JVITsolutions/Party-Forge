class_name ItemGenerationFailure
extends RefCounted

var stage: StringName
var code: StringName
var source_id: StringName
var seed := 0
var generation_sequence := 0
var details: Dictionary = {}

func message() -> String:
	return "PARTY_FORGE_ITEM_GENERATION_ERROR stage=%s code=%s source=%s seed=%d sequence=%d" % [stage, code, source_id, seed, generation_sequence]
