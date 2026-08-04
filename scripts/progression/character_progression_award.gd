class_name CharacterProgressionAward
extends RefCounted

var next_state: CharacterProgressionState
var gained_levels: Array[int] = []
var attribute_delta: Dictionary = {}
var milestone_outcomes: Dictionary = {}
var error := ""

func ok() -> bool:
	return next_state != null and error.is_empty()

static func failure(detail: String) -> CharacterProgressionAward:
	var result := CharacterProgressionAward.new()
	result.error = "PARTY_FORGE_PROGRESSION_ERROR reason=%s" % detail
	return result
