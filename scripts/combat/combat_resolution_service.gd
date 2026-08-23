class_name CombatResolutionService
extends Node

const DAMAGE_EVENT := preload("res://scripts/combat/combat_damage_instance_event.gd")
const DAMAGE_BUNDLE := preload("res://scripts/combat/damage_bundle_result.gd")
const MULTI_CRIT_ROLL := preload("res://scripts/combat/multi_crit_roll.gd")
const OVERKILL_BUFFER := preload("res://scripts/combat/overkill_buffer_service.gd")

signal hit_proc_requested(event)
signal crit_proc_requested(event)
signal life_steal_requested(event)
signal target_killed(event)
signal bundle_completed(bundle)
signal bundle_failed(bundle)
signal diagnostics_changed(diagnostics: Dictionary)

var _combat_rng: CombatRng
var _damage_types: DamageTypeCatalog
var _overkill_buffer: OVERKILL_BUFFER = OVERKILL_BUFFER.new()
var _latest_diagnostics: Dictionary = {}
var _resolving := false
var combat_rng: CombatRng:
	get: return _combat_rng
	set(_value): pass
var damage_types: DamageTypeCatalog:
	get: return _damage_types
	set(_value): pass
var overkill_buffer: OVERKILL_BUFFER:
	get: return _overkill_buffer
	set(_value): pass
var latest_diagnostics: Dictionary:
	get: return _latest_diagnostics.duplicate(true)
	set(_value): pass

func _init(rng_value: CombatRng = null, types_value: DamageTypeCatalog = null) -> void:
	_combat_rng = rng_value
	_damage_types = types_value

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> bool:
	return _overkill_buffer.advance(delta)

func resolve_bundle(packet: DamagePacket, target: CombatantAdapter) -> DAMAGE_BUNDLE:
	if _resolving:
		return _reentrant_failure(packet, target)
	_resolving = true
	var bundle := _resolve_bundle_guarded(packet, target)
	_resolving = false
	return bundle

