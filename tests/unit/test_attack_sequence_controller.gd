extends RefCounted

const LEADER_SCENE := preload("res://scenes/characters/leader.tscn")
const COMPANION_SCENE := preload("res://scenes/characters/companion.tscn")

class ExecutorProbe extends Node:
	var calls := 0
	var last_definition: AttackDefinition
	var last_target: CombatTarget
	var last_presentation: Resource

	func execute(definition: AttackDefinition, target: CombatTarget, presentation_definition: Resource = null) -> void:
		calls += 1
		last_definition = definition
		last_target = target
		last_presentation = presentation_definition

class PresentationProbe extends Node:
	signal attack_event(token: int, action_id: StringName, event_name: StringName)
	signal attack_finished(token: int, action_id: StringName)

	var last_rate := 0.0
	var last_token := 0
	var idle_requests := 0

	func start_attack(_definition: AttackDefinition, _target: CombatTarget, _presentation_definition: Resource, token: int, playback_rate: float) -> bool:
		last_rate = playback_rate
		last_token = token
		return token > 0

	func action_playback_rate() -> float:
		return last_rate

	func play_idle() -> bool:
		idle_requests += 1
		return true

func run() -> Array[String]:
	var failures: Array[String] = []
	var root := _new_root()
	var owner := _new_actor(root, LEADER_SCENE, 1, 1)
	var target := _new_actor(root, COMPANION_SCENE, 2, 2)
	var alternate := _new_actor(root, COMPANION_SCENE, 3, 2)
	target.position = Vector3(1.0, 0.0, 0.0)
	alternate.position = Vector3(0.5, 0.0, 0.0)
	var executor := ExecutorProbe.new()
	var presentation := PresentationProbe.new()
	var controller := AttackSequenceController.new()
	root.add_child(executor)
	root.add_child(presentation)
	root.add_child(controller)
	controller.configure(owner, presentation, executor)
	var errors: Array[String] = []
	controller.sequence_error.connect(func(message: String) -> void: errors.append(message))
	var attack := _attack()
	var visual := _visual(attack)

	var first_token := controller.request(attack, target.get_combat_target(), visual, 1.25, 1.0)
	TestAssertions.truthy(first_token > 0, "valid attack sequence starts", failures)
	TestAssertions.near(presentation.last_rate, 1.25, 0.001, "sequence forwards playback rate", failures)
	controller.advance(0.2)
	TestAssertions.equal(executor.calls, 0, "attack does not execute before required event", failures)
	presentation.attack_event.emit(first_token, visual.action_id, visual.required_event_name)
	TestAssertions.equal(executor.calls, 1, "matching event executes exactly once", failures)
	TestAssertions.equal(executor.last_target.actor, target, "release retains the locked target actor", failures)
	TestAssertions.equal(executor.last_presentation, visual, "executor receives presentation context", failures)
	presentation.attack_event.emit(first_token, visual.action_id, visual.required_event_name)
	TestAssertions.equal(executor.calls, 1, "duplicate event cannot execute twice", failures)
	TestAssertions.truthy(_has_reason(errors, "duplicate event"), "duplicate event emits stable sequence diagnostic", failures)
	presentation.attack_finished.emit(first_token, visual.action_id)
	TestAssertions.truthy(not controller.is_busy(), "released sequence clears on action finish", failures)

	var stale_token := controller.request(attack, target.get_combat_target(), visual, 1.0, 1.0)
	presentation.attack_event.emit(first_token, visual.action_id, visual.required_event_name)
	TestAssertions.equal(executor.calls, 1, "stale token cannot release active sequence", failures)
	TestAssertions.truthy(_has_reason(errors, "stale event"), "stale event emits stable sequence diagnostic", failures)
	controller.cancel("test reset")

	var invalid_target_token := controller.request(attack, target.get_combat_target(), visual, 1.0, 1.0)
	(target.get_node("HealthComponent") as HealthComponent).kill()
	presentation.attack_event.emit(invalid_target_token, visual.action_id, visual.required_event_name)
	TestAssertions.equal(executor.calls, 1, "invalidated locked target cancels without executing", failures)
	TestAssertions.truthy(not controller.is_busy(), "invalidated target clears sequence", failures)
	TestAssertions.truthy(_has_reason(errors, "target invalid at release"), "invalidated target reports cancellation reason", failures)
	TestAssertions.truthy(executor.last_target.actor != alternate, "invalidated target never retargets", failures)

	var owner_health := owner.get_node("HealthComponent") as HealthComponent
	var downed_token := controller.request(attack, alternate.get_combat_target(), visual, 1.0, 1.0)
	owner_health.is_downed = true
	presentation.attack_event.emit(downed_token, visual.action_id, visual.required_event_name)
	TestAssertions.equal(executor.calls, 1, "downed owner cannot release attack", failures)
	TestAssertions.truthy(_has_reason(errors, "owner downed at release"), "downed release reports cancellation reason", failures)
	owner_health.is_downed = false

	var missing_event_token := controller.request(attack, alternate.get_combat_target(), visual, 1.0, 1.0)
	presentation.attack_finished.emit(missing_event_token, visual.action_id)
	TestAssertions.equal(executor.calls, 1, "action finish without event cannot execute", failures)
	TestAssertions.truthy(_has_reason(errors, "missing required event impact"), "missing event emits stable sequence diagnostic", failures)
	TestAssertions.truthy(errors.all(func(message: String) -> bool: return message.begins_with("PARTY_FORGE_ATTACK_SEQUENCE_ERROR")), "all sequence diagnostics use stable marker", failures)

	root.free()
	return failures

func _attack() -> AttackDefinition:
	var attack := AttackDefinition.new()
	attack.id = &"sequence_test"
	attack.kind = AttackDefinition.Kind.MELEE_CLEAVE
	attack.cooldown = 1.0
	attack.range = 2.0
	return attack

func _visual(attack: AttackDefinition) -> AttackPresentationDefinition:
	var visual := AttackPresentationDefinition.new()
	visual.id = &"sequence_test_visual"
	visual.attack_id = attack.id
	visual.action_id = &"attack_slash"
	visual.required_event_name = &"impact"
	visual.action_duration = 0.55
	visual.release_time = 0.28
	return visual

func _new_actor(root: Node3D, scene: PackedScene, member_id: int, team_id: int) -> PartyActor:
	var actor := scene.instantiate() as PartyActor
	actor.team_id = team_id
	root.add_child(actor)
	actor.configure(PartyMemberState.new(member_id, load("res://data/classes/fighter.tres") as ClassDefinition, member_id == 1))
	return actor

func _new_root() -> Node3D:
	var root := Node3D.new()
	root.name = "AttackSequenceControllerTest"
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	return root

func _has_reason(messages: Array[String], reason: String) -> bool:
	for message: String in messages:
		if "reason=%s" % reason in message:
			return true
	return false
