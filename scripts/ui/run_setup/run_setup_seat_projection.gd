class_name RunSetupSeatProjection
extends RefCounted

enum State { ACTIVE, COMING_SOON, JOINED, SELECTING, READY, DISCONNECTED }

var seat_number := 0
var label := ""
var state := State.COMING_SOON
var focusable := false

static func active(number: int, seat_label: String) -> RunSetupSeatProjection:
	var result := RunSetupSeatProjection.new()
	result.seat_number = number
	result.label = seat_label
	result.state = State.ACTIVE
	result.focusable = true
	return result

static func coming_soon(number: int) -> RunSetupSeatProjection:
	var result := RunSetupSeatProjection.new()
	result.seat_number = number
	result.label = "P%d - Coming Soon" % number
	result.state = State.COMING_SOON
	return result

func copy() -> RunSetupSeatProjection:
	var result := RunSetupSeatProjection.new()
	result.seat_number = seat_number
	result.label = label
	result.state = state
	result.focusable = focusable
	return result
