class_name HealthBar3D
extends Node3D

@export var downed_color := Color(0.45, 0.45, 0.45)
var health_component: HealthComponent

func configure(health: HealthComponent) -> void:
	health_component = health
	refresh_presentation_anchor()
	_refresh()
	if health_component != null:
		if not health_component.health_changed.is_connected(_on_health_changed): health_component.health_changed.connect(_on_health_changed)
		if not health_component.downed.is_connected(_on_downed): health_component.downed.connect(_on_downed)
		if not health_component.revived.is_connected(_on_revived): health_component.revived.connect(_on_revived)

func refresh_presentation_anchor() -> void:
	var actor := get_parent()
	var presentation := actor.get_node_or_null("Presentation") as CharacterPresentation if actor != null else null
	if presentation == null or presentation.active_model == null:
		position.y = 1.35
		return
	var bounds := presentation.visual_bounds()
	position.y = maxf(1.35, bounds.position.y + bounds.size.y + 0.125)

func _on_health_changed(_current: float, _maximum: float) -> void:
	_refresh()

func _on_downed() -> void:
	var label := get_node("Label3D") as Label3D
	label.text = "DOWNED"
	label.modulate = downed_color

func _on_revived() -> void:
	_refresh()

func _refresh() -> void:
	if health_component == null:
		return
	var label := get_node("Label3D") as Label3D
	var fraction := health_component.current_health / maxf(health_component.max_health, 1.0)
	var filled := clampi(roundi(fraction * 10.0), 0, 10)
	label.text = "[" + "|".repeat(filled) + " ".repeat(10 - filled) + "]"
	label.modulate = Color(0.2, 1.0, 0.3)