func _resolve_bundle_guarded(packet: DamagePacket, target: CombatantAdapter) -> DAMAGE_BUNDLE:
	var target_id := target.combatant_id if target != null else &""
	var target_position := _capture_target_position(target)
	var initial_error := _initial_validation_error(packet, target)
	if not initial_error.is_empty():
		return _publish_failure(initial_error, target_id, target_position, [], _empty_diagnostics(packet))
	if not _vector_is_finite(target_position):
		var position_error := "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s reason=target position must be finite" % [packet.attack_id, packet.source_id, target_id]
		return _publish_failure(position_error, target_id, Vector3.ZERO, [], _empty_diagnostics(packet))

	var roll := packet.multi_crit_roll
	var critical_flags: Array[bool] = roll.critical_flags
	var snapshot := DamageResolver.capture_defense(packet, target, _damage_types)
	if snapshot == null or not snapshot.valid:
		var snapshot_error: String = snapshot.error_reason if snapshot != null else "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s reason=missing defense snapshot" % [packet.attack_id, packet.source_id, target_id]
		return _publish_failure(snapshot_error, target_id, target_position, [], _diagnostics_for_roll(roll, 0.0))
	if not target.available or target.health == null or not is_instance_valid(target.health):
		var capture_error := "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s stage=defense_capture reason=target health became unavailable during defense capture" % [packet.attack_id, packet.source_id, target_id]
		var capture_diagnostics := _diagnostics_for_roll(roll, 0.0)
		capture_diagnostics["processed_before_failure"] = 0
		capture_diagnostics["failed_instance_index"] = -1
		capture_diagnostics["capture_failed"] = true
		return _publish_failure(capture_error, target_id, target_position, [], capture_diagnostics)
	if target.health.is_dead or target.health.is_downed or target.health.current_health <= 0.0:
		var capture_state_error := "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s stage=defense_capture reason=target health became nonliving during defense capture" % [packet.attack_id, packet.source_id, target_id]
		var capture_state_diagnostics := _diagnostics_for_roll(roll, 0.0)
		capture_state_diagnostics["processed_before_failure"] = 0
		capture_state_diagnostics["failed_instance_index"] = -1
		capture_state_diagnostics["capture_failed"] = true
		return _publish_failure(capture_state_error, target_id, target_position, [], capture_state_diagnostics)

	var captured_health := target.health
	var captured_team_id := target.team_id
	var preflight_target := CombatantAdapter.new(null, target_id, captured_team_id, captured_health, null, true)
	var aggregate_upper_bound := 0.0
	for index: int in critical_flags.size():
		var preflight := DamageResolver.preflight_instance(packet, index, critical_flags[index], snapshot, preflight_target, _damage_types, critical_flags)
		if not bool(preflight.get("valid", false)):
			var preflight_diagnostics := _diagnostics_for_roll(roll, 0.0)
			preflight_diagnostics["processed_before_failure"] = 0
			preflight_diagnostics["failed_instance_index"] = index
			preflight_diagnostics["preflight_failed"] = true
			return _publish_failure(String(preflight.get("error_reason", "PARTY_FORGE_DAMAGE_ERROR reason=instance preflight failed")), target_id, target_position, [], preflight_diagnostics)
		var maximum_final_damage := float(preflight["maximum_final_damage"])
		var next_upper_bound := aggregate_upper_bound + maximum_final_damage
		if not is_finite(next_upper_bound) or next_upper_bound < 0.0:
			var aggregate_error := "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s instance=%d stage=aggregate reason=bundle damage upper bound must be finite and nonnegative" % [packet.attack_id, packet.source_id, target_id, index]
			var aggregate_diagnostics := _diagnostics_for_roll(roll, 0.0)
			aggregate_diagnostics["processed_before_failure"] = 0
			aggregate_diagnostics["failed_instance_index"] = index
			aggregate_diagnostics["preflight_failed"] = true
			return _publish_failure(aggregate_error, target_id, target_position, [], aggregate_diagnostics)
		aggregate_upper_bound = next_upper_bound

	var frozen_dead_health := HealthComponent.new()
	frozen_dead_health.configure(1.0, true, 8.0, 0.5, true)
	frozen_dead_health.current_health = 0.0
	frozen_dead_health.is_dead = true
	var results: Array[DamageResult] = []
	var events: Array[DAMAGE_EVENT] = []
	var total_overkill := 0.0
	var target_alive := true
	var killing_event: DAMAGE_EVENT
	for index: int in critical_flags.size():
		var instance_health: HealthComponent = captured_health if target_alive and is_instance_valid(captured_health) else frozen_dead_health
		var instance_available := target.available if target_alive else true
		if target_alive and not is_instance_valid(captured_health):
			instance_health = null
		var instance_target := CombatantAdapter.new(
			null,
			target_id,
			captured_team_id,
			instance_health,
			null,
			instance_available,
		)
		var result := DamageResolver.resolve_instance(
			packet,
			index,
			critical_flags[index],
			snapshot,
			instance_target,
			_combat_rng,
			_damage_types,
			target_alive,
			target_alive,
			critical_flags
		)
		results.append(result)
		if not result.valid:
			var failed_diagnostics := _diagnostics_for_roll(roll, total_overkill)
			failed_diagnostics["processed_before_failure"] = index
			failed_diagnostics["failed_instance_index"] = index
			frozen_dead_health.free()
			return _publish_failure(result.error_reason, target_id, target_position, results, failed_diagnostics)

		var event: DAMAGE_EVENT = DAMAGE_EVENT.create(result, target_position, critical_flags.size())
		events.append(event)
		if result.killing_blow or result.overkill_only:
			var next_overkill := total_overkill + result.excess_damage
			if not is_finite(next_overkill) or next_overkill < 0.0:
				var overkill_error := "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s instance=%d stage=overkill reason=total overkill must be finite and nonnegative" % [packet.attack_id, packet.source_id, target_id, index]
				var overkill_diagnostics := _diagnostics_for_roll(roll, total_overkill)
				overkill_diagnostics["processed_before_failure"] = index
				overkill_diagnostics["failed_instance_index"] = index
				frozen_dead_health.free()
				return _publish_failure(overkill_error, target_id, target_position, results, overkill_diagnostics)
			total_overkill = next_overkill
		if result.killing_blow:
			target_alive = false
			killing_event = event
		if result.proc_eligible and result.target_was_alive:
			hit_proc_requested.emit(event.copy())
			if result.critical:
				crit_proc_requested.emit(event.copy())
			if packet.life_steal_rate > 0.0:
				life_steal_requested.emit(event.copy())
		if result.killing_blow:
			target_killed.emit(event.copy())

	if killing_event != null:
		var recorded := _overkill_buffer.record(target_id, total_overkill, {
			"attack_id": String(packet.attack_id),
			"source_id": String(packet.source_id),
			"instance_count": critical_flags.size(),
			"killing_instance_index": killing_event.instance_index,
			"target_position": target_position,
		})
		if not recorded:
			var buffer_error := "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s stage=overkill_buffer reason=record rejected" % [packet.attack_id, packet.source_id, target_id]
			var buffer_diagnostics := _diagnostics_for_roll(roll, total_overkill)
			buffer_diagnostics["processed_before_failure"] = results.size()
			frozen_dead_health.free()
			return _publish_failure(buffer_error, target_id, target_position, results, buffer_diagnostics)
	frozen_dead_health.free()
	var diagnostics := _diagnostics_for_roll(roll, total_overkill)
	diagnostics["resolution_valid"] = true
	diagnostics["error_reason"] = ""
	_latest_diagnostics = diagnostics.duplicate(true)
	var bundle: DAMAGE_BUNDLE = DAMAGE_BUNDLE.create_completed(target_id, target_position, results, events, total_overkill, diagnostics)
	diagnostics_changed.emit(diagnostics.duplicate(true))
	bundle_completed.emit(bundle.copy())
	return bundle

