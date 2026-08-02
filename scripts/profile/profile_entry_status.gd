class_name ProfileEntryStatus
extends RefCounted

enum State { HEALTHY, RECOVERED, DAMAGED }

var state := State.HEALTHY
var error := ""
var recovered := false
var profile_id := ""
var display_name := ""

static func from_profile(profile: ProfileState, was_recovered: bool = false, detail: String = "") -> ProfileEntryStatus:
	var result := ProfileEntryStatus.new()
	result.state = State.RECOVERED if was_recovered else State.HEALTHY
	result.recovered = was_recovered
	result.profile_id = profile.profile_id
	result.display_name = profile.display_name
	result.error = detail
	return result

static func damaged(id: String, detail: String) -> ProfileEntryStatus:
	var result := ProfileEntryStatus.new()
	result.state = State.DAMAGED
	result.profile_id = id
	result.display_name = id
	result.error = detail
	return result

func selectable() -> bool:
	return state != State.DAMAGED

func state_name() -> String:
	match state:
		State.RECOVERED:
			return "recovered"
		State.DAMAGED:
			return "damaged"
		_:
			return "healthy"

func copy() -> ProfileEntryStatus:
	var result := ProfileEntryStatus.new()
	result.state = state
	result.error = error
	result.recovered = recovered
	result.profile_id = profile_id
	result.display_name = display_name
	return result
