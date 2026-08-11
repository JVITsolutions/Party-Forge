class_name PlayerOwnerMarker3D
extends Node3D

var player_number := 0
var owner_color := Color.WHITE


func bind(player_number_value: int, owner_color_value: Color) -> void:
	player_number = clampi(player_number_value, 1, LocalPlayerIdentityService.MAX_LOCAL_PLAYERS)
	owner_color = owner_color_value
	var pennant := get_node("Pennant") as Label3D
	var label := get_node("OwnerLabel") as Label3D
	pennant.text = "▼"
	pennant.modulate = owner_color
	pennant.outline_modulate = Color(0.04, 0.05, 0.07, 1.0)
	label.text = "P%d" % player_number
	label.modulate = Color.WHITE
	label.outline_modulate = Color(0.02, 0.025, 0.035, 1.0)
	pennant.visible = true
	label.visible = true
