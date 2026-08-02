class_name AttackSequenceController
extends Node

signal sequence_error(message: String)

var owner_actor: PartyActor
var presentation: Node
var executor: Node
var active_definition: AttackDefinition
var active_presentation: AttackPresentationDefinition
var locked_target: CombatTarget
var active_token := 0
var next_token := 1
var released := false
var elapsed_scaled := 0.0
var locked_range_multiplier := 1.0

func configure(actor: PartyActor, visual: Node, attack_executor: Node) -> void:
	_disconnect_presentation()
	owner_actor = actor
	presentation = visual
	executor = attack_executor
	if presentation != null and presentation.has_signal(&"attack_event"):
		presentation.connect(&"attack_event", _on_attack_event)
	if presentation != null and presentation.has_signal(&"attack_finished"):
		presentation.connect(&"attack_finished", _on_attack_finished)

func request(definition: AttackDefinition, target: CombatTarget, visual: AttackPresentationDefinition, playback_rate: float, range_multiplier: float) -> int:
	if is_busy() or definition == null or target == null or visual == null or not is_finite(playback_rate) or playback_rate <= 0.0 or not is_finite(range_multiplier) or range_multiplier <= 0.0:
		return 0
	var validation_errors := visual.validate(definition)
	if not validation_errors.is_empty():
		_sequence_error(0, visual.action_id, validation_errors[0])
		return 0
	if presentation == null or executor == null or not presentation.has_method(&"start_attack"):
		_sequence_error(0, visual.action_id, "sequence dependencies are incomplete")
		return 0
	active_token = next_token
	next_token += 1
	active_definition = definition
	active_presentation = visual
	locked_target = target
	released = false
	elapsed_scaled = 0.0
	locked_range_multiplier = range_multiplier
	if not bool(presentation.call(&"start_attack", definition, target, visual, active_token, playback_rate)):
		var failed_token := active_token
		_clear_active()
		_sequence_error(failed_token, visual.action_id, "action failed to start", definition.id)
		return 0
	return active_token

func advance(delta: float) -> void:
	if not is_busy():
		return
	var playback_rate := 1.0
	if presentation != null and presentation.has_method(&"action_playback_rate"):
		playback_rate = maxf(float(presentation.call(&"action_playback_rate")), 0.001)
	elapsed_scaled += maxf(delta, 0.0) * playback_rate
	if elapsed_scaled > active_presentation.action_duration + 0.05:
		cancel("missing required event %s" % active_presentation.required_event_name)

func is_busy() -> bool:
	return active_token > 0

func cancel(reason: String) -> void:
	if not is_busy():
		return
	var token := active_token
	var action_id := active_presentation.action_id if active_presentation != null else &"<missing>"
	var attack_id := active_definition.id if active_definition != null else &"<missing>"
	_clear_active()
	_sequence_error(token, action_id, reason, attack_id)
	_return_to_locomotion()

func _on_attack_event(token: int, action_id: StringName, event_name: StringName) -> void:
	if token != active_token:
		_sequence_error(token, action_id, "stale event")
		return
	if released:
		_sequence_error(token, action_id, "duplicate event")
		return
	if active_presentation == null or action_id != active_presentation.action_id or event_name != active_presentation.required_event_name:
		return
	var refreshed := _revalidate_locked_target()
	if refreshed == null:
		cancel("target invalid at release")
		return
	if _owner_is_downed():
		cancel("owner downed at release")
		return
	released = true
	executor.call(&"execute", active_definition, refreshed, active_presentation)

func _on_attack_finished(token: int, action_id: StringName) -> void:
	if token != active_token:
		_sequence_error(token, action_id, "stale finish")
		return
	if active_presentation == null or action_id != active_presentation.action_id:
		return
	if not released:
		cancel("missing required event %s" % active_presentation.required_event_name)
		return
	_clear_active()
	_return_to_locomotion()

func _revalidate_locked_target() -> CombatTarget:
	if owner_actor == null or active_definition == null or locked_target == null or locked_target.actor == null or not is_instance_valid(locked_target.actor) or not locked_target.actor.has_method(&"get_combat_target"):
		return null
	var current := locked_target.actor.call(&"get_combat_target") as CombatTarget
	if current == null or current.actor != locked_target.actor or not current.is_available:
		return null
	var expects_ally := active_definition.kind == AttackDefinition.Kind.HEAL
	if (current.team_id == owner_actor.team_id) != expects_ally:
		return null
	var origin := owner_actor.global_position if owner_actor.is_inside_tree() else owner_actor.position
	var geometry := ResolvedAttackGeometry.from_attack(active_definition, locked_range_multiplier, 1.0)
	return current if origin.distance_squared_to(current.position) <= geometry.range * geometry.range else null

func _owner_is_downed() -> bool:
	var health := owner_actor.get_node_or_null("HealthComponent") as HealthComponent if owner_actor != null else null
	return health == null or health.is_downed or health.is_dead

func _return_to_locomotion() -> void:
	if presentation == null:
		return
	if presentation.has_method(&"finish_attack_sequence"):
		presentation.call(&"finish_attack_sequence")
	elif presentation.has_method(&"play_idle"):
		presentation.call(&"play_idle")

func _clear_active() -> void:
	active_token = 0
	active_definition = null
	active_presentation = null
	locked_target = null
	released = false
	elapsed_scaled = 0.0
	locked_range_multiplier = 1.0

func _sequence_error(token: int, action_id: StringName, reason: String, attack_id: StringName = &"") -> void:
	var resolved_attack_id := attack_id
	if resolved_attack_id.is_empty():
		resolved_attack_id = active_definition.id if active_definition != null else &"<missing>"
	var message := "PARTY_FORGE_ATTACK_SEQUENCE_ERROR attack=%s action=%s token=%d reason=%s" % [resolved_attack_id, action_id, token, reason]
	sequence_error.emit(message)
	push_error(message)

func _disconnect_presentation() -> void:
	if presentation == null or not is_instance_valid(presentation):
		return
	if presentation.has_signal(&"attack_event") and presentation.is_connected(&"attack_event", _on_attack_event):
		presentation.disconnect(&"attack_event", _on_attack_event)
	if presentation.has_signal(&"attack_finished") and presentation.is_connected(&"attack_finished", _on_attack_finished):
		presentation.disconnect(&"attack_finished", _on_attack_finished)
