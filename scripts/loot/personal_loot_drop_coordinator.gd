class_name PersonalLootDropCoordinator
extends RefCounted

var roll_service: PersonalLootRollService
var contexts: RunContextRegistry
var equipment: EquipmentCatalog
var foundation: ItemFoundationCatalog
var registry: GroundItemRegistry
var difficulty_id: StringName = &"normal"
var heat := 0.0

var _identities: Dictionary = {}
var _ownership := GroundLootOwnershipService.new()
var _configured := false

func configure(
	personal_roll_service: PersonalLootRollService,
	context_registry: RunContextRegistry,
	session_identities: Dictionary,
	equipment_catalog: EquipmentCatalog,
	foundation_catalog: ItemFoundationCatalog,
	ground_registry: GroundItemRegistry,
	difficulty: StringName = &"normal",
	heat_value: float = 0.0,
) -> PackedStringArray:
	var errors := PackedStringArray()
	if personal_roll_service == null:
		errors.append(_error("roll_service", "must not be null"))
	if context_registry == null:
		errors.append(_error("contexts", "must not be null"))
	if equipment_catalog == null:
		errors.append(_error("equipment", "must not be null"))
	if foundation_catalog == null:
		errors.append(_error("foundation", "must not be null"))
	if ground_registry == null:
		errors.append(_error("registry", "must not be null"))
	if personal_roll_service != null and (personal_roll_service.difficulty_id != difficulty or not is_equal_approx(personal_roll_service.heat, heat_value)):
		errors.append(_error("item_level_context", "roll and generation difficulty/Heat must match"))
	if personal_roll_service != null and personal_roll_service.loot_tuning != null and not personal_roll_service.loot_tuning.supports_difficulty(difficulty):
		errors.append(_error("difficulty_id", "unsupported difficulty %s" % difficulty))
	if not is_finite(heat_value) or heat_value < 0.0:
		errors.append(_error("heat", "must be finite and nonnegative"))
	if context_registry != null:
		for context: PlayerRunContext in context_registry.all_contexts():
			errors.append_array(_identity_errors(context, session_identities.get(context.run_player_id)))
	if not errors.is_empty():
		_configured = false
		return errors
	roll_service = personal_roll_service
	contexts = context_registry
	equipment = equipment_catalog
	foundation = foundation_catalog
	registry = ground_registry
	difficulty_id = difficulty
	heat = heat_value
	_identities = session_identities.duplicate(true)
	_configured = true
	return errors

func resolve_defeat(event: EnemyDefeatEvent) -> Dictionary:
	var report := {"decisions": [], "spawned_drop_ids": [], "diagnostics": []}
	if not _configured:
		(report.diagnostics as Array).append(_diagnostic(&"configuration", &"coordinator_unavailable", &"", _error("configuration", "coordinator is unavailable")))
		return report
	if event == null or not event.validate().is_empty():
		(report.diagnostics as Array).append(_diagnostic(&"configuration", &"invalid_event", &"", _error("event", "enemy defeat event is invalid")))
		return report
	var decisions := roll_service.resolve(event)
	report["decisions"] = decisions
	for decision: PersonalLootDecision in decisions:
		if decision == null or not decision.success:
			continue
		var context := contexts.context_for(decision.run_player_id)
		if context == null:
			(report.diagnostics as Array).append(_diagnostic(&"ownership", &"context_missing", decision.run_player_id, _owner_error(decision.run_player_id, "context is unavailable")))
			continue
		var identity := _identities.get(decision.run_player_id) as Dictionary
		var request := _request_for(decision, context)
		var drop_id := StringName("drop:%s:%d" % [decision.run_player_id, event.defeat_sequence])
		var record_identity := {
			"drop_id": drop_id,
			"run_player_id": decision.run_player_id,
			"profile_id": decision.profile_id,
			"player_number": int(identity.get("player_number", 0)),
			"color_id": StringName(identity.get("color_id", &"")),
			"world_position": event.world_position,
			"source_id": request.source_id,
		}
		var result := _ownership.create_drop(context, request, record_identity, equipment, foundation, registry)
		if not result.ok():
			(report.diagnostics as Array).append(_diagnostic(result.diagnostic_stage, result.diagnostic_code, decision.run_player_id, _owner_error(decision.run_player_id, result.error)))
			continue
		(report.spawned_drop_ids as Array).append(drop_id)
	return report