func _reentrant_failure(packet: DamagePacket, target: CombatantAdapter) -> DAMAGE_BUNDLE:
	var target_id := target.combatant_id if target != null else &""
	var reason := "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s reason=reentrant bundle resolution is not allowed" % [_attack_id(packet), _source_id(packet), _target_id(target)]
	var diagnostics := _empty_diagnostics(packet)
	diagnostics["resolution_valid"] = false
	diagnostics["error_reason"] = reason
	diagnostics["reentrant_rejected"] = true
	return DAMAGE_BUNDLE.create_failed(reason, target_id, Vector3.ZERO, [], diagnostics)

func _publish_failure(reason: String, target_id: StringName, target_position: Vector3, results: Array[DamageResult], diagnostics: Dictionary) -> DAMAGE_BUNDLE:
	var published_diagnostics := diagnostics.duplicate(true)
	published_diagnostics["resolution_valid"] = false
	published_diagnostics["error_reason"] = reason
	_latest_diagnostics = published_diagnostics.duplicate(true)
	var bundle: DAMAGE_BUNDLE = DAMAGE_BUNDLE.create_failed(reason, target_id, target_position, results, published_diagnostics)
	diagnostics_changed.emit(published_diagnostics.duplicate(true))
	bundle_failed.emit(bundle.copy())
	return bundle

func _initial_validation_error(packet: DamagePacket, target: CombatantAdapter) -> String:
	if _combat_rng == null:
		return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s reason=missing combat RNG" % [_attack_id(packet), _source_id(packet), _target_id(target)]
	if _damage_types == null:
		return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s reason=missing damage catalog" % [_attack_id(packet), _source_id(packet), _target_id(target)]
	if packet == null:
		return "PARTY_FORGE_DAMAGE_ERROR attack=<null> source=<null> target=%s reason=missing packet" % _target_id(target)
	if not packet.valid:
		return packet.error_reason
	if target == null:
		return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=<null> reason=missing target provider" % [packet.attack_id, packet.source_id]
	if target.combatant_id.is_empty():
		return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=<empty> reason=missing combatant identity" % [packet.attack_id, packet.source_id]
	if not target.available or target.health == null:
		return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s reason=target unavailable" % [packet.attack_id, packet.source_id, target.combatant_id]
	if target.health.is_dead or target.health.is_downed or target.health.current_health <= 0.0:
		return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s reason=target not living at bundle start" % [packet.attack_id, packet.source_id, target.combatant_id]
	var roll := packet.multi_crit_roll
	if roll == null or not roll.valid:
		return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s reason=missing valid multi-crit roll" % [packet.attack_id, packet.source_id, target.combatant_id]
	var flags: Array[bool] = roll.critical_flags
	if flags.is_empty() or flags.size() != roll.processed_instances:
		return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s processed=%d flags=%d reason=invalid multi-crit instance evidence" % [packet.attack_id, packet.source_id, target.combatant_id, roll.processed_instances, flags.size()]
	return ""

func _diagnostics_for_roll(roll: MULTI_CRIT_ROLL, total_overkill: float) -> Dictionary:
	if roll == null:
		return _empty_diagnostics(null)
	return {
		"requested_instances": roll.requested_instances,
		"processed_instances": roll.processed_instances,
		"guaranteed_instances": roll.guaranteed_instances,
		"fractional_chance": roll.fractional_chance,
		"fractional_draw": roll.fractional_draw,
		"fractional_success": roll.fractional_success,
		"fractional_draw_consumed": roll.fractional_draw_consumed,
		"ceiling_truncated": roll.ceiling_truncated,
		"requested_count_overflow": roll.requested_count_overflow,
		"total_overkill": total_overkill,
	}

func _empty_diagnostics(packet: DamagePacket) -> Dictionary:
	var roll := packet.multi_crit_roll if packet != null and packet.valid else null
	return _diagnostics_for_roll(roll, 0.0) if roll != null else {
		"requested_instances": 0,
		"processed_instances": 0,
		"guaranteed_instances": 0,
		"fractional_chance": 0.0,
		"fractional_draw": -1.0,
		"fractional_success": false,
		"fractional_draw_consumed": false,
		"ceiling_truncated": false,
		"requested_count_overflow": false,
		"total_overkill": 0.0,
	}

func _capture_target_position(target: CombatantAdapter) -> Vector3:
	if target == null or target.actor == null or not is_instance_valid(target.actor):
		return Vector3.ZERO
	return target.actor.global_position if target.actor.is_inside_tree() else target.actor.position

func _vector_is_finite(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

func _attack_id(packet: DamagePacket) -> String:
	return String(packet.attack_id) if packet != null else "<null>"

func _source_id(packet: DamagePacket) -> String:
	return String(packet.source_id) if packet != null else "<null>"

func _target_id(target: CombatantAdapter) -> String:
	return String(target.combatant_id) if target != null else "<null>"
