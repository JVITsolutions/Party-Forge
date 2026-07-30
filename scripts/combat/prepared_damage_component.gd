class_name PreparedDamageComponent
extends RefCounted

var damage_type_id: StringName
var authored_amount := 0.0
var global_scaled := 0.0
var typed_scaled := 0.0
var post_crit := 0.0

func _init(type_id: StringName = &"", authored: float = 0.0, global_amount: float = 0.0, typed_amount: float = 0.0, critical_amount: float = 0.0) -> void:
	damage_type_id = type_id
	authored_amount = authored
	global_scaled = global_amount
	typed_scaled = typed_amount
	post_crit = critical_amount

func copy() -> PreparedDamageComponent:
	return PreparedDamageComponent.new(damage_type_id, authored_amount, global_scaled, typed_scaled, post_crit)