func _request_for(decision: PersonalLootDecision, context: PlayerRunContext) -> ItemGenerationRequest:
	var request := ItemGenerationRequest.create(
		decision.generation_seed,
		decision.generation_sequence,
		decision.item_level,
		&"ordinary_enemy",
		&"ordinary_drop",
		_ordinary_rarity_ids(foundation),
	)
	request.difficulty_id = difficulty_id
	request.heat = heat
	request.party_archetype_tags = _party_archetype_tags(context)
	request.charisma_value = _leader_charisma(context)
	request.unlock_tags = _generation_unlock_tags(context, foundation)
	return request

func _ordinary_rarity_ids(source: ItemFoundationCatalog) -> Array[StringName]:
	var result: Array[StringName] = []
	if source == null:
		return result
	for rarity: ItemRarityDefinition in source.rarities:
		if rarity != null and rarity.instance_supported and rarity.ordinary_generation_enabled:
			result.append(rarity.id)
	result.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	return result

func _party_archetype_tags(context: PlayerRunContext) -> Array[StringName]:
	var result: Array[StringName] = []
	if context == null or context.party == null:
		return result
	for member: PartyMemberState in context.party.members:
		if member == null:
			continue
		var has_caster := &"caster" in member.capability_tags
		var has_ranged := &"ranged" in member.capability_tags
		if has_caster and &"caster" not in result:
			result.append(&"caster")
		if has_ranged and &"ranged" not in result:
			result.append(&"ranged")
		if not has_caster and not has_ranged and &"melee" not in result:
			result.append(&"melee")
	result.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	return result

func _leader_charisma(context: PlayerRunContext) -> float:
	var leader_id := _leader_id(context)
	if leader_id <= 0 or context.party == null:
		return 0.0
	var stats := context.party.stats_for(leader_id)
	return stats.value(&"charisma") if stats != null else 0.0

func _generation_unlock_tags(context: PlayerRunContext, source: ItemFoundationCatalog) -> Array[StringName]:
	var result: Array[StringName] = []
	var profile := context.profile_snapshot if context != null else null
	if profile == null or source == null:
		return result
	var available := source.generation_unlock_tags()
	for value: String in profile.permanent_feature_unlocks:
		var tag := StringName(value)
		if tag in available and tag not in result:
			result.append(tag)
	result.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	return result

func _leader_id(context: PlayerRunContext) -> int:
	if context == null or context.party == null:
		return 0
	for member: PartyMemberState in context.party.members:
		if member != null and member.is_leader:
			return member.member_id
	return 0

func _identity_errors(context: PlayerRunContext, value: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not value is Dictionary:
		errors.append(_owner_error(context.run_player_id, "session identity is missing"))
		return errors
	var identity := value as Dictionary
	if int(identity.get("player_number", 0)) != context.player_slot_index + 1:
		errors.append(_owner_error(context.run_player_id, "session player number does not match slot"))
	if not PlayerColorPalette.is_valid(StringName(identity.get("color_id", &""))):
		errors.append(_owner_error(context.run_player_id, "session color is invalid"))
	return errors

func _owner_error(run_player_id: StringName, reason: String) -> String:
	return "PARTY_FORGE_PERSONAL_LOOT_COORDINATOR_ERROR run_player_id=%s reason=%s" % [run_player_id, reason]

func _error(field: String, reason: String) -> String:
	return "PARTY_FORGE_PERSONAL_LOOT_COORDINATOR_ERROR field=%s reason=%s" % [field, reason]

func _diagnostic(stage: StringName, code: StringName, run_player_id: StringName, message: String) -> Dictionary:
	return {
		"stage": stage,
		"code": code,
		"run_player_id": run_player_id,
		"message": message,
	}
