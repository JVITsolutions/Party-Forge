class_name RunSetupLobbyProjection
extends RefCounted

enum State { NO_SELECTION, CHECKING, READY, NEEDS_ATTENTION, UNAVAILABLE, STARTING, ERROR }

var _seats: Array[RunSetupSeatProjection] = []
var _classes: Array[RunSetupClassProjection] = []
var selected_class_id: StringName = &""
var previewed_class_id: StringName = &""
var state := State.NO_SELECTION
var status_copy := ""

var seats: Array[RunSetupSeatProjection]:
	get:
		var result: Array[RunSetupSeatProjection] = []
		for seat: RunSetupSeatProjection in _seats:
			result.append(seat.copy())
		return result

var classes: Array[RunSetupClassProjection]:
	get:
		var result: Array[RunSetupClassProjection] = []
		for class_projection: RunSetupClassProjection in _classes:
			result.append(class_projection.copy())
		return result

static func create(
	seat_values: Array[RunSetupSeatProjection],
	class_values: Array[RunSetupClassProjection],
	selected_id: StringName,
	previewed_id: StringName,
	lobby_state: State,
	player_status_copy: String,
) -> RunSetupLobbyProjection:
	var result := RunSetupLobbyProjection.new()
	for seat: RunSetupSeatProjection in seat_values:
		if seat != null:
			result._seats.append(seat.copy())
	for class_projection: RunSetupClassProjection in class_values:
		if class_projection != null:
			result._classes.append(class_projection.copy())
	result.selected_class_id = selected_id
	result.previewed_class_id = previewed_id
	result.state = lobby_state
	result.status_copy = player_status_copy
	return result

func copy() -> RunSetupLobbyProjection:
	return create(_seats, _classes, selected_class_id, previewed_class_id, state, status_copy)
